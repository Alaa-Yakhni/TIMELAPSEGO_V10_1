#!/bin/bash

#include global vars and functions
. /home/pi/scripts/global.sh

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################
# Fonction pour extraire les données d'un fichier JSON
# Fonction pour extraire et transformer les données d'un fichier JSON
extract_data_from_json() {
    local file="$1"

    # Utiliser jq pour extraire et transformer les valeurs du fichier JSON
    temperature=$(jq '.temperature' "$file")
    pressure=$(jq '.pressure' "$file")
    humidity=$(jq '.humidity' "$file")
    voltage=$(jq '.voltage * 100' "$file")
}



#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################
send_database()
{   image_name=$1
    now=$2
    DATABASE_DIR=$3
    echo "+--------------------------------------------------------------------------+" 
    echo "|                         SEND DATA TO DATABASE                            |" 
    echo "+--------------------------------------------------------------------------+" 
    # Chemin du fichier JSON correspondant
        json_file="$DATABASE_DIR/${now}.json"
    
    # get value for nanosence sensor save to /home/pi/data/nanosenceValue.json
    if [ -f /home/pi/data/nanosenseValue.json ]; then 
        temperature=$(jq '.temperature' "/home/pi/data/nanosenseValue.json")
        pressure=$(jq '.pressure' "/home/pi/data/nanosenseValue.json")
        humidity=$(jq '.humidity' "/home/pi/data/nanosenseValue.json")
        pm1=$(jq '.pm1' "/home/pi/data/nanosenseValue.json")
        pm25=$(jq '.["pm2.5"]' "/home/pi/data/nanosenseValue.json")
        pm10=$(jq '.pm10' "/home/pi/data/nanosenseValue.json")
        noise_avg=$(jq '.noise_avg' "/home/pi/data/nanosenseValue.json")
        noise_peak=$(jq '.noise_peak' "/home/pi/data/nanosenseValue.json")
        voltage=$(jq '.voltage * 100' "$DATABASE_DIR/${now}.json")

        # Envoyer les images et les données via la requête cURL
        curl_output=$(curl -i --max-time 120 --connect-timeout 60 --write-out "%{http_code}" -X POST "$url" \
            -H "Content-Type: application/json" \
            -d '[{"name": "'"$image_name"'", "path": "'"$image_name"'", "date": "'"$now"'", "md5": "'" "'", "data_voltage": "'"$voltage"'", "data_temp": "'"$temperature"'", "data_humidity": "'"$humidity"'", "data_pressure": "'"$pressure"'","data_pm1":"'"$pm1"'","data_pm25":"'"$pm25"'","data_pm10":"'"$pm10"'","data_soundavg":"'"$noise_avg"'","data_soundpeak":"'"$noise_peak"'"}]')
         rm /home/pi/data/nanosenseValue.json
    else
        # Extraire les données du fichier JSON correspondant
        if [ -f "$json_file" ]; then
            extract_data_from_json "$json_file"
            # Envoyer les images et les données via la requête cURL
            curl_output=$(curl -i --max-time 120 --connect-timeout 60 --write-out "%{http_code}" -X POST "$url" \
                -H "Content-Type: application/json" \
                -d '[{"name": "'"$image_name"'", "path": "'"$image_name"'", "date": "'"$now"'", "md5": "'" "'", "data_voltage": "'"$voltage"'", "data_temp": "'"$temperature"'", "data_humidity": "'"$humidity"'", "data_pressure": "'"$pressure"'"}]')

        # Append curl output to the log file
        else
            echo "Fichier JSON correspondant non trouvé pour $image_name"
                # Send curl request using variables
        curl_output=$(curl -i --max-time 120 --connect-timeout 60 --write-out "%{http_code}" -X POST "$url" \
            -H "Content-Type: application/json" \
            -d '[{"name": "'"$image_name"'", "path": "'"$image_name"'", "date": "'"$now"'", "md5": "'" "'", "data_voltage": "'" "'", "data_temp": "'" "'", "data_humidity": "'" "'", "data_pressure": "'" "'"}]')
        fi
    fi
    # Append curl output to the log file

    http_code=$(echo "$curl_output" | sed -n '/HTTP\/1\.[01]/,/^$/p')

    http_code=$(echo "$http_code" | sed '/^{/d')

    echo "$http_code"

    rm "$json_file"
}
#----------------------------------------------------------------------------------------------#
                                #SEND TO S3#
#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################
send_picture ()
{

    local PICTURES_DIR=$1
    local PICTURES_LOW=$2
    local LOG_DIR=$3
    local DATABASE_DIR=$4
    local PICTURES_RAW=$5

    image_list=($(ls -1t "$PICTURES_DIR"/*.jpg))

    #IMAGES REMAINING TO BE SENT
    num_images=${#image_list[@]}

    local MAX_IMAGES=5  # Maximum number of images to process
    local count=0  # Counter for processed images
    # Iterate through each image
    for image in "${image_list[@]}"; do
        start=$(date +%s)
        # Extract image filename
        image_name=$(basename "$image") 
        # Image capture date
        now=$(echo "$image_name" | sed 's/\.jpg$//g')
        if [ ! -s "$PICTURES_LOW/$image_name" ]; then
            # Supprimer le fichier si taille de zero
            rm "$PICTURES_LOW/$image_name"
        fi
        if [ -f "$PICTURES_LOW/$image_name" ] && [ -s "$PICTURES_LOW/$image_name" ]; then
            # Check Internet connection
            if ping -c 1 google.com &> /dev/null; then
                echo "$(date +'%Y-%m-%d %H:%M:%S') - Internet connection OK" >> "$LOG_DIR/${now}_send_picture.txt"
            else
                # Reset USB
                reset_usb
                # Record action in log file
                echo "$(date +'%Y-%m-%d %H:%M:%S') - USB reset due to loss of Internet connection" >> "$LOG_DIR/${now}_send_picture.txt"
            fi

            system_info "$LOG_DIR/${now}_send_picture.txt"

            echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_send_picture.txt"
            echo "|                           SEND IMAGE HIGH                                |" >> "$LOG_DIR/${now}_send_picture.txt"
            echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_send_picture.txt"

                # Send the image to S3 for HIGH 
                sudo s3cmd put "$image" "$S3_ENDPOINT_HIGH/" >> "$LOG_DIR/${now}_send_picture.txt"
                if [ $? -eq 0 ]; then

                    echo "Image $image_name successfully sent in high resolution to S3." >> "$LOG_DIR/${now}_send_picture.txt"
                else
                    echo "Error sending image $image_name in high resolution to S3" >> "$LOG_DIR/${now}_send_picture.txt"
                fi
                # Append a separator line to the log file
                echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_send_picture.txt"
                echo "|                           SEND IMAGE LOW                                 |" >> "$LOG_DIR/${now}_send_picture.txt"
                echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_send_picture.txt"

                # Send the image to S3 for LOW
                sudo s3cmd put "$PICTURES_LOW/$image_name" "$S3_ENDPOINT_LOW/" >> "$LOG_DIR/${now}_send_picture.txt"
                if [ $? -eq 0 ]; then
                    echo "Image $image_name successfully sent in low resolution to S3" >> "$LOG_DIR/${now}_send_picture.txt"

                    ############### send picture and data to database
                    send_database $image_name $now $DATABASE_DIR >> "$LOG_DIR/${now}_send_picture.txt"
                    # Delete  image after successful sending
                    rm "$PICTURES_LOW/$image_name" 
                    rm "$image"
                else

                    echo "Error sending image $image_name in low resolution to S3" >> "$LOG_DIR/${now}_send_picture.txt"
                fi
            end=$(date +%s)
            elapsed_time=$((end - start))
            # Display the elapsed time
            echo "Send finished execution in $elapsed_time seconds" >> "$LOG_DIR/${now}_send_picture.txt" 
            # Append a separator line to the log file
        fi
        if [ -f "$PICTURES_RAW/${now}.nef" ]; then
            # Append a separator line to the log file
                echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_send_picture.txt"
                echo "|                           SEND IMAGE RAW                                 |" >> "$LOG_DIR/${now}_send_picture.txt"
                echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_send_picture.txt"
                # Send the image to S3 for RAW
                sudo s3cmd put "$PICTURES_RAW/${now}.nef" "$S3_ENDPOINT_RAW/" >> "$LOG_DIR/${now}_send_picture.txt"
                if [ $? -eq 0 ]; then
                    echo "Image ${now}.nef successfully sent  to S3" >> "$LOG_DIR/${now}_send_picture.txt"
                    rm "${now}.nef"
                else

                    echo "Error sending image ${now}.nef to S3" >> "$LOG_DIR/${now}_send_picture.txt"
                fi
            echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_send_picture.txt"
            echo "|                             END SEND                                     |" >> "$LOG_DIR/${now}_send_picture.txt"
            echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_send_picture.txt"
        fi
        # Increment the counter for processed images
        ((count++))
        if [ $count -eq $MAX_IMAGES ]; then
            echo "Maximum number of images processed. Exiting..."
            break
        fi
    done
}
#----------------------------------------------------------------------------------------------#
                                #SEND TO S3#
#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

send_blur()
{
    local PICTURES_BLUR=$1
    local LOG_DIR=$2
    local DATABASE_DIR=$3

    image_list=($(ls -1t "$PICTURES_BLUR"/*.jpg))

    #IMAGES REMAINING TO BE SENT
    num_images=${#image_list[@]}

    local MAX_IMAGES=5  # Maximum number of images to process
    local count=0  # Counter for processed images
    # Iterate through each image
    for image in "${image_list[@]}"; do
        start=$(date +%s)
        # Extract image filename
        image_name=$(basename "$image")
        # Image capture date
        now=$(echo "$image_name" | sed 's/\.jpg$//g')
        # Check Internet connection
        if ping -c 1 google.com &> /dev/null; then
            echo "$(date +'%Y-%m-%d %H:%M:%S') - Internet connection OK" >> "$LOG_DIR/${now}_send_picture.txt"
        else
            # Reset USB
            reset_usb
            # Record action in log file
            echo "$(date +'%Y-%m-%d %H:%M:%S') - USB reset due to loss of Internet connection" >> "$LOG_DIR/$(date +'%Y-%m-%d')_send_picture.txt"
        fi
        system_info "$LOG_DIR/${now}_send_picture.txt"

        echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_send_picture.txt"
        echo "|                           SEND IMAGE                                     |" >> "$LOG_DIR/${now}_send_picture.txt"
        echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_send_picture.txt"

        
        # Send the image to S3 for HIGH with retry
        sudo s3cmd put "$image" "$S3_ENDPOINT_BLUR/" >> "$LOG_DIR/${now}_send_picture.txt"
        if [ $? -eq 0 ]; then
            echo "Image blur $image_name successfully sent in high resolution to S3." >> "$LOG_DIR/${now}_send_picture.txt"

            ############### send picture and data to database
            send_database $image_name $now $DATABASE_DIR
            rm "$image"
        else
            echo "Error sending image blur $image_name in high resolution to S3 " >> "$LOG_DIR/${now}_send_picture.txt"
        fi
      
        end=$(date +%s)
        elapsed_time=$((end - start))
        # Display the elapsed time
        echo "Send finished execution in $elapsed_time seconds" >> "$LOG_DIR/${now}_send_picture.txt" 
        echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_send_picture.txt"
        echo "|                              END SEND                                    |" >> "$LOG_DIR/${now}_send_picture.txt"
        echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${now}_send_picture.txt"
    done

    # Increment the counter for processed images
    ((count++))
    if [ $count -eq $MAX_IMAGES ]; then
        echo "Maximum number of images processed. Exiting..."
        break
    fi
}
#----------------------------------------------------------------------------------------------#
                                #SEND TO S3#
#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################
send_log() {
    local LOG_DIR=$1

    # Get the last 12 log files sorted by modification date
    log_files=($(ls -t "$LOG_DIR"/*.txt | head -n 12))

    for log_file in "${log_files[@]}"; do
        # Check if log file exists
        if [ -f "$log_file" ]; then
            # Send log file to S3
            sudo s3cmd put "$log_file" "$S3_ENDPOINT_LOG/"

            # Check if sending was successful
            if [ $? -eq 0 ]; then
                echo "Log file $log_file successfully sent to S3"
                # Delete the log file after successful sending
                rm "$log_file"
            else
                echo "Error sending log file $log_file to S3"
            fi
        fi
    done
}
#----------------------------------------------------------------------------------------------#
                                #SEND FTP#
#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

# Function to check if the file exists on the FTP server
    file_exists_on_ftp() {
        image_name=$1
        curl -s -u "${FTP_USER}:${FTP_PASS}" "ftp://${FTP_SERVER}/${REMOTE_DIR}/" | grep -q "${image_name}"
        return $?
    }
#----------------------------------------------------------------------------------------------#
                                #SEND FTP#
#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

# Fonction pour envoyer les images au serveur FTP
send_ftp_pictures() {
   
    # Liste des images dans le répertoire local
    REMOTE_DIR=$1
    image_list=$2
    DATABASE_DIR=$3
    # Itérer à travers chaque image
    for image in "${image_list[@]}"; do
        # Extraire le nom du fichier image
        image_name=$(basename "$image")
        
        # Image capture date
        now=$(echo "$image_name" | sed 's/\.[^.]*$//g')
        # Vérifier si le répertoire existe
        curl -s -u "${FTP_USER}:${FTP_PASS}" "ftp://${FTP_SERVER}/${REMOTE_DIR}/" > /dev/null
        if [ $? -ne 0 ]; then
            # Le répertoire n'existe pas, le créer et envoyer le fichier
            curl -T "${image}" -u "${FTP_USER}:${FTP_PASS}" --ftp-create-dirs "ftp://${FTP_SERVER}/${REMOTE_DIR}/${image_name}" && {
                echo "The directory ${REMOTE_DIR} was successfully created and the file ${image_name} was uploaded."
                rm "${image}"
                if [[ data_storage == *"Server"* ]]; then
                    send_database $image_name $now $DATABASE_DIR
                fi
            } || {
                echo "Error uploading the file ${image_name} to the directory ${REMOTE_DIR}."
            }
        else
            # Le répertoire existe, vérifier si le fichier existe déjà
            if file_exists_on_ftp $image_name; then
                echo "The file ${image_name} already exists in the directory ${REMOTE_DIR}."
            else
                # Le fichier n'existe pas, le télécharger
                curl -T "${image}" -u "${FTP_USER}:${FTP_PASS}" "ftp://${FTP_SERVER}/${REMOTE_DIR}/${image_name}" && {
                    echo "The file ${image_name} was uploaded to the directory ${REMOTE_DIR}."
                    rm "${image}"
                    if [[ data_storage == *"Server"* ]]; then
                        send_database $image_name $now $DATABASE_DIR
                    fi
                } || {
                    echo "Error uploading the file ${image_name} to the directory ${REMOTE_DIR}."
                }
            fi
        fi
    done
}
#----------------------------------------------------------------------------------------------#
                                #SEND FTP#
#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################
send_log_ftp() {
    local LOG_DIR=$1
    
    # Créer le répertoire distant s'il n'existe pas
    curl -s -u "${FTP_USER}:${FTP_PASS}" "ftp://${FTP_SERVER}/${REMOTE_DIR_LOG}/" > /dev/null
    if [ $? -ne 0 ]; then
        echo "Remote directory ${REMOTE_DIR_LOG} does not exist, creating..."
        curl -u "${FTP_USER}:${FTP_PASS}" "ftp://${FTP_SERVER}/${REMOTE_DIR_LOG}/" --ftp-create-dirs
    fi

    # Envoyer tous les fichiers journaux vers FTP et les supprimer ensuite
    for log_file in "$LOG_DIR"/*.txt; do
        # Vérifier si le fichier journal existe
        if [ -f "$log_file" ]; then
            # Vérifier si le fichier journal est en cours d'accès par un autre processus
            if lsof "$log_file" >/dev/null 2>&1; then
                echo "Log file $log_file is still being accessed, skipping..."
            else
                # Envoyer le fichier journal vers FTP
                curl -T "${log_file}" -u "${FTP_USER}:${FTP_PASS}" "ftp://${FTP_SERVER}/${REMOTE_DIR_LOG}/$(basename "$log_file")"

                # Vérifier si l'envoi a réussi
                if [ $? -eq 0 ]; then
                    echo "Log file $log_file successfully sent to FTP"
                    # Supprimer le fichier journal après un envoi réussi
                    rm "$log_file"
                else
                    echo "Error sending log file $log_file to FTP"
                fi
            fi
        fi
    done
}
#----------------------------------------------------------------------------------------------#
                                #SEND USB#
#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

# Définition de la fonction pour déplacer les fichiers conditionnellement
move_files_if_exists() {
    # Arguments de la fonction
    local source_dir="$1"
    local destination_dir="$2"
    local check_dir="$3"

    # Vérifier et créer le répertoire de destination si nécessaire
    mkdir -p "$destination_dir"

    # Boucle à travers les fichiers dans le répertoire source
    for file in "$source_dir"/*; do
        # Vérifie si c'est un fichier régulier
        if [ -f "$file" ]; then
            # Extraire le nom de base du fichier
            filename=$(basename "$file")
            
            # Vérifier si le fichier existe dans le répertoire check_dir
            if [ -f "$check_dir/$filename" ]; then
                # Déplacer le fichier vers le répertoire de destination
                mv "$file" "$destination_dir"
                echo "Fichier $filename déplacé vers $destination_dir"
            else
                echo "Fichier $filename non trouvé dans $check_dir, non déplacé."
            fi
        fi
    done
}

usb_send_picture()
{
    mkdir -p /mnt/usb/DATABASE
    model=$(cat /proc/device-tree/model)
    if [[ "$model" == *"Raspberry Pi"* ]]; then
        move_files_if_exists /DATA/HIGH /mnt/usb/HIGH /DATA/img_send_usb_HIGH
        move_files_if_exists /DATA/RAW /mnt/usb/RAW /DATA/img_send_usb_RAW
        mv /DATA/DATABASE/* /mnt/usb/DATABASE/
    elif [[ "$model" == *"NanoPi"* ]]; then

        #from NanoPi
        move_files_if_exists /DATA/HIGH /mnt/usb/HIGH /DATA/img_send_usb_HIGH
        move_files_if_exists /DATA/RAW /mnt/usb/RAW /DATA/img_send_usb_RAW
        mv /DATA/DATABASE/* /mnt/usb/DATABASE/

        #from sdcard
        move_files_if_exists /mnt/sdcard/HIGH /mnt/usb/HIGH /mnt/sdcard/img_send_usb_HIGH
        move_files_if_exists /mnt/sdcard/RAW /mnt/usb/RAW /mnt/sdcard/img_send_usb_RAW
        mv /mnt/sdcard/DATABASE/* /mnt/usb/DATABASE/
    fi
    rm /mnt/usb/HIGH/*jpg_exiftool_tmp
    rm /mnt/usb/RAW/*jpg_exiftool_tmp
}
#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

usb_send_log() {
    # Define source and destination paths
    source_dirs=(
        "/mnt/sdcard/LOG"
        "/DATA/LOG"
    )
    destination_dir="/mnt/usb/LOG"

    # Create the destination directory if it does not exist
    mkdir -p "$destination_dir"

    # Check and move files if the source directories are not empty
    for source_dir in "${source_dirs[@]}"; do
        if [ -d "$source_dir" ] && [ "$(ls -A "$source_dir")" ]; then
            # Move the contents of the source directory to the destination directory
            mv "$source_dir"/* "$destination_dir"
            echo "Contents of $source_dir moved to $destination_dir"
        else
            echo "The directory $source_dir is empty or does not exist"
        fi
    done
}

#############################################################################
##                               MAIN                                      ##
#############################################################################
# Get the box identifier
getID

# Configure s3cmd here after getting id to have UDID
S3_BUCKET="timelapsestorage"
S3_BUCKET_BLUR="timelapseblur"
S3_ENDPOINT_HIGH="s3://$S3_BUCKET/$UDID/HIGH"
S3_ENDPOINT_LOW="s3://$S3_BUCKET/$UDID/LOW"
S3_ENDPOINT_LOG="s3://$S3_BUCKET/$UDID/LOG"
S3_ENDPOINT_RAW="s3://$S3_BUCKET/$UDID/RAW"
S3_ENDPOINT_BLUR="s3://$S3_BUCKET_BLUR/$UDID/HIGH"
# Destination URL
url="https://prod.timelapsego.com/rest/box/$UDID/pictures"

# get value is_no_transfer from JSON_FILE
no_transfer=$(jq -r '.is_no_transfer' "$JSON_FILE")
is_blur=$(jq -r '.is_blur' "$JSON_FILE")
power_supply=$(jq -r '.type' "$JSON_FILE")
no_transfer_voltage=$(jq -r '.no_transfer_voltage' "$JSON_FILE")
no_picture_voltage=$(jq -r '.no_picture_voltage' "$JSON_FILE")
img_storage=$(jq -r '.img_storage' "$JSON_FILE")
data_storage=$(jq -r '.data_storage' "$JSON_FILE")
log_storage=$(jq -r '.log_storage' "$JSON_FILE")


voltage=$(jq -r '.voltage'  /home/pi/data/system_info.json)
CONFIG_FILE="/boot/ftp_config.json"


if [[ $img_storage == *"USB"* ]] || [[ $log_storage == *"USB"* ]]; then
    # Mount point path
    MOUNT_POINT="/mnt/usb" 
    # Create the mount point directory if it doesn't exist
    mkdir -p "$MOUNT_POINT"
    # Detect USB devices
    for device in /dev/sd*; do
        if [ -b "$device" ]; then
        # Check if the device is a partition and not a whole disk
        if lsblk -no pkname "$device" | grep -q '^sd'; then
            sudo mount "$device" "$MOUNT_POINT"
            if [ $? -eq 0 ]; then
                echo "Successfully mounted $device at $MOUNT_POINT"
            else
                echo "Failed to mount $device"
            fi
        fi
        fi
    done
fi


if [ -e $CONFIG_FILE ]; then

    # Extraire les valeurs du fichier JSON
    FTP_SERVER=$(jq -r '.FTP_SERVER' "$CONFIG_FILE")
    FTP_USER=$(jq -r '.FTP_USER' "$CONFIG_FILE")
    FTP_PASS=$(jq -r '.FTP_PASS' "$CONFIG_FILE")
    REMOTE_DIR_HIGH=$(jq -r '.REMOTE_DIR_HIGH' "$CONFIG_FILE")
    REMOTE_DIR_LOG=$(jq -r '.REMOTE_DIR_LOG' "$CONFIG_FILE")
    REMOTE_DIR_RAW=$(jq -r '.REMOTE_DIR_RAW' "$CONFIG_FILE")

        # create Dir if not exist
    create_remote_dir() {
        local dir="$1"
        curl -s -u "$FTP_USER:$FTP_PASS" --create-dirs -o /dev/null "ftp://$FTP_SERVER/$dir/"
    }
    # create Dir if not exist
    create_remote_dir "$REMOTE_DIR_HIGH"
    create_remote_dir "$REMOTE_DIR_LOG"
    create_remote_dir "$REMOTE_DIR_RAW"
fi

################################################################################### 
#                                 PICTURES
###################################################################################

#-----------------------------------------------------------------------------#
#                              CASE FTP                                       #
#-----------------------------------------------------------------------------#

if [[ $img_storage == *"FTP"* ]]; then
    #### image HIGH
    image_list=($(ls -1t /DATA/HIGH/*.jpg))
    send_ftp_pictures $REMOTE_DIR_HIGH $image_list /DATA/DATABASE
    #######################################
    #### image RAW
    image_list_Raw=($(ls -1t /DATA/RAW/*.nef))
    send_ftp_pictures $REMOTE_DIR_RAW $image_list_Raw /DATA/DATABASE
    #######################################
    #### image HIGH
    image_list_sd=($(ls -1t /mnt/sdcard/HIGH/*.jpg))
    send_ftp_pictures $REMOTE_DIR_HIGH $image_list_sd /mnt/sdcard/DATABASE
    #######################################
    #### image RAW
    image_list_Raw_sd=($(ls -1t /DATA/RAW/*.nef))
    send_ftp_pictures $REMOTE_DIR_RAW $image_list_Raw_sd /mnt/sdcard/DATABASE
    #######################################
fi   
    
#-----------------------------------------------------------------------------#
#                              CASE S3                                        #
#-----------------------------------------------------------------------------#

if [[ $img_storage == *"S3"* ]] && [[ "$no_transfer" == "false" ]] && (( $(echo "$voltage > $no_transfer_voltage" | bc -l) )); then
  
    # Envoyer les photos depuis Pi
    send_picture /DATA/HIGH /DATA/LOW /DATA/LOG /DATA/DATABASE /DATA/RAW
    # Envoyer les photos depuis la carte SD 
    send_picture /mnt/sdcard/HIGH /mnt/sdcard/LOW /mnt/sdcard/LOG /mnt/sdcard/DATABASE /mnt/sdcard/RAW
            
    ## Depuis Pi 
    send_blur /DATA/BLUR /DATA/LOG /DATA/DATABASE
    ### Depuis la carte SD
    send_blur /mnt/sdcard/BLUR /mnt/sdcard/LOG /mnt/sdcard/DATABASE  
fi

#-----------------------------------------------------------------------------#
#                              CASE USB                                       #
#-----------------------------------------------------------------------------#
 
if [[ $img_storage == *"USB"* ]]; then
    if lsblk -o NAME,MOUNTPOINT | grep -q "/mnt/usb"; then
        usb_send_picture
        # Vérifier si le répertoire existe et contient des fichiers .json
        if [[ $data_storage == *"Server"* ]] && [[ -d "/mnt/usb/DATABASE" ]]; then
            if ping -q -c 1 -W 1 pool.ntp.org >/dev/null; then 
                # Boucle pour parcourir tous les fichiers .json dans le répertoire
                for file in "/mnt/usb/DATABASE"/*.json; do
                    # Vérifier si des fichiers .json existent
                    if [ -e "$file" ]; then
                        # Extraire le nom du fichier sans le chemin
                        file_name=$(basename "$file" .json)
                        send_database ${file_name}.jpg $file_name /mnt/usb/DATABASE
                    else
                        # Si aucun fichier .json n'est trouvé
                        echo "Aucun fichier .json trouvé dans $source_dir"
                        break
                    fi
                done
            fi
        fi
        sudo sync
    else
        echo "/mnt/usb is not associated with any device."
    fi
fi


################################################################################### 
#                                 LOG
###################################################################################
#-----------------------------------------------------------------------------#
#                              CASE FTP                                       #
#-----------------------------------------------------------------------------#

if [[ $log_storage == *"FTP"* ]]; then 
    #### LOG ##########
    send_log_ftp /DATA/LOG
    ###################
    #### Nano PI 
    send_log_ftp /mnt/sdcard/LOG
    ##########################
fi  

#-----------------------------------------------------------------------------#
#                              CASE S3                                        #
#-----------------------------------------------------------------------------#

if [[ $log_storage == *"S3"* ]] && (( $(echo "$voltage > $no_transfer_voltage" | bc -l) )); then

    # Envoyer les logs depuis  Pi
    send_log  /DATA/LOG
    # Envoyer les logs depuis la carte SD
    send_log  /mnt/sdcard/LOG
fi

#-----------------------------------------------------------------------------#
#                              CASE USB                                       #
#-----------------------------------------------------------------------------#
 
if [[ $log_storage == *"USB"* ]]; then
    if lsblk -o NAME,MOUNTPOINT | grep -q "/mnt/usb"; then
        usb_send_log
        sudo sync
    else
        echo "/mnt/usb is not associated with any device."
    fi
fi



#######  si la tension est plus petit de tension d'envoi envoyer la tension au base des donnes ( une fois toutes les deux heures)
if (( $(echo "$voltage < $no_transfer_voltage" | bc -l) )); then
    # Check if the last update file exists
    if [ -f "$last_send_voltage" ]; then
        # Read the last modification time of the file in seconds since Unix epoch
        last_time=$(stat -c %Y "$last_send_voltage")   
    else
        # If the file doesn't exist, initialize last_time to 0
        last_time=0
    fi

    # Get the current time in seconds since Unix epoch
    current_time=$(date +%s)

    # Calculate the time difference in seconds
    time_diff=$((current_time - last_time))

    # Calculate the absolute value of time_diff
    if [ "$time_diff" -lt 0 ]; then
        time_diff=$((time_diff * -1))
    fi
    if [ "$time_diff" -gt 7200 ]; then
        now="$(date +"%Y_%m_%d_%H_%M_%S")"
        voltage_data=$voltage*100
        curl -i --max-time 120 --connect-timeout 60 --write-out "%{http_code}" -X POST "$url" \
                -H "Content-Type: application/json" \
                -d '[{"name": "'"$now"'", "date": "'"$now"'",  "data_voltage": "'"$voltage_data"'" }]'
     
        touch $last_send_voltage
    fi
fi
