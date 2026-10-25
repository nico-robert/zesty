# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {}

oo::class create zesty::Table {
    variable _options
    variable _column_options
    variable _column_configs
    variable _rows
    variable _isWindows
    variable _termWidth
    variable _termHeight
    variable _col_index
    variable _footer

    constructor {args} {
        # Initializes table with default options and detects terminal
        # capabilities for proper rendering.
        #
        # args - Configuration arguments in key-value pairs
        # title            - Table title
        # caption          - Table caption
        # box              - Table box style
        # padding          - Table padding
        # showEdge         - Show table edge
        # lines            - Show table lines
        # header           - Show table header
        # footer           - Show table footer
        # keyPgup          - Key for page up
        # keyPgdn          - Key for page down
        # keyQuit          - Key for quit
        # maxVisibleLines  - Maximum number of visible lines
        # autoScroll       - Enable auto-scrolling
        # pageScroll       - Enable page scrolling
        # continuousScroll - Enable continuous scrolling
        #
        # Returns nothing.
        set _rows {}
        set _column_options {}
        set _footer {}
        set _col_index -1
        set _isWindows  [zesty::isWindows]
        set size        [zesty::getTerminalSize]
        set _termWidth  [lindex $size 0]
        set _termHeight [lindex $size 1]

        # Table options
        zesty::def _options "-title" -validvalue formatVKVP -type struct -with {
            name    -validvalue {}           -type any|none  -default ""
            style   -validvalue formatStyle  -type any|none  -default ""
            justify -validvalue formatAlign  -type str       -default "center"
        }
        zesty::def _options "-caption" -validvalue formatVKVP -type struct -with {
            name    -validvalue {}           -type any|none  -default ""
            style   -validvalue formatStyle  -type any|none  -default ""
            justify -validvalue formatAlign  -type str       -default "center"
        }
        zesty::def _options "-box" -validvalue formatVKVP  -type struct  -with {
            type       -validvalue formatTypeTable  -type str        -default "rounded"
            style      -validvalue formatStyle      -type any|none   -default ""
        }
        zesty::def _options "-padding"  -validvalue formatPad   -type num      -default 1
        zesty::def _options "-showEdge" -validvalue formatVBool -type any      -default "true"
        zesty::def _options "-lines"    -validvalue formatVKVP  -type struct -with {
            show  -validvalue formatVBool  -type any       -default "true"
            style -validvalue formatStyle  -type any|none  -default ""
        }
        # separator: 'auto' (default behavior of each part: the header
        # separator is drawn only with edges, the footer one always),
        # or a boolean to force it.
        zesty::def _options "-header"    -validvalue formatVKVP  -type struct -with {
            show      -validvalue formatVBool      -type any       -default "true"
            style     -validvalue formatStyle      -type any|none  -default ""
            separator -validvalue formatSeparator  -type any       -default "auto"
        }
        zesty::def _options "-footer"    -validvalue formatVKVP  -type struct -with {
            show      -validvalue formatVBool      -type any       -default "true"
            style     -validvalue formatStyle      -type any|none  -default ""
            separator -validvalue formatSeparator  -type any       -default "auto"
        }
        zesty::def _options "-keyPgup"          -validvalue {}          -type str|num  -default "p"
        zesty::def _options "-keyPgdn"          -validvalue {}          -type str|num  -default "f"
        zesty::def _options "-keyQuit"          -validvalue {}          -type str|num  -default "q"
        zesty::def _options "-maxVisibleLines"  -validvalue formatMVL   -type num      -default 0
        zesty::def _options "-autoScroll"       -validvalue formatVBool -type any      -default "false"
        zesty::def _options "-pageScroll"       -validvalue formatVBool -type any      -default "false"
        zesty::def _options "-continuousScroll" -validvalue formatVBool -type any      -default "false"

        # Merge options and args
        set _options [zesty::merge $_options $args]

        # Column options
        zesty::def _column_configs "-name"     -validvalue {}              -type any|none  -default ""
        zesty::def _column_configs "-style"    -validvalue formatStyle     -type any|none  -default ""
        zesty::def _column_configs "-justify"  -validvalue formatAlign     -type str       -default "left"
        zesty::def _column_configs "-vertical" -validvalue formatVertical  -type str       -default "middle"
        zesty::def _column_configs "-width"    -validvalue formatColums    -type num       -default -1
        zesty::def _column_configs "-minWidth" -validvalue {}              -type num       -default 0
        zesty::def _column_configs "-maxWidth" -validvalue {}              -type num       -default 0
        zesty::def _column_configs "-noWrap"   -validvalue formatVBool     -type any       -default "false"

    }

    method PagedDisplay {headerLines dataLines footerLines} {
        # Displays table content with automatic page-based scrolling.
        #
        # headerLines - fixed header lines (title, top border, column headers)
        # dataLines   - data lines
        # footerLines - fixed footer lines (footer, bottom border, caption)
        #
        # Returns nothing.

        # Determine maximum height to use
        set maxLines [dict get $_options maxVisibleLines]
        if {$maxLines <= 0 || $maxLines >= ($_termHeight - 2)} {
            # If maxVisibleLines is not set or is 0, use terminal height
            set availableHeight [expr {$_termHeight - 2}]
        } else {
            # Use the configured maxVisibleLines value
            set availableHeight [expr {$maxLines - 2}]
        }

        # Ensure minimum height
        if {$availableHeight < 5} {
            set availableHeight 5
        }

        set allLines [concat $headerLines $dataLines $footerLines]

        # If table fits entirely in available space, display it directly
        if {[llength $allLines] <= $availableHeight} {
            zesty::echo "[join $allLines "\n"]\n"
            return {}
        }

        set totalDataLines [llength $dataLines]

        # Calculate how many data lines can be displayed at once
        set visibleDataHeight [expr {$availableHeight - [llength $headerLines] - [llength $footerLines]}]
        if {$visibleDataHeight < 1} {set visibleDataHeight 1}

        # Calculate total number of pages
        set totalPages [expr {int(ceil(double($totalDataLines) / $visibleDataHeight))}]
        if {$totalPages < 1} {set totalPages 1}

        # Display data page by page
        set currentPage 0

        while {$currentPage < $totalPages} {
            # Clear screen before displaying new page
            zesty::resetTerminal

            # Display fixed header
            zesty::echo [join $headerLines "\n"]

            # Calculate which data lines to display for this page
            set pageStart [expr {$currentPage * $visibleDataHeight}]
            set pageEnd [expr {$pageStart + $visibleDataHeight - 1}]
            if {$pageEnd >= $totalDataLines} {
                set pageEnd [expr {$totalDataLines - 1}]
            }

            # Display data lines for this page
            for {set i $pageStart} {$i <= $pageEnd} {incr i} {
                zesty::echo [lindex $dataLines $i]
            }

            # Display table footer
            zesty::echo [join $footerLines "\n"]

            set keyquit [dict get $_options keyQuit]
            set keypgup [dict get $_options keyPgup]

            # Display pagination information with maxVisibleLines info if applicable
            if {[dict get $_options maxVisibleLines] > 0} {
                zesty::echo "-- Page [expr {$currentPage + 1}] of $totalPages -- \
                            Lines [expr {$pageStart + 1}]-[expr {$pageEnd + 1}] of $totalDataLines\
                            (maxLines: [dict get $_options maxVisibleLines]) --"
            } else {
                zesty::echo "-- Page [expr {$currentPage + 1}] of $totalPages -- \
                            Lines [expr {$pageStart + 1}]-[expr {$pageEnd + 1}] of $totalDataLines --"
            }
            zesty::echo "Press Enter to continue, '$keyquit' to quit, '$keypgup' for previous page..."

            # Read user input (end of input stops paging)
            if {[gets stdin input] < 0} {
                break
            }
            set input [string tolower [string trim $input]]

            if {$input eq [string tolower $keyquit]} {
                break
            } elseif {$input eq [string tolower $keypgup]} {
                # Previous page
                if {$currentPage > 0} {
                    incr currentPage -1
                }
            } else {
                # Next page (default)
                if {$currentPage < $totalPages - 1} {
                    incr currentPage
                } else {
                    # If on last page, quit
                    break
                }
            }
        }

        # Clear screen at the end
        zesty::resetTerminal

        return {}
    }

    method ContinuousScroll {headerLines dataLines footerLines} {
        # Displays table content with line-by-line continuous scrolling.
        # Only the header stays visible: the footer scrolls with the data.
        #
        # headerLines - fixed header lines (title, top border, column headers)
        # dataLines   - data lines
        # footerLines - footer lines (footer, bottom border, caption)
        #
        # Returns nothing.

        # Reserve one line for information
        set availableHeight [expr {$_termHeight - 2}]
        set allLines [concat $headerLines $dataLines $footerLines]

        # If table fits entirely in terminal, display it directly
        if {[llength $allLines] <= $availableHeight} {
            zesty::echo "[join $allLines "\n"]\n"
            return {}
        }

        # Fixed part (header)
        set headerHeight [llength $headerLines]

        # Scrollable part (content and footer)
        set scrollLines [concat $dataLines $footerLines]
        set totalDataLines [llength $scrollLines]

        # Available space for data
        set visibleDataHeight [expr {$availableHeight - $headerHeight}]
        if {$visibleDataHeight < 5} {set visibleDataHeight 5}

        # Display data with scrolling
        set startLine 0
        set maxStartLine [expr {$totalDataLines - $visibleDataHeight}]
        if {$maxStartLine < 0} {set maxStartLine 0}

        while {1} {
            zesty::resetTerminal

            # Display fixed header
            zesty::echo [join $headerLines "\n"]

            # Display visible data lines
            set endLine [expr {$startLine + $visibleDataHeight - 1}]
            if {$endLine >= $totalDataLines} {
                set endLine [expr {$totalDataLines - 1}]
            }

            for {set i $startLine} {$i <= $endLine} {incr i} {
                zesty::echo [lindex $scrollLines $i]
            }

            set keyquit [dict get $_options keyQuit]
            set keypgup [dict get $_options keyPgup]
            set keypgdn [dict get $_options keyPgdn]

            # Display position information
            set cline [expr {$startLine + 1}]-[expr {$endLine + 1}]
            zesty::echo "-- Lines $cline of $totalDataLines | $keypgdn: down, $keypgup: up, $keyquit: quit --"

            # Read user input (end of input stops scrolling)
            if {[gets stdin input] < 0} {
                break
            }
            set input [string tolower [string trim $input]]

            if {$input eq [string tolower $keyquit]} {
                break
            } elseif {$input eq [string tolower $keypgup]} {
                # Scroll up
                incr startLine -1
                if {$startLine < 0} {set startLine 0}
            } elseif {$input eq [string tolower $keypgdn]} {
                # Scroll down
                if {$startLine < $maxStartLine} {
                    incr startLine
                } else {
                    # At end, quit
                    break
                }
            }
        }

        # Clear screen at the end
        zesty::resetTerminal

        return {}
    }

    method addColumn {args} {
        # Adds a new column to the table with specified configuration.
        #
        # args - Column configuration arguments in key-value pairs
        #
        # Returns nothing.
        incr _col_index

        # Merge column options
        set colopts [zesty::merge $_column_configs $args]

        if {[dict get $colopts name] eq ""} {
            dict set colopts name "column:${_col_index}"
        } else {
            dict set colopts name [zesty::ExpandTabs [dict get $colopts name]]
        }

        # Store column header and its options
        dict set _column_options $_col_index $colopts

        return {}
    }

    method DisplayWithScroll {headerLines dataLines footerLines} {
        # Displays table content with automatic scroll detection.
        #
        # headerLines - fixed header lines (title, top border, column headers)
        # dataLines   - data lines
        # footerLines - fixed footer lines (footer, bottom border, caption)
        #
        # Returns nothing.

        set allLines   [concat $headerLines $dataLines $footerLines]
        set totalLines [llength $allLines]

        # Determine maximum number of lines to display
        set maxLines [dict get $_options maxVisibleLines]
        if {($maxLines <= 0 )|| $maxLines >= ($_termHeight - 2)} {
            # Auto-detection based on terminal height
            set maxLines $_termHeight
            # Reserve 2 lines for status bar, etc.
            incr maxLines -2
            if {$maxLines < 10} {set maxLines 10}
        }

        # If content fits in available space, display normally
        if {$totalLines <= $maxLines} {
            zesty::echo "[join $allLines "\n"]\n"
            return {}
        }

        # Number of lines kept visible above and below the data
        set headerRows [llength $headerLines]
        set footerRows [llength $footerLines]

        # Calculate number of lines available for scrollable content
        set contentRows [expr {$maxLines - $headerRows - $footerRows}]
        if {$contentRows < 5} {set contentRows 5}

        # Total number of "data" lines (without header or footer)
        set dataCount [llength $dataLines]

        # If not enough data to scroll, display normally
        if {$dataCount <= $contentRows} {
            zesty::echo "[join $allLines "\n"]\n"
            return {}
        }

        set keyquit [dict get $_options keyQuit]

        # 1. Header (always visible)
        zesty::echo [join $headerLines "\n"]

        # 2. Content with scrolling
        for {set dataStart 0} {$dataStart <= $dataCount - $contentRows} {incr dataStart} {
            # Get and display visible segment
            set dataEnd [expr {$dataStart + $contentRows - 1}]
            zesty::echo [join [lrange $dataLines $dataStart $dataEnd] "\n"]

            # 3. Table footer (always visible)
            zesty::echo [join $footerLines "\n"]

            # Add progress indicator
            zesty::echo "-- Lines [expr {$dataStart + 1}]-[expr {$dataEnd + 1}]\
                        out of $dataCount (Press Enter to continue, '$keyquit' to quit) --"

            # Wait for user input (end of input stops scrolling)
            if {[gets stdin input] < 0} {
                break
            }
            set input [string tolower [string trim $input]]

            if {$input eq [string tolower $keyquit]} {
                break
            }

            # Clear screen for next page (except for last)
            if {$dataStart < $dataCount - $contentRows} {
                puts "\033\[H\033\[J"  ;# Clear screen and place cursor at top

                # Redisplay fixed header
                zesty::echo [join $headerLines "\n"]
            }
        }

        return {}
    }

    method addRow {args} {
        # Adds a new row to the table with data validation.
        #
        # args - Row data as separate arguments for each column
        #
        # Returns nothing.
        set numCols [dict size $_column_options]
        set numArgs [llength $args]

        # Ensure we have sufficient arguments
        if {$numArgs > $numCols} {
            error "zesty(error): Too many arguments provided\
                '$numArgs' for '$numCols' columns"
        }

        # Padding with empty strings for missing columns
        set row [lmap cell $args {zesty::ExpandTabs $cell}]
        while {[llength $row] < $numCols} {
            lappend row ""
        }

        lappend _rows $row

        return {}
    }

    method setFooter {args} {
        # Sets footer data for the table.
        #
        # args - footer data as separate arguments for each column
        #
        # Returns nothing.

        set numCols [dict size $_column_options]
        set numArgs [llength $args]

        # Ensure we don't have too many arguments
        if {$numArgs > $numCols} {
            error "zesty(error): Too many arguments provided\
                '$numArgs' for '$numCols' columns"
        }

        # Pad with empty strings for missing columns
        set footerData [lmap cell $args {zesty::ExpandTabs $cell}]
        while {[llength $footerData] < $numCols} {
            lappend footerData ""
        }

        # Store footer data in class variable
        set _footer $footerData

        return {}
    }

    method setTermWidth {width} {
        # Sets terminal width.
        #
        # width - Terminal width in characters
        #
        # Returns nothing.
        if {$width <= 0} {
            error "zesty(error): Invalid terminal width '$width'"
        }
        set _termWidth $width
    }

    method CalculateTableColumnWidths {} {
        # Calculates optimal column widths based on content and constraints.
        #
        # Returns list of column widths in characters including padding.

        set naturalWidths [my GetNaturalColumnWidths]
        set numCols [dict size $_column_options]
        set pad [dict get $_options padding]

        # Calculate available space
        set availableWidth [my GetAvailableTableWidth]

        # Separate fixed and auto columns
        lassign [my ClassifyColumns] autoColumns fixedColumns fixedTotalWidth

        # Special case: all columns are auto
        if {[llength $autoColumns] == $numCols && $numCols > 0} {
            return [my DistributeAllAutoColumns $naturalWidths $availableWidth $pad]
        }

        # Mixed case: some fixed, some auto
        return [my DistributeMixedColumns \
            $naturalWidths $availableWidth $pad \
            $autoColumns $fixedColumns $fixedTotalWidth
        ]
    }

    method GetNaturalColumnWidths {} {
        # Calculate natural width for each column based on content.
        # Takes noWrap option into account.
        #
        # Returns list of natural widths without padding.

        set naturalWidths {}

        for {set i 0} {$i < [dict size $_column_options]} {incr i} {
            # A header may span several lines: its width is the longest one.
            set headerLen 0
            foreach line [split [dict get $_column_options $i name] "\n"] {
                set headerLen [expr {max($headerLen, [zesty::strLength [zesty::extractVisibleText $line]])}]
            }
            set maxContentLen 0

            # Check if noWrap is enabled for this column
            set noWrap [dict get $_column_options $i noWrap]

            # Find maximum content width in this column (the footer, when
            # displayed, is taken into account like a row).
            set rows $_rows
            if {[dict get $_options footer show] && [llength $_footer]} {
                lappend rows $_footer
            }
            foreach row $rows {
                if {$i < [llength $row]} {
                    set content [lindex $row $i]

                    # For noWrap columns, we need the absolute maximum line length
                    if {[string first "\n" $content] != -1} {
                        foreach line [split $content "\n"] {
                            set contentLen [zesty::strLength [zesty::extractVisibleText $line]]
                            if {$contentLen > $maxContentLen} {
                                set maxContentLen $contentLen
                            }
                        }
                    } else {
                        set contentLen [zesty::strLength [zesty::extractVisibleText $content]]
                        if {$contentLen > $maxContentLen} {
                            set maxContentLen $contentLen
                        }
                    }
                }
            }

            # Natural width is the maximum of header and content
            set naturalWidth [expr {max($headerLen, $maxContentLen)}]

            # For noWrap columns, this is the minimum width we need
            if {$noWrap} {
                # Store this as a special requirement
                dict set _column_options $i _requiredWidth $naturalWidth
            }

            lappend naturalWidths $naturalWidth
        }

        return $naturalWidths
    }

    method GetAvailableTableWidth {} {
        # Calculate available width for table content.
        #
        # Returns available width excluding borders and separators.

        set numCols [dict size $_column_options]
        set lines_show [dict get $_options lines show]

        # Space for separators and borders
        set separatorSpace 0
        if {$lines_show} {
            set separatorSpace [expr {$numCols + 1}]
        } elseif {[dict get $_options showEdge]} {
            set separatorSpace 2
        }

        # Terminal width minus separators and safety margin
        return [expr {$_termWidth - $separatorSpace - 2}]
    }

    method ClassifyColumns {} {
        # Classify columns as auto or fixed width.
        #
        # Returns list of: autoColumns fixedColumns fixedTotalWidth

        set autoColumns {}
        set fixedColumns {}
        set fixedTotalWidth 0
        set pad [dict get $_options padding]

        for {set i 0} {$i < [dict size $_column_options]} {incr i} {
            set width [dict get $_column_options $i width]

            if {$width == -1} {
                lappend autoColumns $i
            } else {
                lappend fixedColumns $i
                incr fixedTotalWidth [expr {$width + (2 * $pad)}]
            }
        }

        return [list $autoColumns $fixedColumns $fixedTotalWidth]
    }

    method ColumnMinWidth {colIndex pad} {
        # Minimum width an auto column can be compressed to: its minWidth
        # (5 by default), but never more than its maxWidth.
        #
        # colIndex - column index
        # pad      - padding value
        #
        # Returns minimum width with padding.

        set colMinWidth [dict get $_column_options $colIndex minWidth]
        set colMaxWidth [dict get $_column_options $colIndex maxWidth]

        set width [expr {($colMinWidth > 0) ? $colMinWidth : 5}]
        if {($colMaxWidth > 0) && ($width > $colMaxWidth)} {
            set width $colMaxWidth
        }

        return [expr {$width + (2 * $pad)}]
    }

    method DistributeAllAutoColumns {naturalWidths availableWidth pad} {
        # Distribute width when all columns are auto.
        # Respects minWidth constraints for all columns.
        #
        # naturalWidths  - list of natural content widths
        # availableWidth - total available width
        # pad            - padding value
        #
        # Returns list of column widths with padding.

        set numCols [llength $naturalWidths]

        # Step 1: Calculate widths respecting minWidth and maxWidth
        set colWidths {}
        set totalRequired 0

        for {set i 0} {$i < $numCols} {incr i} {
            set naturalWidth [lindex $naturalWidths $i]
            set colMinWidth [dict get $_column_options $i minWidth]
            set colMaxWidth [dict get $_column_options $i maxWidth]

            # Width is MAX(natural, minWidth), capped by maxWidth
            set width $naturalWidth
            if {($colMinWidth > 0) && ($width < $colMinWidth)} {
                set width $colMinWidth
            }
            if {($colMaxWidth > 0) && ($width > $colMaxWidth)} {
                set width $colMaxWidth
            }

            set widthWithPadding [expr {$width + (2 * $pad)}]
            lappend colWidths $widthWithPadding
            incr totalRequired $widthWithPadding
        }

        # Step 2: Check if compression is needed
        if {$totalRequired <= $availableWidth} {
            # Everything fits with minWidth respected
            return $colWidths
        }

        # Step 3: Need compression - identify compressible columns
        set compressibleColumns {}
        set fixedSpace 0
        set compressibleSpace 0

        for {set i 0} {$i < $numCols} {incr i} {
            set currentWidth [lindex $colWidths $i]
            set minRequired [my ColumnMinWidth $i $pad]

            if {$currentWidth > $minRequired} {
                # This column can be compressed
                lappend compressibleColumns $i
                incr compressibleSpace [expr {$currentWidth - $minRequired}]
            }
            incr fixedSpace $minRequired
        }

        # Step 4: If total minimum requirements exceed available space
        if {$fixedSpace > $availableWidth} {
            # Even with all columns at minimum, we exceed available space:
            # share it in proportion to the minimum widths, so that larger
            # minWidth columns stay larger.
            set colWidths {}

            for {set i 0} {$i < $numCols} {incr i} {
                set minRequired [my ColumnMinWidth $i $pad]
                set width [expr {int($availableWidth * $minRequired / double($fixedSpace))}]
                lappend colWidths [expr {max($width, 3 + 2 * $pad)}]
            }
            return $colWidths
        }

        # Step 5: Compress only the compressible columns
        if {[llength $compressibleColumns] > 0 && $compressibleSpace > 0} {
            set needToCompress [expr {$totalRequired - $availableWidth}]

            # Distribute compression proportionally among compressible columns
            foreach idx $compressibleColumns {
                set currentWidth [lindex $colWidths $idx]
                set minRequired [my ColumnMinWidth $idx $pad]

                # How much this column can be compressed
                set canCompress [expr {$currentWidth - $minRequired}]

                # Proportional compression
                set compressionRatio [expr {double($canCompress) / double($compressibleSpace)}]
                set toCompress [expr {int($needToCompress * $compressionRatio)}]

                # Apply compression but respect minimum
                set newWidth [expr {$currentWidth - $toCompress}]
                if {$newWidth < $minRequired} {
                    set newWidth $minRequired
                }

                lset colWidths $idx $newWidth
            }
        }

        # Step 6: Final adjustment if still exceeding
        set finalTotal [tcl::mathop::+ {*}$colWidths]
        if {$finalTotal > $availableWidth} {
            # Do a final proportional adjustment
            set ratio [expr {double($availableWidth) / double($finalTotal)}]
            set adjustedWidths {}

            for {set i 0} {$i < $numCols} {incr i} {
                set width [lindex $colWidths $i]
                set newWidth [expr {int($width * $ratio)}]

                # Still respect minimum
                set minRequired [my ColumnMinWidth $i $pad]

                if {$newWidth < $minRequired} {
                    set newWidth $minRequired
                }

                lappend adjustedWidths $newWidth
            }
            return $adjustedWidths
        }

        return $colWidths
    }

    method DistributeMixedColumns {naturalWidths availableWidth pad autoColumns fixedColumns fixedTotalWidth} {
        # Distribute width with mixed fixed/auto columns.
        #
        # naturalWidths   - list of natural content widths
        # availableWidth  - total available width
        # pad             - padding value
        # autoColumns     - list of auto column indices
        # fixedColumns    - list of fixed column indices
        # fixedTotalWidth - total width of fixed columns
        #
        # Returns list of column widths with padding.

        set numCols [dict size $_column_options]
        set colWidths {}

        # Initialize with fixed columns
        for {set i 0} {$i < $numCols} {incr i} {
            if {$i in $fixedColumns} {
                set width [dict get $_column_options $i width]
                lappend colWidths [expr {$width + (2 * $pad)}]
            } else {
                lappend colWidths 0  ;# Placeholder
            }
        }

        # Distribute remaining space to auto columns
        set remainingSpace [expr {$availableWidth - $fixedTotalWidth}]

        # Target (natural) and minimum widths of auto columns, with
        # padding and constraints (minWidth, maxWidth, noWrap) applied.
        set targets {}
        set mins {}
        set totalTarget 0
        set totalMin 0
        foreach idx $autoColumns {
            set naturalWidth [lindex $naturalWidths $idx]
            set target [my ConstrainColumnWidth $idx [expr {$naturalWidth + (2 * $pad)}] $pad]
            set min [expr {min($target, [my ConstrainColumnWidth $idx 0 $pad])}]
            dict set targets $idx $target
            dict set mins $idx $min
            incr totalTarget $target
            incr totalMin $min
        }

        if {$totalTarget <= $remainingSpace} {
            # Everything fits: auto columns keep their natural width
            # instead of filling the whole terminal.
            dict for {idx target} $targets {
                lset colWidths $idx $target
            }
        } elseif {$totalMin >= $remainingSpace} {
            # Not even the minimums fit: use them (the table overflows
            # as little as possible).
            dict for {idx min} $mins {
                lset colWidths $idx $min
            }
        } else {
            # Each auto column gets its minimum, then the space left is
            # shared in proportion to what each column still needs to
            # reach its natural width. The total never exceeds the
            # remaining space.
            set extra [expr {$remainingSpace - $totalMin}]
            set totalNeed [expr {$totalTarget - $totalMin}]
            dict for {idx min} $mins {
                set need [expr {[dict get $targets $idx] - $min}]
                lset colWidths $idx [expr {$min + int($extra * $need / double($totalNeed))}]
            }
        }

        return $colWidths
    }

    method ConstrainColumnWidth {colIndex targetWidth pad} {
        # Apply min/max constraints to a column width.
        # Also ensures noWrap columns get their required width.
        #
        # colIndex     - column index
        # targetWidth  - target width with padding
        # pad          - padding value
        #
        # Returns constrained width with padding.

        set colMinWidth [dict get $_column_options $colIndex minWidth]
        set colMaxWidth [dict get $_column_options $colIndex maxWidth]
        set noWrap [dict get $_column_options $colIndex noWrap]

        # For noWrap columns, ensure minimum is the required width
        if {$noWrap && [dict exists $_column_options $colIndex _requiredWidth]} {
            set requiredWidth [dict get $_column_options $colIndex _requiredWidth]

            # The minimum for noWrap is the larger of configured minimum or required width
            set minAllowed [expr {max(($colMinWidth > 0 ? $colMinWidth : 5), $requiredWidth)}]
        } else {
            # Normal minimum
            set minAllowed [expr {($colMinWidth > 0) ? $colMinWidth : 5}]
        }

        set minWithPadding [expr {$minAllowed + (2 * $pad)}]

        if {$targetWidth < $minWithPadding} {
            set targetWidth $minWithPadding
        }

        # Apply maximum
        if {($colMaxWidth > 0) && ($targetWidth > ($colMaxWidth + 2 * $pad))} {
            set targetWidth [expr {$colMaxWidth + (2 * $pad)}]
        }

        return $targetWidth
    }

    method CalculateTotalTableWidth {colWidths} {
        # Calculates total table width including separators and borders.
        #
        # colWidths - list of column widths
        #
        # Returns total table width in characters.

        set tableWidth 0
        foreach width $colWidths {
            incr tableWidth $width
        }

        set numCols [llength $colWidths]
        set lines_show [dict get $_options lines show]

        # Add width of column separators
        if {$lines_show} {
            incr tableWidth [expr {$numCols + 1}]
        } elseif {[dict get $_options showEdge]} {
            incr tableWidth 2
        }

        return $tableWidth
    }

    method AlignCellContentVertical {lines cellHeight verticalAlign} {
        # Vertically aligns cell content within specified height.
        #
        # lines         - List of text lines in the cell
        # cellHeight    - Target height in lines
        # verticalAlign - Alignment: "top", "bottom", or "middle"
        #
        # Returns list of lines padded to cellHeight with proper
        # vertical alignment.
        set numLines [llength $lines]
        set result $lines

        if {$numLines < $cellHeight} {
            set padding [expr {$cellHeight - $numLines}]
            set topPad 0
            set bottomPad 0

            switch -exact -- $verticalAlign {
                "top" {
                    set bottomPad $padding
                }
                "bottom" {
                    set topPad $padding
                }
                "middle" -
                default {
                    set topPad [expr {$padding / 2}]
                    set bottomPad [expr {$padding - $topPad}]
                }
            }

            set result {}
            for {set i 0} {$i < $topPad} {incr i} {
                lappend result ""
            }
            foreach line $lines {
                lappend result $line
            }
            for {set i 0} {$i < $bottomPad} {incr i} {
                lappend result ""
            }
        }

        return $result
    }


    method AdjustColumnsForTitle {colWidths title} {
        # Adjusts column widths if title is wider than table.
        #
        # colWidths - current column widths
        # title     - title text
        #
        # Returns adjusted column widths list.

        if {$title eq ""} {
            return $colWidths
        }

        set titleWidth [zesty::strLength [zesty::extractVisibleText $title]]
        set minTitleWidth [expr {$titleWidth + 2}]
        set tableWidth [my CalculateTotalTableWidth $colWidths]

        if {$minTitleWidth <= $tableWidth} {
            return $colWidths
        }

        # Calculate extra space needed
        set extraSpace [expr {$minTitleWidth - $tableWidth}]
        set numCols [llength $colWidths]
        set extraPerCol [expr {$extraSpace / $numCols}]
        set remainder [expr {$extraSpace % $numCols}]

        # Update column widths
        set adjustedWidths {}
        for {set i 0} {$i < $numCols} {incr i} {
            set currentWidth [lindex $colWidths $i]
            set newWidth [expr {$currentWidth + $extraPerCol}]
            if {$i < $remainder} {
                incr newWidth
            }
            lappend adjustedWidths $newWidth
        }

        return $adjustedWidths
    }

    method GetBoxCharacters {} {
        # Gets box drawing characters based on configured style.
        #
        # Returns dictionary with box character keys.

        set boxtype [dict get $_options box type]

        if {![dict exists $::zesty::tablestyles $boxtype]} {
            error "zesty(error): '$boxtype' is not a valid box type"
        }

        set boxchars [dict get $::zesty::tablestyles $boxtype]

        return [dict create \
            tl  [lindex $boxchars 0] \
            tr  [lindex $boxchars 1] \
            bl  [lindex $boxchars 2] \
            br  [lindex $boxchars 3] \
            vl  [lindex $boxchars 4] \
            hl  [lindex $boxchars 5] \
            xc  [lindex $boxchars 6] \
            tt  [lindex $boxchars 7] \
            tb  [lindex $boxchars 8] \
            tlj [lindex $boxchars 9] \
            trj [lindex $boxchars 10]
        ]
    }

    method RenderTitle {title tableWidth boxChars} {
        # Renders table title section.
        #
        # title      - title text
        # tableWidth - total table width
        # boxChars   - dictionary of box characters
        #
        # Returns formatted title section string.

        if {$title eq ""} {
            return ""
        }

        set edge_style [my EdgeStyle]
        set result ""

        # Top border
        if {[dict get $_options showEdge]} {
            set hl_l [string repeat [dict get $boxChars hl] [expr {$tableWidth - 2}]]
            append result [zesty::parseStyleDictToXML [dict get $boxChars tl] $edge_style]
            append result [zesty::parseStyleDictToXML $hl_l $edge_style]
            append result [zesty::parseStyleDictToXML [dict get $boxChars tr] $edge_style]
            append result "\n"
        }

        # Title text
        set title_justify [dict get $_options title justify]
        set paddedTitle [zesty::alignText $title [expr {$tableWidth - 2}] $title_justify]
        set title_style [dict get $_options title style]
        set paddedTitle [zesty::parseStyleDictToXML $paddedTitle $title_style]

        if {[dict get $_options showEdge]} {
            append result [zesty::parseStyleDictToXML [dict get $boxChars vl] $edge_style]
            append result $paddedTitle
            append result [zesty::parseStyleDictToXML [dict get $boxChars vl] $edge_style]
        } else {
            append result " $paddedTitle"
        }
        append result "\n"

        return $result
    }

    method BorderLine {colWidths left junction right boxChars {inner 0}} {
        # Builds a horizontal line: left corner, the horizontal
        # character over each column, a junction between columns when
        # column lines are shown, and right corner.
        #
        # colWidths - list of column widths
        # left      - box character key of the left end, "" for none
        # junction  - box character key between columns
        # right     - box character key of the right end, "" for none
        # boxChars  - dictionary of box characters
        # inner     - 1 for a separator inside the table: its ends are
        #             in the edge style, the rest in the lines style
        #
        # Returns styled line followed by a newline.

        set lines_show [dict get $_options lines show]
        set horizontal [dict get $boxChars hl]

        set line ""
        set first 1
        foreach width $colWidths {
            if {!$first && $lines_show} {
                append line [dict get $boxChars $junction]
            }
            append line [string repeat $horizontal $width]
            set first 0
        }

        set left  [expr {$left  eq "" ? "" : [dict get $boxChars $left]}]
        set right [expr {$right eq "" ? "" : [dict get $boxChars $right]}]

        set edge_style [my EdgeStyle]
        set line_style [expr {$inner ? [my LineStyle] : $edge_style}]

        # Same style everywhere: a single tag for the whole line.
        if {$edge_style eq $line_style} {
            return "[zesty::parseStyleDictToXML $left$line$right $edge_style]\n"
        }

        set result ""
        if {$left ne ""} {
            append result [zesty::parseStyleDictToXML $left $edge_style]
        }
        append result [zesty::parseStyleDictToXML $line $line_style]
        if {$right ne ""} {
            append result [zesty::parseStyleDictToXML $right $edge_style]
        }

        return "$result\n"
    }

    method EdgeStyle {} {
        # Gets the style of the table frame (borders, edges, title box):
        # '-box style', or '-lines style' when it is not set.
        #
        # Returns style dictionary.
        set style [dict get $_options box style]
        if {$style eq ""} {
            set style [dict get $_options lines style]
        }
        return $style
    }

    method LineStyle {} {
        # Gets the style of the lines inside the table (between columns,
        # under the header, above the footer): '-lines style', or
        # '-box style' when it is not set.
        #
        # Returns style dictionary.
        set style [dict get $_options lines style]
        if {$style eq ""} {
            set style [dict get $_options box style]
        }
        return $style
    }

    method RenderTopBorder {colWidths hasTitle boxChars} {
        # Renders top border of table.
        #
        # colWidths - list of column widths
        # hasTitle  - whether table has a title
        # boxChars  - dictionary of box characters
        #
        # Returns formatted top border string.

        if {![dict get $_options showEdge]} {
            return ""
        }

        # Under a title, the corners join the title box.
        if {$hasTitle} {
            return [my BorderLine $colWidths tlj tt trj $boxChars]
        }
        return [my BorderLine $colWidths tl tt tr $boxChars]
    }

    method RenderSeparator {colWidths boxChars} {
        # Renders a separator line between table parts (under the
        # header, above the footer). Without edges, only the inner
        # part is drawn.
        #
        # colWidths - list of column widths
        # boxChars  - dictionary of box characters
        #
        # Returns formatted separator string.

        if {[dict get $_options showEdge]} {
            return [my BorderLine $colWidths tlj xc trj $boxChars 1]
        }
        return [my BorderLine $colWidths "" xc "" $boxChars 1]
    }

    method RenderBottomBorder {colWidths boxChars} {
        # Renders bottom border of table.
        #
        # colWidths - list of column widths
        # boxChars  - dictionary of box characters
        #
        # Returns formatted bottom border string.

        if {![dict get $_options showEdge]} {
            return ""
        }

        return [my BorderLine $colWidths bl tb br $boxChars]
    }

    method WrapCell {content width noWrap} {
        # Wraps the content of a cell: manual line breaks first, then
        # each line is wrapped (or truncated) to the column width.
        #
        # content - cell content (may contain style tags)
        # width   - available width (column width without padding)
        # noWrap  - 1 to truncate with an ellipsis instead of wrapping
        #
        # Returns list of cell lines.

        set lines {}
        foreach line [split $content "\n"] {
            lappend lines {*}[zesty::wrapText $line $width $noWrap]
        }

        return $lines
    }

    method CellLines {cells height colWidths styles boxChars} {
        # Renders the screen lines of a table row: on each line, the
        # cells side by side with their padding, alignment and style,
        # separated by column lines.
        #
        # cells     - list (one element per column) of cell lines
        # height    - number of screen lines
        # colWidths - list of column widths
        # styles    - list (one element per column) of style dicts
        # boxChars  - dictionary of box characters
        #
        # Returns formatted lines string.

        set lines_show  [dict get $_options lines show]
        set showEdge    [dict get $_options showEdge]
        set padding     [string repeat " " [dict get $_options padding]]
        set edge        [zesty::parseStyleDictToXML [dict get $boxChars vl] [my EdgeStyle]]
        set vertical    [zesty::parseStyleDictToXML [dict get $boxChars vl] [my LineStyle]]
        set numCols     [llength $colWidths]

        set result ""
        for {set lineIdx 0} {$lineIdx < $height} {incr lineIdx} {
            set line [expr {$showEdge ? $edge : ""}]

            for {set colIdx 0} {$colIdx < $numCols} {incr colIdx} {
                set colWidth [lindex $colWidths $colIdx]
                # Shorter cells end with empty lines.
                set colContent [lindex $cells $colIdx $lineIdx]

                if {$colContent eq ""} {
                    set paddedContent [string repeat " " $colWidth]
                } else {
                    set justify [dict get $_column_options $colIdx justify]
                    set paddedContent [zesty::alignText \
                        "$padding$colContent$padding" $colWidth $justify]
                }

                append line [zesty::parseStyleDictToXML $paddedContent [lindex $styles $colIdx]]

                if {($colIdx < $numCols - 1) && $lines_show} {
                    append line $vertical
                }
            }

            if {$showEdge} {
                append line $edge
            }

            append result "$line\n"
        }

        return $result
    }

    method RenderHeader {colWidths boxChars} {
        # Renders table header with column names.
        #
        # colWidths - list of column widths
        # boxChars  - dictionary of box characters
        #
        # Returns formatted header string.

        if {![dict get $_options header show]} {
            return ""
        }

        set pad [dict get $_options padding]
        set numCols [dict size $_column_options]

        # Prepare headers: each line of a multi-line header is
        # truncated on its own.
        set cells {}
        set height 1

        for {set i 0} {$i < $numCols} {incr i} {
            set availableWidth [expr {[lindex $colWidths $i] - 2 * $pad}]

            if {$availableWidth <= 0} {
                lappend cells [list ""]
            } else {
                lappend cells [my WrapCell [dict get $_column_options $i name] $availableWidth 1]
            }
            set height [expr {max($height, [llength [lindex $cells end]])}]
        }

        set styles [lrepeat $numCols [dict get $_options header style]]

        return [my CellLines $cells $height $colWidths $styles $boxChars]
    }

    method RenderHeaderSeparator {colWidths boxChars} {
        # Renders separator line after header.
        #
        # colWidths - list of column widths
        # boxChars  - dictionary of box characters
        #
        # Returns formatted separator string.

        if {![dict get $_options header show] || ![my ShowSeparator header]} {
            return ""
        }

        return [my RenderSeparator $colWidths $boxChars]
    }

    method ShowSeparator {part} {
        # Checks if the separator of a table part is drawn. 'auto'
        # keeps the default behavior: the header separator is drawn
        # only with edges, the footer separator always.
        #
        # part - 'header' or 'footer'
        #
        # Returns 1 if the separator is drawn, 0 otherwise.
        set value [dict get $_options $part separator]

        if {$value eq "auto"} {
            return [expr {($part eq "footer") || [dict get $_options showEdge]}]
        }

        return [string is true $value]
    }

    method ProcessRows {colWidths} {
        # Processes all rows for rendering with proper wrapping and alignment.
        #
        # colWidths - list of column widths
        #
        # Returns list of processed rows with height and aligned cells.

        set processedRows {}
        set numCols [dict size $_column_options]
        set pad [dict get $_options padding]

        foreach row $_rows {
            set processedCells {}
            set rowHeight 1

            for {set i 0} {$i < $numCols} {incr i} {
                set content [lindex $row $i]
                if {$content eq ""} {set content " "}

                set colWidth [expr {[lindex $colWidths $i] - 2 * $pad}]
                set nowrap [dict get $_column_options $i noWrap]
                set wrappedContent [my WrapCell $content $colWidth $nowrap]

                set rowHeight [expr {max($rowHeight, [llength $wrappedContent])}]
                lappend processedCells $wrappedContent
            }

            # Vertically align all cells in the row
            set alignedCells {}
            for {set i 0} {$i < $numCols} {incr i} {
                set vertical [dict get $_column_options $i vertical]
                set cellContent [lindex $processedCells $i]
                set alignedContent [my AlignCellContentVertical $cellContent $rowHeight $vertical]
                lappend alignedCells $alignedContent
            }

            lappend processedRows [list $rowHeight $alignedCells]
        }

        return $processedRows
    }

    method RenderDataRows {processedRows colWidths boxChars} {
        # Renders all data rows with proper formatting.
        #
        # processedRows - processed row data with height and cells
        # colWidths     - column widths
        # boxChars      - dictionary of box characters
        #
        # Returns formatted data rows string.

        set styles {}
        for {set i 0} {$i < [dict size $_column_options]} {incr i} {
            lappend styles [dict get $_column_options $i style]
        }

        set result ""
        foreach processedRow $processedRows {
            lassign $processedRow rowHeight alignedCells
            append result [my CellLines $alignedCells $rowHeight $colWidths $styles $boxChars]
        }

        return $result
    }

    method RenderCaption {tableWidth} {
        # Renders table caption.
        #
        # tableWidth - total table width
        #
        # Returns formatted caption string.

        set caption_name [zesty::ExpandTabs [dict get $_options caption name]]
        if {$caption_name eq ""} {
            return ""
        }

        set caption_style [dict get $_options caption style]
        set captionLine ""

        # Apply wrapping to caption
        set maxCaptionWidth [expr {$tableWidth - 2}]
        set wrappedCaption [zesty::wrapText $caption_name $maxCaptionWidth 0]

        # Each line is styled on its own, so that the caption can be
        # split into lines (scrolling modes) without breaking tags.
        foreach line $wrappedCaption {
            set paddedLine [zesty::alignText $line $tableWidth [dict get $_options caption justify]]
            append captionLine "[zesty::parseStyleDictToXML $paddedLine $caption_style]\n"
        }

        return $captionLine
    }

    method RenderFooter {colWidths boxChars} {
        # Renders table footer row(s).
        #
        # colWidths - list of column widths
        # boxChars  - dictionary of box characters
        #
        # Returns formatted footer string.

        if {![dict get $_options footer show] || ![llength $_footer]} {
            return ""
        }

        set result ""
        set pad [dict get $_options padding]
        set numCols [dict size $_column_options]

        # Separate footer from data if enabled
        if {[my ShowSeparator footer]} {
            append result [my RenderSeparator $colWidths $boxChars]
        }

        # Prepare footer cells with wrapping
        set cells {}
        set height 1

        for {set i 0} {$i < $numCols} {incr i} {
            set cellContent [lindex $_footer $i]
            set availableWidth [expr {[lindex $colWidths $i] - 2 * $pad}]

            if {$availableWidth <= 0 || $cellContent eq ""} {
                lappend cells [list " "]
            } else {
                lappend cells [my WrapCell $cellContent $availableWidth 0]
            }
            set height [expr {max($height, [llength [lindex $cells end]])}]
        }

        set styles [lrepeat $numCols [dict get $_options footer style]]
        append result [my CellLines $cells $height $colWidths $styles $boxChars]

        return $result
    }

    method RenderParts {{colWidths ""}} {
        # Renders the table as three lists of lines: the fixed header
        # (title, top border, column headers), the data rows, and the
        # fixed footer (footer rows, bottom border, caption). The
        # scrolling modes keep the header and footer visible.
        #
        # colWidths - column widths to use (see ColumnWidths), empty
        #             to compute them from the rows
        #
        # Returns list of: headerLines dataLines footerLines

        # Get box characters
        set boxChars [my GetBoxCharacters]

        set title [zesty::ExpandTabs [dict get $_options title name]]
        if {$colWidths eq ""} {
            set colWidths [my ColumnWidths]
        }

        # Calculate total table width
        set tableWidth [my CalculateTotalTableWidth $colWidths]

        # Title, top border and header
        set header [my RenderTitle $title $tableWidth $boxChars]
        append header [my RenderTopBorder \
            $colWidths \
            [expr {$title ne ""}] \
            $boxChars
        ]
        append header [my RenderHeader $colWidths $boxChars]
        append header [my RenderHeaderSeparator $colWidths $boxChars]

        # Data rows
        set processedRows [my ProcessRows $colWidths]
        set data [my RenderDataRows $processedRows $colWidths $boxChars]

        # Footer, bottom border and caption
        set footer [my RenderFooter $colWidths $boxChars]
        append footer [my RenderBottomBorder $colWidths $boxChars]
        append footer [my RenderCaption $tableWidth]

        # Each part ends with a newline: remove it before splitting.
        set parts {}
        foreach part [list $header $data $footer] {
            lappend parts [split [string range $part 0 end-1] "\n"]
        }

        return $parts
    }

    method ColumnWidths {} {
        # Calculates the column widths of the table, adjusted for the
        # title.
        #
        # Returns list of column widths including padding.
        set colWidths [my CalculateTableColumnWidths]
        set title [zesty::ExpandTabs [dict get $_options title name]]

        return [my AdjustColumnsForTitle $colWidths $title]
    }

    method render {} {
        # Renders the complete table as formatted text.
        #
        # Returns fully formatted table as string with borders, headers,
        # content rows, and optional title/caption.

        set lines [concat {*}[my RenderParts]]
        if {![llength $lines]} {
            return ""
        }

        return "[join $lines "\n"]\n"
    }

    method display {} {
        # Displays the table using appropriate scrolling method.
        # Determines if scrolling is needed based on content size and
        # terminal height, then applies the configured display method.
        # Falls back to normal display if content fits in terminal.
        #
        # Returns nothing.

        lassign [my RenderParts] header data footer
        set lines [concat $header $data $footer]
        set fullContent "[join $lines "\n"]\n"

        # The table is followed by an empty line and the cursor line,
        # hence the 2 lines kept free.
        if {[llength $lines] <= $_termHeight - 2} {
            zesty::echo $fullContent
        } elseif {[dict get $_options autoScroll]} {
            my DisplayWithScroll $header $data $footer
        } elseif {[dict get $_options pageScroll]} {
            my PagedDisplay $header $data $footer
        } elseif {[dict get $_options continuousScroll]} {
            my ContinuousScroll $header $data $footer
        } else {
            zesty::echo $fullContent
        }
        return {}
    }
}