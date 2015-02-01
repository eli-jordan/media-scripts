#!/bin/bash

# Where to log the progress of this script
export LOG_DIR=/Users/admin/scripts/

#############################
#### Transmission Stuff  ####
#############################

TRANSMISSION_REMOTE="/Users/admin/Transmission/bin/transmission-remote"
UNRAR="/usr/local/bin/unrar"
WGET="/usr/local/bin/wget"

source ./seeding_complete_cleanup.sh

# remove the torrent from transmission and delete the file
function removeAndDeleteCompleteTorrent
{
   echo "`date`: Removing complete torrent $TR_TORRENT_NAME and deleting associated file"
   $TRANSMISSION_REMOTE -t$TR_TORRENT_ID --remove-and-delete &
}

# remove the torrent from transmission
function removeCompleteTorrent
{
   echo "`date`: Removing complete torrent $TR_TORRENT_NAME"
   $TRANSMISSION_REMOTE -t$TR_TORRENT_ID --remove &
}

# Prints the seed ratio configured for the current torrent.
# Possible value are; Unlimited, Default, 1.00 (or some other numeric ratio)
function torrentSeedRatio
{
   $TRANSMISSION_REMOTE -t$TR_TORRENT_ID  -i | grep 'Ratio Limit' | cut -d':' -f2 | sed -e 's/ //'
}

# attempt to unpack a downloaded archive
# $1 - the parent directory e.g. $TR_TORRENT_DIR
# $2 - the child directory e.g. $TR_TORRENT_NAME
function unpack
{
   local parent=$1
   local name=$2

   cd "$parent"

   echo "`date`: Attempting to unpack torrent $name"
   
   # if the torrent name is a directory
   if [ -d "$name" ]
   then
      echo "`date`: $name is a directory"

      # handle RAR files
      if ls -R "$name"/*.rar > /dev/null 2>&1
      then
         find "$name" -iname "*.rar" | while read file
         do
            echo "`date`: Extracting RAR archive $file"
            $UNRAR x -inul "$file"
         done
      # handle ZIP files
      elif ls -R "$name"/*.zip > /dev/null 2>&1
      then
         find "$name" -iname "*.zip" | while read file
         do
            echo "`date`: Extracting ZIP archive $file"
            unzip "$file"
         done
      fi
   # if the torrent name is a file
   elif [ -f "$name" ]
   then
      echo "`date`: $name is a file"
      
      if [ ${name: -4} == ".rar" ]
      then
         echo "`date`: Extracting RAR archive $name"
         $UNRAR x -inul "$name"
      elif [ ${name: -4} == ".zip" ]
      then
         echo "`date`: Extracting ZIP archive $name"
         unzip "$name"   
      fi
   fi
}

###################################################
#                                                 #
#            CouchPotato Processing               #
#                                                 #
###################################################

CP_HOST="localhost"
CP_PORT="5050"
CP_API_KEY="5655d18f80c04c61ad88530e8cb23df5"

COUCHPOTATO_SEEDED_HOLDING_DIR="/Users/admin/Downloads/TorrentDownloads/Movies_CouchPotato_Seeding"
COUCHPOTATO_DOWNLOAD_DIR="/Users/admin/Downloads/TorrentDownloads/Movies_CouchPotato"
COUCHPOTATO_RENAME_TMP_DIR="/Users/admin/Downloads/TorrentDownloads/Movies_CouchPotato_TmpRename"

# Process a couch potato download that needs to keep seeding
function processCouchPotatoSeeded
{
   # move the torrent to a seeding directory, using transmission-remote
   local torrentDir="$COUCHPOTATO_SEEDED_HOLDING_DIR/$TR_TORRENT_NAME.seeding"
   mkdir "$torrentDir"
   $TRANSMISSION_REMOTE -t$TR_TORRENT_ID --move "$torrentDir"

   # the torrent gets paused when a move is performed, so ensure it is started
   $TRANSMISSION_REMOTE -t$TR_TORRENT_ID --start

   # unpack any archives that may be in the torrent
   unpack "$torrentDir" "$TR_TORRENT_NAME"

   # run the renamer
   runCouchPotatoRenamer "$torrentDir" "link"
}

# Process a couch potato download that does not need to keep seeding
function processCouchPotatoNonSeeded
{
   unpack "$TR_TORRENT_DIR" "$TR_TORRENT_NAME"
   mkdir "$COUCHPOTATO_RENAME_TMP_DIR"
   cd "$COUCHPOTATO_DOWNLOAD_DIR"
   mv ./* "$COUCHPOTATO_RENAME_TMP_DIR"

   # run the renamer
   runCouchPotatoRenamer "$COUCHPOTATO_RENAME_TMP_DIR" "move"

   # remove the torrent from transmission
   removeCompleteTorrent
}

# Run the couch potato renamer to move downloaded movies
#
# $1 - the option directory to scan. If not provided the directory 
#      configured in CouchPotato is used
# $2 - the file action to use i.e. move, link, copy
function runCouchPotatoRenamer
{
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
      $WGET "http://$CP_HOST:$CP_PORT/api/$CP_API_KEY/renamer.scan?media_folder=$1" -O /dev/null
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
function getCurrentFileAction
{
   local settingConf="/Users/admin/Library/Application Support/CouchPotato/settings.conf"
   cat "$settingConf" | grep default_file_action | cut -d'=' -f2 | sed -e 's/ //g'
}


###################################################
#                                                 #
#               SickRage Processing               #
#                                                 #
###################################################

SICKRAGE_POST_PROCESS_SCRIPT="/Users/admin/SickRage/autoProcessTV/transmissionToSickRage.py"

# Where torrents added by SickRage that need to keep seeding
# are stashed away while they continue to seed.
SICKRAGE_SEEDED_HOLDING_DIR="/Users/admin/Downloads/TorrentDownloads/TV_SickRage_Seeding"

SICKRAGE_DOWNLOAD_DIR="/Users/admin/Downloads/TorrentDownloads/TV_SickRage"
SICKRAGE_RENAME_TMP_DIR="/Users/admin/Downloads/TorrentDownloads/TV_SickRage_TmpRename"

# Run the SickRage post processor
# using the customised version of sabToSickbeard.py
#
# $1 - the directory to scan for files to rename
# $2 - the process action i.e. move, copy, symlink
function runSickRageRenamer
{
	echo "=====+++++ Starting SickRage rename +++++====="

	$SICKRAGE_POST_PROCESS_SCRIPT "$1" "$2"

	echo "=====+++++ Finished SickRage rename +++++====="
}

# Processes a SickRage download that needs to keep seeding
# This relies on sickrage to sym-link the files when post-processed
function processSickRageSeeded
{
   # move the torrent to a seeding directory, using transmission-remote
   local torrentDir="$SICKRAGE_SEEDED_HOLDING_DIR/$TR_TORRENT_NAME.seeding"
   mkdir "$torrentDir"
   $TRANSMISSION_REMOTE -t$TR_TORRENT_ID --move "$torrentDir"

   # the torrent gets paused when a move is performed, so ensure it is started
   $TRANSMISSION_REMOTE -t$TR_TORRENT_ID --start

   # unpack any archives that mey be in the torrent
   unpack "$torrentDir" "$TR_TORRENT_NAME"

   # run the renamer
   runSickRageRenamer "$torrentDir" "symlink"
}

# Process a SickRage download that does not need to keep seeding
function processSickRageNonSeeded
{
   unpack "$TR_TORRENT_DIR" "$TR_TORRENT_NAME"
   mkdir "$SICKRAGE_RENAME_TMP_DIR"
   cd "$SICKRAGE_DOWNLOAD_DIR"
   mv ./* "$SICKRAGE_RENAME_TMP_DIR"

   # run the renamer
   runSickRageRenamer "$SICKRAGE_RENAME_TMP_DIR" "move"

   # remove the torrent from transmission
   removeCompleteTorrent
}


######################
#                    #
#  Main Function     #
#                    #
######################
function main
{
   echo ""
   echo "=================== Started (`date`) =============================="
   echo "`date`: Running torrent post processing script"

   write_transmission_info_file "$TR_TORRENT_ID"

   cleanup_seeding_torrents >> $LOG_DIR/seeding_torrent_cleanup.log 2>&1
   
   local ratio="`torrentSeedRatio`"

   # For 'zero' seed ratio, we don't need to worry about keeping the torrent file
   # around for seeding
   # Assume that the default is to not seed
   if [ "$ratio" == "0.00" ] || [ "$ratio" == "Default" ]
   then
      echo "SeedRatio $ratio is zero for $TR_TORRENT_NAME, no need to keep it around"
      echo "TR_TORRENT_DIR = $TR_TORRENT_DIR"
      
      if [[ "$TR_TORRENT_DIR" == *"TV_SickRage"* ]]
      then
         echo "Handling a SickRage download, where torrents aren't retained"
         processSickRageNonSeeded
      else
         echo "Handling a CouchPotato download, where torrents aren't retained"
         processCouchPotatoNonSeeded
      fi
   else
      echo "SeedRatio $ratio is non-zero for $TR_TORRENT_NAME, we need to keep the torrent around for seeding"
      echo "TR_TORRENT_DIR = $TR_TORRENT_DIR"

      if [[ "$TR_TORRENT_DIR" == *"TV_SickRage"* ]]
      then
         echo "Handling a SickRage download, where torrent needs to be retained"
         processSickRageSeeded
      else
         echo "Handling a CouchPotato download, where torrent needs to be retained"
         processCouchPotatoSeeded
      fi
   fi

   echo "=================== Finished (`date`) =============================="
}

# run the script, logging to the specified file
main >> $LOG_DIR/torrent_post_processing.log 2>&1
