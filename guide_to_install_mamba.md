# Guide to Install Mamba and Create Environment

This guide explains how to install **Mamba** (a faster Conda package manager) and create a dedicated environment for this pipeline.

---

## Step 1: Download Miniforge (Mamba-enabled Conda installer)

bash wget https://github.com/conda-forge/miniforge/releases/download/25.3.1-0/Miniforge3-25.3.1-0-Linux-x86_64.sh

## Enter -> Yes -> Enter -> Yes

source ~/.bashrc

## create an environment to download necessary tools to run the pipelioen and activate 
mamba create -n gvar python=3.10
mamba activate gvar

