#!/bin/bash
#description=delete all snapshots on btrfs array drives.
#arrayStarted=true

INCLUDE=daten

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

#Tokenize include list
declare -A includes
for token in ${INCLUDE//,/ }; do
    includes[$token]=1
done

#iterate over all disks on array
for disk in /mnt/disk*[0-9]* ; do

    #examine disk for btrfs-formatting (MOSTLY UNTESTED)
    if is_btrfs_subvolume $disk ; then
        
        #iterate over shares present on disk
        for share in ${disk}/* ; do
            declare baseShare=$(basename $share)

            #test for inclusion
            if [ -n "${includes[$baseShare]}" ]; then
                echo "delete all snapshots on $share..."               

                for share_snap in $(find $share/.snapshots/* -maxdepth 0 -mindepth 0); do
                    #echo "delete $share_snap"    
                    btrfs subvolume delete $share_snap
                done
             
                #echo "delete $share/.snapshot"
                btrfs subvolume delete $share/.snapshots
            fi
        done
    fi
done