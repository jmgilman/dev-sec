#! /usr/bin/env bash
#
# Author: Joshua Gilman <joshuagilman@gmail.com>
#
#/ Usage: key_build.sh
#/
#/ Creates a PGP master and subkeys
#/

set -o errexit  # abort on nonzero exitstatus
set -o nounset  # abort on unbound variable
set -o pipefail # don't hide errors within pipes

readonly yellow='\e[0;33m'
readonly green='\e[0;32m'
readonly red='\e[0;31m'
readonly cyan='\e[0;36m'
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

# Usage: yesno MESSAGE
#
# Asks the user for an answer via y/n syntax.
yesno() {
    read -p "${*} [y/n] " -r
    printf "\n"
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        return 1
    else
        return 0
    fi
}

# Usage: yesno_exit MESSAGE
#
# Asks the user to confirm via y/n syntax. Exits if answer is no.
yesno_exit() {
    read -p "${*} [y/n] " -r
    printf "\n"
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
}

# Usage: block_network
#
# Sets a soft block on Wifi and Bluetooth adapters.
block_network() {
    restart=0
    wstatus=$(rfkill -J | jq -r ".rfkilldevices[] | select ( .type == \"wlan\") | .soft")
    if [[ "${wstatus}" == "unblocked" ]]; then
        log "Wifi is not blocked. Using rfkill to block wifi..."
        sudo rfkill block wifi
        restart=1
    else
        success "Wifi is blocked."
    fi

    bstatus=$(rfkill -J | jq -r ".rfkilldevices[] | select ( .type == \"bluetooth\") | .soft")
    if [[ "${bstatus}" == "unblocked" ]]; then
        log "Bluetooth is not blocked. Using rfkill to block bluetooth..."
        sudo rfkill block bluetooth
        restart=1
    else
        success "Bluetooth is blocked."
    fi

    if [[ ${restart} == 1 ]]; then
        die "Please reboot the system to apply the changes."
    fi
}

# Usage: gen_primary FULLNAME EMAIL PASSPHRASE ALG
#
# Generates a GnuPG primary key using the given arguments.
gen_primary() {
    local name="${1}"
    local email="${2}"
    local pass="${3}"
    local alg="${4}"

    gpg --batch \
        --passphrase "${pass}" \
        --quick-generate-key \
        "${name} <${email}>" \
        "${alg}" cert,sign never
}

# Usage: gen_subkey PASSPHRASE FINGERPRINT ALGORITHM FUNCTION EXPIRES
#
# Adds a new subkey to primary key (FINGERPRINT) using given arguments.
gen_subkey() {
    local pass="${1}"
    local fp="${2}"
    local alg="${3}"
    local func="${4}"
    local expire="${5}"

    gpg --batch \
        --pinentry-mode=loopback \
        --passphrase "${primary_pass}" \
        --quick-add-key "${fp}" "${alg}" "${func}" "${expire}"
}

log "Welcome!"
log "This is an interactive script for generating PGP keys."
log "The result of this process will be a PGP master key along with subkeys."
log "Subkeys will be responsible for signing, encryption, and authentication."
log "Subkeys will eventually be transferred to a YubiKey."
log ""

log "--------------------------------------------------------------------------"
log "First I will confirm that bluetooth/wifi are blocked."
block_network

log "Now I will generate some entropy using rngd."
sudo rngd -r /dev/hwrng

log "Waiting 15 seconds for rngd to come up..."
sleep 15

log "Now I will ask you to verify that the current system time is correct."
date
yesno_exit "Confirm the above date/time is correct"

success "Setup complete."

log "--------------------------------------------------------------------------"
log "Now I will generate a strong randomized password for the primary key."
log "Please write down and store this password in a safe place."

primary_pass="$(
    tr -dc '[:upper:]' </dev/urandom | fold -w 20 | head -n1
    echo
)"
printf "${yellow}>> Primary key passphrase: ${cyan}%s${reset}\n" "${primary_pass}"
yesno_exit "Confirm the passphrase has been stored safely."

log "Now I will generate the primary key."
log "First I need to collect some information."

read -r -p "Enter fullname: " fullname
read -r -p "Enter email: " email
printf "${yellow}>> Full name: ${cyan}%s${reset}\n" "${fullname}"
printf "${yellow}>> Email: ${cyan}%s${reset}\n" "${email}"
yesno_exit "Confirm this is correct?"

log "Generating primary key..."
gen_primary "${fullname}" "${email}" "${primary_pass}" ed25519
fp="$(gpg --list-keys --with-colons | sed -n 3p | cut -f10 -d ':')"

printf "${green}>> Success! Generated primary key with fingerprint: ${cyan}%s${reset}\n" "${fp}"

log "Generating signing subkey..."
gen_subkey "${primary_pass}" "${fp}" ed25519 sign 1y

log "Generating encryption subkey..."
gen_subkey "${primary_pass}" "${fp}" cv25519 encr 1y

log "Generating authentication subkey..."
gen_subkey "${primary_pass}" "${fp}" ed25519 auth 1y

success "Success! Subkeys successfully generated."
log "Now I will show the contents of the keyring."
gpg -K
yesno_exit "Please verify the above looks good"

log "--------------------------------------------------------------------------"
log "Now I will export copies of the keys to facilitate backing them up."
mkdir -p "${GNUPGHOME}/backup"

log "Backing up primary key..."
gpg --batch \
    --pinentry-mode=loopback \
    --passphrase "${primary_pass}" \
    --armor --export-secret-keys "${fp}" >"${GNUPGHOME}/backup/master.asc"
log "Backing up subkeys..."
gpg --batch \
    --pinentry-mode=loopback \
    --passphrase "${primary_pass}" \
    --armor --export-secret-subkeys "${fp}" >"${GNUPGHOME}/backup/sub.asc"
log "Backing up revocation certificate..."
cp "${GNUPGHOME}/openpgp-revocs.d/${fp}.rev" "${GNUPGHOME}/backup/${fp}.rev"

success "Success! Keys have been backed up to ${GNUPGHOME}/backup."

log "--------------------------------------------------------------------------"
log "Now I will generate a strong randomized password for the backup media."
log "Please write down and store this password in a safe place."

backup_pass="$(
    tr -dc '[:upper:]' </dev/urandom | fold -w 20 | head -n1
    echo
)"
printf "${yellow}>> Backup media passphrase: ${cyan}%s${reset}\n" "${backup_pass}"
yesno_exit "Confirm the passphrase has been stored safely."

log "Now I will locate the correct backup USB device to prepare."
yesno_exit "Confirm the backup USB is plugged in."

log "Please examine the below block devices"
lsblk --list --exclude 7 -o name,size,type,tran

read -r -p "Enter the block device name for the backup USB device: " device

printf "${yellow}The following device will be prepared for backing up key data: ${cyan}%s${reset}\n" "${device}"
yesno_exit "Confirm this is the correct device."

log "Now I will prepare the backup media for securely backing up the key data."
error "WARNING: This process will erase the entire media with randomized data."
yesno_exit "Continue?"

log "It's best practice to write randomized data to the backup media."
log "This will prepare it for securely holding encrypted data."
if yesno "Would you like to perform this step?"; then
    log "Preparing USB backup media..."
    sudo dd if=/dev/urandom of="${device}" bs=4M status=progress
else
    log "Skipping..."
fi

log "Creating a new partition..."
sudo parted -s "${device}" mklabel gpt
sudo parted -s "${device}" mkpart private ext4 1MB 26MB

log "Encrypting partition with LUKS..."
echo -n "${backup_pass}" | sudo cryptsetup luksFormat "${device}1" -d -
echo -n "${backup_pass}" | sudo cryptsetup luksOpen "${device}1" private -d -

log "Creating ext4 filesystem..."
sudo mkfs.ext4 /dev/mapper/private -L private

log "Mounting newly created partition..."
sudo mkdir -p /mnt/private
sudo mount /dev/mapper/private /mnt/private

log "Backing up files..."
sudo cp "${GNUPGHOME}"/backup/* /mnt/private

log "Unmounting partition..."
sudo umount /mnt/private
sudo cryptsetup luksClose private

success "Success! Key data has been securely backed up to USB device."

log "Now I will create a second partition for storing the public key."

log "Creating a new partition..."
sudo parted -s "${device}" mkpart public ntfs 27MB 52MB

log "Creating NTFS filesystem..."
sudo mkfs.ntfs "${device}2" -L public

log "Mounting newly created partition..."
sudo mkdir -p /mnt/public
sudo mount "${device}2" /mnt/public

log "Exporting public key..."
gpg --armor --export "${fp}" | sudo tee "/mnt/public/gpg-${fp}.asc"

log "Unmounting partition..."
sudo umount /mnt/public

success "Success! Public key has been backed up to USB device."

log "--------------------------------------------------------------------------"
log "This completes the setup script."
log "I will now cleanup the temporary environment."

log "Deleting GnuPG home directory..."
sudo rm -rf "${GNUPGHOME}"

success "Done!"
log "To clear memory, the machine will now reboot."
yesno_exit "Confirm reboot?"
sudo reboot now
