#!/bin/bash
set -euo pipefail

SAREK_OUTDIR=$1
ABRAOM_DB=$2

RUN_NAME=$(basename "$SAREK_OUTDIR")
OUTPUT="${SAREK_OUTDIR}/${RUN_NAME}_tabela_mestra_variantes.tsv"
OUTPUT_FILTERED="${SAREK_OUTDIR}/${RUN_NAME}_priorizadas.tsv"

module load bcftools >/dev/null 2>&1 || true
VEP_DIR="${SAREK_OUTDIR}/annotation"

if [[ ! -d "$VEP_DIR" ]]; then
    echo "Erro: Pasta 'annotation' não encontrada em $SAREK_OUTDIR"
    exit 1
fi

echo -e "Amostra\tGene\tMutacao\tDP\tVAF(%)\tConsequencia\tFreq_gnomAD\tFreq_ABraOM" > "$OUTPUT"
echo "[INFO] Sumarizando variantes (Usando ABraOM: $ABRAOM_DB)"

find "$VEP_DIR" -name "*.vcf.gz" | while read VCF; do
    SAMPLE_NAME=$(basename "$VCF" | cut -d'.' -f1)
    echo " [+] Extraindo: $SAMPLE_NAME"

    CSQ_FORMAT=$(bcftools view -h "$VCF" | grep 'ID=CSQ' | sed 's/.*Format: //; s/">//' || echo "")
    if [[ -z "$CSQ_FORMAT" ]]; then continue; fi

    IDX_GENE=$(echo "$CSQ_FORMAT" | tr '|' '\n' | grep -nx 'SYMBOL' | cut -d: -f1)
    IDX_CONSQ=$(echo "$CSQ_FORMAT" | tr '|' '\n' | grep -nx 'Consequence' | cut -d: -f1)
    IDX_GNOMAD=$(echo "$CSQ_FORMAT" | tr '|' '\n' | grep -nx 'gnomADe_AF' | cut -d: -f1 || echo "")
    if [[ -z "$IDX_GNOMAD" ]]; then IDX_GNOMAD=$(echo "$CSQ_FORMAT" | tr '|' '\n' | grep -nx 'MAX_AF' | cut -d: -f1); fi

    HDR_ABRAOM=$(mktemp)
    echo '##INFO=<ID=ABRAOM_AF,Number=1,Type=Float,Description="Allele Frequency from ABraOM">' > "$HDR_ABRAOM"

    bcftools annotate -a "$ABRAOM_DB" -c CHROM,POS,REF,ALT,-,-,-,-,-,-,-,-,-,-,INFO/ABRAOM_AF -h "$HDR_ABRAOM" "$VCF" | \
    bcftools query -f '[%SAMPLE]\t%CHROM\t%POS\t%REF\t%ALT\t[%DP]\t[%AD]\t%INFO/ABRAOM_AF\t%INFO/CSQ\n' | \
    awk -F'\t' -v igene="$IDX_GENE" -v iconsq="$IDX_CONSQ" -v ignomad="$IDX_GNOMAD" '
    {
        sample = $1; chr = $2; pos = $3; ref = $4; alt = $5; dp = $6; ad = $7; abraom = $8; csq_full = $9
        if (abraom == ".") abraom = "0.0"

        split(ad, ad_arr, ","); ref_reads = ad_arr[1]; alt_reads = ad_arr[2]
        total = ref_reads + alt_reads
        vaf = (total > 0) ? sprintf("%.1f", (alt_reads / total) * 100) : "0.0"

        split(csq_full, transcripts, ","); split(transcripts[1], csq, "|")
        gene = csq[igene]; consq = csq[iconsq]; gnomad = csq[ignomad]
        
        if (gnomad == "") gnomad = "0.0"
        if (gene == "") gene = "Intergenic"

        printf "%s\t%s\t%s:%s %s>%s\t%s\t%s\t%s\t%s\t%s\n", sample, gene, chr, pos, ref, alt, dp, vaf, consq, gnomad, abraom
    }' >> "$OUTPUT"
    rm -f "$HDR_ABRAOM"
done

echo "[INFO] Aplicando filtros clínicos..."
awk -F'\t' 'NR==1 {print $0; next} { if (($7 < 0.01 || $7 == "0.0") && ($8 < 0.01 || $8 == "0.0") && $6 !~ /synonymous|intron_variant|intergenic|upstream|downstream|regulatory/) print $0 }' "$OUTPUT" > "$OUTPUT_FILTERED"

echo "[SUCESSO] Tabelas geradas na pasta da corrida!"
