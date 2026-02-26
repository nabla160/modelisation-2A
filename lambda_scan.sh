#!/bin/bash
# =============================================================================
#  lambda_scan.sh  —  Scan du paramètre lambda pour DL_POLY (benzène / ZSM-5)
#
#  Lance 10 valeurs de lambda (0.10 … 1.00), 5 runs indépendants chacune,
#  soit 50 simulations séquentielles.
#
#  Prérequis (dans le dossier courant au lancement) :
#    - dlpoly.sh          : script de lancement DL_POLY (non versionné)
#    - files10ps10xlambda/ : contient CONFIG, CONTROL, FIELD.original, DL_ALBNAT
#
#  Usage : ./lambda_scan.sh
# =============================================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
TEMPLATE_DIR="files10ps10xlambda"
OUTPUT_DIR="lambda_scan"
NB_RUNS=5
LOG_FILE="lambda_scan.log"

# Redirige stdout et stderr vers le terminal ET le fichier log
mkdir -p "${OUTPUT_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

# Logue les erreurs avec contexte
trap 'echo "[$(date "+%Y-%m-%d %H:%M:%S")] ERREUR ligne $LINENO : \"$BASH_COMMAND\" (code $?)"' ERR

echo "[$(date '+%Y-%m-%d %H:%M:%S')] Démarrage du scan"

# Paramètres B de référence à lambda = 1.0 (FIELD.original)
C_O_B_REF=1807.0
H_O_B_REF=510.8

# 10 valeurs de lambda : 0.10 à 1.00
LAMBDAS=("0.10" "0.20" "0.30" "0.40" "0.50" "0.60" "0.70" "0.80" "0.90" "1.00")
# ──────────────────────────────────────────────────────────────────────────────

# Vérification des prérequis
for dep in "${TEMPLATE_DIR}/CONFIG" "${TEMPLATE_DIR}/CONTROL" \
           "${TEMPLATE_DIR}/FIELD.original" "${TEMPLATE_DIR}/DL_ALBNAT"; do
    if [[ ! -e "${dep}" ]]; then
        echo "ERREUR : fichier requis introuvable → ${dep}" >&2
        exit 1
    fi
done

echo "======================================================"
echo " Lambda scan : ${#LAMBDAS[@]} valeurs × ${NB_RUNS} runs"
echo " Total : $(( ${#LAMBDAS[@]} * NB_RUNS )) simulations séquentielles"
echo "======================================================"

for j in "${!LAMBDAS[@]}"; do
    lambda="${LAMBDAS[$j]}"

    # Calcul des B scalés (awk pour éviter les problèmes de virgule flottante Bash)
    C_O_B=$(awk -v l="${lambda}" -v b="${C_O_B_REF}" 'BEGIN { printf "%.4f", l*b }')
    H_O_B=$(awk -v l="${lambda}" -v b="${H_O_B_REF}" 'BEGIN { printf "%.4f", l*b }')

    LAMBDA_DIR="${OUTPUT_DIR}/lambda_${lambda}"
    mkdir -p "${LAMBDA_DIR}"

    for i in $(seq 1 ${NB_RUNS}); do
        RUN_DIR="${LAMBDA_DIR}/run_${i}"

        # Nettoyage si le dossier existe déjà
        rm -rf "${RUN_DIR}"
        mkdir -p "${RUN_DIR}"

        # Copie des fichiers de template
        cp "${TEMPLATE_DIR}/CONFIG"         "${RUN_DIR}/"
        cp "${TEMPLATE_DIR}/CONTROL"        "${RUN_DIR}/"
        cp "${TEMPLATE_DIR}/FIELD.original" "${RUN_DIR}/"
        cp "${TEMPLATE_DIR}/DL_ALBNAT"      "${RUN_DIR}/"

        # Graine unique pour chaque run (évite des trajectoires identiques)
        SEED=$(( j * NB_RUNS + i + 1337 ))
        sed -i "s/^seeds.*/seeds        ${SEED} 1 2022/" "${RUN_DIR}/CONTROL"

        # Génération du FIELD avec B scalé par lambda
        # Remplace le dernier champ des lignes C-O et H-O (potentiel 12-6)
        # sed -E : extended regex (compatible macOS/BSD et GNU)
        sed -E \
            -e "s/(C       O       12-6     1\.335E6 +)[0-9.]+/\1${C_O_B}/" \
            -e "s/(H       O       12-6     1\.599E5 +)[0-9.]+/\1${H_O_B}/" \
            "${TEMPLATE_DIR}/FIELD.original" > "${RUN_DIR}/FIELD"

        # Lancement séquentiel
        cd "${RUN_DIR}" || exit 1
        chmod +x DL_ALBNAT

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [λ=${lambda} run ${i}] Démarré..."

        # Simulation DL_POLY
        dlpoly.sh "lbd${lambda}_r${i}" > run.log 2>&1

        # Analyses post-simulation
        thermoDynamics.py  >> run.log 2>&1
        calculateMSD.py C  >> run.log 2>&1
        calculateMSD.py H  >> run.log 2>&1

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [λ=${lambda} run ${i}] Terminé."

        cd - > /dev/null

    done
done

echo ""
echo "======================================================"
echo " Toutes les simulations sont terminées."
echo " Résultats dans : ${OUTPUT_DIR}/"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Scan terminé."
echo "======================================================"
