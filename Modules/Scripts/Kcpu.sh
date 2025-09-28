####################################
# KCpu By: Koneko Dev
# Test Version
####################################

pemboy_activator () {
setprop debug.hwui.use_hint_manager true
setprop debug.sf.enable_afpf_cpu_hint true
}

pemboy_perf() {
pemboy_activator
setprop debug.hwui.target_cpu_time_percent 20
}

pemboy_balanced() {
pemboy_activator
setprop debug.hwui.target_cpu_time_percent 35
}
pemboy_powersave() {
pemboy_activator
setprop debug.hwui.target_cpu_time_percent 80
}