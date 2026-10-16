#!/usr/bin/env bash
case "$1" in Username*) echo "x-access-token";; *) echo "$GITHUB_BACKUP_TOKEN";; esac
