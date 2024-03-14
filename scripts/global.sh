#!/bin/bash


S3_BUCKET="timelapsestorage"
S3_ENDPOINT_HIGH="s3://$S3_BUCKET/$UDID/HIGH"
S3_ENDPOINT_LOW="s3://$S3_BUCKET/$UDID/LOW"
S3_ENDPOINT_LOG="s3://$S3_BUCKET/$UDID/LOG"

LOG_DIR="/home/pi/logs"


# Destination directory for the box identifier
ID_FILE="/home/pi/data/UDID.txt"

# Path to the TLGO configuration file
TLGO_CONFIG="/home/pi/data/config.json"



get_CurrentUpload()
{

    current_upload=""


    # URL à partir de laquelle récupérer les informations
        URL="http://192.168.8.1/api/monitoring/traffic-statistics"

        # Récupérer les données XML de l'URL
        xml_data=$(curl -s "$URL")

   
        # Extraire les valeurs à partir des données XML
   
        current_upload=$(echo "$xml_data" | xmlstarlet sel -t -v "//CurrentUpload")
   
       ################ si n'est pas ni 325 ni 320 ###################
        if [[ "$current_upload" == '' ]]; then 
            ################ si 607 #################################
            DATA=`curl --silent --connect-timeout 30 http://192.168.8.1/api/webserver/SesTokInfo`
                SESSIONID=`echo "$DATA" | grep "SessionID=" | cut -b 10-147`
                token=`echo "$DATA" | grep "TokInfo" | cut -b 10-41`

       

            # Envoyer une requête GET à l'URL de l'API avec le token pour récupérer les informations du périphérique
            xml_data=$(curl --silent --connect-timeout 30 "$URL" \
               -H "Cookie: $SESSIONID" -H "__RequestVerificationToken: $token")
        
            # Extraire les valeurs des balises XML
            current_upload=$(echo "$xml_data" | xmlstarlet sel -t -v "//CurrentUpload")
        fi 

        if [[ "$current_upload" == '' ]]; then 
            ##### si le cas de 153 #########################
            # Récupérer le token en envoyant une requête GET à l'URL de l'API
            response=$(curl --silent --connect-timeout 30 http://192.168.8.1/api/webserver/token)
            # Extraire le contenu de la balise <token> en utilisant awk
            token=$(echo "$response" | awk -F'[><]' '/<token>/{print $3}')
        
            # Envoyer une requête GET à l'URL de l'API avec le token pour récupérer les informations du périphérique
            xml_data=$(curl --silent --connect-timeout 30 "$URL" \
                 -H "__RequestVerificationToken: $token")
        
            # Extraire les valeurs des balises XML
            current_upload=$(echo "$xml_data" | xmlstarlet sel -t -v "//CurrentUpload")
        fi
        # Afficher les valeurs récupérées
    
        echo "$current_upload" 

}


get_device_information() {
    
     local logfile="$1"

    msisdn="" # Initialisation de la variable msisdn à vide
    
     RESPONSE=`curl --connect-timeout 30 --silent --request GET http://192.168.8.1/api/webserver/SesTokInfo`
            SESSIONID="SessionID="`echo "$RESPONSE"| grep -oPm1 "(?<=<SesInfo>)[^<]+"`
            token=`echo "$RESPONSE"| grep -oPm1 "(?<=<TokInfo>)[^<]+"`
    ############## pour le cas de 325 et 320 ##############################
    URL_dongle="http://192.168.8.1/api/device/information"

    # Récupérer les données XML de l'URL
    xml_data=$(curl -s "$URL_dongle")

    # Extraire les valeurs à partir des données XML
    device_name=$(echo "$xml_data" | awk -F'[><]' '/<DeviceName>/{print $3}')
    msisdn=$(echo "$xml_data" | awk -F'[><]' '/<Msisdn>/{print $3}')
    
    ################ si n'est pas ni 325 ni 320 ###################
    if [[ "$msisdn" == '' ]]; then 
        ################ si 607 #################################
        DATA=`curl --silent --connect-timeout 30 http://192.168.8.1/api/webserver/SesTokInfo`
            SESSIONID=`echo "$DATA" | grep "SessionID=" | cut -b 10-147`
            token=`echo "$DATA" | grep "TokInfo" | cut -b 10-41`

       

        # Envoyer une requête GET à l'URL de l'API avec le token pour récupérer les informations du périphérique
        xml_data=$(curl --silent --connect-timeout 30 "http://192.168.8.1/api/device/information" \
           -H "Cookie: $SESSIONID" -H "__RequestVerificationToken: $token")
        
        # Extraire les valeurs des balises XML
        device_name=$(echo "$xml_data" | awk -F'[><]' '/<DeviceName>/{print $3}')
        msisdn=$(echo "$xml_data" | awk -F'[><]' '/<Msisdn>/{print $3}')
    fi 

    if [[ "$msisdn" == '' ]]; then 
        ##### si le cas de 153 #########################
        # Récupérer le token en envoyant une requête GET à l'URL de l'API
        response=$(curl --silent --connect-timeout 30 http://192.168.8.1/api/webserver/token)
        # Extraire le contenu de la balise <token> en utilisant awk
        token=$(echo "$response" | awk -F'[><]' '/<token>/{print $3}')
        
        # Envoyer une requête GET à l'URL de l'API avec le token pour récupérer les informations du périphérique
        xml_data=$(curl --silent --connect-timeout 30 "http://192.168.8.1/api/device/information" \
             -H "__RequestVerificationToken: $token")
        
        # Extraire les valeurs des balises XML
        device_name=$(echo "$xml_data" | awk -F'[><]' '/<DeviceName>/{print $3}')
        msisdn=$(echo "$xml_data" | awk -F'[><]' '/<Msisdn>/{print $3}')
    fi 
    
    # Afficher les valeurs récupérées
    echo "Device Name : $device_name" >> $logfile
    echo "Phone number : $msisdn" >> $logfile
    
  }




get_rssi()
{
    local logfile="$1"

    # URL à partir de laquelle récupérer les informations
    URL="http://192.168.8.1/api/device/signal"
    ### sauf la version 607 demande authentification on l'ajoute et pas 
    # obligation de faire if car les autres version ne le demandent pas pou RSSI 
    DATA=`curl --silent --connect-timeout 30 http://192.168.8.1/api/webserver/SesTokInfo`
            SESSIONID=`echo "$DATA" | grep "SessionID=" | cut -b 10-147`
            token=`echo "$DATA" | grep "TokInfo" | cut -b 10-41`

    # Récupérer les données XML de l'URL et extraire la valeur RSSI
    rssi=$(curl -s "$URL" -H "Cookie: $SESSIONID" -H "__RequestVerificationToken: $token" | xmlstarlet sel -t -v "//rssi")

    # Vérifier si la valeur RSSI a été récupérée avec succès
    if [ -n "$rssi" ]; then
        echo "Received Signal Strength Indicator RSSI: $rssi " >> $logfile
    else
        echo "Erreur lors de la récupération du RSSI" >> $logfile
   fi
}



system_info() {
    # Check if the log file path is specified
    if [ -z "$1" ]; then
        echo "Please specify the path to the log file."
        return 1
    fi
    local logfile="$1"
    emmc_used=$(df --output=pcent / | awk 'NR==2 {sub(/%/,"",$1); print $1}')

    # Obtenir les informations sur l'utilisation de la mémoire
mem_info=$(free -m | awk 'NR==2 {print $3,$2}')

# Extraire la mémoire utilisée et la mémoire totale
used_mem=$(echo "$mem_info" | awk '{print $1}')
total_mem=$(echo "$mem_info" | awk '{print $2}')

# Calculer le pourcentage d'utilisation de la mémoire
usage_percentage=$(awk "BEGIN {printf \"%.0f\", ($used_mem / $total_mem) * 100}")


    echo "+--------------------------------------------------------------------------+" >> "$logfile"
    echo "|                                  SYSTEM INFORMATION                      |" >> "$logfile"
    echo "+--------------------------------------------------------------------------+" >> "$logfile"

# Afficher le résultat
echo "Memory usage: $usage_percentage% of ${total_mem}MB" >> "$logfile"

    VERSION=$(sudo /home/pi/tlgo_commands --get_firmware)
    infouptime=$(uptime)
    cputemperature=$(( $(cat /sys/class/thermal/thermal_zone0/temp)/1000))
    voltage=$(sudo /home/pi/tlgo_commands -V)

    # Writing information into the specified log file

    sudo python3 /home/pi/scripts/sensor.py >> "$logfile"   

    echo "Boot Info: $infouptime" >> "$logfile"
    echo "TLGO Version: $VERSION" >> "$logfile"
    echo "Disk Space used: $emmc_used %" >> "$logfile"
    echo "CPU Temp: $cputemperature C" >> "$logfile"
    echo "voltage: $voltage" >> "$logfile"
    echo "+--------------------------------------------------------------------------+" >> "$logfile"
    echo "|                                4G information connection                 |" >> "$logfile"
    echo "+--------------------------------------------------------------------------+" >> "$logfile"
   
    get_rssi $logfile
   
   get_device_information $logfile
    echo "+--------------------------------------------------------------------------+" >> "$logfile"
    echo "+--------------------------------------------------------------------------+" >> "$logfile"

}




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



