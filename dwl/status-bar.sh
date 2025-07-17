#!/bin/sh

# --- Configuration ---
POLL_INTERVAL=1 # seconds
TIME_UPDATE_FREQ=60 # seconds

# --- Initial Status Values ---
CURRENT_TIME=""
CURRENT_VOLUME=""
VOLUME_ICON="🔊" # Default volume icon, will change to 🔇 if muted
LAST_TIME_UPDATE=$(date +%s)

# --- Function to update volume ---
update_volume() {
    if ! command -v wpctl > /dev/null; then
        CURRENT_VOLUME="wpctl N/A"
        VOLUME_ICON="❓" # Use a different icon for missing wpctl, e.g., a question mark
        return
    fi

    VOLUME_RAW=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '/Volume:/ { printf("%s", $2) }')
    IS_MUTED=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null | awk '/Volume:/ { print $3 }')

    # Calculate percentage regardless of mute status
    local calculated_percentage="N/A"
    if [ -n "$VOLUME_RAW" ]; then
        calculated_percentage=$(printf "%.0f" "$(echo "$VOLUME_RAW * 100" | bc -l)")
    fi

    # Set the icon based on mute status
    if [ "$IS_MUTED" = "[MUTED]" ]; then
        VOLUME_ICON="🔇" # Muted icon
    else
        VOLUME_ICON="🔊" # Unmuted icon
    fi

    # Always show the percentage, even if muted
    CURRENT_VOLUME="${calculated_percentage}%"
}

# --- Function to display the bar content ---
display_bar() {
    # Added spaces around the pipe for better readability
    echo "[${VOLUME_ICON}${CURRENT_VOLUME} | ${CURRENT_TIME}]"
}

# --- Main Logic ---

# Perform initial updates
update_volume
CURRENT_TIME=$(date +"%R")
display_bar

# Main loop (polling-based)
while true; do
    update_volume

    CURRENT_TIMESTAMP=$(date +%s)
    if [ $((CURRENT_TIMESTAMP - LAST_TIME_UPDATE)) -ge "$TIME_UPDATE_FREQ" ]; then
        CURRENT_TIME=$(date +"%R")
        LAST_TIME_UPDATE=$CURRENT_TIMESTAMP
    fi

    display_bar
    sleep "$POLL_INTERVAL"
done
