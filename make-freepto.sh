#!/bin/bash
#set -x

usage() {
    cat <<EOF
$0 [-br] DEVICE
Options:
    -b         skip badblocks check
    -r         skip random filling (use only if you know what you are doing)
    -i IMAGE   put IMAGE on DEVICE (default is binary.img)
EOF
}

# Check if user is root
if [ "$(id -u)" != "0" ]; then
   echo "[-] This script must be run as root" 1>&2
   exit 1
fi

skip_badblocks=0
skip_random=0
img=binary.img

while getopts 'bri:' opt; do
    case $opt in
    b)
        skip_badblocks=1
        ;;
    r)
        skip_random=1
        ;;
    i)
        img=$OPTARG
        ;;
    \?)
        echo "Invalid option: -$OPTARG" >&2
        usage
        exit 1
        ;;
    esac
done
shift $((OPTIND-1))

if ! [[ -f "$img" ]]; then
    echo "Image $img is not valid"
    exit 1
fi

if [ $# != 1 ];then
    echo "[-] Wrong argument number"
    usage
    exit 1
fi

if ! [[ -b $1 ]]; then
    echo "[-] $1 should be a block special device"
    usage
    exit 1
fi
device=$1

# check dependencies
if ! which mkfs.btrfs &> /dev/null; then
     echo "[-] No btrfs. Setting up btrfs-tools"
     sudo apt-get --force-yes --yes install btrfs-tools && echo "[+] Btrfs-tools installed!"
fi
if ! which cryptsetup &> /dev/null; then
     echo "[-] No cryptsetup. Setting up cryptsetup"
     sudo apt-get --force-yes --yes install cryptsetup && echo "[+] Cryptsetup installed!"
fi

# Check for bad block on the device:
if [[ $skip_badblocks -eq 0 ]]; then
    badblocks -c 10240 -s -w -t random -v "${device}"
    echo "[+] Badblock check completed!"
fi

# Random data on the device:
if [[ $skip_random -eq 0 ]]; then
    echo "[+] Writing random data on the device!"
    dd if=/dev/urandom of="${device}"
    echo "[+] Completed!"
fi

# DD THE binary.img to a usb
echo -n "[+] Starting copy"
dd "if=$img" of="${device}" &
ddpid=$!
echo " with PID $ddpid"
totchar=$(stat -c '%s' "$img")
humansize=$(du -h "$img" | cut -f1)
while kill -0 $ddpid; do
    wchar=$(egrep '^wchar:' /proc/$ddpid/io | awk '{ print $2 }')
    echo -en "\rWriting $humansize: $((wchar * 100 / totchar))%"
    sleep 10
done
wait
echo "[+] Completed!"

# Make the partition
echo "[+] Make ecnrypted and persistent partition"
img_bytes=$(stat -c %s "$img")
img_bytes=$((img_bytes+1))

parted "${device}" -- mkpart primary "${img_bytes}B" -1

# Ecnrypt partition
cryptsetup --verbose --batch-mode luksFormat "${device}2" <<<freepto

# Open partition
cryptsetup luksOpen "${device}2" my_usb <<<freepto

# Make FS with label: "persistence"
mkfs.btrfs -L persistence /dev/mapper/my_usb

# Make a mount point
mkdir -p /mnt/my_usb

# Munt the partition
mount /dev/mapper/my_usb /mnt/my_usb/ -o noatime,nodiratime,compress=lzo

# Make the persistence.conf file
echo "/ union" > ~/persistence.conf
mv ~/persistence.conf /mnt/my_usb

# Umount
umount /dev/mapper/my_usb

# Close LUKS
cryptsetup luksClose /dev/mapper/my_usb

# vim: set et ts=4 sw=4:
