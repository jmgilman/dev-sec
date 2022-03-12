#! /usr/bin/env bash
#
# Author: Joshua Gilman <joshuagilman@gmail.com>
#
#/ Usage: build.sh
#/
#/ Builds the flake using the configured multipass instance
#/

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes

readonly yellow='\e[0;33m'
readonly green='\e[0;32m'
readonly red='\e[0;31m'
readonly reset='\e[0m'

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
    printf "${green} %s${reset}\n" "${*}"
}

# Usage: error [ARG]...
#
# Prints all arguments on the standard error stream
error() {
    printf "${red}!!! %s${reset}\n" "${*}" 1>&2
}

# Usage: die MESSAGE
# Prints the specified error message and exits with an error status
die() {
    error "${*}"
    exit 1
}

if ! command -v multipass; then
    die "Multipass must be installed before running this script"
fi

log "Mounting local directory to instance..."
multipass mount "${PWD}" dev-sec:/dev-sec

log "Building flake..."
multipass exec dev-sec -- .nix-profile/bin/nix build /dev-sec#images.rpi

log "Copying image..."
name=$(multipass exec dev-sec -- bash -c "ls \$(pwd)/result/sd-image")
multipass transfer "dev-sec:result/sd-image/${name}" .

log "Cleaning up..."
multipass exec dev-sec -- bash -c "rm -rf \$(pwd)/result"

log "Unmounting local directory..."
multipass umount dev-sec

success "Done!"
