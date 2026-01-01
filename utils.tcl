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
            set height [zesty::win32::getConsoleHeight $handle]
        } else {
            # Unix/Linux
            set null "2>/dev/null"
            if {![catch {set sttyOut [exec stty size $null]}]} {
                set height [lindex $sttyOut 0]
            } elseif {![catch {exec tput lines $null} height]} {
            } else {
                error "zesty(error): Impossible to find the terminal\ 
                    height for systems Unix/Linux"
            }
        }
    } msg]} {
        error "zesty(error): $msg"
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
            set width [zesty::win32::getConsoleWidth $handle]
        } else {
            # Unix/Linux
            set null "2>/dev/null"
            if {![catch {set sttyOut [exec stty size $null]}]} {
                set width [lindex $sttyOut 1]
            } elseif {![catch {exec tput cols $null} width]} {
            } else {
                error "zesty(error): Impossible to find the terminal\ 
                    width for systems Unix/Linux"
            }
        }
    } msg]} {
        error "zesty(error): $msg"
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
        set handle [zesty::win32::getStdOutHandle]   
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

        return [zesty::win32::getConsoleCursorPosition $handle]
        
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
                zesty::throwError "Could not parse cursor position\
                    response: $response"
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
        error "zesty(error): Invalid hex format: $hex"
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
        error "zesty(error): No 'zesty::tcolor' variable\
            available."
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

    # Split text into characters to works with Tcl 8.6
    # instead to use string index command.
    set chars [split $text ""]

    set len [llength $chars]
    if {$len <= 1} {
        return [zesty::parseStyleDictToXML $text [list fg $sc]]
    }
    
    set result ""
    for {set i 0} {$i < $len} {incr i} {
        set ratio [expr {double($i) / ($len - 1)}]
        set current_color [zesty::blendColors $sc $ec $ratio]
        set char [lindex $chars $i]
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
        error "zesty(error): No 'zesty::tcolor' variable\
            available."
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

proc zesty::SetTerminalTitle {text} {
    # Sets terminal title.
    #
    # text - terminal title
    #
    # Returns nothing.
    if {[zesty::isWindows]} {
        zesty::win32::setTitle $text
    } else {
        puts -nonewline "\033]0;$text\007"
        flush stdout
    }
}

proc zesty::setTerminalTitle {text} {
    # See zesty::SetTerminalTitle proc for details.
    zesty::SetTerminalTitle $text
} 

proc zesty::showCursor {} {
    # Sends ANSI escape sequences to show cursor.
    #
    # Returns nothing. 
    puts -nonewline "\033\[?25h"
    flush stdout
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
            error "zesty(error): '$key' must be greater than $limit."
        } else {
            error "zesty(error): '$key' must be a positive integer."
        }
    }
}

proc zesty::isListOfList {args} {
    # Checks if the 'value' is of type list of list.
    #
    # args - list
    #
    # Returns true if value is a list of list,
    # false otherwise.

    # Cleans up the list of braces, spaces.
    regsub -all -line {(^\s+)|(\s+$)|\n|\t} $args {} str

    return [expr {
            [string range $str 0 1] eq "\{\{" &&
            [string range $str end-1 end] eq "\}\}"
        }
    ]
}

proc zesty::findWithBounds {lines start_index} {
    # Finds the start and end indices of a block of lines with
    # matching brace characters.
    #
    # lines - list of lines to search in.
    # start_index - index of the line to start searching from.
    #
    # Returns a list of three elements
    set start_idx -1
    set end_idx -1

    for {set i $start_index} {$i < [llength $lines]} {incr i} {
        if {[string first "\{" [lindex $lines $i]] >= 0} {
            set start_idx [expr {$i + 1}]
            break
        }
    }

    if {$start_idx >= 0} {
        set buffer [lindex $lines $start_index]
        set j $start_index
        
        while {![info complete $buffer] && $j < [llength $lines] - 1} {
            incr j
            append buffer " [lindex $lines $j]"
        }

        set end_idx [expr {$j - 1}]
        return [list $start_idx $end_idx [expr {$j + 1}]]
    }
    
    return {-1 -1 -1}
}

proc zesty::def {d key args} {
    # Set dict definition with value type and default value.
    # An error exception is raised if args value is not found.
    #
    # d - dict
    # key - dict key
    # args - type, default, validvalue.
    #
    # Returns dictionary
    upvar 1 $d _dict

    foreach {k value} $args {
        switch -exact -- $k {
            -validvalue {set validvalue $value}
            -type {set type $value}
            -default {set default $value}
            -with {
                set temp_dict {}
                set lines {}
                foreach line [split $value "\n"] {
                    set line [string trim $line]
                    if {[string length $line] > 0} {
                        lappend lines $line
                    }
                }
                set j 0
                
                while {$j < [llength $lines]} {
                    set line [lindex $lines $j]
                    
                    if {$line eq "\}"} {incr j; continue}

                    if {[string match {*-with*} $line]} {
                        set lsplit [split $line]
                        set lkey   [lindex $lsplit 0]
                        set ltype  [lsearch $lsplit *-type*]
                        set lvalid [lsearch $lsplit *-validvalue*]
                        if {$ltype  < 0} {
                            error "zesty(error): Missing 'type' for '$lkey'"
                        }
                        if {$lvalid < 0} {
                            error "zesty(error): Missing 'validvalue' for '$lkey'"
                        }
                        lassign [zesty::findWithBounds $lines $j] start_idx end_idx next_j
                        
                        if {($start_idx >= 0) && ($end_idx >= 0)} {
                            set d_temp {}
                            set ltype  [lindex $lsplit $ltype+1]
                            set lvalid [lindex $lsplit $lvalid+1]
                            set sub_content [join [lrange $lines $start_idx $end_idx] "\n"]
                            zesty::def d_temp "temp" -validvalue $lvalid -type $ltype -with $sub_content
                            set processed_content [lindex [dict get $d_temp "temp"] 0]
                            dict set temp_dict $lkey [list $processed_content $ltype $lvalid]
                            set j $next_j
                        } else {
                            incr j
                        }
                    } else {
                        # simple line
                        zesty::def temp_dict {*}$line
                        incr j
                    }
                }
                set default $temp_dict
            }
            default {error "zesty(error): Unknown key '$k' specified"}
        }
    }
    
    dict set _dict $key [list $default $type $validvalue]
}

proc zesty::getBaseDict {type_dict {prefix ""}} {
    # Recursively extracts a flattened dictionary of keys with their default
    # values, types, and valid values from a nested type dictionary.
    #
    # type_dict - nested dictionary containing type definitions
    # prefix    - string to prepend to keys for namespacing (optional)
    #
    # Returns: a flattened dictionary with full keys and their definitions
    
    set result_dict {}

    foreach key [dict keys $type_dict] {
        # Construct the full key with prefix if provided
        set full_key [expr {$prefix eq "" ? $key : "$prefix.$key"}]

        # Retrieve the definition of the current key
        set definition    [dict get $type_dict $key]
        set default_value [lindex $definition 0]
        set type          [lindex $definition 1]
        set validvalue    [lindex $definition 2]

        if {$type eq "struct"} {
            zesty::validValue $type $key $validvalue $default_value
            # If the type is a structure, process its sub-keys recursively
            set sub_result [zesty::getBaseDict $default_value $full_key]
            
            # Merge the results of the sub-keys into the result dictionary
            dict for {sub_key sub_info} $sub_result {
                dict set result_dict $sub_key $sub_info
            }
        } else {
            # If it's a final value, add it to the result dictionary
            dict set result_dict $full_key [list value $default_value type $type validvalue $validvalue]
        }
    }

    return $result_dict
}

proc zesty::getUserDict {flat_dict type_dict {prefix ""}} {
    # Recursively extracts a user-provided dictionary of keys with their values,
    # types, and valid values from a nested type dictionary.
    #
    # flat_dict - user-provided dictionary containing key-value pairs
    # type_dict - nested dictionary containing type definitions
    # prefix    - string to prepend to keys for namespacing (optional)
    #
    # Returns: a recursively constructed dictionary with full keys and their
    # definitions

    set result_dict {}
    
    foreach {key value} $flat_dict {
        # Construct the full key with prefix if provided
        set full_key [expr {$prefix eq "" ? $key : "$prefix.$key"}]
        
        # Search for this key directly in the current type dictionary
        if {[dict exists $type_dict $key]} {
            # Retrieve the definition of the current key
            set definition    [dict get $type_dict $key]
            set default_value [lindex $definition 0]
            set type          [lindex $definition 1]
            set validvalue    [lindex $definition 2]
            
            if {$type eq "struct"} {
                zesty::validValue $type $key $validvalue $default_value
                # If the type is a structure, process its sub-keys recursively
                set sub_result [zesty::getUserDict $value $default_value $full_key]
                # Merge the results of the sub-keys into the result dictionary
                dict for {sub_key sub_info} $sub_result {
                    dict set result_dict $sub_key $sub_info
                }
            } else {
                # If it's a final value, add it to the result dictionary
                dict set result_dict $full_key [list value $value type $type validvalue $validvalue]
            }
        } else {
            # If the key doesn't exist in the current type dictionary, add the
            # value with empty type and valid values.
            dict set result_dict $full_key [list value $value type {} validvalue {}]
        }
    }
    
    return $result_dict
}

proc zesty::keyCompare {kd kother} {
    # Output an error message if key name doesn't exist 
    # in key default option.
    #
    # kd     - keys dict (default option(s))
    # kother - keys user
    #
    # Returns nothing
    foreach used_key $kother {
        if {$used_key ni $kd} {
            error "Unknown key '$used_key' specified."
        }
    }
}

proc zesty::typeOf {value} {
    # Guess the type of the value.
    # 
    # value - string
    #
    # Returns type of value

    if {$value eq ""} {
        return none
    }

    if {[string is integer -strict $value]} {
        return num
    }

    if {[info commands $value] ne ""} {
        return cmd
    }

    if {[zesty::isListOfList $value]} {
        return list
    }

    return str
}

proc zesty::matchTypeOf {mytype type keyt} {
    # Guess type, follow optional list.
    # 
    # mytype - type
    # type   - list default type
    # keyt   - upvar key type
    #
    # Returns true if mytype is found, 
    # false otherwise.
    upvar 1 $keyt typekey

    foreach valtype [split $type "|"] {
        if {[string match $mytype $valtype]} {
            set typekey $valtype
            return 1
        }
    }

    if {$type in {"any|none" "any"}} {
        set typekey "any"
        return 1
    }

    return 0
}

proc zesty::merge {d other} {
    # Merge 2 dictionaries and control the type of value.
    # An error exception is raised if type of value doesn't match.
    #
    # d      - dict (default option(s))
    # other  - list values
    #
    # Returns a new dictionary

    zesty::validateKeyValuePairs "args" $other

    set base_dict [zesty::getBaseDict $d]
    set user_dict [zesty::getUserDict $other $d]

    # Compare keys
    zesty::keyCompare [dict keys $base_dict] \
                      [dict keys $user_dict]

    set _dict [dict create]

    dict for {key info} $base_dict {

        if {[dict exists $user_dict $key]} {
            set value [dict get $user_dict $key value]
            set type  [dict get $user_dict $key type]
            set mytype [zesty::typeOf $value]

            # Check type in default list
            if {![zesty::matchTypeOf $mytype $type typekey]} {
                error "type 'set' should be '$type' instead of '$mytype'\
                    for this key '$key'."
            }

            set v_value [dict get $user_dict $key validvalue]

            zesty::validValue $typekey $key $v_value $value

            set clean_key [string trimleft $key "-"]
            dict set _dict {*}[split $clean_key "."] $value
        } else {
            set value [dict get $info value]
            set type  [dict get $info type]
            set mytype [zesty::typeOf $value]

            # Check type in default list
            if {![zesty::matchTypeOf $mytype $type typekey]} {
                error "type 'default' should be '$type' instead of '$mytype'\
                    for this key '$key'."
            }

            set v_value [dict get $base_dict $key validvalue]

            zesty::validValue $typekey $key $v_value $value

            set clean_key [string trimleft $key "-"]
            dict set _dict {*}[split $clean_key "."] $value
        }
    }

    return $_dict
}