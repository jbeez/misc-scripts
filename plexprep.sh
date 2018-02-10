#!/bin/bash
# Setup Script for PHT on Ubuntu Server 14.04.1
# asus chromebox M004U with amazon fire tv remote
#jtbright 05.09.2014
# v1.1
 
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi
 
echo "Adding Repos"
#Add Repos for plexht and deps
add-apt-repository -y ppa:plexapp/plexht >/dev/null 2>&1
add-apt-repository -y ppa:jon-severinsson/ffmpeg >/dev/null 2>&1
add-apt-repository -y ppa:pulse-eight/libcec>/dev/null 2>&1
apt-get -qq update
 
#Install all our packages so we can start configurations
echo "installing packages for plex"
apt-get -qq install plexhometheater bluez python-gobject python-dbus xinit libva-intel-vaapi-driver >/dev/null 2>&1
 
####
##Edit existing config files and write out some new ones now that packages are installed
####
echo "fixing stock config files for ssd trim and grub splash screen"
sed -i 's/errors=remount-ro 0/errors=remount-ro,discard 0/g' /etc/fstab
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"/g' /etc/default/grub
sed -i 's/GRUB_TIMEOUT=2/GRUB_TIMEOUT=0/g' /etc/default/grub
echo GRUB_BACKGROUND=/opt/plexhometheater/share/XBMC/media/Splash.png >>/etc/default/grub
echo GRUB_GFXPAYLOAD_LINUX=keep >>/etc/default/grub
update-grub >/dev/null 2>&1
 
    if [ ! -d /lib/plymouth/themes/plex ]; then
        mkdir -p /lib/plymouth/themes/plex
    fi
 
    if [ ! -h /lib/plymouth/themes/plex/plex.png ]; then
        ln -s /opt/plexhometheater/share/XBMC/media/Splash.png /lib/plymouth/themes/plex/plex.png
    fi
 
(cat <<- '_EOF_'
[Plymouth Theme]
Name=Plex Logo
Description=A theme that features a blank background with a logo.
ModuleName=script
 
[script]
ImageDir=/lib/plymouth/themes/plex
ScriptFile=/lib/plymouth/themes/plex/plex.script
_EOF_
) > /lib/plymouth/themes/plex/plex.plymouth
 
(cat <<- '_EOF_'
wallpaper_image = Image("plex.png");
screen_width = Window.GetWidth();
screen_height = Window.GetHeight();
resized_wallpaper_image = wallpaper_image.Scale(screen_width,screen_height);
wallpaper_sprite = Sprite(resized_wallpaper_image);
wallpaper_sprite.SetZ(-100);
_EOF_
) > /lib/plymouth/themes/plex/plex.script
 
#Enable Plex Splashscreen
update-alternatives --quiet --install /lib/plymouth/themes/default.plymouth default.plymouth /lib/plymouth/themes/plex/plex.plymouth 100
update-initramfs -u >/dev/null 2>&1
 
###
#bluetooth remote adding code
###
#would like to store hcitool output in array and label the choices a/b/c or 1/2/3 
#and let users type a single letter/number to answer for their choice
clear
echo -e "Press and hold the home button on your Amazon Fire remote"
echo
sleep 6
echo -n "Now press enter to scan for your remote"
read
###
IFS=$'\n';
 
scantool=($(hcitool scan |grep \:))
skipoption=("           FF:FF:FF:FF:FF:FF       The option to skip.")
themacs=("${scantool[@]}" "${skipoption[@]}")
 
PS3="Which device do you want to pair? "
 
unset bt
        while [[ ! ${bt} =~ ^([0-9A-Fa-f]{2}[:]){5}[0-9A-Fa-f]{2}$ ]]; do
        select mac in "${themacs[@]}"; do echo "You've selected ${mac}"; break; done
        bt=($(echo $mac | awk '{print $1;}'))
        done
unset IFS
###
bluez-simple-agent hci0 $bt >/dev/null 2>&1
bluez-test-device trusted $bt yes >/dev/null 2>&1
bluez-test-input connect $bt >/dev/null 2>&1
##
#END Bluetooth Add Section
##
 
##
#Write /etc/init/plexhometheater.conf
##
 
(cat <<- '_EOF_'
# plexhometheater - Plex Home Theater
description "Plex Home Theater"
start on starting tty1 and net-device-up IFACE!=lo
stop on starting rc RUNLEVEL=[016]
respawn
 
# What to execute
script
    if [ -r /etc/default/plexhometheater ]; then
        . /etc/default/plexhometheater
    fi
    start-stop-daemon --start -c $RUN_AS --exec $DAEMON -- $DAEMON_OPTS
end script
_EOF_
) > /etc/init/plexhometheater.conf
 
##
#Write /etc/default/plexhometheater
##
 
(cat <<- '_EOF_'
export XBMC_HOME=/opt/plexhometheater/share/XBMC
export DISPLAY=:0.0
export DAEMON=/usr/bin/X11/xinit
export DAEMON_OPTS="/opt/plexhometheater/bin/plexhometheater --standalone -- :0 -nocursor -bs -nolisten tcp"
export RUN_AS=root
_EOF_
) > /etc/default/plexhometheater
 
initctl reload-configuration
echo "All Finished, you should now restart your server to test a clean bootup."
