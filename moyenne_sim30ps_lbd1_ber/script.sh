#!/bin/bash

# ==========================================
#        CONFIGURATION
# ==========================================
SIM_NAME="somename"         
NB_SIMS=10                  
SCRIPT_DL="dlpoly.sh"       
# ==========================================

# On reste dans le dossier actuel
MODELE_DIR=$(pwd)

echo "--- Script Linux de Simulation (Mode Sous-Dossiers) ---"
echo "Les résultats seront créés ici : $MODELE_DIR"

for i in $(seq 1 $NB_SIMS)
do
    # Nom du sous-dossier
    RUN_DIR="run_$i"
    
    # Nettoyage si le sous-dossier existe déjà
    rm -rf "$RUN_DIR"
    
    # On crée le sous-dossier
    mkdir -p "$RUN_DIR"
    
    # On copie tout le contenu du modèle (sauf les dossiers run déjà créés) 
    # dans le sous-dossier
    # On utilise find pour éviter de copier les dossiers "run_" dans eux-mêmes
    find . -maxdepth 1 ! -name "$RUN_DIR" ! -name "run_*" ! -name "." -exec cp -t "$RUN_DIR" -r {} + 2>/dev/null

    # Calcul de l'ID du coeur (0 à 9)
    CPU_ID=$((i - 1))
    
    (
        cd "$RUN_DIR" || exit
        chmod +x "$SCRIPT_DL"
        
        echo "[Run $i] Lancé dans ./$RUN_DIR sur le cœur CPU $CPU_ID"
        
        # Exécution fixée sur le cœur choisi
        taskset -c $CPU_ID ./"$SCRIPT_DL" "$SIM_NAME" > "run.log" 2>&1
        
        echo "[Run $i] Terminé."
    ) &
done

echo "----------------------------------------------------"
echo "Les $NB_SIMS simulations tournent en sous-dossiers."
echo "----------------------------------------------------"

wait
echo "Toutes les simulations sont finies."