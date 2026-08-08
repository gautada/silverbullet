#!/bin/sh
# ╭――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╮
# │ VERSION - SILVERBULLET VERSION REPORT                                     │
# ╰――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╯
# This script returns the SilverBullet server version packaged in the container.
# SilverBullet 2.10 exposes a dedicated version subcommand.
VERSION=$(/usr/local/bin/silverbullet version 2>/dev/null | head -n 1 | cut -d- -f1)

if [ -z "$VERSION" ]; then
    printf "unknown\n"
    exit 1
fi

printf "%s\n" "$VERSION"
