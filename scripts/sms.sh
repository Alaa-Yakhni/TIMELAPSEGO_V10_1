#!/bin/bash

JSON_FILE="/home/pi/data/config.json"
PICTURES_DIR="/DATA/HIGH"
LOG_DIR="/DATA/LOG"
DATABASE_DIR="/DATA/DATABASE"
PICTURES_LOW="/DATA/LOW"
PICTURES_BLUR="/DATA/BLUR"

take()
{   
   
    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
    echo "|                               START TAKE                                 |" >> "$tem_log"
    echo "+--------------------------------------------------------------------------+" >> "$tem_log"
    # Nombre maximum de tentatives
    max_attempts=2
    attempt=1

    # Loop pour la capture de l'image
    while [ $attempt -le $max_attempts ]; do
        # Take a picture with the specified name
        gphoto2 --capture-image-and-download --filename "$PICTURES_DIR/$photo_name" >> "$tem_log"

        # Check if the picture was taken successfully
        if [ $? -eq 0 ] && [ -f "$PICTURES_DIR/$photo_name" ]; then
	
             # Check if the picture has a size greater than 0 bytes
	         image_size=$(stat -c %s "$PICTURES_DIR/$photo_name")
             if [ "$image_size" -eq 0 ]; then
	         rm "$PICTURES_DIR/$photo_name"
	         echo "Error: Captured image is empty (0 bytes)." >> "$tem_log"
             else
                content_send="Picture_taken"
                send_sms $sender_number $content_send
                # Get the size of the image
                image_size=$(stat -c %s "$PICTURES_DIR/$photo_name")
                image_size_mb=$(echo "scale=2; $image_size / (1024 * 1024)" | bc)
                echo "The photo was successfully taken after the SMS was triggered: $photo_name. Image size: $image_size_mb Mo." >> "$tem_log"
                echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                
                # Add copyright
                exiftool -overwrite_original -Copyright="TimeLapse Go'" "$PICTURES_DIR/$photo_name" &
                ## update info to system
                /home/pi/scripts/system_info.sh "$DATABASE_DIR/$now.json"  2>/dev/null
                # Check if the picture needs to be blurred
                is_blur=$(jq -r '.is_blur' "$JSON_FILE")
                if [ "$is_blur" == "true" ]; then
                    mv "$PICTURES_DIR/$photo_name" "$PICTURES_BLUR"
                    echo "Moving $photo_name to $PICTURES_BLUR" >> "$tem_log"
                fi
             break
            fi
        else
            content_send="Failedto_capture"
            end_sms $sender_number $content_send
            echo "Error: Failed to capture the photo on attempt $attempt." >> "$tem_log"
            rm "$DATABASE_DIR/$now.json"
        fi

        # Augmenter le compteur de tentative
        ((attempt++))
    done
}

Check-pictureLow() {

    PICTURES=$1
    LOW_PICTURES=$2

    start_comp=$(date +%s)

    image_list=($(ls -1t "$PICTURES"/*.jpg))
    # Check if the picture needs to be blurred
    is_blur=$(jq -r '.is_blur' "$JSON_FILE")

    # Check if the picture should not be transferred
    notransfer=$(jq -r '.is_no_transfer' "$JSON_FILE")
    # Vérifier si le transfert n'est pas désactivé et si l'image ne doit pas être floue
    if [ "$notransfer" == "false" ] && [ "$is_blur" == "false" ]; then
        # Parcourir chaque image dans l'image_list
        for image in "${image_list[@]}"; do

            # Extraire le nom de l'image
            image_name=$(basename "$image")

            # Vérifier si l'image n'existe pas déjà dans PICTURES_LOW
            if [ ! -f "$LOW_PICTURES/$image_name" ]; then
                # Vérifier le nombre de traitements en cours
                echo "+--------------------------------------------------------------------------+" >> "$tem_log"
		        echo "+--------------------------------------------------------------------------+" >> "$tem_log"
                size=$(stat -c %s "$image")
                if [ "$size" -eq 0 ]; then
                   rm "$image"
                   echo " $image is deleted size equal 0" >> "$tem_log"
                else
	       	      # Compresser l'image et modifier les métadonnées
               	  convert "$image" -strip -quality 60% -resize 900x600 -define jpeg:optimize-coding=true "$LOW_PICTURES/$image_name"
                  size_low=$(stat -c %s "$LOW_PICTURES/$image_name")
                if [ "$size_low" -eq 0 ]; then
                   rm "$LOW_PICTURES/$image_name"
                   echo " $LOW_PICTURES/$image_name is deleted size equal 0" >> "$tem_log"
		        fi
               	
               	# Vérifier si la compression a réussi
               	if [ $? -eq 0 ]; then
                    echo "Photo $image compressed successfully" >> "$tem_log"
                    end_comp=$(date +%s)

   		            # Calculate the time difference
   		            elapsed_time_comp=$((end_comp - start_comp))
                    # Display the elapsed time
                    echo " compress finished execution in $elapsed_time_comp seconds from $PICTURES" >> "$tem_log"
                else
                    echo "Error: Unable to compress $image" >> "$tem_log"
                fi
              fi
            fi
        done
    fi

}

get_device_information() {
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
        # Récupérer le token en envoyant une
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
    echo "$device_name" 
    echo "$msisdn" 
    # Retourner la valeur du token
    echo "$token"
    echo "$SESSIONID"
}



send_sms() {
    PHONE="$1"
    contents="$2"
    result=$(get_device_information)

    # Lecture des lignes dans des variables distinctes
    IFS=$'\n' read -r device_name <<< "$(echo "$result" | sed -n '1p')"
    IFS=$'\n' read -r msisdn <<< "$(echo "$result" | sed -n '2p')"
    IFS=$'\n' read -r token <<< "$(echo "$result" | sed -n '3p')"
    IFS=$'\n' read -r SESSIONID <<< "$(echo "$result" | sed -n '4p')"


    #echo "Envoi du SMS : $device_name Au numéro : $PHONE Avec un routeur de type : $device_name"
    DATA="<request><Index>-1</Index><Phones><Phone>$PHONE</Phone></Phones><Sca></Sca><Content>$contents</Content><Length>${#device_name}</Length><Reserved>1</Reserved><Date>`date +'%F %T'`</Date></request>"

    curl --silent --connect-timeout 30 --request POST http://192.168.8.1/api/sms/send-sms \
    -H "Cookie: $SESSIONID" -H "__RequestVerificationToken: $token" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
    --data "$DATA"

}

check-cont()
{
    result=$(get_device_information)

    # Lecture des lignes dans des variables distinctes
    IFS=$'\n' read -r device_name <<< "$(echo "$result" | sed -n '1p')"
    IFS=$'\n' read -r msisdn <<< "$(echo "$result" | sed -n '2p')"
    IFS=$'\n' read -r token <<< "$(echo "$result" | sed -n '3p')"
    IFS=$'\n' read -r SESSIONID <<< "$(echo "$result" | sed -n '4p')"
    CONTENT="Notification"
    DATA="<request><PageIndex>1</PageIndex><ReadCount>1</ReadCount><BoxType>1</BoxType><SortType>1</SortType><Ascending>0</Ascending><UnreadPreferred>1</UnreadPreferred></request>"
    response=$(curl --silent --connect-timeout 30 --request POST http://192.168.8.1/api/sms/sms-list \
    -H "Cookie: $SESSIONID" -H "__RequestVerificationToken: $token" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
    --data "$DATA")

    # Récupérer le contenu du dernier message
    last_message_content=$(xmlstarlet sel -t -v "//Message[1]/Content" <<< "$response")
  if [ -n "$last_message_content" ]; then
    # Récupérer le numéro de téléphone du dernier message
    sender_number=$(echo "$response" | grep "<Phone>" | sed 's/.*<Phone>\(.*\)<\/Phone>.*/\1/')
    last_message_index=$(grep -B 2 "<Content>$last_message_content</Content>" <<< "$response" | grep "<Index>" | sed 's/.*<Index>\(.*\)<\/Index>.*/\1/' | head -n 1)
    echo "$last_message_index"
    # Afficher le contenu du dernier message si c'est le bon
    if [[ "$last_message_content" == *"$CONTENT"* ]]; then
        ##echo "Ok, envoyé par : $sender_number"
        now="$(date +"%Y_%m_%d_%H_%M_%S")"

    	# log temporel
    	tem_log="${now}_take_photo.txt"
    	file_log="$LOG_DIR/${now}_take_photo.txt"
        photo_name="${now}.jpg"
        # prendre une photo 
        take  
        
        #######
        Check-pictureLow /DATA/HIGH /DATA/LOW
        sudo mv $tem_log $file_log 
    fi
    # Supprimer le message en utilisant son index
        # récupérer de nouveau token change aprés chaque utilisation
        result2=$(get_device_information)
        IFS=$'\n' read -r token2 <<< "$(echo "$result2" | sed -n '3p')"
        IFS=$'\n' read -r SESSIONID2 <<< "$(echo "$result2" | sed -n '4p')"
        DATA_delete="<request><Index>$last_message_index</Index></request>"
        curl --silent --connect-timeout 30 --request POST http://192.168.8.1/api/sms/delete-sms \
        -H "Cookie: $SESSIONID2" -H "__RequestVerificationToken: $token2" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
        --data "$DATA_delete"
  fi

result=$(get_device_information)

IFS=$'\n' read -r token <<< "$(echo "$result" | sed -n '3p')"
IFS=$'\n' read -r SESSIONID <<< "$(echo "$result" | sed -n '4p')"

# Récupérer la liste des messages envoyés
DATA_send="<request><PageIndex>1</PageIndex><ReadCount>1</ReadCount><BoxType>2</BoxType><SortType>1</SortType><Ascending>0</Ascending><UnreadPreferred>1</UnreadPreferred></request>"
response_send=$(curl --silent --connect-timeout 30 --request POST http://192.168.8.1/api/sms/sms-list \
    -H "Cookie: $SESSIONID" -H "__RequestVerificationToken: $token" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
    --data "$DATA_send")

# Récupérer le contenu du dernier message envoyé
send_message_content=$(grep -m 1 "<Content>" <<< "$response_send" | sed 's/.*<Content>\(.*\)<\/Content>.*/\1/')

if [ -n "$send_message_content" ]; then 
    send_message_index=$(echo "$response_send" | grep "<Index>" | sed 's/.*<Index>\(.*\)<\/Index>.*/\1/' | head -n 1)

    result=$(get_device_information)

    IFS=$'\n' read -r token <<< "$(echo "$result" | sed -n '3p')"
    IFS=$'\n' read -r SESSIONID <<< "$(echo "$result" | sed -n '4p')"
    # Supprimer le dernier message envoyé
    DATA_send_delete="<request><Index>$send_message_index</Index></request>"
    curl --silent --connect-timeout 30 --request POST http://192.168.8.1/api/sms/delete-sms \
        -H "Cookie: $SESSIONID" -H "__RequestVerificationToken: $token" -H "Content-Type: application/x-www-form-urlencoded; charset=UTF-8" \
        --data "$DATA_send_delete"
fi
}

while true; do

    check-cont
    
    if [ -f "/tmp/update.lock" ]; then

       exit 
    fi
    sleep 0.25
done
