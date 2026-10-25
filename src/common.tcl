# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {
    # Cache of character widths (code point -> columns), see strLength.
    variable charWidths {}
}

proc zesty::alignText {text width align} {
    # Aligns text within specified width using padding.
    #
    # text  - text content to align (may contain style tags)
    # width - target width in characters
    # align - alignment type: "left", "right", or "center"
    #
    # Returns aligned text padded with spaces to achieve specified
    # width.
    
    # Extract visible text to calculate true length
    set visible_text [zesty::extractVisibleText $text]
    set visible_length [zesty::strLength $visible_text]
    
    # Calculate padding needed
    set padding [expr {$width - $visible_length}]
    
    # If text is already wider than target width, return as-is.
    if {$padding <= 0} {
        return $text
    }
    
    # Apply alignment
    switch -exact -- $align {
        "left" {
            return "${text}[string repeat " " $padding]"
        }
        "right" {
            return "[string repeat " " $padding]${text}"
        }
        "center" {
            set left_pad [expr {$padding / 2}]
            set right_pad [expr {$padding - $left_pad}]
            return "[string repeat " " $left_pad]${text}[string repeat " " $right_pad]"
        }
        default {
            # Default to left alignment
            return "${text}[string repeat " " $padding]"
        }
    }
}

proc zesty::wrapText {text maxWidth {noWrap 0} {ellipsisWidth 3}} {
    # Wraps text to fit within specified width with ellipsis support.
    #
    # text          - text content to wrap
    # maxWidth      - maximum width in characters
    # noWrap        - if true, truncate with ellipsis instead of wrapping
    # ellipsisWidth - width reserved for ellipsis (default: 3)
    #
    # Returns list of wrapped text lines. When noWrap is enabled,
    # truncates text and adds ellipsis if it exceeds maxWidth.

    # Extract visible text for length calculation
    set visible_text   [zesty::extractVisibleText $text]
    set visible_length [zesty::strLength $visible_text]

    # If text is already shorter than maximum width
    if {$visible_length <= $maxWidth} {
        return [list $text]
    }

    # If noWrap is enabled, truncate with ellipsis instead of wrapping
    if {$noWrap} {
        if {$maxWidth < $ellipsisWidth} {
            return [list [string repeat "." $maxWidth]]
        } else {
            set truncateWidth [expr {$maxWidth - $ellipsisWidth}]
            if {$truncateWidth < 1} {
                return [list [string repeat "." $maxWidth]]
            }

            # smartTruncateStyledText reserves the room for the ellipsis itself.
            set truncated [zesty::smartTruncateStyledText $text $maxWidth 1]
            if {$truncated eq ""} {
                return [list [string repeat "." [expr {min($maxWidth, $ellipsisWidth)}]]]
            }

            return [list $truncated]
        }
    }

    # No spaces in text: split character by character
    if {[string first " " $visible_text] == -1} {
        return [zesty::SplitToWidth $text $maxWidth]
    }

    # Normal wrapping: split text into words
    set lines {}
    set currentLine ""

    foreach word [zesty::splitWithProtectedTags $text] {
        # Test if adding word exceeds max width
        set testLine "$currentLine $word"
        set testLine [string trimleft $testLine]
        set visibleline [zesty::extractVisibleText $testLine]

        if {
            ([zesty::strLength $visibleline] <= $maxWidth) ||
            ($currentLine eq "")
        } {
            set currentLine $testLine
        } else {
            lappend lines $currentLine
            set currentLine $word
        }
    }

    if {$currentLine ne ""} {
        lappend lines $currentLine
    }

    # Handle lines still too long (individual words longer than maxWidth)
    set wrappedLines {}
    foreach line $lines {
        if {[zesty::strLength [zesty::extractVisibleText $line]] <= $maxWidth} {
            lappend wrappedLines $line
        } else {
            lappend wrappedLines {*}[zesty::SplitToWidth $line $maxWidth]
        }
    }

    return $wrappedLines
}

proc zesty::SplitToWidth {text maxWidth} {
    # Splits a styled text glyph by glyph into parts of at
    # most maxWidth columns. Each character keeps its style.
    #
    # text     - text content (may contain style tags)
    # maxWidth - maximum width in columns
    #
    # Returns list of parts.
    set parts {}
    set currentPart ""
    set currentWidth 0

    foreach segment [zesty::StyleSegments $text] {
        lassign $segment styled content attrs
        foreach char [zesty::Clusters $content] {
            set charWidth [zesty::strLength $char]
            set unit [zesty::StyledText $char $attrs]

            if {($currentWidth + $charWidth) <= $maxWidth} {
                append currentPart $unit
                incr currentWidth $charWidth
            } else {
                lappend parts $currentPart
                set currentPart $unit
                set currentWidth $charWidth
            }
        }
    }

    if {$currentPart ne ""} {
        lappend parts $currentPart
    }

    return $parts
}

proc zesty::splitWithProtectedTags {string {what " "}} {
    # Splits a string into words, preserving tags: the content of a
    # tag is kept as a single word, spaces included.
    #
    # string - string to split
    # what   - character to split on
    #
    # Returns list of words and tags.
    set result {}

    foreach segment [zesty::StyleSegments $string] {
        lassign $segment styled content attrs
        if {$styled} {
            lappend result [zesty::StyledText $content $attrs]
            continue
        }
        foreach word [split [string trim $content] $what] {
            if {$word ne ""} {
                lappend result $word
            }
        }
    }

    return $result
}

proc zesty::extractVisibleText {text} {
    # Extracts visible text by removing style tags.
    #
    # text - styled text containing <s>...</s> tags
    #
    # Returns plain text with all style tags removed.
    set visible_text ""

    # Attributes are not needed here: skip their parsing (faster).
    foreach segment [zesty::StyleSegments $text 0] {
        append visible_text [lindex $segment 1]
    }

    return $visible_text
}

proc zesty::ExpandTabs {text {size 4}} {
    # Replaces tabs with spaces up to the next tab stop, so that the
    # measured width is the displayed width. Columns are counted on
    # the visible text (style tags excluded), from the start of each
    # line.
    #
    # text - text that may contain tabs and style tags
    # size - distance between tab stops
    #
    # Returns text without tabs.
    if {[string first "\t" $text] < 0} {
        return $text
    }

    set result {}
    foreach line [split $text "\n"] {
        set parts [split [zesty::extractVisibleText $line] "\t"]
        set tabs [regexp -all {\t} $line]

        # A tab inside a tag attribute is not visible: fall back to
        # a fixed width.
        if {[llength $parts] - 1 != $tabs} {
            lappend result [string map [list "\t" [string repeat " " $size]] $line]
            continue
        }

        # Number of spaces for each tab, from the visible columns.
        set col 0
        set spaces {}
        foreach part [lrange $parts 0 end-1] {
            incr col [zesty::strLength $part]
            set n [expr {$size - $col % $size}]
            lappend spaces $n
            incr col $n
        }

        # Replace each tab of the original line in turn.
        set i 0
        set newline ""
        foreach chunk [split $line "\t"] {
            append newline $chunk
            if {$i < [llength $spaces]} {
                append newline [string repeat " " [lindex $spaces $i]]
            }
            incr i
        }
        lappend result $newline
    }

    return [join $result "\n"]
}

proc zesty::smartTruncateStyledText {styled_text target_length add_ellipsis} {
    # Intelligently truncates styled text preserving formatting.
    #
    # styled_text   - text with style tags to truncate
    # target_length - maximum visible character length
    # add_ellipsis  - whether to add ellipsis for truncated text
    #
    # Returns truncated styled text maintaining style tags while
    # respecting character limits and preserving formatting.

    # Rebuild respecting character limit
    set result ""
    set visible_count 0
    set ellipsis_length [expr {$add_ellipsis ? 3 : 0}]
    set effective_target [expr {$target_length - $ellipsis_length}]
    set addEllipsis [string repeat "." $ellipsis_length]

    foreach segment [zesty::StyleSegments $styled_text] {
        lassign $segment styled content attrs
        set content_length [zesty::strLength $content]

        if {$visible_count + $content_length <= $effective_target} {
            # Complete segment fits
            append result [zesty::StyledText $content $attrs]
            incr visible_count $content_length
        } else {
            # Segment must be truncated
            set remaining_space [expr {$effective_target - $visible_count}]
            if {$remaining_space > 0} {
                set truncated_content [zesty::truncateToWidth $content $remaining_space]
                # A wide character that does not fit leaves a gap: fill it.
                set gap [string repeat " " [expr {$remaining_space - [zesty::strLength $truncated_content]}]]
                append result [zesty::StyledText "${truncated_content}${addEllipsis}${gap}" $attrs]
            }
            break
        }
    }

    return $result
}

proc zesty::strLength {text} {
    # Calculate the visual width of a string taking into account wide characters
    # such as emojis and CJK characters that occupy 2 terminal columns instead of 1.
    #
    # text - The string.
    #
    # Returns the visual width of the string.
    variable charWidths

    if {$text eq ""} {return 0}
    # Fast path: printable ASCII only, one column per character.
    if {[regexp {^[\x20-\x7E]*$} $text]} {
        return [string length $text]
    }

    set width  0
    set prev   0  ;# width of the previous visible character
    set joined 0  ;# the previous character was a zero width joiner

    # 'split' keeps characters above U+FFFF whole, even with Tcl 8.6.
    foreach char [split $text ""] {
        scan $char %c codepoint

        if {$codepoint == 0x200D} {
            # Zero width joiner: the next character is drawn in the same
            # glyph (emoji sequences such as 👨‍👩‍👧).
            set joined 1
            continue
        }
        if {$codepoint == 0xFE0F} {
            # Emoji presentation selector: a narrow symbol (✔ ⚠ ❤)
            # followed by it is drawn as a wide emoji.
            if {$prev == 1} {
                incr width
                set prev 2
            }
            continue
        }

        if {$codepoint >= 0x1F3FB && $codepoint <= 0x1F3FF && $prev == 2} {
            # Skin tone modifier: drawn in the glyph of the emoji before it.
            continue
        }

        if {[dict exists $charWidths $codepoint]} {
            set w [dict get $charWidths $codepoint]
        } else {
            set w [zesty::CharWidth $codepoint]
            dict set charWidths $codepoint $w
        }

        if {$w == 0} {continue}
        if {$joined} {
            set joined 0
            continue
        }
        incr width $w
        set prev $w
    }

    return $width
}

proc zesty::CharWidth {codepoint} {
    # Gets the number of terminal columns used by a single character,
    # following the Unicode East Asian Width property.
    #
    # codepoint - character code point
    #
    # Returns 0 (control and combining characters), 1 or 2 (wide
    # characters: CJK, fullwidth forms, emoji).

    if {$codepoint < 0x0300} {
        # Control characters
        if {($codepoint <= 0x1F) || ($codepoint >= 0x7F && $codepoint <= 0x9F)} {
            return 0
        }
        return 1
    }

    # Zero width: combining marks, zero width spaces and joiners,
    # variation selectors, byte order mark.
    if {
        ($codepoint <= 0x036F) ||
        ($codepoint >= 0x1AB0 && $codepoint <= 0x1AFF) ||
        ($codepoint >= 0x1DC0 && $codepoint <= 0x1DFF) ||
        ($codepoint >= 0x200B && $codepoint <= 0x200F) ||
        ($codepoint >= 0x20D0 && $codepoint <= 0x20FF) ||
        ($codepoint >= 0xFE00 && $codepoint <= 0xFE0F) ||
        ($codepoint >= 0xFE20 && $codepoint <= 0xFE2F) ||
        ($codepoint == 0xFEFF) ||
        ($codepoint >= 0xE0100 && $codepoint <= 0xE01EF)
    } {
        return 0
    }

    if {$codepoint < 0x1100} {
        return 1
    }

    # Symbol blocks: only the characters with an emoji presentation
    # by default are wide (⌛ ⚡ ✅ ❌ ➖ ⭐...), the others (✔ ⚠ ★ ⚙)
    # use a single column.
    if {$codepoint >= 0x2300 && $codepoint <= 0x2BFF} {
        foreach {first last} {
            0x231A 0x231B  0x2329 0x232A  0x23E9 0x23EC  0x23F0 0x23F0
            0x23F3 0x23F3  0x2614 0x2615  0x2648 0x2653  0x267F 0x267F
            0x2693 0x2693  0x26A1 0x26A1  0x26AA 0x26AB  0x26BD 0x26BE
            0x26C4 0x26C5  0x26CE 0x26CE  0x26D4 0x26D4  0x26EA 0x26EA
            0x26F2 0x26F3  0x26F5 0x26F5  0x26FA 0x26FA  0x26FD 0x26FD
            0x2705 0x2705  0x270A 0x270B  0x2728 0x2728  0x274C 0x274C
            0x274E 0x274E  0x2753 0x2755  0x2757 0x2757  0x2795 0x2797
            0x27B0 0x27B0  0x27BF 0x27BF  0x2B1B 0x2B1C  0x2B50 0x2B50
            0x2B55 0x2B55
        } {
            if {$codepoint >= $first && $codepoint <= $last} {
                return 2
            }
        }
        return 1
    }

    # Wide characters: CJK, Hangul, fullwidth forms, emoji.
    if {
        ($codepoint >= 0x1100 && $codepoint <= 0x115F) ||
        ($codepoint >= 0x2E80 && $codepoint <= 0x303E) ||
        ($codepoint >= 0x3041 && $codepoint <= 0x33FF) ||
        ($codepoint >= 0x3400 && $codepoint <= 0x4DBF) ||
        ($codepoint >= 0x4E00 && $codepoint <= 0x9FFF) ||
        ($codepoint >= 0xA000 && $codepoint <= 0xA4CF) ||
        ($codepoint >= 0xAC00 && $codepoint <= 0xD7A3) ||
        ($codepoint >= 0xF900 && $codepoint <= 0xFAFF) ||
        ($codepoint >= 0xFE30 && $codepoint <= 0xFE4F) ||
        ($codepoint >= 0xFF00 && $codepoint <= 0xFF60) ||
        ($codepoint >= 0xFFE0 && $codepoint <= 0xFFE6) ||
        ($codepoint >= 0x1F004 && $codepoint <= 0x1F004) ||
        ($codepoint >= 0x1F0CF && $codepoint <= 0x1F0CF) ||
        ($codepoint >= 0x1F18E && $codepoint <= 0x1F18E) ||
        ($codepoint >= 0x1F191 && $codepoint <= 0x1F19A) ||
        ($codepoint >= 0x1F200 && $codepoint <= 0x1F64F) ||
        ($codepoint >= 0x1F680 && $codepoint <= 0x1F6FF) ||
        ($codepoint >= 0x1F7E0 && $codepoint <= 0x1F7EB) ||
        ($codepoint >= 0x1F90C && $codepoint <= 0x1F9FF) ||
        ($codepoint >= 0x1FA70 && $codepoint <= 0x1FAFF) ||
        ($codepoint >= 0x20000 && $codepoint <= 0x3FFFD)
    } {
        return 2
    }

    return 1
}

proc zesty::Clusters {text} {
    # Splits a text into the units drawn as one glyph: a character with
    # its combining marks, emoji sequences joined by U+200D, emojis with
    # a presentation selector or a skin tone, and flags (pairs of
    # regional indicators). Cutting a text between two clusters never
    # breaks a glyph.
    #
    # text - plain text (no style tags)
    #
    # Returns list of clusters.
    variable charWidths

    set clusters {}
    set current ""
    set joined 0  ;# the previous character was a zero width joiner
    set flag   0  ;# the current cluster is a single regional indicator

    foreach char [split $text ""] {
        scan $char %c codepoint

        # Printable ASCII always starts a new cluster (fast path).
        if {$codepoint >= 0x20 && $codepoint <= 0x7E && !$joined} {
            if {$current ne ""} {lappend clusters $current}
            set current $char
            set flag 0
            continue
        }

        if {![dict exists $charWidths $codepoint]} {
            dict set charWidths $codepoint [zesty::CharWidth $codepoint]
        }
        set regional [expr {$codepoint >= 0x1F1E6 && $codepoint <= 0x1F1FF}]

        if {$current ne "" && (
            $joined || $codepoint == 0x200D || $codepoint == 0xFE0F ||
            ($codepoint >= 0x1F3FB && $codepoint <= 0x1F3FF) ||
            ($regional && $flag) || [dict get $charWidths $codepoint] == 0
        )} {
            append current $char
            set flag 0
        } else {
            if {$current ne ""} {lappend clusters $current}
            set current $char
            set flag $regional
        }
        set joined [expr {$codepoint == 0x200D}]
    }

    if {$current ne ""} {lappend clusters $current}

    return $clusters
}

proc zesty::truncateToWidth {text maxWidth} {
    # Truncates a plain text to a maximum visual width in terminal
    # columns, taking wide characters (emojis, CJK) into account.
    #
    # text     - plain text (no style tags)
    # maxWidth - maximum width in terminal columns
    #
    # Returns: The longest beginning of text fitting in maxWidth columns.
    # Fast path: printable ASCII only, one column per character.
    if {[regexp {^[\x20-\x7E]*$} $text]} {
        return [string range $text 0 $maxWidth-1]
    }

    set width 0
    set result ""
    foreach cluster [zesty::Clusters $text] {
        set w [zesty::strLength $cluster]
        if {$width + $w > $maxWidth} {break}
        incr width $w
        append result $cluster
    }

    # Tcl 8.6 stores emojis as surrogate pairs (two characters):
    # never keep half of one. No effect with Tcl 9.
    if {$result ne ""} {
        scan [string index $result end] %c last
        if {$last >= 0xD800 && $last <= 0xDBFF} {
            set result [string range $result 0 end-1]
        }
    }

    return $result
}

proc zesty::formatTextWithAlignment {text width align preserveStyles ellipsisThreshold} {
    # Formats plain text with alignment (no style preservation).
    #
    # text              - plain text to format
    # width             - target width
    # align             - alignment (left, right, center, default: left)
    # ellipsisThreshold - threshold for ellipsis
    # preserveStyles    - whether to preserve styles
    #
    # Returns formatted text with proper alignment and truncation.
    
    # Style preservation
    if {$preserveStyles} {
        set visible_text [zesty::extractVisibleText $text]
    } else {
        set visible_text $text
    }
    
    set visible_length [zesty::strLength $visible_text]

    if {$visible_length > $width} {
        if {$preserveStyles} {
            # smartTruncateStyledText reserves the room for the ellipsis itself.
            return [zesty::smartTruncateStyledText $text $width [expr {$width > $ellipsisThreshold}]]
        }
        if {$width > $ellipsisThreshold} {
            set truncated "[zesty::truncateToWidth $text [expr {$width - 3}]]..."
        } else {
            set truncated [zesty::truncateToWidth $text $width]
        }
        # A wide character that does not fit leaves a gap: fill it.
        return "$truncated[string repeat " " [expr {$width - [zesty::strLength $truncated]}]]"
    }
    
    # Text alignment.
    return [zesty::alignText $text $width $align]
}