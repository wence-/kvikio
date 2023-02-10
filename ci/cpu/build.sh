#!/bin/bash
# Copyright (c) 2022-2023, NVIDIA CORPORATION.
##############################################
# kvikIO CPU conda build script for CI       #
##############################################
set -e

# Set path and build parallel level
export PATH=/opt/conda/bin:/usr/local/cuda/bin:$PATH
export PARALLEL_LEVEL=${PARALLEL_LEVEL:-4}

# Set home to the job's workspace
export HOME="$WORKSPACE"

# Determine CUDA release version
export CUDA_REL=${CUDA_VERSION%.*}

# Setup 'gpuci_conda_retry' for build retries (results in 2 total attempts)
export GPUCI_CONDA_RETRY_MAX=1
export GPUCI_CONDA_RETRY_SLEEP=30

# Workaround to keep Jenkins builds working
# until we migrate fully to GitHub Actions
export RAPIDS_CUDA_VERSION="${CUDA}"
export SCCACHE_BUCKET=rapids-sccache
export SCCACHE_REGION=us-west-2
export SCCACHE_IDLE_TIMEOUT=32768
export RAPIDS_DATE_STRING=$(date +%y%m%d)

# Use Ninja to build, setup Conda Build Dir
# export CMAKE_GENERATOR="Ninja"
export CONDA_BLD_DIR="$WORKSPACE/.conda-bld"

# Switch to project root; also root of repo checkout
cd "$WORKSPACE"

export RAPIDS_DATE_STRING=$(date +%y%m%d)

################################################################################
# SETUP - Check environment
################################################################################

gpuci_logger "Check environment variables"
env

gpuci_logger "Activate conda env"
. /opt/conda/etc/profile.d/conda.sh
conda activate rapids

# Remove rapidsai-nightly channel if we are building main branch
if [ "$SOURCE_BRANCH" = "main" ]; then
  conda config --system --remove channels rapidsai-nightly
fi

gpuci_logger "Check compiler versions"
python --version
$CC --version
$CXX --version

gpuci_logger "Check conda environment"
conda info
conda config --show-sources
conda list --show-channel-urls

# FIX Added to deal with Anancoda SSL verification issues during conda builds
conda config --set ssl_verify False

# FIXME: Remove
gpuci_mamba_retry install -c conda-forge boa

################################################################################
# BUILD - Conda package builds
################################################################################

gpuci_logger "Build conda pkg for libkvikio"
gpuci_conda_retry mambabuild --croot ${CONDA_BLD_DIR} conda/recipes/libkvikio --python=$PYTHON $CONDA_BUILD_ARGS

gpuci_logger "Build conda pkg for kvikio"
gpuci_conda_retry mambabuild --croot ${CONDA_BLD_DIR} conda/recipes/kvikio --python=$PYTHON $CONDA_BUILD_ARGS

################################################################################
# UPLOAD - Conda packages
################################################################################

gpuci_logger "Upload conda pkgs"
source ci/cpu/upload.sh
