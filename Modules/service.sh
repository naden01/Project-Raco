#!/system/bin/sh

# Wait for boot completion
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 10
done

CONFIG_FILE="/data/adb/modules/ProjectRaco/raco.txt"

# Define the function to change the CPU governor.
# It will only be called if INCLUDE_SANDEV is set to 1.
change_cpu_gov() {
  chmod 644 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
  echo "$1" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
  chmod 444 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
}

# Set CPU governor to performance only if INCLUDE_SANDEV=1
if grep -q "INCLUDE_SANDEV=1" "$CONFIG_FILE"; then
    change_cpu_gov performance
fi

# Mali Scheduler Tweaks By: MiAzami
mali_dir=$(ls -d /sys/devices/platform/soc/*mali*/scheduling 2>/dev/null | head -n 1)
mali1_dir=$(ls -d /sys/devices/platform/soc/*mali* 2>/dev/null | head -n 1)

tweak() {
    if [ -e "$1" ]; then
        echo "$2" > "$1"
    fi
}

if [ -n "$mali_dir" ]; then
    tweak "$mali_dir/serialize_jobs" "full"
fi

if [ -n "$mali1_dir" ]; then
    tweak "$mali1_dir/js_ctx_scheduling_mode" "1"
fi

tweak 0 /proc/sys/kernel/panic
tweak 0 /proc/sys/kernel/panic_on_oops
tweak 0 /proc/sys/kernel/panic_on_warn
tweak 0 /proc/sys/kernel/softlockup_panic

# Run AnyaMelfissa.sh only if both INCLUDE_ANYA and ANYA are set to 1
if grep -q "INCLUDE_ANYA=1" "$CONFIG_FILE" && grep -q "ANYA=1" "$CONFIG_FILE"; then
    sh /data/adb/modules/ProjectRaco/Scripts/AnyaMelfissa.sh
    su -lp 2000 -c "cmd notification post -S bigtext -t 'Anya Melfissa' -i file:///data/local/tmp/Anya.png -I file:///data/local/tmp/Anya.png TagAnya 'Good Day! Thermal Is Dead BTW'"
fi

# Run KoboKanaeru.sh if INCLUDE_KOBO=1
if grep -q "INCLUDE_KOBO=1" "$CONFIG_FILE"; then
    sh /data/adb/modules/ProjectRaco/Scripts/KoboKanaeru.sh
fi

# Run Zeta.sh if INCLUDE_ZETA=1
if grep -q "INCLUDE_ZETA=1" "$CONFIG_FILE"; then
    sh /data/adb/modules/ProjectRaco/Scripts/Zeta.sh
fi

###################################
# Carlotta Render (@Koneko_Dev)
# Version 2.0 
# Note: The purpose is different from Celestial Render
# This tweak surface flinger
###################################
get_stable_refresh_rate() {
    i=0
    while [ $i -lt 5 ]; do
        period=$(dumpsys SurfaceFlinger --latency 2>/dev/null | head -n1 | awk 'NR==1 {print $1}')
        case $period in
            ''|*[!0-9]*)
                ;;
            *)
                if [ "$period" -gt 0 ]; then
                    rate=$(((1000000000 + (period / 2)) / period))
                    if [ "$rate" -ge 30 ] && [ "$rate" -le 240 ]; then
                        samples="$samples $rate"
                    fi
                fi
                ;;
        esac
        i=$((i + 1))
        sleep 0.05
    done

    if [ -z "$samples" ]; then
        echo 60
        return
    fi

    sorted=$(echo "$samples" | tr ' ' '\n' | sort -n)
    count=$(echo "$sorted" | wc -l)
    mid=$((count / 2))

    if [ $((count % 2)) -eq 1 ]; then
        median=$(echo "$sorted" | sed -n "$((mid + 1))p")
    else
        val1=$(echo "$sorted" | sed -n "$mid p")
        val2=$(echo "$sorted" | sed -n "$((mid + 1))p")
        median=$(( (val1 + val2) / 2 ))
    fi

    echo "$median"
}
refresh_rate=$(get_stable_refresh_rate)
echo "Detected stable refresh rate: ${refresh_rate}Hz"

frame_duration_ns=$(awk -v r="$refresh_rate" 'BEGIN { printf "%.0f", 1000000000 / r }')
echo "Frame duration: ${frame_duration_ns}ns"

calculate_dynamic_margin() {
    base_margin=0.07
    cpu_load=$(top -n 1 -b 2>/dev/null | grep "Cpu(s)" | awk '{print $2 + $4}')
    margin=$base_margin
    awk -v load="$cpu_load" -v base="$base_margin" 'BEGIN {
        if (load > 70) {
            print base + 0.01
        } else {
            print base
        }
    }'
}

margin_ratio=$(calculate_dynamic_margin)
min_margin=$(awk -v fd="$frame_duration_ns" -v m="$margin_ratio" 'BEGIN { printf "%.0f", fd * m }')
echo "Dynamic margin: $(awk -v m="$margin_ratio" 'BEGIN { printf "%.2f", m*100 }')% (${min_margin}ns)"

if [ "$refresh_rate" -ge 120 ]; then
    app_phase_ratio=0.68
    sf_phase_ratio=0.85
    app_duration_ratio=0.58
    sf_duration_ratio=0.32
elif [ "$refresh_rate" -ge 90 ]; then
    app_phase_ratio=0.66
    sf_phase_ratio=0.82
    app_duration_ratio=0.60
    sf_duration_ratio=0.30
elif [ "$refresh_rate" -ge 75 ]; then
    app_phase_ratio=0.64
    sf_phase_ratio=0.80
    app_duration_ratio=0.62
    sf_duration_ratio=0.28
else
    app_phase_ratio=0.62
    sf_phase_ratio=0.75
    app_duration_ratio=0.65
    sf_duration_ratio=0.25
fi

app_phase_offset_ns=$(awk -v fd="$frame_duration_ns" -v r="$app_phase_ratio" 'BEGIN { printf "%.0f", -fd * r }')
sf_phase_offset_ns=$(awk -v fd="$frame_duration_ns" -v r="$sf_phase_ratio" 'BEGIN { printf "%.0f", -fd * r }')

app_duration=$(awk -v fd="$frame_duration_ns" -v r="$app_duration_ratio" 'BEGIN { printf "%.0f", fd * r }')
sf_duration=$(awk -v fd="$frame_duration_ns" -v r="$sf_duration_ratio" 'BEGIN { printf "%.0f", fd * r }')

app_end_time=$(awk -v offset="$app_phase_offset_ns" -v dur="$app_duration" 'BEGIN { print offset + dur }')
dead_time=$(awk -v app_end="$app_end_time" -v sf_offset="$sf_phase_offset_ns" 'BEGIN { print -(app_end + sf_offset) }')

adjust_needed=$(awk -v dt="$dead_time" -v mm="$min_margin" 'BEGIN { print (dt < mm) ? 1 : 0 }')
if [ "$adjust_needed" -eq 1 ]; then
    adjustment=$(awk -v mm="$min_margin" -v dt="$dead_time" 'BEGIN { print mm - dt }')
    new_app_duration=$(awk -v app_dur="$app_duration" -v adj="$adjustment" 'BEGIN { res = app_dur - adj; print (res > 0) ? res : 0 }')
    echo "Optimization: Adjusted app duration by -${adjustment}ns for dynamic margin"
    app_duration=$new_app_duration
fi

min_phase_duration=$(awk -v fd="$frame_duration_ns" 'BEGIN { printf "%.0f", fd * 0.12 }')

app_too_short=$(awk -v dur="$app_duration" -v min="$min_phase_duration" 'BEGIN { print (dur < min) ? 1 : 0 }')
if [ "$app_too_short" -eq 1 ]; then
    app_duration=$min_phase_duration
fi

sf_too_short=$(awk -v dur="$sf_duration" -v min="$min_phase_duration" 'BEGIN { print (dur < min) ? 1 : 0 }')
if [ "$sf_too_short" -eq 1 ]; then
    sf_duration=$min_phase_duration
fi

total_usage=$(awk -v app_dur="$app_duration" -v sf_dur="$sf_duration" -v fd="$frame_duration_ns" 'BEGIN { printf "%.2f", (app_dur + sf_dur) * 100 / fd }')
pipeline_efficiency=$(awk -v app_off="$app_phase_offset_ns" -v sf_off="$sf_phase_offset_ns" -v fd="$frame_duration_ns" 'BEGIN { printf "%.2f", (1 - ((app_off + sf_off) / fd)) * 100 }')

echo "=== ℂ𝔸ℝ𝕃𝕆𝕋𝕋𝔸-ℝ𝔼ℕ𝔻𝔼ℝ-𝕋𝕎𝔸𝕂𝕊 ==="
echo "Refresh Rate: ${refresh_rate}Hz"
echo "Frame Duration: ${frame_duration_ns}ns"
echo "App Phase: ${app_duration}ns ($(awk -v dur="$app_duration" -v fd="$frame_duration_ns" 'BEGIN { printf "%.2f", dur * 100 / fd }')%) offset: ${app_phase_offset_ns}ns"
echo "SF Phase:  ${sf_duration}ns ($(awk -v dur="$sf_duration" -v fd="$frame_duration_ns" 'BEGIN { printf "%.2f", dur * 100 / fd }')%) offset: ${sf_phase_offset_ns}ns"
echo "Pipeline Efficiency: ${pipeline_efficiency}%"
echo "Total Usage: ${total_usage}%"
echo "Dead Time (System Margin): $(awk -v usage="$total_usage" 'BEGIN { printf "%.2f", 100 - usage }')%"

echo ""
echo "Applying optimized settings..."

setprop debug.sf.early.app.duration "$app_duration"
setprop debug.sf.earlyGl.app.duration "$app_duration"
setprop debug.sf.late.app.duration "$app_duration"

setprop debug.sf.early.sf.duration "$sf_duration"
setprop debug.sf.earlyGl.sf.duration "$sf_duration"
setprop debug.sf.late.sf.duration "$sf_duration"

setprop debug.sf.early_app_phase_offset_ns "$app_phase_offset_ns"
setprop debug.sf.high_fps_early_app_phase_offset_ns "$app_phase_offset_ns"
setprop debug.sf.high_fps_late_app_phase_offset_ns "$app_phase_offset_ns"
setprop debug.sf.early_phase_offset_ns "$sf_phase_offset_ns"
setprop debug.sf.high_fps_early_phase_offset_ns "$sf_phase_offset_ns"
setprop debug.sf.high_fps_late_sf_phase_offset_ns "$sf_phase_offset_ns"
if [ "$refresh_rate" -ge 120 ]; then
    threshold_ratio=0.28
elif [ "$refresh_rate" -ge 90 ]; then
    threshold_ratio=0.32
elif [ "$refresh_rate" -ge 75 ]; then
    threshold_ratio=0.35
else
    threshold_ratio=0.38
fi

phase_offset_threshold_ns=$(awk -v fd="$frame_duration_ns" -v tr="$threshold_ratio" 'BEGIN { printf "%.0f", fd * tr }')

max_threshold=$(awk -v fd="$frame_duration_ns" 'BEGIN { printf "%.0f", fd * 0.45 }')
min_threshold=$(awk -v fd="$frame_duration_ns" 'BEGIN { printf "%.0f", fd * 0.22 }')

phase_offset_threshold_ns=$(awk -v val="$phase_offset_threshold_ns" -v max="$max_threshold" -v min="$min_threshold" '
BEGIN {
    if (val > max) {
        print max
    } else if (val < min) {
        print min
    } else {
        print val
    }
}')

percent=$(awk -v val="$phase_offset_threshold_ns" -v fd="$frame_duration_ns" 'BEGIN { printf "%.2f", val * 100 / fd }')
echo "=== ℂ𝔸ℝ𝕃𝕆𝕋𝕋𝔸-ℝ𝔼ℕ𝔻𝔼ℝ-𝕋𝕎𝔼𝔸𝕂 ==="
echo "Refresh Rate: ${refresh_rate}Hz"
echo "Frame Duration: ${frame_duration_ns}ns"
echo "Phase Offset Threshold: ${phase_offset_threshold_ns}ns (${percent}%)"
echo "Threshold Range: ${min_threshold}ns (22%) - ${max_threshold}ns (45%)"

setprop debug.sf.phase_offset_threshold_for_next_vsync_ns "$phase_offset_threshold_ns"
echo "System property debug.sf.phase_offset_threshold_for_next_vsync_ns set to $phase_offset_threshold_ns"

setprop debug.sf.enable_advanced_sf_phase_offset 1
setprop debug.sf.predict_hwc_composition_strategy 1
setprop debug.sf.use_phase_offsets_as_durations 1
setprop debug.sf.disable_hwc_vds 1
setprop debug.sf.show_refresh_rate_overlay_spinner 0
setprop debug.sf.show_refresh_rate_overlay_render_rate 0
setprop debug.sf.show_refresh_rate_overlay_in_middle 0
setprop debug.sf.kernel_idle_timer_update_overlay 0
setprop debug.sf.dump.enable 0
setprop debug.sf.dump.external 0
setprop debug.sf.dump.primary 0
setprop debug.sf.treat_170m_as_sRGB 0
setprop debug.sf.luma_sampling 0
setprop debug.sf.showupdates 0
setprop debug.sf.disable_client_composition_cache 0
setprop debug.sf.treble_testing_override false
setprop debug.sf.enable_layer_caching false
setprop debug.sf.enable_cached_set_render_scheduling true
setprop debug.sf.layer_history_trace false
setprop debug.sf.edge_extension_shader false
setprop debug.sf.enable_egl_image_tracker false
setprop debug.sf.use_phase_offsets_as_durations false
setprop debug.sf.layer_caching_highlight false
setprop debug.sf.enable_hwc_vds false
setprop debug.sf.vsp_trace false
setprop debug.sf.enable_transaction_tracing false
setprop debug.hwui.filter_test_overhead false
setprop debug.hwui.show_layers_updates false
setprop debug.hwui.capture_skp_enabled false
setprop debug.hwui.trace_gpu_resources false
setprop debug.hwui.skia_tracing_enabled false
setprop debug.hwui.nv_profiling false
setprop debug.hwui.skia_use_perfetto_track_events false
setprop debug.hwui.show_dirty_regions false
setprop debug.hwui.profile false
setprop debug.hwui.overdraw false
setprop debug.hwui.show_non_rect_clip hide
setprop debug.hwui.webview_overlays_enabled false
setprop debug.hwui.skip_empty_damage true
setprop debug.hwui.use_gpu_pixel_buffers true
setprop debug.hwui.use_buffer_age true
setprop debug.hwui.use_partial_updates true
setprop debug.hwui.skip_eglmanager_telemetry true
setprop debug.hwui.level 0
echo ""
echo "=== VERIFYING APPLIED SETTINGS ==="

properties_to_check=(
    "debug.sf.early.app.duration"
    "debug.sf.early.sf.duration"
    "debug.sf.earlyGl.app.duration"
    "debug.sf.earlyGl.sf.duration"
    "debug.sf.late.app.duration"
    "debug.sf.late.sf.duration"
    "debug.sf.early_app_phase_offset_ns"
    "debug.sf.high_fps_early_app_phase_offset_ns"
    "debug.sf.high_fps_late_app_phase_offset_ns"
    "debug.sf.early_phase_offset_ns"
    "debug.sf.high_fps_early_phase_offset_ns"
    "debug.sf.high_fps_late_sf_phase_offset_ns"
    "debug.sf.phase_offset_threshold_for_next_vsync_ns"
    "debug.sf.enable_advanced_sf_phase_offset"

)

all_success=true
for prop in "${properties_to_check[@]}"; do
    value=$(getprop "$prop")
    if [ -n "$value" ]; then
        echo "✓ $prop = $value"
    else
        echo "✗ $prop = NOT SET"
        all_success=false
    fi
done


echo ""
if $all_success; then
    echo "ALL SETTINGS SUCCESSFULLY APPLIED!"
    echo "Carlotta-Render-Tweak optimization active for ${refresh_rate}Hz"
else
    echo "Some settings failed to apply"
    echo "Maybe the device doesn't support all debug.sf properties"
fi 
echo ""


#####################################
# End of Carlotta Render
#####################################

###################################
# Celestial Render FlowX (@Kzuyoo)
# Version: 1.5G 
# Note: Notification Disabled
# Purpose of this is the Render (GPU, etc)
###################################

# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
MODDIR=${0%/*}

# ----------------- VARIABLES -----------------
ps_ret="$(ps -Ao pid,args)"
GED_PATH="/sys/module/ged/parameters"
GED_PATH2="/sys/kernel/debug/ged/hal"
GPUF_PATH="/proc/gpufreq"
GPUF_PATHV2="/proc/gpufreqv2"
PVR_PATH="/sys/module/pvrsrvkm/parameters"
PVR_PATH2="/sys/kernel/debug/pvr/apphint"
ADRENO_PATH="/sys/class/kgsl/kgsl-3d0"
ADRENO_PATH2="/sys/kernel/debug/kgsl/kgsl-3d0/profiling"
ADRENO_PATH3="/sys/module/adreno_idler/parameters"
KERNEL_FPSGO_PATH="/sys/kernel/debug/fpsgo/common"
MALI_PATH="/proc/mali"
PLATFORM_GPU_PATH="/sys/devices/platform/gpu"
GPUFREQ_TRACING_PATH="/sys/kernel/debug/tracing/events/mtk_events"
FPS=$(dumpsys display | grep -oE 'fps=[0-9]+' | grep -oE '[0-9]+' | sort -nr | head -n 1)

# ----------------- HELPER FUNCTIONS -----------------
log() {
    echo "$1"
}

wait_until_boot_completed() {
    while [ "$(getprop sys.boot_completed)" != "1" ]; do sleep 3; done
    while [ "$(dumpsys window policy | grep mInputRestricted=true)" != "" ]; do sleep 0.1; done
    while [ ! -d "/sdcard/Android" ]; do sleep 1; done
}

mask_val() {
    touch /data/local/tmp/mount_mask
    for p in $2; do
      if [ -f "$p" ]; then
         umount "$p"
         chmod 644 "$p"
         echo "$1" >"$p"
         mount --bind /data/local/tmp/mount_mask "$p"
      fi
    done
}

write_val() {
    local file="$1"
    local value="$2"
    if [ -e "$file" ]; then
        chmod +w "$file" 2>/dev/null
        echo "$value" > "$file" && log "Write : $file → $value" || log "Failed to Write : $file"
    fi
}

change_task_cgroup() {
    # $1:task_name $2:cgroup_name $3:"cpuset"/"stune"
    local comm
    for temp_pid in $(echo "$ps_ret" | grep -i -E "$1" | grep -v "PID" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            comm="$(cat /proc/$temp_pid/task/$temp_tid/comm)"
            echo "$temp_tid" >"/dev/$3/$2/tasks"
        done
    done
}

change_task_nice() {
    # $1:task_name $2:nice(relative to 120)
    for temp_pid in $(echo "$ps_ret" | grep -i -E "$1" | grep -v "PID" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            renice -n +40 -p "$temp_tid"
            renice -n -19 -p "$temp_tid"
            renice -n "$2" -p "$temp_tid"
        done
    done
}

# ----------------- OPTIMIZATION SECTIONS -----------------
optimize_gpu_temperature() {
    # Adjust GPU and DDR temperature thresholds ( @Bias_khaliq )
    for THERMAL in /sys/class/thermal/thermal_zone*/type; do
        if grep -E "gpu|ddr" "$THERMAL" > /dev/null; then
          for ZONE in "${THERMAL%/*}"/trip_point_*_temp; do
            CURRENT_TEMP=$(cat "$ZONE")
            if [ "$CURRENT_TEMP" -lt "90000" ]; then
              write_val "$ZONE" "95000"
            fi
          done
        fi
    done
        
        # Disable Temperature for Adreno
        for all_thermal in $(find /sys/devices/soc/*/kgsl/kgsl-3d0/ -name *temp*); do
            chmod 000 $all_thermal
        done
}

additional_gpu_settings() {
    # Optimize GPU parameters via GED driver
    if [ -d "$GED_PATH" ]; then
        write_val "$GED_PATH/gpu_cust_boost_freq" "2000000"
        write_val "$GED_PATH/gpu_cust_upbound_freq" "2000000"
        write_val "$GED_PATH/ged_smart_boost" "1000"
        write_val "$GED_PATH/gpu_bottom_freq" "800000"
        write_val "$GED_PATH/boost_upper_bound" "100"
        write_val "$GED_PATH/gx_dfps" "$FPS"
        write_val "$GED_PATH/g_gpu_timer_based_emu" "1"
        write_val "$GED_PATH/boost_gpu_enable" "1"
        write_val "$GED_PATH/ged_boost_enable" "1"
        write_val "$GED_PATH/enable_gpu_boost" "1"
        write_val "$GED_PATH/gx_game_mode" "1"
        write_val "$GED_PATH/gx_boost_on" "1"
        write_val "$GED_PATH/boost_amp" "1"
        write_val "$GED_PATH/gx_3D_benchmark_on" "1"
        write_val "$GED_PATH/is_GED_KPI_enabled" "1"
        write_val "$GED_PATH/gpu_dvfs_enable" "1"
        write_val "$GED_PATH/ged_monitor_3D_fence_disable" "0"
        write_val "$GED_PATH/ged_monitor_3D_fence_debug" "0"
        write_val "$GED_PATH/ged_log_perf_trace_enable" "0"
        write_val "$GED_PATH/ged_log_trace_enable" "0"
        write_val "$GED_PATH/gpu_bw_err_debug" "0"
        write_val "$GED_PATH/gx_frc_mode" "0"
        write_val "$GED_PATH/gpu_idle" "0"
        write_val "$GED_PATH/gpu_debug_enable" "0"
    else
        echo "Unknown $GED_PATH path. Skipping optimization."
    fi
    
    # Additional kernel-ged GPU optimizations
    if [ -d "$GED_PATH2" ]; then
         write_val "$GED_PATH2/gpu_boost_level" "2"
         # source https://cpu52.com/archives/314.html
         write_val "$GED_PATH2/custom_upbound_gpu_freq" "1"
    else
        echo "Unknown $GED_PATH2 path. Skipping optimization."
    fi
    
    # Additional GPU settings for MediaTek ( @Bias_khaliq )
    if [ -d "$PLATFORM_GPU_PATH" ]; then
         write_val "$PLATFORM_GPU_PATH/dvfs_enable" "1"
         write_val "$PLATFORM_GPU_PATH/gpu_busy" "1"
    else
        echo "Unknown $GED_PATH2 path. Skipping optimization."
    fi
}

optimize_gpu_frequency() {
    # Optimize GPU frequency configurations
    gpu_freq="$(cat $GPUF_PATH/gpufreq_opp_dump | grep -o 'freq = [0-9]*' | sed 's/freq = //' | sort -nr | head -n 1)"
        write_val "$GPUF_PATH/gpufreq_opp_freq" "$gpu_freq"
    if [ -d "$GPUF_PATH" ]; then
        for i in $(seq 0 8); do
            write_val "$GPUF_PATH/limit_table" "$i 0 0"
        done
        write_val "$GPUF_PATH/limit_table" "1 1 1"
        write_val "$GPUF_PATH/gpufreq_limited_thermal_ignore" "1"
        write_val "$GPUF_PATH/gpufreq_limited_oc_ignore" "1"
        write_val "$GPUF_PATH/gpufreq_limited_low_batt_volume_ignore" "1"
        write_val "$GPUF_PATH/gpufreq_limited_low_batt_volt_ignore" "1"
        write_val "$GPUF_PATH/gpufreq_fixed_freq_volt" "0"
        write_val "$GPUF_PATH/gpufreq_opp_stress_test" "0"
        write_val "$GPUF_PATH/gpufreq_power_dump" "0"
        write_val "$GPUF_PATH/gpufreq_power_limited" "0"
    else
        echo "Unknown $GPUF_PATH path. Skipping optimization."
    fi

    # Optimize GPU frequency v2 configurations (Matt Yang)（吟惋兮改)
    gpu_freq="$(cat $GPUF_PATHV2/gpu_working_opp_table | awk '{print $3}' | sed 's/,//g' | sort -nr | head -n 1)"
	gpu_volt="$(cat $GPUF_PATHV2/gpu_working_opp_table | awk -v freq="$freq" '$0 ~ freq {gsub(/.*, volt: /, ""); gsub(/,.*/, ""); print}')"
	write_val "$GPUF_PATHV2/fix_custom_freq_volt" "${gpu_freq} ${gpu_volt}"
    if [ -d "$GPUF_PATHV2" ]; then
        for i in $(seq 0 10); do
            lock_val "$i 0 0" /proc/gpufreqv2/limit_table
        done
        # Enable only levels 1–3
        for i in 1 3; do
            write_val "$GPUF_PATHV2/limit_table" "$i 1 1"
        done
        write_val "$GPUF_PATHV2/aging_mode" "disable"
    else
        echo "Unknown $GPUF_PATHV2 path. Skipping optimization."
    fi
}

optimize_pvr_settings() {
    # Adjust PowerVR settings for performance
    if [ -d "$PVR_PATH" ]; then
        write_val "$PVR_PATH/gpu_power" "2"
        write_val "$PVR_PATH/HTBufferSizeInKB" "512"
        write_val "$PVR_PATH/DisableClockGating" "1"
        write_val "$PVR_PATH/EmuMaxFreq" "2"
        write_val "$PVR_PATH/EnableFWContextSwitch" "1"
        write_val "$PVR_PATH/gPVRDebugLevel" "0"
        write_val "$PVR_PATH/gpu_dvfs_enable" "1"
    else
        echo "Unknown $PVR_PATH path. Skipping optimization."
    fi

    # Additional settings power vr apphint
    if [ -d "$PVR_PATH2" ]; then
        write_val "$PVR_PATH2/CacheOpConfig" "1"
        write_val "$PVR_PATH2/CacheOpUMKMThresholdSize" "512"
        write_val "$PVR_PATH2/EnableFTraceGPU" "0"
        write_val "$PVR_PATH2/HTBOperationMode" "2"
        write_val "$PVR_PATH2/TimeCorrClock" "1"
        write_val "$PVR_PATH2/0/DisableFEDLogging" "1"
        write_val "$PVR_PATH2/0/EnableAPM" "0"
    else
        echo "Unknown $PVR_PATH2 path. Skipping optimization."
    fi
}

optimize_adreno_driver() {
    # Additional adreno settings to stabilize the gpu (Matt Yang)（吟惋兮改)
    if [ -d "$ADRENO_PATH" ]; then
        PWRLVL=$(($(cat $ADRENO_PATH/num_pwrlevels) - 1))
        mask_val "$PWRLVL" "$ADRENO_PATH/default_pwrlevel"
        mask_val "$PWRLVL" "$ADRENO_PATH/min_pwrlevel"
        mask_val "0" "$ADRENO_PATH/max_pwrlevel"
        mask_val "1" "$ADRENO_PATH/bus_split"
        mask_val "1" "$ADRENO_PATH/force_clk_on"
        mask_val "1" "$ADRENO_PATH/force_no_nap"
        mask_val "1" "$ADRENO_PATH/force_rail_on"
        mask_val "0" "$ADRENO_PATH/force_bus_on"
        mask_val "0" "$ADRENO_PATH/thermal_pwrlevel"
        mask_val "0" "$ADRENO_PATH/perfcounter"
        mask_val "0" "$ADRENO_PATH/throttling"
        mask_val "0" "$ADRENO_PATH/fsync_enable"
        mask_val "0" "$ADRENO_PATH/vsync_enable"
    else
        echo "Unknown $ADRENO_PATH path. Skipping optimization."
    fi
    
    # Adreno 610 GPU max clock speed set 1114MHz 
    # (thx to vamper865 & yash5643 from module
    # AdrenoRenderEngineTweaks)
    mask_val "1114800000" "$ADRENO_PATH/max_gpuclk"
    mask_val "1114800000" "$ADRENO_PATH/gpuclk"
    mask_val "1114" "$ADRENO_PATH/max_clock_mhz"
    mask_val "1114" "$ADRENO_PATH/gpuclk_mhz"
    
    # Disable AdrenoBoost feature on Adreno GPU
    mask_val "0" "$ADRENO_PATH/devfreq/adrenoboost"
    
    # Disable kgsl profiling
    write_val "$ADRENO_PATH2/enable" "0"
    
    # Disable adreno idler
    write_val "$ADRENO_PATH3/adreno_idler_active" "0"
}

optimize_mali_driver() {
    # Mali GPU-specific optimizations ( @Bias_khaliq )
    if [ -d "$MALI_PATH" ]; then
         write_val "$MALI_PATH/dvfs_enable" "1"
         write_val "$MALI_PATH/max_clock" "550000"
         write_val "$MALI_PATH/min_clock" "100000"
    else
        echo "Unknown $MALI_PATH path. Skipping optimization."
    fi
}

optimize_task_cgroup_nice() {
    # thx to (Matt Yang)（吟惋兮改)
    change_task_cgroup "surfaceflinger" "" "cpuset"
    change_task_cgroup "system_server" "foreground" "cpuset"
    change_task_cgroup "netd|allocator" "foreground" "cpuset"
    change_task_cgroup "hardware.media.c2|vendor.mediatek.hardware" "background" "cpuset"
    change_task_cgroup "aal_sof|kfps|dsp_send_thread|vdec_ipi_recv|mtk_drm_disp_id|disp_feature|hif_thread|main_thread|rx_thread|ged_" "background" "cpuset"
    change_task_cgroup "pp_event|crtc_" "background" "cpuset"

    # Task Optimizer By: Kazuyoo
    change_task_cgroup "media.codec|media.swcodec|mediaserver" "background" "cpuset"
    change_task_cgroup "pp_event|crtc_|kbase_event" "background" "cpuset"
    change_task_cgroup "com.tencent|tencent" "foreground" "cpuset"
    change_task_cgroup "com.garena|garena" "foreground" "cpuset"
    change_task_cgroup "com.mobile.legends" "foreground" "cpuset"
    change_task_cgroup "com.miHoYo|mihoyo" "foreground" "cpuset"
    change_task_cgroup "cameraserver" "foreground" "cpuset"
    change_task_cgroup "zygote" "foreground" "cpuset"
    
    change_task_nice "surfaceflinger" -20
    change_task_nice "system_server" -10
    change_task_nice "netd" 10
    change_task_nice "mediaserver" 5
    change_task_nice "cameraserver" -10
    change_task_nice "zygote" -5
    change_task_nice "com.tencent" -15
    change_task_nice "com.garena" -15
    change_task_nice "com.mobile.legends" -15
    change_task_nice "com.miHoYo" -15
}

final_optimize_gpu() {
    # Additional kernel-fpsgo GPU optimizations
    if [ -d "$KERNEL_FPSGO_PATH" ]; then
      if [ -f "$KERNEL_FPSGO_PATH/gpu_block_boost" ]; then
          current_val=$(cat "$KERNEL_FPSGO_PATH/gpu_block_boost" 2>/dev/null)
          # Hitung jumlah angka yang ada di dalamnya
          num_fields=$(echo "$current_val" | awk '{print NF}')
        
          if [ "$num_fields" -eq 1 ]; then
              write_val "$KERNEL_FPSGO_PATH/gpu_block_boost" "100"
          elif [ "$num_fields" -eq 3 ]; then
              write_val "$KERNEL_FPSGO_PATH/gpu_block_boost" "60 120 1"
          else
              echo "Unknown gpu_block_boost format: $current_val"
          fi
      else
          echo "gpu_block_boost node not found."
      fi
    else
        echo "Unknown $KERNEL_FPSGO_PATH path. Skipping optimization."
    fi
    
    # disable pvr tracing
    for pvrtracing in $(find /sys/kernel/debug/tracing/events/pvr_fence -name 'enable'); do
        if [ -d "/sys/kernel/debug/tracing/events/pvr_fence" ]; then
            write_val "$pvrtracing" "0"
        fi
    done
        
   # disable gpu tracing for mtk
    write_val "$GPUFREQ_TRACING_PATH/enable" "0"
   
   # Disable auto voltage scaling for mtk
    write_val "$GPU_FREQ_PATH/gpufreq_aging_enable" "0"
}

cleanup_memory() {
    # Clean up memory and cache
     write_val "/proc/sys/vm/drop_caches" "3"
     write_val "/proc/sys/vm/compact_memory" "1"
}

# ----------------- MAIN EXECUTION -----------------
main() {
    wait_until_boot_completed
    optimize_gpu_temperature
    additional_gpu_settings
    optimize_gpu_frequency
    optimize_pvr_settings
    optimize_adreno_driver
    optimize_mali_driver
    optimize_task_cgroup_nice
    final_optimize_gpu
    cleanup_memory
}

# Main Execution
sync && main

############################
# End of Celestial Render
############################

# This script will be executed in late_start service mode
su -lp 2000 -c "cmd notification post -S bigtext -t 'Project Raco' -i file:///data/local/tmp/logo.png -I file:///data/local/tmp/logo.png TagRaco 'Project Raco - オンライン'"

# Revert CPU governor to default after 20 seconds, only if INCLUDE_SANDEV=1
if grep -q "INCLUDE_SANDEV=1" "$CONFIG_FILE"; then
    sleep 10
    
    DEFAULT_CPU_GOV=$(grep '^GOV=' "$CONFIG_FILE" | cut -d'=' -f2)

    if [ -z "$DEFAULT_CPU_GOV" ]; then
        if [ -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ] && grep -q "schedhorizon" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; then
            DEFAULT_CPU_GOV="schedhorizon"
        else
            DEFAULT_CPU_GOV="schedutil"
        fi
    fi

    change_cpu_gov "$DEFAULT_CPU_GOV"
fi