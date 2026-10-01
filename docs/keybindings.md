# Keybindings Reference

## XFCE Desktop

| Binding | Action |
|---------|--------|
| `Ctrl+Alt+T` | Open terminal |
| `Ctrl+Alt+L` / `Super+L` | Lock screen (`xflock4`) |
| `Ctrl+Alt+Del` | Log out / shutdown dialog (`xfce4-session-logout`) |
| `Super+D` | Show desktop |
| `Alt+F2` | App finder |
| `Print` | Screenshot (full screen) |
| `Shift+Print` | Screenshot (select region) |
| `Alt+F4` | Close window |
| `Alt+F11` | Fullscreen |

Minimize and maximize have no default key binding in Kali's XFCE; bind them
yourself under Settings → Window Manager → Keyboard if you want them.
| `Alt+Tab` | Switch windows |
| `Ctrl+Alt+Left/Right` | Switch workspace |

## SPICE / VM

| Binding | Action |
|---------|--------|
| `Ctrl+C` / `Ctrl+V` | Copy/paste works between host and guest automatically |
| Drag SPICE window edge | Guest display auto-resizes |

### VM helper commands (run in guest terminal)

| Command | Action |
|---------|--------|
| `fix-display` | Re-trigger xrandr auto-resize |
| `fix-clipboard` | Restart spice-vdagent |
| `pbcopy` / `pbpaste` | Copy/paste via xclip |
| `echo text \| clip` | Pipe to clipboard |
| `clip -o` | Paste from clipboard |
| `osi-update` | Update APT packages (`--all` also upgrades pipx tools) |

## tmux

Prefix is `Ctrl+a`.

| Binding | Action |
|---------|--------|
| `Prefix+\|` | Split pane vertically |
| `Prefix+-` | Split pane horizontally |
| `Prefix+h/j/k/l` | Navigate panes (vim-style) |
| `Prefix+H/J/K/L` | Resize pane |
| `Prefix+r` | Reload tmux config |
| `Prefix+[` | Enter copy mode (vi keys) |
| `v` (copy mode) | Begin selection |
| `y` (copy mode) | Copy selection |
| `Prefix+]` | Paste |
| `Prefix+c` | New window |
| `Prefix+n/p` | Next/previous window |
| `Prefix+1-9` | Jump to window N |
| `Prefix+,` | Rename window |
| `Prefix+$` | Rename session |
| `Prefix+d` | Detach session |

## vim

Leader key is `\` (backslash).

| Binding | Action |
|---------|--------|
| `Enter` | Clear search highlight |
| `\w` | Save file |
| `Ctrl+w hjkl` | Navigate splits |
| `Ctrl+w v` | Vertical split |
| `Ctrl+w s` | Horizontal split |
