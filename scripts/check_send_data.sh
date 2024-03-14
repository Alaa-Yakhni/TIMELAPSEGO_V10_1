#!/bin/bash

# Vérifier si le script send_picture est en cours d'exécution
if pgrep -f "send_picture.sh" >/dev/null; then
    echo "Le script  est déjà en cours d'exécution." >> /home/pi/test.txt
else
    echo "Le script  n'est pas en cours d'exécution. Lancement du script..." >> /home/pi/test.txt
    # Ajoutez ici la commande pour lancer le script send.sh
    /home/pi/scripts/send_picture.sh
fi

# Ajoutez ici les commandes pour prendre la photo
# Exemple : raspistill -o image.jpg
