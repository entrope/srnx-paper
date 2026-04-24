#! /bin/bash -e

for f in *.bin; do
#    raw=$(stat -f%z "$f")
    raw=$(stat -c%s "$f")
    if [ "$raw" -eq 0 ]; then
        printf "  %-22s raw=%10d  (empty)\n" "$f" "$raw"
        continue
    fi
    kanzi -c -j 1 -x -l 9 -v 0 -i "$f" -o "/tmp/cz_$f" 2>/dev/null
#    cmp=$(stat -f%z "/tmp/cz_$f")
    cmp=$(stat -c%s "/tmp/cz_$f")
    ratio=$(awk -v r=$raw -v c=$cmp 'BEGIN{ if (c>0) printf "%.3f", r/c; else print "inf" }')
    saved=$((raw - cmp))
    printf "  %-22s raw=%10d  kanzi=%10d  ratio=%6s  saved=%10d\n" "$f" "$raw" "$cmp" "$ratio" "$saved"
done
