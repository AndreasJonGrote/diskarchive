#!/usr/bin/env bash
# Füllt Stick-Struktur auf dem STRESS-Volume (2×700, 2×14_300, 1×1_400 + ._meta).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MOUNT="${STRESS_MOUNT:-/Volumes/STRESS}"
STICK="${STRESS_STICK_ROOT:-$MOUNT/stick}"
PARALLEL="${STRESS_FILL_PARALLEL:-4}"
LARGE="${STRESS_LARGE_COUNT:-14300}"
SMALL="${STRESS_SMALL_COUNT:-700}"
TINY="${STRESS_TINY_COUNT:-1400}"

if [[ ! -d "$MOUNT" ]]; then
  echo "Mount fehlt: $MOUNT (STRESS_BUILD_IMAGE=1 oder Volume manuell mounten)" >&2
  exit 1
fi

mkdir -p "$STICK/700-a" "$STICK/700-b" "$STICK/14300-a" "$STICK/14300-b" "$STICK/1400"

fill_dir() {
  local dir="$1"
  local count="$2"
  local label="$3"
  echo "=== $label ($count Dateien) → $dir ==="
  local batch=500
  local i=0
  while (( i < count )); do
    local end=$(( i + batch ))
    (( end > count )) && end=$count
    for (( j = i; j < end; j++ )); do
      echo "x" > "$dir/f-$j.txt"
      echo "meta" > "$dir/._f-$j.txt"
    done
    i=$end
    if (( i % 2000 == 0 || i == count )); then
      echo "  … $i / $count"
    fi
  done
}

export -f fill_dir

for pair in "700-a:$SMALL" "700-b:$SMALL" "1400:$TINY"; do
  name="${pair%%:*}"
  count="${pair##*:}"
  fill_dir "$STICK/$name" "$count" "$name"
done

if [[ "$PARALLEL" -gt 1 ]]; then
  echo "=== Große Ordner (parallel=$PARALLEL) ==="
  fill_dir "$STICK/14300-a" "$LARGE" "14300-a" &
  fill_dir "$STICK/14300-b" "$LARGE" "14300-b" &
  wait
else
  fill_dir "$STICK/14300-a" "$LARGE" "14300-a"
  fill_dir "$STICK/14300-b" "$LARGE" "14300-b"
fi

find "$STICK" -type f | wc -l | awk -v s="$STICK" '{print "Dateien unter " s ": " $1}'
echo "Fertig: stress_fill_stick.sh"
