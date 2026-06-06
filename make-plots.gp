set datafile separator " "

# Unicode geometric shapes for point type:
# -filled-   -unfilled-
# ● \U+25CF   ○ \U+25CB
# ■ \U+25A0   □ \U+25A1
# ◆ \U+25C6   ◇ \U+25C7
# ⬢ \U+2B22   ⬡ \U+2B21
# ▲ \U+25B2   △ \U+25B3
# ▼ \U+25BC   ▽ \U+25BD
# ◀ \U+25C0   ◁ \U+25C1
# ▶ \U+25B6   ▷ \U+25B7
# ◉ \U+25C9   ◎ \U+25CE
# use hollow shapes for 30s points, filled shapes for undecimated points

set title "Compression Ratio vs Wall Time"
set xlabel "Compression Ratio"
set ylabel "Wall Time (s)"
set key right top
set pointsize 2
set logscale
set xtics 4, 2, 256
set ytics 50, 3, 4050
plot [3:240] [40:4000] \
	'pareto.dat' index 'crx'      using 1:2 title 'CRX' with points pt "\U+25A0", \
	'' index 'crx+gzip'           using 1:2 title 'CRX + gzip' with points pt "\U+25C6", \
	'' index 'crx+bzip3'          using 1:2 title 'CRX + bzip3' with points pt "\U+2B22", \
	'' index 'srnx'               using 1:2 title 'SRNX' with points pt "\U+25B2", \
	'' index 'srnx+bzip3'         using 1:2 title 'SRNX + bzip3' with points pt "\U+25C0", \
	'' index 'srnx+zpaq'          using 1:2 title 'SRNX + zpaq' with points pt "\U+25B6", \
	'' index '30s'                using 1:2 title '30 s' with points pt "\U+25CB", \
	'' index '30s+crx'            using 1:2 title '30 s + CRX' with points pt "\U+25A1", \
	'' index '30s+crx+gzip'       using 1:2 title '30s + CRX + gzip' with points pt "\U+25C7", \
	'' index '30s+srnx'           using 1:2 title '30s + SRNX' with points pt "\U+25B3", \
	'' index '30s+srnx+pcompress' using 1:2 title '30s + SRNX + pcompress' with points pt "\U+25C1", \
	'' index '30s+srnx+zpaq'      using 1:2 title '30s + SRNX + zpaq' with points pt "\U+25B7"
