# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {}

proc zesty::extendedColorsIsSupported {} {
    # Checks if extended colors are supported on Windows.
    #
    # Returns true if Windows 10 build 16257 or higher, false
    # otherwise.
    set hwkey {HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion}
    if {![catch {registry get $hwkey "CurrentBuild"} val]} {
        return [expr {$val >= 16257}] ; # Windows 10 build 16257
    }

    return false
}

proc zesty::getTermHeight {handle} {
    # Gets terminal height in character rows.
    #
    # handle - console handle (Windows) or "null" for Unix
    #
    # Returns terminal height in rows.
    if {[catch {
        if {[zesty::isWindows] && ($handle ne "null")} {
            set height [zesty::getConsoleHeight $handle]
        } else {
            # Unix/Linux
            set null "2>/dev/null"
            if {![catch {set sttyOut [exec stty size $null]}]} {
                set height [lindex $sttyOut 0]
            } elseif {![catch {exec tput lines $null} height]} {
            } else {
                zesty::throwError "Impossible to find height for systems Unix/Linux"
            }
        }
    } msg]} {
        zesty::throwError $msg
    }

    return $height
}

proc zesty::getTermWidth {handle} {
    # Gets terminal width in character columns.
    #
    # handle - console handle (Windows) or "null" for Unix
    #
    # Returns terminal width in columns.
    if {[catch {
        if {[zesty::isWindows] && ($handle ne "null")} {
            set width [zesty::getConsoleWidth $handle]
        } else {
            # Unix/Linux
            set null "2>/dev/null"
            if {![catch {set sttyOut [exec stty size $null]}]} {
                set width [lindex $sttyOut 1]
            } elseif {![catch {exec tput cols $null} width]} {
            } else {
                zesty::throwError "Impossible to find width for systems Unix/Linux"
            }
        }
    } msg]} {
        zesty::throwError $msg
    }
            
    return $width
}

proc zesty::getTerminalSize {{handle "null"}} {
    # Gets terminal dimensions as width and height.
    #
    # handle - console handle (optional, defaults to "null")
    #
    # Returns list containing terminal width and height in
    # characters.
    if {[zesty::isWindows] && ($handle eq "null")} {
        set handle [zesty::GetStdOutHandle]   
    }
    return [list \
        [zesty::getTermWidth $handle] \
        [zesty::getTermHeight $handle] \
    ]
}

proc zesty::getCursorPosition {handle} {
    # Gets current cursor position in the terminal.
    # Uses Windows console API or Unix ANSI escape sequences.
    #
    # handle - console handle (Windows) or "null" for Unix
    #
    # Returns list containing X and Y coordinates of cursor.

    if {[zesty::isWindows]} {
        if {$handle eq "null"} {
            zesty::throwError "Windows console 'handle' not available."
        }

        return [zesty::getConsoleCursorPosition $handle]
        
    } else {
        set old_tty_settings ""
        if {[catch {set old_tty_settings [exec stty -g <@stdin]} msg]} {
            zesty::throwError "Could not get terminal settings: $msg"
        }
        # Unix
        try {
            exec stty raw -echo <@stdin
            puts -nonewline "\033\[6n"
            flush stdout
            
            set response ""
            set char ""
            while {$char ne "R"} {
                set char [read stdin 1]
                append response $char
            }
            
            if {[regexp {\[(\d+);(\d+)R} $response -> y x]} {
                return [list $x $y]
            } else {
                zesty::throwError "Could not parse cursor position response: $response"
            }
        } finally {
            if {$old_tty_settings ne ""} {
                exec stty $old_tty_settings <@stdin
            }
        }
    }
}

proc ::oo::Helpers::classvar {name} {
    # Links caller's locals to class variables.
    # source : https://wiki.tcl-lang.org/page/TclOO+Tricks
    #
    # name - variable name
    #
    # Returns nothing.
    set ns [uplevel 1 {my getONSClass}]
    set vs [list $name $name]

    tailcall namespace upvar $ns {*}$vs

    return {}
}

proc zesty::isWindows {} {
    # Checks if running on Windows platform.
    #
    # Returns true if platform is Windows, false otherwise.
    return [expr {$::tcl_platform(platform) eq "windows"}]
}

proc zesty::run {delay current end body} {
    # Asynchronous loop runner.
    # Runs the loop with given parameters.
    #
    # delay   - delay between iterations
    # current - current value
    # end     - ending value (exclusive)
    # body    - loop body code to executed
    #
    # Returns nothing.

    if {$current >= $end} {
        set ::$::token 1
        return
    }

    # Execute the loop body
    uplevel #0 $body
    incr current

    after $delay [list zesty::run $delay $current $end $body]
}


proc zesty::loop {args} {
    # Creates an asynchronous loop with specified parameters.
    #
    # args - variable arguments supporting:
    #   -delay {milliseconds} - delay between iterations
    #   -start {number}       - starting value
    #   -end {number}         - ending value (exclusive)
    #   body                  - loop body code to execute
    #
    # Returns nothing.
    set delay 1000
    set start 0
    set end 100
    set body [lindex $args end]
    set args [lrange $args 0 end-1]
    
    # Extract body (last argument)
    if {$body eq ""} {
        zesty::throwError "No loop body provided"
    }
    # Validate arguments
    zesty::validateKeyValuePairs "args" $args
    
    foreach {key value} $args {
        switch -exact -- $key {
            -delay  {set delay $value}
            -start  {set start $value}
            -end    {set end $value}
            default {zesty::throwError "'$key' non supporté"}
        }
    }
    
    set resolved_body [uplevel 1 [list subst $body]]
    
    set token "zesty::loop[clock milliseconds][expr {int(rand() * 10000)}]"
    set ::${token} 0
    set coro_name "::loop[clock milliseconds]_[expr {int(rand() * 10000)}]"
    
    coroutine $coro_name apply {{start end delay resolved_body token coro_name} {
        for {set i $start} {$i < $end} {incr i} {
            if {[catch {eval $resolved_body} err]} {
                zesty::throwError "$err"
            }
            after $delay [list $coro_name]
            yield
        }
        set ::${token} 1
    }} $start $end $delay $resolved_body $token $coro_name
    
    vwait ::${token}
    
    if {[info commands $coro_name] ne ""} {
        rename $coro_name ""
    }
}

proc zesty::findColorByHex {hex_pattern} {
    # Searches for colors matching hexadecimal pattern.
    #
    # hex_pattern - hex color pattern to search for
    #
    # Returns list of matches, each containing color name, code,
    # and hex value.
    variable tcolor

    set matches {}
    set pattern_lower [string tolower $hex_pattern]
    
    # Remove # if present for search
    set pattern_clean [string trimleft $pattern_lower "#"]
    
    if {[info exists tcolor]} {
        dict for {code color_info} $tcolor {
            if {[dict exists $color_info hex]} {
                set hex_value [dict get $color_info hex]
                set hex_clean [string trimleft [string tolower $hex_value] "#"]
                
                if {[string match "*${pattern_clean}*" $hex_clean]} {
                    set color_name [dict get $color_info name]
                    lappend matches [list $color_name $code $hex_value]
                }
            }
        }
    }
    
    return $matches
}

proc zesty::colorInfo {color_name} {
    # Displays detailed information about a color.
    #
    # color_name - name or code of color to examine
    #
    # Returns nothing.
    variable tcolor
    set code [zesty::getColorCode $color_name]
    
    if {$code ne ""} {
        set exact_name [zesty::getColorName $color_name]
        set hex_value [zesty::getColorHex $color_name]
        
        if {[info exists tcolor] && [dict exists $tcolor $code]} {
            set color_info [dict get $tcolor $code]
            set name [dict get $color_info name]
            set hex [dict get $color_info hex]
            
            puts "Information for '$color_name' :"
            puts "  ANSI Code: $code"
            puts "  Official name: $name"
            puts "  Hex value: $hex"
            zesty::echo "  Preview: Sample text" -style [list fg $exact_name]
            zesty::echo "  Palette: \u2588\u2588\u2588"  -style [list fg $exact_name]
        } else {
            puts "Color code for '$color_name': $code"
            if {$hex_value ne ""} {
                puts "  Hex value: $hex_value"
            }
            zesty::echo "Preview: Sample text" -style [list fg $color_name]
        }
    } else {
        puts "Color '$color_name' not found"
        
        # If it's potentially a hex value, give suggestions
        if {[zesty::isValidHex]} {
            puts "Suggestion: Check that the hexadecimal value is correct"
            puts "Expected format: #ff0000 or ff0000"
        }
    }
    
    return {}
}

proc zesty::listColors {} {
    # Lists all available colors with their information.
    #
    # Returns nothing.
    variable tcolor
    
    foreach key [dict keys $tcolor] {
        zesty::colorInfo $key
    }
}

proc zesty::findColorByName {pattern} {
    # Searches for colors by name pattern.
    # Performs case-insensitive pattern matching in tcolor
    # dictionary.
    #
    # pattern - pattern to search for in color names
    #
    # Returns list of matches, each containing color name and code.

    variable tcolor

    set matches {}
    set pattern_lower [string tolower $pattern]
    
    # Search in original zesty::tcolor dictionary
    if {[info exists tcolor]} {
        dict for {code color_info} $tcolor {
            if {[dict exists $color_info name]} {
                set color_name [dict get $color_info name]
                set color_lower [string tolower $color_name]
                
                if {[string match "*${pattern_lower}*" $color_lower]} {
                    lappend matches [list $color_name $code]
                }
            }
        }
    }
    
    return $matches
}

proc zesty::rgbToHex {r g b} {
    # Converts RGB values to hexadecimal color format.
    #
    # r - red component   (0-255)
    # g - green component (0-255)
    # b - blue component  (0-255)
    #
    # Returns hexadecimal color string in format #rrggbb.
    return [format "#%02x%02x%02x" $r $g $b]
}

proc zesty::hexToRGB {hex} {
    # Converts hexadecimal color to RGB components.
    #
    # hex - hexadecimal color string (#rrggbb or rrggbb)
    #
    # Returns list containing red, green, and blue values (0-255)
    # or throws error if hex format is invalid.

    if {![zesty::isValidHex $hex]} {
        zesty::throwError "Invalid hex format: $hex"
    }

    # Remove # if present
    set hex_clean [string trimleft $hex "#"]
    
    # Extract components
    set r [expr 0x[string range $hex_clean 0 1]]
    set g [expr 0x[string range $hex_clean 2 3]]
    set b [expr 0x[string range $hex_clean 4 5]]
    
    return [list $r $g $b]
}

proc zesty::rgbToLab {r g b} {
    # Converts RGB to Lab color space (simplified approximation).
    # A distance function based on CIEDE2000 color difference formula
    # Source : https://hajim.rochester.edu/ece/sites/gsharma/ciede2000/
    #
    # r - red component   (0-255)
    # g - green component (0-255)
    # b - blue component  (0-255)
    #
    # Returns list containing L, a, and b components in Lab color

    set r [expr {$r / 255.0}]
    set g [expr {$g / 255.0}]
    set b [expr {$b / 255.0}]
    
    # Gamma correction (approximation)
    if {$r > 0.04045} {
        set r [expr {pow(($r + 0.055) / 1.055, 2.4)}]
    } else {
        set r [expr {$r / 12.92}]
    }
    if {$g > 0.04045} {
        set g [expr {pow(($g + 0.055) / 1.055, 2.4)}]
    } else {
        set g [expr {$g / 12.92}]
    }
    if {$b > 0.04045} {
        set b [expr {pow(($b + 0.055) / 1.055, 2.4)}]
    } else {
        set b [expr {$b / 12.92}]
    }
    
    # XYZ conversion (D65)
    set x [expr {$r * 0.4124564 + $g * 0.3575761 + $b * 0.1804375}]
    set y [expr {$r * 0.2126729 + $g * 0.7151522 + $b * 0.0721750}]
    set z [expr {$r * 0.0193339 + $g * 0.1191920 + $b * 0.9503041}]
    
    # XYZ normalization
    set xn 0.95047
    set yn 1.0
    set zn 1.08883
    
    set fx [expr {$x / $xn}]
    set fy [expr {$y / $yn}]
    set fz [expr {$z / $zn}]
    
    # Function f(t)
    if {$fx > 0.008856} {
        set fx [expr {pow($fx, 1.0/3.0)}]
    } else {
        set fx [expr {(7.787 * $fx) + (16.0/116.0)}]
    }
    if {$fy > 0.008856} {
        set fy [expr {pow($fy, 1.0/3.0)}]
    } else {
        set fy [expr {(7.787 * $fy) + (16.0/116.0)}]
    }
    if {$fz > 0.008856} {
        set fz [expr {pow($fz, 1.0/3.0)}]
    } else {
        set fz [expr {(7.787 * $fz) + (16.0/116.0)}]
    }
    
    # Lab calculation
    set L [expr {(116.0 * $fy) - 16.0}]
    set a [expr {500.0 * ($fx - $fy)}]
    set b [expr {200.0 * ($fy - $fz)}]
    
    return [list $L $a $b]
}

proc zesty::colorDistanceLab {hex1 hex2} {
    # Calculates Delta E distance between two colors in Lab space.
    #
    # hex1 - first hexadecimal color
    # hex2 - second hexadecimal color
    #
    # Returns Delta E distance (lower values = more similar colors)
    # or -1 if conversion fails
    set rgb1 [zesty::hexToRGB $hex1]
    set rgb2 [zesty::hexToRGB $hex2]
    
    if {([llength $rgb1] == 0) || ([llength $rgb2] == 0)} {
        return -1
    }
    
    set lab1 [zesty::rgbToLab {*}$rgb1]
    set lab2 [zesty::rgbToLab {*}$rgb2]
    
    set L1 [lindex $lab1 0]
    set a1 [lindex $lab1 1]
    set b1 [lindex $lab1 2]
    
    set L2 [lindex $lab2 0]
    set a2 [lindex $lab2 1]
    set b2 [lindex $lab2 2]
    
    set dL [expr {$L1 - $L2}]
    set da [expr {$a1 - $a2}]
    set db [expr {$b1 - $b2}]
    
    return [expr {sqrt($dL*$dL + $da*$da + $db*$db)}]
}

proc zesty::findClosestColor {target_hex} {
    # Finds the closest color to target hex in available palette.
    #
    # target_hex - target hexadecimal color to match
    #
    # Returns list containing closest color code, name, hex value,
    # and distance, or empty list if no colors available.
    variable tcolor

    if {![info exists tcolor]} {
        zesty::throwError "zesty::tcolor not available"
    }
    
    set target_rgb [zesty::hexToRGB $target_hex]
    
    set min_distance -1
    set closest_color {}
    set closest_info {}
    
    # Browse all colors in dictionary
    dict for {code color_info} $tcolor {
        if {[dict exists $color_info hex]} {
            set hex_value [dict get $color_info hex]

            set distance [zesty::colorDistanceLab $target_hex $hex_value]
 
            if {$distance >= 0 && ($min_distance < 0 || $distance < $min_distance)} {
                set min_distance $distance
                set closest_color $code
                set closest_info $color_info
            }
        }
    }
    
    if {$closest_color ne ""} {
        set name [dict get $closest_info name]
        set hex [dict get $closest_info hex]
        return [list $closest_color $name $hex $min_distance]
    }
    
    return {}
}

proc zesty::gradient {text start_color end_color} {
    # Creates a color gradient effect across text characters.
    #
    # text        - text to apply gradient to
    # start_color - starting color of gradient
    # end_color   - ending color of gradient
    #
    # Returns styled text with gradient effect where each character
    # transitions from start_color to end_color.

    set sc [zesty::getColorCode $start_color]
    set ec [zesty::getColorCode $end_color]

    set len [string length $text]
    if {$len <= 1} {
        return [zesty::parseStyleDictToXML $text [list fg $sc]]
    }
    
    set result ""
    for {set i 0} {$i < $len} {incr i} {
        set ratio [expr {double($i) / ($len - 1)}]
        set current_color [zesty::blendColors $sc $ec $ratio]
        set char [string index $text $i]
        append result [zesty::parseStyleDictToXML $char [list fg $current_color]]
    }
    return $result
}

proc zesty::blendColors {color1 color2 {ratio 0.5}} {
    # Blends two colors according to specified ratio.
    # Performs RGB interpolation and finds nearest match.
    #
    # color1 - first color (code or name)
    # color2 - second color (code or name)
    # ratio  - blend ratio (0.0 = all color1, 1.0 = all color2)
    #
    # Returns color code of closest available color to the blend
    # result.
    if {$ratio < 0.0} {
        set ratio 0.0
    } elseif {$ratio > 1.0} {
        set ratio 1.0
    }

    # Convert color codes to hexadecimal
    set hex1 [zesty::getColorHex $color1]
    set hex2 [zesty::getColorHex $color2]

    # Convert to RGB
    lassign [zesty::hexToRGB $hex1] r1 g1 b1
    lassign [zesty::hexToRGB $hex2] r2 g2 b2
    
    # Calculate blend: color1 * (1-ratio) + color2 * ratio
    set r_blend [expr {int($r1 * (1.0 - $ratio) + $r2 * $ratio)}]
    set g_blend [expr {int($g1 * (1.0 - $ratio) + $g2 * $ratio)}]
    set b_blend [expr {int($b1 * (1.0 - $ratio) + $b2 * $ratio)}]
    
    # Ensure values are in 0-255 range
    set r_blend [expr {max(0, min(255, $r_blend))}]
    set g_blend [expr {max(0, min(255, $g_blend))}]
    set b_blend [expr {max(0, min(255, $b_blend))}]
    
    # Convert to hex
    set hex_blend [zesty::rgbToHex $r_blend $g_blend $b_blend]
    
    # Find closest color in available palette
    return [lindex [zesty::findClosestColor $hex_blend] 0]
}

proc zesty::getColorHex {color} {
    # Gets hexadecimal value of a color.
    #
    # color - color name or code
    #
    # Returns hexadecimal color value if found, empty string
    # otherwise.
    variable tcolor

    # Check if zesty::tcolor exists
    if {![info exists tcolor]} {
        zesty::throwError "Warning: zesty::tcolor not found."
    }

    set code [zesty::getColorCode $color]
    
    if {($code ne "") && [dict exists $tcolor $code]} {
        set color_info [dict get $tcolor $code]
        if {[dict exists $color_info hex]} {
            return [dict get $color_info hex]
        }
    }
    
    return {}
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
            set before_text [string range $styled_text $current_pos [expr {$match_start - 1}]]
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
                set truncated_content [string range $content 0 [expr {$remaining_space - 1}]]
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
        if {[regexp $pattern $line]} {
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
        if {[regexp $pattern $line] && ($i > 0)} {
            return $i
        }
    }
    
    return -1
}

proc zesty::isValidHex {hex} {
    # Checks if a string is a valid hexadecimal color.
    #
    # hex - string to validate as hex color
    #
    # Returns true if string is valid 6-character hexadecimal
    # color (with or without # prefix), false otherwise.

    set hex_clean [string trimleft $hex "#"]
    
    # Check that it's exactly 6 hexadecimal characters
    return [regexp {^[0-9a-fA-F]{6}$} $hex_clean]
}

proc zesty::resetTerminal {} {
    # Sends ANSI escape sequences to clear
    # screen and position cursor at top-left corner.
    #
    # Returns nothing. 
    puts -nonewline "\033\[2J\033\[H"
    flush stdout
}

proc zesty::hideCursor {} {
    # Sends ANSI escape sequences to hide cursor.
    #
    # Returns nothing. 
    puts -nonewline "\033\[?25l"
    flush stdout
}

proc zesty::showCursor {} {
    # Sends ANSI escape sequences to show cursor.
    #
    # Returns nothing. 
    puts -nonewline "\033\[?25h"
    flush stdout
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


proc zesty::throwError {msg} {
    # Throws an error.
    #
    # msg - error message
    #
    # Returns error message. 

    zesty::resetTerminal
    zesty::showCursor

    return -code error "zesty(error): $msg"
}

proc zesty::validateKeyValuePairs {key value} {
    # Checks if arguments are in key-value pairs.
    #
    # key   - key name.
    # value - list of arguments.
    #
    # Returns nothing or an error message if invalid.

    if {[llength $value] % 2} {
        set msg "wrong # args: '$key' must be in key-value pairs."
        return -level [info level] -code error $msg
    }
}

proc zesty::isPositiveIntegerValue {key value {limit 0}} {
    # Checks if key value is a positive integer.
    #
    # key   - key name.
    # value - integer value.
    # limit - minimum value
    #
    # Returns nothing or an error message if invalid.

    if {![string is integer -strict $value] || ($value < $limit)} {
        if {$limit > 0} {
            zesty::throwError "'$key' must be greater than $limit."
        } else {
            zesty::throwError "'$key' must be a positive integer."
        }
    }
}

proc zesty::isBooleanValue {key value} {
    # Checks if key value is boolean value.
    #
    # key   - key name.
    # value - integer value.
    #
    # Returns nothing or an error message if invalid.

    if {![string is boolean -strict $value]} {
        zesty::throwError "'$key' must be a boolean value."
    }
}