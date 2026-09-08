#!/usr/bin/env bash

# Synoptik SystemMonitorCard - combined GPU/disk/temp sampler.
#
# Runs on a plain hybrid-graphics laptop (Intel iGPU + NVIDIA dGPU) where
# nvidia-smi only ever reports the dGPU - it has zero visibility into the
# iGPU, which is what actually decodes video in a browser on this kind of
# setup. Intel's i915 driver exposes no aggregate "busy percent" sysfs file
# (that's an amdgpu-only convention), so iGPU load is derived instead from
# each process's /proc/<pid>/fdinfo, which the kernel annotates with
# per-engine cumulative busy time (drm-engine-*, in ns) for every open DRM
# client - the same mechanism nvtop/intel_gpu_top use, and unlike
# intel_gpu_top's perf-counter path, this needs no root/perf_event_paranoid
# access since it's just a regular proc read of your own processes.
#
# Output, one value per line:
#   1) nvidia dGPU utilization percent (0-100)
#   2) disk used percent on /
#   3) CPU package temp, deg C (from coretemp, matched by hwmon name - not
#      "whichever hwmon happened to enumerate first", which is what the
#      previous version of this check effectively did)
#   4) nvidia dGPU temp, deg C
#   5) iGPU busy percent (0-100) - max across its render/video/
#      video-enhance/copy engines, already computed below (unlike the
#      other lines, this genuinely can't be a stateless snapshot - see why
#      below - so QML just reads it directly rather than doing its own
#      delta math on raw counters).
#
# --- why line 5 needs on-disk state -----------------------------------
# The per-engine counters are cumulative for the lifetime of each DRM
# client, not system-wide - a client that opened 1.9s ago and has been
# rendering the whole time already shows ~1.9s of accumulated busy time
# the very first time this script ever sees it. An earlier version of
# this summed one grand total across every currently-open client and
# diffed that single number against the previous poll's grand total; the
# instant any client appeared or disappeared between polls (Chrome
# opening a tab's GPU context, Quickshell's own compositor doing the
# same), that client's *entire* pre-existing accumulated time got
# misattributed to a single ~2s tick, producing false spikes that could
# read as "pegged at 99%" for one sample and correctly idle the next -
# confirmed empirically, this is exactly what was observed in practice.
# The fix is per-client delta tracking: remember each client's own last
# cumulative value, and treat a client with no prior baseline as
# contributing 0 to *this* tick (its own real delta starts showing up
# from the next tick onward, once a baseline exists) - same principle
# the CPU accounting above already gets for free from /proc/stat being a
# genuinely monotonic system-wide counter, which per-client GPU counters
# aren't.
state_file="$HOME/.cache/synoptik/gpu_intel_state.tsv"
mkdir -p "$(dirname "$state_file")"

nvidia_util=0
nvidia_temp=0
if [ -e /dev/nvidiactl ] && command -v nvidia-smi >/dev/null 2>&1; then
    read -r gpu_u dec_u <<< "$(nvidia-smi --query-gpu=utilization.gpu,utilization.decoder --format=csv,noheader,nounits 2>/dev/null | tr -d ',')"
    gpu_u=${gpu_u:-0}
    dec_u=${dec_u:-0}
    nvidia_util=$(( gpu_u > dec_u ? gpu_u : dec_u ))
    nvidia_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -n1)
    [ -z "$nvidia_temp" ] && nvidia_temp=0
fi

disk_pct=$(df / 2>/dev/null | awk 'NR==2 { gsub("%","",$5); print $5 }')
[ -z "$disk_pct" ] && disk_pct=0

cpu_temp=0
for h in /sys/class/hwmon/hwmon*; do
    if [ "$(cat "$h/name" 2>/dev/null)" = "coretemp" ]; then
        raw=$(cat "$h/temp1_input" 2>/dev/null)
        [ -n "$raw" ] && cpu_temp=$(( raw / 1000 ))
        break
    fi
done

now_ns=$(date +%s%N)

declare -A prev_val
prev_ns=0
if [ -f "$state_file" ]; then
    while IFS=$'\t' read -r key val; do
        if [ "$key" = "__ts__" ]; then
            prev_ns=$val
        else
            prev_val["$key"]=$val
        fi
    done < "$state_file"
fi

render_delta=0
video_delta=0
videoenh_delta=0
copy_delta=0

# grep -l first as a cheap pre-filter (short-circuits on the first match
# per file instead of fully parsing every process's fdinfo) before the
# real per-engine parse, which only then runs on files already confirmed
# to belong to an i915 client.
matches=$(grep -l "^drm-driver:.*i915" /proc/[0-9]*/fdinfo/* 2>/dev/null)
new_state="__ts__	$now_ns"$'\n'
if [ -n "$matches" ]; then
    declare -A seen_this_run
    while IFS= read -r f; do
        pid=$(cut -d/ -f3 <<< "$f")
        vals=$(awk '
            /^drm-client-id:/ { cid = $2 }
            /^drm-engine-render:/ { r = $2 }
            /^drm-engine-video-enhance:/ { ve = $2 }
            /^drm-engine-video:/ { v = $2 }
            /^drm-engine-copy:/ { c = $2 }
            END { print cid "|" r+0 "|" v+0 "|" ve+0 "|" c+0 }
        ' "$f" 2>/dev/null)
        [ -z "$vals" ] && continue
        cid="${vals%%|*}"
        # A process can hold more than one fd onto the same DRM client
        # (dup(), inherited across fork()) - each would report identical
        # cumulative counters, so dedupe per pid+client-id within this
        # run to avoid summing the same client's usage twice. Distinct
        # pids with distinct client-ids (e.g. Chrome's separate renderer
        # processes) are genuinely independent GPU contexts and are meant
        # to add up.
        key="$pid:$cid"
        [ -n "${seen_this_run[$key]:-}" ] && continue
        seen_this_run[$key]=1
        IFS='|' read -r _ r v ve c <<< "$vals"

        for pair in "render:$r" "video:$v" "videoenh:$ve" "copy:$c"; do
            engine="${pair%%:*}"
            cur="${pair#*:}"
            statekey="$key:$engine"
            new_state+="$statekey	$cur"$'\n'
            prior="${prev_val[$statekey]:-}"
            if [ -n "$prior" ]; then
                d=$(( cur - prior ))
                # A negative delta means the counter went backwards - the
                # client was replaced by a new one reusing the same
                # pid+client-id+engine key (possible after pid/client-id
                # wraparound) rather than genuinely rendering less than
                # zero - nothing meaningful to attribute to this tick.
                [ "$d" -lt 0 ] && d=0
                case "$engine" in
                    render) render_delta=$(( render_delta + d )) ;;
                    video) video_delta=$(( video_delta + d )) ;;
                    videoenh) videoenh_delta=$(( videoenh_delta + d )) ;;
                    copy) copy_delta=$(( copy_delta + d )) ;;
                esac
            fi
            # else: first time this exact client+engine has been seen -
            # no baseline yet, so it contributes 0 this tick by design
            # (see the header comment) rather than counting its entire
            # pre-existing accumulated time as a false spike.
        done
    done <<< "$matches"
fi

# Overwrites with only this run's keys - a client that disappeared simply
# isn't carried forward, which is correct: if the same pid+client-id ever
# reappears (only plausible after id wraparound) it should start fresh
# rather than diff against a stale, unrelated reading.
printf '%s' "$new_state" > "$state_file"

igpu_pct=0
if [ "$prev_ns" -gt 0 ]; then
    elapsed_ns=$(( now_ns - prev_ns ))
    if [ "$elapsed_ns" -gt 0 ]; then
        max_delta=$render_delta
        [ "$video_delta" -gt "$max_delta" ] && max_delta=$video_delta
        [ "$videoenh_delta" -gt "$max_delta" ] && max_delta=$videoenh_delta
        [ "$copy_delta" -gt "$max_delta" ] && max_delta=$copy_delta
        igpu_pct=$(( max_delta * 100 / elapsed_ns ))
        [ "$igpu_pct" -gt 100 ] && igpu_pct=100
        [ "$igpu_pct" -lt 0 ] && igpu_pct=0
    fi
fi
# else: first-ever run, no previous timestamp to diff against - 0 is
# correct here (not a guess), matching how every *client* with no prior
# baseline is also correctly treated as 0 this same tick above.

echo "$nvidia_util"
echo "$disk_pct"
echo "$cpu_temp"
echo "$nvidia_temp"
echo "$igpu_pct"
