#!/bin/bash
# Run as osi inside the guest.
set -e

TOOLS="$HOME/tools"
mkdir -p "$TOOLS"

# Metasploit
if ! command -v msfconsole &>/dev/null; then
    curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb \
        > /tmp/msfinstall
    chmod +x /tmp/msfinstall
    sudo /tmp/msfinstall
fi

# Burp Suite Community
if [ ! -f "$TOOLS/burpsuite/burpsuite_community.jar" ]; then
    mkdir -p "$TOOLS/burpsuite"
    wget -q "https://portswigger.net/burp/releases/download?product=community&type=jar" \
        -O "$TOOLS/burpsuite/burpsuite_community.jar"
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/burpsuite" << 'BURP'
#!/bin/sh
exec java -jar "$HOME/tools/burpsuite/burpsuite_community.jar" "$@"
BURP
    chmod +x "$HOME/.local/bin/burpsuite"
fi

# pipx tools
pipx install impacket
pipx install git+https://github.com/Pennyw0rth/NetExec

# Ruby tools
gem install evil-winrm

# Responder
if [ ! -d "$TOOLS/Responder" ]; then
    git clone https://github.com/lgandx/Responder "$TOOLS/Responder"
    echo "3.11.9" > "$TOOLS/Responder/.python-version"
fi

# BloodHound
if [ ! -d "$TOOLS/BloodHound" ]; then
    git clone https://github.com/SpecterOps/BloodHound "$TOOLS/BloodHound"
fi

# Go-based tools (nuclei, subfinder, httpx, feroxbuster, amass, ligolo-ng)
install_gh_release() {
    local REPO="$1" PATTERN="$2" BIN="$3"
    command -v "$BIN" &>/dev/null && return
    VER=$(curl -s "https://api.github.com/repos/$REPO/releases/latest" | jq -r .tag_name)
    URL="https://github.com/$REPO/releases/download/$VER/$(echo "$PATTERN" | sed "s/VERSION/${VER#v}/g")"
    curl -fsSL "$URL" -o /tmp/tool.zip
    unzip -q /tmp/tool.zip -d /tmp/tool/
    sudo mv /tmp/tool/"$BIN" /usr/local/bin/ 2>/dev/null \
        || sudo mv /tmp/tool/*/"$BIN" /usr/local/bin/
    rm -rf /tmp/tool /tmp/tool.zip
}

install_gh_release "projectdiscovery/nuclei"    "nuclei_VERSION_linux_amd64.zip"       "nuclei"
install_gh_release "projectdiscovery/subfinder" "subfinder_VERSION_linux_amd64.zip"    "subfinder"
install_gh_release "projectdiscovery/httpx"     "httpx_VERSION_linux_amd64.zip"        "httpx"
install_gh_release "epi052/feroxbuster"         "feroxbuster-VERSION-linux-amd64.zip"  "feroxbuster"
install_gh_release "owasp-amass/amass"          "amass_linux_amd64.zip"                "amass"

# ligolo-ng (proxy + agent)
if [ ! -f "$TOOLS/ligolo-ng/proxy" ]; then
    mkdir -p "$TOOLS/ligolo-ng"
    VER=$(curl -s https://api.github.com/repos/nicocha30/ligolo-ng/releases/latest | jq -r .tag_name)
    for PART in proxy agent; do
        curl -fsSL "https://github.com/nicocha30/ligolo-ng/releases/download/$VER/ligolo-ng_${PART}_linux_amd64.tar.gz" \
            | tar xz -C "$TOOLS/ligolo-ng/"
    done
fi

# Update nuclei templates
nuclei -update-templates 2>/dev/null || true

echo "Tier 2 tools installed."
