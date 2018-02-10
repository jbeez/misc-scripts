#!/bin/bash
#
# This script offers options to prep an Asus/HP ChromeBox for 
# OpenELEC or Ubuntu installation, create OpenELEC install
# media for a standalone setup, install a custom coreboot
# firmware, and install either OpenELEC 
# or Ubunutu (w/kernel 3.14.1 and XBMC) in a # dual boot config
#
# Created by Matt DeVillier <matt.devillier@gmail.com>
# Parts taken from Jay Lee's ChrUbuntu scripts
#
# May be freely distributed and modified as needed, 
# as long as proper attribution is given.
#
 
#define these here for easy updating
script_version="2.17"
OE_version="OpenELEC-Generic.x86_64-4.1.4"
coreboot_file="coreboot-panther-zako-20140729-md.rom"
seabios_file="seabios-panther-zako-20140729-md.bin"
seabios_md5sum="04869151fbd0399a8799a1bbb14badb2"
dropbox_url="https://dl.dropboxusercontent.com/u/98309225/"
OE_url="http://releases.openelec.tv/"
 
#other globals
usb_devs=""
num_usb_devs=0
usb_device=""
 
function echo_red()
{
echo -e "\E[0;31m$1"
echo -e '\e[0m'
}
 
function echo_green()
{
echo -e "\E[0;32m$1"
echo -e '\e[0m'
}
 
function echo_yellow()
{
echo -e "\E[1;33m$1"
echo -e '\e[0m'
}
 
 
####################
# list USB devices #
####################
function list_usb_devices()
{
#list available drives, excluding internal HDD and root device
rootdev=`rootdev -d -s`
eval usb_devs=(`fdisk -l 2> /dev/null | grep -v 'Disk /dev/sda' | grep -v "Disk $rootdev" | grep 'Disk /dev/sd' | awk -F"/dev/sd|:" '{print $2}'`)
#ensure at least 1 drive available
[ "$usb_devs" != "" ] || return 1
echo -e "\nDevices available:\n"
num_usb_devs=0
for dev in "${usb_devs[@]}"
do
num_usb_devs=$(($num_usb_devs+1))
vendor=`udevadm info --query=all --name=sd${dev} | grep -E "ID_VENDOR=" | awk -F"=" '{print $2}'`
model=`udevadm info --query=all --name=sd${dev} | grep -E "ID_MODEL=" | awk -F"=" '{print $2}'`
sz=`fdisk -l 2> /dev/null | grep "Disk /dev/sd${dev}" | awk '{print $3}'`
echo -n "$num_usb_devs)"
if [ -n "${vendor}" ]; then
    echo -n " ${vendor}"
fi
if [ -n "${model}" ]; then
    echo -n " ${model}"
fi
echo -e " (${sz} GB)" 
done
echo -e ""
return 0
}
 
 
###########################
# Create OE Install Media #
###########################
function create_oe_install_media()
{
echo_green "\nCreate OpenELEC Installation Media"
trap oe_fail INT TERM EXIT
read -p "Connect the USB/SD device (>512MB) to be used as OpenELEC installation media and press [Enter] to continue.
This will erase all contents of the USB/SD device, so be sure no other USB/SD devices are connected. "
list_usb_devices
[ $? -eq 0 ] || die "No USB devices available to create OpenELEC install media."
read -p "Enter the number for the device to be used to install OpenELEC: " usb_dev_index
[ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || die "Error: Invalid option selected."
usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"
#get OpenELEC
echo -e ""
tar_file="${OE_version}.tar"
tar_url="${OE_url}${tar_file}"
wget $tar_url
if [ $? -ne 0 ]; then
    echo_yellow "Failed to download OE; trying dropbox mirror"
    tar_url="${dropbox_url}${tar_file}"
    wget $tar_url   
    if [ $? -ne 0 ]; then
        die "Failed to download OpenELEC; check your Internet connection and try again"
    fi
fi
 
echo_green "OpenELEC download complete; extracting..."
tar -xpf $tar_file
if [ $? -ne 0 ]; then
    die "Failed to extract OpenELEC download; check your Internet connection and try again"
fi
 
cd ${OE_version}
bash ./create_installstick "$usb_device"
cd ..
rm -rf ${OE_version}
trap - INT TERM EXIT
echo_green "
Creation of OpenELEC install media is complete.
Upon reboot, press [ESC] at the boot menu prompt, then select your USB/SD device from the list."
 
echo_yellow "If you have not already done so, run the Standalone Setup option before reboot."
 
read -p "Press [Enter] to return to the main menu."
}
 
function oe_fail() {
trap - INT TERM EXIT
die "\nOpenELEC installation media creation failed; retry with different USB/SD media"
}
 
function die()
{
    echo_red "$@"
    exit 1
}
 
function option_picked() {
    COLOR='\033[01;31m' # bold red
    RESET='\033[00;00m' # normal white
    MESSAGE=${@:-"${RESET}Error: No message passed"}
    echo -e "${COLOR}${MESSAGE}${RESET}"
}
 
###############
# Device Prep #
###############
function device_prep() 
{
# check dev mode firmware 
echo_yellow "\nChecking device config"
if [[ "`crossystem | grep mainfw_type`" != *"developer"* ]]; then
    echo_yellow "setting firmware mode to developer"
    chromeos-firmwareupdate --mode=todev
fi
echo_green "Developer firmware installed"
 
# set dev mode boot flags 
crossystem dev_boot_usb=1 dev_boot_legacy=1 dev_boot_signed_only=0 > /dev/null
echo_green "Developer boot flags set"
 
# update legacy BIOS
flash_legacy
 
echo_green "Finished device config"
}
 
 
######################
# flash legacy BIOS #
######################
function flash_legacy()
{
#first check device name
if echo `crossystem platform_family` | grep -q "Haswell"; then
    echo_yellow "Checking if Legacy BIOS needs updating/repairing"
    cd /tmp
    echo "${seabios_md5sum} legacy.bin" > legacy.md5
    flashrom -r -i RW_LEGACY:legacy.bin > /dev/null 2>&1
    md5sum -c legacy.md5 --quiet > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo_green "Original fixed Legacy BIOS update by John Lewis http://johnlewis.ie"
        #download SeaBIOS update
        echo_yellow "Downloading legacy BIOS/SeaBIOS"
        curl -L -O ${dropbox_url}${seabios_file}
        #verify checksum on downloaded file
        echo "${seabios_md5sum} ${seabios_file}" > ${seabios_file}.md5
        md5sum -c ${seabios_file}.md5 --quiet 2> /dev/null
        if [ $? -eq 0 ]; then
            #flash updated legacy BIOS
            echo_green "\nInstalling SeaBIOS: ${seabios_file}"
            flashrom -w -i RW_LEGACY:${seabios_file}
            echo_green "\nLegacy BIOS successfully updated/repaired"
        else
            #download checksum fail
            echo_red "Legacy BIOS download checksum fail; download corrupted, cannot flash"
        fi     
    else
        echo_green "Legacy BIOS does not need update/repair"
    fi 
fi
}
 
######################
# update legacy BIOS #
######################
function update_legacy()
{
flash_legacy
read -p "Press [Enter] to return to the main menu.";
}
 
 
#############################
# Install coreboot Firmware #
#############################
function flash_coreboot()
{
echo_green "\nStandalone Setup / coreboot firmware install"
echo_red "WARNING: This firmware is only valid for the Asus/HP ChromeBox.
Use on any other device will almost certainly brick it."
echo_yellow "Standard disclaimer: flashing the firmware has the potential to brick your ChromeBox, 
requiring relatively inexpensive hardware and some technical knowledge to recover. You have been warned."
 
read -p "Do you wish to continue? [y/N] "
[ "$REPLY" == "y" ] || return
 
#read existing firmware and try to extract MAC address info
echo_yellow "\nReading current firmware"
flashrom -r /tmp/bios.bin
if [ $? -ne 0 ]; then
    echo_red "Failure reading current firmware; cannot proceed."
    read -p "Press [Enter] to return to the main menu."
    return;
fi
#check if contains MAC address, extract
extract_vpd /tmp/bios.bin
if [ $? -ne 0 ]; then
    #need user to supply stock firmware file for VPD extract 
    read -p "
Your current firmware does not contain data for the device MAC address.  
Would you like to load it from a previously backed-up stock firmware file? [Y/n] "
    if [ "$REPLY" != "n" ]; then
        read -p "
Connect the USB/SD device which contains the backed-up stock firmware and press [Enter] to continue. "
         
        list_usb_devices
        [ $? -eq 0 ] || die "No USB devices available to read firmware backup."
        read -p "Enter the number for the device which contains the stock firmware backup: " usb_dev_index
        [ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || die "Error: Invalid option selected."
        usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"
        mkdir /tmp/usb > /dev/null 2>&1
        mount "${usb_device}" /tmp/usb > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            mount "${usb_device}1" /tmp/usb
        fi
        if [ $? -ne 0 ]; then
            echo_red "USB device failed to mount; cannot proceed."
            read -p "Press [Enter] to return to the main menu."
            return
        fi
        #extract MAC from user-supplied stock firmware
        extract_vpd /tmp/usb/stock-firmware.rom
        if [ $? -ne 0 ]; then
            #unable to extract from stock firmware backup
            echo_red "Failure reading stock firmware backup; cannot proceed."
            read -p "Press [Enter] to return to the main menu."
            return
        fi
    else
        #TODO - user enter MAC manually?
        echo_red "Skipping setting of MAC address."
    fi
 
fi
 
#check if existing firmware is stock
grep -obUa "vboot" /tmp/bios.bin >/dev/null
if [ $? -eq 0 ]; then
    echo ""
    read -p "Create a backup copy of your stock firmware? [Y/n]
 
This is highly recommended in case you wish to return the ChromeBox to the stock configuration/run ChromeOS, 
or in the (unlikely) event that things go south and you need to recover using an external EEPROM programmer. "
    [ "$REPLY" == "n" ] || backup_firmware
fi
 
echo ""
 
#download firmware file
cd /tmp
echo_yellow "Downloading coreboot firmware"
curl -L -O "${dropbox_url}${coreboot_file}"
curl -L -O "${dropbox_url}${coreboot_file}.md5"
#verify checksum on downloaded file
md5sum -c ${coreboot_file}.md5 --quiet > /dev/null 2>&1
if [ $? -eq 0 ]; then
    #check if we have a VPD to restore
    if [ -f /tmp/vpd.bin ]; then
        get_cbfstool
        if [ $? -ne 0 ]; then
            echo_red "Unable to download cbfstool; MAC address will not be persisted"
        else
            /tmp/boot/util/cbfstool ${coreboot_file} add -n vpd.bin -f /tmp/vpd.bin -t raw
        fi     
    fi
    #flash coreboot firmware
    echo_green "\nInstalling custom coreboot firmware: ${coreboot_file}"
    flashrom -w "${coreboot_file}"
    if [ $? -eq 0 ]; then
        echo_green "\ncoreboot firmware successfully installed."
        echo_green "You may now create the OpenELEC install media, or reboot and install your OS of choice via USB/SD."
    else
        echo_red "An error occurred flashing the coreboot firmware. DO NOT REBOOT!"
    fi
else
    #download checksum fail
    echo_red "coreboot firmware download checksum fail; download corrupted, cannot flash."
fi 
#clean up
if [ -d /tmp/boot/util ]; then
    rm -rf /tmp/boot/util > /dev/null 2>&1
fi
umount /tmp/boot > /dev/null 2>&1 
 
read -p "Press [Enter] to return to the main menu."
}
 
 
########################
# Extract firmware VPD #
########################
function extract_vpd() 
{
#check params
if [ -z "$1" ] 
then
 die "Error: extract_vpd(): missing function parameter"
 read -p "Press [Enter] to return to the main menu."
 return 1
fi
firmware_file="$1"
#check if file contains MAC address
grep -obUa "ethernet_mac" ${firmware_file} >/dev/null
if [ $? -eq 0 ]; then
    #we have a MAC; determine if stock firmware (FMAP) or coreboot (CBFS)
    grep -obUa "vboot" ${firmware_file} >/dev/null
    if [ $? -eq 0 ]; then
        #stock firmware, extract w/dd
        extract_cmd="dd if=${firmware_file} bs=1 skip=$((0x00600000)) count=$((0x00004000)) of=/tmp/vpd.bin"
    else
        #coreboot firmware, extract w/cbfstool
        extract_cmd="/tmp/boot/util/cbfstool ${firmware_file} extract -n vpd.bin -f /tmp/vpd.bin"
        #make sure cbfstool exists
        get_cbfstool
        if [ $? -ne 0 ]; then
            return 1;
        fi
    fi
    #run extract command
    ${extract_cmd} >& /dev/null
    if [ $? -ne 0 ]; then
        echo_red "Failure extracting MAC address from current firmware."
        return 1
    else
        #VPD extracted successfully
        #debug
        #echo_yellow "\nExtracted VPD from ${firmware_file}"
        return 0
    fi
else
    #file doesn't contain VPD
    return 1
fi
}
 
################
# Get cbfstool #
################
function get_cbfstool()
{
if [ ! -x /tmp/boot/util/cbfstool ]; then
    #download cbfstool
    working_dir=`pwd`
    rootdev=`rootdev -d -s`
    boot_mounted=`mount | grep ${rootdev}12`
    if [ "${boot_mounted}" == "" ]; then
        #mount boot
        mkdir /tmp/boot >/dev/null 2>&1
        mount `rootdev -d -s`12 /tmp/boot
        if [ $? -ne 0 ]; then
            echo_red "Error mounting boot partition; cannot proceed."
            return 1
        fi
    fi
    #create util dir
    mkdir /tmp/boot/util 2>/dev/null
    cd /tmp/boot/util
    echo_yellow "\nDownloading cbfstool utility"
    curl -L -O ${dropbox_url}/cbfstool.tar.gz
    if [ $? -ne 0 ]; then
        echo_red "Error downloading cbfstool; cannot proceed."
        #restore working dir
        cd ${working_dir}
        return 1
    fi
    tar -zxf cbfstool.tar.gz --no-same-owner
    if [ $? -ne 0 ]; then
        echo_red "Error extracting cbfstool; cannot proceed."
        #restore working dir
        cd ${working_dir}
        return 1
    fi
    #set +x
    chmod +x cbfstool
    #restore working dir
    cd ${working_dir}
fi
return 0    
}
 
 
#########################
# Backup stock firmware #
#########################
function backup_firmware() 
{
echo -e ""
read -p "Connect the USB/SD device to store the firmware backup and press [Enter] to continue.  
This is non-destructive, but it is best to ensure no other USB/SD devices are connected. "
list_usb_devices
[ $? -eq 0 ] || die "No USB devices available to store firmware backup."
read -p "Enter the number for the device to be used for firmware backup: " usb_dev_index
[ $usb_dev_index -gt 0 ] && [ $usb_dev_index  -le $num_usb_devs ] || die "Error: Invalid option selected."
usb_device="/dev/sd${usb_devs[${usb_dev_index}-1]}"
mkdir /tmp/usb > /dev/null 2>&1
mount "${usb_device}" /tmp/usb > /dev/null 2>&1
if [ $? != 0 ]; then
    mount "${usb_device}1" /tmp/usb
fi
[ $? -eq 0 ] || backup_fail "USB backup device failed to mount; cannot proceed."
cp /tmp/bios.bin /tmp/usb/stock-firmware.rom
[ $? -eq 0 ] || backup_fail "Failure reading stock firmware for backup; cannot proceed."
umount /tmp/usb > /dev/null 2>&1
rmdir /tmp/usb
echo_green "\nFirmware backup complete"
}
 
function backup_fail()
{
umount /tmp/usb > /dev/null 2>&1
rmdir /tmp/usb
die "$@"
}
 
 
####################
# Set Boot Options #
####################
function set_boot_options() 
{
# set boot options via firmware boot flags
# ensure hardware write protect disabled
if [[ "`crossystem | grep wpsw_cur`" == *"0"* ]]; then
 
    if [[ "`crossystem | grep dev_boot_usb`" != *"1"* ]]; then
        echo_red "\nDual-boot setup not completed; cannot set boot options."
        read -p "Press [Enter] to return to the main menu."
        return;
    fi
 
    echo_green "\nSelect your preferred boot delay and default boot option.
You can always override the default using [CTRL-D] or [CTRL-L]"
    echo_yellow "Note: these options are not relevant for a standalone setup, and should
only be set AFTER completing the 2nd stage of a dual-boot setup.  It's strongly
recommended that you test your dual boot setup before setting these boot options."
    echo -e "1) Short boot delay (1s) + OpenELEC/Ubuntu default
2) Long boot delay (30s) + OpenELEC/Ubuntu default
3) Short boot delay (1s) + ChromeOS default
4) Long boot delay (30s) + ChromeOS default
5) Cancel/exit
"
    while :
    do
        read n
        case $n in
            1) set_gbb_flags.sh 0x489; echo_green "\nBoot options successfully set."; break;;
            2) set_gbb_flags.sh 0x488; echo_green "\nBoot options successfully set."; break;;
            3) set_gbb_flags.sh 0x1; echo_green "\nBoot options successfully set."; break;;
            4) set_gbb_flags.sh 0x0; echo_green "\nBoot options successfully set."; break;;
            5) break;;
            *) invalid option;;
        esac
    done
    flash_legacy
else
    echo_red "\nWrite-protect enabled, non-stock firmware installed, or not running ChromeOS; cannot set boot options."
fi
read -p "Press [Enter] to return to the main menu."
}
 
##########################
# Install OE (dual boot) #
##########################
function chrOpenELEC() 
{
echo_green "\nOpenELEC / Dual Boot Install"
 
target_disk="`rootdev -d -s`"
# Do partitioning (if we haven't already)
ckern_size="`cgpt show -i 6 -n -s -q ${target_disk}`"
croot_size="`cgpt show -i 7 -n -s -q ${target_disk}`"
state_size="`cgpt show -i 1 -n -s -q ${target_disk}`"
 
max_openelec_size=$(($state_size/1024/1024/2))
rec_openelec_size=$(($max_openelec_size - 1))
# If KERN-C and ROOT-C are one, we partition, otherwise assume they're what they need to be...
if [ "$ckern_size" =  "1" -o "$croot_size" = "1" ]; then
    echo_green "Stage 1: Repartitioning the internal HDD"
     
    # prevent user from booting into legacy until install complete
    crossystem dev_boot_usb=0 dev_boot_legacy=0 > /dev/null 2>&1
     
    while :
    do
        echo "Enter the size in GB you want to reserve for OpenELEC Storage."
        read -p "Acceptable range is 1 to $max_openelec_size but $rec_openelec_size is the recommended maximum: " openelec_size
        if [ ! $openelec_size -ne 0 2>/dev/null ]; then
            echo_red "\n\nWhole numbers only please...\n\n"
            continue
        fi
        if [ $openelec_size -lt 1 -o $openelec_size -gt $max_openelec_size ]; then
            echo_red "\n\nThat number is out of range. Enter a number 1 through $max_openelec_size\n\n"
            continue
        fi
        break
    done
    # We've got our size in GB for ROOT-C so do the math...
 
    #calculate sector size for rootc
    rootc_size=$(($openelec_size*1024*1024*2))
 
    #kernc is always 250mb
    kernc_size=512000
 
    #new stateful size with rootc and kernc subtracted from original
    stateful_size=$(($state_size - $rootc_size - $kernc_size))
 
    #start stateful at the same spot it currently starts at
    stateful_start="`cgpt show -i 1 -n -b -q ${target_disk}`"
 
    #start kernc at stateful start plus stateful size
    kernc_start=$(($stateful_start + $stateful_size))
 
    #start rootc at kernc start plus kernc size
    rootc_start=$(($kernc_start + $kernc_size))
 
    #Do the real work
 
    echo_yellow "\n\nModifying partition table to make room for OpenELEC."
    umount -f /mnt/stateful_partition > /dev/null 2>&1
 
    # stateful first
    cgpt add -i 1 -b $stateful_start -s $stateful_size -l STATE ${target_disk}
 
    # now kernc
    cgpt add -i 6 -b $kernc_start -s $kernc_size -l KERN-C -t "kernel" ${target_disk}
 
    # finally rootc
    cgpt add -i 7 -b $rootc_start -s $rootc_size -l ROOT-C ${target_disk}
 
    echo_green "Stage 1 complete; after reboot ChromeOS will \"repair\" itself.
Then re-download/re-run this script to complete OpenELEC setup."
 
    read -p "Press [Enter] to reboot..."
    reboot
    exit
fi
 
echo_green "Stage 1 / repartitioning completed, moving on."
echo_green "\nStage 2: Installing OpenELEC"
 
#target partitions
target_rootfs="${target_disk}7"
target_kern="${target_disk}6"
 
if mount|grep ${target_rootfs}
then
  echo_red "Refusing to continue since ${target_rootfs} is formatted and mounted. Try rebooting"
  exit
fi
 
#format partitions, disable journaling, set labels
mkfs.ext4 -v -m0 -O ^has_journal -L KERN-C ${target_kern} > /dev/null
if [ $? -ne 0 ]; then
    OE_install_error "Failed to format OE partition(s); reboot and try again"
fi
mkfs.ext4 -v -m0 -O ^has_journal -L ROOT-C ${target_rootfs} > /dev/null
if [ $? -ne 0 ]; then
    OE_install_error "Failed to format OE partition(s); reboot and try again"
fi
  
#mount partitions
if [ ! -d /tmp/System ]
then
  mkdir /tmp/System
fi
mount -t ext4 ${target_kern} /tmp/System > /dev/null 2>&1
if [ $? -ne 0 ]; then
    OE_install_error "Failed to mount OE System partition; reboot and try again"
fi
 
if [ ! -d /tmp/Storage ]
then
  mkdir /tmp/Storage
fi
mount -t ext4 ${target_rootfs} /tmp/Storage > /dev/null
if [ $? -ne 0 ]; then
    OE_install_error "Failed to format OE Storage partition; reboot and try again"
fi
 
echo_green "\nPartitions formatted and mounted"
 
#get/extract syslinux
tar_file="${dropbox_url}syslinux-5.10-md.tar.bz2"
wget -O /tmp/Storage/syslinux.tar.bz2 $tar_file 
if [ $? -ne 0 ]; then
    OE_install_error "Failed to download syslinux; check your Internet connection and try again"
fi
cd /tmp/Storage
tar -xpjf syslinux.tar.bz2
if [ $? -ne 0 ]; then
    OE_install_error "Failed to extract syslinux download; reboot and try again"
fi
 
 
#install extlinux on OpenELEC kernel partition
cd /tmp/Storage/syslinux-5.10/extlinux/
./extlinux -i /tmp/System/
if [ $? -ne 0 ]; then
    OE_install_error "Failed to install extlinux; reboot and try again"
fi
 
#create extlinux.conf
echo -e "DEFAULT linux\nPROMPT 0\nLABEL linux\nKERNEL /KERNEL\nAPPEND boot=LABEL=KERN-C disk=LABEL=ROOT-C quiet ssh" > /tmp/System/extlinux.conf
 
 
#Upgrade/modify existing syslinux install
#mount boot partition sda12
if [ ! -d /tmp/boot ]
then
  mkdir /tmp/boot
fi
mount /dev/sda12 /tmp/boot > /dev/null
if [ $? -ne 0 ]; then
    OE_install_error "Failed to mount boot partition; reboot and try again"
fi
 
#create syslinux.cfg
 
rm -f /tmp/boot/syslinux/syslinux.cfg 2>/dev/null
#UUID=`cgpt find -l KERN-C -v | grep 'UUID:' | sed s/UUID://g | sed "s/^[ \t]*//"`
echo -e "DEFAULT openelec\nPROMPT 0\nLABEL openelec\nCOM32 chain.c32\nAPPEND label=KERN-C" > /tmp/boot/syslinux/syslinux.cfg
 
#copy chain loader files
cp /tmp/Storage/syslinux-5.10/com32/chain/chain.c32 /tmp/boot/syslinux/chain.c32
cp /tmp/Storage/syslinux-5.10/com32/lib/libcom32.c32 /tmp/boot/syslinux/libcom32.c32
cp /tmp/Storage/syslinux-5.10/com32/libutil/libutil.c32 /tmp/boot/syslinux/libutil.c32
 
#install/update syslinux
cd /tmp/Storage/syslinux-5.10/linux/
rm -f /tmp/boot/ldlinux.* 1>/dev/null 2>&1
./syslinux -i -f /dev/sda12 -d syslinux
if [ $? -ne 0 ]; then
    OE_install_error "Failed to install syslinux; reboot and try again"
fi
 
echo_green "\nSyslinux bootloader downloaded and installed"
 
#unmount boot partition
umount /tmp/boot 1>/dev/null 2>&1
 
#get OpenELEC
tar_file="${OE_version}.tar"
tar_url="${OE_url}${tar_file}"
cd /tmp/Storage
wget $tar_url
if [ $? -ne 0 ]; then
    echo_yellow "Failed to download OE; trying dropbox mirror"
    tar_url="${dropbox_url}${tar_file}"
    wget $tar_url
    if [ $? -ne 0 ]; then
        OE_install_error "Failed to download OpenELEC; check your Internet connection and try again"
    fi
fi
echo_green "OpenELEC download complete; extracting..."
tar -xpf $tar_file
if [ $? -ne 0 ]; then
    OE_install_error "Failed to extract OpenELEC download; check your Internet connection and try again"
fi
 
#install
cp /tmp/Storage/${OE_version}/target/KERNEL /tmp/System/
cp /tmp/Storage/${OE_version}/target/SYSTEM /tmp/System/
 
#sanity check file sizes
[ -s /tmp/System/KERNEL ] || OE_install_error "OE KERNEL has file size 0"
[ -s /tmp/System/SYSTEM ] || OE_install_error "OE SYSTEM has file size 0"
 
#clean up
cd ~
umount /tmp/Storage > /dev/null 2>&1
umount /tmp/System > /dev/null 2>&1
rm -rf /tmp/Storage > /dev/null 2>&1
rm -rf /tmp/System > /dev/null 2>&1
 
#run device prep / update legacy BIOS
device_prep
 
echo_green "OpenELEC Installation Complete"
read -p "Press [Enter] to return to the main menu."
}
 
function OE_install_error()
{
cd ~
umount /tmp/boot > /dev/null 2>&1
umount /tmp/Storage > /dev/null 2>&1
umount /tmp/System > /dev/null 2>&1
rm -rf /tmp/boot > /dev/null 2>&1
rm -rf /tmp/Storage > /dev/null 2>&1
rm -rf /tmp/System > /dev/null 2>&1
die "Error: $@"
 
}
 
##############################
# Install Ubuntu (dual boot) #
##############################
function chrUbuntu() 
{
echo_green "\nUbuntu / Dual Boot Install"
echo_green "Using ChrUbuntu install script (c) Jay Lee\nhttp://chromeos-cr48.blogspot.com/"
 
target_disk="`rootdev -d -s`"
# Do partitioning (if we haven't already)
ckern_size="`cgpt show -i 6 -n -s -q ${target_disk}`"
croot_size="`cgpt show -i 7 -n -s -q ${target_disk}`"
state_size="`cgpt show -i 1 -n -s -q ${target_disk}`"
 
max_ubuntu_size=$(($state_size/1024/1024/2))
rec_ubuntu_size=$(($max_ubuntu_size - 1))
# If KERN-C and ROOT-C are one, we partition, otherwise assume they're what they need to be...
if [ "$ckern_size" =  "1" -o "$croot_size" = "1" ]; then
    echo_green "Stage 1: Repartitioning the internal HDD"
     
    # prevent user from booting into legacy until install complete
    crossystem dev_boot_usb=0 dev_boot_legacy=0 > /dev/null 2>&1
     
    while :
    do
        echo "Enter the size in GB you want to reserve for Ubuntu."
        read -p "Acceptable range is 5 to $max_ubuntu_size  but $rec_ubuntu_size is the recommended maximum: " ubuntu_size
        if [ ! $ubuntu_size -ne 0 2>/dev/null ]; then
            echo_red "\n\nWhole numbers only please...\n\n"
            continue
        fi
        if [ $ubuntu_size -lt 5 -o $ubuntu_size -gt $max_ubuntu_size ]; then
            echo_red "\n\nThat number is out of range. Enter a number 5 through $max_ubuntu_size\n\n"
            continue
        fi
        break
    done
    # We've got our size in GB for ROOT-C so do the math...
 
    #calculate sector size for rootc
    rootc_size=$(($ubuntu_size*1024*1024*2))
 
    #kernc is always 16mb
    kernc_size=32768
 
    #new stateful size with rootc and kernc subtracted from original
    stateful_size=$(($state_size - $rootc_size - $kernc_size))
 
    #start stateful at the same spot it currently starts at
    stateful_start="`cgpt show -i 1 -n -b -q ${target_disk}`"
 
    #start kernc at stateful start plus stateful size
    kernc_start=$(($stateful_start + $stateful_size))
 
    #start rootc at kernc start plus kernc size
    rootc_start=$(($kernc_start + $kernc_size))
 
    #Do the real work
 
    echo_green "\n\nModifying partition table to make room for Ubuntu."
 
    umount -f /mnt/stateful_partition > /dev/null 2>&1
 
    # stateful first
    cgpt add -i 1 -b $stateful_start -s $stateful_size -l STATE ${target_disk}
 
    # now kernc
    cgpt add -i 6 -b $kernc_start -s $kernc_size -l KERN-C -t "kernel" ${target_disk}
 
    # finally rootc
    cgpt add -i 7 -b $rootc_start -s $rootc_size -l ROOT-C ${target_disk}
     
    echo_green "Stage 1 complete; after reboot ChromeOS will \"repair\" itself.
Then re-download/re-run this script to complete Ubuntu setup."
    read -p "Press [Enter] to reboot and continue..."
 
    reboot
    exit
fi
echo_yellow "Stage 1 / repartitioning completed, moving on."
echo_green "Stage 2: Installing Ubuntu"
 
#init vars
ubuntu_metapackage="ubuntu-desktop"
ubuntu_version="latest"
ubuntu_arch="amd64"
 
#select Ubuntu metapackage
echo -e "Enter the Ubuntu metapackage to install (eg, xubuntu-desktop).
Valid options are [ubuntu-desktop kubuntu-desktop lubuntu-desktop xubuntu-desktop edubuntu-desktop ubuntu-standard]"
read -p "If no metapackage entered, ubuntu-desktop will be used. " ubuntu_metapackage   
 
if [ "$ubuntu_metapackage" == "" ]; then
    ubuntu_metapackage="ubuntu-desktop"
fi
 
if [ "$ubuntu_version" = "lts" ]
then
  ubuntu_version=`wget --quiet -O - http://changelogs.ubuntu.com/meta-release | grep "^Version:" | grep "LTS" | tail -1 | sed -r 's/^Version: ([^ ]+)( LTS)?$/\1/'`
  tar_file="http://cdimage.ubuntu.com/ubuntu-core/releases/$ubuntu_version/release/ubuntu-core-$ubuntu_version-core-$ubuntu_arch.tar.gz"
elif [ "$ubuntu_version" = "latest" ]
then
  ubuntu_version=`wget --quiet -O - http://changelogs.ubuntu.com/meta-release | grep "^Version: " | tail -1 | sed -r 's/^Version: ([^ ]+)( LTS)?$/\1/'`
  tar_file="http://cdimage.ubuntu.com/ubuntu-core/releases/$ubuntu_version/release/ubuntu-core-$ubuntu_version-core-$ubuntu_arch.tar.gz"
elif [ $ubuntu_version = "dev" ]
then
  ubuntu_version=`wget --quiet -O - http://changelogs.ubuntu.com/meta-release-development | grep "^Version: " | tail -1 | sed -r 's/^Version: ([^ ]+)( LTS)?$/\1/'`
  ubuntu_animal=`wget --quiet -O - http://changelogs.ubuntu.com/meta-release-development | grep "^Dist: " | tail -1 | sed -r 's/^Dist: (.*)$/\1/'`
  tar_file="http://cdimage.ubuntu.com/ubuntu-core/daily/current/$ubuntu_animal-core-$ubuntu_arch.tar.gz"
else
  tar_file="http://cdimage.ubuntu.com/ubuntu-core/releases/$ubuntu_version/release/ubuntu-core-$ubuntu_version-core-$ubuntu_arch.tar.gz"
fi
 
echo_green "\nInstalling Ubuntu ${ubuntu_version} with metapackage ${ubuntu_metapackage}\nThis is going to take some time."
 
read -p "Press [Enter] to continue..."
 
#set target partitions
target_rootfs="${target_disk}7"
target_kern="${target_disk}6"
 
if mount|grep ${target_rootfs}
then
  echo_red "Refusing to continue since ${target_rootfs} is formatted and mounted. Try rebooting"
  exit
fi
 
mkfs.ext4 ${target_rootfs}
 
if [ ! -d /tmp/urfs ]
then
  mkdir /tmp/urfs
fi
mount -t ext4 ${target_rootfs} /tmp/urfs
 
wget -O - $tar_file | tar xzvvp -C /tmp/urfs/
 
mount -o bind /proc /tmp/urfs/proc
mount -o bind /dev /tmp/urfs/dev
mount -o bind /dev/pts /tmp/urfs/dev/pts
mount -o bind /sys /tmp/urfs/sys
 
if [ -f /usr/bin/old_bins/cgpt ]
then
  cp /usr/bin/old_bins/cgpt /tmp/urfs/usr/bin/
else
  cp /usr/bin/cgpt /tmp/urfs/usr/bin/
fi
 
chmod a+rx /tmp/urfs/usr/bin/cgpt
cp /etc/resolv.conf /tmp/urfs/etc/
echo chrubuntu > /tmp/urfs/etc/hostname
echo -e "\n127.0.1.1       chrubuntu" >> /tmp/urfs/etc/hosts
 
cr_install="wget -q -O - https://dl-ssl.google.com/linux/linux_signing_key.pub | sudo apt-key add -
add-apt-repository \"deb http://dl.google.com/linux/chrome/deb/ stable main\"
apt-get update
apt-get -y install google-chrome-stable"
 
echo -e "export DEBIAN_FRONTEND=noninteractive
apt-get -y update
apt-get -y dist-upgrade
apt-get -y install ubuntu-minimal
apt-get -y install wget
apt-get -y install software-properties-common
add-apt-repository main
add-apt-repository universe
add-apt-repository restricted
add-apt-repository multiverse 
apt-get update
apt-get -y install $ubuntu_metapackage
$cr_install
apt-get -y install linux-generic
apt-get -y install grub-pc
grub-mkconfig -o /boot/grub/grub.cfg
grub-install ${target_disk} --force
mykern=\`ls /boot/vmlinuz-* | grep -oP \"[0-9].*\" | sort -rV | head -1\`
wget http://goo.gl/kz917j
bash kz917j \$mykern
rm kz917j
useradd -m user -s /bin/bash
echo user | echo user:user | chpasswd
adduser user adm
adduser user sudo
if [ -f /usr/lib/lightdm/lightdm-set-defaults ]
then
  /usr/lib/lightdm/lightdm-set-defaults --autologin user
fi
#update kernel
wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.14.1-trusty/linux-headers-3.14.1-031401_3.14.1-031401.201404141220_all.deb
wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.14.1-trusty/linux-headers-3.14.1-031401-generic_3.14.1-031401.201404141220_amd64.deb
wget http://kernel.ubuntu.com/~kernel-ppa/mainline/v3.14.1-trusty/linux-image-3.14.1-031401-generic_3.14.1-031401.201404141220_amd64.deb
dpkg -i linux-headers-3.14.1-*.deb linux-image-3.14.1-*.deb
#install MCE fix
apt-add-repository ppa:tikhonov/fixes -y
apt-get update
apt-get -y install mceusb-dkms
#install XBMC
apt-get -y install python-software-properties pkg-config
apt-get -y install software-properties-common
add-apt-repository ppa:team-xbmc/ppa -y
apt-get update
apt-get -y install xbmc
" > /tmp/urfs/install-ubuntu.sh
 
chmod a+x /tmp/urfs/install-ubuntu.sh
chroot /tmp/urfs /bin/bash -c /install-ubuntu.sh
#rm /tmp/urfs/install-ubuntu.sh
 
echo -e "Section \"InputClass\"
    Identifier      \"touchpad peppy cyapa\"
    MatchIsTouchpad \"on\"
    MatchDevicePath \"/dev/input/event*\"
    MatchProduct    \"cyapa\"
    Option          \"FingerLow\" \"10\"
    Option          \"FingerHigh\" \"10\"
EndSection" > /tmp/urfs/usr/share/X11/xorg.conf.d/50-cros-touchpad.conf
 
echo -e "Section \"Device\"
    Identifier      \"Intel Graphics\"
    Driver          \"intel\"
    Option         \"TearFree\"    \"true\"
EndSection" > /tmp/urfs/usr/share/X11/xorg.conf.d/20-intel.conf
 
#run device prep / update legacy BIOS
device_prep
 
echo_green "
Ubuntu Installation is complete! On reboot at the dev mode screen, you can press
[CTRL+L] to boot Ubuntu or [CTRL+D] to boot Chrome OS. The Ubuntu login is:
 
Username:  user
Password:  user
"
 
read -p "Press [Enter] to return to the main menu."
}
 
#############
# Main Menu #
#############
function main_menu() {
    NORMAL=`echo "\033[m"`
    MENU=`echo "\033[36m"` #Blue
    NUMBER=`echo "\033[33m"` #yellow
    FGRED=`echo "\033[41m"`
    RED_TEXT=`echo "\033[31m"`
    ENTER_LINE=`echo "\033[33m"`
    clear
    echo -e "${NORMAL}\n ChromeBox E-Z Setup v${script_version} ${NORMAL}"
    echo -e "${NORMAL} (c) 2014 Matt DeVillier <matt.devillier@gmail.com>\n ${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${MENU}**${NORMAL}    Dual Boot ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 1)${MENU} Setup: ChromeOS + OpenELEC ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 2)${MENU} Setup: ChromeOS + Ubuntu ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 3)${MENU} Set Boot Options ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 4)${MENU} Update Legacy BIOS ${NORMAL}"
    echo -e "${MENU}**${NORMAL}    Standalone ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 5)${MENU} Setup: coreboot firmware install/update ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 6)${MENU} Create OpenELEC USB/SD Installer ${NORMAL}"
    echo -e "${MENU}** ${NORMAL}"
    echo -e "${MENU}**${NUMBER} 7)${NORMAL} Reboot ${NORMAL}"
    echo -e "${MENU}*********************************************${NORMAL}"
    echo -e "${ENTER_LINE}Select a menu option or ${RED_TEXT}q to quit${NORMAL}"
    read opt
}
 
# Must run as root 
[ $(whoami) == "root" ] || die "You need to run this script as root; use 'sudo bash <script name>'"
 
#ensure running under ChromeOS/ChromiumOS
which fmap_decode > /dev/null 2>&1
if [ $? -ne 0 ]; then
    die "You must run this script from either ChromeOS or ChromiumOS"
fi
 
#disable power mgmt
powerd_status="`initctl status powerd`"
if [ ! "$powerd_status" = "powerd stop/waiting" ]; then
    initctl stop powerd
fi
 
clear
#show main menu
main_menu
while [ opt != '' ]
    do
    if [[ $opt = "q" ]]; then
            exit;
    else
        case $opt in
 
        1)  chrOpenELEC;
            main_menu;
            ;;
        2)  chrUbuntu;
            main_menu;
            ;;
        3)  set_boot_options;
            main_menu;
            ;;
        4)  update_legacy;  
            main_menu;
            ;;
        5)  flash_coreboot;
            main_menu;
            ;;      
        6)  create_oe_install_media;
            main_menu;
            ;;              
        7)  echo -e "\nRebooting...\n";
            reboot;
            exit;
            ;;
        #8)  list_usb_devices;
        #   read -p "Press [Enter] to return to the main menu.";
        #   main_menu;
        #   ;;
        q)  exit;
            ;;
        \n) exit;
            ;;
        *)  clear;
            option_picked "Pick an option from the menu";
            main_menu;
            ;;
    esac
fi
done
