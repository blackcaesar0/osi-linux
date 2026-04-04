# OSI Linux — bash aliases and pentest helper functions

# ── nmap helpers ──────────────────────────────────────────────────────────────
# Use functions (not aliases) so they accept positional arguments cleanly.

quick_scan() {
    # Fast version + open port scan. Usage: quick_scan <target>
    nmap -sV --open -T4 "$@"
}

full_scan() {
    # Full TCP range, version detection. Usage: full_scan <target>
    nmap -sV -p- --open -T4 "$@"
}

script_scan() {
    # Version + default scripts + all ports. Usage: script_scan <target>
    nmap -sV -sC -p- --open -T4 "$@"
}

udp_scan() {
    # Top 200 UDP ports (requires root). Usage: udp_scan <target>
    sudo nmap -sU --top-ports 200 -T4 "$@"
}

# ── HTTP server ───────────────────────────────────────────────────────────────
serve() {
    # Start a Python HTTP server in the current directory.
    # Usage: serve [port]  (default 8080)
    python3 -m http.server "${1:-8080}"
}

# ── IP helpers ────────────────────────────────────────────────────────────────
myip() {
    # Primary outbound interface IP (no network request needed).
    ip route get 1.1.1.1 2>/dev/null | awk '/src/{print $7; exit}'
}

pubip() {
    # Public IP via ifconfig.me.
    curl -s https://ifconfig.me; echo
}

getip() {
    # Resolve a hostname to IP. Usage: getip <hostname>
    host "$1" | awk '/has address/{print $4}'
}

# ── General ───────────────────────────────────────────────────────────────────
alias ll='ls -lah --color=auto'
alias la='ls -A --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias ports='ss -tlnp'
alias listening='ss -tlnp'

# ── tmux ──────────────────────────────────────────────────────────────────────
alias ta='tmux attach -t'
alias tn='tmux new-session -s'
alias tl='tmux list-sessions'
alias tk='tmux kill-session -t'

# ── Clipboard (works with SPICE host<>guest sharing) ────────────────────────
alias pbcopy='xclip -selection clipboard'
alias pbpaste='xclip -selection clipboard -o'
alias cb='xclip -selection clipboard'
alias cbp='xclip -selection clipboard -o'

# ── Directory shortcuts ───────────────────────────────────────────────────────
alias tools='cd ~/tools'
alias recon='cd ~/tools/recon'
alias exploit='cd ~/tools/exploitation'
alias post='cd ~/tools/post-exploitation'
alias web='cd ~/tools/web'
alias wordlists='cd ~/tools/wordlists'

# ── VM helpers ────────────────────────────────────────────────────────────────
alias fix-display='xrandr --output "$(xrandr | grep " connected" | head -1 | awk "{print \$1}")" --auto'
alias fix-clipboard='killall spice-vdagent 2>/dev/null; sleep 1; spice-vdagent &'
