#!/bin/bash
#
# mmi - A script to mount/extract android images on Linux
#
# Author  : Winny Mathew Kurian
# Created : 05-06-2015
#
# Copyright (C) 2015-2018 Winny Mathew Kurian (WiZarD)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################
#                                   History
# -----------------------------------------------------------------------------
# Version        Date        Comment
# -----------------------------------------------------------------------------
#  v1.0          05-06-2015  Initial version
#  v1.1          25-08-2015  Updated to extract recovery image
#  v1.2          13-06-2017  1. Updated to extract dt image
#                               Dependencies:
#                               a. apt-get install device-tree-compiler
#                               b. https://github.com/s0be/dtimgextract
#                            2. Updated to extract modem
#                            3. More messages added
# v1.3           17-07-2017  Updated to handle factory images
#
###############################################################################

ARG=$1
IMAGE=$2

function PrintUsage
{
    echo
    echo `basename $0` - Mount My Image
    echo
    echo "Usage: $0 [ mount | unmount ] image_name.img"
    echo "       $0 [ cleanup ]"
    echo
    echo "[ Options ]"
    echo "mount   - Mount/Extract image"
    echo "umount  - Un-mount image (for system/NON-HLOS/factory images)"
    echo "cleanup - Cleanup the temporary files/folders (for recovery/boot/dt images)"
    echo
    echo "Note: You need to be root to use this script"
    echo "Note: Un-mounting - system, factory NON-HLOS"
    echo "Note:     Cleanup - recovery, boot, dt"
    echo
}

if [ -z "$ARG" ]
then
    PrintUsage
    exit 2
else
    if [ "$ARG" != "cleanup" ]
    then
        if [ -z "$2" ] 
        then
            echo
            echo "Please specify an image name!"
            echo
            PrintUsage
            exit 3
        fi
    fi
fi

# Make sure we can use our executables
chmod +x ./tools/unmkbootimg
chmod +x ./tools/simg2img
chmod +x ./tools/dtimgextract

if [ "$ARG" == "mount" ]
then
    if [[ "$IMAGE" == "NON-HLOS.bin" || "$IMAGE" == "factory.img" ]]
    then
        mkdir -p ./mnt/$IMAGE
        echo "Mount $IMAGE..."
        sudo mount -o loop $IMAGE ./mnt/$IMAGE
        echo
        echo "Listing $IMAGE files:"
        ls -la ./mnt/$IMAGE
        echo
    elif [[ "$IMAGE" == "dt.img" ]]
    then
        mkdir -p dt
        cd dt
        echo "Extract Device Tree..."
        ../tools/dtimgextract ../$IMAGE
        for DTB_FILE in $(ls *.dtb); do
            echo
            echo "Decompiling $DTB_FILE..."
            # We need device-tree-compiler support
            if hash dtc 2>/dev/null; then
                dtc -I dtb -O dts $DTB_FILE -o $DTB_FILE.dts
            else
                echo "Not de-compiling $DTB_FILE!"
                echo "For de-compiling, please install device-tree-compiler"
            fi
        done
        echo
        echo "Listing DTS files:"
        ls -la *.dts
        echo
    elif [[ "$IMAGE" == "recovery.img" || "$IMAGE" == "boot.img" ]]
    then
        echo "Unmkboot..."
        ./tools/unmkbootimg $IMAGE
        mkdir -p ramdisk
        cd ramdisk
        echo "Unzip initramfs..."
        gunzip -c ../initramfs.cpio.gz | cpio -i
        echo
        echo "Listing files:"
        ls -la
        echo
    else
        echo "Converting to RAW image..."
        ./tools/simg2img $IMAGE $IMAGE.raw

        if [ $? -eq 0 ]
        then
            mkdir -p ./mnt/$IMAGE
            echo "Mount RAW image..."
            sudo mount -t ext4 -o loop $IMAGE.raw ./mnt/$IMAGE
        else
            echo
            echo "I am not able to complete the $ARG operation! Bailing..."
            echo
            rm $IMAGE.raw
        fi
        echo
        echo "Listing files:"
        ls -la ./mnt/$IMAGE
        echo
    fi
elif [ "$ARG" == "unmount" ]
then
    echo "Un-mount image..."
    sudo umount ./mnt/$IMAGE
    if [ $? -eq 0 ]
    then
        rm -rf ./mnt/$IMAGE
        # Not preserving the raw image
        # If you need faster mounts, comment the line below
        rm -f $IMAGE.raw
    else
        echo
        echo "I am not able to complete the $ARG operation! Bailing..."
        echo
    fi
elif [ "$ARG" == "cleanup" ]
then
    echo
    echo "Cleaning up files and directories..."
    echo
    rm -rf *.raw zImage initramfs.cpio.gz
    rm -rf ./mnt
    rm -rf ./ramdisk
    rm -rf ./dt
else
    PrintUsage
fi

