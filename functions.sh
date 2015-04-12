#!/bin/bash

# start SAB NZB downloader application
function startSABnzbd
{
   echo "Starting SABnzbd..."
   open /Applications/SABnzbd.app/
}

# open XBMC
function startXBMC
{
   echo "Starting XBMC..."
   open -a Kodi
}

# start SickBeard TV show downloader
function startSickBeard
{
   echo "Starting SickBeard..."
   python ~/SickBeardThePirateBay/SickBeard.py > /dev/null &
}

function startSickRage
{
  echo "Starting SickRage..."
  python ~/SickRage/SickBeard.py > /dev/null &
}

# start CouchPotato movie downloader
function startCouchPotato
{
   echo "Starting CouchPotato..."
   python ~/CouchPotato/CouchPotato.py --daemon
}

# start Headphones music downloader
function startHeadphones
{
   echo "Starting Headphones..."
   python ~/headphones/Headphones.py > /dev/null &
}

# start the maraschino dashboard
function startMaraschino
{
   echo "Starting Maraschino..."
   python ~/maraschino/Maraschino.py --port=7777 > /dev/null &
}

# start tyransmission
function startTransmission
{
  echo "Starting Transmission..."
  open -a Transmission
}

# how long to wait before attempting to mound the drive again
SLEEP_TIME=600 # 600s = 10mins

# Continuously loop and attempt to mount the media
# drive. This will remount the drive if for some 
# reason it is disconnected.
function startRemounter
{
    while true
    do
        echo "`date` attempting remount"
        osascript -e 'tell application "Finder" to mount volume "afp://admin@10.0.1.9/Media"'
        sleep $SLEEP_TIME
    done      
}

function restartVPN
{
   sleep 60
   local saved=$SUDO_ASKPASS
   export SUDO_ASKPASS="/Users/admin/scripts/password.sh"
   sudo -A serveradmin stop vpn
   sleep 5
   sudo -A serveradmin start vpn
   export SUDO_ASKPASS=$saved
}



