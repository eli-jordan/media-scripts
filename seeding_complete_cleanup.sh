#!/bin/bash

TRANSMISSION_REMOTE="/Users/admin/Transmission/bin/transmission-remote"
COUCHPOTATO_SEEDED_HOLDING_DIR="/Users/admin/Downloads/TorrentDownloads/Movies_CouchPotato_Seeding"
SICKRAGE_SEEDED_HOLDING_DIR="/Users/admin/Downloads/TorrentDownloads/TV_SickRage_Seeding"

# For now when files are identified as seeding complete they are just moved to this directory
# in case there is a bug in the script.
SEEDING_COMPLETE_REMOVED="/Users/admin/Downloads/TorrentDownloads/SeedingComplete"

# the separator used to separte the fields in the info file
INFO_FILE_SEPARATOR='|'

# Process the transmission seed descriptors, in a given root directory.
# 
# $1 the root directory to find transmission descriptors in
# $2 the callback command to pass each file to
function process_seed_descriptors
{
   local rootDir="$1"
   local callback="$2"

   find "$rootDir" -type f -name "*.transmission_info" | while read info_file
   do
      $callback "$info_file"
   done
}

# The callback that checks if a torrent is still is transmission
# and if it isn't removes the file.
function process_seeding_descriptor_callback
{
   local info_file="$1"
   local info_file_contents="`cat \"$info_file\"`"

   if is_torrent_in_transmission "$info_file"
   then
      echo "$info_file_contents is still in transmission, nothing to do"
   else
      echo "$info_file_contents is no longer in transmission. Removing seed files..."
      remove_seeding_files "$info_file"
   fi
}

function remove_seeding_files
{
   local seedingDir="`dirname $1`"
   mv "$seedingDir" "$SEEDING_COMPLETE_REMOVED"
}

# Read a seeding descriptor file, and check if the associated torrent is still
# seeding in transmission.
function is_torrent_in_transmission 
{
   local descriptorFile="$1"

   local old_ifs=$IFS
   IFS=$INFO_FILE_SEPARATOR
   read -r id name tr_hash < "$descriptorFile" 
   IFS=$old_ifs

   echo "Grepping for name \"$name\" in \"$descriptorFile\""

   local info_line="`$TRANSMISSION_REMOTE --list | grep \"$name\"`"

   echo "Info Line: $info_line"

   if [ -z "$info_line" ]
   then
      return 1 # non-zero == false
   else
      return 0 # zero == true
   fi
}

# Check if we can access transmission using transmission-remote
function is_transmission_up
{
   $TRANSMISSION_REMOTE --list > /dev/null
   return $?
}

# Get the hash for the torrent in transmission
# $1 the transmission id
function torrent_hash
{
   local id="$1"
   $TRANSMISSION_REMOTE -t"$id" -i | grep "Hash:" | cut -d':' -f2 | sed -e 's/^ *//g'
}

# Get the name for the torrent in transmission
# $1 the transmission id
function torrent_name
{
   local id="$1"
   $TRANSMISSION_REMOTE -t"$id" -i | grep "Name:" | cut -d':' -f2 | sed -e 's/^ *//g'
}

# Get the name for the torrent in transmission
# $1 the transmission id
function torrent_location
{
   local id="$1"
   $TRANSMISSION_REMOTE -t"$id" -i | grep "Location:" | cut -d':' -f2 | sed -e 's/^ *//g'
}

# Write the info files for all complete torrents in transmission
function write_all_info_files
{
   $TRANSMISSION_REMOTE --list | grep '100%' | tr -s ' ' | cut -d' ' -f2 | while read id
   do 
      write_transmission_info_file "$id"
   done
}

# Write the transmission info file
# $1 the torrent id
# $2 the directory to write the file
function write_transmission_info_file
{
   local id="$1"
   local writeToDir=""`torrent_location $id`""

   local tr_hash="`torrent_hash $id`"
   local tr_name="`torrent_name $id`"

   local file_name="$writeToDir/$tr_name.transmission_info"
   echo "File Name: $file_name"

   echo "$id$INFO_FILE_SEPARATOR$tr_name$INFO_FILE_SEPARATOR$tr_hash" > "$file_name"
}

# The main entry point of this script
function cleanup_seeding_torrents 
{
   # first check that we can contact transmission using transmission-remote
   local sleep_time=10
   for attempt in {1..5}
   do
      echo "Checking transmission attempt $attempt"
      if is_transmission_up
      then
         echo "Transmission is up. Continuing."
         break
      else
         echo "Unable to contact Transmission using transmission-remote, will retry in $sleep_time sec"
         sleep $sleep_time
      fi
   done

   if ! is_transmission_up
   then
      echo "Script was unable to contact transmission. Exiting..."
      return -1
   fi

   echo "`date`: ======================================= Start ==================================="
   echo "Seeding torrents cleanup: SickRage"
   process_seed_descriptors "$SICKRAGE_SEEDED_HOLDING_DIR" process_seeding_descriptor_callback

   echo "Seeding torrents cleanup: CouchPotato"
   process_seed_descriptors "$COUCHPOTATO_SEEDED_HOLDING_DIR" process_seeding_descriptor_callback

   echo "`date`: ======================================= End ==================================="
}