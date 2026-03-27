#!/bin/sh
# ╭――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╮
# │ VERSION - SILVERBULLET VERSION REPORT                                     │
# ╰――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╯
# This script returns the SilverBullet server version packaged in the container.
# It parses the verbose output to extract only the major.minor.patch version.

# Example output: Starting SilverBullet version 2.5.2-0-gad45eeb-2026-03-06T12-20-46Z
VERSION=$(/usr/local/bin/silverbullet --version 2>&1 | awk '/version/ {print $NF}' | cut -d'-' -f1)

if [ -z "$VERSION" ]; then
    printf "unknown\n"
    exit 1
fi

printf "%s\n" "$VERSION"
