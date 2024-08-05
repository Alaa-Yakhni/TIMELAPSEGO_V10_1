#!/bin/bash

while true; do
    if [ -f "/tmp/send_picture.lock" ]; then
        echo "Le script est en cours "
    else
	echo "lancement"

        # Create the lock file
        touch /tmp/send_picture.lock

        # Run the script send_picture.sh
        /home/pi/scripts/send_picture.sh

        # Remove the lock file after the script finishes
        rm /tmp/send_picture.lock
    fi

   if [ -f "/tmp/update.lock" ]; then

       exit 
   fi
   sleep 2
done
