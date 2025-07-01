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
    variable boxstyles

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
            columns     -validvalue formatColums       -type any|none  -default ""
            alignments  -validvalue formatAlignements  -type any|none  -default ""
            separator   -validvalue formatVBool        -type any       -default "false"
            styles      -validvalue formatStyles       -type any|none  -default ""
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
    foreach {top_left top_right bottom_left bottom_right vertical horizontal} [dict get $boxstyles $box_type] {
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
    set available_content_height -1
    set total_width 0
    set total_height 0

    if {$fullScreen} {
        # Full screen mode
        set total_width [expr {$terminal_width - 3}]
        set total_height [expr {$terminal_height - 3}]
        set box_content_width [expr {$total_width - 2 * $paddingX}]
        set available_content_height [expr {$total_height - 2 - 2 * $paddingY}]

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
        } else {
            set total_height $custom_height
        }

        set box_content_width [expr {$total_width - 2 * $paddingX}]
        set available_content_height [expr {$total_height - 2 - 2 * $paddingY}]
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

        # Table mode - process data as table
        set processed_lines [zesty::processTableContent \
            $content \
            $content_style \
            $box_content_width \
            $options
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

    # Handle height constraints for fullScreen and custom_size modes
    if {$fullScreen || ($custom_size ne "")} {
        lassign [zesty::TruncateContentToHeight \
            $processed_lines \
            $available_content_height \
            $terminal_width \
            $paddingX \
        ] processed_lines lines_removed

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
    # char               - title character to insert
    # side               - title side (w or e)
    # align              - title alignment
    # box_content_width  - content area width
    # paddingX           - horizontal padding
    # vertical           - vertical border character
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
    # line_info          - content line information dictionary
    # char               - title character to insert
    # side               - title side (w or e)
    # align              - title alignment
    # box_content_width  - content area width
    # paddingX           - horizontal padding
    # vertical           - vertical border character
    # content_align      - content alignment
    #
    # Returns formatted content line with title character.
    set result ""
    set padded_content [zesty::buildPaddedContent \
        $line_info $box_content_width $paddingX $content_align \
    ]

    if {$side eq "w"} {
        # Title replaces left border (west)
        append result $char
        append result $padded_content
        # Normal right border
        append result $vertical
    } else {
        # Normal left border
        append result $vertical
        append result $padded_content
        # Title replaces right border (east)
        append result $char
    }

    append result "\n"
    return $result
}

proc zesty::buildPaddedContent {line_info box_content_width paddingX content_align} {
    # Builds the inner part of a box line: padding + aligned content + padding.
    #
    # line_info         - content line information dictionary
    # box_content_width - content area width
    # paddingX          - horizontal padding
    # content_align     - content alignment
    #
    # Returns the padded and aligned content string.
    set result ""
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
    return $result
}

proc zesty::buildBoxWithoutTitle {
    total_width box_content_width paddingX paddingY
    top_left top_right bottom_left bottom_right
    vertical horizontal processed_lines content_align
} {
    # Builds a simple box without title.
    #
    # total_width                                     - total box width including borders
    # box_content_width                               - content area width
    # paddingX                                        - horizontal padding
    # paddingY                                        - vertical padding
    # top_left, top_right, bottom_left, bottom_right  - corner characters
    # vertical, horizontal                            - border characters
    # processed_lines                                 - list of processed content lines
    # content_align                                   - content alignment (left, right, center)
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
        append result [zesty::buildPaddedContent $line_info \
            $box_content_width $paddingX $content_align]
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

proc zesty::processTableContent {content content_style box_content_width options} {
    # Processes table content using a temporary Table instance.
    #
    # content            - table data as text with separators
    # content_style      - global content style
    # box_content_width  - available content width
    # options            - additional processing options
    #
    # Returns list of processed line information dictionaries.

    # Extract options
    set lineShow [dict get $options content table separator]
    set table_columns [dict get $options content table columns]
    set table_styles [dict get $options content table styles]

    zesty::validateTableData $content $table_columns

    # Create temporary table instance
    set tempTable [zesty::Table new \
        -showEdge false \
        -header {show false} \
        -lines [list show $lineShow style [dict get $options box style]] \
        -padding [dict get $options paddingX] \
        -box [list type [dict get $options box type]]
    ]

    # Configure table dimensions
    if {$box_content_width > 0} {
        $tempTable setTermWidth $box_content_width
    }

    # Parse alignments if provided
    set alignments {}
    if {[dict exists $options content table alignments]} {
        set alignments [dict get $options content table alignments]
    }

    # Add columns based on specifications
    for {set i 0} {$i < [llength $table_columns]} {incr i} {
        set colWidth [lindex $table_columns $i]

        # Determine alignment
        set align "left"
        if {$i < [llength $alignments]} {
            set align [lindex $alignments $i]
        }

        # Determine style
        set colStyle ""
        if {$i < [llength $table_styles]} {
            set colStyle [lindex $table_styles $i]
        }

        # Add column to temporary table
        $tempTable addColumn \
            -width $colWidth \
            -justify $align \
            -style $colStyle
    }

    # Parse and add data rows
    foreach row $content {
        $tempTable addRow {*}$row
    }

    # Render table and convert to line information
    set processed_lines {}
    foreach line [split [$tempTable render] "\n"] {
        if {$line ne ""} {
            # Apply content style if specified
            if {$content_style ne ""} {
                set line [zesty::parseStyleDictToXML $line $content_style]
            }

            set line_info [zesty::parseContentLine $line]
            lappend processed_lines $line_info
        }
    }

    # Clean up
    $tempTable destroy

    return $processed_lines
}

proc zesty::validateTableData {data columns} {
    # Validates table data consistency.
    #
    # data    - table data to validate
    # columns - column specifications
    #
    # Returns nothing, throws error if validation fails.

    if {[llength $data] == 0} {
        error "zesty(error): Table data is empty"
    }

    set expected_cols [llength $columns]
    if {$expected_cols == 0} {
        error "zesty(error): Table columns are empty"
    }

    foreach row $data {
        if {[llength $row] != $expected_cols} {
            error "zesty(error): Inconsistent number of columns in table data"
        }
    }
}

proc zesty::TruncateContentToHeight {processed_lines available_height terminal_width paddingX} {
    # Truncates content to fit available height with intelligent truncation.
    #
    # processed_lines  - list of processed line information
    # available_height - maximum number of lines to display
    # terminal_width   - terminal width for truncation calculation
    # paddingX         - horizontal padding
    #
    # Returns list of truncated_lines lines_removed

    set content_lines_count [llength $processed_lines]
    set lines_removed 0

    # If content fits, add empty lines if necessary
    if {$content_lines_count <= $available_height} {
        set lines_to_add [expr {$available_height - $content_lines_count}]
        set result_lines $processed_lines

        for {set i 0} {$i < $lines_to_add} {incr i} {
            set empty_line_info [dict create visible_length 0 original_line ""]
            lappend result_lines $empty_line_info
        }
        return [list $result_lines 0]
    }

    # Content exceeds available height - need to truncate
    set lines_removed [expr {$content_lines_count - $available_height}]

    if {$available_height <= 0} {
        return [list {} $lines_removed]
    }

    # Keep first lines
    set kept_lines [lrange $processed_lines 0 $available_height-2]

    if {$available_height >= 2} {
        # Take next line and truncate with "..."
        set next_line_info [lindex $processed_lines $available_height-1]
        if {$next_line_info ne ""} {
            set next_line [dict get $next_line_info original_line]
            # Calculate available width for content
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

    return [list $kept_lines $lines_removed]
}