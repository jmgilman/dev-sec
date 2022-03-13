#! /usr/bin/env bash
#
# Author: Joshua Gilman <joshuagilman@gmail.com>
#
#/ Usage: key_workspace.sh
#/
#/ Creates a new temporary workspace for working with GnuPG.
#/

set -o errexit  # abort on nonzero exitstatus
set -o pipefail # don't hide errors within pipes

tmpdir=$(mktemp -d -t gnupg_XXXX)
cat /etc/key/gpg.conf >"${tmpdir}/gpg.conf"
cat /etc/key/gpg-agent.conf >"${tmpdir}/gpg-agent.conf"

echo "${tmpdir}"
