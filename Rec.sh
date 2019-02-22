#!/bin/bash

#**********************************************************************************
# Verify that the target file is being created in the correct format
#**********************************************************************************
verify_target() {
    WAV="$1"
    if [ -z "$WAV" ]; then
        echo "Usage: $0 OUTPUT.WAV" >&2
        exit 1
    fi

    OUTPUT="${1##*.}"

    if [ $OUTPUT != "wav" ]; then
        WAV+=".wav"
    fi
    rm -f "$WAV"
}

#**********************************************************************************
# Get sink monitor
#**********************************************************************************
get_sink_monitor() {
    MONITOR=$(pactl list | egrep -A2 '^(\*\*\* )?Source #' | \
    grep 'Name: .*\.monitor$' | awk '{print $NF}' | tail -n1)
    echo "set-source-mute ${MONITOR} false" | pacmd >/dev/null
}

#**********************************************************************************
# Record it raw, and convert to a wav
#**********************************************************************************
record_audio_stream() {
    echo "Recording to $WAV ..."
    echo "Close this window to stop (with ctrl+c)"
    parec -d "$MONITOR" | sox -t raw -r 44100 -sLb 16 -c 2 - "$WAV"
    #parec –format=s16le –device=”$MONITOR” | oggenc –raw –quiet –quality=4 -o $WAV -
}

#**********************************************************************************
# Verify necessary external programs
#**********************************************************************************
verify_dependencies() {
    error_code=0
    hash parec || error_code=$?
    hash pactl || error_code=$?
    hash awk || error_code=$?

    if [ $error_code -ne 0 ]; then
        echo "Missing one (or more) necessary dependencies: parec, pactl, awk"
        exit 1
    fi
}

#**********************************************************************************
# Main function
#**********************************************************************************
verify_dependencies
verify_target "$1"
get_sink_monitor
record_audio_stream
