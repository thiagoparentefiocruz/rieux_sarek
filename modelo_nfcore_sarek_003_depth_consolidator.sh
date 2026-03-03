#!/bin/bash
set -euo pipefail

SAREK_OUTDIR=$1
PAINEL_BED=$2

# Captura o nome da pasta de corrida para padronizar o output
RUN_NAME=$(basename "$SAREK_OUTDIR")
OUTPUT="${SAREK_OUTDIR}/${RUN_NAME}_cobertura_detalhada.tsv"
TMP_DIR="${SAREK_OUTDIR}/tmp_depth_$(date +%s)"

MOSDEPTH_DIR="${SAREK_OUTDIR}/reports/mosdepth"

if [[ ! -d "$MOSDEPTH_DIR" ]]; then
    echo "Erro: Pasta 'mosdepth' não encontrada em $MOSDEPTH_DIR"
    exit 1
fi

mkdir -p "$TMP_DIR"
SAMPLES=()

echo "[INFO] Analisando cobertura a partir de: $MOSDEPTH_DIR"

for sample_path in "$MOSDEPTH_DIR"/*/; do
    SAMPLE_NAME=$(basename "$sample_path")
    SAMPLES+=("$SAMPLE_NAME")
    
    FILE=$(ls "${sample_path}${SAMPLE_NAME}.recal.regions.bed.gz" 2>/dev/null || ls "${sample_path}${SAMPLE_NAME}.md.regions.bed.gz" 2>/dev/null || true)
    
    if [[ ! -f "$FILE" ]]; then continue; fi
    echo " [+] Processando: $SAMPLE_NAME"
    
    zcat "$FILE" | awk -v bed="$PAINEL_BED" '
        BEGIN { 
            while(getline < bed > 0) { chr[i]=$1; s[i]=$2; e[i]=$3; n[i]=$4; valid_chr[$1] = 1; i++ }; total=i 
        }
        !valid_chr[$1] { next }
        { 
            for(j=0; j<total; j++) { 
                if($1 == chr[j] && $2 < e[j] && $3 > s[j]) { sum[j]+=$4; count[j]++; } 
            } 
        }
        END { 
            for(j=0; j<total; j++) { 
                final_mean = (count[j] > 0 ? sum[j]/count[j] : 0);
                printf "%.1f\n", final_mean
            }
        }' > "${TMP_DIR}/${SAMPLE_NAME}.col"
done

printf "Gene\tCromossomo\tInicio\tFim\t%s\n" "$(IFS=$'\t'; echo "${SAMPLES[*]}")" > "$OUTPUT"
paste <(awk '{print $4 "\t" $1 "\t" $2 "\t" $3}' "$PAINEL_BED") "${TMP_DIR}"/*.col >> "$OUTPUT"

rm -rf "$TMP_DIR"
echo "[SUCESSO] Relatório gerado: $OUTPUT"
