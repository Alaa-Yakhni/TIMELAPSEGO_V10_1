#!/bin/bash

# Execute tlgo-commands 
sudo tlgo-commands -i 
sudo /home/pi/scripts/system_info.sh /home/pi/data/system_info.json
# Check if the SD card is available and mount it if it exists
if [ -b /dev/mmcblk1p1 ]; then
    sudo mount /dev/mmcblk1p1 /mnt/sdcard
fi

is_trigger_sms=$(jq -r '.is_trigger_sms' "/home/pi/data/config.json")
PCB=$(sed -n '2p' /home/pi/data/info.txt)
if [ $is_trigger_sms == "true" ]; then
    if [ "$PCB" == "PCBv3" ]; then
        # on camera
        sudo tlgo-commands -c 0
        else
        # on camera
        sudo tlgo-commands -c 1
    fi
fi

sudo systemctl start ssh.service
