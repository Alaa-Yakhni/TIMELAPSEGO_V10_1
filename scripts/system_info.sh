#!/bin/bash

# Récupérer le chemin du fichier passé en argument
file=$1


PCB=$(sed -n '2p' /home/pi/data/info.txt)

if [ "$PCB" == "PCBv3" ]; then

throttled=$(vcgencmd get_throttled)

if [ "$throttled" == "0x500001" ]; then
   voltage=11
else
   voltage=13
fi

   json_data=$(cat <<EOF
{
    "voltage": $voltage,
    "VERSION": "PCBv3"
}
EOF
)

else
# Obtenir la version du firmware
VERSION=$(sudo tlgo-commands -W)

max_attempts=2
attempt=0
# Boucle pour obtenir la tension
while [ $attempt -lt $max_attempts ]; do
    # Obtenir la tension
    voltage=$(sudo tlgo-commands -V)
    
    # Vérifier si la valeur est valide (ajustez la condition selon vos besoins)
    if [[ "$voltage" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        echo "Tension obtenue : $voltage V"
        break  # Sortir de la boucle si la tension est valide
    else
        echo "Valeur de tension invalide. Nouvelle tentative..."
        attempt=$((attempt + 1))
        sleep 0.2  # Attendre 
    fi
done

# Si toutes les tentatives échouent, initialiser à 12
if [ $attempt -eq $max_attempts ]; then
    voltage=12
    echo "Valeur de tension initialisée à : $voltage V"
fi

if [ "$PCB" == "PCBv10" ]; then
        # Exécuter le script pour récupérer les données du capteur
        output=$(sudo python3 /home/pi/scripts/sensor.py -b 1)
fi


if [ "$PCB" == "PCBv9" ]; then
        # Exécuter le script pour récupérer les données du capteur
        output=$(sudo python3 /home/pi/scripts/sensor.py -b 0)
fi


if [ "$PCB" == "PCBv10" ] || [ "$PCB" == "PCBv9" ]; then	

	# Extraire les valeurs de température, pression et humidité
	temperature=$(echo "$output" | grep -oP 'Temperature : \K\d+\.\d+')
	pressure=$(echo "$output" | grep -oP 'Pressure : \K\d+\.\d+')
	humidity=$(echo "$output" | grep -oP 'Humidity : \K\d+\.\d+')
fi
# Créer une structure JSON avec les données extraites
if [ "$PCB" = "PCBv10" ]; then
    
    max_attempts=2
    attempt=0

    # Boucle pour obtenir la tension
    while [ $attempt -lt $max_attempts ]; do
        # Activer le canal 1 pour la caméra et obtenir sa tension
        sudo tlgo-commands -A 1
        voltage_camera=$(sudo tlgo-commands -v)
    
        # Vérifier si la valeur est valide 
        if [[ "$voltage_camera" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo "Tension obtenue : $voltage_camera V"
            break  # Sortir de la boucle si la tension est valide
        else
            echo "Valeur de tension invalide. Nouvelle tentative..."
            attempt=$((attempt + 1))
            sleep 0.2  # Attendre 
        fi
    done

    # Si toutes les tentatives échouent, initialiser à 12
    if [ $attempt -eq $max_attempts ]; then
        voltage_camera=8
        echo "Valeur de tension initialisée à : $voltage_camera V"
    fi

    max_attempts=2
    attempt=0

    # Boucle pour obtenir la tension
    while [ $attempt -lt $max_attempts ]; do
        
        # Activer le canal 2 pour  Pi et obtenir sa tension
        sudo tlgo-commands -A 2
        voltage_pi=$(sudo tlgo-commands -v)
    
        # Vérifier si la valeur est valide 
        if [[ "$voltage_pi" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            echo "Tension obtenue : $voltage_pi V"
            break  # Sortir de la boucle si la tension est valide
        else
            echo "Valeur de tension invalide. Nouvelle tentative..."
            attempt=$((attempt + 1))
            sleep 0.2  # Attendre 
        fi
    done

    # Si toutes les tentatives échouent, initialiser à 12
    if [ $attempt -eq $max_attempts ]; then
        voltage_pi=5
        echo "Valeur de tension initialisée à : $voltage_pi V"
    fi



    if [ -n "$temperature" ] && [ -n "$pressure" ] && [ -n "$humidity" ]; then 

        json_data=$(cat <<EOF
{
    "temperature": $temperature,
    "pressure": $pressure,
    "humidity": $humidity,
    "voltage": $voltage,
    "VERSION": "$VERSION",
    "voltage_camera": $voltage_camera,
    "voltage_pi": $voltage_pi
}
EOF
)

    else 
json_data=$(cat <<EOF
{
    "voltage": $voltage,
    "VERSION": "$VERSION",
    "voltage_camera": $voltage_camera,
    "voltage_pi": $voltage_pi
}
EOF
)
    fi
    
elif [ -n "$temperature" ] && [ -n "$pressure" ] && [ -n "$humidity" ]; then 
      json_data=$(cat <<EOF
{
    "temperature": $temperature,
    "pressure": $pressure,
    "humidity": $humidity,
    "voltage": $voltage,
    "VERSION": "$VERSION"
}
EOF
)

else 
      json_data=$(cat <<EOF
{
    "voltage": $voltage,
    "VERSION": "$VERSION"
}
EOF
)
fi

fi
# Écrire les données JSON dans le fichier passé en argument
echo "$json_data" > "$file"

# Vérifier si le fichier spécifié est différent de /home/pi/data/system_info.json
if [ "$file" != "/home/pi/data/system_info.json" ]; then
  echo "$json_data" > /home/pi/data/system_info.json
fi

