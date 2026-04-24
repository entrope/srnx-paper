#!/bin/sh
# Convert CSS-styled railroad SVG to inline attributes for Inkscape compatibility.
#
# Inkscape's CSS parser and PDF exporter mishandle:
#   - child combinator ">" selectors
#   - rgba() fill values (rendered as solid black in PDF)
#   - background-* properties on <svg>
#
# Usage: sh fix-svg-bg.sh < input.svg > output.svg

awk '
function get_class(s,    tmp) {
    tmp = s
    if (sub(/^.*class="/, "", tmp)) {
        sub(/".*$/, "", tmp)
        return tmp
    }
    return ""
}

BEGIN { in_style = 0; stack_top = -1 }

# --- Remove <style> block ---
/^<style/ { in_style = 1; next }
/^<\/style>/ { in_style = 0; next }
in_style { next }

# --- Inject background rect after <svg> opening tag ---
/^<svg / {
    print
    print "<rect width=\"100%\" height=\"100%\" fill=\"#f4f2ef\"/>"
    next
}

# --- Track parent <g> context via stack ---
/<g class=/ {
    c = get_class($0)
    if (c != "") {
        stack_top++
        stack[stack_top] = c
    }
    print
    next
}

# --- Style <rect> based on direct parent context ---
/<rect / {
    c = get_class($0)

    if (c == "railroad_canvas") {
        gsub(/<rect /, "<rect fill=\"none\" stroke-width=\"0\" ", $0)
    } else if (stack_top >= 0 && stack[stack_top] == "terminal") {
        gsub(/<rect /, "<rect fill=\"#f1f7d3\" stroke=\"black\" stroke-width=\"3\" ", $0)
    } else if (stack_top >= 0 && stack[stack_top] == "labeledbox") {
        # #e9e9ee = rgba(90,90,150,0.1) blended over white
        # (Inkscape PDF exporter renders rgba() as solid black)
        gsub(/<rect /, "<rect fill=\"#e9e9ee\" stroke=\"grey\" stroke-width=\"1\" stroke-dasharray=\"5\" ", $0)
    } else {
        gsub(/<rect /, "<rect fill=\"#f1f7d3\" stroke=\"black\" stroke-width=\"3\" ", $0)
    }
    print
    next
}

# --- Style <path> ---
/<path / {
    gsub(/<path /, "<path stroke=\"black\" stroke-width=\"3\" fill=\"none\" ", $0)
    print
    next
}

# --- Style <text> ---
/<text / {
    c = get_class($0)
    is_comment = (c == "comment")
    is_nonterm = (stack_top >= 0 && stack[stack_top] == "nonterminal")

    fs = is_comment ? "12" : "14"
    fw = is_nonterm ? " font-weight=\"bold\"" : ""
    fst = is_comment ? " font-style=\"italic\"" : ""

    sub(/<text /, "<text font=\"" fs "px monospace\" text-anchor=\"middle\"" fw fst " ", $0)
    # Strip class="comment" — style is now inline
    gsub(/ class="comment"/, "", $0)
    print
    next
}

# --- Pop context on </g> ---
/<\/g>/ {
    if (stack_top >= 0) stack_top--
    print
    next
}

# --- Pass through everything else ---
{ print }
'
