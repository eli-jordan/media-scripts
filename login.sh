#!/bin/bash

# This file contains commands run at login. It is referenced
# in an automator application that is added to login items.

source ~/scripts/functions.sh

function main
{
   nohup ~/scripts/run_remounter.sh &
   
   echo "Starting SAB"
   startSABnzbd

   #echo "Starting SickBeard"
   #startSickBeard

   echo "Starting SickRage"
   startSickRage

   echo "Starting CouchPotato"
   startCouchPotato
   
   echo "Starting XBMC"
   startXBMC

   echo "Starting Marachino"
   startMaraschino

   #restartVPN
}

main >> ~/login.log 2>&1
