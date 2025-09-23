#!/system/bin/sh
#
# Telegram: @RiProG | Channel: @RiOpSo | Group: @RiOpSoDisc
# RiProG Thermal 2.6.1 (RTN 2.6.1 Low + UnSensor) - Converted to shell by Kanagawa Yamada
#
# Modified to only run if specific conditions are met in the Raco.txt config file.

# --- Configuration ---
CONFIG_FILE="/data/adb/modules/ProjectRaco/Raco.txt"

# --- Main Execution Logic ---
# Check if the config file exists and if both required settings are present.
if [ -f "$CONFIG_FILE" ] && grep -q "INCLUDE_ANYA=1" "$CONFIG_FILE" && grep -q "ANYA=1" "$CONFIG_FILE"; then

    # Function to get thermal-related properties.
    get_properties() {
        getprop | grep 'thermal' | cut -d '[' -f2 | cut -d ']' -f1 | grep -v 'hal'
    }

    # First attempt to stop services using setprop.
    get_properties | while read -r prop; do
        if [ -n "$prop" ]; then
            status=$(getprop "$prop")
            if [ "$status" = "running" ] || [ "$status" = "restarting" ]; then
                service=${prop:9}
                setprop ctl.stop "$service"
            fi
        fi
    done

    # Second attempt to stop services using the stop command as a fallback.
    get_properties | while read -r prop; do
        if [ -n "$prop" ]; then
            status=$(getprop "$prop")
            if [ "$status" = "running" ] || [ "$status" = "restarting" ]; then
                service=${prop:9}
                stop "$service"
            fi
        fi
    done

fi