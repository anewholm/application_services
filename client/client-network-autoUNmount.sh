#!/bin/bash
# Not for loopback!
[ "$IFACE" != "lo" ] || exit 0

# comment this for testing
exec 1>/dev/null # squelch output for non-interactive

# umount all sshfs mounts
logger -t mountsshfs "Beginning client-network-autoUNmount"
mounted=`grep 'fuse.sshfs\|sshfs#' /etc/mtab | awk '{ print $2 }'`
[ -n "$mounted" ] && { for mount in $mounted; do umount -l $mount; done; }
