#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future
# dark gpu rendering by Dreamy Wanderer
MODDIR=${0%/*}
dir=$MODDIR

# @Bias_khaliq
# Function to detect GPU type 
detect_gpu_type() {
    if [ -d "/sys/class/kgsl/kgsl-3d0" ]; then
        echo "adreno"
    elif [ -n "$(find /sys/devices/platform -name mali -type d)" ]; then
        echo "mali"
    elif [ -n "$(find /sys/ -name pvr* -type d)" ]; then
        echo "PowerVR"
    else
        echo "none"
    fi
}

gpu_optimize_adreno() {
    mkdir -p "$dir/system/lib/egl" "$dir/system/lib64/egl" "$dir/system/vendor/lib/egl" "$dir/system/vendor/lib64/egl"
    # Function to get GPU model
    get_gpu_model() {
        if [ -d "/sys/class/kgsl/kgsl-3d0" ]; then
            model=$(cat "/sys/class/kgsl/kgsl-3d0/gpu_model")
            echo "$model"
        fi
    }
    # Get GPU vendor and model
    gpu_model=$(get_gpu_model)
    # Write GPU info to egl.cfg files
    write_gpu_info() {
        egl_cfg_path=$1
        gpu_model=$2
        echo "0 1 $gpu_model" > "$egl_cfg_path"
    }
    write_gpu_info "$dir/system/lib/egl/egl.cfg" "$gpu_model"
    write_gpu_info "$dir/system/lib64/egl/egl.cfg" "$gpu_model"
    write_gpu_info "$dir/system/vendor/lib/egl/egl.cfg" "$gpu_model"
    write_gpu_info "$dir/system/vendor/lib64/egl/egl.cfg" "$gpu_model"
}

gpu_optimize_mali() {
    gpu_path=$(find /sys/devices/platform/*mali*/gpuinfo -type f -print | head -n 1)
    if [ ! -d "$dir/system" ] && [ -n "$gpu_path" ]; then
        mkdir -p "$dir/system/lib/egl" "$dir/system/lib64/egl" "$dir/system/vendor/lib/egl" "$dir/system/vendor/lib64/egl" &&
        gpu_id=$(awk '{print $1}' "$gpu_path")
        echo "0 1 $gpu_id" > "$dir/system/lib/egl/egl.cfg"
        echo "0 1 $gpu_id" > "$dir/system/lib64/egl/egl.cfg"
        echo "0 1 $gpu_id" > "$dir/system/vendor/lib/egl/egl.cfg"
        echo "0 1 $gpu_id" > "$dir/system/vendor/lib64/egl/egl.cfg"
    fi
}

gpu_optimize_powervr() {
    mkdir -p "$dir/system/lib/egl" "$dir/system/lib64/egl" "$dir/system/vendor/lib/egl" "$dir/system/vendor/lib64/egl"

# Get GPU vendor and model
    gpu_model=pvr

# Write GPU info to egl.cfg files
  write_gpu_info() {
    egl_cfg_path=$1
    gpu_model=$2
    echo "0 1 $gpu_model" > "$egl_cfg_path"
  }

    write_gpu_info "$dir/system/lib/egl/egl.cfg" "$gpu_model"
    write_gpu_info "$dir/system/lib64/egl/egl.cfg" "$gpu_model"
    write_gpu_info "$dir/system/vendor/lib/egl/egl.cfg" "$gpu_model"
    write_gpu_info "$dir/system/vendor/lib64/egl/egl.cfg" "$gpu_model"
}

# Detect GPU type
gpu_type=$(detect_gpu_type)

# Execute appropriate function based on GPU type 
case $gpu_type in
    "adreno")
        echo "adreno"
        gpu_optimize_adreno
        ;;
    "mali")
        echo "mali"
        gpu_optimize_mali
        ;;
    "pvr")
        echo "powervr"
        gpu_optimize_powervr
        ;;
    *)
        echo "Unknown or unsupported GPU type. Skipping optimization."
        ;;
esac

# This script will be executed in post-fs-data mode