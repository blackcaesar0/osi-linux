# OSI Linux — common tasks.
# Run `make` or `make help` for the list.

SHELL      := /bin/bash
PROJECT    := osi-linux
SKEL       := kali-config/common/includes.chroot/etc/skel
SHELL_SRCS := build.sh launch-vm.sh $(wildcard scripts/*.sh) \
              $(wildcard kali-config/common/hooks/live/*.hook.chroot)
ISO        ?= $(firstword $(wildcard build/*.iso))

.DEFAULT_GOAL := help
.PHONY: help lint shellcheck syntax check-theme check-repo check-packages check check-all sync-skel build rebuild vm vm-create clean

help: ## Show this help
	@echo "OSI Linux — available targets:"
	@echo
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[1m%-14s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "Variables:  ISO=<path>  (defaults to the newest ISO in build/)"

## ── Quality gates ────────────────────────────────────────────────────────────

syntax: ## Parse every shell script with bash -n
	@echo "==> bash -n"
	@rc=0; for f in $(SHELL_SRCS); do \
	    if bash -n "$$f" 2>/dev/null; then echo "  [ OK ] $$f"; \
	    else echo "  [FAIL] $$f"; bash -n "$$f" || true; rc=1; fi; \
	  done; exit $$rc

shellcheck: ## Lint every shell script (warning severity)
	@command -v shellcheck >/dev/null 2>&1 || { \
	    echo "shellcheck not installed — sudo apt install shellcheck"; exit 1; }
	@echo "==> shellcheck --severity=warning"
	@shellcheck -s bash --severity=warning $(SHELL_SRCS) && echo "  [ OK ] no warnings"

check-theme: ## Verify OSI-Noir is strictly B&W and skel is in sync
	@bash scripts/check-theme.sh

check-repo: ## Verify hook exec bits and package-list hygiene
	@echo "==> Repo invariants"
	@rc=0; \
	 for h in kali-config/common/hooks/live/*.hook.chroot; do \
	     if [ -x "$$h" ]; then echo "  [ OK ] executable: $$h"; \
	     else echo "  [FAIL] not executable: $$h"; rc=1; fi; \
	 done; \
	 list=kali-config/variant-osi/package-lists/osi.list.chroot; \
	 dups=$$(grep -vE '^[[:space:]]*(#|$$)' $$list | tr -d ' \t' | sort | uniq -d); \
	 if [ -n "$$dups" ]; then \
	     echo "  [FAIL] duplicate packages:"; echo "$$dups" | sed 's/^/         /'; rc=1; \
	 else \
	     echo "  [ OK ] no duplicate packages ($$(grep -vcE '^[[:space:]]*(#|$$)' $$list) entries)"; \
	 fi; \
	 exit $$rc

check-packages: ## Resolve every package against the live kali-rolling index (needs network)
	@bash scripts/check-packages.sh

lint: syntax shellcheck ## Run bash -n and shellcheck

check: lint check-theme check-repo ## Fast offline gates (use this before pushing)
	@echo
	@echo "All checks passed."

check-all: check check-packages ## Everything, including the networked package check
	@echo
	@echo "All checks passed (including package resolution)." 

## ── Maintenance ──────────────────────────────────────────────────────────────

sync-skel: ## Copy config/ into the /etc/skel overlay (build.sh does this too)
	@echo "==> Syncing config/ -> $(SKEL)"
	@mkdir -p "$(SKEL)/.config/xfce4/terminal" \
	          "$(SKEL)/.config/xfce4/xfconf/xfce-perchannel-xml"
	@cp config/tmux/tmux.conf            "$(SKEL)/.tmux.conf"
	@cp config/vim/vimrc                 "$(SKEL)/.vimrc"
	@cp config/shell/bash_aliases        "$(SKEL)/.bash_aliases"
	@cp config/xfce4/terminal/terminalrc "$(SKEL)/.config/xfce4/terminal/terminalrc"
	@cp config/xfce4/xfconf/xfce-perchannel-xml/*.xml \
	    "$(SKEL)/.config/xfce4/xfconf/xfce-perchannel-xml/"
	@echo "  Done."

## ── Build / run ──────────────────────────────────────────────────────────────

build: ## Build the ISO (needs root; 30-90 min)
	sudo ./build.sh

rebuild: ## Clean then build the ISO from scratch
	sudo ./build.sh --clean

vm: ## Boot the installed VM  (make vm)
	./launch-vm.sh

vm-create: ## Create a qcow2 disk and boot the installer  (make vm-create ISO=path)
	@test -n "$(ISO)" || { echo "No ISO found. Pass one: make vm-create ISO=build/osi-linux.iso"; exit 1; }
	bash scripts/create-vm.sh "$(ISO)"

clean: ## Remove build artefacts from the host
	bash scripts/cleanup-host.sh
