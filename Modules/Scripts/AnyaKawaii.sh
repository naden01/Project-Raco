#!/system/bin/sh

if grep -q "ANYA=1" /data/adb/modules/ProjectRaco/raco.txt; then
# Function to find all relevant thermal service properties.
get_properties() {
    getprop | grep 'thermal' | cut -d '[' -f2 | cut -d ']' -f1 | grep -v 'hal'
}

get_properties | while read -r prop; do
    if [[ -n "$prop" && "$prop" == init.svc.* ]]; then
        service=${prop:9}
        setprop ctl.start "$service"
    fi
done

get_properties | while read -r prop; do
    if [[ -n "$prop" && "$prop" == init.svc.* ]]; then
        service=${prop:9}
        start "$service"
    fi
done
else
    exit 0
fi
