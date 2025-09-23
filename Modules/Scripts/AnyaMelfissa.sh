#!/system/bin/sh
#
# Telegram: @RiProG | Channel: @RiOpSo | Group: @RiOpSoDisc
# RiProG Thermal 2.6.1 (RTN 2.6.1 Low + UnSensor) - Converted to shell by Kanagawa Yamada
#

CONFIG_FILE="/data/adb/modules/ProjectRaco/Raco.txt"

# Check if both required settings are present.
if grep -q "INCLUDE_ANYA=1" "$CONFIG_FILE" && grep -q "ANYA=1" "$CONFIG_FILE"; then

    # Function to get thermal-related service properties.
    get_properties() {
        getprop | grep 'thermal' | cut -d '[' -f2 | cut -d ']' -f1 | grep -v 'hal'
    }

    # Stop thermal services using two different methods for reliability.
    get_properties | while read -r prop; do
        if [ -n "$prop" ]; then
            service=${prop:9}
            setprop ctl.stop "$service"
            stop "$service"
        fi
    done

fi