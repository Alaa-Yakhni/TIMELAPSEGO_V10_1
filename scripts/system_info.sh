#!/bin/bash

# Récupérer le chemin du fichier passé en argument
file=$1

# Obtenir la version du firmware
VERSION=$(sudo tlgo-commands -W)
PCB=$(sed -n '2p' /home/pi/data/info.txt)
# Obtenir la tension
voltage=$(sudo tlgo-commands -V)

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
    # Activer le canal 1 pour la caméra et obtenir sa tension
    sudo tlgo-commands -A 1
    voltage_camera=$(sudo tlgo-commands -v)

    # Activer le canal 2 pour  Pi et obtenir sa tension
    sudo tlgo-commands -A 2
    voltage_pi=$(sudo tlgo-commands -v)
    
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
# Écrire les données JSON dans le fichier passé en argument
echo "$json_data" > "$file"

# Vérifier si le fichier spécifié est différent de /home/pi/data/system_info.json
if [ "$file" != "/home/pi/data/system_info.json" ]; then
  echo "$json_data" > /home/pi/data/system_info.json
fi
