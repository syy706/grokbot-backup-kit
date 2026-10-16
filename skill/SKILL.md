---
name: Box backup and restore via GitHub
description: >-
  Use when backing up this box's skills, agent configs, preferences and small
  workspace files to a private GitHub repo (manually or from a routine), or when
  restoring them after a box reset or data loss.
---
# Box backup & restore via GitHub
Kit: https://github.com/syy706/grokbot-backup-kit installed at `/home/box/backup-kit`.
Parameters (required, from the routine or the user's request): `BACKUP_GH_USER` (GitHub username), `BACKUP_REPO` (PRIVATE data repo name). Token: env `GITHUB_BACKUP_TOKEN` (classic PAT with `repo`, or fine-grained with Contents + Administration read/write). Never print the token or write it to files, URLs or git config.

Decide the mode: **backup** (routine fire / user asks) or **restore** (box reset, kit or skills missing, user asks). If the kit is missing in backup mode, install it: `git clone -q https://github.com/syy706/grokbot-backup-kit /home/box/backup-kit` (or restore first if a data repo exists).

## Token check
`[ -n "$GITHUB_BACKUP_TOKEN" ]`. If missing: in backup mode run `backup.sh --dry-run` only; then ask the user for the token via a secret request and stop.

## Backup
1. `BACKUP_GH_USER=<user> BACKUP_REPO=<repo> /home/box/backup-kit/backup.sh` — stages allowlisted files, writes a tool manifest, runs a secret scan, creates the private repo if missing, commits + pushes only on changes, and copies the kit into `kit/` of the data repo.
2. If the secret scan aborts, do NOT push. Report flagged files; exclude them in the CONFIG section of `collect.py` or remove the secret.
3. Report briefly (commit + file count / "no changes" / error). From a routine, stay quiet on success.

## Restore
1. Bootstrap (blank box; nothing written to git config):
   ```
   A=$(mktemp); printf '#!/bin/sh\ncase "$1" in U*) echo x-access-token;; *) echo "$GITHUB_BACKUP_TOKEN";; esac\n' >$A; chmod +x $A
   rm -rf /tmp/gb && GIT_ASKPASS=$A GIT_TERMINAL_PROMPT=0 git clone -q https://github.com/$BACKUP_GH_USER/$BACKUP_REPO.git /tmp/gb; rm -f $A
   ```
2. Dry run: `bash /tmp/gb/kit/restore.sh`; summarize NEW/CHANGED for the user.
3. After the user confirms (or if files are only missing), `bash /tmp/gb/kit/restore.sh --apply` (`--no-tools` skips package reinstall). Old files go to `/home/box/.pre-restore/<timestamp>/`; kit is reinstalled to `/home/box/backup-kit`.
4. Verify: dry run again (expect 0 new/changed), spot-check files, report.

## Notes
- Always excluded: secrets/gateway files, cookies, tokens, keys, .env, ~/.ssh, gh config, *.lock, large media, venvs, node_modules, caches.
- Memory and routines live server-side and aren't backed up. Browser logins aren't either; re-sign-in may be needed.
