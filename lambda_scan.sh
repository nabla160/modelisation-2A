#!/bin/bash
# =============================================================================
#  lambda_scan.sh  —  Scan du paramètre lambda pour DL_POLY (benzène / ZSM-5)
#
#  Lance 10 valeurs de lambda (0.10 … 1.00), 5 runs indépendants chacune,
#  soit 50 simulations avec 4 cœurs par job (25 jobs simultanés max sur 100 cœurs).
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
CORES_PER_JOB=4
TOTAL_CORES=100
MAX_JOBS=$(( TOTAL_CORES / CORES_PER_JOB ))   # 25 jobs simultanés

# Auto-détachement : rend la main immédiatement si lancé en premier plan
if [[ "${LAMBDA_SCAN_DETACHED:-0}" != "1" ]]; then
    mkdir -p "${OUTPUT_DIR}"
    LAMBDA_SCAN_DETACHED=1 nohup "$0" "$@" >> "${LOG_FILE}" 2>&1 &
    echo "Scan lancé en arrière-plan (PID $!)."
    echo "Suivez la progression : tail -f ${LOG_FILE}"
    exit 0
fi

# Redirige stdout et stderr vers le fichier log
exec >> "${LOG_FILE}" 2>&1

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
echo " Total : $(( ${#LAMBDAS[@]} * NB_RUNS )) simulations en parallèle"
echo "======================================================"

for j in "${!LAMBDAS[@]}"; do
    lambda="${LAMBDAS[$j]}"

    # Calcul des B scalés (awk pour éviter les problèmes de virgule flottante Bash)
    C_O_B=$(awk -v l="${lambda}" -v b="${C_O_B_REF}" 'BEGIN { printf "%.4f", l*b }')
    H_O_B=$(awk -v l="${lambda}" -v b="${H_O_B_REF}" 'BEGIN { printf "%.4f", l*b }')

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [λ=${lambda}] C_O_B=${C_O_B}  H_O_B=${H_O_B}"

    LAMBDA_DIR="${OUTPUT_DIR}/lambda_${lambda}"
    mkdir -p "${LAMBDA_DIR}"

    for i in $(seq 1 ${NB_RUNS}); do
        # File d'attente : attend qu'un slot se libère
        while [[ $(jobs -r | wc -l) -ge ${MAX_JOBS} ]]; do
            wait -n 2>/dev/null || true
        done

        JOB_IDX=$(( j * NB_RUNS + (i - 1) ))
        CPU_START=$(( (JOB_IDX % MAX_JOBS) * CORES_PER_JOB ))
        CPU_END=$(( CPU_START + CORES_PER_JOB - 1 ))   # plages 0-7, 8-15, … 88-95 (cyclique)
        RUN_DIR="${LAMBDA_DIR}/run_${i}"
        SEED=$(( j * NB_RUNS + i + 1337 ))

        # Nettoyage si le dossier existe déjà
        rm -rf "${RUN_DIR}"
        mkdir -p "${RUN_DIR}"

        # Copie des fichiers de template
        cp "${TEMPLATE_DIR}/CONFIG"         "${RUN_DIR}/"
        cp "${TEMPLATE_DIR}/CONTROL"        "${RUN_DIR}/"
        cp "${TEMPLATE_DIR}/FIELD.original" "${RUN_DIR}/"
        cp "${TEMPLATE_DIR}/DL_ALBNAT"      "${RUN_DIR}/"

        # Graine unique pour chaque run (évite des trajectoires identiques)
        sed -i "s/^seeds.*/seeds        ${SEED} 1 2022/" "${RUN_DIR}/CONTROL"

        # Génération du FIELD avec B scalé par lambda
        sed -E \
            -e "s/(C       O       12-6     1\.335E6 +)[0-9.]+/\1${C_O_B}/" \
            -e "s/(H       O       12-6     1\.599E5 +)[0-9.]+/\1${H_O_B}/" \
            "${TEMPLATE_DIR}/FIELD.original" > "${RUN_DIR}/FIELD"

        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [λ=${lambda} run ${i}] Préparé (seed=${SEED}, cœurs=${CPU_START}-${CPU_END})"

        # Lancement en arrière-plan sur le cœur dédié
        (
            TAG="[λ=${lambda} run ${i}]"
            cd "${RUN_DIR}" || exit 1
            chmod +x DL_ALBNAT

            log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${TAG} $*"; }

            log "Simulation DL_POLY démarrée..."
            if taskset -c "${CPU_START}-${CPU_END}" dlpoly.sh "lbd${lambda}_r${i}" 4 > run.log 2>&1; then
                log "Simulation DL_POLY terminée."
            else
                log "ERREUR : DL_POLY a échoué (code $?) — voir run.log"
                exit 1
            fi

            log "Analyse thermodynamique..."
            if thermoDynamics.py >> run.log 2>&1; then
                log "thermoDynamics.py OK."
            else
                log "ERREUR : thermoDynamics.py a échoué (code $?) — voir run.log"
            fi

            log "Calcul MSD (C)..."
            if calculateMSD.py C >> run.log 2>&1; then
                log "calculateMSD.py C OK."
            else
                log "ERREUR : calculateMSD.py C a échoué (code $?) — voir run.log"
            fi

            log "Calcul MSD (H)..."
            if calculateMSD.py H >> run.log 2>&1; then
                log "calculateMSD.py H OK."
            else
                log "ERREUR : calculateMSD.py H a échoué (code $?) — voir run.log"
            fi

            log "Run complet."
        ) &

    done
done

echo ""
echo "50 simulations lancées. En attente de la fin..."
wait
echo ""
echo "======================================================"
echo " Toutes les simulations sont terminées."
echo " Résultats dans : ${OUTPUT_DIR}/"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Scan terminé."
echo "======================================================"
