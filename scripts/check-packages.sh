#!/bin/bash
# ──────────────────────────────────────────────────────────────────────────────
# OSI Linux — package list validation
#
# Kali rolling removes and renames packages continuously. When a name in
# osi.list.chroot stops existing, `lb chroot` fails partway through a 30-90
# minute build with an apt error — the slowest possible way to discover a
# one-word typo. The package list already carries scars from this (see the
# "removed — no longer packaged" comments in it).
#
# This resolves every requested package name against the live kali-rolling
# index, counting both real packages and virtual ones (Provides:).
#
# Exit codes:
#   0  every package resolves, OR the index could not be fetched (infra, not a
#      code defect — reported as SKIP so transient mirror trouble does not fail CI)
#   1  the index was fetched and at least one package does not exist
#
# Usage: bash scripts/check-packages.sh
# ──────────────────────────────────────────────────────────────────────────────
set -uo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIST="$PROJECT_DIR/kali-config/variant-osi/package-lists/osi.list.chroot"

MIRROR="${OSI_MIRROR:-http://http.kali.org/kali}"
SUITE="${OSI_SUITE:-kali-rolling}"
ARCH="${OSI_ARCH:-amd64}"
COMPONENTS="${OSI_COMPONENTS:-main contrib non-free non-free-firmware}"

if [ ! -f "$LIST" ]; then
    echo "[FAIL] package list not found: $LIST"
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "==> Validating package list against $SUITE/$ARCH"

# ── Requested names (strip comments and blanks) ──────────────────────────────
grep -vE '^[[:space:]]*(#|$)' "$LIST" | tr -d ' \t' | sort -u > "$WORK/want.txt"
WANT_COUNT=$(wc -l < "$WORK/want.txt")
echo "    requested: $WANT_COUNT package(s)"

# ── Fetch the indices ────────────────────────────────────────────────────────
FETCHED=0
: > "$WORK/have.txt"
for comp in $COMPONENTS; do
    url="$MIRROR/dists/$SUITE/$comp/binary-$ARCH/Packages.gz"
    if curl -sfL --max-time 180 -o "$WORK/$comp.gz" "$url" 2>/dev/null; then
        # Collect real package names and anything they Provide (virtual packages).
        if zcat "$WORK/$comp.gz" 2>/dev/null | awk '
            /^Package: /  { print $2 }
            /^Provides: / { sub(/^Provides: /, "")
                            n = split($0, a, ", ")
                            for (i = 1; i <= n; i++) { split(a[i], b, " "); print b[1] } }
        ' >> "$WORK/have.txt"; then
            FETCHED=$((FETCHED + 1))
        fi
    fi
done

if [ "$FETCHED" -eq 0 ]; then
    echo "    [SKIP] could not fetch any package index from $MIRROR"
    echo "           (network or mirror problem — not treated as a failure)"
    exit 0
fi

sort -u "$WORK/have.txt" -o "$WORK/have.txt"
echo "    index:     $(wc -l < "$WORK/have.txt") installable name(s) from $FETCHED component(s)"

# ── Compare ──────────────────────────────────────────────────────────────────
comm -23 "$WORK/want.txt" "$WORK/have.txt" > "$WORK/missing.txt"
MISSING_COUNT=$(wc -l < "$WORK/missing.txt")

if [ "$MISSING_COUNT" -eq 0 ]; then
    echo "    [ OK ] all $WANT_COUNT packages resolve"
    exit 0
fi

echo
echo "    [FAIL] $MISSING_COUNT package(s) do not exist in $SUITE/$ARCH:"
while read -r pkg; do
    [ -n "$pkg" ] || continue
    # Offer the closest existing names to make the fix obvious.
    near=$(grep -E "^${pkg%%-*}" "$WORK/have.txt" 2>/dev/null | head -4 | tr '\n' ' ')
    printf '           %-34s' "$pkg"
    [ -n "$near" ] && printf ' (near: %s)' "$near"
    printf '\n'
done < "$WORK/missing.txt"
echo
echo "    These would fail 'lb chroot' partway through a full build."
exit 1
