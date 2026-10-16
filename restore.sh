#!/usr/bin/env bash
# Usage: restore.sh [--apply] [--no-tools]   default is dry-run. env: GITHUB_BACKUP_TOKEN, BACKUP_GH_USER, BACKUP_REPO
# Bootstrap on a fresh box:
#   export GITHUB_BACKUP_TOKEN=...; T=$(mktemp -d); printf '#!/bin/sh\ncase "$1" in U*) echo x-access-token;; *) echo "$GITHUB_BACKUP_TOKEN";; esac\n' >$T/a; chmod +x $T/a
#   GIT_ASKPASS=$T/a git clone https://github.com/$BACKUP_GH_USER/$BACKUP_REPO.git /tmp/gb && bash /tmp/gb/kit/restore.sh
set -euo pipefail
APPLY=0; TOOLS=1; for a in "$@"; do case $a in --apply) APPLY=1;; --no-tools) TOOLS=0;; esac; done
U="${BACKUP_GH_USER:?set BACKUP_GH_USER to your GitHub username}"; R="${BACKUP_REPO:?set BACKUP_REPO to your (private) data repo name}"
HERE="$(cd "$(dirname "$0")" && pwd)"
if [ -d "$HERE/../data" ]; then SRC="$(cd "$HERE/.." && pwd)"; else
  : "${GITHUB_BACKUP_TOKEN:?GITHUB_BACKUP_TOKEN not set}"
  A=$(mktemp); printf '#!/bin/sh\ncase "$1" in U*) echo x-access-token;; *) echo "$GITHUB_BACKUP_TOKEN";; esac\n' >"$A"; chmod +x "$A"
  SRC=$(mktemp -d); GIT_ASKPASS="$A" GIT_TERMINAL_PROMPT=0 git clone -q "https://github.com/$U/$R.git" "$SRC"; rm -f "$A"
fi
map(){ case "$1" in agent-data/*) echo "${BACKUP_HOME:-/home/box}/$1";; workspace/*) echo "/${1}";; esac; }
TS=$(date +%Y%m%d-%H%M%S); PRE="${BACKUP_HOME:-/home/box}/.pre-restore/$TS"
new=0; chg=0; same=0
while IFS= read -r rel; do
  dst=$(map "$rel"); [ -n "$dst" ] || continue; s="$SRC/data/$rel"
  if [ ! -e "$dst" ]; then st=NEW; new=$((new+1)); elif cmp -s "$s" "$dst"; then same=$((same+1)); continue; else st=CHANGED; chg=$((chg+1)); fi
  echo "$st $dst"
  if [ $APPLY = 1 ]; then
    [ -e "$dst" ] && { mkdir -p "$PRE/$(dirname "$dst")"; cp -a "$dst" "$PRE/$dst"; }
    mkdir -p "$(dirname "$dst")"; cp "$s" "$dst"
  fi
done < <(cd "$SRC/data" && find . -type f | sed 's|^\./||')
echo "summary: new=$new changed=$chg unchanged=$same"
mkdir -p ${BACKUP_HOME:-/home/box}/backup-kit; [ $APPLY = 1 ] && cp "$SRC"/kit/* ${BACKUP_HOME:-/home/box}/backup-kit/ 2>/dev/null && chmod +x ${BACKUP_HOME:-/home/box}/backup-kit/*.sh || true
if [ $APPLY = 0 ]; then echo "DRY RUN. re-run with --apply"; exit 0; fi
[ -d "$PRE" ] && echo "previous versions saved to $PRE"
if [ $TOOLS = 1 ]; then
  M="$SRC/manifest"
  [ -s "$M/pip-user.txt" ] && pip install --user -q -r "$M/pip-user.txt" || echo "pip reinstall had errors (non-fatal)"
  [ -s "$M/npm-global.txt" ] && xargs -r npm i -g < "$M/npm-global.txt" || true
  if [ -s "$M/apt-manual.txt" ] && command -v sudo >/dev/null; then
    comm -13 <(apt-mark showmanual | sort) <(sort "$M/apt-manual.txt") | xargs -r sudo apt-get install -y -q || true; fi
fi
echo "restore done"
