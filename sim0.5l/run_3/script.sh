SIM_NAME="somename"         
NB_SIMS=10                  
SCRIPT_DL="dlpoly.sh"       
MODELE_DIR=$(pwd)

echo "--- Script Linux de Simulation (Mode Sous-Dossiers) ---"
echo "Les résultats seront créés ici : $MODELE_DIR"

for i in $(seq 1 $NB_SIMS)
do
       RUN_DIR="run_$i"
    
        rm -rf "$RUN_DIR"
    
        mkdir -p "$RUN_DIR"
    
       find . -maxdepth 1 ! -name "$RUN_DIR" ! -name "run_*" ! -name "." -exec cp -t "$RUN_DIR" -r {} + 2>/dev/null

       CPU_ID=$((i - 1))
    
    (
        cd "$RUN_DIR" || exit
        chmod +x "$SCRIPT_DL"
        
        echo "[Run $i] Lancé dans ./$RUN_DIR sur le cœur CPU $CPU_ID"
        
        taskset -c $CPU_ID "$SCRIPT_DL" "$SIM_NAME" > "run.log" 2>&1
        
        echo "[Run $i] Terminé."
    ) &
done

echo "----------------------------------------------------"
echo "Les $NB_SIMS simulations tournent en sous-dossiers."
echo "----------------------------------------------------"

wait
echo "Toutes les simulations sont finies."