#!/usr/bin/env bash
# Usage: backup.sh [--dry-run]   env: GITHUB_BACKUP_TOKEN, BACKUP_GH_USER, BACKUP_REPO (both required)
set -euo pipefail
KIT="$(cd "$(dirname "$0")" && pwd)"; REPO_DIR="$KIT/repo"
U="${BACKUP_GH_USER:?set BACKUP_GH_USER to your GitHub username}"; R="${BACKUP_REPO:?set BACKUP_REPO to your (private) data repo name}"
URL="https://github.com/$U/$R.git"
if [ "${1:-}" = "--dry-run" ]; then
  python3 "$KIT/collect.py" /tmp/x --list
  T=$(mktemp -d); python3 "$KIT/collect.py" "$T"; cp "$KIT"/*.sh "$KIT"/*.py "$T/"
  "$KIT/secret_scan.sh" "$T"; rc=$?; rm -rf "$T"; exit $rc
fi
: "${GITHUB_BACKUP_TOKEN:?GITHUB_BACKUP_TOKEN not set}"
# token only via env-reading askpass; never written to disk config
export GIT_ASKPASS="$KIT/askpass.sh" GIT_TERMINAL_PROMPT=0
api(){ curl -fsS -H "Authorization: Bearer $GITHUB_BACKUP_TOKEN" -H "Accept: application/vnd.github+json" "$@"; }
if ! api "https://api.github.com/repos/$U/$R" >/dev/null 2>&1; then
  echo "creating private repo $U/$R"
  api -X POST https://api.github.com/user/repos -d "{\"name\":\"$R\",\"private\":true,\"auto_init\":true}" >/dev/null
  sleep 2
fi
if [ ! -d "$REPO_DIR/.git" ]; then git clone -q "$URL" "$REPO_DIR"; else git -C "$REPO_DIR" pull -q --rebase || true; fi
git -C "$REPO_DIR" remote set-url origin "$URL"
python3 "$KIT/collect.py" "$REPO_DIR"
mkdir -p "$REPO_DIR/kit"; cp "$KIT"/backup.sh "$KIT"/restore.sh "$KIT"/collect.py "$KIT"/secret_scan.sh "$KIT"/askpass.sh "$REPO_DIR/kit/"
"$KIT/secret_scan.sh" "$REPO_DIR" || { echo "ABORT: not pushing"; exit 2; }
cd "$REPO_DIR"; git add -A
if git diff --cached --quiet; then echo "no changes"; exit 0; fi
git -c user.name="backup-kit" -c user.email="backup@localhost" commit -qm "backup $(date '+%Y-%m-%d %H:%M:%S %z')"
git push -q origin HEAD; echo "pushed: $(git rev-parse --short HEAD), $(git ls-files | wc -l) files"
