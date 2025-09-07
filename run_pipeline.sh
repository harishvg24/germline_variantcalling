#!/bin/bash
# ========================================================
# Genome Variant Calling Pipeline (hg38 reference genome)
# ========================================================
# Author: Harish V G
# GitHub: https://github.com/harishvg24/germline_variantcalling
# note: the final step gatk haplotypecaller is run for one sample , if you want to club multiple samples use -ERC GVCF
#
# This script:
#   1. Downloads raw FASTQ
#   2. Runs QC (FastQC)
#   3. Performs read trimming
#   4. Aligns reads to reference genome (BWA-MEM)
#   5. Processes BAM files (sorting, marking duplicates, BQSR)
#   6. Calls variants using GATK HaplotypeCaller
#
# Usage:
#   bash run_pipeline.sh
#
# Requirements:
#   - Installed via requirements.txt
#   - Mamba environment "gvar" activated
# ========================================================

set -euo pipefail

# --------------------
# VARIABLES
# --------------------
THREADS=36
SAMPLE=SRR622461
REF=~/results/reference/Homo_sapiens_assembly38.fasta

# --------------------
# STEP 1: DOWNLOAD FASTQ
# --------------------
echo "[STEP 1] Downloading FASTQ..."
cd ~/input
fasterq-dump $SAMPLE
pigz -p $THREADS ${SAMPLE}*

# --------------------
# STEP 2: QUALITY CONTROL
# --------------------
echo "[STEP 2] Running FastQC..."
cd ~/results/fastqc
fastqc -t $THREADS ~/input/${SAMPLE}_1.fastq.gz ~/input/${SAMPLE}_2.fastq.gz -o .

# --------------------
# STEP 3: TRIMMING
# --------------------
echo "[STEP 3] Trimming reads..."
cd ~/results/trim
java -Xmx16G -jar $(dirname $(which trimmomatic))/../share/trimmomatic*/trimmomatic.jar PE -threads $THREADS -phred33 \
  ~/input/${SAMPLE}_1.fastq.gz ~/input/${SAMPLE}_2.fastq.gz \
  ${SAMPLE}_1_paired.fq.gz ${SAMPLE}_1_unpaired.fq.gz \
  ${SAMPLE}_2_paired.fq.gz ${SAMPLE}_2_unpaired.fq.gz \
  ILLUMINACLIP:$(dirname $(which trimmomatic))/../share/trimmomatic*/adapters/TruSeq3-PE.fa:2:30:10 \
  LEADING:3 TRAILING:3 SLIDINGWINDOW:4:15 MINLEN:36

# --------------------
# STEP 4: ALIGNMENT
# --------------------
echo "[STEP 4] Aligning with BWA-MEM..."
mkdir -p ~/results/alignment
bwa mem -t $THREADS $REF \
  ~/results/trim/${SAMPLE}_1_paired.fq.gz ~/results/trim/${SAMPLE}_2_paired.fq.gz \
  > ~/results/alignment/${SAMPLE}_aligned.sam

# --------------------
# STEP 5: BAM PROCESSING
# --------------------
echo "[STEP 5] Processing BAM files..."
cd ~/results/bam

# Convert SAM → BAM
samtools view -bS ~/results/alignment/${SAMPLE}_aligned.sam > ${SAMPLE}_aligned.bam

# Sort BAM
samtools sort ${SAMPLE}_aligned.bam -o ${SAMPLE}_aligned.sorted.bam
samtools index ${SAMPLE}_aligned.sorted.bam

# Add Read Groups
picard AddOrReplaceReadGroups \
  I=${SAMPLE}_aligned.sorted.bam \
  O=${SAMPLE}_aligned.rg.bam \
  RGID=$SAMPLE RGLB=lib1 RGPL=ILLUMINA RGPU=unit1 RGSM=$SAMPLE
samtools index ${SAMPLE}_aligned.rg.bam

# Mark Duplicates
gatk MarkDuplicates \
  -I ${SAMPLE}_aligned.rg.bam \
  -O ${SAMPLE}_aligned.dedup.bam \
  -M ${SAMPLE}_duplicates.metrics \
  --REMOVE_DUPLICATES true

# Base Quality Score Recalibration
gatk BaseRecalibrator \
  -I ${SAMPLE}_aligned.dedup.bam \
  -R $REF \
  --known-sites ~/results/reference/Homo_sapiens_assembly38.dbsnp138.vcf \
  --known-sites ~/results/reference/1000G_phase1.snps.high_confidence.hg38.vcf.gz \
  --known-sites ~/results/reference/1000G_omni2.5.hg38.vcf.gz \
  --known-sites ~/results/reference/hapmap_3.3.hg38.vcf.gz \
  --known-sites ~/results/reference/Axiom_Exome_Plus.genotypes.all_populations.poly.hg38.vcf.gz \
  --known-sites ~/results/reference/Mills_and_1000G_gold_standard.indels.hg38.vcf.gz \
  --known-sites ~/results/reference/Homo_sapiens_assembly38.known_indels.vcf.gz \
  -O ${SAMPLE}_recal_data.table

gatk ApplyBQSR \
  -R $REF \
  -I ${SAMPLE}_aligned.dedup.bam \
  --bqsr-recal-file ${SAMPLE}_recal_data.table \
  -O ${SAMPLE}_recal.bam

# --------------------
# STEP 6: VARIANT CALLING
# --------------------
echo "[STEP 6] Running HaplotypeCaller..."
mkdir -p ~/results/vcf
gatk HaplotypeCaller \
  -R $REF \
  -I ${SAMPLE}_recal.bam \
  -O ~/results/vcf/${SAMPLE}.raw.vcf.gz

echo "Pipeline finished successfully ✅"
