#!/system/bin/sh

copy_with_retry() {
  local SOURCE_FILE="$1"
  local DEST_PATH="$2"
  local FILE_NAME=$(basename "$SOURCE_FILE")
  local DEST_FILE="$DEST_PATH/$FILE_NAME"

  ui_print "- Copying $FILE_NAME..."
  for i in 1 2 3 4; do
    cp -f "$SOURCE_FILE" "$DEST_PATH" >/dev/null 2>&1
    if [ -s "$DEST_FILE" ]; then
      ui_print "  ...Success."
      return 0
    fi
    if [ "$i" -lt 4 ]; then
      ui_print "  ...Failed. Retrying (Attempt $i/4)"
      sleep 1
    fi
  done

  ui_print "! CRITICAL: Failed to copy $FILE_NAME after 4 attempts."
  abort "! Aborting installation."
}

move_with_retry() {
  local SOURCE_FILE="$1"
  local DEST_FILE="$2"

  ui_print "- Moving $(basename "$SOURCE_FILE")..."
  for i in 1 2 3 4; do
    mv -f "$SOURCE_FILE" "$DEST_FILE" >/dev/null 2>&1
    if [ -s "$DEST_FILE" ] && [ ! -f "$SOURCE_FILE" ]; then
      ui_print "  ...Success."
      return 0
    fi
    if [ "$i" -lt 4 ]; then
      ui_print "  ...Failed. Retrying (Attempt $i/4)"
      sleep 1
    fi
  done

  ui_print "! CRITICAL: Failed to move $(basename "$SOURCE_FILE") after 4 attempts."
  abort "! Aborting installation."
}


LATESTARTSERVICE=true
SOC=0

ui_print "------------------------------------"
ui_print "             Project Raco           "
ui_print "------------------------------------"
ui_print "         By: Kanagawa Yamada        "
ui_print "------------------------------------"
ui_print " "
sleep 1.5

ui_print "------------------------------------"
ui_print "DO NOT COMBINE WITH ANY PERF MODULE!"
ui_print "------------------------------------"
ui_print " "
sleep 1.5

soc_recognition_extra() {
	[ -d /sys/class/kgsl/kgsl-3d0/devfreq ] && { SOC=2; return 0; }
	[ -d /sys/devices/platform/kgsl-2d0.0/kgsl ] && { SOC=2; return 0; }
	[ -d /sys/kernel/ged/hal ] && { SOC=1; return 0; }
	[ -d /sys/kernel/tegra_gpu ] && { SOC=6; return 0; }
	return 1
}

get_soc_getprop() {
	local SOC_PROP="
ro.board.platform
ro.soc.model
ro.hardware
ro.chipname
ro.hardware.chipname
ro.vendor.soc.model.external_name
ro.vendor.qti.soc_name
ro.vendor.soc.model.part_name
ro.vendor.soc.model
"
	for prop in $SOC_PROP; do
		getprop "$prop"
	done
}

recognize_soc() {
	case "$1" in
	*mt* | *MT*) SOC=1 ;;
	*sm* | *qcom* | *SM* | *QCOM* | *Qualcomm*) SOC=2 ;;
	*exynos* | *Exynos* | *EXYNOS* | *universal* | *samsung* | *erd* | *s5e*) SOC=3 ;;
	*Unisoc* | *unisoc* | *ums*) SOC=4 ;;
	*gs* | *Tensor* | *tensor*) SOC=5 ;;
	*kirin*) SOC=7 ;;
	esac
	[ $SOC -eq 0 ] && return 1
}

ui_print "------------------------------------"
ui_print "        RECOGNIZING CHIPSET         "
ui_print "------------------------------------"
soc_recognition_extra
[ $SOC -eq 0 ] && recognize_soc "$(get_soc_getprop)"
[ $SOC -eq 0 ] && recognize_soc "$(grep -E "Hardware|Processor" /proc/cpuinfo | uniq | cut -d ':' -f 2 | sed 's/^[ \t]*//')"
[ $SOC -eq 0 ] && recognize_soc "$(grep "model\sname" /proc/cpuinfo | uniq | cut -d ':' -f 2 | sed 's/^[ \t]*//')"
[ $SOC -eq 0 ] && {
  ui_print "! Unable to detect your SoC (Chipset)."
  abort "! Installation cannot continue. Aborting."
}

ui_print "------------------------------------"
ui_print "            MODULE INFO             "
ui_print "------------------------------------"
ui_print "Name : Project Raco"
ui_print "Version : CBT 5.0"
ui_print " "
sleep 1.5

ui_print "      INSTALLING Project Raco       "
ui_print " "
sleep 1.5

ui_print "- Setting up module files..."
mkdir -p /data/ProjectRaco
unzip -o "$ZIPFILE" 'Scripts/*' -d $MODPATH >&2
copy_with_retry "$MODPATH/logo.png" "/data/local/tmp"
copy_with_retry "$MODPATH/Anya.png" "/data/local/tmp"

if [ -f "/data/ProjectRaco/game.txt" ]; then
    ui_print "- Existing game.txt found, preserving user settings."
else
    ui_print "- Performing first-time setup for game.txt."
    copy_with_retry "$MODPATH/game.txt" "/data/ProjectRaco"
fi
ui_print " "

set_perm_recursive $MODPATH 0 0 0755 0755
set_perm_recursive $MODPATH/Scripts 0 0 0777 0755

sleep 1.5

choose() {
  while true; do
    /system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > "$TMPDIR/events"
    if [ -s "$TMPDIR/events" ]; then
      if grep -q "KEY_VOLUMEUP" "$TMPDIR/events"; then
        return 0
      else
        return 1
      fi
    fi
  done
}

RACO_PERSIST_CONFIG="/data/ProjectRaco/raco.txt"
RACO_MODULE_CONFIG="$MODPATH/raco.txt"

ui_print "------------------------------------"
ui_print "      OPTIONAL ADDON SELECTION      "
ui_print "------------------------------------"
ui_print "- Extracting configuration file..."
unzip -o "$ZIPFILE" 'raco.txt' -d $MODPATH >&2

USE_SAVED_CONFIG=false
if [ -f "$RACO_PERSIST_CONFIG" ]; then
  ui_print " "
  ui_print "- Saved configuration found."
  ui_print "  Do you want to use it?"
  ui_print " "
  ui_print "  Vol+ = Yes, use saved config"
  ui_print "  Vol- = No, choose again"
  ui_print " "
  if choose; then
    ui_print "- Using saved configuration."
    copy_with_retry "$RACO_PERSIST_CONFIG" "$MODPATH"
    USE_SAVED_CONFIG=true
  else
    ui_print "- Re-configuring addons."
  fi
fi

if [ "$USE_SAVED_CONFIG" = false ]; then
  ui_print " "
  ui_print "- Include Anya Thermal?"
  ui_print "Disable / Enable Thermal | Anya Flowstate"
  ui_print "  Vol+ = Yes  |  Vol- = No"
  if choose; then INCLUDE_ANYA=1; ui_print "  > Yes"; else INCLUDE_ANYA=0; ui_print "  > No"; fi

  ui_print " "
  ui_print "- Include Kobo Fast Charge?"
  ui_print "Fast Charging Add On"
  ui_print "  Vol+ = Yes  |  Vol- = No"
  if choose; then INCLUDE_KOBO=1; ui_print "  > Yes"; else INCLUDE_KOBO=0; ui_print "  > No"; fi

  ui_print " "
  ui_print "- Include Sandevistan Boot?"
  ui_print "An Attempt to Make Boot Faster"
  ui_print "  Vol+ = Yes  |  Vol- = No"
  if choose; then INCLUDE_SANDEV=1; ui_print "  > Yes"; else INCLUDE_SANDEV=0; ui_print "  > No"; fi

  ui_print " "
  ui_print "- Updating module configuration..."
  sed -i "s/^INCLUDE_ANYA=.*/INCLUDE_ANYA=$INCLUDE_ANYA/" "$RACO_MODULE_CONFIG"
  sed -i "s/^INCLUDE_KOBO=.*/INCLUDE_KOBO=$INCLUDE_KOBO/" "$RACO_MODULE_CONFIG"
  sed -i "s/^INCLUDE_SANDEV=.*/INCLUDE_SANDEV=$INCLUDE_SANDEV/" "$RACO_MODULE_CONFIG"

  ui_print " "
  ui_print "- Save these choices for future installations?"
  ui_print "  Vol+ = Yes  |  Vol- = No"
  if choose; then
    ui_print "- Saving configuration for next time."
    ui_print "  - Adding SOC Code ($SOC) to persistent config."
    sed -i "s/^SOC=.*/SOC=$SOC/" "$RACO_MODULE_CONFIG"
    copy_with_retry "$RACO_MODULE_CONFIG" "/data/ProjectRaco"
  else
    ui_print "- Choices will not be saved."
    [ -f "$RACO_PERSIST_CONFIG" ] && rm -f "$RACO_PERSIST_CONFIG"
  fi
fi

ui_print " "
ui_print "- Writing final configuration..."
if [ -f "$RACO_MODULE_CONFIG" ]; then
    ui_print "- Writing SOC Code ($SOC) to raco.txt"
    sed -i "s/^SOC=.*/SOC=$SOC/" "$RACO_MODULE_CONFIG"
else
    ui_print "! raco.txt not found, cannot write SOC value."
fi
ui_print " "
sleep 1.5

ui_print " "
ui_print "     INSTALLING Project Raco App      "
ui_print " "

if pm list packages | grep -q "com.kanagawa.yamada.project.raco"; then
    pm uninstall --user 0 com.kanagawa.yamada.project.raco >/dev/null 2>&1
fi

copy_with_retry "$MODPATH/ProjectRaco.apk" "/data/local/tmp"
pm install /data/local/tmp/ProjectRaco.apk >/dev/null 2>&1
rm /data/local/tmp/ProjectRaco.apk >/dev/null 2>&1

ui_print " "
ui_print "         INSTALLING HAMADA AI         "
ui_print " "

BIN_PATH=$MODPATH/system/bin
TARGET_BIN_NAME=HamadaAI
TARGET_BIN_PATH=$BIN_PATH/$TARGET_BIN_NAME

mkdir -p $BIN_PATH

ARCH=$(getprop ro.product.cpu.abi)
if [[ "$ARCH" == *"arm64"* ]]; then
  ui_print "- Detected 64-bit ARM architecture ($ARCH)"
  SOURCE_BIN_IN_ZIP='HamadaAI/hamadaAI_arm64'
else
  ui_print "- Detected 32-bit ARM architecture or other ($ARCH)"
  SOURCE_BIN_IN_ZIP='HamadaAI/hamadaAI_arm32'
fi

ui_print "- Extracting HamadaAI binary..."
unzip -j -o "$ZIPFILE" "$SOURCE_BIN_IN_ZIP" -d $TMPDIR >&2
EXTRACTED_FILE_NAME=$(basename "$SOURCE_BIN_IN_ZIP")
EXTRACTED_FILE_PATH="$TMPDIR/$EXTRACTED_FILE_NAME"

if [ -f "$EXTRACTED_FILE_PATH" ]; then
  move_with_retry "$EXTRACTED_FILE_PATH" "$TARGET_BIN_PATH"

  ui_print "- Setting permissions for $TARGET_BIN_NAME"
  set_perm $TARGET_BIN_PATH 0 0 0755
  chmod 755 $TARGET_BIN_PATH
else
  ui_print "! ERROR: Failed to extract binary from $SOURCE_BIN_IN_ZIP"
  abort "! Aborting installation."
fi

#############################
# Celestial Render FlowX (@Kzuyoo)
# Version 1.5G
#############################

set_perm_recursive $MODPATH/system/lib/libncurses.so 0 0 0644 0644