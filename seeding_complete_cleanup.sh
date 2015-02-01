#!/bin/bash

TRANSMISSION_REMOTE="/Users/admin/Transmission/bin/transmission-remote"
COUCHPOTATO_SEEDED_HOLDING_DIR="/Users/admin/Downloads/TorrentDownloads/Movies_CouchPotato_Seeding"
SICKRAGE_SEEDED_HOLDING_DIR="/Users/admin/Downloads/TorrentDownloads/TV_SickRage_Seeding"

# For now when files are identified as seeding complete they are just moved to this directory
# in case there is a bug in the script.
SEEDING_COMPLETE_REMOVED="/Users/admin/Downloads/TorrentDownloads/SeedingComplete"

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
   if is_torrent_in_transmission "$info_file"
   then
      echo "`cat $info_file` is still in transmission, nothing to do"
   else
      echo "`cat $info_file` is no longer in transmission. Removing seed files..."
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
   read -r id name tr_hash < "$descriptorFile" 

   echo "is_torrent_in_transmission: id: $id, name: $name, hash: $tr_hash"
   local transmission_hash="`torrent_hash $id`"

   # Check if the hash read from the descriptor file matches that in transmission
   # meaning that it is still in transmission and seeding
   if [ "$transmission_hash" == "$tr_hash" ]
   then
      return 0 # 0 == true
   else
      return 1 # non-zero == false
   fi
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
      write_transmission_info_file "$id" "`torrent_location $id`"
   done
}

# Write the transmission info file
# $1 the torrent id
# $2 the directory to write the file
function write_transmission_info_file
{
   local id="$1"
   local writeToDir="$2"

   local tr_hash="`torrent_hash $id`"
   local tr_name="`torrent_name $id`"

   local file_name="$writeToDir/$tr_name.transmission_info"
   echo "File Name: $file_name"

   echo "$id $tr_name $tr_hash" > "$file_name"
}

# The main entry point of this script
function cleanup_seeding_torrents 
{
   echo "`date`: ======================================= Start ==================================="
   echo "Seeding torrents cleanup: SickRage"
   process_seed_descriptors "$SICKRAGE_SEEDED_HOLDING_DIR" process_seeding_descriptor_callback

   echo "Seeding torrents cleanup: CouchPotato"
   process_seed_descriptors "$COUCHPOTATO_SEEDED_HOLDING_DIR" process_seeding_descriptor_callback

   echo "`date`: ======================================= End ==================================="
}