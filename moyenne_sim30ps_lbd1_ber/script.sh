#!/bin/bash

# ==========================================
#        VARIABLES À MODIFIER ICI
# ==========================================
SIM_NAME="somename"       # Argument passé à dlpoly.sh
NB_SIMS=20                # Nombre total de simulations à lancer
# ==========================================

# Récupération automatique des noms de dossiers
MODELE_DIR_PATH=$(dirname "$(realpath "$0")")
MODELE_DIR_NAME=$(basename "$MODELE_DIR_PATH")

echo "--- Démarrage de l'automatisation ---"
echo "Dossier modèle : $MODELE_DIR_NAME"
echo "Nombre de runs  : $NB_SIMS"

# On remonte d'un cran pour créer les copies à côté du modèle
cd ..

for i in $(seq 1 $NB_SIMS)
do
    NEW_DIR="${MODELE_DIR_NAME}_run_$i"
    
    # 1. Préparation du dossier
    echo "[Run $i] Copie des fichiers..."
    cp -r "$MODELE_DIR_NAME" "$NEW_DIR"
    
    # 2. Lancement en arrière-plan (grâce aux parenthèses et au &)
    (
        cd "$NEW_DIR" || exit
        
        # Supprimer le script de lancement dans la copie pour rester propre
        rm -f "run_sims.sh"
        
        echo "[Run $i] Simulation lancée sur un cœur libre..."
        
        # Lancement de la simulation (on redirige la sortie vers un log)
        ./dlpoly.sh "$SIM_NAME" > "output_run_$i.log" 2>&1
        
        echo "[Run $i] Simulation terminée (Log: $NEW_DIR/output_run_$i.log)"
    ) &
    
done

# Attendre que TOUTES les simulations lancées en & soient finies avant de rendre la main
echo "----------------------------------------------------"
echo "Toutes les simulations sont lancées en parallèle."
echo "Utilisez 'top' (touche 1) pour voir vos cœurs travailler."
echo "----------------------------------------------------"
wait
echo "Félicitations : les $NB_SIMS simulations sont terminées."


