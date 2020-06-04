#!/bin/bash

# An ISO builder for macOS to use with Parallels or other VM software on a mac.
#
# To use just download a version of macOS from Apple
# Based on  https://apple.stackexchange.com/questions/253640/install-sierra-as-guest-os-in-vm-with-parallels-12

# Joshua Olson 2020-06-02
# Available under: CC BY-SA 3.0 
# https://creativecommons.org/licenses/by-sa/3.0/

 set -x

cur_dir="$(pwd)"
default_dmg="${cur_dir}/InstallOS.dmg"
# There needs to be two parameters
[ $# -eq 0 ] && { 
    echo "Usage: $0 <InstallOS.dmg>"; 
    echo
    echo "<InstallOS.dmg>:\t default:${default_dmg}"
    exit 1; 
}

# Variables
dmg="${1:=$default_dmg}"
path="$(dirname "${dmg}")"
filename="$(basename "${dmg}")"

esd_location="${path}/InstallESD.dmg"
tmp="/tmp/InstallOS.pkg"
tmp_path="${tmp}/InstallOS.pkg"

# Mount points
installer="/Volumes/InstallOS.dmg"
base_system="/Volumes/OS X Base System"
iso="/Volumes/iso"
esd="/Volumes/esd"

# Extract InstallESD from InstallOS.dmg
echo "Extracting InstallESK.dmg from ${dmg}"
hdiutil attach "${dmg}" -noverify -nobrowse -mountpoint ${installer}
pkgutil --expand-full ${installer}/InstallOS.pkg ${tmp}
mv ${tmp_path}/InstallESD.dmg ${path}

# Get the version of the OS from the Info.plist inside the installer
version="10.$(cat ${tmp_path}/Payload/*/Contents/Info.plist | grep macos | cut -d. -f2 | cut -di -f1)"
# Get the name of the OS from the name of the Installer
os_name="$(ls ${tmp_path}/Payload/ | awk '{print $3}' | cut -d' ' -f3 | cut -d. -f1)"

iso_name="macOS_${os_name}_${version}"
echo "Mac OS version found: ${iso_name}"
iso_file="${path}/${iso_name}"

echo
echo "Convert InstallESD.dmg to a CDR disk image"
hdiutil attach ${esd_location} -noverify -nobrowse -mountpoint ${esd}
hdiutil create -o ${iso_file}.cdr -size 6144m -layout SPUD -fs HFS+J

echo
echo "Creating ISO disk image from scratch"
hdiutil attach ${iso_file}.cdr.dmg -noverify -nobrowse -mountpoint ${iso}

# Use asr to copy the BaseSystem onto the new volume (it also renames the ISO mount to OS X Base System)
asr restore -source ${esd}/BaseSystem.dmg -target ${iso} -noprompt -noverify -erase

# Replace the BaseSystem packages with the ones from the ESD image
rm "${base_system}/System/Installation/Packages"
cp -rp ${esd}/Packages "${base_system}/System/Installation"

cp -rp ${esd}/BaseSystem.chunklist "${base_system}/"
cp -rp ${esd}/BaseSystem.dmg "${base_system}/"

# Detach so we can convert it
hdiutil detach "${base_system}"
hdiutil convert ${iso_file}.cdr.dmg -format UDTO -o ${iso_file}.iso
mv ${iso_file}.iso.cdr ${iso_file}.iso

# Clean up
rm -rf ${tmp}
rm ${esd_location}
rm ${iso_name}.cdr.dmg

hdiutil detach ${installer}
hdiutil detach ${esd}
