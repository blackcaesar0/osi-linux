#!/bin/bash
# Run as root inside the guest.
# Applies kernel parameters, sudoers, time sync, and resource limits.
set -euo pipefail

step() { echo; echo "==> $*"; }

# ── Resolve the desktop user ─────────────────────────────────────────────────
DESKTOP_USER="${SUDO_USER:-${DESKTOP_USER:-}}"
if [ -z "$DESKTOP_USER" ] || [ "$DESKTOP_USER" = "root" ]; then
    DESKTOP_USER=$(getent passwd | awk -F: '$3 >= 1000 && $6 ~ /^\/home\// {print $1}' | grep -v nobody | head -1)
fi

if [ -z "$DESKTOP_USER" ]; then
    echo "ERROR: Could not determine desktop user."
    echo "       Set DESKTOP_USER=<username> and re-run."
    exit 1
fi

if ! id "$DESKTOP_USER" &>/dev/null; then
    echo "ERROR: User '$DESKTOP_USER' does not exist."
    exit 1
fi

# ── sysctl ────────────────────────────────────────────────────────────────────
step "Writing sysctl tuning (/etc/sysctl.d/99-osi.conf)"
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-osi.conf << 'EOF'
# Large socket buffers — helps scanners and packet capture under load
net.core.rmem_max        = 134217728
net.core.wmem_max        = 134217728
net.core.rmem_default    = 16777216
net.core.wmem_default    = 16777216
net.ipv4.tcp_rmem        = 4096 87380 134217728
net.ipv4.tcp_wmem        = 4096 65536 134217728
net.core.netdev_max_backlog = 5000

# Core dumps — useful for exploit development and debugging
kernel.core_pattern      = /tmp/core.%e.%p
kernel.core_uses_pid     = 1
fs.suid_dumpable         = 2

# inotify — some recon/monitoring tools exhaust the default
fs.inotify.max_user_watches   = 524288
fs.inotify.max_user_instances = 512

# Perf events — needed for profiling and some kernel exploit research
kernel.perf_event_paranoid = 1

# Increase the max open files at the kernel level
fs.file-max = 2097152
EOF
sysctl -p /etc/sysctl.d/99-osi.conf

# ── sudoers ───────────────────────────────────────────────────────────────────
step "Configuring passwordless sudo for $DESKTOP_USER (/etc/sudoers.d/99-osi-nopasswd)"
echo "$DESKTOP_USER ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-osi-nopasswd
chmod 0440 /etc/sudoers.d/99-osi-nopasswd

# ── openntpd runit service ────────────────────────────────────────────────────
step "Setting up openntpd time sync service"
mkdir -p /etc/sv/openntpd
cat > /etc/sv/openntpd/run << 'EOF'
#!/bin/sh
exec /usr/sbin/ntpd -d -s -f /etc/ntpd.conf 2>&1
EOF
chmod +x /etc/sv/openntpd/run
ln -sf /etc/sv/openntpd /var/service/ 2>/dev/null || true

# ── resource limits ───────────────────────────────────────────────────────────
# NOTE: Cannot use single-quoted heredoc here — $DESKTOP_USER must expand
step "Setting resource limits (/etc/security/limits.d/99-osi.conf)"
mkdir -p /etc/security/limits.d
cat > /etc/security/limits.d/99-osi.conf << EOF
# High open-file limits — needed by scanners, proxies, and fuzzing tools
*    soft nofile  65535
*    hard nofile  65535
$DESKTOP_USER  soft nofile  1048576
$DESKTOP_USER  hard nofile  1048576
EOF

# ── timezone ──────────────────────────────────────────────────────────────────
step "Setting timezone to ${TZ:-UTC}"
ln -sf "/usr/share/zoneinfo/${TZ:-UTC}" /etc/localtime

echo ""
echo "==> sysconfig complete."
