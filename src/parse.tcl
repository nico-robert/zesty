# Copyright (c) 2025-2026 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {}

proc zesty::parseStyle {text base_style {no_reset 0} {filters {}} {command {}}} {
    # Parses inline styles with base style support.
    #
    # text       - input text containing style tags
    # base_style - base style dictionary to apply
    # no_reset   - whether to suppress reset codes (default: 0)
    # filters    - list of type filters to apply
    # command    - command to execute on text
    #
    # Returns: the processed text with ANSI escape codes applied.
    set result $text

    if {([llength $filters] > 0) && ($command ne "")} {
        zesty::throwError "'Filters' and 'command' cannot be used together."
    }

    # Apply type filters first if present
    if {[llength $filters] > 0} {
        set result [zesty::parseTypeFilters $result $filters]
    } elseif {$command ne ""} {
        set name [lindex $command 0]
        if {[uplevel #0 [list namespace which -command $name]] eq ""} {
            zesty::throwError "'$name' is not a valid command."
        }
        set result [uplevel #0 [list {*}$command $text]]
    }

    # Process tags sequentially
    set processed_text ""

    # Generate ANSI codes for base style
    set base_ansi ""
    if {[llength $base_style] > 0} {
        set base_ansi [zesty::parseStyleDictToANSI $base_style]
    }

    # If there's a base style, start by applying it
    if {$base_ansi ne ""} {
        set processed_text $base_ansi
    }

    foreach segment [zesty::StyleSegments $result] {
        lassign $segment styled content attrs

        # Text outside tags (with base style if defined)
        if {!$styled} {
            append processed_text $content
            continue
        }

        # 'link' is not a style: 'link=1' targets the content itself,
        # any other value is the target URL, a false value disables it.
        set link ""
        if {[dict exists $attrs link]} {
            set link [dict get $attrs link]
            dict unset attrs link
            if {[string is boolean -strict $link]} {
                set link [expr {$link ? $content : ""}]
            }
        }
        set local_ansi [zesty::parseStyleDictToANSI $attrs]

        # Apply local style, then content, then return to base style
        if {$local_ansi ne ""} {
            append processed_text $local_ansi
        }
        if {$link ne ""} {
            # OSC 8 hyperlink: the terminal shows the content and
            # opens the link on Ctrl+click (ignored if unsupported).
            append processed_text "\033\]8;;$link\033\\" $content "\033\]8;;\033\\"
        } else {
            append processed_text $content
        }

        # Return to base style after local content (or reset if no base)
        if {$base_ansi ne ""} {
            append processed_text $base_ansi  ; # Return to base style
        } elseif {!$no_reset} {
            append processed_text [zesty::resetANSIStyle]   ; # Complete reset
        }
    }

    # Final reset if necessary
    if {!$no_reset} {
        append processed_text [zesty::resetANSIStyle]
    }

    return $processed_text
}

proc zesty::StyleSegments {text {withAttrs 1}} {
    # Splits a text into plain and styled segments. This is the only
    # place where style tags are parsed.
    # Nested tags are flattened: a segment gets the attributes of all
    # the tags around it, the innermost ones taking precedence. A tag
    # without its closing tag (or the reverse) is kept as plain text.
    #
    # text      - text containing style tags
    # withAttrs - 0 to skip attribute parsing (faster, when only the
    #             visible text is needed)
    #
    # Returns: A list of {styled content attrs} elements: styled is 1
    # for the content of a tag and 0 for plain text, attrs is the
    # dictionary of the tag attributes. 'link=1' is replaced by the
    # visible text of its tag, so that a link split by nested tags
    # still targets the whole text.

    # Fast path: no closing tag, no style.
    if {[string first "</s>" $text] < 0} {
        return [list [list 0 $text {}]]
    }

    # 1. Pair opening and closing tags.
    set opened {}
    set tags {}
    # No capture group: much faster with the Tcl regexp engine.
    foreach match [regexp -all -inline -indices {<s\s+[^>]+>|</s>} $text] {
        lassign $match start end

        if {[string index $text $start+1] ne "/"} {
            set attributes [string trimleft [string range $text $start+2 $end-1]]
            lappend opened [list $start $end $attributes]
            continue
        }

        # Closing tag without opening tag: plain text.
        if {![llength $opened]} {continue}

        lassign [lindex $opened end] open_start open_end attributes
        set opened [lrange $opened 0 end-1]

        if {![string match "*=*" $attributes]} {
            error "zesty(error): Unsupported style format: $attributes"
        }

        set attrs {}
        if {$withAttrs} {
            set attrs [zesty::parseEqualAttributes $attributes]

            if {[dict exists $attrs link] && [string is true -strict [dict get $attrs link]]} {
                set inner [string range $text $open_end+1 $start-1]
                dict set attrs link [regsub -all {<s\s+[^>]+>|</s>} $inner {}]
            }
        }

        # Nested tags are listed when their closing tag is found, so the
        # list must be sorted (side by side tags are already in order).
        if {[llength $tags] && $open_start < [lindex $tags end 0]} {
            set nested 1
        }
        lappend tags [list $open_start $open_end $attrs] [list $start $end {}]
    }
    # Opening tags left in 'opened' have no closing tag: plain text.
    if {[info exists nested]} {
        set tags [lsort -integer -index 0 $tags]
    }

    # 2. Walk the paired tags in order, with a stack of merged attributes.
    set segments {}
    set stack {}
    set pos 0

    foreach tag $tags {
        lassign $tag start end attrs

        set content [string range $text $pos $start-1]
        if {$content ne ""} {
            if {[llength $stack]} {
                lappend segments [list 1 $content [lindex $stack end]]
            } else {
                lappend segments [list 0 $content {}]
            }
        }

        if {[string index $text $start+1] eq "/"} {
            set stack [lrange $stack 0 end-1]
        } elseif {[llength $stack] && [dict size $attrs]} {
            lappend stack [dict merge [lindex $stack end] $attrs]
        } elseif {[llength $stack]} {
            lappend stack [lindex $stack end]
        } else {
            lappend stack $attrs
        }
        set pos [expr {$end + 1}]
    }

    set content [string range $text $pos end]
    if {$content ne "" || ![llength $segments]} {
        lappend segments [list 0 $content {}]
    }

    return $segments
}

proc zesty::StyledText {text attrs} {
    # Wraps text in a style tag, the reverse of zesty::StyleSegments.
    #
    # text  - text to wrap
    # attrs - dictionary of tag attributes
    #
    # Returns: the tagged text, or text as is if attrs is empty.
    if {![dict size $attrs]} {
        return $text
    }

    return "<s [zesty::formatEqualAttributes $attrs]>$text</s>"
}

proc zesty::parseTypeFilters {text filters} {
    # Applies type-based filters to text using regex patterns.
    # Supports 'num', 'email', and 'url' filter types.
    #
    # text - input text to filter
    # filters - key-value pairs of filter types and styles
    #
    # Returns: the text with type-specific styling applied.
    zesty::validateKeyValuePairs "args" $filters

    # Build the regsub pattern and replacement of each filter
    set rules {}
    foreach {key style} $filters {
        # Validate style
        zesty::validateKeyValuePairs "style" $style

        set pattern {}

        # Build replacement pattern according to type
        switch -exact -- $key {
            "num" {
                # Replace all numbers (integers and decimals)
                # Uses word boundaries to avoid false positives
                set pattern {\m(\d+(?:\.\d+)?)\M}
            }
            "email" {
                # Pattern for email addresses
                set pattern {([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,})}
                # A clickable email address opens the mail client.
                if {[dict exists $style link] && [string is true -strict [dict get $style link]]} {
                    dict set style link "mailto:\\1"
                }
            }
            "url" {
                # Pattern for URLs (trailing punctuation is not part of the link).
                # \x22 is '"', written this way to keep editors' syntax highlighting.
                set pattern {(https?://[^\s<>\x22]*[^\s<>\x22.,;:!?)\]])}
            }
            default {
                zesty::throwError "Unknown type: $key"
            }
        }

        lappend rules $pattern [zesty::parseStyleDictToXML "\\1" $style]
    }

    # Filters apply to the content of user tags too (the nested tags
    # they create are flattened later), but not inside the tags added
    # by a previous filter: the digits of an URL stay part of the URL.
    set result ""
    foreach segment [zesty::StyleSegments $text] {
        lassign $segment styled content attrs
        foreach {pattern replacement} $rules {
            set content [zesty::regsubOutsideTags $pattern $content $replacement]
        }
        append result [zesty::StyledText $content $attrs]
    }

    return $result
}

proc zesty::regsubOutsideTags {pattern text replacement} {
    # Applies 'regsub -all' to the parts of text located outside
    # <s ...>...</s> tags.
    #
    # pattern     - regular expression
    # text        - input text, possibly containing style tags
    # replacement - replacement string (same syntax as regsub)
    #
    # Returns: the text with replacements applied outside tags.
    set result ""

    foreach segment [zesty::StyleSegments $text] {
        lassign $segment styled content attrs
        if {$styled} {
            append result [zesty::StyledText $content $attrs]
        } else {
            append result [regsub -all $pattern $content $replacement]
        }
    }

    return $result
}

proc zesty::parseEqualAttributes {attributes} {
    # Parses the format with equal sign (fg=red bold=true) into a
    # dictionary. Supports values with spaces when quoted (single or
    # double quotes).
    #
    # attributes - attribute string with key=value pairs
    #
    # Returns: A dictionary of attribute names and values.
    set style_dict {}
    set pattern {(\w+)\s*=\s*(?:'([^']*)'|\"([^\"]*)\"|([^\s]+))}

    set matches [regexp -all -inline $pattern $attributes]

    # Process each match
    foreach {match key val_single val_double val_plain} $matches {
        set value ""
        foreach val [list $val_single $val_double $val_plain] {
            if {$val ne ""} {
                set value $val
                break
            }
        }
        dict set style_dict $key $value
    }

    return $style_dict
}

proc zesty::NormalizeStyle {style_dict} {
    # Converts a style dictionary into tag attributes: 'fg' and 'bg'
    # as color codes (unknown colors are dropped), enabled terminal
    # styles as 1 and 'link' as is. Shared by parseStyleDictToANSI
    # and parseStyleDictToXML.
    #
    # style_dict - dictionary containing style specifications
    #
    # Returns: A dictionary of attributes, in the order fg, bg,
    # terminal styles, link.
    variable termstyles
    set attrs {}

    foreach key {fg bg} {
        if {[dict exists $style_dict $key]} {
            set code [zesty::getColorCode [dict get $style_dict $key]]
            if {$code ne ""} {
                dict set attrs $key $code
            }
        }
    }

    foreach style_name [dict keys $termstyles] {
        if {[dict exists $style_dict $style_name]} {
            if {[zesty::styleEnabled $style_name [dict get $style_dict $style_name]]} {
                dict set attrs $style_name 1
            }
        }
    }

    # Hyperlink: 'link 1' targets the text itself, otherwise the given URL.
    if {[dict exists $style_dict link]} {
        dict set attrs link [dict get $style_dict link]
    }

    return $attrs
}

proc zesty::parseStyleDictToANSI {style_dict} {
    # Parses style dictionary to ANSI escape codes.
    #
    # style_dict - dictionary containing style specifications
    #
    # Returns: concatenated ANSI escape codes for foreground,
    # background colors and terminal styles.
    set ansi_codes ""

    dict for {key value} [zesty::NormalizeStyle $style_dict] {
        switch -exact -- $key {
            fg      {append ansi_codes [zesty::colorANSICode $value 0]}
            bg      {append ansi_codes [zesty::colorANSICode $value 1]}
            link    {}
            default {append ansi_codes [zesty::styleANSICode $key]}
        }
    }

    return $ansi_codes
}

proc zesty::styleEnabled {name value} {
    # Checks if a terminal style (bold, italic...) is enabled.
    #
    # name  - style name
    # value - style value, must be a boolean
    #
    # Returns: 1 if the style is enabled, 0 otherwise, or throws an
    # error if value is not a boolean.
    if {![string is boolean -strict $value]} {
        error "zesty(error): style '$name' must be a boolean value,\
            got '$value'."
    }

    return [string is true $value]
}

proc zesty::formatEqualAttributes {attrs} {
    # Formats a dictionary as attributes with equal sign
    # (fg=red bold=1), the reverse of zesty::parseEqualAttributes.
    # Empty values and values containing spaces are quoted.
    #
    # attrs - dictionary of attribute names and values
    #
    # Returns: The attribute string.
    set result {}
    dict for {key value} $attrs {
        if {$value eq "" || [regexp {\s} $value]} {
            set quote [expr {[string first "'" $value] >= 0 ? "\"" : "'"}]
            set value $quote$value$quote
        }
        lappend result "${key}=${value}"
    }

    return [join $result " "]
}

proc zesty::parseStyleDictToXML {text style_dict} {
    # Parses style dictionary to XML-like style tags.
    #
    # text       - text content to wrap with style tags
    # style_dict - dictionary containing style specifications
    #
    # Returns: text wrapped in <s> tags with style attributes.

    # If no style to apply, return text as is
    if {$style_dict eq ""} {
        return $text
    }

    # Process constructor arguments with validation
    zesty::validateKeyValuePairs "args" $style_dict

    # Build general style attributes
    set general_attrs [zesty::NormalizeStyle $style_dict]

    # If no valid attributes, return text as is
    if {![dict size $general_attrs]} {
        return $text
    }

    # No existing tags: wrap the whole text
    set segments [zesty::StyleSegments $text]
    if {([llength $segments] == 1) && ![lindex $segments 0 0]} {
        return [zesty::StyledText $text $general_attrs]
    }

    # 'link 1' targets the whole visible text, not each segment
    if {[dict exists $general_attrs link] &&
        [string is true -strict [dict get $general_attrs link]]
    } {
        set visible ""
        foreach segment $segments {
            append visible [lindex $segment 1]
        }
        dict set general_attrs link $visible
    }

    # Existing tags: merge attributes (general first, then existing
    # for priority)
    set result ""
    foreach segment $segments {
        lassign $segment styled content attrs
        append result [zesty::StyledText $content [dict merge $general_attrs $attrs]]
    }

    return $result
}

proc zesty::parseContentLine {line} {
    # Main function to analyze a complex line (style tags + ANSI codes).
    #
    # line - input line containing style tags and ANSI codes
    #
    # Returns: a dictionary with original_line, parsed_line, and
    # visible_length keys for content analysis.

    # First, parse <s> tags
    set parsed_line [zesty::extractVisibleText $line]

    return [list \
        original_line $line \
        parsed_line $parsed_line \
        visible_length [zesty::strLength $parsed_line] \
    ]
}

proc zesty::unescapeStyleTags {text escape_map} {
    # Unescape back to original characters
    #
    # text       - input text
    # escape_map - escape character mapping
    #
    # Returns: unescaped text

    return [string map $escape_map $text]
}
