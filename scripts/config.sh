#!/bin/bash

# include global vars and functions
. "/home/pi/scripts/global.sh"

LOG_DIR="/DATA/LOG"

# Chemin vers le fichier JSON
JSON_FILE="/home/pi/data/config.json"

# Chemin vers votre script de prise de photo
TAKE_SCRIPT="/home/pi/scripts/take_picture.sh"

# Nom du fichier de configuration pour les tâches cron taka_picture
CRON_FILE="/etc/cron.d/take_picture"

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

# Function to extract capture frequency from JSON file for a specific job
get_frequency() {
    jq -r ".jobs[$1].frequency" "$JSON_FILE" | cut -d' ' -f1
}

# Function to extract specified hours from JSON file for a specific job
get_hours() {
    jq -r ".jobs[$1].frequency" "$JSON_FILE" | cut -d' ' -f2
}

# Function to extract specified days from JSON file for a specific job
get_days() {
    jq -r ".jobs[$1].frequency" "$JSON_FILE" | cut -d' ' -f5
}

# Function to extract the value of is_trigger_sms from the JSON file
get_is_trigger_sms() {
    jq -r '.is_trigger_sms' "$JSON_FILE"
}

# Function to extract the value of is_no_transfer from the JSON file
get_is_no_transfer() {
    jq -r '.is_no_transfer' "$JSON_FILE"
}

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

# Function to create a Cron task for a specific job
set_cron_for_job()
{
    # Retrieve the index of the job
    local job_index=$1
    
    # Retrieve frequency, hours, and days from the JSON file for the specified job
    frequency=$(get_frequency "$job_index")
    hours=$(get_hours "$job_index")
    days=$(get_days "$job_index")

    # Retrieve image size, ISO, f-number, shutter speed, and image quality from the JSON file for the specified job
    image_size=$(jq -r --argjson index "$job_index" '.jobs[$index].imagesize' "$JSON_FILE")
    iso=$(jq -r --argjson index "$job_index" '.jobs[$index].iso' "$JSON_FILE")
    fnumber=$(jq -r --argjson index "$job_index" '.jobs[$index].fnumber' "$JSON_FILE")
    shutterspeed=$(jq -r --argjson index "$job_index" '.jobs[$index].shutterspeed' "$JSON_FILE")
    image_quality=$(jq -r --argjson index "$job_index" '.jobs[$index].jpgquality' "$JSON_FILE")
    mode=$(jq -r --argjson index "$job_index" '.jobs[$index].boxmode' "$JSON_FILE")
 
    if [ "$mode" = "burst_20" ]; then
        # Construct the Cron expressions
        cron_expression="* $hours * * $days root /bin/bash $TAKE_SCRIPT 0 $image_size $iso $fnumber $shutterspeed $image_quality $mode"
        cron_expression+="\n* $hours * * $days root /bin/bash $TAKE_SCRIPT 20 $image_size $iso $fnumber $shutterspeed $image_quality $mode"
        cron_expression+="\n* $hours * * $days root /bin/bash $TAKE_SCRIPT 40 $image_size $iso $fnumber $shutterspeed $image_quality $mode"
        # Write the Cron expressions into the configuration file
        echo -e "$cron_expression" >> "$CRON_FILE"
    elif [ "$mode" = "burst_30" ]; then
        # Construct the Cron expressions
        cron_expression="* $hours * * $days root /bin/bash $TAKE_SCRIPT 0 $image_size $iso $fnumber $shutterspeed $image_quality $mode"
        cron_expression+="\n* $hours * * $days root /bin/bash $TAKE_SCRIPT 30 $image_size $iso $fnumber $shutterspeed $image_quality $mode"

        # Write the Cron expressions into the configuration file
        echo -e "$cron_expression" >> "$CRON_FILE"
    else
        # Construct the default Cron expression
        cron_expression="$frequency $hours * * $days root /bin/bash $TAKE_SCRIPT 0 $image_size $iso $fnumber $shutterspeed $image_quality $mode"

        # Write the default Cron expression into the configuration file
        echo "$cron_expression" >> "$CRON_FILE"
    fi
}
#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

# Function to update Cron tasks for all jobs
update_cron_for_all_jobs() {
    # Remove the existing configuration file if it exists
    rm -f "$CRON_FILE"
    # Create an empty file for the configuration file
    touch "$CRON_FILE"
    # Iterate over all jobs to create Cron tasks
    num_jobs=$(jq '.jobs | length' "$JSON_FILE")
    for ((i=0; i<num_jobs; i++)); do
        set_cron_for_job "$i"
    done

    # Check if the Cron file was successfully updated
    if [ -f "$CRON_FILE" ]; then
        echo "Cron tasks have been updated successfully" >> "$tem_log"
    else
        echo "Failed to update Cron tasks" >> "$tem_log"
    fi
    echo "List of jobs : " >> "$tem_log"
    # Get the number of jobs in the JSON file
    num_jobs=$(jq '.jobs | length' "$JSON_FILE")
    # Browse and display jobs
    for ((i=0; i<num_jobs; i++)); do
                  
        job=$(jq -r ".jobs[$i].frequency" "$JSON_FILE")
        mode=$(jq -r --argjson index "$i" '.jobs[$index].boxmode' "$JSON_FILE")
        echo "Job $((i+1)) : { $job }" >> "$tem_log"
        echo "Boxmode: $mode" >> "$tem_log"
    done
}


#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

# Function to update the SMS Cron task
update_service_sms() {
    # Get the value of is_trigger_sms
    is_trigger_sms=$(get_is_trigger_sms)

    # Check if is_trigger_sms is "true"
    if [ "$is_trigger_sms" == "true" ]; then
        
        # starting service sms 
        sudo systemctl start sms.service
        #Enable the service so that it starts at boot time 
        sudo systemctl enable sms.service
        echo "Service task to launch the SMS script at startup has been added" >> "$tem_log"
        PCB=$(sed -n '2p' /home/pi/data/info.txt)
        ## On camera
        if [ "$PCB" == "PCBv3" ]; then
            # on camera
            sudo tlgo-commands -c 0
        else
            # on camera
            sudo tlgo-commands -c 1
        fi
    else
        # stop service sms 
        sudo systemctl stop sms.service
        #Disable the service so that it starts at boot time
        sudo systemctl disable sms.service

        echo "no service sms,sms triggering is faulse" >> "$tem_log"
        
    fi
}

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

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

        echo "The uniquekey value has been extracted and saved in UDID.txt" >> "$tem_log"
    else
        echo "The config.json file does not exist. No action performed" >> "$tem_log"
    fi
}

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

update_s3()
{
    # Path to the .s3cfg file
    s3cfg_file="/root/.s3cfg"

    # Path to the JSON file containing S3 access keys
    json_file="/home/pi/data/config.json"

    # Check if the JSON file exists
    if [ -f "$json_file" ]; then
        # Extract S3 access keys from the JSON file
        s3_access_key=$(jq -r '.s3_access_key' "$json_file")
        s3_secret_key=$(jq -r '.s3_secret_key' "$json_file")

        # Check if the access keys are not empty
        if [ -n "$s3_access_key" ] && [ -n "$s3_secret_key" ]; then
            # Update the .s3cfg file with the new access keys
            sudo sed -i "s/access_key =.*/access_key = $s3_access_key/g" "$s3cfg_file"
            sudo sed -i 's#secret_key =.*#secret_key = '"$s3_secret_key"'#g' "$s3cfg_file"
            echo "S3 access keys have been successfully updated in $s3cfg_file" >> "$tem_log"
        else
            echo "Error: S3 access keys cannot be empty" >> "$tem_log"
        fi
    else
        echo "Error: The file $json_file does not exist" >> "$tem_log"
    fi

}

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

configure_SD_card() {
    # Check and create data directory if it doesn't exist
    if [ ! -d "/home/pi/data" ]; then
        mkdir /home/pi/data
    fi

    ##############################################################################################################
    ###                                         for nanoPI                                                       ###
    ##############################################################################################################
    # Check if SD card is detected gor nanoPI 
    if [ -d "/mnt/sdcard" ]; then
        # Search for JSON files (including .json and .json.skip) on SD card
        for file in /mnt/sdcard/tlgo_install_box.json /mnt/sdcard/tlgo_install_box.json.skip; do
            if [ -f "$file" ]; then
                echo "JSON file found: $file" >> "$tem_log"
                # Remove existing config.json file in /home/pi/data
                if [ -f "/home/pi/data/config.json" ]; then
                    sudo rm -f /home/pi/data/config.json
                fi
                # Copy JSON file from SD card and rename it
                sudo cp "$file" /home/pi/data/config.json
                #Extract "uniquekey" and "boxname" and write them to the new JSON file .done
		        jq '{uniquekey: .uniquekey, boxname: .boxname}' "$file" > "$file".done
		        rm "$file"

                # Execute other functions
                extract_UDID
                update_s3 ### aws s3

                echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                echo "|          UPDATING  CRON FOR TAKE (JOB)  / SERVICE SMS                    |" >> "$tem_log"
                echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                update_cron_for_all_jobs

                update_service_sms
                return 1
            fi
        done
    fi

    ##############################################################################################################
    ###                                         for raspberryPi                                                ###
    ##############################################################################################################
    if [ -d "/boot" ]; then
        # Search for JSON files (including .json and .json.skip) on SD card
        for file in /boot/tlgo_install_box.json /boot/tlgo_install_box.json.skip; do
            if [ -f "$file" ]; then
                echo "JSON file found: $file" >> "$tem_log"
                # Remove existing config.json file in /home/pi/data
                if [ -f "/home/pi/data/config.json" ]; then
                    sudo rm -f /home/pi/data/config.json
                fi
                # Copy JSON file from SD card and rename it
                sudo cp "$file" /home/pi/data/config.json
                #Extract "uniquekey" and "boxname" and write them to the new JSON file .done
		        jq '{uniquekey: .uniquekey, boxname: .boxname}' "$file" > "$file".done
		        rm "$file"

                # Execute other functions
                extract_UDID
                update_s3 ### aws s3

                echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                echo "|           UPDATING  CRON FOR TAKE (JOB)  / SERVICE SMS                   |" >> "$tem_log"
                echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                update_cron_for_all_jobs

                update_service_sms
            fi
        done
    fi
}
#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################
configure_usb()
{
     if [ -d "/mnt/usb/conf" ]; then
        # Search for JSON files (including .json and .json.skip) on SD card
        for file in /mnt/usb/conf/config.json /mnt/usb/conf/config.json.skip; do
            if [ -f "$file" ]; then
                echo "JSON file found: $file" >> "$tem_log"
                # Remove existing config.json file in /home/pi/data
                if [ -f "/home/pi/data/config.json" ]; then
                    sudo rm -f /home/pi/data/config.json
                fi
                # Copy JSON file from SD card and rename it
                sudo cp "$file" /home/pi/data/config.json
                #Extract "uniquekey" and "boxname" and write them to the new JSON file .done
		        jq '{uniquekey: .uniquekey, boxname: .boxname}' "$file" > "$file".done
		        rm "$file"

                # Execute other functions
                extract_UDID

                echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                echo "|           UPDATING  CRON FOR TAKE (JOB)  / SERVICE SMS                   |" >> "$tem_log"
                echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                update_cron_for_all_jobs

                update_service_sms
            fi
        done
     fi
}

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

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
        # Connection to fetch camera configuration successful
        echo "Connection to fetch camera configuration successful" >> "$tem_log"
        # Retrieve JSON content with curl and write to file
        new_content=$(curl -s "$URL_CONFIG")

        # Compare existing content with new content
        if [ "$existing_content" != "$new_content" ]; then
            # Overwrite existing file with new content
            echo "$new_content" > "$output_file"


            echo "+--------------------------------------------------------------------------+" >> "$tem_log"
            echo "|                    UPDATING  CRON FOR TAKE (JOB) / SMS                   |" >> "$tem_log"
            echo "+--------------------------------------------------------------------------+" >> "$tem_log"
            update_cron_for_all_jobs

            update_service_sms
        else
            echo "No change for cron" >> "$tem_log"
            echo "List of jobs : " >> "$tem_log"
            # Get the number of jobs in the JSON file
            num_jobs=$(jq '.jobs | length' "$JSON_FILE")
            # Browse and display jobs
            for ((i=0; i<num_jobs; i++)); do
                  
                job=$(jq -r ".jobs[$i].frequency" "$JSON_FILE")
                mode=$(jq -r --argjson index "$i" '.jobs[$index].boxmode' "$JSON_FILE")
                echo "Job $((i+1)) : { $job }" >> "$tem_log"
                echo "Boxmode: $mode" >> "$tem_log"
            done
        fi
    else
        # Connection to fetch camera configuration failed
        echo "Failed to fetch camera configuration. HTTP code: $new_content" >> "$tem_log"
    fi
}




#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

sync_time() {

    # Execute the command and store the output in a variable
    date_rtc=$(sudo tlgo-rtc -g)
    # Convert the dates to  timestamps
    timestamp_rtc=$(date -d "$date_rtc" +%s)

    # Lire le fichier JSON et stocker les valeurs dans des variables
    last_date_pi=$(stat -c %Y /home/pi/data/date.txt)


    # Compare the timestamps
    if [ $timestamp_rtc -gt $last_date_pi ]; then
     #   echo "The RTC date is later than the system date."
        sudo tlgo-rtc -s
        echo "The new system date is the RTC date $date_rtc" >> "/home/pi/config.txt"
    else
        # camera_time_seconds=$(gphoto2 --get-config datetime | grep -oP 'Current: \K\d+')
        # if [ $camera_time_seconds -gt $timestamp_last_date ];then 
            # Convert the new system timestamp to date format
        #    date_new_sys=$(date -d "@$camera_time_seconds" +"%Y-%m-%d %H:%M:%S")
            # Set the system time 
        #     sudo date -s "$date_new_sys"
        #else 
            # Exécuter le script Python
          output=$(python3 /home/pi/scripts/cron.py)
          tache_min=$(echo "$output" | awk 'NR==2')
          time_to_sleep=$(($tache_min - 20))
            # Calculate the new system timestamp by adding the sleep time
          timestamp_new_sys=$((last_date_pi + time_to_sleep))
            # Convert the new system timestamp to date format
            date_new_sys=$(date -d "@$timestamp_new_sys" +"%Y-%m-%d %H:%M:%S")
            echo "The new system date is the last date plus the sleep duration: $date_new_sys" >> "/home/pi/config.txt"
            # Set the system time to the calculated new date
            sudo date -s "$date_new_sys"
        # fi
      fi
    # Number of retries
    retries=30
    echo "+--------------------------------------------------------------------------+" >> "/home/pi/config.txt"
    # Attempt to sync time with NTP server multiple times
    for ((attempt=1; attempt<=$retries; attempt++)); do
        # Check if Internet access is available by trying to connect to an NTP server
        if ping -q -c 1 -W 1 pool.ntp.org >/dev/null; then
            # Retrieve time from an NTP server and update system clock
            sudo ntpdate -u pool.ntp.org >> "/home/pi/config.txt" 2>&1
            echo "+--------------------------------------------------------------------------+" >> "/home/pi/config.txt"
            # Update hardware clock (RTC) with system time
            sudo tlgo-rtc -r
            echo "The new system date is synchronized with NTP" >> "/home/pi/config.txt" 2>&1
            # Update camera date 
            #gphoto2 --set-config datetime=`date +%s`
           # date_now=$(date +%s)
          ##  echo "$date_now" > /home/pi/data/date.txt
            # Exit loop if synchronization was successful
            break
        else
            echo "Attempt $attempt: Internet connection not available. Cannot synchronize time" >> "/home/pi/config.txt" 2>&1
        fi
        sleep 2
    done
}

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

update_from_s3() {
    # Get the box identifier
    getID
    S3_ENDPOINT_LOG="s3://$S3_BUCKET/$UDID/LOG"
    # Path to local script
    LOCAL_SCRIPT_PATH="/home/pi/script.sh"
    LOCAL_SCRIPT_DONE_PATH="/home/pi/script.sh.done"
    
    if [ -f "$LOCAL_SCRIPT_PATH" ]; then
    	# Remove the file
    	rm "$LOCAL_SCRIPT_PATH"
    fi
    output_done=$(sudo s3cmd ls "$S3_ENDPOINT_LOG/script.sh.done" 2>/dev/null)
    if [ -n "$output_done" ]; then
      echo "script.sh.done already exists" >> "$tem_log"
    else
    	output=$(sudo s3cmd ls "$S3_ENDPOINT_LOG/script.sh" 2>/dev/null)

	    # Vérifier si le fichier existe en vérifiant la sortie de la commande
   	 if [ -n "$output" ]; then
       	 # File exists, download it
       	 if sudo s3cmd get "$S3_ENDPOINT_LOG/script.sh" "$LOCAL_SCRIPT_PATH" >> "$tem_log" 2>&1; then
        	    # Execute the script
	            chmod +x "$LOCAL_SCRIPT_PATH"
           	 if sudo bash "$LOCAL_SCRIPT_PATH" >> "$tem_log" 2>&1; then
               		 echo "The script was executed successfully." >> "$tem_log"
               		 # Rename the script
               		 mv "$LOCAL_SCRIPT_PATH" "$LOCAL_SCRIPT_DONE_PATH" >> "$tem_log" 2>&1

                # Upload the renamed script back to S3
                if sudo s3cmd put "$LOCAL_SCRIPT_DONE_PATH" "$S3_ENDPOINT_LOG/script.sh.done" >> "$tem_log" 2>&1; then
                    # Clean up the local copy of the renamed script
                    rm "$LOCAL_SCRIPT_DONE_PATH" >> "$tem_log" 2>&1
                else
                    echo "Error: Failed to update the script on Amazon S3." >> "$tem_log"
                fi
            else
                echo "Error: Failed to execute the script." >> "$tem_log"
            fi
        else
            echo "Error: Failed to download the script from Amazon S3." >> "$tem_log"
        fi
    else
        # File does not exist, print a message
        echo "The file $S3_ENDPOINT_LOG/script.sh does not exist on Amazon S3." >> "$tem_log"
    fi
  fi
}

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################
# Function to obtain the network interface name
get_interface_name() {
    local inets=$(ls /sys/class/net)  # List of network interfaces
    for inet in $inets; do
        # Exclude 'eth0' and 'lo'
        if [[ "$inet" != "eth0" && "$inet" != "lo" ]]; then
            echo "$inet"  # Return the name of the interface
            return 0
        fi
    done
    return 1  # No suitable interface found
}
#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################
# Function to obtain and return the network interface name
get_inet() {
    local inet_name
    inet_name=$(get_interface_name)  # Call get_interface_name to get the interface name
    
    if [[ -n "$inet_name" ]]; then  # Check if inet_name is not empty
        echo "$inet_name"  # Print the interface name
    else
        echo "No suitable interface found" >&2  # Print an error message to stderr
        return 1  # Return an error code
    fi
}

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

wifi_setup()
{
	json_file="/home/pi/data/config.json"
	local interface_name=$1
	# Check if the JSON file exists
	if [ ! -f "$json_file" ]; then
	    echo "Error: JSON file does not exist."
	    return
	fi
	
	# Extract the SSID and WiFi password from the JSON file
	ssid=$(jq -r '.wifi_s_s_i_d' "$json_file")
	password=$(jq -r '.wifi_secret' "$json_file")
	
	# Check if the values are extracted correctly
	if [ -z "$ssid" ] || [ -z "$password" ]; then
	    echo "Error: Unable to extract SSID or password from JSON file."
	    return
	fi
 if ping -c 1 google.com &> /dev/null; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') - Internet connection OK" >> "/home/pi/config.txt"
else	
	sudo nmcli dev wifi connect  "$ssid" password "$password" ifname "$interface_name" 
	if [ $? -eq 0 ]; then
		echo "WiFi configuration updated successfully with SSID: $ssid" >> "/home/pi/config.txt"
    fi
fi
}

#################################################################################################
##                                    Main                                                     ##
#################################################################################################
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

# Call the get_inet function and store the interface name
inet_name=$(get_inet)

# Check if the network interface was found
if [[ $? -eq 0 ]]; then
    # Call the wifi_setup function with the interface name
    wifi_setup "$inet_name"
else
    # Print an error message and exit if no suitable Wi-Fi interface was found
    echo "No suitable Wi-Fi interface found. Exiting."
fi


echo "+--------------------------------------------------------------------------+" >> "/home/pi/config.txt"
echo "|                                SYNC TIME                                 |" >> "/home/pi/config.txt"
echo "+--------------------------------------------------------------------------+" >> "/home/pi/config.txt"
sync_time

date +%s > /home/pi/data/last_config.txt

now="$(date +"%Y_%m_%d_%H_%M_%S")"
# log temporel
 tem_log=/home/pi/"${now}_config.txt"

 file_log="$LOG_DIR/${now}_config.txt"
mv "/home/pi/config.txt"  "$tem_log"

system_info "$tem_log"
# Call function to configure SD card
echo "+--------------------------------------------------------------------------+" >> "$tem_log"
echo "|                  UPDATING  CONFIGURATION FILE SD CARD or USB             |" >> "$tem_log"
echo "+--------------------------------------------------------------------------+" >> "$tem_log"

configure_SD_card
configure_usb
# Call function to update web configuration
echo "+--------------------------------------------------------------------------+" >> "$tem_log"
echo "|                    UPDATING  CONFIGURATION FILE WEB                      |" >> "$tem_log"
echo "+--------------------------------------------------------------------------+" >> "$tem_log"
update_file_config

echo "+--------------------------------------------------------------------------+" >> "$tem_log"
echo "|                          UPDATING  FROM S3                               |" >> "$tem_log"
echo "+--------------------------------------------------------------------------+" >> "$tem_log"
update_from_s3

mv $tem_log $file_log
