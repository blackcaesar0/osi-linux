#!/bin/sh
# OSI Linux — first-run Firefox setup.
#
# Runs once on first XDG autostart, locates the user's Firefox profile (after
# Firefox has been launched at least once and created one), and drops
# userChrome.css into chrome/. Removes itself when done.

set -eu

PROFILES_INI="$HOME/.mozilla/firefox/profiles.ini"
SRC=/usr/share/osi/firefox/userChrome.css
MARKER="$HOME/.config/osi-firefox-init.done"

[ -e "$MARKER" ] && exit 0
[ -r "$SRC" ] || exit 0

if [ ! -f "$PROFILES_INI" ]; then
    # Profile not created yet — exit silently; we'll be re-run next login.
    exit 0
fi

# Pick the default-release profile, falling back to the first profile.
profile=""
in_default=0
while IFS= read -r line; do
    case "$line" in
        \[Profile*\]) in_default=0; current="" ;;
        Path=*) current="${line#Path=}" ;;
        Default=1) [ -n "$current" ] && profile="$current" ;;
    esac
done < "$PROFILES_INI"

if [ -z "$profile" ]; then
    profile=$(awk -F= '/^Path=/{print $2; exit}' "$PROFILES_INI")
fi
[ -n "$profile" ] || exit 0

# The path may be relative to ~/.mozilla/firefox/ or absolute.
case "$profile" in
    /*) profile_dir="$profile" ;;
    *)  profile_dir="$HOME/.mozilla/firefox/$profile" ;;
esac
[ -d "$profile_dir" ] || exit 0

mkdir -p "$profile_dir/chrome"
cp -f "$SRC" "$profile_dir/chrome/userChrome.css"

mkdir -p "$(dirname "$MARKER")"
: > "$MARKER"
