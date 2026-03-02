#!/bin/bash
#SBATCH --job-name=self-build-mi210
#SBATCH --partition=main
#SBATCH --nodes=1
#SBATCH --ntasks=4
#SBATCH --cpus-per-task=8
#SBATCH --gres=gpu:mi210:4
#SBATCH --time=01:00:00
#SBATCH --container-image=docker://higherordermethods/selfish:latest-x86-rocm643-gfx90a
# --container-mounts and --container-workdir are passed at submission time:
#   sbatch --container-mounts="${BUILDKITE_BUILD_CHECKOUT_PATH}:/workspace" \
#          --container-workdir=/workspace \
#          self-build-mi210.sh

# The entire script runs inside the container.
# srun job steps use --container-inherit to run test binaries in the same container.

set -euo pipefail

# Build configuration
BUILD_TYPE="debug"
ENABLE_GPU="ON"
ENABLE_INTERFACE="OFF"
ENABLE_DOUBLE_PRECISION="ON"
ENABLE_MULTITHREADING="ON"
NTHREADS=8
GPU_ARCH="gfx90a"
GCOV="gcov"
ENABLE_TESTING="ON"
ENABLE_EXAMPLES="ON"

# --- Build ---
source /opt/spack-environment/activate.sh

mkdir -p /workspace/build
cd /workspace/build

FC=gfortran cmake \
    -DCMAKE_INSTALL_PREFIX=/workspace/opt/self \
    -DMPIEXEC_EXECUTABLE="srun" \
    -DMPIEXEC_NUMPROC_FLAG="-n" \
    -DSELF_MPIEXEC_NUMPROCS="${SLURM_NTASKS}" \
    -DSELF_MPIEXEC_OPTIONS="--container-inherit" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DSELF_ENABLE_GPU="${ENABLE_GPU}" \
    -DSELF_ENABLE_MULTITHREADING="${ENABLE_MULTITHREADING}" \
    -DSELF_MULTITHREADING_NTHREADS="${NTHREADS}" \
    -DSELF_ENABLE_DOUBLE_PRECISION="${ENABLE_DOUBLE_PRECISION}" \
    -DSELF_ENABLE_TESTING="${ENABLE_TESTING}" \
    -DCMAKE_HIP_ARCHITECTURES="${GPU_ARCH}" \
    -DSELF_ENABLE_EXAMPLES="${ENABLE_EXAMPLES}" \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DSELF_ENABLE_INTERFACE="${ENABLE_INTERFACE}" \
    /workspace/

make -j

# --- Test ---
# Serial tests run directly inside this container.
# MPI tests are launched by ctest as:
#   srun -n ${SLURM_NTASKS} --container-inherit ./test_binary
# Those srun job steps inherit this sbatch container context via --container-inherit.
ctest --test-dir /workspace/build --output-on-failure
