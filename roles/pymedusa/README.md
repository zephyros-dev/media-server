# Pymedusa hardlink rename problem with mergerfs

- This tasks is for removing empty directory in all data disks. When pymedusa rename a show with hardlink, the following happen if empty directory is not cleared:

1. Pymedusa make a folder on the shared mergerfs pool before moving the hardlink file
2. By default mergerfs try to create directory on the disks with the most common branch and most free space, which means that if empty common branch directory exists on all disks, it may create the new directory on a different disks from the file, which will make the hardlink fail to be preserve
3. Pymedusa (or mergerfs?) will silently move the file over to the disk different from the original hardlink

- To avoid this, delete the empty folder on all disk so that the most common branch only exists on the disks with the hardlink file, which will guarantee that the hardlink file and the created folder will be on the same disk. To do this manually:

1. Remove the empty directory once done (TOOD: This step could be automated to run periodically by a systemd service timer)

```
ansible-playbook pymedusa.yaml --tags rmdir
```
