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

trap '[[ $? -ne 0 ]] && echo "Hit <Enter> to exit" && read' EXIT

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

# Usage: check_env
# exports special variables to the environment to distinguish OS type
# 
#   WSL: Windows Subsystem for Linux
#
check_env() {
	if uname -a | grep -Eiq '(NT|Microsoft|WSL)'; then
		export WSL=1
		log "Detected running in WSL.."
	fi
}

if ! command -v multipass; then
	die "Multipass must be installed before running this script"
fi

check_env

LOCAL_MOUNTPOINT="$PWD"/image
if [ -v WSL ]; then
	log "Configuring multipass to allow instances to mount local filesystem...
Local mounts are disabled by default on windows..."
	if ! multipass set local.privileged-mounts=Yes; then
		die "Couldn't set local.privileged-mounts setting on WSL"
	fi
	if multipass version | grep -iq win; then
		LOCAL_MOUNTPOINT="$(wslpath -w $LOCAL_MOUNTPOINT)"
		log "multipass is a windows .exe, converting $PWD to $LOCAL_MOUNTPOINT.."
	fi
fi
log "Mounting local directory to instance..."
multipass mount $LOCAL_MOUNTPOINT dev-sec:/dev-sec

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
