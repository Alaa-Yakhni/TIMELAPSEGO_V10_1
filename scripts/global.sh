#!/bin/bash


S3_BUCKET="timelapsestorage"
S3_ENDPOINT_HIGH="s3://$S3_BUCKET/$UDID/HIGH"
S3_ENDPOINT_LOW="s3://$S3_BUCKET/$UDID/LOW"
S3_ENDPOINT_LOG="s3://$S3_BUCKET/$UDID/LOG"

LOG_DIR="/DATA/LOG"


# Destination directory for the box identifier
ID_FILE="/home/pi/data/UDID.txt"

# Path to the TLGO configuration file
TLGO_CONFIG="/home/pi/data/config.json"

# Chemin vers le fichier JSON
JSON_FILE="/home/pi/data/config.json"


#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

get_device_information() {

    local logfile="$1"

    msisdn="" # Initialisation de la variable msisdn Ã  vide

    RESPONSE=`curl --connect-timeout 30 --silent --request GET http://192.168.8.1/api/webserver/SesTokInfo`
            SESSIONID="SessionID="`echo "$RESPONSE"| grep -oPm1 "(?<=<SesInfo>)[^<]+"`
            token=`echo "$RESPONSE"| grep -oPm1 "(?<=<TokInfo>)[^<]+"`
    ############## pour le cas de 325 et 320 ##############################
    URL_dongle="http://192.168.8.1/api/device/information"

    # RÃ©cupÃ©rer les donnÃ©es XML de l'URL
    xml_data=$(curl -s "$URL_dongle")

    # Extraire les valeurs Ã  partir des donnÃ©es XML
    device_name=$(echo "$xml_data" | awk -F'[><]' '/<DeviceName>/{print $3}')
    msisdn=$(echo "$xml_data" | awk -F'[><]' '/<Msisdn>/{print $3}')

    ################ si n'est pas ni 325 ni 320 ###################
    if [[ "$msisdn" == '' ]]; then 
        ################ si 607 #################################
        DATA=`curl --silent --connect-timeout 30 http://192.168.8.1/api/webserver/SesTokInfo`
            SESSIONID=`echo "$DATA" | grep "SessionID=" | cut -b 10-147`
            token=`echo "$DATA" | grep "TokInfo" | cut -b 10-41`

        # Envoyer une requÃªte GET Ã  l'URL de l'API avec le token pour rÃ©cupÃ©rer les informations du pÃ©riphÃ©rique
        xml_data=$(curl --silent --connect-timeout 30 "http://192.168.8.1/api/device/information" \
           -H "Cookie: $SESSIONID" -H "__RequestVerificationToken: $token")

        # Extraire les valeurs des balises XML
        device_name=$(echo "$xml_data" | awk -F'[><]' '/<DeviceName>/{print $3}')
        msisdn=$(echo "$xml_data" | awk -F'[><]' '/<Msisdn>/{print $3}')
    fi

    if [[ "$msisdn" == '' ]]; then
        ##### si le cas de 153 #########################
        # RÃ©cupÃ©rer le token en envoyant une requÃªte GET Ã  l'URL de l'API
        response=$(curl --silent --connect-timeout 30 http://192.168.8.1/api/webserver/token)
        # Extraire le contenu de la balise <token> en utilisant awk
        token=$(echo "$response" | awk -F'[><]' '/<token>/{print $3}')

        # Envoyer une requÃªte GET Ã  l'URL de l'API avec le token pour rÃ©cupÃ©rer les informations du pÃ©riphÃ©rique
        xml_data=$(curl --silent --connect-timeout 30 "http://192.168.8.1/api/device/information" \
             -H "__RequestVerificationToken: $token")

        # Extraire les valeurs des balises XML
        device_name=$(echo "$xml_data" | awk -F'[><]' '/<DeviceName>/{print $3}')
        msisdn=$(echo "$xml_data" | awk -F'[><]' '/<Msisdn>/{print $3}')
    fi

    # Afficher les valeurs rÃ©cupÃ©rÃ©es
    echo "Device Name : $device_name" >> $logfile
    echo "Phone number : $msisdn" >> $logfile

  }


#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

get_rssi()
{
    local logfile="$1"

    # URL Ã  partir de laquelle rÃ©cupÃ©rer les informations
    URL="http://192.168.8.1/api/device/signal"
    ### sauf la version 607 demande authentification on l'ajoute et pas 
    # pas obligation de faire if car les autres versions ne le demandent pas pou RSSI 
    DATA=`curl --silent --connect-timeout 30 http://192.168.8.1/api/webserver/SesTokInfo`
            SESSIONID=`echo "$DATA" | grep "SessionID=" | cut -b 10-147`
            token=`echo "$DATA" | grep "TokInfo" | cut -b 10-41`

    # RÃ©cupÃ©rer les donnÃ©es XML de l'URL et extraire la valeur RSSI
    rssi=$(curl -s "$URL" -H "Cookie: $SESSIONID" -H "__RequestVerificationToken: $token" | xmlstarlet sel -t -v "//rssi")

    # VÃ©rifier si la valeur RSSI a Ã©tÃ© rÃ©cupÃ©rÃ©e avec succÃ¨s
    if [ -n "$rssi" ]; then
        echo "Received Signal Strength Indicator RSSI: $rssi " >> $logfile
    else
        echo "Erreur lors de la rÃ©cupÃ©ration du RSSI" >> $logfile
   fi
}


#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################
# Fonction pour extraire les donnÃ©es d'un fichier JSON
extract_data() {
    local file="/home/pi/data/system_info.json"

    temperature=$(jq -r '.temperature' "$file")
    pressure=$(jq -r '.pressure' "$file")
    humidity=$(jq -r '.humidity' "$file")
    voltage=$(jq -r '.voltage' "$file")
    VERSION=$(jq -r '.VERSION' "$file")
    PCB=$(sed -n '2p' /home/pi/data/info.txt)
    if [ "$PCB" == "PCBv10" ]; then
         voltage_camera=$(jq -r '.voltage_camera' "$file")
         voltage_pi=$(jq -r '.voltage_pi' "$file")
    fi
}

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################


system_info()
{
   local logfile="$1"
   disk_usage=$(df --output=pcent,used,size / | awk 'NR==2 {gsub(/%/, "", $1); print $1, $2, $3}')
   usage_percent=$(echo "$disk_usage" | awk '{print $1}')
   used_size_gb=$(echo "$disk_usage" | awk '{print $2/1024/1024}' | bc)
   total_size_gb=$(echo "$disk_usage" | awk '{print $3/1024/1024}' | bc)

   # Obtenir les informations sur l'utilisation de la mÃ©moire
   mem_info=$(free -m | awk 'NR==2 {print $3,$2}')

   # Extraire la mÃ©moire utilisÃ©e et la mÃ©moire totale
   used_mem=$(echo "$mem_info" | awk '{print $1}')
   total_mem=$(echo "$mem_info" | awk '{print $2}')
   # Calculer le pourcentage d'utilisation de la mÃ©moire
   usage_percentage=$(awk "BEGIN {printf \"%.0f\", ($used_mem / $total_mem) * 100}")

   infouptime=$(uptime)
   cputemperature=$(( $(cat /sys/class/thermal/thermal_zone0/temp)/1000))

   startup_time=$(systemd-analyze)
   VERSION=$(sed -n '5p' /home/pi/data/info.txt)
   version_code=$(sed -n '3p' /home/pi/data/info.txt)
   PCB=$(sed -n '2p' /home/pi/data/info.txt)
   model=$(sed -n '1p' /home/pi/data/info.txt | tr -d '\0')
   processor=$(sed -n '4p' /home/pi/data/info.txt)
   ## from json
   extract_data

   if [ -b /dev/mmcblk1p1 ]; then
        sudo fsck /dev/mmcblk1p1
        if [ $? -eq 0 ]; then
            # Get disk space usage information
            usage_info=$(df -h /mnt/sdcard | awk 'NR==2 {print}')
            # Extract total, used, and free storage information
            total_storage=$(echo "$usage_info" | awk '{print $2}')
            used_storage=$(echo "$usage_info" | awk '{print $3}')
            #free_storage=$(echo "$usage_info" | awk '{print $4}')
        else 
            total_storage="No SD card"
            used_storage="No SD card"
            # free_storage="No SD card"
        fi
   fi

   

   echo "+--------------------------------------------------------------------------+" >> "$logfile"
   echo "|                           SYSTEM INFORMATION                             |" >> "$logfile"
   echo "+--------------------------------------------------------------------------+" >> "$logfile"
   # Afficher
   sudo tlgo-pcb >> "$logfile"
   echo "Memory usage RAM: $usage_percentage% of ${total_mem}MB" >> "$logfile"
   echo "Disk Space stockage: $usage_percent% | Used: $used_size_gb GB of $total_size_gb GB" >> "$logfile"
   echo "$startup_time" >> "$logfile"
   echo "Boot Info: $infouptime" >> "$logfile"
   echo "$processor" >> "$logfile"
   echo "Model : $model" >> "$logfile"
   echo "PCB : $PCB" >> "$logfile"
   echo "Version code : $version_code" >> "$logfile"
   echo "CPU Temp: $cputemperature C" >> "$logfile"

   if [ -b /dev/mmcblk1p1 ]; then
        echo "Total storage SD card : $total_storage" >> "$logfile"
        echo "Used storage SD card : $used_storage" >> "$logfile"
   fi

   # Check that the USB key is mounted at /mnt/usb
   if lsblk -o NAME,MOUNTPOINT | grep -q "/mnt/usb"; then
        # Get the storage information for the mount point
        df -h "/mnt/usb" | awk 'NR==2 {print "Total storage USB: " $2 "\nUsed storage USB: " $3}' >> "$logfile"
   fi

   if [ "$PCB" != "PCBv3" ];then

       echo "TLGO Version: $VERSION" >> "$logfile"
       echo "voltage (12 v): $voltage volts" >> "$logfile"
       if [ "$PCB" == "PCBv10" ]; then
   	     echo "voltage camera (8 v): $voltage_camera Volts" >> "$logfile"
   	     echo "voltage Pi (5 v): $voltage_pi volts" >> "$logfile"
       fi

       if [ "$PCB" == "PCBv10" ] || [ "$PCB" == "PCBv9" ]; then
   	     echo "Temperature: $temperature C" >> "$logfile"
   	     echo "Pressure: $pressure hPa">> "$logfile"
   	     echo "Humidity: $humidity %" >> "$logfile"
       fi
   fi


   echo "+--------------------------------------------------------------------------+" >> "$logfile"
   echo "|                         4G information connection                        |" >> "$logfile"
   echo "+--------------------------------------------------------------------------+" >> "$logfile"
   
   # Adresse IP à pinger
   ip_address="192.168.8.1"

   # Effectuer un ping silencieux avec 1 requête et un délai d'attente de 1 seconde
   if ping -q -c 1 -W 1 $ip_address > /dev/null 2>&1; then
      get_rssi $logfile

      get_device_information $logfile
   else
        echo "No connection 4G" >> "$logfile"
   fi
  
   echo "+--------------------------------------------------------------------------+" >> "$logfile"
   echo "+--------------------------------------------------------------------------+" >> "$logfile"

   echo "+--------------------------------------------------------------------------+" >> "$logfile"
   echo "|                                Images                                    |" >> "$logfile"
   echo "+--------------------------------------------------------------------------+" >> "$logfile"

   image_list=($(ls -1t /DATA/HIGH/*.jpg))
   num_images=${#image_list[@]}
   echo "Images in  pi: $num_images Images" >> "$logfile"
   if [ -b /dev/mmcblk1p1 ]; then
     sudo fsck /dev/mmcblk1p1
   	 if [ $? -eq 0 ]; then
       		 image_listSD=($(ls -1t /mnt/sdcard/HIGH/*.jpg))
       		 num_imagesSD=${#image_listSD[@]}
       		 echo "Images in SD card: $num_imagesSD Images" >> "$logfile"
   	 else 
       		 echo "No SD card" >> "$logfile"
   	 fi
   fi
   # Check that the USB key is mounted at /mnt/usb
   if lsblk -o NAME,MOUNTPOINT | grep -q "/mnt/usb"; then
        image_list_USB=($(ls -1t /mnt/usb/HIGH/*.jpg))
        num_images_USB=${#image_list_USB[@]}
        echo "Images in USB: $num_images_USB Images" >> "$logfile"
   fi

}


#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################

function getID() {
  # Check if ID_FILE variable is defined
  if [ -z "$ID_FILE" ]; then
    echo "Error: ID_FILE variable is not defined"
    return 1
  fi

  # Check if file exists
  if [ -f "$ID_FILE" ]; then
    # Read only the first line to avoid potential errors
    udid=$(sed -n '1p' "$ID_FILE")
    export UDID="$udid"
  else
    # No ID found
    export UDID=''
  fi
}

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################
sleep_PI()
{   time_to_sleep=$1
    time=$2
   
    # Executer la commande tlgo-commands
     sudo tlgo-commands -T "$time_to_sleep" -t "$time" 

}

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################
debug_led()
{
    # Boucle pour allumer et Ã©teindre la LED plusieurs fois
    for i in {1..6}; do
        sudo tlgo-commands -L 1  # ON LED
        sleep 0.25
        sudo tlgo-commands -L 0  # OFF LED
       sleep 0.25
    done
}

#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################
reset_usb()
{
    res=$(lsusb | grep Huawei )
    read -a strarr <<< "$res"
    port=$(echo ${strarr[3]} | sed s/://)
    sudo usbreset /dev/bus/usb/$bus/$port
    echo "RESET 4G bus:$bus, port:$port"
}
#######################################################################################
##                                  FUNCTION                                         ##
#######################################################################################
### reset usb camera 
reset_usb_nikon() {
    res=$(lsusb | grep Nikon)
    if [ -z "$res" ]; then
        echo "Nikon device not found"
        return
    fi
    read -a strarr <<< "$res"
    bus=$(echo ${strarr[1]})
    port=$(echo ${strarr[3]} | sed 's/://')
    sudo /usr/local/bin/usbreset /dev/bus/usb/$bus/$port
    echo "RESET Nikon bus:$bus, port:$port"
}
