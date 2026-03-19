#!/bin/sh
# ╭――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╮
# │ VERSION - SILVERBULLET VERSION REPORT                                     │
# ╰――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――――╯
# This script returns the SilverBullet server version packaged in the container.

printf "%s\n" "${SILVERBULLET_VERSION:-unknown}"
