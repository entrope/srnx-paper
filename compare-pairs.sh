#!/bin/bash

# Process command line arguments in pairs, ignoring a trailing odd argument.
# For each pair (file-a file-b), run ./+release/rnxcmp file-a file-b.

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 file1 file2 [file3 file4 ...]"
    exit 1
fi

# Iterate over arguments two at a time
i=1
while [[ $((i+1)) -lt $# ]]; do
    j=$((i+1))
    file_a="${!i}"
    file_b="${!j}"
    ${RNXCMP-rnxcmp} "$file_a" "$file_b" > /dev/null
    i=$((i+2))
done
