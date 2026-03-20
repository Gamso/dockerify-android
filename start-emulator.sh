#!/bin/bash

# Kill any running emulator instances before starting a new one
pkill -f "/opt/android-sdk/emulator/emulator"

# Removes .lock files before emulator starts to prevent crashes
rm -rf /data/android.avd/*.lock

# Use custom ramdisk if present
if [ -f /data/android.avd/ramdisk.img ]; then
  RAMDISK="-ramdisk /data/android.avd/ramdisk.img"
fi

# Path to the AVD config
CONFIG_FILE="/data/android.avd/config.ini"

update_config() {
  local key="$1"
  local value="$2"
  if grep -q "^$key=" "$CONFIG_FILE"; then
    sed -i "s/^$key=.*/$key=$value/" "$CONFIG_FILE"
  else
    echo "$key=$value" >> "$CONFIG_FILE"
  fi
}

# Configure optional screen resolution and density directly via config.ini
if [ -f "$CONFIG_FILE" ]; then
  if [ -n "$SCREEN_RESOLUTION" ]; then
    WIDTH=${SCREEN_RESOLUTION%x*}
    HEIGHT=${SCREEN_RESOLUTION#*x}
    update_config "hw.lcd.width" "$WIDTH"
    update_config "hw.lcd.height" "$HEIGHT"
  fi
  if [ -n "$SCREEN_DENSITY" ]; then
    update_config "hw.lcd.density" "$SCREEN_DENSITY"
  fi
fi

# Configure snapshot options based on SNAPSHOT_ENABLED
SNAPSHOT_DIR="/data/android.avd/snapshots/default_boot"
if [ "${SNAPSHOT_ENABLED}" = "1" ] || [ "${SNAPSHOT_ENABLED,,}" = "true" ]; then
  if [ -d "$SNAPSHOT_DIR" ] && [ -f "$SNAPSHOT_DIR/snapshot.pb" ]; then
    echo "Snapshot found — loading for fast boot..."
    SNAPSHOT_OPTS="-snapshot default_boot -no-snapshot-save"
  else
    echo "No snapshot yet — will do a cold boot and save a snapshot..."
    SNAPSHOT_OPTS="-no-snapshot-load -snapshot default_boot"
    (
      while [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" != "1" ]; do
        sleep 5
      done
      sleep 30
      echo "Saving snapshot..."
      adb emu avd snapshot save default_boot
      echo "Snapshot saved!"
    ) &
  fi
else
  SNAPSHOT_OPTS="-no-snapshot"
fi

# Start the emulator with the appropriate ramdisk.img
/opt/android-sdk/emulator/emulator -avd android -nojni -netfast -writable-system -no-window -no-audio -no-boot-anim -skip-adb-auth -gpu swiftshader_indirect -no-metrics $SNAPSHOT_OPTS $RAMDISK -qemu -m ${RAM_SIZE:-4096}
