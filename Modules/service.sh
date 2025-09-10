#!/system/bin/sh

# Wait for boot completion
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 10
done

# EnCorinVest Service Script
# Mali Scheduler Tweaks By: MiAzami

mali_dir=$(ls -d /sys/devices/platform/soc/*mali*/scheduling 2>/dev/null | head -n 1)
mali1_dir=$(ls -d /sys/devices/platform/soc/*mali* 2>/dev/null | head -n 1)
CONFIG_FILE="/data/adb/modules/ProjectRaco/raco.txt"

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

if grep -q "INCLUDE_ANYA=1" "$CONFIG_FILE"; then
    sh /data/adb/modules/ProjectRaco/Scripts/AnyaMelfissa.sh
fi

if grep -q "INCLUDE_KOBO=1" "$CONFIG_FILE"; then
    sh /data/adb/modules/ProjectRaco/Scripts/KoboKanaeru.sh
fi

if grep -q "INCLUDE_SANDEV=1" "$CONFIG_FILE"; then
    sh /data/adb/modules/ProjectRaco/Scripts/SandevBoot.sh
fi

su -lp 2000 -c "cmd notification post -S bigtext -t 'EnCorinVest' -i file:///data/local/tmp/logo.png -I file:///data/local/tmp/logo.png TagEncorin 'EnCorinVest - オンライン'"