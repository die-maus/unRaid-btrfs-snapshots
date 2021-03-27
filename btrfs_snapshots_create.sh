#!/bin/bash
#description=This script implements incremental snapshots on btrfs array drives.
#arrayStarted=true

## Credits - https://forums.unraid.net/topic/86674-btrfs-incremental-snapshots/
# catapultam_habeo - Initial script
# Tomr - Modified version with SNAPSHOT_TYPE retention policy
# ChrisYx511 - modified @Tomr's snapshot with retention policy script to merge in @catapultam_habeo's original snapshot pruning method in order to improve the reliability of snapsot pruning.

#If you change the type you'll have to delete the old snapshots manually
#valid values are: hourly, daily, weekly, monthly
SNAPSHOT_TYPE=hourly

#How many snapshots should be kept.
MAX_SNAPS=24
#Name of the shares to exclude, can be comma separated like "medias,valuables"
EXCLUDE=backup,isos,timemachine

#name of the snapshot folder and delimeter. Do not change.
#https://www.samba.org/samba/docs/current/man-html/vfs_shadow_copy2.8.html
SNAPSHOT_DELIMETER="_"
SNAPSHOT_FORMAT="$(date +${SNAPSHOT_TYPE}${SNAPSHOT_DELIMETER}%Y.%m.%d-%H.%M.%S)"

shopt -s nullglob #make empty directories not freak out

is_btrfs_subvolume() {
    local dir=$1
    [ "$(stat -f --format="%T" "$dir")" == "btrfs" ] || return 1
    inode="$(stat --format="%i" "$dir")"
    case "$inode" in
        2|256)
        return 0;;
        *)
        return 1;;
    esac
}

#ADJUST MAX_SNAPS to prevent off-by-1
MAX_SNAPS=$((MAX_SNAPS+1))

#Tokenize exclude list
declare -A excludes
for token in ${EXCLUDE//,/ }; do
    excludes[$token]=1
done

#iterate over all disks on array
for disk in /mnt/disk*[0-9]* ; do
    
    #examine disk for btrfs-formatting (MOSTLY UNTESTED)
    if is_btrfs_subvolume $disk ; then
        
        #iterate over shares present on disk
        for share in ${disk}/* ; do
            declare baseShare=$(basename $share)

            #test for exclusion
            if [ -n "${excludes[$baseShare]}" ]; then
                echo "$share is on the exclusion list. Skipping..."
            else
                #echo "Examining $share on $disk"
                is_btrfs_subvolume $share
                if [ ! "$?" -eq 0 ]; then
                    echo "$share is likely not a subvolume - converting..."
                    mv -v ${share} ${share}_TEMP
                    btrfs subvolume create $share
                    cp -avT --reflink=always ${share}_TEMP $share
                    rm -vrf ${share}_TEMP
                fi
                
                #check for .snapshots directory
                if [ ! -d "$share/.snapshots/" ] ; then
                    btrfs subvolume create $share/.snapshots
                fi
                
                #make new snap - change timestamp
                btrfs subvolume snap ${share} ${share}/.snapshots/${SNAPSHOT_FORMAT}
                touch ${share}/.snapshots/${SNAPSHOT_FORMAT}
                btrfs property set -ts ${share}/.snapshots/${SNAPSHOT_FORMAT} ro true
                
                #find old snaps
                echo "$share/.snapshots/${SNAPSHOT_TYPE} with $(find $share/.snapshots/${SNAPSHOT_TYPE}${SNAPSHOT_DELIMETER}*/ -maxdepth 0 -mindepth 0 | sort -nr | tail -n +$MAX_SNAPS | wc -l) old snaps"

                for share_snap in $(find $share/.snapshots/${SNAPSHOT_TYPE}${SNAPSHOT_DELIMETER}*/ -maxdepth 0 -mindepth 0 | sort -nr | tail -n +$MAX_SNAPS); do
                    btrfs subvolume delete $share_snap
                done              
            fi
        done
    fi
done
