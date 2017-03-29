#!/bin/bash

WGET="/usr/local/bin/wget"

CP_HOST="localhost"
CP_PORT="5050"
CP_API_KEY="488686af46144736a7f32e5c84372be4"

# Run the couch potato renamer to move downloaded movies
#
# $1 - the option directory to scan. If not provided the directory 
#      configured in CouchPotato is used
# $2 - the file action to use i.e. move, link, copy
runCouchPotatoRenamer() {
   echo "=====+++++ Starting CouchPotato rename +++++====="

   local savedAction="`getCurrentFileAction`"

   # if an action was specified, then set it 
   if [ ! -z "$2" ]
   then
      echo "Setting CouchPotato file process action to $2"
      $WGET "http://$CP_HOST:$CP_PORT/api/$CP_API_KEY/settings.save/?section=renamer&name=default_file_action&value=$2" -O /dev/null
   fi

   if [ ! -z "$1" ]
   then
      echo "`date` -- Running couch potato renamer in specified directory $1"
      echo "URL = http://$CP_HOST:$CP_PORT/api/$CP_API_KEY/renamer.scan?media_folder=$1"
      $WGET "http://$CP_HOST:$CP_PORT/api/$CP_API_KEY/renamer.scan?media_folder=$1"
   else
      echo "`date` -- Running couch potato renamer in the default directory"
      /usr/local/bin/wget "http://$CP_HOST:$CP_PORT/api/$CP_API_KEY/renamer.scan/" -O /dev/null
   fi

   # if an action was specified, then reset it to its previous value
   if [ ! -z "$2" ]
   then
      echo "Resetting CouchPotato file process action to $savedAction"
      $WGET "http://$CP_HOST:$CP_PORT/api/$CP_API_KEY/settings.save/?section=renamer&name=default_file_action&value=$savedAction" -O /dev/null
   fi

   echo "=====+++++ Finished CouchPotato rename +++++====="
}

# gets the current config for the default_file_action
# used by the renamer
getCurrentFileAction() {
   local settingConf="/Users/admin/Library/Application Support/CouchPotato/settings.conf"
   cat "$settingConf" | grep default_file_action | cut -d'=' -f2 | sed -e 's/ //g'
}

main() {
   local dir="$1"
   echo "Running couch potato renamer in $dir"

   find "$dir" -type f -name '*rename*ignore*' | xargs rm -f 

   runCouchPotatoRenamer "$dir" "copy"
}

main $@ >> /Users/admin/scripts/couchpotato_renamer_service.log