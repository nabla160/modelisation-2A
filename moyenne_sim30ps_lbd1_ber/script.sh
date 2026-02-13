#!/bin/bash

# ==========================================
#        CONFIGURATION (Facile à modifier)
# ==========================================
SIM_NAME="somename"         # L'argument pour dlpoly.sh
NB_SIMS=10                  # Nombre de simulations (tu as 58 coeurs, c'est large)
SCRIPT_DL="dlpoly.sh"       # Le nom du script de simulation
# ==========================================

# Récupère le nom du dossier où se trouve ce script (le modèle)
MODELE_DIR=$(cd "$(dirname "$0")" && pwd)
MODELE_NAME=$(basename "$MODELE_DIR")

echo "--- Script Linux de Simulation ---"
echo "Modèle détecté : $MODELE_NAME"

# On remonte d'un étage pour créer les copies à côté du modèle
cd ..

for i in $(seq 1 $NB_SIMS)
do
    RUN_DIR="${MODELE_NAME}_run_$i"
    
    # Nettoyage si le dossier existe déjà (évite les erreurs)
    rm -rf "$RUN_DIR"
    
    # Copie propre du modèle
    cp -r "$MODELE_NAME" "$RUN_DIR"
    
    # Lancement en arrière-plan (parallélisation sur tes coeurs)
    (
        cd "$RUN_DIR" || exit
        chmod +x "$SCRIPT_DL"
        
        echo "[Run $i] Simulation démarrée..."
        
        # Exécution : on capture tout dans un log pour ne pas polluer l'écran
        ./"$SCRIPT_DL" "$SIM_NAME" > "run.log" 2>&1
        
        echo "[Run $i] Terminé avec succès."
    ) &
done

echo "----------------------------------------------------"
echo "Les $NB_SIMS simulations tournent sur tes coeurs."
echo "Pour voir l'activité : tape 'top' puis la touche '1'."
echo "----------------------------------------------------"

# Attente de la fin de tous les processus fils
wait
echo "Bravo : toutes les simulations sont finies."