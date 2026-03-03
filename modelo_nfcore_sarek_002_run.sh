#!/bin/bash
set -euo pipefail

# Verificação essencial do Screen
if [[ -z "${STY:-}" && -z "${TMUX:-}" ]]; then
    echo "================================================================================="
    echo " ATENÇÃO: Você não está rodando isso dentro de uma sessão screen ou tmux!"
    echo " Se a sua conexão de internet cair ou o computador hibernar, o pipeline morre."
    echo " Recomendo cancelar agora (Ctrl+C), abrir um screen e rodar de novo."
    echo " Se você não sabe o que é um screen, pesquise na internet para saber como se usa."
    echo " É bem simples!"
    echo "================================================================================="
    sleep 5
fi

MODE=""
SAMPLESHEET=""
BED_FILE=""
OUTDIR_BASE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --mode) MODE="$2"; shift 2 ;;
        --samplesheet) SAMPLESHEET=$(readlink -f "$2"); shift 2 ;;
        --bed_file) BED_FILE=$(readlink -f "$2"); shift 2 ;;
        --outdir) OUTDIR_BASE=$(readlink -f "$2"); shift 2 ;;
        *) echo "Erro: Opção $1 não reconhecida em run."; exit 1 ;;
    esac
done

if [[ -z "$SAMPLESHEET" || -z "$OUTDIR_BASE" ]]; then
    echo "Erro: --samplesheet e --outdir são obrigatórios."
    exit 1
fi

RUN_ID="run_v381_$(date +%Y%m%d_%H%M%S)"
OUTDIR="${OUTDIR_BASE}/${RUN_ID}"
LOGS_DIR="${OUTDIR}/logs"
INPUTS_DIR="${OUTDIR_BASE}/../sarek_run_input_files" # Assume a estrutura padrão

mkdir -p "$OUTDIR" "$LOGS_DIR" "$INPUTS_DIR"

# Rastreabilidade: Link simbólico do BED para a pasta de inputs do projeto
if [[ -n "$BED_FILE" && -f "$BED_FILE" ]]; then
    TARGET_BED="${INPUTS_DIR}/$(basename "$BED_FILE")"
    
    # Só cria o link se o arquivo de origem e o destino não forem exatamente os mesmos
    if [[ "$(readlink -f "$BED_FILE")" != "$(readlink -f "$TARGET_BED")" ]]; then
        ln -sf "$BED_FILE" "$TARGET_BED"
    fi
else
    TARGET_BED=""
fi

export NXF_HOME="${HOME}/.nextflow"
SCRATCH_DIR="/scratch/${USER}/sarek_${RUN_ID}"
export NXF_SINGULARITY_CACHEDIR="${SCRATCH_DIR}/nxf_singularity_cache"
export SINGULARITY_CACHEDIR="${SCRATCH_DIR}/singularity_cache"
export SINGULARITY_TMPDIR="${SCRATCH_DIR}/singularity_tmp"
mkdir -p "$NXF_SINGULARITY_CACHEDIR" "$SINGULARITY_CACHEDIR" "$SINGULARITY_TMPDIR"
ln -s ${SINGULARITY_LIBRARY}/* "$NXF_SINGULARITY_CACHEDIR/" 2>/dev/null || true

module purge >/dev/null 2>&1 || true
module load samtools/1.22.1 openjdk/19.0.1 nextflow/25.10.2 >/dev/null 2>&1 || true

JAVA_BIN="$(readlink -f "$(command -v java)")"
export JAVA_HOME="$(dirname "$(dirname "$JAVA_BIN")")"
export PATH="$JAVA_HOME/bin:$PATH"

export NXF_WORK="${SCRATCH_DIR}/work"
mkdir -p "$NXF_WORK"

cat <<EOF > "${SCRATCH_DIR}/slurm.config"
process { executor = 'slurm'; queue = 'fat' }
singularity { cacheDir = '${NXF_SINGULARITY_CACHEDIR}' }
EOF

if [[ ! -f "${GENOME_FASTA}.fai" ]]; then samtools faidx "$GENOME_FASTA"; fi

export NXF_UPDATE="false"
NXF_CMD="nextflow run $PIPELINE -name ${RUN_ID} -profile singularity -c ${SCRATCH_DIR}/slurm.config \
  --igenomes_ignore true --tools haplotypecaller,vep --input $SAMPLESHEET --outdir $OUTDIR \
  --fasta $GENOME_FASTA --fasta_fai ${GENOME_FASTA}.fai --dict $GENOME_DICT --bwa $BWAMEM_INDEX_DIR \
  --dbsnp $KNOWN_DBSNP --vep_cache $VEP_CACHE_DIR --vep_cache_version $VEP_CACHE_VERSION \
  --vep_species homo_sapiens --vep_genome GRCh38 -work-dir $NXF_WORK \
  -with-report $LOGS_DIR/nf-report.html -with-trace $LOGS_DIR/nf-trace.txt -with-timeline $LOGS_DIR/nf-timeline.html"

if [[ -n "$TARGET_BED" ]]; then
    NXF_CMD="$NXF_CMD --intervals $TARGET_BED"
fi

if [[ "$MODE" == "panel" ]]; then
    echo "[INFO] Modo Painel: Bypass do filtervarianttranches ativado."
    NXF_CMD="$NXF_CMD --skip_tools haplotypecaller_filter"
fi

echo "[INFO] Iniciando Sarek no nó MGT1 para o Rieux..."
eval $NXF_CMD
