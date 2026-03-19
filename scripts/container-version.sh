#!/bin/sh
# ╭――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╮
# │ VERSION - SILVERBULLET VERSION REPORT                                     │
# ╰――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╯
# This script returns the SilverBullet server version packaged in the container.

VERSION=$(/usr/local/bin/silverbullet --version 2>&1 | awk '{print $NF}' | tr -d '[:space:]')

if [ -z "$VERSION" ]; then
    printf "unknown\n"
    exit 1
fi

printf "%s\n" "$VERSION"
