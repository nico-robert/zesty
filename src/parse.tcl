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
    set current_pos 0
    
    # Generate ANSI codes for base style
    set base_ansi ""
    if {[llength $base_style] > 0} {
        set base_ansi [zesty::parseStyleDictToANSI $base_style]
    }
    
    # If there's a base style, start by applying it
    if {$base_ansi ne ""} {
        set processed_text $base_ansi
    }
    
    # Regular expression to match <s> tags
    set re {<s\s+([^>]+)>([^<]*)</s>}
    
    # Search for <s> tags
    while {[regexp -indices -start $current_pos $re $result match attr_indices content_indices]} {
        lassign $match match_start match_end
        lassign $attr_indices attr_start attr_end
        lassign $content_indices content_start content_end
        
        # Extract parts
        set before     [string range $result $current_pos $match_start-1]
        set attributes [string range $result $attr_start $attr_end]
        set content    [string range $result $content_start $content_end]
        
        # Add text before tag (with base style if defined)
        append processed_text $before
        
        # Process tag attributes
        if {![string match "*=*" $attributes]} {
            error "zesty(error): Unsupported style format: $attributes"
        }
        set attrs [zesty::parseEqualAttributes $attributes]

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
        
        set current_pos [expr {$match_end + 1}]
    }
    
    # Add remaining text
    append processed_text [string range $result $current_pos end]
    
    # Final reset if necessary
    if {!$no_reset} {
        append processed_text [zesty::resetANSIStyle]
    }

    return $processed_text
}

proc zesty::parseTypeFilters {text filters} {
    # Applies type-based filters to text using regex patterns.
    # Supports 'num', 'email', and 'url' filter types.
    #
    # text - input text to filter
    # filters - key-value pairs of filter types and styles
    #
    # Returns: the text with type-specific styling applied.
    set result $text

    zesty::validateKeyValuePairs "args" $filters
    
    # Process each filter
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

        # Tags added by a previous filter (or inline tags) are left
        # untouched: tags cannot be nested.
        set result [zesty::regsubOutsideTags \
            $pattern \
            $result \
            [zesty::parseStyleDictToXML "\\1" $style] \
        ]
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
    set pos 0

    while {[regexp -indices -start $pos {<s\s+[^>]*>[^<]*</s>} $text tag]} {
        lassign $tag tag_start tag_end
        set before [string range $text $pos $tag_start-1]
        append result [regsub -all $pattern $before $replacement]
        append result [string range $text $tag_start $tag_end]
        set pos [expr {$tag_end + 1}]
    }
    set after [string range $text $pos end]
    append result [regsub -all $pattern $after $replacement]

    return $result
}

proc zesty::parseEqualFormat {attributes} {
    # Parses the format with equal sign (fg=red bold=true).
    # Handles quoted values and converts style dictionary to ANSI.
    #
    # attributes - attribute string with key=value pairs
    #
    # Returns: ANSI escape codes for the parsed attributes.
    return [zesty::parseStyleDictToANSI [zesty::parseEqualAttributes $attributes]]
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

proc zesty::parseStyleDictToANSI {style_dict} {
    # Parses style dictionary to ANSI escape codes.
    #
    # style_dict - dictionary containing style specifications
    #
    # Returns: concatenated ANSI escape codes for foreground,
    # background colors and terminal styles.
    variable termstyles
    set ansi_codes ""
    
    # Processing style dictionary options
    if {[dict exists $style_dict fg]} {
        set fg_color [dict get $style_dict fg]
        set fg_code [zesty::getColorCode $fg_color]
        if {$fg_code ne ""} {
            append ansi_codes [zesty::colorANSICode $fg_code 0]
        }
    }
    
    if {[dict exists $style_dict bg]} {
        set bg_color [dict get $style_dict bg]
        set bg_code [zesty::getColorCode $bg_color]
        if {$bg_code ne ""} {
            append ansi_codes [zesty::colorANSICode $bg_code 1]
        }
    }
    
    # Processing styles
    foreach style_name [dict keys $termstyles] {
        if {[dict exists $style_dict $style_name]} {
            if {[zesty::styleEnabled $style_name [dict get $style_dict $style_name]]} {
                append ansi_codes [zesty::styleANSICode $style_name]
            }
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
    variable termstyles
    
    # If no style to apply, return text as is
    if {$style_dict eq ""} {
        return $text
    }

    # Process constructor arguments with validation
    zesty::validateKeyValuePairs "args" $style_dict
    
    # Build general style attributes
    set general_attrs {}
    
    # Processing style dictionary options
    if {[dict exists $style_dict fg]} {
        set fg_color [dict get $style_dict fg]
        set fg_code [zesty::getColorCode $fg_color]
        if {$fg_code ne ""} {
            dict set general_attrs fg $fg_code
        }
    }
    
    if {[dict exists $style_dict bg]} {
        set bg_color [dict get $style_dict bg]
        set bg_code [zesty::getColorCode $bg_color]
        if {$bg_code ne ""} {
            dict set general_attrs bg $bg_code
        }
    }
    
    # Processing styles.
    foreach style_name [dict keys $termstyles] {
        if {[dict exists $style_dict $style_name]} {
            if {[zesty::styleEnabled $style_name [dict get $style_dict $style_name]]} {
                dict set general_attrs $style_name 1
            }
        }
    }

    # Hyperlink: 'link 1' targets the text itself, otherwise the given URL.
    if {[dict exists $style_dict link]} {
        dict set general_attrs link [dict get $style_dict link]
    }

    # If no valid attributes, return text as is
    if {![dict size $general_attrs]} {
        return $text
    }
    
    # Check if there are existing tags in the text
    if {![string match {*<s*</s>*} $text]} {
        # No existing tags, original behavior
        return "<s [zesty::formatEqualAttributes $general_attrs]>$text</s>"
    }

    # There are existing (flat) tags, process them directly
    set result ""
    set current_pos 0
    set re {<s\s+([^>]*)>([^<]*)</s>}
    
    while {$current_pos < [string length $text]} {
        # Search for next <s> tag
        if {[regexp -indices -start $current_pos $re $text match attr_indices content_indices]} {
            lassign $match match_start match_end
            lassign $attr_indices attr_start attr_end
            lassign $content_indices content_start content_end
            
            # Add text before tag (with general style)
            if {$current_pos < $match_start} {
                set before_text [string range $text $current_pos $match_start-1]
                if {$before_text ne ""} {
                    append result "<s [zesty::formatEqualAttributes $general_attrs]>$before_text</s>"
                }
            }
            
            # Process existing tag
            set existing_attrs_string [string range $text $attr_start $attr_end]
            set content [string range $text $content_start $content_end]
            
            # Parse existing attributes (quoted values may contain spaces)
            set existing_attrs [zesty::parseEqualAttributes $existing_attrs_string]

            # Merge attributes (general first, then existing for priority)
            set merged_attrs [dict merge $general_attrs $existing_attrs]

            # Build merged tag
            append result "<s [zesty::formatEqualAttributes $merged_attrs]>$content</s>"
            
            set current_pos [expr {$match_end + 1}]
        } else {
            # No more tags, add remaining text with general style
            set remaining_text [string range $text $current_pos end]
            if {$remaining_text ne ""} {
                append result "<s [zesty::formatEqualAttributes $general_attrs]>$remaining_text</s>"
            }
            break
        }
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