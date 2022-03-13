#! /usr/bin/env bash
#
# Author: Joshua Gilman <joshuagilman@gmail.com>
#
#/ Usage: key_open.sh BLOCK_DEVICE
#/
#/ Imports the primary key located at BLOCK_DEVICE/master.asc.
#/

set -o errexit  # abort on nonzero exitstatus
set -o pipefail # don't hide errors within pipes

readonly yellow='\e[0;33m'
readonly green='\e[0;32m'
readonly red='\e[0;31m'
readonly reset='\e[0m'

# Usage: error [ARG]...
#
# Prints all arguments on the standard error stream
error() {
    printf "${red}!!! %s${reset}\n" "${*}" 1>&2
}

# Usage: log [ARG]...
#
# Prints all arguments on the standard output stream
log() {
    printf "${yellow}>> %s${reset}\n" "${*}"
}

# Usage: success [ARG]...
#
# Prints all arguments on the standard output stream
success() {
    printf "${green}>> %s${reset}\n" "${*}"
}

# Usage: die MESSAGE
#
# Prints the specified error message and exits with an error status
die() {
    error "${*}"
    exit 1
}

if [[ -z "${1}" ]]; then
    die "Must specify the block device to import from."
fi

if [[ ! -b "${1}" ]]; then
    die "Invalid block device: ${1}"
fi

device="${1}"

log "Decrypting block device..."
sudo cryptsetup luksOpen "${device}" private

log "Mounting partition /dev/mapper/private at /mnt/private..."
sudo mkdir -p /mnt/private
sudo mount /dev/mapper/private /mnt/private

log "Importing primary key..."
gpg --import /mnt/private/master.asc

fp="$(gpg --list-keys --with-colons | sed -n 3p | cut -f10 -d ':')"
success "Successfully imported key with fingerprint: ${fp}!"
