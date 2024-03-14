#!/bin/bash

# include global vars and functions
. "/home/pi/scripts/global.sh"

LOG_DIR="/home/pi/logs"

extract_UDID() {
    # Check and create data directory if it doesn't exist
    if [ ! -d "/home/pi/data" ]; then
        mkdir /home/pi/data
    fi

    # Check if config.json file exists
    if [ -f "/home/pi/data/config.json" ]; then
        # Extract uniquekey value from config.json file
        UDID=$(jq -r '.uniquekey' /home/pi/data/config.json)

        # Check if UDID.txt file exists, otherwise create it
        if [ ! -f "/home/pi/data/UDID.txt" ]; then
            touch /home/pi/data/UDID.txt
        else
            # If UDID.txt file exists, clear its contents
            > /home/pi/data/UDID.txt
        fi

        # Write uniquekey value to UDID.txt file
        echo "$UDID" > /home/pi/data/UDID.txt

        echo "The uniquekey value has been extracted and saved in UDID.txt." >> "$LOG_DIR/${current_date}_config.txt"
    else
        echo "The config.json file does not exist. No action performed." >> "$LOG_DIR/${current_date}_config.txt"
    fi
}

update_credentials() {
    # Check and create data directory if it doesn't exist
    if [ ! -d "/home/pi/data" ]; then
        mkdir /home/pi/data
    fi

    # Check if config.json file exists
    if [ -f "/home/pi/data/config.json" ]; then
        # Extract s3_access_key and s3_secret_key values from config.json file
        s3_access_key=$(jq -r '.s3_access_key' /home/pi/data/config.json)
        s3_secret_key=$(jq -r '.s3_secret_key' /home/pi/data/config.json)

        # Check if .aws directory exists, otherwise create it
        if [ ! -d "/home/pi/.aws" ]; then
            mkdir /home/pi/.aws
        fi

        # Create credentials file if it doesn't exist
        if [ ! -f "/home/pi/.aws/credentials" ]; then
            touch /home/pi/.aws/credentials
            chmod 600 /home/pi/.aws/credentials
        fi

        # Update [default] profile in credentials file
        if [ -n "$s3_access_key" ] && [ -n "$s3_secret_key" ]; then
            echo "[default]" > /home/pi/.aws/credentials
            echo "aws_access_key_id = $s3_access_key" >> /home/pi/.aws/credentials
            echo "aws_secret_access_key = $s3_secret_key" >> /home/pi/.aws/credentials

            echo "AWS credentials have been successfully updated." >> "$LOG_DIR/${current_date}_config.txt"
        else
            echo "s3_access_key and/or s3_secret_key values are not present in the JSON file. No action performed." >> "$LOG_DIR/${current_date}_config.txt"
        fi
    else
        echo "The config.json file does not exist. No action performed." >> "$LOG_DIR/${current_date}_config.txt"
    fi
}

configure_SD_card() {
    # Check and create data directory if it doesn't exist
    if [ ! -d "/home/pi/data" ]; then
        mkdir /home/pi/data
    fi

    # Mount SD card
    sudo mount /dev/mmcblk1p1 /mnt

    # Check if mount was successful
    if [ $? -ne 0 ]; then
        echo "No SD card detected" >> "$LOG_DIR/${current_date}_config.txt"
        return 1
    fi

    # Check if SD card is detected
    if [ -d "/mnt" ]; then
        echo "SD card detected" >> "$LOG_DIR/${current_date}_config.txt"

        # Search for JSON file on SD card
        for file in /mnt/*.json; do
            if [ -f "$file" ]; then
                echo "JSON file found: $file" >> "$LOG_DIR/${current_date}_config.txt"
                # Remove existing config.json file in /home/pi/data
                if [ -f "/home/pi/data/config.json" ]; then
                    sudo rm -f /home/pi/data/config.json
                fi
                # Copy JSON file from SD card and rename it
                sudo cp "$file" /home/pi/data/config.json
                # Unmount SD card
                sudo umount /mnt

                # Execute other functions
                extract_UDID
                update_credentials

                return 1
            fi
        done

        # If no JSON file is found on SD card
        echo "No JSON file found on SD card. No updates possible." >> "$LOG_DIR/${current_date}_config.txt"
        # Unmount SD card
        sudo umount /mnt
        return 1
    else
        echo "No SD card detected. No updates possible." >> "$LOG_DIR/${current_date}_config.txt"
        return 1
    fi
}

update_file_config() {
    # Check if a camera is detected
    
        getID
        URL_CONFIG="https://prod.timelapsego.com/rest/box/$UDID/config"

        # Full path to camera configuration file
        local output_file="/home/pi/data/config.json"

        # Existing file content if it exists
        local existing_content=""
        if [ -f "$output_file" ]; then
            existing_content=$(<"$output_file")
        fi

        # Retrieve JSON content with curl
        local new_content=$(curl -s -o /dev/null -w "%{http_code}" "$URL_CONFIG")
        
        # Check curl return code
        if [ "$new_content" -eq 200 ]; then
            echo "Connection to fetch camera configuration successful" >> "$LOG_DIR/${current_date}_config.txt"
            # Retrieve JSON content with curl and write to file
            new_content=$(curl -s "$URL_CONFIG")
            
            # Compare existing content with new content
            if [ "$existing_content" != "$new_content" ]; then
                # Overwrite existing file with new content
                echo "$new_content" > "$output_file"
                
           
            fi
       
        fi
}




# Chemin vers le fichier JSON
JSON_FILE="/home/pi/data/config.json"

# Chemin vers votre script de prise de photo
TAKE_SCRIPT="/home/pi/scripts/take_picture.sh"

# Nom du fichier de configuration pour les tâches cron
CRON_FILE="/etc/cron.d/take_picture"

# Fonction pour extraire la fréquence de capture du fichier JSON pour un job spécifique
get_frequency() {
    jq -r ".jobs[$1].frequency" "$JSON_FILE" | cut -d' ' -f1
}

# Fonction pour extraire les heures spécifiées du fichier JSON pour un job spécifique
get_hours() {
    jq -r ".jobs[$1].frequency" "$JSON_FILE" | cut -d' ' -f2
}

# Fonction pour extraire les jours spécifiés du fichier JSON pour un job spécifiquels
get_days() {
    jq -r ".jobs[$1].frequency" "$JSON_FILE" | cut -d' ' -f5
}

# Fonction pour extraire la valeur de is_trigger_sms du fichier JSON
get_is_trigger_sms() {
    jq -r '.is_trigger_sms' "$JSON_FILE"
}

# Fonction pour extraire la valeur de is_no_transfer du fichier JSON
get_is_no_transfer() {
    jq -r '.is_no_transfer' "$JSON_FILE"
}
# Fonction pour créer la tâche Cron pour un job spécifique
set_cron_for_job() {
    local job_index=$1
    frequency=$(get_frequency "$job_index")
    hours=$(get_hours "$job_index")
    days=$(get_days "$job_index")
    image_size=$(jq -r --argjson index "$job_index" '.jobs[$index].imagesize' "$JSON_FILE")
    iso=$(jq -r --argjson index "$job_index" '.jobs[$index].iso' "$JSON_FILE")
    fnumber=$(jq -r --argjson index "$job_index" '.jobs[$index].fnumber' "$JSON_FILE")
    shutterspeed=$(jq -r --argjson index "$job_index" '.jobs[$index].shutterspeed' "$JSON_FILE")
    image_quality=$(jq -r --argjson index "$job_index" '.jobs[$index].jpgquality' "$JSON_FILE")
    cron_expression="$frequency $hours * * $days pi /bin/bash $TAKE_SCRIPT $image_size $iso $fnumber $shutterspeed $image_quality"
    # Écrit la tâche Cron dans le fichier de configuration en ajoutant au lieu d'écraser
    echo "$cron_expression" >> "$CRON_FILE"
}

# Fonction pour mettre à jour les tâches Cron pour tous les jobs
update_cron_for_all_jobs() {
    # Supprime le fichier de configuration existant s'il existe
    rm -f "$CRON_FILE"
    # Crée un fichier vide pour le fichier de configuration
    touch "$CRON_FILE"
    # Parcourt tous les jobs pour créer les tâches cron
    num_jobs=$(jq '.jobs | length' "$JSON_FILE")
    for ((i=0; i<num_jobs; i++)); do
        set_cron_for_job "$i"
    done
}

update_cron_sms() {
    # Récupérer la valeur de is_trigger_sms
    is_trigger_sms=$(get_is_trigger_sms)

    # Chemin vers le fichier de configuration pour les tâches cron
    CRON_FILE="/etc/cron.d/sms"

    

    # Supprimer le fichier de configuration existant s'il existe
    sudo rm -f "$CRON_FILE"

    # Créer un fichier vide pour le fichier de configuration
    sudo touch "$CRON_FILE"

    # Vérifier si is_trigger_sms est "true"
    if [ "$is_trigger_sms" == "true" ]; then
        # Si oui, ajouter une entrée dans le fichier de configuration Cron pour lancer le script au démarrage
	 # Si oui, lancer le script SMS une seule fois en arrière-plan
        /bin/bash /home/pi/scripts/sms.sh &
        echo "@reboot root /bin/bash /home/pi/scripts/sms.sh" | sudo tee -a "$CRON_FILE" 
        echo "La tâche Cron pour lancer le script SMS au démarrage a été ajoutée."
    else
        # Vérifier si le script SMS est déjà en cours d'exécution
        if pgrep -x "sms.sh" >/dev/null; then
        # Si oui, le tuer
        sudo pkill -x sms.sh
        echo "Le processus sms.sh en cours d'exécution a été arrêté avant d'ajouter la tâche Cron."
        fi
    fi
}



update_cron_send() {
    if [ "$is_no_transfer" == "true" ]; then
        # Si oui, supprimer la tâche Cron pour envoyer des données
        sudo rm -f "/etc/cron.d/check_send_data"
        echo "La tâche Cron pour envoyer des données a été supprimée car is_no_transfer est 'true'."
    else
        # Si non, créer la tâche Cron pour envoyer des données
        echo "*/1 * * * * root /bin/bash /home/pi/scripts/check_send_data.sh" | sudo tee "/etc/cron.d/check_send_data" >/dev/null
        echo "La tâche Cron pour envoyer des données a été ajoutée."
    fi
}












#################################################################################################
#                                     Main
#################################################################################################

current_date="$(date +"%Y_%m_%d_%H_%M_%S")"

# Call function to configure SD card
echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${current_date}_config.txt"
echo "|             UPDATING  CONFIGURATION FILE SD CARD                         |" >> "$LOG_DIR/${current_date}_config.txt"
echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${current_date}_config.txt"

#configure_SD_card

# Call function to update web configuration
echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${current_date}_config.txt"
echo "|             UPDATING  CONFIGURATION FILE WEB                             |" >> "$LOG_DIR/${current_date}_config.txt"
echo "+--------------------------------------------------------------------------+" >> "$LOG_DIR/${current_date}_config.txt"
update_file_config



update_cron_for_all_jobs

update_cron_sms

update_cron_send
