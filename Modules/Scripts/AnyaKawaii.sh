#!/system/bin/sh
# AnyaKawaii.sh - Simplified to run if ANYA=1 is NOT set.

if grep -q "ANYA=1" /data/adb/modules/ProjectRaco/Raco.txt; then
    exit 0
fi

# Function to find all relevant thermal service properties.
get_properties() {
    getprop | grep 'thermal' | cut -d '[' -f2 | cut -d ']' -f1 | grep -v 'hal'
}

# Start the thermal-related services using two methods for reliability.
get_properties | while read -r prop; do
    if [[ -n "$prop" && "$prop" == init.svc.* ]]; then
        service=${prop:9}
        setprop ctl.start "$service"
        start "$service"
    fi
done