# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {
    namespace export echo
}

proc zesty::initStyles {} {
    # Initializes the color and style dictionaries from zesty::tcolor.
    # This procedure builds internal dictionaries for color lookup by name,
    # hex value, and normalizes color names for case-insensitive searching.
    # Also handles Windows compatibility for extended colors.
    #
    # Populates module variables :
    # - colors_dict:       normalized name -> color code mapping.
    # - color_names_dict:  normalized name -> original name mapping.
    # - hex_dict:          hex value -> color code mapping.
    # - termstyles:        terminal style codes dictionary.
    # - boxstyles:         box style codes dictionary.
    # - tablestyles:       table style codes dictionary.
    # - spinnerstyles:     spinner style codes dictionary.
    # - titleAnchor:       title anchor list.
    #
    # Returns: nothing

    variable colors_dict
    variable color_names_dict
    variable hex_dict 
    variable termstyles
    variable tcolor
    variable boxstyles
    variable titleAnchor
    variable tablestyles
    variable spinnerstyles

    # Check if zesty::tcolor exists
    if {![info exists tcolor]} {
        zesty::throwError "zesty::tcolor not found."
    }

    set termstyles {
        reset 0 bold 1 dim 2 italic 3
        underline 4 blink 5
        reverse 7 strikethrough 9
    }

    if {[zesty::isWindows] && ![zesty::extendedColorsIsSupported]} {
        for {set i 16} {$i < 256} {incr i} {lappend lnum $i}
        # Delete all colors not supported from tcolor dictionary.
        set tcolor [dict remove $tcolor {*}$lnum]
    }
    
    set colors_dict {}
    set color_names_dict {}
    set hex_dict {}
    
    # Browse through the zesty::tcolor dictionary
    dict for {code color_info} $tcolor {
        set color_name [dict get $color_info name]
        set hex_value  [dict get $color_info hex]
        
        # Create search key (lowercase, no spaces/dashes)
        set map {" " "" "_" "" "-" ""}
        set search_key [string tolower [string map $map $color_name]]

        if {[dict exists colors_dict $search_key]} {
            zesty::throwError "Color '$color_name' ($code) is duplicate\
                               of '[dict get $color_names_dict $search_key]'\
                               ([dict get $colors_dict $search_key])"
        }
        
        # Store code with search key
        dict set colors_dict $search_key $code
        
        # Store exact name for display
        dict set color_names_dict $search_key $color_name
        
        # Store also by hex value (without the #)
        set hex_clean [string trimleft $hex_value "#"]
        dict set hex_dict [string tolower $hex_clean] $code

        # Store also with # for search
        dict set hex_dict [string tolower $hex_value] $code
    }

    # Box styles dictionary
    set boxstyles {
        single  {┌ ┐ └ ┘ │ ─}
        double  {╔ ╗ ╚ ╝ ║ ═}
        rounded {╭ ╮ ╰ ╯ │ ─}
        thick   {┏ ┓ ┗ ┛ ┃ ━}
        ascii   {+ + + + | -}
    }

    # Title anchors
    set titleAnchor {
        ne nc nw
        sw sc se
        en ec es
        wn wc ws
    }

    # Table styles
    set tablestyles {
        single  {┌ ┐ └ ┘ │ ─ ┼ ┬ ┴ ├ ┤}
        double  {╔ ╗ ╚ ╝ ║ ═ ╬ ╦ ╩ ╠ ╣}
        rounded {╭ ╮ ╰ ╯ │ ─ ┼ ┬ ┴ ├ ┤}
        thick   {┏ ┓ ┗ ┛ ┃ ━ ┃ ┳ ┻ ┣ ┫}
        ascii   {+ + + + | - + + + + +}
    }

    # Spinner styles
    set spinnerstyles {
        dots   {⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏}
        line   {| / - \\}
        circle {◐ ◓ ◑ ◒}
        emoji  {😂 😭 😌}
        arrows {← ↖ ↑ ↗ → ↘ ↓ ↙}
        bars   {▁ ▃ ▄ ▅ ▆ ▇ █ ▇ ▆ ▅ ▄ ▃}
        moon   {🌑 🌒 🌓 🌔 🌕 🌖 🌗 🌘}
    }

}

proc zesty::getColorName {color} {
    # Gets the exact name of a color from various input formats.
    #
    # color - color specification (name, number, or hex value)
    #
    # Returns: the exact color name if found, or the original input
    # if no matching color name exists.
    variable color_names_dict
    
    # If it's a number, search for corresponding name
    if {[string is integer $color]} {
        dict for {key name} $color_names_dict {
            if {[zesty::getColorCode $name] eq $color} {
                return $name
            }
        }
        return $color
    }
    
    # If it's a hex value, search for corresponding name
    if {[zesty::isValidHex $color]} {
        set code [zesty::getColorCode $color]
        if {$code ne ""} {
            return [zesty::getColorName $code]
        }
        return $color
    }

    set map {" " "" "_" "" "-" ""}
    set search_key [string tolower [string map $map $color]]
    
    if {[dict exists $color_names_dict $search_key]} {
        return [dict get $color_names_dict $search_key]
    }
    
    return $color
}

proc zesty::getColorCode {color {find_closest 1}} {
    # Gets the color code from various input formats with optional
    # closest match.
    #
    # color        - color specification (name, number, or hex value)
    # find_closest - whether to find closest color for unmatched hex
    #                values (default: 1)
    #
    # Returns: the color code (0-255) if found, empty string otherwise.
    variable colors_dict 
    variable hex_dict
    
    # If it's already a number, return it directly
    if {
        [string is integer $color] && 
        ($color >= 0 && $color <= 255)
    } {
        return $color
    }
    
    # Check if it's a hexadecimal value
    if {[zesty::isValidHex $color]} {
        set hex_key [string tolower $color]
        if {[dict exists $hex_dict $hex_key]} {
            return [dict get $hex_dict $hex_key]
        }
        
        # Try with/without # depending on the case
        if {[string match "#*" $color]} {
            set hex_without_hash [string trimleft $hex_key "#"]
            if {[dict exists $hex_dict $hex_without_hash]} {
                return [dict get $hex_dict $hex_without_hash]
            }
        } else {
            set hex_with_hash "#$hex_key"
            if {[dict exists $hex_dict $hex_with_hash]} {
                return [dict get $hex_dict $hex_with_hash]
            }
        }
        
        # If not found and find_closest enabled, search for closest color
        if {$find_closest} {
            set closest [zesty::findClosestColor $color]
            if {[llength $closest] > 0} {
                return [lindex $closest 0]
            }
        }
    }

    set map {" " "" "_" "" "-" ""}
    set search_key [string tolower [string map $map $color]]
    
    if {[dict exists $colors_dict $search_key]} {
        return [dict get $colors_dict $search_key]
    }
    
    return {}
}

proc zesty::styleANSICode {name} {
    # Generates ANSI escape code for terminal styling.
    #
    # name - style name (reset, bold, dim, italic, underline, blink,
    #        reverse, strikethrough)
    #
    # Returns: the ANSI escape sequence for the specified style.
    variable termstyles
    
    return "\033\[[dict get $termstyles $name]m"
}

proc zesty::colorANSICode {color_code {bg 0}} {
    # Generates ANSI escape code for terminal colors.
    #
    # color_code - numeric color code (0-255)
    # bg         - whether to apply as background color (default: 0)
    #
    # Returns: the ANSI escape sequence for the specified color,
    # empty string if color_code is empty.

    if {$color_code ne ""} {
        if {$bg} {
            return "\033\[48;5;${color_code}m"
        } else {
            return "\033\[38;5;${color_code}m"
        }
    }

    return {}
}

proc zesty::echo {args} {
    # Main function for styled text output with color and formatting
    # support.
    #
    # args - variable arguments supporting:
    #   -style {key value ...}  - style specifications
    #   -filters {filter_list}  - text filters to apply
    #   -command {command}      - command to execute
    #   -n                      - suppress newline
    #   -noreset                - don't reset formatting at end
    #   text...                 - text content to display
    #
    # Returns: nothing, outputs formatted text to stdout.
    set text ""
    set styleList {}
    set filters {}
    set addNewline 1
    set noReset 0
    set command {}

    for {set i 0} {$i < [llength $args]} {incr i} {
        set arg [lindex $args $i]
        switch -- $arg {
            "-style" {
                incr i
                if {$i < [llength $args]} {
                    set styleList [lindex $args $i]
                }
            }
            "-filters" {
                incr i
                if {$i < [llength $args]} {
                    set filters [lindex $args $i]
                }
            }
            "-command" {
                incr i
                if {$i < [llength $args]} {
                    set command [lindex $args $i]
                }
            }
            "-n"       {set addNewline 0}
            "-noreset" {set noReset 1}
            default {
                append text $arg
                if {$i < [llength $args] - 1} {
                    append text " "
                }
            }
        }
    }
    
    # Mode with base style + inline tags
    if {[llength $styleList] > 0} {
        # Check if arguments are in key-value pairs
        zesty::validateKeyValuePairs "-style" $styleList
    }

    set output [zesty::parseStyle \
        $text $styleList \
        $noReset $filters \
        $command 
    ]
    
    # Display output
    if {$addNewline} {
        puts stdout $output
    } else {
        puts -nonewline stdout $output
    }
}

# Initialize styles.
zesty::initStyles