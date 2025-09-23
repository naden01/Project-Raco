LATESTARTSERVICE=true
# Initialize SOC variable
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

# =============================
# SOC Recognition and Configuration
# =============================

soc_recognition_extra() {
	[ -d /sys/class/kgsl/kgsl-3d0/devfreq ] && {
		SOC=2
		return 0
	}

	[ -d /sys/devices/platform/kgsl-2d0.0/kgsl ] && {
		SOC=2
		return 0
	}

	[ -d /sys/kernel/ged/hal ] && {
		SOC=1
		return 0
	}

	[ -d /sys/kernel/tegra_gpu ] && {
		SOC=6
		return 0
	}

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
# SOC CODE:
# 1 = MediaTek
# 2 = Qualcomm Snapdragon
# 3 = Exynos
# 4 = Unisoc
# 5 = Google Tensor
# 6 = Nvidia Tegra
# 7 = Kirin

# Recognize Chipset by calling the functions defined above
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
ui_print "Version : CBT"
ui_print " "
sleep 1.5

ui_print "      INSTALLING Project Raco       "
ui_print " "
sleep 1.5

# Check if game.txt exists in the new location, skip copy operations if it does
if [ -f "/data/ProjectRaco/game.txt" ]; then
    ui_print "- game.txt found, skipping file copy operations"
    ui_print " "
else
    ui_print "- game.txt not found, proceeding with file copy"
    # Create the target directory if it doesn't exist
    mkdir -p /data/ProjectRaco
    unzip -o "$ZIPFILE" 'Scripts/*' -d $MODPATH >&2
    # Copy game.txt to the new location
    cp -r "$MODPATH"/game.txt /data/ProjectRaco/ >/dev/null 2>&1
    cp -r "$MODPATH"/logo.png /data/local/tmp >/dev/null 2>&1
    cp -r "$MODPATH"/Anya.png /data/local/tmp >/dev/null 2>&1
fi

set_perm_recursive $MODPATH 0 0 0755 0755
set_perm_recursive $MODPATH/Scripts 0 0 0777 0755

sleep 1.5

# =============================
# Addon Selection by Volume Keys
# =============================

# Function to get key presses using getevent
choose() {
  while true; do
    /system/bin/getevent -lc 1 2>&1 | /system/bin/grep VOLUME | /system/bin/grep " DOWN" > "$TMPDIR/events"
    if [ -n "$(cat "$TMPDIR/events")" ]; then
      if echo "$(cat "$TMPDIR/events")" | grep -q "KEY_VOLUMEUP"; then
        return 0 # Return 0 for Vol+ (Yes)
      else
        return 1 # Return 1 for Vol- (No)
      fi
    fi
  done
}

# Define config file paths
RACO_PERSIST_CONFIG="/data/ProjectRaco/raco.txt"
RACO_MODULE_CONFIG="$MODPATH/raco.txt"

ui_print "------------------------------------"
ui_print "      OPTIONAL ADDON SELECTION      "
ui_print "------------------------------------"

# Extract the template config file to the module path
ui_print "- Extracting configuration file..."
unzip -o "$ZIPFILE" 'raco.txt' -d $MODPATH >&2

# Initialize default values
USE_SAVED_CONFIG=false

# Check for a saved configuration
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
    cp "$RACO_PERSIST_CONFIG" "$RACO_MODULE_CONFIG"
    USE_SAVED_CONFIG=true
  else
    ui_print "- Re-configuring addons."
    USE_SAVED_CONFIG=false
  fi
else
  USE_SAVED_CONFIG=false
fi

# If not using saved config, ask the user for their choices
if [ "$USE_SAVED_CONFIG" = false ]; then

  # Prompt for Anya Thermal
  ui_print " "
  ui_print "- Include Anya Thermal?"
  ui_print " "
  ui_print "  Vol+ = Yes"
  ui_print "  Vol- = No"
  ui_print " "
  if choose; then
    INCLUDE_ANYA=1
    ui_print "  Anya Thermal will be included."
  else
    INCLUDE_ANYA=0
    ui_print "  Anya Thermal will NOT be included."
  fi

  # Prompt for Kobo Fast Charge
  ui_print " "
  ui_print "- Include Kobo Fast Charge?"
  ui_print " "
  ui_print "  Vol+ = Yes"
  ui_print "  Vol- = No"
  ui_print " "
  if choose; then
    INCLUDE_KOBO=1
    ui_print "  Kobo Fast Charge will be included."
  else
    INCLUDE_KOBO=0
    ui_print "  Kobo Fast Charge will NOT be included."
  fi

  # Prompt for Sandevistan Boot
  ui_print " "
  ui_print "- Include Sandevistan Boot?"
  ui_print " "
  ui_print "  Vol+ = Yes"
  ui_print "  Vol- = No"
  ui_print " "
  if choose; then
    INCLUDE_SANDEV=1
    ui_print "  Sandevistan Boot will be included."
  else
    INCLUDE_SANDEV=0
    ui_print "  Sandevistan Boot will NOT be included."
  fi
  
  # Update the module's config file with the new choices
  ui_print " "
  ui_print "- Updating module configuration..."
  sed -i "s/^INCLUDE_ANYA=.*/INCLUDE_ANYA=$INCLUDE_ANYA/" "$RACO_MODULE_CONFIG"
  sed -i "s/^INCLUDE_KOBO=.*/INCLUDE_KOBO=$INCLUDE_KOBO/" "$RACO_MODULE_CONFIG"
  sed -i "s/^INCLUDE_SANDEV=.*/INCLUDE_SANDEV=$INCLUDE_SANDEV/" "$RACO_MODULE_CONFIG"

  # Prompt to save choices for future installations
  ui_print " "
  ui_print "- Save these choices for future"
  ui_print "  installations?"
  ui_print " "
  ui_print "  Vol+ = Yes"
  ui_print "  Vol- = No"
  ui_print " "
  if choose; then
    ui_print "- Saving configuration for next time."
    cp "$RACO_MODULE_CONFIG" "$RACO_PERSIST_CONFIG"
  else
    ui_print "- Choices will not be saved."
    # Remove old saved config if user declines to save new choices
    [ -f "$RACO_PERSIST_CONFIG" ] && rm "$RACO_PERSIST_CONFIG"
  fi
fi

# =============================
# Final Configuration
# =============================
ui_print " "
ui_print "- Writing final configuration..."
# Write the detected SOC code to the config file
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

# Check if Project Raco App is already installed
if pm list packages | grep -q "com.kanagawa.yamada.project.raco"; then
    pm uninstall --user 0 com.kanagawa.yamada.project.raco >/dev/null 2>&1
fi

cp "$MODPATH"/ProjectRaco.apk /data/local/tmp >/dev/null 2>&1
pm install /data/local/tmp/ProjectRaco.apk >/dev/null 2>&1
rm /data/local/tmp/ProjectRaco.apk >/dev/null 2&>1

ui_print " "
ui_print "         INSTALLING HAMADA AI         "
ui_print " "

# Define paths and target binary name
BIN_PATH=$MODPATH/system/bin
TARGET_BIN_NAME=HamadaAI
TARGET_BIN_PATH=$BIN_PATH/$TARGET_BIN_NAME
TEMP_EXTRACT_DIR=$TMPDIR/hamada_extract # Use a temporary directory for extraction

# Create necessary directories
mkdir -p $BIN_PATH
mkdir -p $TEMP_EXTRACT_DIR

# Detect architecture
ARCH=$(getprop ro.product.cpu.abi)

# Determine which binary to extract based on architecture
if [[ "$ARCH" == *"arm64"* ]]; then
  # 64-bit architecture
  ui_print "- Detected 64-bit ARM architecture ($ARCH)"
  SOURCE_BIN_ZIP_PATH='HamadaAI/hamadaAI_arm64' # Path inside the zip file
  SOURCE_BIN_EXTRACTED_PATH=$TEMP_EXTRACT_DIR/HamadaAI/hamadaAI_arm64 # Path after extraction to temp dir
  ui_print "- Extracting $SOURCE_BIN_ZIP_PATH..."
  unzip -o "$ZIPFILE" "$SOURCE_BIN_ZIP_PATH" -d $TEMP_EXTRACT_DIR >&2
else
  # Assume 32-bit architecture (or non-arm64)
  ui_print "- Detected 32-bit ARM architecture or other ($ARCH)"
  SOURCE_BIN_ZIP_PATH='HamadaAI/hamadaAI_arm32' # Path inside the zip file
  SOURCE_BIN_EXTRACTED_PATH=$TEMP_EXTRACT_DIR/HamadaAI/hamadaAI_arm32 # Path after extraction to temp dir
  ui_print "- Extracting $SOURCE_BIN_ZIP_PATH..."
  unzip -o "$ZIPFILE" "$SOURCE_BIN_ZIP_PATH" -d $TEMP_EXTRACT_DIR >&2
fi

# Check if extraction was successful and the source file exists
if [ -f "$SOURCE_BIN_EXTRACTED_PATH" ]; then
  ui_print "- Moving and renaming binary to $TARGET_BIN_PATH"
  # Move the extracted binary to the final destination and rename it
  mv "$SOURCE_BIN_EXTRACTED_PATH" "$TARGET_BIN_PATH"

  # Check if the final binary exists
  if [ -f "$TARGET_BIN_PATH" ]; then
    ui_print "- Setting permissions for $TARGET_BIN_NAME"
    set_perm $TARGET_BIN_PATH 0 0 0755 0755
  else
    ui_print "! ERROR: Failed to move binary to $TARGET_BIN_PATH"
  fi
else
  ui_print "! ERROR: Failed to extract binary from $SOURCE_BIN_ZIP_PATH"
fi

# Clean up temporary extraction directory
rm -rf $TEMP_EXTRACT_DIR