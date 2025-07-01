# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {}

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

            set truncated [zesty::smartTruncateStyledText $text $truncateWidth 1]
            if {$truncated eq ""} {
                return [list [string repeat "." [expr {min($maxWidth, $ellipsisWidth)}]]]
            }
            
            return [list $truncated]
        }
    }
    
    # Normal wrapping when noWrap is disabled
    set lines {}
    set currentLine ""
    
    # Split text into words
    if {[string first " " $visible_text] != -1} {
        set words [zesty::splitWithProtectedTags $text]

        foreach word $words {
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

    } else {
        # No spaces in text, split character by character
        set currentWidth 0
        set currentLine ""
        set result [zesty::splitTagsToChars $text]
        
        foreach char [zesty::splitWithProtectedTags $result ""] {
            set visiblechar [zesty::extractVisibleText $char]
            set charWidth [zesty::strLength $visiblechar]
            
            if {($currentWidth + $charWidth) <= $maxWidth} {
                append currentLine $char
                incr currentWidth $charWidth
            } else {
                lappend lines $currentLine
                set currentLine $char
                set currentWidth $charWidth
            }
        }
        
        if {$currentLine ne ""} {
            lappend lines $currentLine
        }
    }
    
    # Handle lines still too long (individual words longer than maxWidth)
    set wrappedLines {}
    foreach line $lines {
        if {[zesty::strLength [zesty::extractVisibleText $line]] <= $maxWidth} {
            lappend wrappedLines $line
        } else {
            # Split line character by character
            set currentWidth 0
            set currentPart ""
            set result [zesty::splitTagsToChars $line]

            foreach char [zesty::splitWithProtectedTags $result ""] {
                set visiblechar [zesty::extractVisibleText $char]
                set charWidth [zesty::strLength $visiblechar]
                
                if {($currentWidth + $charWidth) <= $maxWidth} {
                    append currentPart $char
                    incr currentWidth $charWidth
                } else {
                    lappend wrappedLines $currentPart
                    set currentPart $char
                    set currentWidth $charWidth
                }
            }
            
            if {$currentPart ne ""} {
                lappend wrappedLines $currentPart
            }
        }
    }
    
    return $wrappedLines
}

proc zesty::splitWithProtectedTags {string {what " "}} {
    # Splits a string into words, preserving tags.
    #
    # string - string to split
    # what   - character to split on
    #
    # Returns list of words and tags.
    set marker "___SPACE___"
    set result {}
    set remaining $string
    
    # Process each part of the string - regex updated to handle both formats
    while {[regexp {^(.*?)<s([^>]*)>([^<]*)</s>(.*)$} $remaining -> before attr content after]} {
        # Add words before the tag
        if {$before ne ""} {
            foreach word [split [string trim $before] $what] {
                if {$word ne ""} {
                    lappend result $word
                }
            }
        }
        
        # Create the tag with protected spaces
        set protected_content [string map [list " " $marker] $content]
        set complete_tag "<s$attr>$protected_content</s>"
        lappend result $complete_tag
        
        set remaining $after
    }
    
    # Process what remains
    if {$remaining ne ""} {
        foreach word [split [string trim $remaining] $what] {
            if {$word ne ""} {
                lappend result $word
            }
        }
    }
    
    # Restore spaces in tags
    set final_result {}
    foreach word $result {
        lappend final_result [string map [list $marker " "] $word]
    }
    
    return $final_result
}

proc zesty::splitTagsToChars {string} {
    set result ""
    set remaining $string
    
    # Process each part of the string
    while {[regexp {^(.*?)<s([^>]*)>([^<]*)</s>(.*)$} $remaining -> before attr content after]} {
        # Add the part before the tag
        append result $before
        
        # Split the tag content character by character
        for {set i 0} {$i < [string length $content]} {incr i} {
            set char [string index $content $i]
            append result "<s$attr>$char</s>"
        }
        
        set remaining $after
    }
    
    # Add what remains
    append result $remaining
    
    return $result
}

proc zesty::extractVisibleText {text} {
    # Extracts visible text by removing style tags.
    #
    # text - styled text containing <s>...</s> tags
    #
    # Returns plain text with all style tags removed.
    set visible_text $text
    
    # Remove all <s ...>...</s> tags
    while {[regexp -indices {<s\s*[^>]*>([^<]*)</s>} $visible_text match content_indices]} {
        lassign $match match_start match_end
        lassign $content_indices content_start content_end
        
        # Extract visible content
        set content [string range $visible_text $content_start $content_end]
        
        # Replace complete tag with its content
        set visible_text [string replace $visible_text $match_start $match_end $content]
    }
    
    return $visible_text
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

    set segments {}
    set current_pos 0
    
    # Parse text to identify styled and non-styled segments
    while {
        [regexp -indices -start \
        $current_pos {<s\s*([^>]*)>([^<]*)</s>} $styled_text match attr_indices content_indices]
    } {
        lassign $match match_start match_end
        lassign $attr_indices attr_start attr_end
        lassign $content_indices content_start content_end
        
        # Text before tag (non-styled)
        if {$current_pos < $match_start} {
            set before_text [string range $styled_text $current_pos $match_start-1]
            if {$before_text ne ""} {
                lappend segments [list "plain" $before_text]
            }
        }
        
        # Tag content (styled)
        set attributes [string range $styled_text $attr_start $attr_end]
        set content [string range $styled_text $content_start $content_end]
        lappend segments [list "styled" $content $attributes]
        
        set current_pos [expr {$match_end + 1}]
    }
    
    # Add remaining text after last tag
    if {$current_pos < [string length $styled_text]} {
        set remaining_text [string range $styled_text $current_pos end]
        if {$remaining_text ne ""} {
            lappend segments [list "plain" $remaining_text]
        }
    }
    
    # Rebuild respecting character limit
    set result ""
    set visible_count 0
    set ellipsis_length [expr {$add_ellipsis ? 3 : 0}]
    set effective_target [expr {$target_length - $ellipsis_length}]
    
    foreach segment $segments {
        set type [lindex $segment 0]
        set content [lindex $segment 1]
        set content_length [string length $content]
        
        if {$visible_count + $content_length <= $effective_target} {
            # Complete segment fits
            if {$type eq "styled"} {
                set attributes [lindex $segment 2]
                append result "<s $attributes>$content</s>"
            } else {
                append result $content
            }
            incr visible_count $content_length
        } else {
            # Segment must be truncated
            set remaining_space [expr {$effective_target - $visible_count}]
            if {$remaining_space > 0} {
                set truncated_content [string range $content 0 $remaining_space-1]
                if {$type eq "styled"} {
                    set attributes [lindex $segment 2]
                    append result "<s $attributes>${truncated_content}...</s>"
                } else {
                    append result "${truncated_content}..."
                }
            }
            break
        }
    }

    return $result
}

proc zesty::findLastPattern {contentLines typeStyle} {
    # Searches for the last occurrence of a pattern in a list of lines.
    # The pattern is generated from the characters in the style lists.
    #
    # contentLines -  List of lines to search in.
    # typeStyle    -  Dictionary mapping pattern type to list of style characters.
    #
    # Returns the index of the last line containing the pattern, or -1 if no
    # line contains the pattern.
    set allBorderChars {}

    foreach styleList [dict values $typeStyle] {
        foreach char $styleList {
            lappend allBorderChars $char
        }
    }

    set bdchars [join [lsort -unique $allBorderChars] ""]

    set totalLines [llength $contentLines]
    set pattern "^\[^\w\]*\[$bdchars\]+\[^\w\]*\$"
    
    # Search backwards from the end
    for {set i [expr {$totalLines - 1}]} {$i >= 0} {incr i -1} {
        set line [lindex $contentLines $i]
        set visible_line [zesty::extractVisibleText $line]
        if {[regexp $pattern $visible_line]} {
            return $i
        }
    }
    
    return -1
}

proc zesty::findFirstPattern {contentLines typeStyle} {
    # Searches for the first occurrence of a pattern in a list of lines.
    # The pattern is generated from the characters in the style lists.
    #
    # contentLines -  List of lines to search in.
    # typeStyle    -  Dictionary mapping pattern type to list of style characters.
    #
    # Returns: The index of the first line containing the pattern, or -1 if not found.
    set allBorderChars {}

    foreach styleList [dict values $typeStyle] {
        foreach char $styleList {
            lappend allBorderChars $char
        }
    }

    set bdchars [join [lsort -unique $allBorderChars] ""]

    set totalLines [llength $contentLines]
    set pattern "^\[^\w\]*\[$bdchars\]+\[^\w\]*\$"
    
    # Search
    for {set i 0} {$i < $totalLines} {incr i} {
        set line [lindex $contentLines $i]
        set visible_line [zesty::extractVisibleText $line]
        if {[regexp $pattern $visible_line] && ($i > 0)} {
            return $i
        }
    }
    
    return -1
}

proc zesty::strLength {text} {
    # Calculate the visual width of a string taking into account wide characters
    # such as emojis and CJK characters that occupy 2 terminal columns instead of 1.
    #
    # text - The string.
    #
    # Returns the visual width of the string.

    if {$text eq ""} {return 0}
    set width 0

    for {set i 0} {$i < [string length $text]} {incr i} {
        set char [string index $text $i]
        set codepoint [scan $char %c]

        # Control characters (zero width)
        if {
            ($codepoint <= 0x1F) ||
            ($codepoint >= 0x7F && $codepoint <= 0x9F)
        } {
            continue
        }

        # Determine if this is a wide character (emoji or CJK characters)
        if {
            ($codepoint >= 0x1100 && $codepoint <= 0x11FF) || 
            ($codepoint >= 0x3000 && $codepoint <= 0x303F) || 
            ($codepoint >= 0x3040 && $codepoint <= 0x309F) || 
            ($codepoint >= 0x30A0 && $codepoint <= 0x30FF) || 
            ($codepoint >= 0x3400 && $codepoint <= 0x4DBF) || 
            ($codepoint >= 0x4E00 && $codepoint <= 0x9FFF) || 
            ($codepoint >= 0xAC00 && $codepoint <= 0xD7AF) || 
            ($codepoint >= 0xF900 && $codepoint <= 0xFAFF) || 
            ($codepoint >= 0xFF00 && $codepoint <= 0xFFEF) || 
            ($codepoint >= 0x1F300 && $codepoint <= 0x1F9FF) ||
            ($codepoint >= 0x2600 && $codepoint <= 0x26FF) || 
            ($codepoint >= 0x2700 && $codepoint <= 0x27BF) || 
            ($codepoint >= 0x2300 && $codepoint <= 0x23FF) || 
            ($codepoint >= 0x2B00 && $codepoint <= 0x2BFF)
        } { 
            incr width 2
        } else {
            incr width 1
        }
    }
    
    return $width
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
            if {$width > $ellipsisThreshold} {
                # Preserving styled tags and add "..."
                return [zesty::smartTruncateStyledText $text [expr {$width - 3}] "true"]
            } else {
                # Simply truncate preserving tags
                return [zesty::smartTruncateStyledText $text $width "false"]
            }
        } else {
            if {$width > $ellipsisThreshold} {
                return "[string range $text 0 $width-4]..."
            } else {
                return [string range $text 0 $width-1]
            }
        }
    }
    
    # Text alignment.
    return [zesty::alignText $text $width $align]
}