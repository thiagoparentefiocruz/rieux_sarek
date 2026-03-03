#!/bin/bash
set -euo pipefail

FASTQ_DIR=""
OUTDIR=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --fastq-dir) FASTQ_DIR=$(readlink -f "$2"); shift 2 ;;
        --outdir) OUTDIR=$(readlink -f "$2"); shift 2 ;;
        *) echo "Erro: Opção $1 não reconhecida em samplesheet."; exit 1 ;;
    esac
done

if [[ -z "$FASTQ_DIR" || -z "$OUTDIR" ]]; then
    echo "Erro: Forneça --fastq-dir e --outdir."
    exit 1
fi

mkdir -p "$OUTDIR"
OUTPUT="${OUTDIR}/nfcore_sarek_samplesheet.csv"

if ! ls "${FASTQ_DIR}"/*_R1_001.fastq.gz >/dev/null 2>&1; then
    echo "Erro: Nenhum *_R1_001.fastq.gz encontrado em $FASTQ_DIR"
    exit 1
fi

# Formato estrito exigido pelo nf-core/sarek
echo "patient,sex,status,sample,lane,fastq_1,fastq_2" > "$OUTPUT"

echo "[INFO] Gerando samplesheet em: $OUTPUT"

for r1_file in "${FASTQ_DIR}"/*_R1_001.fastq.gz; do
    r2_file="${r1_file/_R1_/_R2_}"
    
    if [[ ! -f "$r2_file" ]]; then
        echo "[AVISO] Par R2 não encontrado para $r1_file. Pulando..."
        continue
    fi

    # Extrai o nome da amostra (ID)
    sample_id=$(basename "$r1_file" | sed 's/_L001_.*//')

    # Status: 0 (Normal), Sex: XX (Feminino), Lane: 1
    echo "${sample_id},XX,0,${sample_id},1,${r1_file},${r2_file}" >> "$OUTPUT"
    echo " [+] Adicionada: ${sample_id} [XX/0]"
done

echo "[SUCESSO] Samplesheet pronta!"
