#!/bin/bash

# This file contains commands run at login. It is referenced
# in an automator application that is added to login items.

source ~/scripts/functions.sh

function main
{
   nohup ~/scripts/run_remounter.sh &

   startSABnzbd

   startTransmission

   startSickRage

   startCouchPotato

   startXBMC

   startMaraschino
}

main >> ~/login.log 2>&1
