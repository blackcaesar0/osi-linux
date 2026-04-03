#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# OSI Linux — Clean up build artifacts on the host
# Usage: bash scripts/cleanup-host.sh
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

echo "OSI Linux — Host Cleanup"
echo "========================"
echo ""

# ── Build directory ───────────────────────────────────────────────────────────
if [ -d "$BUILD_DIR" ]; then
    SIZE=$(du -sh "$BUILD_DIR" 2>/dev/null | cut -f1)
    echo "Build directory: $BUILD_DIR ($SIZE)"
    echo -n "Remove? [y/N] "; read -r CONFIRM
    if [ "$CONFIRM" = "y" ] || [ "$CONFIRM" = "Y" ]; then
        # May need root for chroot leftovers
        if [ "$(id -u)" -eq 0 ]; then
            rm -rf "$BUILD_DIR"
        else
            sudo rm -rf "$BUILD_DIR"
        fi
        echo "  Removed."
    fi
else
    echo "No build directory found — already clean."
fi

# ── Stale PID/socket files ────────────────────────────────────────────────────
for f in /tmp/osi-vm.pid /tmp/qga.sock; do
    if [ -e "$f" ]; then
        if [ "$f" = "/tmp/osi-vm.pid" ]; then
            PID=$(cat "$f" 2>/dev/null || echo "")
            if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
                echo "VM is still running (PID $PID) — not removing $f"
                continue
            fi
        fi
        rm -f "$f"
        echo "Removed stale $f"
    fi
done

echo ""
echo "Cleanup complete."
