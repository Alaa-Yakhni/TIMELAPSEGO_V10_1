#!/bin/bash

TLGO_CONFIG="/home/pi/data/config.json"
PICTURES_DIR="/home/pi/pictures"
LOG_DIR="/home/pi/logs"


#include global vars and functions
. "/home/pi/global.sh"
# Function to take a photo
take_picture() {
    # Check if the logs directory exists, if not, create it
    if [ ! -d "$LOG_DIR" ]; then
        mkdir -p "$LOG_DIR"
        echo "Directory $LOG_DIR created."
    fi

    # Check if the pictures directory exists, if not, create it
    if [ ! -d "$PICTURES_DIR" ]; then
        mkdir "$PICTURES_DIR"
        echo "Directory $PICTURES_DIR created."
    fi

    
    now="$(date +"%Y_%m_%d_%H_%M_%S")"
    
    # Define the photo name with the current date
    photo_name="$now.jpg"


    echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_take_photo.txt"
    echo "|                           SYSTEM INFORMATION                             |" >> "$LOG_DIR/${now}_take_photo.txt"
    echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_take_photo.txt"

    system_info "$LOG_DIR/${now}_take_photo.txt"
    echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_take_photo.txt"
    echo "|                               START                                      |" >> "$LOG_DIR/${now}_take_photo.txt"
    echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_take_photo.txt"
    # Take a photo with the specified name
    gphoto2 --capture-image-and-download --filename "$PICTURES_DIR/$photo_name" >> "$LOG_DIR/${now}_take_photo.txt"

    # Check if the photo was taken successfully
    if [ $? -eq 0 ]; then
        # Check if the photo file exists
        if [ -f "$PICTURES_DIR/$photo_name" ]; then
            echo "Photo taken successfully: $photo_name" >> "$LOG_DIR/${now}_take_photo.txt"
        else
            echo "Error: Photo file was not created. Camera may be on but did not capture photo." >> "$LOG_DIR/${now}_take_photo.txt"
        fi
    else
        echo "Error: Failed to take photo." >> "$LOG_DIR/${now}_take_photo.txt"
    fi

    echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_take_photo.txt"
    echo "|                               END                                        |" >> "$LOG_DIR/${now}_take_photo.txt"
    echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_take_photo.txt"

}



#############################################################################
#                          MAIN
############################################################################

take_picture
