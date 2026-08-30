#!/usr/bin/env bash
# Compares `advs ipc call` (direct socket) against `qs ipc call` on the same call.
#   ITERATIONS=50 WARMUPS=3 CALL="lock isLocked" scripts/benchmark-ipc.sh
set -euo pipefail

ITERATIONS="${ITERATIONS:-50}"
WARMUPS="${WARMUPS:-3}"
CALL="${CALL:-lock isLocked}"
ADVS_BIN="${ADVS_BIN:-advs}"
QS_BIN="${QS_BIN:-qs}"

for bin in "$ADVS_BIN" "$QS_BIN"; do
    command -v "$bin" >/dev/null 2>&1 || { echo "not found: $bin" >&2; exit 1; }
done

# shellcheck disable=SC2206
call=($CALL)
if [[ -n "${QS_ARGS:-}" ]]; then
    # shellcheck disable=SC2206
    qs_args=($QS_ARGS)
else
    repo_shell="$(cd "$(dirname "$0")/.." && pwd)/quickshell/shell.qml"
    config_path="$("$QS_BIN" list --all 2>/dev/null | awk -F': ' -v want="$repo_shell" '/Config path:/ { if ($2 == want) { print $2; found = 1; exit } if (!first) first = $2 } END { if (!found) print first }')"
    if [[ -n "$config_path" ]]; then
        qs_args=(-p "$config_path")
    else
        qs_args=(-c advs)
    fi
fi

run_advs() { "$ADVS_BIN" ipc call "${call[@]}"; }
run_qs() { "$QS_BIN" "${qs_args[@]}" ipc call "${call[@]}"; }

advs_out="$(run_advs)" || { echo "advs ipc call failed" >&2; exit 1; }
qs_out="$(run_qs)" || { echo "qs ipc call failed" >&2; exit 1; }
if [[ "$advs_out" != "$qs_out" ]]; then
    echo "outputs differ:" >&2
    echo "  advs: $advs_out" >&2
    echo "  qs:  $qs_out" >&2
    exit 1
fi

measure() {
    local fn="$1" i start end
    for ((i = 0; i < WARMUPS; i++)); do "$fn" >/dev/null; done
    for ((i = 0; i < ITERATIONS; i++)); do
        start=$(date +%s%N)
        "$fn" >/dev/null
        end=$(date +%s%N)
        echo $((end - start))
    done
}

summarize() {
    sort -n | awk '
        { v[NR] = $1; sum += $1 }
        END {
            median = (NR % 2) ? v[(NR + 1) / 2] : (v[NR / 2] + v[NR / 2 + 1]) / 2
            printf "%.2f | %.2f | %.2f", v[1] / 1e6, median / 1e6, sum / NR / 1e6
        }'
}

advs_stats="$(measure run_advs | summarize)"
qs_stats="$(measure run_qs | summarize)"

cat <<TABLE
IPC benchmark: \`$CALL\` ($ITERATIONS iterations, $WARMUPS warmups)
Output: $advs_out

| Command | Min (ms) | Median (ms) | Average (ms) |
|---|---:|---:|---:|
| advs ipc call | $advs_stats |
| qs ${qs_args[*]} ipc call | $qs_stats |
TABLE
