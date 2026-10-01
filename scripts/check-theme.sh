#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# OSI Linux — theme consistency guard
#
# OSI-Noir is documented as strict black-and-white: "limited grayscale only,
# never full colour". That rule is easy to break by accident — a copied snippet
# or an upstream default quietly reintroduces an accent colour and the distro
# ships a muddled identity.
#
# This script fails if either invariant is broken:
#   1. Any hex colour in a theme-bearing file is not grayscale (R == G == B).
#   2. config/ and its /etc/skel mirror have drifted apart.
#
# Usage: bash scripts/check-theme.sh
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR" || exit 1

RC=0
fail() { printf '  [FAIL] %s\n' "$*"; RC=1; }
ok()   { printf '  [ OK ] %s\n' "$*"; }

# ── 1. Grayscale-only check ──────────────────────────────────────────────────
echo "==> Checking theme files are strictly grayscale"

THEME_FILES=(
    config/tmux/tmux.conf
    config/vim/vimrc
    config/xfce4/terminal/terminalrc
    kali-config/common/includes.chroot/usr/share/themes/OSI-Noir/gtk-3.0/gtk.css
    kali-config/common/includes.chroot/usr/share/themes/OSI-Noir/gtk-3.0/gtk-dark.css
    kali-config/common/includes.chroot/usr/share/themes/OSI-Noir/gtk-4.0/gtk.css
    kali-config/common/includes.chroot/usr/share/themes/OSI-Noir/xfwm4/themerc
    kali-config/common/includes.chroot/usr/share/osi/firefox/userChrome.css
    kali-config/common/includes.chroot/etc/lightdm/lightdm-gtk-greeter.conf
    kali-config/common/hooks/live/0020-desktop-setup.hook.chroot
    kali-config/common/hooks/live/0030-osi-branding.hook.chroot
    kali-config/common/hooks/live/0031-grub-theme.hook.chroot
    kali-config/common/hooks/live/0035-osi-noir-theme.hook.chroot
)

for f in "${THEME_FILES[@]}"; do
    [ -f "$f" ] || { fail "missing theme file: $f"; continue; }

    # Pull every #RRGGBB literal and keep the ones that are not grayscale.
    bad=$(grep -oE '#[0-9a-fA-F]{6}\b' "$f" 2>/dev/null | sort -u | awk '
        {
            hex = tolower(substr($0, 2))
            r = substr(hex, 1, 2); g = substr(hex, 3, 2); b = substr(hex, 5, 2)
            if (r != g || g != b) print $0
        }')

    if [ -n "$bad" ]; then
        fail "$f contains non-grayscale colour(s): $(echo "$bad" | tr '\n' ' ')"
    else
        ok "$f"
    fi
done

# ── 1b. GTK3 theme must import a base sheet AND clamp its chroma ─────────────
# GTK 3 does not merge a named theme with a built-in default: the theme's
# gtk.css IS the whole stylesheet, so without an @import every widget loses its
# padding and minimum size. The import pulls in Adwaita's geometry, but Adwaita
# also hardcodes blue as literal colours that @define-color cannot reach — so
# the import is only safe while the grayscale clamp block accompanies it.
# Fail if one is present without the other.
echo
echo "==> Checking the GTK3 theme imports a base sheet and clamps its chroma"
for f in kali-config/common/includes.chroot/usr/share/themes/OSI-Noir/gtk-3.0/gtk.css \
         kali-config/common/includes.chroot/usr/share/themes/OSI-Noir/gtk-3.0/gtk-dark.css; do
    if [ ! -f "$f" ]; then fail "missing GTK3 theme file: $f"; continue; fi

    has_import=0; has_clamp=0
    grep -q 'gtk-contained-dark\.css' "$f" 2>/dev/null && has_import=1
    grep -q 'Neutralise the chroma' "$f" 2>/dev/null && has_clamp=1

    if [ "$has_import" -eq 0 ]; then
        fail "$(basename "$f") does not import a base sheet — widgets lose all padding"
    elif [ "$has_clamp" -eq 0 ]; then
        fail "$(basename "$f") imports Adwaita without the grayscale clamp — blue accents will ship"
    else
        ok "$(basename "$f") imports a base sheet and clamps its chroma"
    fi
done

# ── 2. config/ vs /etc/skel mirror ───────────────────────────────────────────
echo
echo "==> Checking config/ and /etc/skel overlay are in sync"
SKEL="kali-config/common/includes.chroot/etc/skel"

check_pair() {
    local src="$1" dst="$2"
    if [ ! -f "$src" ]; then fail "missing source: $src"; return; fi
    if [ ! -f "$dst" ]; then fail "missing skel copy: $dst"; return; fi
    if diff -q "$src" "$dst" >/dev/null 2>&1; then
        ok "$(basename "$src") in sync"
    else
        fail "$src and $dst have drifted (run: make sync-skel)"
    fi
}

check_pair config/tmux/tmux.conf              "$SKEL/.tmux.conf"
check_pair config/vim/vimrc                   "$SKEL/.vimrc"
check_pair config/shell/bash_aliases          "$SKEL/.bash_aliases"
check_pair config/xfce4/terminal/terminalrc   "$SKEL/.config/xfce4/terminal/terminalrc"

for xml in config/xfce4/xfconf/xfce-perchannel-xml/*.xml; do
    [ -f "$xml" ] || continue
    check_pair "$xml" "$SKEL/.config/xfce4/xfconf/xfce-perchannel-xml/$(basename "$xml")"
done

echo
if [ "$RC" -eq 0 ]; then
    echo "Theme consistency: PASS"
else
    echo "Theme consistency: FAIL"
fi
exit "$RC"
