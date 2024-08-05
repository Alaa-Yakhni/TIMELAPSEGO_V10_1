#!/usr/bin/env python3
# Import des modules nécessaires
from crontab import CronTab
from datetime import datetime

# Fonction pour calculer le temps restant jusqu'à la prochaine exécution d'une tâche cron
def temps_restant_jusqu_a_prochaine_execution(tache_cron):
    maintenant = datetime.now()
    # Calcul de la prochaine exécution de la tâche cron par rapport à l'heure actuelle
    prochaine_exec = tache_cron.schedule(date_from=maintenant).get_next()
    # Calcul du temps restant jusqu'à la prochaine exécution
    temps_restant = prochaine_exec - maintenant
    # Conversion du temps restant en minutes et secondes
    minutes_restantes = int(temps_restant.total_seconds() // 60)
    secondes_restantes = int(temps_restant.total_seconds() % 60)
    return minutes_restantes, secondes_restantes

# Fonction pour charger les tâches cron depuis un fichier crontab spécifié
def charger_taches_cron(chemin_crontab):
    try:
        # Charger les tâches cron depuis le fichier spécifié
        return CronTab(tabfile=chemin_crontab)
    except FileNotFoundError:
        # Gérer l'exception si le fichier crontab n'existe pas
        print(f"Le fichier crontab {chemin_crontab} n'existe pas.")
    except Exception as e:
        # Gérer toute autre exception lors du chargement des tâches cron
        print(f"Une erreur s'est produite lors du chargement des tâches cron depuis {chemin_crontab} : {e}")
    return None

# Fonction principale
def main():
    # Chemin vers le fichier crontab contenant les tâches à surveiller
    chemin_crontab_take_picture = '/etc/cron.d/take_picture'

    # Charger les tâches cron depuis le fichier spécifié
    cron_take_picture = charger_taches_cron(chemin_crontab_take_picture)

    # Si aucun fichier crontab n'a été chargé avec succès, arrêter l'exécution de la fonction
    if cron_take_picture is None:
        return

    # Initialiser la liste pour toutes les tâches et leurs temps restants
    toutes_les_taches = []

    # Variable pour suivre la tâche avec le temps minimum restant
    temps_min_restant = None
    tache_min = None
    index_min = None

    # Parcourir toutes les tâches cron chargées
    for index, tache in enumerate(cron_take_picture):
        # Vérifier si la ligne de la tâche cron ne commence pas par '#'
        if not tache.render().strip().startswith("#"):
            # Calculer le temps restant jusqu'à la prochaine exécution de la tâche
            minutes_restantes, secondes_restantes = temps_restant_jusqu_a_prochaine_execution(tache)
            # Convertir le temps restant en secondes
            temps_restant_total = minutes_restantes * 60 + secondes_restantes
            # Ajouter la tâche et son temps restant à la liste
            toutes_les_taches.append((index, tache, temps_restant_total))
            # Mettre à jour la tâche la plus proche si nécessaire
            if temps_min_restant is None or temps_restant_total < temps_min_restant:
                temps_min_restant = temps_restant_total
                tache_min = tache
                index_min = index

    

    # Afficher l'index de la tâche la plus proche et son temps restant
    if tache_min is not None:
        
        print(index_min)
        print(int(temps_min_restant))
    else:
        print("Aucune tache a executer dans le futur.")

# Vérifier si le script est exécuté en tant que programme principal
if __name__ == "__main__":
    # Appeler la fonction principale
    main()
