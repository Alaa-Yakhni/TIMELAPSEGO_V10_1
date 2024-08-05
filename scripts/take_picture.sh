#!/bin/bash

JSON_FILE="/home/pi/data/config.json"
PICTURES_DIR="/DATA/HIGH"
LOG_DIR="/DATA/LOG"
DATABASE_DIR="/DATA/DATABASE"
PICTURES_LOW="/DATA/LOW"
PICTURES_BLUR="/DATA/BLUR"
PICTURES_RAW="/DATA/RAW"
#include global vars and functions
. "/home/pi/scripts/global.sh"


#############################################################################
##                              Function                                   ##
#############################################################################
initialize_camera() {

    start_initialize_camera=$(date +%s)
    #echo " Start time initialize $start_initialize_camera secodes" >> "$tem_log"

    local image_size=$1
    local iso=$2
    local fnumber=$3
    local shutterspeed=$4
    local image_quality=$5

    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
    echo "|                         Initialize Camera                                |" >> "$tem_log"
    echo "+--------------------------------------------------------------------------+" >> "$tem_log"

    # Check if a camera is detected
    if gphoto2 --auto-detect | grep -q "No camera"; then
        echo "No camera detected." >> "$tem_log"
    else
        # Load image configuration for the first job
        config="--set-config imagesize=$image_size --set-config iso=$iso --set-config f-number=$fnumber --set-config shutterspeed=$shutterspeed --set-config imagequality=$image_quality"

        echo "+--------------------------------------------------------------------------+" >> "$tem_log"

        # Print the loaded configuration
        echo "Loaded camera configuration: $config" >> "$tem_log"

        echo "+--------------------------------------------------------------------------+" >> "$tem_log"
        # Initialize the camera with parameters
        gphoto2 $config >> "$tem_log" 2>&1
        # Check if initialization was successful
        if [ $? -eq 0 ]; then
            echo "Camera successfully initialized with the provided configurations." >> "$tem_log"
        else
            echo "Error initializing the camera with the provided configurations." >> "$tem_log"
        fi
    fi
    end_initialize_camera=$(date +%s)
    # Calculate the time difference
    elapsed_time_initialize=$((end_initialize_camera - start_initialize_camera))

    # Display the elapsed time
    echo "Initialize camera finished execution in $elapsed_time_initialize seconds" >> "$tem_log"
}
#############################################################################
##                              Function                                   ##
#############################################################################

take_picture()
{
    start_take=$(date +%s)
    #echo "Start time take $start_take secondes" >> "$tem_log"

    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
    echo "|                               START TAKE                                 |" >> "$tem_log"
    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
    # Nombre maximum de tentatives
    max_attempts=2
    attempt=1

    # Loop pour la capture de l'image
    while [ $attempt -le $max_attempts ]; do
        # Take a picture with the specified name
        gphoto2 --capture-image-and-download  >> "$tem_log"

        if [ -f "capt0000.jpg" ]; then 
            mv capt0000.jpg "$PICTURES_DIR/${now}.jpg"
            echo "Saving file as $PICTURES_DIR/${now}.jpg" >> "$tem_log"
        fi
        # Vérifier si le fichier capt0000.nef existe et le déplacer vers "raw"
        if [ -f "capt0000.nef" ]; then
            mv capt0000.nef "$PICTURES_RAW/${now}.nef"
            echo "Saving file as $PICTURES_RAW/${now}.nef" >> "$tem_log"
        fi 
        # Check if the picture was taken successfully
        if [ $? -eq 0 ] && [ -f "$PICTURES_DIR/${now}.jpg" ]; then
	
             # Check if the picture has a size greater than 0 bytes
	         image_size=$(stat -c %s "$PICTURES_DIR/${now}.jpg")
             if [ "$image_size" -eq 0 ]; then
	         rm "$PICTURES_DIR/${now}.jpg"
	         echo "Error: Captured image is empty (0 bytes)." >> "$tem_log"
             else
                if [ "$is_trigger_sms" == "false" ]; then 
                    if [ "$PCB" == "PCBv3" ]; then
                        # off camera
                        sudo tlgo-commands -c 1 
                        else 
                        # off camera
                        sudo tlgo-commands -c 0 
                    fi
                fi
                # Get the size of the image
                image_size=$(stat -c %s "$PICTURES_DIR/${now}.jpg")
                image_size_mb=$(echo "scale=2; $image_size / (1024 * 1024)" | bc)
                echo "Photo taken successfully: ${now}.jpg Image size: $image_size_mb Mo." >> "$tem_log"
                echo "+--------------------------------------------------------------------------+" >> "$tem_log"

                if [ "$PCB" == "PCBv10" ]; then
                  # Start debug_led function in background
                  debug_led &
                fi 
                # Add copyright
                exiftool -overwrite_original -Copyright="TimeLapse Go'" "$PICTURES_DIR/${now}.jpg" &
                exiftool -Model -SerialNumber -ShutterCount "$PICTURES_DIR/${now}.jpg"  >> "$tem_log" &
                if [ "$is_blur" == "true" ]; then
                    mv "$PICTURES_DIR/${now}.jpg" "$PICTURES_BLUR"
                    echo "Moving ${now}.jpg to $PICTURES_BLUR" >> "$tem_log"
                fi
             break
            fi
        else
            echo "Error: Failed to capture the photo on attempt $attempt." >> "$tem_log"
            if [ $attempt -eq $max_attempts ]; then
                rm "$DATABASE_DIR/$now.json"
                if [ "$is_trigger_sms" == "false" ]; then 
                    if [ "$PCB" == "PCBv3" ]; then
                        # off camera
                        sudo tlgo-commands -c 1 
                        else 
                        # off camera
                        sudo tlgo-commands -c 0 
                    fi
                fi
            fi
        fi

        # Augmenter le compteur de tentative
        ((attempt++))
    done

    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
    echo "|                              END TAKE                                    |" >> "$tem_log"
    echo "+--------------------------------------------------------------------------+" >> "$tem_log"

    end_take=$(date +%s)
    #echo "End time take $end_take secondes" >> "$tem_log"

    # Calculate the time difference
    elapsed_time_take=$((end_take - start_take))

    # Display the elapsed time
    echo "TAKE finished execution in $elapsed_time_take seconds" >> "$tem_log"
}
#############################################################################
##                              Function                                   ##
#############################################################################
Check-pictureLow() {

    PICTURES=$1
    LOW_PICTURES=$2
    MAX_RETRIES=2

    start_comp=$(date +%s)

    image_list=($(ls -1t "$PICTURES"/*.jpg))

    # Check if the transfer is not disabled and if the image should not be blurred
    if [ "$notransfer" == "false" ] && [ "$is_blur" == "false" ]; then
        # Loop through each image in the image_list
        for image in "${image_list[@]}"; do

            # Extract the image name
            image_name=$(basename "$image")

            # Check if the image does not already exist in LOW_PICTURES
            if [ ! -f "$LOW_PICTURES/$image_name" ]; then
                # Check the number of ongoing processes
                echo "+--------------------------------------------------------------------------+" >> "$tem_log"
		        echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                size=$(stat -c %s "$image")
                if [ "$size" -eq 0 ]; then
                   rm "$image"
                   echo " $image is deleted size equal 0" >> "$tem_log"
                else
                    attempt=1
                    while [ $attempt -le $MAX_RETRIES ]; do

                        # Compress the image and modify the metadata
                        gm convert "$image" -strip -quality 60% -resize 900x600 -define jpeg:optimize-coding=true "$LOW_PICTURES/$image_name"
                        size_low=$(stat -c %s "$LOW_PICTURES/$image_name")

                        if [ "$size_low" -eq 0 ]; then
                            rm "$LOW_PICTURES/$image_name"
                            echo " $LOW_PICTURES/$image_name is deleted size equal 0" >> "$tem_log"
                            success=0
                        else
                            success=1
                        fi

                        # Check if the compression was successful
                        if [ $success -eq 1 ]; then
                            echo "Photo $image compressed successfully" >> "$tem_log"
                            end_comp=$(date +%s)

                            # Calculate the time difference
                            elapsed_time_comp=$((end_comp - start_comp))
                            # Display the elapsed time
                            echo " compress finished execution in $elapsed_time_comp seconds from $PICTURES" >> "$tem_log"
                            break
                        else
                            echo "Error: Unable to compress $image on attempt $attempt" >> "$tem_log"
                            attempt=$((attempt + 1))
                        fi
                    done

                    if [ $success -eq 0 ]; then
                        echo "Failed to compress $image after $MAX_RETRIES attempts" >> "$tem_log"
                    fi
                fi
            fi
        done
    fi
}

#############################################################################
#                          MAIN
############################################################################

no_picture_voltage=$(jq -r '.no_picture_voltage' "$JSON_FILE")
voltage=$(jq '.voltage' "/home/pi/data/system_info.json")
# Check if the value is empty or zero
if [ -z "$voltage" ] || [ "$voltage" == "0" ]; then
    echo "La valeur de voltage n'existe pas ou est zéro. Attribution de la valeur par défaut."
    voltage=$(sudo tlgo-commands -V)
fi

if (( $(echo "$voltage < $no_picture_voltage" | bc -l) )); then
    exit 1
fi
#
touch /tmp/take_picture.lock
sleep $1

model=$(cat /proc/device-tree/model)

img_storage=$(jq -r '.img_storage' "$JSON_FILE")
data_storage=$(jq -r '.data_storage' "$JSON_FILE")
# get value is_no_transfer from JSON_FILE
notransfer=$(jq -r '.is_no_transfer' "$JSON_FILE")
# get value is_blur from JSON_FILE 
is_blur=$(jq -r '.is_blur' "$JSON_FILE")

is_trigger_sms=$(jq -r '.is_trigger_sms' "$JSON_FILE")

if [ ! -d /DATA ]; then
        mkdir -p /DATA
        echo "Directory /DATA created."
fi

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

    # Check if the database directory exists, if not, create it
if [ ! -d "$DATABASE_DIR" ]; then
    mkdir "$DATABASE_DIR"
    echo "Directory $DATABASE_DIR created."
fi

# Check if the pictures LOW directory  exists, if not, create it
if [ ! -d "$PICTURES_LOW" ]; then
    mkdir "$PICTURES_LOW"
    echo "Directory $PICTURES_LOW created."
fi

# Check if the pictures blur directory exists, if not, create it
if [ ! -d "$PICTURES_BLUR" ]; then
    mkdir "$PICTURES_BLUR"
    echo "Directory $PICTURES_BLUR created."
fi

# Check if the pictures raw directory exists, if not, create it
if [ ! -d "$PICTURES_RAW" ]; then
    mkdir "$PICTURES_RAW"
    echo "Directory $PICTURES_RAW created."
fi

now="$(date +"%Y_%m_%d_%H_%M_%S")"

# log temporel
tem_log="${now}_take_photo.txt"

file_log="$LOG_DIR/${now}_take_photo.txt"
# Define the photo name with the current date
photo_name="$now.jpg"

if [[ $data_storage == *"Server"* ]]; then
    ## update info to system
    /home/pi/scripts/system_info.sh "$DATABASE_DIR/$now.json"  2>/dev/null &
fi
if [ -e /dev/ttyACM0 ]; then
    # get value for nanosence sensor save to /home/pi/data/nanosenceValue.json
    getNanosense_Value &
fi
PCB=$(sed -n '2p' /home/pi/data/info.txt) 
if [ "$is_trigger_sms" == "false" ]; then 
    if [ "$PCB" == "PCBv3" ]; then
        # on camera
        sudo tlgo-commands -c 0
        else
        # on camera
        sudo tlgo-commands -c 1
    fi
fi

system_info "$tem_log"


if [[ "$model" == *"Raspberry"* ]]; then
    sleep 1
fi

### reset usb camera
reset_usb_nikon

# Appel de la fonction initialize_camera avec les valeurs passées en arguments
initialize_camera $2 $3 $4 $5 $6

take_picture

if [[ $img_storage == *"S3"* ]]; then
  Check-pictureLow $PICTURES_DIR $PICTURES_LOW
fi

## move photos in time directory kept for 30 days in the case of transfer to usb
if [[ $img_storage == *"USB"* ]]; then
    mkdir -p /DATA/img_send_usb_HIGH
    mkdir -p /DATA/img_send_usb_RAW
    cp /DATA/HIGH/* /DATA/img_send_usb_HIGH 
    cp /DATA/RAW/* /DATA/img_send_usb_RAW
fi



if [ -b /dev/mmcblk1p1 ]; then
    start_sd=$(date +%s)

    # Create directories if they don't exist
    if [ ! -d "/mnt/sdcard/LOG" ]; then
        mkdir -p "/mnt/sdcard/LOG"
        echo "Directory /mnt/sdcard/LOG created" 
    fi

    if [ ! -d "/mnt/sdcard/HIGH" ]; then
        mkdir "/mnt/sdcard/HIGH"
        echo "Directory /mnt/sdcard/HIGH created" 
    fi

    if [ ! -d "/mnt/sdcard/DATABASE" ]; then
        mkdir "/mnt/sdcard/DATABASE"
        echo "Directory /mnt/sdcard/DATABASE created" 
    fi

    # Check if the pictures LOW directory  exists, if not, create it
    if [ ! -d "/mnt/sdcard/LOW" ]; then
        mkdir "/mnt/sdcard/LOW"
        echo "Directory /mnt/sdcard/LOW created" 
    fi

    # Check if the pictures blur directory  exists, if not, create it
    if [ ! -d "/mnt/sdcard/BLUR" ]; then
        mkdir "/mnt/sdcard/BLUR"
        echo "Directory /mnt/sdcard/BLUR created"
    fi

    # Check if the pictures RAW directory  exists, if not, create it
    if [ ! -d "/mnt/sdcard/RAW" ]; then
        mkdir "/mnt/sdcard/RAW"
        echo "Directory /mnt/sdcard/RAW created"
    fi

    sudo fsck /dev/mmcblk1p1
    if [ $? -eq 0 ]; then
        # Check available space on sd card octet
        available_space=$(df --block-size=1 --output=avail "$SD_MOUNT_POINT" | awk 'NR==2')
        # Calculate the total size of each directory in bytes
        total_size=$(du -sb "$PICTURES_DIR" "$LOG_DIR" "$DATABASE_DIR" "$PICTURES_LOW" "$PICTURES_BLUR" "$PICTURES_RAW" | awk '{s+=$1} END {print s}')

        if [ "$available_space" -ge "$total_size" ]; then

            if [ "$is_blur" == "true" ]; then
                if [ -d "/mnt/sdcard/BLUR" ]; then
                    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                    cp "$PICTURES_BLUR/$photo_name" /mnt/sdcard/BLUR
                    if [ $? -eq 0 ]; then
                        echo "Copying $photo_name to /mnt/sdcard/BLUR succeeded" >> "$tem_log"
                        rm "$PICTURES_BLUR/$photo_name"
                    else
                        echo "Error while copying $photo_name to /mnt/sdcard/BLUR" >> "$tem_log" 
                    fi
                    sudo sync
                    # Copie de tous les fichiers du répertoire "$PICTURES_BLUR" vers "/mnt/sdcard/blur_pictures"
                    if [ "$(ls -A $PICTURES_BLUR)" ]; then
                        cp -r "$PICTURES_BLUR"/* /mnt/sdcard/BLUR
                        if [ $? -eq 0 ]; then
                            echo "Copying all files from $PICTURES_BLUR to /mnt/sdcard/BLUR succeeded" >> "$tem_log"
                            rm -rf "$PICTURES_BLUR"/*
                        fi
                    fi
                    sudo sync
                fi
            else
                if [ -d "/mnt/sdcard/HIGH" ]; then
                    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                    cp "$PICTURES_DIR/$photo_name" "/mnt/sdcard/HIGH"
                    if [ $? -eq 0 ]; then
                        echo "Copying $photo_name to /mnt/sdcard/HIGH succeeded" >> "$tem_log"
                        rm "$PICTURES_DIR/$photo_name"
                    else
                        echo "Error while copying $photo_name to /mnt/sdcard/HIGH" >> "$tem_log"
                    fi
                    sudo sync
                    # Copie de tous les fichiers du répertoire "$PICTURES_DIR" vers "/mnt/sdcard/pictures"
                    if [ "$(ls -A $PICTURES_DIR)" ]; then
                        cp -r "$PICTURES_DIR"/* /mnt/sdcard/HIGH
                        if [ $? -eq 0 ]; then
                            echo "Copying all files from $PICTURES_DIR to /mnt/sdcard/HIGH succeeded" >> "$tem_log"
                            rm -rf "$PICTURES_DIR"/*
                        fi
                    fi
                    sudo sync
                fi

                if [ -d "/mnt/sdcard/LOW" ]; then
                    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                    cp "$PICTURES_LOW/$photo_name" /mnt/sdcard/LOW
                    if [ $? -eq 0 ]; then
                        echo "Copying $photo_name to /mnt/sdcard/LOW succeeded" >> "$tem_log"
                        rm "$PICTURES_LOW/$photo_name"
                    else
                        echo "$photo_name not exist to $PICTURES_LOW" >> "$tem_log"
                    fi
                    sudo sync
                    # Copie de tous les fichiers du répertoire "$PICTURES_LOW" vers "/mnt/sdcard/low_pictures"
                    if [ "$(ls -A $PICTURES_LOW)" ]; then
                        cp -r "$PICTURES_LOW"/* /mnt/sdcard/LOW
                        if [ $? -eq 0 ]; then
                            echo "Copying all files from $PICTURES_LOW to /mnt/sdcard/LOW succeeded" >> "$tem_log"
                            rm -rf "$PICTURES_LOW"/*
                        fi
                    fi
                    sudo sync
                fi
            fi

            # Copie de tous les fichiers du répertoire "$PICTURES_DIR" vers "/mnt/sdcard/pictures"
            if [ "$(ls -A $PICTURES_RAW)" ]; then
                cp -r "$PICTURES_RAW"/* /mnt/sdcard/RAW
                if [ $? -eq 0 ]; then
                    echo "Copying all files from $PICTURES_RAW to /mnt/sdcard/RAW succeeded" >> "$tem_log"
                    rm -rf "$PICTURES_RAW"/*
                fi
            fi
            sudo sync

            if [ -d "/mnt/sdcard/DATABASE" ]; then
                echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                cp "$DATABASE_DIR/$now.json" /mnt/sdcard/DATABASE
                if [ $? -eq 0 ]; then
                    echo "Copying $now.json to /mnt/sdcard/DATABASE succeeded" >> "$tem_log"
                    rm "$DATABASE_DIR/$now.json"
                else
                    echo "Error while copying $now.json to /mnt/sdcard/DATABASE" >> "$tem_log" 
                fi
                sudo sync
                if [ "$(ls -A $DATABASE_DIR)" ]; then
                    cp -r "$DATABASE_DIR"/* /mnt/sdcard/DATABASE
                    if [ $? -eq 0 ]; then
                        echo "Copying all files from $DATABASE_DIR to /mnt/sdcard/DATABASE succeeded" >> "$tem_log"
                        rm -rf "$DATABASE_DIR"/*
                    fi
                fi
                sudo sync
            fi

            if [[ $img_storage == *"S3"* ]]; then
                 Check-pictureLow /mnt/sdcard/HIGH /mnt/sdcard/LOW
            fi
            #echo "End time to move to sdcard $end_sd secondes" >> "$tem_log"
            end_sd=$(date +%s)
            # Calculate the time difference
            elapsed_time_sd=$((end_sd - start_sd))

            # Display the elapsed time
            echo " Move to sdcard finished execution in $elapsed_time_sd seconds"  >> "$tem_log"
            echo "+--------------------------------------------------------------------------+" >> "$tem_log"
            echo "+--------------------------------------------------------------------------+" >> "$tem_log"
            mv $tem_log $file_log
            if [ -d "/mnt/sdcard/LOG" ]; then

                cp "$file_log" /mnt/sdcard/LOG
                if [ $? -eq 0 ]; then
                    echo "Moving $file_log to /mnt/sdcard/LOG succeeded" 
                    rm "$file_log"

                else
                    echo "Error while moving $file_log to /mnt/sdcard/LOG" 
                fi
                sudo sync
                if [ "$(ls -A $LOG_DIR)" ]; then
                    cp "$LOG_DIR"/* /mnt/sdcard/LOG
                    if [ $? -eq 0 ]; then
                        echo "Copying all files from $LOG_DIR to /mnt/sdcard/LOG succeeded" 
                        rm -rf "$LOG_DIR"/*
                    fi
                fi
                sudo sync
            fi
            ## move photos in time directory kept for 30 days in the case of transfer to usb sd card
            if [[ $img_storage == *"USB"* ]]; then
                mkdir -p /mnt/sdcard/img_send_usb_HIGH
                mkdir -p /mnt/sdcard/img_send_usb_RAW   
                cp /DATA/img_send_usb_HIGH/* /mnt/sdcard/img_send_usb_HIGH    
                cp /DATA/img_send_usb_RAW/* /mnt/sdcard/img_send_usb_RAW 
            fi
        else 
            echo "Error: Not enough space available on SD card to move files" >> "$tem_log"
        fi

    else
        echo "No SD card detected" >> "$tem_log"
        echo "+--------------------------------------------------------------------------+" >> "$tem_log"
        echo "+--------------------------------------------------------------------------+" >> "$tem_log"
        mv $tem_log $file_log
    fi
else
    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
    mv $tem_log $file_log
fi

echo "$7" > /home/pi/data/mode.txt


# Supprimer les fichiers plus anciens que 30 jours dans /DATA/img_send_usb
find /DATA/img_send_usb_HIGH -type f -mtime +30 -exec rm {} \;

# Supprimer les fichiers plus anciens que 30 jours dans /mnt/sdcard/img_send_usb
find /mnt/sdcard/img_send_usb_HIGH -type f -mtime +30 -exec rm {} \;

# Supprimer les fichiers plus anciens que 30 jours dans /DATA/img_send_usb
find /DATA/img_send_usb_RAW -type f -mtime +30 -exec rm {} \;

# Supprimer les fichiers plus anciens que 30 jours dans /mnt/sdcard/img_send_usb
find /mnt/sdcard/img_send_usb_RAW -type f -mtime +30 -exec rm {} \;



rm /tmp/take_picture.lock

