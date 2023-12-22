#!/bin/bash

#**********************************************************************************
# Interrupt handler
#**********************************************************************************
recording_interrupt () {
    ENDED=$(lib time from "$STARTED")
    echo "Process complete in $ENDED"
    exit 0
}

STARTED=$(lib time)
trap recording_interrupt SIGINT SIGTERM

#**********************************************************************************
# Verify that the target file is being created in the correct format
# 1 - filename
#**********************************************************************************
verify_target() {
    WAV="$1"
    [ -z "$WAV" ] && printHelp

    OUTPUT="${1##*.}"
    [ "$OUTPUT" != "wav" ] && WAV+=".wav"

    [ -f "$WAV" ] && rm -f "$WAV"
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
# Format time into future from current time, get timeout and endtime
#**********************************************************************************
format_time() {
    TIME_START=$(lib time)

    if [[ "$1" =~ "m" ]] || [[ "$1" =~ "h" ]] || [[ "$1" =~ "s" ]] || [[ "$1" =~ "d" ]]; then TIMEOUT="$1"
    else TIMEOUT="${1}m"; fi

    TIMEHANDLER=${TIMEOUT%?}

    if   [[ "$TIMEOUT" =~ "m" ]]; then
        calc=$((TIMEHANDLER * 60))
        RUNTIME=$((TIME_START + calc))
    elif [[ "$TIMEOUT" =~ "h" ]]; then
        calc=$((TIMEHANDLER * 3600))
        RUNTIME=$((TIME_START + calc))
    elif [[ "$TIMEOUT" =~ "s" ]]; then
        RUNTIME=$((TIME_START + TIMEHANDLER))
    elif [[ "$TIMEOUT" =~ "d" ]]; then
        calc=$((TIMEHANDLER * 86400))
        RUNTIME=$((TIME_START + calc))
    fi
    echo "start:$TIME_START -> handler:$TIMEHANDLER | calc:$calc, RUN:$RUNTIME"

    TIME_END=$(lib time zone $RUNTIME)
}

#**********************************************************************************
# Record it raw, and convert to a wav
# 1 - Possible timeout value for recording
#**********************************************************************************
record_audio_stream() {
    echo "Recording to $WAV ... from $MONITOR"

    if [ -z "$1" ]; then
        echo "Close this window to stop (with ctrl+c) recording"
        arecord -f cd |tee "$WAV" >/dev/null 2>&1
    else
        format_time "$1"

        echo "This process will terminate in $TIMEOUT. Started at $(date +%T). Stopping at $TIME_END"
        timeout -v "$TIMEOUT" arecord -f cd |tee "$WAV" >/dev/null 2>&1
        recording_interrupt
    fi
}

#**********************************************************************************
# Verify necessary external programs
#**********************************************************************************
verify_dependencies() {
    error_code=0
    hash pactl || error_code=$?
    hash awk || error_code=$?
    hash arecord || error_code=$?
    hash tee || error_code=$?

    if [ $error_code -ne 0 ]; then
        echo "Missing one (or more) necessary dependencies: pactl, awk, arecord, tee"
        exit 1
    fi
}

#**********************************************************************************
# Help printing
#**********************************************************************************
printHelp() {
    echo "System audio output recorder"
    echo "first parameter: name of the target wav file"
    echo "second parameter (optional): time to run 'VALUE's/m/h/d (secs/mins/hours/days) [default:m]"
    exit 1
}

#**********************************************************************************
# Main function
# 1 - filename
# 2 - timeout value (VALUEs/m/h/d)
#**********************************************************************************

[ -z "$1" ] && printHelp
[ "$1" == "-h" ] && printHelp

verify_dependencies
verify_target "$1"
get_sink_monitor
record_audio_stream "$2"
recording_interrupt
