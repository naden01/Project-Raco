#!/bin/bash

# Check if SandevBoot is enabled in the config file
RACO_CONFIG="/data/adb/modules/ProjectRaco/raco.txt"
if grep -q "^INCLUDE_SANDEV=1" "$RACO_CONFIG"; then

    change_cpu_gov() {
      chmod 644 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
      echo "$1" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
      chmod 444 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    }

    change_cpu_gov performance

    sleep 30

    DEFAULT_CPU_GOV=$(grep '^GOV=' "$RACO_CONFIG" | cut -d'=' -f2)

    if [ -z "$DEFAULT_CPU_GOV" ]; then
        if [ -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ] && grep -q "schedhorizon" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; then
            DEFAULT_CPU_GOV="schedhorizon"
        else
            DEFAULT_CPU_GOV="schedutil"
        fi
    fi

    change_cpu_gov "$DEFAULT_CPU_GOV"
fi