#!/usr/bin/env bash
# Map Pioneer/XDJ USB input channels and compare against hypothesized REC OUT pairs.
# Does NOT change the macOS default input (no SwitchAudioSource / Homebrew).
set -euo pipefail

DEVICE_NAME="${SETCATCHER_XDJ_DEVICE_NAME:-XDJ-XZ}"
DURATION="${SETCATCHER_XDJ_MAP_SECONDS:-15}"
SIGNAL_THRESHOLD_DB="${SETCATCHER_XDJ_SIGNAL_THRESHOLD_DB:--33.98}"
RUN_STAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
OUTPUT_DIR="${SETCATCHER_XDJ_MAP_OUTPUT_DIR:-/tmp/setcatcher-xdj-channel-map-$RUN_STAMP}"
CAPTURE_PATH="$OUTPUT_DIR/$DEVICE_NAME-native.wav"
REPORT_PATH="$OUTPUT_DIR/channel-levels.txt"

# Hypothesized 0-based REC OUT pair (see docs/xdj-usb-routing-2026-08-29.md).
# Override with SETCATCHER_XDJ_HYPOTHESIZED_LEFT / _RIGHT when probing another layout.
hypothesized_pair_for_device() {
    local name_lc
    name_lc="$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')"
    case "$name_lc" in
        *xdj-xz*|*xdj\ xz*) echo "4 5" ;; # measured Core Audio 2026-08-29: channels 5/6
        *xdj-rx3*|*xdj\ rx3*) echo "4 5" ;;
        *xdj-rx2*|*xdj\ rx2*) echo "2 3" ;;
        *djm-v10*|*djm\ v10*) echo "10 11" ;;
        *djm-a9*|*djm\ a9*) echo "8 9" ;;
        *djm-900*|*djm\ 900*) echo "8 9" ;;
        *) echo "" ;;
    esac
}

if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "ffmpeg is required for the XDJ channel-map bench." >&2
    exit 2
fi
if ! command -v ffprobe >/dev/null 2>&1; then
    echo "ffprobe is required for the XDJ channel-map bench." >&2
    exit 2
fi

mkdir -p "$OUTPUT_DIR"

DEVICE_LIST="$(ffmpeg -hide_banner -f avfoundation -list_devices true -i '' 2>&1 || true)"
DEVICE_INDEX="$(printf '%s\n' "$DEVICE_LIST" | sed -n "s/.*\\[\\([0-9][0-9]*\\)\\] $DEVICE_NAME$/\\1/p" | head -1)"
if [[ -z "$DEVICE_INDEX" ]]; then
    echo "Could not find AVFoundation audio input '$DEVICE_NAME'." >&2
    printf '%s\n' "$DEVICE_LIST" >&2
    exit 2
fi

HYP_LEFT=""
HYP_RIGHT=""
if [[ -n "${SETCATCHER_XDJ_HYPOTHESIZED_LEFT:-}" && -n "${SETCATCHER_XDJ_HYPOTHESIZED_RIGHT:-}" ]]; then
    HYP_LEFT="$SETCATCHER_XDJ_HYPOTHESIZED_LEFT"
    HYP_RIGHT="$SETCATCHER_XDJ_HYPOTHESIZED_RIGHT"
else
    read -r HYP_LEFT HYP_RIGHT <<<"$(hypothesized_pair_for_device "$DEVICE_NAME")"
fi

cat <<MSG
SetCatcher XDJ input channel map
device=$DEVICE_NAME
avfoundationIndex=$DEVICE_INDEX
durationSeconds=$DURATION
signalThresholdDB=$SIGNAL_THRESHOLD_DB
hypothesizedPair0Based=${HYP_LEFT:-none}/${HYP_RIGHT:-none}
hypothesizedPair1Based=$([ -n "${HYP_LEFT:-}" ] && echo "$((HYP_LEFT + 1))/$((HYP_RIGHT + 1))" || echo none)
capture=$CAPTURE_PATH

Play a recognizable track through the XDJ for the entire capture window.
Listen to extractions on Studio Display Speakers (not the XDJ).
MSG

ffmpeg -hide_banner -loglevel warning \
    -f avfoundation -i ":$DEVICE_INDEX" \
    -t "$DURATION" -map 0:a:0 -c:a pcm_f32le -y "$CAPTURE_PATH"

CHANNEL_COUNT="$(ffprobe -v error -select_streams a:0 -show_entries stream=channels -of csv=p=0 "$CAPTURE_PATH" | head -1)"
SAMPLE_RATE="$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$CAPTURE_PATH" | head -1)"
if [[ -z "$CHANNEL_COUNT" || "$CHANNEL_COUNT" -lt 1 ]]; then
    echo "FAIL: could not read channel count from $CAPTURE_PATH" >&2
    exit 1
fi

{
    echo "device=$DEVICE_NAME"
    echo "avfoundationIndex=$DEVICE_INDEX"
    echo "durationSeconds=$DURATION"
    echo "actualChannels=$CHANNEL_COUNT"
    echo "sampleRate=$SAMPLE_RATE"
    echo "signalThresholdDB=$SIGNAL_THRESHOLD_DB"
    echo "hypothesizedLeft0Based=${HYP_LEFT:-none}"
    echo "hypothesizedRight0Based=${HYP_RIGHT:-none}"
    echo "capture=$CAPTURE_PATH"
} > "$REPORT_PATH"

printf 'actualChannels=%s sampleRate=%s\n' "$CHANNEL_COUNT" "$SAMPLE_RATE"

HYP_IN_RANGE=0
HYP_STATUS="none"
if [[ -n "${HYP_LEFT:-}" && -n "${HYP_RIGHT:-}" ]]; then
    REQUIRED=$(( HYP_LEFT > HYP_RIGHT ? HYP_LEFT + 1 : HYP_RIGHT + 1 ))
    if (( CHANNEL_COUNT < REQUIRED )); then
        HYP_STATUS="out_of_range"
        {
            echo "hypothesizedStatus=out_of_range"
            echo "hypothesizedRequiredChannels=$REQUIRED"
        } | tee -a "$REPORT_PATH"
        echo "FAIL: hypothesized REC OUT pair $((HYP_LEFT + 1))/$((HYP_RIGHT + 1)) needs $REQUIRED channels; device exposes $CHANNEL_COUNT." >&2
        echo "Open XDJ Setting Utility / confirm USB layout, then re-run. Scanning available channels anyway." >&2
    else
        HYP_IN_RANGE=1
        HYP_STATUS="in_range"
        echo "hypothesizedStatus=in_range" | tee -a "$REPORT_PATH"
    fi
fi

active_channels=""
previous_active=""
stereo_path=""
hyp_stereo_path=""

for ((channel_index = 0; channel_index < CHANNEL_COUNT; channel_index++)); do
    stats="$(ffmpeg -hide_banner -i "$CAPTURE_PATH" \
        -af "pan=mono|c0=c$channel_index,astats=metadata=1:reset=0" \
        -f null - 2>&1 || true)"
    peak_db="$(printf '%s\n' "$stats" | awk -F': ' '/Peak level dB/ { value=$2 } END { gsub(/[[:space:]]/, "", value); print value }')"
    rms_db="$(printf '%s\n' "$stats" | awk -F': ' '/RMS level dB/ { value=$2 } END { gsub(/[[:space:]]/, "", value); print value }')"
    peak_db="${peak_db:--inf}"
    rms_db="${rms_db:--inf}"
    channel_number=$((channel_index + 1))
    printf 'channel=%d peakDB=%s rmsDB=%s\n' "$channel_number" "$peak_db" "$rms_db" | tee -a "$REPORT_PATH"

    passes="$(awk -v peak="$peak_db" -v threshold="$SIGNAL_THRESHOLD_DB" \
        'BEGIN { print (peak != "-inf" && peak + 0 >= threshold + 0) ? "yes" : "no" }')"
    if [[ "$passes" == "yes" ]]; then
        active_channels="${active_channels}${active_channels:+,}$channel_number"
        if [[ -n "$previous_active" ]] && (( channel_index == previous_active + 1 )) && [[ -z "$stereo_path" ]]; then
            left_index="$previous_active"
            right_index="$channel_index"
            left_number=$((left_index + 1))
            right_number=$((right_index + 1))
            stereo_path="$OUTPUT_DIR/$DEVICE_NAME-channels-$left_number-$right_number.wav"
            ffmpeg -hide_banner -loglevel warning -i "$CAPTURE_PATH" \
                -af "pan=stereo|c0=c$left_index|c1=c$right_index" \
                -c:a pcm_s16le -y "$stereo_path"
        fi
        previous_active="$channel_index"
    else
        previous_active=""
    fi
done

if (( HYP_IN_RANGE == 1 )); then
    hyp_stereo_path="$OUTPUT_DIR/$DEVICE_NAME-hypothesized-$((HYP_LEFT + 1))-$((HYP_RIGHT + 1)).wav"
    ffmpeg -hide_banner -loglevel warning -i "$CAPTURE_PATH" \
        -af "pan=stereo|c0=c$HYP_LEFT|c1=c$HYP_RIGHT" \
        -c:a pcm_s16le -y "$hyp_stereo_path"
    hyp_stats="$(ffmpeg -hide_banner -i "$hyp_stereo_path" \
        -af "astats=metadata=1:reset=0" -f null - 2>&1 || true)"
    hyp_peak="$(printf '%s\n' "$hyp_stats" | awk -F': ' '/Peak level dB/ { value=$2 } END { gsub(/[[:space:]]/, "", value); print value }')"
    hyp_peak="${hyp_peak:--inf}"
    printf 'hypothesizedExtraction=%s peakDB=%s\n' "$hyp_stereo_path" "$hyp_peak" | tee -a "$REPORT_PATH"
    hyp_passes="$(awk -v peak="$hyp_peak" -v threshold="$SIGNAL_THRESHOLD_DB" \
        'BEGIN { print (peak != "-inf" && peak + 0 >= threshold + 0) ? "yes" : "no" }')"
    if [[ "$hyp_passes" != "yes" ]]; then
        echo "hypothesizedSignal=below_threshold" | tee -a "$REPORT_PATH"
    else
        echo "hypothesizedSignal=above_threshold" | tee -a "$REPORT_PATH"
    fi
fi

{
    echo "activeChannels=${active_channels:-none}"
    echo "stereoExtraction=${stereo_path:-none}"
    echo "hypothesizedStatus=$HYP_STATUS"
} | tee -a "$REPORT_PATH"

echo "report=$REPORT_PATH"

if [[ -z "$active_channels" ]]; then
    echo "FAIL: no XDJ input channel reached the signal threshold." >&2
    if [[ "$HYP_STATUS" == "out_of_range" ]]; then
        echo "NOTE: hypothesized pair was also out of range for channelCount=$CHANNEL_COUNT." >&2
    fi
    exit 1
fi
if [[ -n "${hyp_stereo_path:-}" ]]; then
    hyp_passes_final="$(awk -v peak="${hyp_peak:--inf}" -v threshold="$SIGNAL_THRESHOLD_DB" \
        'BEGIN { print (peak != "-inf" && peak + 0 >= threshold + 0) ? "yes" : "no" }')"
    if [[ "$hyp_passes_final" == "yes" ]]; then
        echo "PASS: hypothesized REC OUT pair extracted to $hyp_stereo_path"
        exit 0
    fi
fi
if [[ -n "$stereo_path" ]]; then
    if [[ "$HYP_STATUS" == "out_of_range" ]]; then
        echo "NOTE: hypothesized pair out of range; using first adjacent active pair." >&2
    fi
    echo "PASS: active XDJ stereo input pair extracted to $stereo_path"
    exit 0
fi
if [[ "$HYP_STATUS" == "out_of_range" ]]; then
    echo "FAIL: hypothesized REC OUT pair exceeds device channel count ($CHANNEL_COUNT)." >&2
    exit 1
fi
if [[ -z "$stereo_path" && "$HYP_STATUS" != "in_range" ]]; then
    echo "FAIL: signal was detected, but no adjacent stereo pair reached the threshold." >&2
    exit 1
fi

echo "FAIL: no usable stereo extraction above threshold." >&2
exit 1
