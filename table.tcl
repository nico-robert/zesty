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
    variable _tablestyles
    variable _col_index

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
        # footer           - Show table footer (not implemented yet)
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
        set _col_index -1
        set _isWindows  [zesty::isWindows]
        set size        [zesty::getTerminalSize]
        set _termWidth  [lindex $size 0]
        set _termHeight [lindex $size 1]

        # Table options
        set _options {
            title {
                name ""
                justify "center"
                style {}
            }
            caption {
                name ""
                justify "center"
                style {}
            }
            box {
                type "rounded"
                style {}
            }
            padding 1
            showEdge 1
            lines {
                show 1
                style {}
            }
            header {
                show 1
                style {}
            }
            footer {
                show 1
                style {}
            }
            keyPgup "p"
            keyPgdn "f"
            keyQuit "q"
            maxVisibleLines 0
            autoScroll 0     
            pageScroll 0     
            continuousScroll 0     
        }

        set _column_configs {
            name ""
            style {}
            justify "left"
            vertical "middle"
            width 0
            minWidth 0
            maxWidth 0
            noWrap 0
        }
        
        set _tablestyles {
            single  {┌ ┐ └ ┘ │ ─ ┼ ┬ ┴ ├ ┤}
            double  {╔ ╗ ╚ ╝ ║ ═ ╬ ╦ ╩ ╠ ╣}
            rounded {╭ ╮ ╰ ╯ │ ─ ┼ ┬ ┴ ├ ┤}
            thick   {┏ ┓ ┗ ┛ ┃ ━ ┃ ┳ ┻ ┣ ┫}
            ascii   {+ + + + | - + + + + +}
        }

        my ConfigureTable {*}$args
    }

    method ConfigureTable {args} {
        # Validates and applies configuration options for table
        # appearance, behavior, and interaction settings.
        #
        # args - Configuration arguments in key-value pairs
        #
        # Returns nothing.
        foreach {key value} $args {
            switch -exact -- $key {
                -keyPgup          -
                -keyPgdn          -
                -keyQuit          -
                -showEdge         -
                -pageScroll       -
                -continuousScroll -
                -autoScroll {dict set _options [string trimleft $key "-"] $value}
                -padding    {
                    zesty::isPositiveIntegerValue $key $value
                    dict set _options padding $value
                }
                -maxVisibleLines    {
                    zesty::isPositiveIntegerValue $key $value
                    dict set _options maxVisibleLines $value
                }
                -title  - 
                -caption {
                    zesty::validateKeyValuePairs "$key" $value
                    set key [string trimleft $key "-"]

                    foreach {skey svalue} $value {
                        switch -exact -- $skey {
                            name     {dict set _options $key $skey $svalue}
                            style    {
                                zesty::validateKeyValuePairs "$skey" $svalue
                                dict set _options $key $skey $svalue
                            }
                            justify  {
                                set titleJustify {"center" "left" "right"}
                                if {$svalue ni $titleJustify} {
                                    set keyType [format {%s or %s.} \
                                        [join [lrange $titleJustify 0 end-1] ", "] \
                                        [lindex $titleJustify end] \
                                    ]
                                    zesty::throwError "'$svalue' must be one of: $keyType"
                                }
                                dict set _options $key $skey $svalue
                            }
                            default {zesty::throwError "'$skey' not supported."}  
                        }
                    }
                }
                -box {
                    zesty::validateKeyValuePairs "$key" $value
                    foreach {skey svalue} $value {
                        switch -exact -- $skey {
                            type  {
                                set keys [dict keys $_tablestyles]
                                if {$svalue ni $keys} {
                                    set keyType [format {%s or %s.} \
                                        [join [lrange $keys 0 end-1] ", "] [lindex $keys end] \
                                    ]
                                    zesty::throwError "'$svalue' must be one of: $keyType"
                                }
                                dict set _options box $skey $svalue
                            }
                            style {
                                zesty::validateKeyValuePairs "$skey" $svalue
                                dict set _options box $skey $svalue
                            }
                            default {zesty::throwError "'$skey' not supported."}  
                        }
                    }
                }
                -lines  -
                -header -
                -footer {
                    zesty::validateKeyValuePairs "$key" $value
                    set key [string trimleft $key "-"]

                    foreach {skey svalue} $value {
                        switch -exact -- $skey {
                            show  {dict set _options $key $skey $svalue}
                            style {
                                zesty::validateKeyValuePairs "$skey" $svalue
                                dict set _options $key $skey $svalue
                            }
                            default {zesty::throwError "'$skey' not supported."}  
                        }
                    }
                }
                default {zesty::throwError "'$key' not supported."}  
            }
        }
        return {}
    }

    method PagedDisplay {fullContent} {
        # Displays table content with automatic page-based scrolling.
        #
        # fullContent - Complete rendered table content as string
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

        set contentLines [split $fullContent "\n"]
        set totalLines [llength $contentLines]
        
        # If table fits entirely in available space, display it directly
        if {$totalLines <= $availableHeight} {
            zesty::echo $fullContent
            return {}
        }
        
        # Analyze table structure to identify important parts
        set headerEndLine 0
        set footerStartLine $totalLines

        # Find line that separates header from content
        # (first line with "+" or "├" after header lines)
        set headerEndLine [zesty::findFirstPattern $contentLines $_tablestyles]
        if {$headerEndLine == -1} {set headerEndLine 0}
        # Find line that separates content from footer
        # (last line with "+" or "├" before footer lines)
        set footerStartLine [zesty::findLastPattern $contentLines $_tablestyles]
        if {$footerStartLine == -1} {set footerStartLine $totalLines}
    
        # Determine fixed and scrollable parts
        set headerLines [lrange $contentLines 0 $headerEndLine]
        set footerLines [lrange $contentLines $footerStartLine end]
        
        # Calculate available space for data between header and footer
        set dataStartLine [expr {$headerEndLine + 1}]
        set dataEndLine [expr {$footerStartLine - 1}]
        set dataLines [lrange $contentLines $dataStartLine $dataEndLine]
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
                if {$i < $totalDataLines} {
                    zesty::echo [lindex $dataLines $i]
                }
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
            
            # Read user input
            set input [string tolower [string trim [gets stdin]]]

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

    method ContinuousScroll {fullContent} {
        # Displays table content with line-by-line continuous scrolling.
        #
        # fullContent - Complete rendered table content as string
        #
        # Returns nothing.

        # Reserve one line for information
        set availableHeight [expr {$_termHeight - 2}]
        set contentLines [split $fullContent "\n"]
        set totalLines [llength $contentLines]
        
        # If table fits entirely in terminal, display it directly
        if {$totalLines <= $availableHeight} {
            zesty::echo $fullContent
            return {}
        }
        
        # Analyze structure to identify header part to keep visible
        set headerEndLine 0
        
        # Find line that separates header from content
        # (first line with "+" or "├" after header lines)
        set headerEndLine [zesty::findFirstPattern $contentLines $_tablestyles]
        if {$headerEndLine == -1} {set headerEndLine 0}
        
        # Fixed part (header)
        set headerLines [lrange $contentLines 0 $headerEndLine]
        set headerHeight [llength $headerLines]
        
        # Scrollable part (content)
        set dataLines [lrange $contentLines [expr {$headerEndLine + 1}] end]
        set totalDataLines [llength $dataLines]
        
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
                if {$i < $totalDataLines} {
                    zesty::echo [lindex $dataLines $i]
                }
            }

            set keyquit [dict get $_options keyQuit]
            set keypgup [dict get $_options keyPgup]
            set keypgdn [dict get $_options keyPgdn]
            
            # Display position information
            set cline [expr {$startLine + 1}]-[expr {$endLine + 1}]
            zesty::echo "-- Lines $cline of $totalDataLines | $keypgdn: down, $keypgup: up, $keyquit: quit --"

            # Read user input
            set input [string tolower [string trim [gets stdin]]]

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

        set colopts $_column_configs
        incr _col_index
        
        foreach {key value} $args {
            set key [string trimleft $key "-"]
            if {[dict exists $_column_configs $key]} {
                dict set colopts $key $value
            } else {
                zesty::throwError "Unknown column option: '$key'."
            }
        }

        if {![dict exists $_column_configs name]} {
            dict set colopts name "column:${_col_index}"
        }

        # Store column header and its options
        dict set _column_options $_col_index $colopts
        
        # Handle existing rows by adding empty cell for new column
        set numExistingRows [llength $_rows]
        if {$numExistingRows > 0} {
            for {set i 0} {$i < $numExistingRows} {incr i} {
                lappend _rows [lindex $_rows $i] ""
                set _rows [lreplace $_rows $i $i]
            }
        }
        
        return {}
    }

    method DisplayWithScroll {fullContent} {
        # Displays table content with automatic scroll detection.
        #
        # fullContent - Complete rendered table content as string
        #
        # Returns nothing.

        set contentLines [split $fullContent "\n"]
        set totalLines   [llength $contentLines]
        
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
            zesty::echo $fullContent
            return {}
        }
        
        # Number of lines to keep for fixed table parts (header, etc.)
        set headerRows 0
        
        # Identify header lines to preserve
        # (Title, top line and column headers)
        if {[dict get $_options title name] ne ""} {
            incr headerRows 2  ;# Title + top line
        } else {
            incr headerRows 1  ;# Only top line
        }
        
        if {[dict get $_options header show]} {
            # Calculate header height
            set headerHeight 1  ;# Minimum one line for column headers
            
            set pad [dict get $_options padding]

            # Find maximum height of column headers
            foreach col [dict keys $_column_options] {
                set colWidth 0
                # Find available width for this column
                foreach width [my CalculateTableColumnWidths] {
                    set colWidth [expr {$width - 2 * $pad}]
                    break
                }
                
                set lines [my WrapText $col $colWidth 0]
                set lineCount [llength $lines]
                if {$lineCount > $headerHeight} {
                    set headerHeight $lineCount
                }
            }
            
            incr headerRows $headerHeight
            # Add separator line under header
            incr headerRows
        }
        
        # Number of lines for table bottom (footer and bottom line)
        set footerRows 1  ;# At minimum the bottom line
        
        if {[dict get $_options footer show]} {
            incr footerRows  ;# Table footer line
        }

        set caption_name [dict get $_options caption name]
        
        if {$caption_name ne ""} {
            # Estimate number of lines for caption
            set captionWidth [expr {$tableWidth - 2}]
            set wrappedCaption [my WrapText $caption_name $captionWidth 0]
            incr footerRows [llength $wrappedCaption]
        }
        
        # Calculate number of lines available for scrollable content
        set contentRows [expr {$maxLines - $headerRows - $footerRows}]
        if {$contentRows < 5} {set contentRows 5}
        
        # Total number of "data" lines (without header or footer)
        set dataLines [expr {$totalLines - $headerRows - $footerRows}]
        
        # If not enough data to scroll, display normally
        if {$dataLines <= $contentRows} {
            zesty::echo $fullContent
            return {}
        }
        
        # Display different parts of the table
        # 1. Header (always visible)
        set headerContent {}
        for {set i 0} {$i < $headerRows} {incr i} {
            lappend headerContent [lindex $contentLines $i]
        }
        zesty::echo [join $headerContent "\n"]
        
        # 2. Content with scrolling
        for {set dataStart 0} {$dataStart <= $dataLines - $contentRows} {incr dataStart} {
            # Absolute position in complete table
            set start [expr {$headerRows + $dataStart}]
            set end [expr {$start + $contentRows - 1}]
            
            # Get and display visible segment
            set visibleContent {}
            for {set i $start} {$i <= $end} {incr i} {
                lappend visibleContent [lindex $contentLines $i]
            }
            zesty::echo [join $visibleContent "\n"]
            
            # 3. Table footer (always visible)
            set footerContent {}
            for {set i [expr {$totalLines - $footerRows}]} {$i < $totalLines} {incr i} {
                lappend footerContent [lindex $contentLines $i]
            }
            zesty::echo [join $footerContent "\n"]
            
            # Add progress indicator
            zesty::echo "-- Lines [expr {$dataStart + 1}]-[expr {$dataStart + $contentRows}] of $dataLines (Press Enter to continue, q to quit) --"
            
            # Wait for user input
            set input [string tolower [string trim [gets stdin]]]
            set keyquit [dict get $_options keyQuit]

            if {$input eq [string tolower $keyquit]} {
                break
            }
            
            # Clear screen for next page (except for last)
            if {$dataStart < $dataLines - $contentRows} {
                puts "\033\[H\033\[J"  ;# Clear screen and place cursor at top
                
                # Redisplay fixed header
                zesty::echo [join $headerContent "\n"]
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
            zesty::throwError "Too many arguments provided: $numArgs for $numCols columns"
        }
        
        # Padding with empty strings for missing columns
        set row $args
        while {[llength $row] < $numCols} {
            lappend row ""
        }
        
        lappend _rows $row

        return {}
    }

    method WrapText {text maxWidth {noWrap 0}} {
        # Wraps text to fit within specified width with ellipsis support.
        #
        # text - Text content to wrap
        # maxWidth - Maximum width in characters
        # noWrap - If true, truncate with ellipsis instead of wrapping
        #
        # Returns list of wrapped text lines. When noWrap is enabled,
        # truncates text and adds ellipsis if it exceeds maxWidth.

        # If text is already shorter than maximum width
        if {[zesty::strLength [zesty::extractVisibleText $text]] <= $maxWidth} {
            return [list $text]
        }

        # If noWrap is enabled, truncate with ellipsis instead of wrapping
        if {$noWrap} {
            # Reserve 3 characters for ellipsis "..."
            set ellipsisWidth 3
            set padding [dict get $_options padding]
            set truncateWidth [expr {($maxWidth - $ellipsisWidth) + ($padding * 2)}]
            
            # If width is too small to even display ellipsis
            if {$truncateWidth <= 0} {
                # Use only as many dots as possible
                set points [string repeat "." [expr {$maxWidth > 0 ? $maxWidth : 1}]]
                return [list $points]
            }

            # Add ellipsis
            set truncated [zesty::smartTruncateStyledText $text $truncateWidth 1]
            return [list $truncated]
        }
        
        # Rest of code for normal wrapping when noWrap is disabled
        set lines {}
        set currentLine ""
        
        set visible_text [zesty::extractVisibleText $text]

        # Split text into words
        if {[string first " " $visible_text] != -1} {
            set words [zesty::splitWithProtectedTags $text]

            foreach word $words {
                # Test if adding word exceeds max width
                set testLine "$currentLine $word"
                set testLine [string trimleft $testLine]
                set visibleline [zesty::extractVisibleText $testLine]
                
                if {
                    ([zesty::strLength $visibleline] <= $maxWidth)  || 
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

    method CalculateTableColumnWidths {} {
        # Calculates optimal column widths based on content and constraints.
        #
        # Returns list of column widths in characters including padding.

        set colWidths {}
        
        for {set i 0} {$i < [dict size $_column_options]} {incr i} {
            set colOpts [dict get $_column_options $i]
            
            set header [dict get $_column_options $i name]
            set headerLen [zesty::strLength $header]
            set maxContentLen 0
            
            # Find maximum content length
            foreach row $_rows {
                # Ensure row has sufficient elements
                if {$i < [llength $row]} {
                    set content [lindex $row $i]
                    # Handle multiple lines in a cell
                    if {[string first "\n" $content] != -1} {
                        foreach line [split $content "\n"] {
                            set lineLen [zesty::strLength \
                                [zesty::extractVisibleText $line]
                            ]
                            if {$lineLen > $maxContentLen} {
                                set maxContentLen $lineLen
                            }
                        }
                    } else {
                        set contentLen [zesty::strLength \
                            [zesty::extractVisibleText $content]
                        ]
                        if {$contentLen > $maxContentLen} {
                            set maxContentLen $contentLen
                        }
                    }
                }
            }
            
            # Calculate column width
            set width $maxContentLen
            if {$headerLen > $width} {
                set width $headerLen
            }

            set colWidth    [dict get $_column_options $i width]
            set colMaxWidth [dict get $_column_options $i maxWidth]
            set colMinWidth [dict get $_column_options $i minWidth]
            
            # Apply width constraints
            if {$colWidth > 0} {
                set width $colWidth
            } elseif {($colMaxWidth > 0) && ($width > $colMaxWidth)} {
                set width $colMaxWidth
            } elseif {($colMinWidth > 0) && ($width < $colMinWidth)} {
                set width $colMinWidth
            }
            
            # Add padding
            set pad [dict get $_options padding]
            set width [expr {$width + ($pad * 2)}]
            
            lappend colWidths $width
        }
        
        return $colWidths
    }

    method PadText {text width justify} {
        # Pads text to specified width with alignment.
        #
        # text    - Text content to pad
        # width   - Target width in characters
        # justify - Alignment: "left", "right", or "center"
        #
        # Returns text padded with spaces to achieve specified width
        # and alignment.

        set displayWidth [zesty::strLength [zesty::extractVisibleText $text]]
        set padLen [expr {$width - $displayWidth}]
        
        if {$padLen <= 0} {
            return $text
        }
        
        switch -exact -- $justify {
            "left" {
                return "$text[string repeat " " $padLen]"
            }
            "right" {
                return "[string repeat " " $padLen]$text"
            }
            "center" {
                set leftPad [expr {$padLen / 2}]
                set rightPad [expr {$padLen - $leftPad}]
                return "[string repeat " " $leftPad]$text[string repeat " " $rightPad]"
            }
            default {
                return "$text[string repeat " " $padLen]"
            }
        }
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

    method render {} {
        # Renders the complete table as formatted text.
        #
        # Returns fully formatted table as string with borders, headers,
        # content rows, and optional title/caption. Handles responsive
        # sizing and style application.

        set result ""
        set boxtype [dict get $_options box type]

        if {![dict exists $_tablestyles $boxtype]} {
            zesty::throwError "$boxtype is not a valid box type"
        }

        set boxchars [dict get $_tablestyles $boxtype]
        set tl  [lindex $boxchars 0]  ;# Top Left corner
        set tr  [lindex $boxchars 1]  ;# Top Right corner
        set bl  [lindex $boxchars 2]  ;# Bottom Left corner
        set br  [lindex $boxchars 3]  ;# Bottom Right corner
        set vl  [lindex $boxchars 4]  ;# Vertical line
        set hl  [lindex $boxchars 5]  ;# Horizontal line
        set xc  [lindex $boxchars 6]  ;# Cross center
        set tt  [lindex $boxchars 7]  ;# T-junction top
        set tb  [lindex $boxchars 8]  ;# T-junction bottom
        set tlj [lindex $boxchars 9]  ;# T-junction left
        set trj [lindex $boxchars 10] ;# T-junction right

        set colWidths [my CalculateTableColumnWidths]
        set numCols   [dict size $_column_options]
        set tableWidth 0
        
        foreach width $colWidths {
            incr tableWidth $width
        }

        set lines_show  [dict get $_options lines show]
        set lines_style [dict get $_options lines style]
        
        # Add width of column separators
        if {$lines_show} {
            incr tableWidth [expr {$numCols + 1}]
        } elseif {[dict get $_options showEdge]} {
            incr tableWidth 2
        }
        
        # Consider title width if present
        set title [dict get $_options title name]
        if {$title ne ""} {
            set titleWidth [zesty::strLength [zesty::extractVisibleText $title]]
            # Add 2 for minimal title padding
            set minTitleWidth [expr {$titleWidth + 2}]
            
            # If title is wider than table, adjust table width
            if {$minTitleWidth > $tableWidth} {
                # Calculate how much extra space is needed
                set extraSpace [expr {$minTitleWidth - $tableWidth}]
                # Distribute extra space equally among columns
                set extraPerCol [expr {$extraSpace / $numCols}]
                set remainder [expr {$extraSpace % $numCols}]
                
                # Update column widths
                for {set i 0} {$i < $numCols} {incr i} {
                    set currentWidth [lindex $colWidths $i]
                    set newWidth [expr {$currentWidth + $extraPerCol}]
                    # Distribute remainder to first columns
                    if {$i < $remainder} {
                        incr newWidth
                    }
                    lset colWidths $i $newWidth
                }
                
                # Recalculate total table width
                set tableWidth 0
                foreach width $colWidths {
                    incr tableWidth $width
                }
                if {$lines_show} {
                    incr tableWidth [expr {$numCols + 1}]
                } elseif {[dict get $_options showEdge]} {
                    incr tableWidth 2
                }
            }
        }
        
        # Resize if necessary (existing code continues)
        if {($_termWidth > 0) && ($tableWidth > $_termWidth)} {
            # Space needed for borders and separators
            set borderSpace 0
            if {$lines_show} {
                set borderSpace [expr {$numCols + 1}]
            } elseif {[dict get $_options showEdge]} {
                set borderSpace 2
            }
            
            # Actually available space for content
            set availableWidth [expr {$_termWidth - $borderSpace}]
            
            # 1. Prepare minimum width constraints for each column
            set minWidths {}
            set totalMinWidth 0
            set pad [dict get $_options padding]
            
            for {set i 0} {$i < $numCols} {incr i} {

                set minwidth [dict get $_column_options $i minWidth]
                
                # Absolute minimum = max(padding*2+3, specified minWidth + padding*2)
                set minWidth [expr {max(($pad*2 + 3), ($minwidth + $pad*2))}]
                lappend minWidths $minWidth
                incr totalMinWidth $minWidth
            }
            
            # 2. If even minimum widths exceed available space, force absolute minimum
            if {$totalMinWidth > $availableWidth} {
                # Distribute available space equally
                set equalWidth [expr {int($availableWidth / $numCols)}]
                if {$equalWidth < 5} {set equalWidth 5}
                
                set adjustedColWidths {}
                for {set i 0} {$i < $numCols} {incr i} {
                    lappend adjustedColWidths $equalWidth
                }
            } else {
                # 3. Calculate how much space we can allocate after guaranteeing minimums
                set excessSpace [expr {$availableWidth - $totalMinWidth}]
                
                # Calculate proportion of each column from its current width
                set totalAdjustableWidth 0
                foreach width $colWidths {
                    incr totalAdjustableWidth $width
                }
                
                # Distribute excess space proportionally
                set adjustedColWidths {}
                set remainingExcess $excessSpace
                
                for {set i 0} {$i < $numCols} {incr i} {
                    set colWidth [lindex $colWidths $i]
                    set minWidth [lindex $minWidths $i]
                    
                    # Calculate proportional share of excess space
                    set share 0
                    if {$totalAdjustableWidth > 0} {
                        set share [expr {int(double($colWidth) / $totalAdjustableWidth * $excessSpace)}]
                    }
                    
                    # Ensure we don't exceed remaining space
                    if {$share > $remainingExcess} {
                        set share $remainingExcess
                    }
                    
                    # New width is minimum plus proportional share
                    set newWidth [expr {$minWidth + $share}]
                    lappend adjustedColWidths $newWidth
                    
                    # Update remaining excess space
                    set remainingExcess [expr {$remainingExcess - $share}]
                }
                
                # Distribute any remaining space to first columns
                for {set i 0} {$i < $numCols && $remainingExcess > 0} {incr i} {
                    lset adjustedColWidths $i [expr {[lindex $adjustedColWidths $i] + 1}]
                    incr remainingExcess -1
                }
            }

            set colWidths $adjustedColWidths
            
            # Recalculate total table width
            set tableWidth $borderSpace
            foreach width $adjustedColWidths {
                incr tableWidth $width
            }
        }
        
        # Display title (now that tableWidth is correctly calculated)
        if {$title ne ""} {
            set titleLine ""
            if {[dict get $_options showEdge]} {
                set hl_l [string repeat $hl [expr {$tableWidth - 2}]]
                append titleLine [zesty::parseStyleDictToXML $tl $lines_style]
                append titleLine [zesty::parseStyleDictToXML $hl_l $lines_style]
                append titleLine [zesty::parseStyleDictToXML $tr $lines_style]
                append titleLine "\n"
            }

            set title_justify [dict get $_options title justify]
            set paddedTitle [my PadText $title [expr {$tableWidth - 2}] $title_justify]
            set title_style [dict get $_options title style]

            set paddedTitle [zesty::parseStyleDictToXML $paddedTitle $title_style]
            
            if {[dict get $_options showEdge]} {
                append titleLine [zesty::parseStyleDictToXML $vl $lines_style]
                append titleLine $paddedTitle
                append titleLine [zesty::parseStyleDictToXML $vl $lines_style]
                append titleLine "\n"
            } else {
                append titleLine " $paddedTitle \n"
            }
            
            append result $titleLine
        }
        
        # Top line
        set topLine ""
        if {[dict get $_options showEdge]} {
            # If we have a title, use appropriate junction characters
            if {$title ne ""} {
                append topLine $tlj  ;# Left junction
            } else {
                append topLine $tl  ;# Top left corner
            }

            for {set i 0} {$i < $numCols} {incr i} {
                append topLine [string repeat $hl [lindex $colWidths $i]]
                
                if {$i < [expr {$numCols - 1}] && $lines_show} {
                    # Use correct junction character
                    if {$title ne ""} {
                        append topLine $tt  ;# T-junction top
                    } else {
                        append topLine $tt  ;# Normal junction
                    }
                }
            }

            # If we have a title, use appropriate junction characters
            if {$title ne ""} {
                append topLine $trj  ;# Right junction
            } else {
                append topLine $tr  ;# Top right corner
            }

            set topLine [zesty::parseStyleDictToXML $topLine $lines_style]
            
            append result "$topLine\n"

        }
        
        # Prepare column headers
        set headerLines {}
        set maxHeaderHeight 1
        set pad [dict get $_options padding]
        for {set i 0} {$i < $numCols} {incr i} {

            set colWidth   [expr {[lindex $colWidths $i] - 2 * $pad}]
            set nowrap     [dict get $_column_options $i noWrap]
            set headerText [dict get $_column_options $i name]
            
            # Apply same treatment as for cell content
            # respecting noWrap option for headers too
            set wrappedHeader [my WrapText $headerText $colWidth $nowrap]
            
            # Update maximum header height
            set headerHeight [llength $wrappedHeader]
            if {$headerHeight > $maxHeaderHeight} {
                set maxHeaderHeight $headerHeight
            }
            
            lappend headerLines $wrappedHeader
        }
        
        # Header
        if {[dict get $_options header show]} {
            set header_style [dict get $_options header style]
            # Display multiline header
            for {set lineIdx 0} {$lineIdx < $maxHeaderHeight} {incr lineIdx} {
                set headerLine ""
                if {[dict get $_options showEdge]} {
                    append headerLine [zesty::parseStyleDictToXML $vl $lines_style]
                }
                
                for {set colIdx 0} {$colIdx < $numCols} {incr colIdx} {
                    
                    set colWidth [lindex $colWidths $colIdx]
                    set colContent ""
                    if {$lineIdx < [llength [lindex $headerLines $colIdx]]} {
                        set colContent [lindex $headerLines $colIdx $lineIdx]
                    }
                    
                    if {$colContent eq ""} {
                        set colContent [string repeat " " $colWidth]
                    }

                    set justify [dict get $_column_options $colIdx justify]
                    
                    # Padding
                    set padding [string repeat " " $pad]
                    set paddedContent "$padding$colContent$padding"
                    set paddedContent [my PadText $paddedContent $colWidth $justify]

                    append headerLine [zesty::parseStyleDictToXML $paddedContent $header_style]
                    
                    if {$colIdx < [expr {$numCols - 1}] && $lines_show} {
                        append headerLine [zesty::parseStyleDictToXML $vl $lines_style]
                    }
                }
                
                if {[dict get $_options showEdge]} {
                    append headerLine [zesty::parseStyleDictToXML $vl $lines_style]
                }
                
                append result "$headerLine\n"
            }
            
            # Separator line after header
            set sepLine ""
            if {[dict get $_options showEdge]} {
                append sepLine $tlj
                for {set i 0} {$i < $numCols} {incr i} {
                    append sepLine [string repeat $hl [lindex $colWidths $i]]
                    if {$i < [expr {$numCols - 1}] && $lines_show} {
                        append sepLine $xc
                    }
                }

                if {[dict get $_options showEdge]} {
                    append sepLine $trj
                }

                set sepLine [zesty::parseStyleDictToXML $sepLine $lines_style]
                append result "$sepLine\n"
            }
        }
        
        # Prepare cell contents
        set processedRows {}
        
        foreach row $_rows {
            set processedCells {}
            set rowHeight 1
            
            for {set i 0} {$i < $numCols} {incr i} {                
                set content [lindex $row $i]
                if {$content eq ""} {set content " "}
                
                set colWidth [expr {[lindex $colWidths $i] - 2 * [dict get $_options padding]}]
                set wrappedContent {}

                set nowrap [dict get $_column_options $i noWrap]
                
                # Handle manual line breaks first
                if {[string first "\n" $content] != -1} {
                    set lines [split $content "\n"]
                    foreach line $lines {
                        # Wrap each line individually
                        set wrapped [my WrapText $line $colWidth $nowrap]
                        foreach wline $wrapped {
                            lappend wrappedContent $wline
                        }
                    }
                } else {
                    # Wrap content normally
                    set wrappedContent [my WrapText $content $colWidth $nowrap]
                }
                
                # Update line height
                set cellHeight [llength $wrappedContent]
                if {$cellHeight > $rowHeight} {
                    set rowHeight $cellHeight
                }
                
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
        
        # Display content rows
        foreach processedRow $processedRows {
            set rowHeight [lindex $processedRow 0]
            set alignedCells [lindex $processedRow 1]
            
            for {set lineIdx 0} {$lineIdx < $rowHeight} {incr lineIdx} {
                set rowLine ""
                if {[dict get $_options showEdge]} {
                    append rowLine [zesty::parseStyleDictToXML $vl $lines_style]
                }
                
                for {set colIdx 0} {$colIdx < $numCols} {incr colIdx} {

                    set col_style [dict get $_column_options $colIdx style]
                    
                    set colWidth [lindex $colWidths $colIdx]
                    set colContent ""
                    if {$lineIdx < [llength [lindex $alignedCells $colIdx]]} {
                        set colContent [lindex $alignedCells $colIdx $lineIdx]
                    }

                    set justify [dict get $_column_options $colIdx justify]
                    
                    # Padding
                    set padding [string repeat " " [dict get $_options padding]]
                    set paddedContent "$padding$colContent$padding"
                    set paddedContent [my PadText $paddedContent $colWidth $justify]

                    append rowLine [zesty::parseStyleDictToXML $paddedContent $col_style]
                    
                    if {$colIdx < [expr {$numCols - 1}] && $lines_show} {
                        append rowLine [zesty::parseStyleDictToXML $vl $lines_style]
                    }
                }
                
                if {[dict get $_options showEdge]} {
                    append rowLine [zesty::parseStyleDictToXML $vl $lines_style]
                }
                
                append result "$rowLine\n"
            }
        }
        
        # Bottom line
        set bottomLine ""
        if {[dict get $_options showEdge]} {
            append bottomLine $bl

            for {set i 0} {$i < $numCols} {incr i} {
                append bottomLine [string repeat $hl [lindex $colWidths $i]]
                
                if {$i < [expr {$numCols - 1}] && $lines_show} {
                    append bottomLine $tb
                }
            }
            append bottomLine $br
            set bottomLine [zesty::parseStyleDictToXML $bottomLine $lines_style]
            append result "$bottomLine\n"
        }

        # Display caption
        set caption_name  [dict get $_options caption name]
        set caption_style [dict get $_options caption style]
        if {$caption_name ne ""} {
            set captionLine ""
            
            # Apply wrapping to caption
            set maxCaptionWidth [expr {$tableWidth - 2}]
            set wrappedCaption [my WrapText $caption_name $maxCaptionWidth 0]
            
            foreach line $wrappedCaption {
                set paddedLine [my PadText $line $tableWidth [dict get $_options caption justify]]
                append captionLine "$paddedLine\n"
            }

            append result [zesty::parseStyleDictToXML $captionLine $caption_style]
        }
        
        return $result
    }

    method display {} {
        # Displays the table using appropriate scrolling method.
        # Determines if scrolling is needed based on content size and
        # terminal height, then applies the configured display method.
        # Falls back to normal display if content fits in terminal.
        #
        # Returns nothing.

        # Get complete table rendering
        set fullContent  [my render]
        set contentLines [split $fullContent "\n"]
        set totalLines   [llength $contentLines]

        # If content fits in terminal or scrolling is disabled.
        if {$totalLines <= $_termHeight} {
            zesty::echo $fullContent
        } elseif {[dict get $_options autoScroll]} {
            zesty::echo [my DisplayWithScroll $fullContent]
        } elseif {[dict get $_options pageScroll]} {
            zesty::echo [my PagedDisplay $fullContent]
        } elseif {[dict get $_options continuousScroll]} {
            zesty::echo [my ContinuousScroll $fullContent]
        } else {
            zesty::echo $fullContent
        }
        return {}
    }
}