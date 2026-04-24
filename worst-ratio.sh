#!/usr/bin/env bash
#
# worst-ratio — find the largest and smallest size ratios between
# matching files in two directories.
#
# Usage: worst-ratio <dir1> <dir2>

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: worst-ratio <dir1> <dir2>" >&2
  exit 1
fi

DIR1="$1"
DIR2="$2"

if [[ ! -d "$DIR1" ]]; then
  echo "Error: '$DIR1' is not a directory" >&2
  exit 1
fi

if [[ ! -d "$DIR2" ]]; then
  echo "Error: '$DIR2' is not a directory" >&2
  exit 1
fi

# Track best/worst ratios (as integers: numerator and denominator)
max_num=0
max_den=1
max_file=""
min_num=0
min_den=1
min_file=""
found=0

for filepath in "$DIR1"/*; do
  # Skip if glob didn't match anything
  [[ -e "$filepath" ]] || continue
  # Only regular files
  [[ -f "$filepath" ]] || continue

  filename=$(basename "$filepath")
  other="$DIR2/$filename"
  #other="$DIR2/${filename%o.srnx}d.srnx"

  # Skip if no matching file in dir2
  [[ -f "$other" ]] || continue

  size1=$(stat -f%z "$filepath" 2>/dev/null || stat -c%s "$filepath")
  size2=$(stat -f%z "$other" 2>/dev/null || stat -c%s "$other")

  # Skip zero-size files to avoid division issues
  [[ "$size2" -eq 0 ]] && continue

  found=1

  # Compare ratio size1/size2 against current max (cross-multiply to stay integer)
  if [[ $(( size1 * max_den )) -gt $(( max_num * size2 )) ]]; then
    max_num=$size1
    max_den=$size2
    max_file="$filename"
  fi

  # Compare ratio size1/size2 against current min
  if [[ "$min_num" -eq 0 ]] || [[ $(( size1 * min_den )) -lt $(( min_num * size2 )) ]]; then
    min_num=$size1
    min_den=$size2
    min_file="$filename"
  fi
done

if [[ "$found" -eq 0 ]]; then
  echo "No matching files found between '$DIR1' and '$DIR2'."
  exit 0
fi

# Compute floating-point ratios for display
max_ratio=$(awk "BEGIN {printf \"%.4f\", $max_num / $max_den}")
min_ratio=$(awk "BEGIN {printf \"%.4f\", $min_num / $min_den}")

echo "Largest ratio: $max_ratio ($max_file)"
echo "Smallest ratio: $min_ratio ($min_file)"
