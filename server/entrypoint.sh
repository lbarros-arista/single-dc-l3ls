#!/bin/sh
set -eu

mkdir -p /run/sshd
ssh-keygen -A

# These daemons fork into the background by default.
/usr/sbin/lldpd
/usr/sbin/smcrouted

# Keep SSH in the foreground so the container stays up and Docker can track it.
exec /usr/sbin/sshd -D -e
