# unRaid-btrfs-snapshots

brtfs shapshots within unRaid

Changes in the original version found in der unRaid forums https://forums.unraid.net/topic/86674-btrfs-incremental-snapshots/

- turning on "Enhanced macOS interoperability" brakes the file versioning for Windows clients
- place .snapshot directory in the /mnt/diskX/shareX/.snapshot/xxx
- this make snapshots usable for Windwos ans MacOS clients
- korrekt the snapshot timestamp for sorting

Add this to your Settings->SMB->SMB Extra. This hides the ".snapshot" directory

hide files = /.snapshots/
