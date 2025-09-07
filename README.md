# Germline Variant Calling Pipeline

This repository contains a complete germline variant calling pipeline using GATK Best Practices.

## Files
- guide_to_install_mamba.md : Instructions to install Mamba
- requirements.txt          : Tool installations, reference downloads, directory setup
- run_pipeline.sh            : Main pipeline script (FASTQ → VCF)

## Usage
1. Follow the guide to install Mamba and create an environment.
2. Run commads in requirements.txt to install tools and references directly from mamba and google cloud bucket.
3. give execution permission using chmod +x run_pipeline.sh
4. Execute the pipeline using bash run_pipeline.sh


