#!/bin/bash

#include global vars and functions
. "/home/pi/scripts/global.sh"

# Chemin vers le fichier JSON
JSON_FILE="/home/pi/data/config.json"


no_picture_voltage=$(jq -r '.no_picture_voltage' "$JSON_FILE")
voltage=$(jq '.voltage' "/home/pi/data/system_info.json")
# Check if the value is empty or zero
if [ -z "$voltage" ] || [ "$voltage" == "0" ]; then
    echo "La valeur de voltage n'existe pas ou est zéro. Attribution de la valeur par défaut."
    voltage=$(sudo tlgo-commands -V)
fi

if (( $(echo "$voltage < $no_picture_voltage" | bc -l) )); then
    # sleep 2 hours 
    sleep_PI 4 7 200
fi

# Définition de la fonction check_mode
check_mode() {
    # Lire le sixième mot de la première ligne
    mode=$(awk 'NR==1{print $1}' /home/pi/data/mode.txt)

    echo "Mode est: $mode"

    if [ "$mode" = "sleepy" ]; then
        # Vérifier si le mode de transfert d'images est activé
        # get value is_no_transfer from JSON_FILE
	    no_transfer=$(jq -r '.is_no_transfer' "$JSON_FILE")
        ### si le mode de transfert d'images n'est pas activé
        if [ "$no_transfer" == "false" ]; then
            # Vérifier si connecté à l'internet
            if ping -c 1 google.com &> /dev/null; then
                # Récupérer la liste des images sur Nano Pi
                image_list=($(ls -1t /DATA/HIGH/*.jpg))

                # Vérifier si le tableau n'est pas vide
                if [ ${#image_list[@]} -ne 0 ]; then
                    echo "Le répertoire pictures contient des fichiers JPG."
                    return 1
                fi
                image_list_low=($(ls -1t /DATA/LOW/*.jpg))

                # Vérifier si le tableau n'est pas vide
                if [ ${#image_list_low[@]} -ne 0 ]; then
                    echo "Le répertoire LOW contient des fichiers JPG."
                    return 1
                fi


                image_list_blur=($(ls -1t /DATA/BLUR/*.jpg))

                # Vérifier si le tableau n'est pas vide
                if [ ${#image_list_blur[@]} -ne 0 ]; then
                    echo "Le répertoire pictures Blur contient des fichiers JPG."
                    return 1
                fi


                # Vérifier si le répertoire logs n'est pas vide
                if [ "$(ls -A /DATA/LOG)" ]; then
                    echo "Le répertoire logs n'est pas vide"
                    return 1
                fi


                # Vérifier si le répertoire logs de la carte SD n'est pas vide
                if [ "$(ls -A /mnt/sdcard/LOG)" ]; then
                    echo "Le répertoire logs de la la carte SD n'est pas vide"
                    return 1
                fi

                if [ -d "/mnt/sdcard/HIGH" ]; then
                    # Récupérer la liste des images sur la carte SD
                    image_listSD=($(ls -1t /mnt/sdcard/HIGH/*.jpg))

                    # Vérifier si le tableau n'est pas vide
                    if [ ${#image_listSD[@]} -ne 0 ]; then
                        echo "Le répertoire HIGH de la carte SD contient des fichiers JPG."
                        return 1
                    fi
                fi
                if [ -d "/mnt/sdcard/LOW" ]; then

                    image_list_lowSD=($(ls -1t /mnt/sdcard/LOW/*.jpg))

                    # Vérifier si le tableau n'est pas vide
                    if [ ${#image_list_lowSD[@]} -ne 0 ]; then
                        echo "Le répertoire pictures LOW de la carte SD contient des fichiers JPG."
                        return 1
                    fi
                fi
                if [ -d "/mnt/sdcard/BLUR" ]; then

                    image_list_blurSD=($(ls -1t /mnt/sdcard/BLUR/*.jpg))

                    # Vérifier si le tableau n'est pas vide
                    if [ ${#image_list_blurSD[@]} -ne 0 ]; then
                        echo "Le répertoire pictures Blur de la carte SD contient des fichiers JPG."
                        return 1
                    fi
                fi
            fi
        fi
        ### si 'config' est en cours
        if pgrep -f "/home/pi/scripts/config.sh" >/dev/null; then
            return 1
        fi

        # Exécuter le script Python
        output=$(python3 /home/pi/scripts/cron.py)

        index=$(echo "$output" | awk 'NR==1')
        tache_min=$(echo "$output" | awk 'NR==2')

        # Extraire la fréquence et récupérer uniquement l'entier
        frequency=$(jq -r ".jobs[$index].frequency" "$JSON_FILE" | cut -d' ' -f1 | grep -o '[0-9]\+')
        #if [ "$frequency" -le 2 ]; then
        #    return 1
        #fi

        frequency_seconds=$((frequency * 60))
        model=$(sed -n '1p' /home/pi/data/info.txt | tr -d '\0')
        if [[ "$model" == *"Raspberry"* ]]; then
            # Calculer le temps jusqu'   la prochaine prise de vue
            time=$(($tache_min - 30))
        else
            # Calculer le temps jusqu'   la prochaine prise de vue
            time=$(($tache_min - 40))
        fi

        echo "$time"
        ### si 'take' est en cours /tmp/take_picture.lock
        if [ -f "/tmp/take_picture.lock" ]; then
            return 1
        fi

        # Vérifier si le temps est supérieur à 20 secondes ( prochaine photo $time + 20 =50 secondes raspberry et 20+40=60 secondes nanopi) 
        if [ "$time" -gt 20 ]; then
                # Calcul de la différence
                difference=$((frequency_seconds - tache_min))

                # difference doit etre positive
                if [ $difference -lt 0 ]; then
                    difference=$(( -1 * difference ))
                fi
                if [ $difference -lt 10 ]; then
                    return 1
                fi
                date_now=$(date +%s)
                echo "$date_now" > /home/pi/data/date.txt
                if [[ "$model" == *"Raspberry"* ]]; then
                    sleep_PI 3 $time
                    poweroff
                    echo "sleep raspberry"
                fi
                sleep_PI 4 $time
                echo "Sleep"
                poweroff
        fi
    fi
}

while true; do

    sleep 2
    # Appel de la fonction check_mode
    check_mode

    if [ -f "/tmp/update.lock" ]; then

       exit 
    fi
done
