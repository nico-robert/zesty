# Copyright (c) 2025 Nicolas ROBERT.
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
        error "'Filters' and 'command' cannot be used together."
    }

    # Apply type filters first if present
    if {[llength $filters] > 0} {
        set result [zesty::parseTypeFilters $result $filters]
    } elseif {$command ne ""} {
        if {[info commands $command] eq ""} {
            error "'$command' is not a valid command."
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
    
    set re {<s\s*([^>]+)>([^<]*)</s>}
    
    # Search for <s> tags
    while {[regexp -indices -start $current_pos $re $result match attr_indices content_indices]} {
        lassign $match match_start match_end
        lassign $attr_indices attr_start attr_end
        lassign $content_indices content_start content_end
        
        # Extract parts
        set before [string range $result $current_pos [expr {$match_start - 1}]]
        set attributes [string range $result $attr_start $attr_end]
        set content [string range $result $content_start $content_end]
        
        # Add text before tag (with base style if defined)
        append processed_text $before
        
        # Process tag attributes
        set local_ansi ""
        if {[string match "*=*" $attributes]} {
            set local_ansi [zesty::parseEqualFormat $attributes]
        } else {
            # Unsupported format - ignore
            error "Error: unsupported style format: $attributes"
        }
        
        # Apply local style, then content, then return to base style
        if {$local_ansi ne ""} {
            append processed_text $local_ansi
        }
        append processed_text $content
        
        # Return to base style after local content (or reset if no base)
        if {$base_ansi ne ""} {
            append processed_text $base_ansi  ; # Return to base style
        } elseif {!$no_reset} {
            append processed_text "\033\[0m"   ; # Complete reset
        }
        
        set current_pos [expr {$match_end + 1}]
    }
    
    # Add remaining text
    append processed_text [string range $result $current_pos end]
    
    # Final reset if necessary
    if {!$no_reset} {
        append processed_text "\033\[0m"
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

    if {[llength $filters] % 2} {
        error "Arguments must be in key-value pairs"
    }
    
    # Process each filter
    foreach {key style} $filters {

        if {[llength $style] % 2} {
             error "'style' must be in key-value pairs"
        }

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
            }
            "url" {
                # Pattern for URLs
                set pattern {(https?://[^\s]+)}
            }
            default {
                error "Unknown type: $key"
            }
        }

        set result [regsub -all \
            $pattern \
            $result \
            [zesty::parseStyleDictToXML "\\1" $style] \
        ]
    }
    
    return $result
}

proc zesty::parseEqualFormat {attributes} {
    # Parses the format with equal sign (fg=red bold=true).
    # Handles quoted values and converts style dictionary to ANSI.
    #
    # attributes - attribute string with key=value pairs
    #
    # Returns: ANSI escape codes for the parsed attributes.
    set style_dict [dict create]
        
    foreach attr [split $attributes] {
        set attr [string trim $attr]
        if {$attr eq ""} {continue}
        
        # Search for key=value format
        if {[regexp {^([^=]+)=(.+)$} $attr -> key value]} {
            # Remove single or double quotes if present
            set value [string map {"'" "" "\"" ""} $value]
            dict set style_dict $key $value
        }
    }
    
    return [zesty::parseStyleDictToANSI $style_dict]
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
            if {[dict get $style_dict $style_name]} {
                append ansi_codes [zesty::styleANSICode $style_name]
            }
        }
    }
    
    return $ansi_codes
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
    if {[llength $style_dict] % 2} {
        error "Arguments must be in key-value pairs"
    }
    
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
            if {[dict get $style_dict $style_name]} {
                dict set general_attrs $style_name 1
            }
        }
    }
    
    # If no valid attributes, return text as is
    if {![dict size $general_attrs]} {
        return $text
    }
    
    # Check if there are existing tags in the text
    if {![string match {*<s*</s>*} $text]} {
        # No existing tags, original behavior
        set xml_codes {}
        dict for {key value} $general_attrs {
            lappend xml_codes "${key}=${value}"
        }
        return "<s [join $xml_codes " "]>$text</s>"
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
                set before_text [string range $text $current_pos [expr {$match_start - 1}]]
                if {$before_text ne ""} {
                    set attrs_list {}
                    dict for {key value} $general_attrs {
                        lappend attrs_list "${key}=${value}"
                    }
                    append result "<s [join $attrs_list " "]>$before_text</s>"
                }
            }
            
            # Process existing tag
            set existing_attrs_string [string range $text $attr_start $attr_end]
            set content [string range $text $content_start $content_end]
            
            # Parse existing attributes
            set existing_attrs {}
            foreach attr [split $existing_attrs_string] {
                set attr [string trim $attr]
                if {$attr eq ""} continue
                
                if {[regexp {^([^=]+)=(.+)$} $attr -> key value]} {
                    dict set existing_attrs $key $value
                }
            }
            
            # Merge attributes (general first, then existing for priority)
            set merged_attrs $general_attrs
            dict for {key value} $existing_attrs {
                dict set merged_attrs $key $value
            }
            
            # Build merged tag
            set merged_attrs_list {}
            dict for {key value} $merged_attrs {
                lappend merged_attrs_list "${key}=${value}"
            }
            append result "<s [join $merged_attrs_list " "]>$content</s>"
            
            set current_pos [expr {$match_end + 1}]
        } else {
            # No more tags, add remaining text with general style
            set remaining_text [string range $text $current_pos end]
            if {$remaining_text ne ""} {
                set attrs_list {}
                dict for {key value} $general_attrs {
                    lappend attrs_list "${key}=${value}"
                }
                append result "<s [join $attrs_list " "]>$remaining_text</s>"
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
        visible_length [string length $parsed_line] \
    ]
}