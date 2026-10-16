#!/usr/bin/env bash
# Exit 1 if likely secrets are found under $1.
D="${1:?dir}"
PAT='ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|gho_[A-Za-z0-9]{20,}|sk-[A-Za-z0-9_-]{20,}|AKIA[0-9A-Z]{16}|BEGIN [A-Z ]*PRIVATE KEY|xox[baprs]-[A-Za-z0-9-]{10,}|"?password"?[[:space:]]*[:=][[:space:]]*"?[^"[:space:]]{4,}'
HITS=$(grep -raEl --exclude-dir=.git "$PAT" "$D" 2>/dev/null)
if [ -n "$HITS" ]; then echo "SECRET SCAN FAILED in:"; echo "$HITS" | sed "s|^$D/||"; exit 1; fi
echo "secret scan: clean"
