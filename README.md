# Sarek @ Rieux CLI Wrapper

https://doi.org/10.5281/zenodo.18852917

A custom command-line interface (CLI) wrapper designed to orchestrate the [nf-core/sarek](https://nf-co.re/sarek) (v3.8.1) variant calling pipeline specifically for the Rieux High-Performance Computing (HPC) cluster. 

This tool automates samplesheet generation, SLURM job submission, bypasses standard whole-genome filters for targeted gene panels, and synthesizes clinical variant tables using local population databases (ABraOM).

## 🚀 Features
* **Automated Samplesheet Construction**: Instantly formats FASTQ directories into strict nf-core/sarek CSV inputs.
* **HPC & SLURM Integration**: Prevents internet-connection drops by enforcing `screen` usage and seamlessly routes heavy downstream jobs to CPU nodes via SLURM.
* **Panel-Specific Optimization**: Custom Nextflow parameters to rescue true-positive variants often discarded by standard GATK HaplotypeCaller filters in small targeted panels (e.g., BRCA1/BRCA2).
* **Clinical Variant Synthesis**: Automatically annotates VEP outputs with the Brazilian ABraOM database and filters variants based on clinical relevance (VAF, DP, consequence, and MAF < 1%).
* **Depth Consolidation**: Generates actionable target-region coverage reports using Mosdepth and user-provided BED files.

## 🛠️ Usage

The wrapper operates through three main modules:

### 1. Build the Samplesheet
```bash
rieux_sarek samplesheet --fastq-dir /path/to/fastqs/ --outdir /path/to/inputs/
```

### 2. Run the Pipeline (Panel Mode)
```Bash
rieux_sarek run --mode panel \
  --samplesheet /path/to/inputs/nfcore_sarek_samplesheet.csv \
  --bed_file /path/to/inputs/target_panel.bed \
  --outdir /path/to/sarek_run/
```
### 3. Generate Final Clinical Reports
Submit the variant synthesis and depth consolidation to the SLURM queue:
```Bash
# For Variant Prioritization (VCF synthesis)
rieux_sarek report --type variants --outdir /path/to/sarek_run/run_ID

# For Coverage Depth Analysis
rieux_sarek report --type depth --bed_file /path/to/inputs/target_panel.bed --outdir /path/to/sarek_run/run_ID
```
📄 Citation
If you use this wrapper in your research, please cite the upcoming paper (DOI: 10.5281/zenodo.18852917) and the original nf-core/sarek publication.
