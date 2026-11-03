#!/usr/bin/env bash

# sound.sh
# Sets the starting volume of notification sounds.

notification_volume_line() {
    printf '%s={"channelVolumes":[%s, %s], "channelMap":["FL", "FR"], "mute":false, "volume":1.000000}\n' \
        "$NOTIFICATION_VOLUME_KEY" "$NOTIFICATION_VOLUME" "$NOTIFICATION_VOLUME"
}

# A volume already saved is the user's choice, so it stays.
install_notification_volume() {
    local line

    if grep -qF "$NOTIFICATION_VOLUME_KEY=" "$WIREPLUMBER_STREAMS_FILE" 2>/dev/null; then
        printf 'Kept the saved notification volume\n'
        return 0
    fi

    line="$(notification_volume_line)"
    install -d -m700 "$(dirname "$WIREPLUMBER_STREAMS_FILE")"
    if grep -qxF '[stream-properties]' "$WIREPLUMBER_STREAMS_FILE" 2>/dev/null; then
        sed -i "/^\[stream-properties\]\$/a $line" "$WIREPLUMBER_STREAMS_FILE"
    else
        printf '[stream-properties]\n%s\n' "$line" >>"$WIREPLUMBER_STREAMS_FILE"
    fi
    printf 'Set the notification volume\n'
}
