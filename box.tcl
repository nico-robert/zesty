# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {}

proc zesty::box {args} {
    # Creates a styled text box with customizable borders, content,
    # and layout options.
    #
    # args - variable arguments supporting:
    #  -padding {number}                   - uniform padding
    #  -paddingX {number}                  - horizontal padding
    #  -paddingY {number}                  - vertical padding
    #  -title {options}                    - title configuration
    #  -content {options}                  - content configuration
    #  -box {options}                      - box appearance settings
    #  -formatCmdBoxMsgtruncated {command} - truncation callback
    #
    # Returns formatted box string with borders, content, and optional
    # title. Supports multiple box styles, content alignment, table
    # mode, and intelligent content truncation.

    zesty::def options "-title" -validvalue formatVKVP -type struct -with {
        name    -validvalue {}                -type any|none  -default ""
        style   -validvalue formatStyle       -type any|none  -default ""
        anchor  -validvalue formatTitleAnchor -type str       -default "nc"
    }
    zesty::def options "-paddingX" -validvalue formatPad -type num  -default 1
    zesty::def options "-paddingY" -validvalue formatPad -type num  -default 0
    zesty::def options "-content" -validvalue formatVKVP -type struct -with {
        text   -validvalue {}           -type any|none   -default ""
        align  -validvalue formatAlign  -type str        -default "left"
        style  -validvalue formatStyle  -type any|none   -default ""
        table  -validvalue formatVKVP   -type struct     -with {
            enabled     -validvalue formatVBool        -type any       -default "false"
            columns     -validvalue formatColums       -type any|none   -default ""
            alignments  -validvalue formatAlignements  -type any|none   -default ""
            separator   -validvalue {}                 -type str|none   -default " "
            styles      -validvalue formatStyles       -type any|none   -default ""
        }
    }
    zesty::def options "-box" -validvalue formatVKVP   -type struct  -with {
        type       -validvalue formatTypeBox  -type str        -default "rounded"
        style      -validvalue formatStyle    -type any|none   -default ""
        size       -validvalue formatSizeBox  -type any|none   -default ""
        fullScreen -validvalue formatVBool    -type any       -default "false"
    }
    zesty::def options "-formatCmdBoxMsgtruncated"  -validvalue {}  -type cmd|none  -default ""

    # Merge options and args
    set options [zesty::merge $options $args]

    set title [dict get $options title name]
    set title_anchor [dict get $options title anchor]
    set title_visible_length 0

    if {$title ne ""} {
        set title_visible_length [zesty::strLength [zesty::extractVisibleText $title]]
        set title_style [dict get $options title style]
        set title [zesty::parseStyleDictToXML $title $title_style]
    }

    # Extract border characters + apply style
    set box_type [dict get $options box type]
    set box_style [dict get $options box style]
    foreach {top_left top_right bottom_left bottom_right vertical horizontal} [dict get $::zesty::boxstyles $box_type] {
        set top_left     [zesty::parseStyleDictToXML $top_left $box_style]
        set top_right    [zesty::parseStyleDictToXML $top_right $box_style]
        set bottom_left  [zesty::parseStyleDictToXML $bottom_left $box_style]
        set bottom_right [zesty::parseStyleDictToXML $bottom_right $box_style]
        set vertical     [zesty::parseStyleDictToXML $vertical $box_style]
        set horizontal   [zesty::parseStyleDictToXML $horizontal $box_style]
    }

    set paddingX [dict get $options paddingX]
    set paddingY [dict get $options paddingY]
    set custom_size [dict get $options box size]
    set fullScreen [dict get $options box fullScreen]
    lassign [zesty::getTerminalSize] terminal_width terminal_height
    
    # Calculate dimensions first to know if content truncation needed
    set box_content_width -1
    if {$fullScreen} {
        # Full screen or normal mode
        set total_width [expr {$terminal_width - 3}]
        set total_height [expr {$terminal_height - 3}]
        set box_content_width [expr {$total_width - 2 * $paddingX}]
        
    } elseif {$custom_size ne ""} {
        # Custom size mode
        lassign $custom_size custom_width custom_height

        if {($custom_width <= 0) || ($custom_width > ($terminal_width - 3))} {
            set total_width [expr {$terminal_width - 3}]
        } else {
            set total_width [expr {$custom_width - 2}]
        }

        if {$custom_height <= 0} {
            set total_height [expr {$terminal_height - 3}]
        }

        set box_content_width [expr {$total_width - 2 * $paddingX}]
    }

    # Calculate content dimensions with truncation if necessary
    set max_length 0
    set processed_lines {}
    set content [dict get $options content text]
    set content_style [dict get $options content style]
    set table_enabled [dict get $options content table enabled]

    if {$table_enabled} {
        # Table mode - process data as table
        set table_columns [dict get $options content table columns]
        set table_separator [dict get $options content table separator]
        set table_styles [dict get $options content table styles]

        # Replace existing call with:
        set processed_lines [zesty::processTableContent \
            $content $table_columns \
            $table_separator $table_styles \
            $content_style $box_content_width \
            $options \
        ]
        
        # Calculate maximum width
        foreach line_info $processed_lines {
            set visible_length [dict get $line_info visible_length]
            if {$visible_length > $max_length} {
                set max_length $visible_length
            }
        }
    } else {
        # Normal mode - line by line processing
        foreach line [split $content "\n"] {
            set line [zesty::parseStyleDictToXML $line $content_style]

            if {$box_content_width > 0} {
                set wrapped_lines [zesty::wrapText $line $box_content_width 1]
                set line [lindex $wrapped_lines 0]
            }
            
            set line_info [zesty::parseContentLine $line]
            set visible_length [dict get $line_info visible_length]

            if {$visible_length > $max_length} {
                set max_length $visible_length
            }
            # Store line information
            lappend processed_lines $line_info
        }
    }
    
    # Variable to track removed lines
    set lines_removed 0
    
    # Calculate dimensions according to different modes
    if {$fullScreen} {
        # Available height = total height - borders (2) - padding lines (2 * paddingY)
        set available_content_height [expr {$total_height - 2 - 2 * $paddingY}]
        
        # Add empty lines if necessary or truncate intelligently
        set content_lines_count [llength $processed_lines]
        if {$content_lines_count < $available_content_height} {
            set lines_to_add [expr {$available_content_height - $content_lines_count}]
            for {set i 0} {$i < $lines_to_add} {incr i} {
                set empty_line_info [dict create visible_length 0 original_line ""]
                lappend processed_lines $empty_line_info
            }
        } elseif {$content_lines_count > $available_content_height} {
            # Count lines that will be removed
            set lines_removed [expr {$content_lines_count - $available_content_height}]
            
            # Truncate content vertically with intelligent truncation
            if {$available_content_height > 0} {
                # Keep first lines and truncate last visible line
                set kept_lines [lrange $processed_lines 0 [expr {$available_content_height - 2}]]
                
                if {$available_content_height >= 2} {
                    # Take next line and truncate with "..."
                    set next_line_info [lindex $processed_lines [expr {$available_content_height - 1}]]
                    if {$next_line_info ne ""} {
                        set next_line [dict get $next_line_info original_line]
                        # Use available width for content (total width - borders - padding)
                        set content_max_width [expr {$terminal_width - 3 - 2 * $paddingX}]
                        set truncated_line [zesty::smartTruncateStyledText \
                            $next_line [expr {$content_max_width - 3}] 1
                        ]
                        set truncated_line_info [dict create \
                            visible_length [string length [zesty::extractVisibleText $truncated_line]] \
                            original_line $truncated_line
                        ]
                        lappend kept_lines $truncated_line_info
                    } else {
                        # If no next line, add line with "..."
                        set ellipsis_line_info [dict create visible_length 3 original_line "..."]
                        lappend kept_lines $ellipsis_line_info
                    }
                } else {
                    # If only 1 line available, fill with "..."
                    set ellipsis_line_info [dict create visible_length 3 original_line "..."]
                    lappend kept_lines $ellipsis_line_info
                }
                
                set processed_lines $kept_lines
            } else {
                # No content lines possible
                set processed_lines {}
            }
        }
    } elseif {$custom_size ne ""} {        
        # Calculate available height for content
        # Available height = custom height - borders (2) - padding lines (2 * paddingY)
        set available_content_height [expr {$custom_height - 2 - 2 * $paddingY}]
        
        # Manage content according to available height
        set content_lines_count [llength $processed_lines]
        if {$content_lines_count < $available_content_height} {
            # Add empty lines if content is smaller
            set lines_to_add [expr {$available_content_height - $content_lines_count}]
            for {set i 0} {$i < $lines_to_add} {incr i} {
                set empty_line_info [dict create visible_length 0 original_line ""]
                lappend processed_lines $empty_line_info
            }
        } elseif {$content_lines_count > $available_content_height} {
            # Count lines that will be removed
            set lines_removed [expr {$content_lines_count - $available_content_height}]
            
            # Truncate content vertically with intelligent truncation
            if {$available_content_height > 0} {
                # Keep first lines and truncate last visible line
                set kept_lines [lrange $processed_lines 0 [expr {$available_content_height - 2}]]
                
                if {$available_content_height >= 2} {
                    # Take next line and truncate with "..."
                    set next_line_info [lindex $processed_lines [expr {$available_content_height - 1}]]
                    if {$next_line_info ne ""} {
                        set next_line [dict get $next_line_info original_line]
                        # Use available width for content (custom width - borders - padding)
                        set content_max_width [expr {$custom_width - 2 - 2 * $paddingX}]
                        set truncated_line [zesty::smartTruncateStyledText \
                            $next_line [expr {$content_max_width - 3}] 1
                        ]
                        set truncated_line_info [dict create \
                            visible_length [string length [zesty::extractVisibleText $truncated_line]] \
                            original_line $truncated_line
                        ]
                        lappend kept_lines $truncated_line_info
                    } else {
                        # If no next line, add line with "..."
                        set ellipsis_line_info [dict create visible_length 3 original_line "..."]
                        lappend kept_lines $ellipsis_line_info
                    }
                } else {
                    # If only 1 line available, fill with "..."
                    set ellipsis_line_info [dict create visible_length 3 original_line "..."]
                    lappend kept_lines $ellipsis_line_info
                }
                
                set processed_lines $kept_lines
            } else {
                # No content lines possible
                set processed_lines {}
            }
        }
    } else {
        # Mode 3: automatic size (fullScreen = 0, size not defined)
        if {$title ne ""} {
            set box_content_width [expr {max($max_length, $title_visible_length + 2)}]
        } else {
            set box_content_width $max_length
        }
        set total_width [expr {$box_content_width + 2 * $paddingX}]
        
        # In automatic mode, check if truncation still needed
        set updated_lines {}
        foreach line_info $processed_lines {
            set line [dict get $line_info original_line]
            set visible_length [dict get $line_info visible_length]
            
            if {$visible_length > $box_content_width} {
                set wrapped_lines [zesty::wrapText $line $box_content_width 1]
                set truncated_line [lindex $wrapped_lines 0]
                set new_visible_length [string length [zesty::extractVisibleText $truncated_line]]
                set updated_line_info [dict create \
                    visible_length $new_visible_length \
                    original_line $truncated_line
                ]
                lappend updated_lines $updated_line_info
            } else {
                lappend updated_lines $line_info
            }
        }
        set processed_lines $updated_lines
    }
    
    set result ""
    
    # Get content alignment
    set content_align [dict get $options content align]
    
    # Build box according to title position
    if {$title ne ""} {
        set result [zesty::buildBoxWithTitle \
            $title $title_anchor $title_visible_length $total_width  \
            $box_content_width $paddingX $paddingY \
            $top_left $top_right $bottom_left $bottom_right $vertical \
            $horizontal $processed_lines $content_align
        ]
    } else {
        set result [zesty::buildBoxWithoutTitle \
            $total_width $box_content_width $paddingX $paddingY \
            $top_left $top_right $bottom_left $bottom_right \
            $vertical $horizontal $processed_lines $content_align
        ]
    }
    
    # Add message if lines were removed
    if {$lines_removed > 0} {

        if {[dict get $options formatCmdBoxMsgtruncated] ne ""} {
            set cmd [dict get $options formatCmdBoxMsgtruncated]

            set msgResult [uplevel #0 [list \
                {*}$cmd $lines_removed \
            ]]
        
            append result "\n[zesty::smartTruncateStyledText $msgResult 9999 false]"
        } elseif {$lines_removed == 1} {
            append result "\n* Box too small line removed"
        } else {
            append result "\n* Box too small '$lines_removed' lines removed"
        }
    }
    
    return $result
}

proc zesty::buildBoxWithTitle {
    title anchor title_length total_width box_content_width 
    paddingX paddingY
    top_left top_right bottom_left bottom_right vertical horizontal 
    processed_lines content_align
} {
    # Builds a box with title positioned according to anchor.
    #
    # title                                          - styled title text
    # anchor                                         - title position (nc, ne, nw, sc, se, sw, ec, en, es, wc, wn, ws)
    # title_length                                   - visible length of title
    # total_width                                    - total box width including borders
    # box_content_width                              - content area width
    # paddingX                                       - horizontal padding
    # paddingY                                       - vertical padding
    # top_left, top_right, bottom_left, bottom_right - corner characters
    # vertical, horizontal                           - border characters
    # processed_lines                                - list of processed content lines
    # content_align                                  - content alignment (left, right, center)
    #
    # Returns complete box string with title integrated into borders.
    
    set result ""
    
    # Parse anchor
    set side [string index $anchor 0]  ;# n, s, e, w
    set align [string index $anchor 1] ;# l, c, r
    
    # Prepare vertical title for w and e sides
    set vertical_title_chars {}
    set title_start_line 0
    if {$side in {"w" "e"}} {
        # Calculate available height for vertical title
        set available_height [expr {[llength $processed_lines] + 2 * $paddingY}]
        set vertical_title_chars [zesty::createVerticalTitle $title $available_height]
        
        # Calculate start position according to vertical alignment
        set title_height [llength $vertical_title_chars]
        switch $align {
            "n" {
                # North alignment (top)
                set title_start_line 0
            }
            "s" {
                # South alignment (bottom)
                set title_start_line [expr {$available_height - $title_height}]
            }
            "c" -
            default {
                # Center alignment
                set title_start_line [expr {($available_height - $title_height) / 2}]
            }
        }
    }
    
    switch $side {
        "n" {
            # Title on top border (north)
            append result [zesty::buildHorizontalBorderWithTitle \
                $title $align \
                $title_length $total_width \
                $top_left $top_right \
                $horizontal 1
            ]
        }
        "s" {
            # Title on bottom border (south) - start with normal border
            append result $top_left
            append result [string repeat $horizontal $total_width]
            append result $top_right
            append result "\n"
        }
        "e" -
        "w" {
            # Title on sides (east/west) - normal border
            append result $top_left
            append result [string repeat $horizontal $total_width]
            append result $top_right
            append result "\n"
        }
        default {
            # Default anchor (nc)
            append result [zesty::buildHorizontalBorderWithTitle \
                $title "c" $title_length \
                $total_width $top_left $top_right \
                $horizontal 1
            ]
        }
    }
    
    # Create list of all lines (padding + content)
    set all_lines {}
    
    # Add top padding lines
    for {set i 0} {$i < $paddingY} {incr i} {
        lappend all_lines "padding"
    }
    
    # Add content lines
    foreach line_info $processed_lines {
        lappend all_lines $line_info
    }
    
    # Add bottom padding lines
    for {set i 0} {$i < $paddingY} {incr i} {
        lappend all_lines "padding"
    }
    
    # Process each line managing vertical titles
    set line_index 0
    foreach line_entry $all_lines {
        set char_index [expr {$line_index - $title_start_line}]
        set has_title_char [expr {($side in {"w" "e"}) && 
                                  $char_index >= 0 && 
                                  $char_index < [llength $vertical_title_chars]}]
        
        if {$line_entry eq "padding"} {
            # Padding line
            if {$has_title_char} {
                # Insert vertical title character
                set char [lindex $vertical_title_chars $char_index]
                append result [zesty::buildVerticalTitleLine \
                    $char $side $align \
                    $box_content_width $paddingX $vertical
                ]
            } else {
                # Normal padding line
                append result $vertical
                append result [string repeat " " [expr {$box_content_width + 2 * $paddingX}]]
                append result $vertical
                append result "\n"
            }
        } else {
            # Content line
            if {$has_title_char} {
                # Content line with vertical title character
                set char [lindex $vertical_title_chars $char_index]
                append result [zesty::buildContentLineWithVerticalTitle \
                    $line_entry $char $side $align \
                    $box_content_width $paddingX \
                    $vertical $content_align
                ]
            } else {
                # Normal content line
                append result $vertical
                if {$paddingX > 0} {
                    append result [string repeat " " $paddingX]
                }
                # Aligned content
                set aligned_line [zesty::alignText \
                    [dict get $line_entry original_line] \
                    $box_content_width \
                    $content_align
                ]
                append result $aligned_line
                
                if {$paddingX > 0} {
                    append result [string repeat " " $paddingX]
                }
                append result $vertical
                append result "\n"
            }
        }
        incr line_index
    }
    
    # Bottom line
    if {$side eq "s"} {
        # Title on bottom border (south)
        append result [zesty::buildHorizontalBorderWithTitle \
            $title $align $title_length \
            $total_width $bottom_left $bottom_right \
            $horizontal 0
        ]
    } else {
        append result $bottom_left
        append result [string repeat $horizontal $total_width]
        append result $bottom_right
    }
    
    return $result
}

proc zesty::buildVerticalTitleLine {char side align box_content_width paddingX vertical} {
    # Builds line with vertical title character (padding line).
    #
    # char - title character to insert
    # side - title side (w or e)
    # align - title alignment
    # box_content_width - content area width
    # paddingX - horizontal padding
    # vertical - vertical border character
    #
    # Returns formatted line with title character replacing border.
    set result ""
    
    if {$side eq "w"} {
        # Title replaces left border (west)
        append result $char
        append result [string repeat " " [expr {$box_content_width + 2 * $paddingX}]]
        append result $vertical
    } else {
        # Title replaces right border (east)
        append result $vertical
        append result [string repeat " " [expr {$box_content_width + 2 * $paddingX}]]
        append result $char
    }
    
    append result "\n"
    return $result
}

proc zesty::buildContentLineWithVerticalTitle {
    line_info char side align box_content_width 
    paddingX vertical content_align
} {
    # Builds content line with vertical title character.
    #
    # line_info - content line information dictionary
    # char - title character to insert
    # side - title side (w or e)
    # align - title alignment
    # box_content_width - content area width
    # paddingX - horizontal padding
    # vertical - vertical border character
    # content_align - content alignment
    #
    # Returns formatted content line with title character.
    set result ""
    
    if {$side eq "w"} {
        # Title replaces left border (west)
        append result $char
        
        # Left padding
        if {$paddingX > 0} {
            append result [string repeat " " $paddingX]
        }
        
        # Aligned content
        set aligned_line [zesty::alignText \
            [dict get $line_info original_line] \
            $box_content_width \
            $content_align
        ]
        append result $aligned_line
        
        # Right padding
        if {$paddingX > 0} {
            append result [string repeat " " $paddingX]
        }
        
        # Normal right border
        append result $vertical
    } else {
        # Normal left border
        append result $vertical
        
        # Left padding
        if {$paddingX > 0} {
            append result [string repeat " " $paddingX]
        }
        
        # Aligned content
        set aligned_line [zesty::alignText \
            [dict get $line_info original_line] \
            $box_content_width \
            $content_align
        ]
        append result $aligned_line
        
        # Right padding
        if {$paddingX > 0} {
            append result [string repeat " " $paddingX]
        }
        
        # Title replaces right border (east)
        append result $char
    }
    
    append result "\n"
    return $result
}

proc zesty::buildBoxWithoutTitle {
    total_width box_content_width paddingX paddingY
    top_left top_right bottom_left bottom_right 
    vertical horizontal processed_lines content_align
} {
    # Builds a simple box without title.
    #
    # total_width - total box width including borders
    # box_content_width - content area width
    # paddingX - horizontal padding
    # paddingY - vertical padding
    # top_left, top_right, bottom_left, bottom_right - corner characters
    # vertical, horizontal - border characters
    # processed_lines - list of processed content lines
    # content_align - content alignment (left, right, center)
    #
    # Returns complete box string with content and padding.
    
    set result ""
    
    # Top line
    append result $top_left
    append result [string repeat $horizontal $total_width]
    append result $top_right
    append result "\n"

    # Top padding lines
    for {set i 0} {$i < $paddingY} {incr i} {
        append result $vertical
        append result [string repeat " " [expr {$box_content_width + 2 * $paddingX}]]
        append result $vertical
        append result "\n"
    }

    # Content lines
    foreach line_info $processed_lines {
        append result $vertical
        if {$paddingX > 0} {
            append result [string repeat " " $paddingX]
        }
        
        set aligned_line [zesty::alignText \
            [dict get $line_info original_line] \
            $box_content_width \
            $content_align
        ]
        append result $aligned_line
        
        if {$paddingX > 0} {
            append result [string repeat " " $paddingX]
        }
        append result $vertical
        append result "\n"
    }

    # Bottom padding lines
    for {set i 0} {$i < $paddingY} {incr i} {
        append result $vertical
        append result [string repeat " " [expr {$box_content_width + 2 * $paddingX}]]
        append result $vertical
        append result "\n"
    }
    
    # Bottom line
    append result $bottom_left
    append result [string repeat $horizontal $total_width]
    append result $bottom_right
    
    return $result
}

proc zesty::buildHorizontalBorderWithTitle {
    title align title_length total_width left_char 
    right_char horizontal add_newline
} {
    # Builds horizontal border with integrated title.
    #
    # title         - styled title text
    # align         - title alignment (w, e, c)
    # title_length  - visible length of title
    # total_width   - total border width
    # left_char     - left corner character
    # right_char    - right corner character
    # horizontal    - horizontal border character
    # add_newline   - whether to add newline at end
    #
    # Returns formatted border line with title embedded.
    set result ""
    append result $left_char

    # Check if title exceeds available width
    set available_width [expr {$total_width - 2}]  ;# -2 for spaces around title
    if {$title_length > $available_width} {
        if {$available_width >= 4} {
            set wrapped_lines [zesty::wrapText $title $available_width 1]
            set title [lindex $wrapped_lines 0]
            set title_length [string length [zesty::extractVisibleText $title]]
        } else {
            # If space too small, just dots
            set title [string repeat "." [expr {min($available_width, 3)}]]
            set title_length [string length $title]
        }
    }
    
    switch $align {
        "w" {
            append result " $title "
            append result [string repeat $horizontal [expr {$total_width - $title_length - 2}]]
        }
        "e" {
            append result [string repeat $horizontal [expr {$total_width - $title_length - 2}]]
            append result " $title "
        }
        "c" -
        default {
            set left_padding [expr {($total_width - $title_length - 2) / 2}]
            set right_padding [expr {$total_width - $title_length - 2 - $left_padding}]
            append result [string repeat $horizontal $left_padding]
            append result " $title "
            append result [string repeat $horizontal $right_padding]
        }
    }
    
    append result $right_char
    if {$add_newline} {
        append result "\n"
    }
    return $result
}

proc zesty::createVerticalTitle {title max_height} {
    # Creates vertical title by splitting into characters.
    #
    # title      - title text to make vertical
    # max_height - maximum height available for title
    #
    # Returns list of characters for vertical display, truncated
    # with ellipsis if necessary.
    
    # Extract visible text (without formatting)
    set visible_text [zesty::extractVisibleText $title]
    set title_chars [split $visible_text ""]
    set title_height [llength $title_chars]
    
    if {$title_height > $max_height} {
        # Truncate and add "..." if necessary
        if {$max_height >= 4} {
            set truncated_lines [zesty::wrapText $title [expr {$max_height - 3}] 1]
            set truncated_title [lindex $truncated_lines 0]
            set truncated_visible [zesty::extractVisibleText $truncated_title]
            set title_chars [split $truncated_visible ""]
        } else {
            # If height too small, keep only dots
            set title_chars [lrepeat [expr {min($max_height, 3)}] "."]
        }
    }
    
    return $title_chars
}

proc zesty::processTableContent {data columns separator styles content_style box_content_width options} {
    # Processes table content with column formatting and constraints.
    #
    # data               - table data as list of rows
    # columns            - column width specifications
    # separator          - column separator string
    # styles             - column-specific styles
    # content_style      - global content style
    # box_content_width  - available content width
    # options            - additional processing options
    #
    # Returns list of processed line information dictionaries.
    set processed_lines {}
    
    # Validate data
    zesty::validateTableData $data $columns
    
    # Calculate optimal column widths
    set computed_columns [zesty::computeColumnWidths $data $columns $box_content_width $separator]
    
    # Process each data row
    foreach row $data {
        set formatted_row [zesty::formatTableRow \
            $row $computed_columns \
            $separator $styles $content_style \
            $options
        ]
        set line_info [zesty::parseContentLine $formatted_row]
        lappend processed_lines $line_info
    }
    
    return $processed_lines
}

proc zesty::validateTableData {data columns} {
    # Validates table data consistency.
    #
    # data - table data to validate
    # columns - column specifications
    #
    # Returns nothing, throws error if validation fails.

    if {[llength $data] == 0} {
        zesty::throwError "Table data is empty"
    }
    
    set expected_cols [llength $columns]
    if {$expected_cols == 0} {
        zesty::throwError "Table columns are empty"
    }
    
    foreach row $data {
        if {[llength $row] != $expected_cols} {
            zesty::throwError "Inconsistent number of columns in table data"
        }
    }
}

proc zesty::computeColumnWidths {data columns available_width separator} {
    # Intelligently computes column widths with constraints.
    #
    # data - table data for width analysis
    # columns - column width specifications (-1 for auto)
    # available_width - total available width
    # separator - column separator string
    #
    # Returns list of computed column widths optimized for content
    # and available space.
    set num_cols [llength $columns]
    if {$num_cols == 0} {
        return {}
    }

    # Calculate maximum widths for each column first
    set max_widths {}
    for {set i 0} {$i < $num_cols} {incr i} {
        lappend max_widths 0
    }
    
    # Analyze content to determine maximum widths
    foreach row $data {
        for {set col 0} {$col < $num_cols} {incr col} {
            set cell [lindex $row $col]
            set visible_length [zesty::strLength [zesty::extractVisibleText $cell]]
            
            # Update maximum
            set current_max [lindex $max_widths $col]
            if {$visible_length > $current_max} {
                lset max_widths $col $visible_length
            }
        }
    }
    
    # Calculate total requested width
    set total_requested 0
    foreach width $columns {
        if {$width != -1} {
            incr total_requested $width
        }
    }
    set separator_space [expr {($num_cols - 1) * [string length $separator]}]
    set total_needed    [expr {$total_requested + $separator_space}]
    
    # If available_width is negative or 0, use requested widths as-is
    if {$available_width <= 0} {
        # Use requested widths or maximum widths for auto columns
        set result_widths {}
        for {set i 0} {$i < $num_cols} {incr i} {
            set requested_width [lindex $columns $i]
            if {$requested_width == -1} {
                # Auto column: use maximum content width + padding
                set content_max [lindex $max_widths $i]
                # Add space for padding (2 * cell_padding)
                # Use default padding of 2 if not specified
                set total_width [expr {$content_max + 4}]  ;# +4 for 2x2 padding
                lappend result_widths $total_width
            } else {
                # Fixed width: use requested value
                lappend result_widths $requested_width
            }
        }
        return $result_widths
    }
    
    
    # Calculate space used by separators
    set content_space [expr {$available_width - $separator_space}]
    
    if {$content_space <= $num_cols} {
        # Insufficient space, return minimal widths
        return [lrepeat $num_cols 1]
    }
    
    # Process columns according to their type
    set result_widths {}
    set fixed_space 0
    set auto_columns {}
    
    for {set i 0} {$i < $num_cols} {incr i} {
        set requested_width [lindex $columns $i]
        
        switch -- $requested_width {
            -1 {
                # Auto column: will be calculated later
                lappend auto_columns $i
                lappend result_widths 0
            }
            default {
                # Fixed width
                lappend result_widths $requested_width
                incr fixed_space $requested_width
            }
        }
    }
    
    # How much does fixed space exceed?
    if {$fixed_space > $content_space} {
        # Reduce all fixed columns proportionally
        set scale_factor [expr {double($content_space) / double($fixed_space)}]
        
        set result_widths {}
        for {set i 0} {$i < $num_cols} {incr i} {
            set requested_width [lindex $columns $i]
            if {$requested_width == -1} {
                # Auto column: no space available
                lappend result_widths 1
            } else {
                # Fixed column: reduce proportionally
                set scaled_width [expr {int($requested_width * $scale_factor)}]
                if {$scaled_width < 1} {
                    set scaled_width 1
                }
                lappend result_widths $scaled_width
            }
        }
        return $result_widths
    }
    
    # Distribute remaining space to auto columns
    set remaining_space [expr {$content_space - $fixed_space}]
    
    if {[llength $auto_columns] > 0} {
        if {$remaining_space > 0} {
            # Distribute remaining space equally
            set space_per_auto [expr {$remaining_space / [llength $auto_columns]}]
            set extra_space [expr {$remaining_space % [llength $auto_columns]}]
            
            foreach col_index $auto_columns {
                set base_width $space_per_auto
                if {$extra_space > 0} {
                    incr base_width
                    incr extra_space -1
                }
                
                # Ensure minimal width (max content + padding)
                set min_required [expr {[lindex $max_widths $col_index] + 4}]
                set final_width [expr {max($base_width, $min_required)}]
                lset result_widths $col_index $final_width
            }
        } else {
            # No remaining space, use minimal required width
            foreach col_index $auto_columns {
                set min_required [expr {[lindex $max_widths $col_index] + 4}]
                lset result_widths $col_index $min_required
            }
        }
    }

    return $result_widths
}

proc zesty::calculateMinimalColumnWidth {content_widths} {
    # Calculates minimal column width based on content analysis.
    #
    # content_widths - list of content widths to analyze
    #
    # Returns minimal width using median to avoid outliers.
    if {[llength $content_widths] == 0} {
        return 1
    }
    
    # Calculate median to avoid outliers
    set sorted [lsort -integer $content_widths]
    set len [llength $sorted]
    set median_index [expr {$len / 2}]
    
    if {($len % 2) == 0} {
        set median [expr {
            ([lindex $sorted [expr {$median_index - 1}]] +
            [lindex $sorted $median_index]) / 2
        }]
    } else {
        set median [lindex $sorted $median_index]
    }
    
    return [expr {max(1, $median)}]
}

proc zesty::formatTableRow {row columns separator styles content_style options} {
    # Formats table row with advanced cell formatting.
    #
    # row - row data as list of cells
    # columns - column width specifications
    # separator - column separator string
    # styles - column-specific styles
    # content_style - global content style
    # options - formatting options including padding
    #
    # Returns formatted row string with styled cells.
    set formatted_cells {}
    set col_index 0
    
    # Get paddingX from box for use in cells
    set cell_padding 0
    if {[dict exists $options paddingX]} {
        set cell_padding [dict get $options paddingX]
    }
    
    # Get alignments
    set alignments {}
    if {[dict exists $options content table alignments]} {
        set alignments [dict get $options content table alignments]
    }

    foreach cell $row {
        # Determine width of this column
        set col_width [lindex $columns $col_index]
        
        # Determine alignment for this column
        set alignment "left"
        if {$col_index < [llength $alignments]} {
            set alignment [lindex $alignments $col_index]
        }
        
        # Column width already includes padding
        # No need to subtract padding here
        set content_width $col_width
        
        # Format cell content with padding
        set formatted_cell [zesty::formatTableCell \
            $cell $content_width \
            $alignment $cell_padding
        ]
        
        # Apply column style if defined
        if {$col_index < [llength $styles]} {
            set col_style [lindex $styles $col_index]
            if {$col_style ne ""} {
                set formatted_cell [zesty::parseStyleDictToXML \
                    $formatted_cell \
                    $col_style
                ]
            }
        }
        
        lappend formatted_cells $formatted_cell
        incr col_index
    }
    
    # Join cells and apply global style
    set result [join $formatted_cells $separator]
    if {$content_style ne ""} {
        set result [zesty::parseStyleDictToXML $result $content_style]
    }
    
    return $result
}

proc zesty::formatTableCell {content target_width alignment cell_padding} {
    # Formats individual table cell with correct padding handling.
    #
    # content      - cell content to format
    # target_width - target cell width including padding
    # alignment    - cell alignment (left, right, center)
    # cell_padding - padding around cell content
    #
    # Returns formatted cell string with proper alignment and padding.
    
    # Calculate available space for content (without padding)
    set content_space [expr {$target_width - 2 * $cell_padding}]
    if {$content_space < 1} {
        set content_space 1
    }
    
    # Wrap content to available space
    set wrapped_lines [zesty::wrapText $content $content_space 1]
    set content [lindex $wrapped_lines 0]
    
    # Apply content alignment using common function
    set aligned_content [zesty::alignText $content $content_space $alignment]
    
    # Add cell padding (uses paddingX from box)
    return "[string repeat " " $cell_padding]${aligned_content}[string repeat " " $cell_padding]"
}