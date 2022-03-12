#! /usr/bin/env bash
#
# Author: Joshua Gilman <joshuagilman@gmail.com>
#
#/ Usage: setup_mp.sh
#/
#/ Configures a multipass instance for building NixOS images
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

log "Launching multipass instance..."
multipass launch \
    --cpus 4 \
    --mem 8G \
    --disk 25G \
    --name dev-sec

log "Running nix installer..."
curl -L https://nixos.org/nix/install | multipass exec dev-sec -- bash -s

log "Configuring experimental features..."
multipass exec dev-sec -- mkdir -p .config/nix
echo "experimental-features = nix-command flakes" | multipass exec dev-sec tee .config/nix/nix.conf

success "Done!"
