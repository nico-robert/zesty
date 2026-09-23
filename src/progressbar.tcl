# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {}

oo::class create zesty::Bar {
    # Progress bar class with multiple column types, animations,
    # and customizable display options. Supports determinate and
    # indeterminate progress modes with various spinner styles.
    
    variable _tasks
    variable _task_index
    variable _all_tasks_completed
    variable _term_width
    variable _term_height
    variable _options
    variable _header_configs
    variable _column_configs
    variable _count_timer_id
    variable _time_timer_id
    variable _spinner_timer_id
    variable _indeterminate_timer_id
    variable _custom_timer_id
    variable _has_spinner_column
    variable _handle
    variable _cache_valid
    variable _column_widths_cache
    variable _isWindows

    constructor {args} {
        # Initialize progress bar with configurable options.
        #
        # args - configuration options in key-value pairs:
        #   -minColumnWidth          - minimum column width
        #   -minBarWidth             - minimum progress bar width
        #   -ellipsisThreshold       - threshold for ellipsis display
        #   -barChar                 - character for progress bar fill
        #   -bgBarChar               - character for progress bar background
        #   -leftBarDelimiter        - left delimiter for progress bar
        #   -rightBarDelimiter       - right delimiter for progress bar
        #   -indeterminateBarStyle   - animation style for indeterminate mode
        #   -spinnerFrequency        - spinner update frequency in ms
        #   -indeterminateSpeed      - animation speed
        #   -setColumns              - custom column configuration
        #   -colorBarChar            - color for progress bar fill
        #   -colorBgBarChar          - color for progress bar background
        #   -headers                 - custom header configuration
        #   -lineHSeparator          - custom header separator configuration
        
        # Initialize variables
        set _tasks {}
        set _all_tasks_completed 0
        set _task_index 0
        set _count_timer_id ""
        set _time_timer_id ""
        set _spinner_timer_id ""
        set _indeterminate_timer_id ""
        set _custom_timer_id ""
        set _handle "null"
        set _cache_valid 0
        set _column_widths_cache {}
        set _header_configs {}
        set _column_configs {}
        set _isWindows 0

        # Default options
        zesty::def _options "-headers" -validvalue formatVKVP  -type struct -with {
            show    -validvalue formatVBool  -type any       -default "false"
            set     -validvalue formatHSets  -type any|none  -default ""
        }
        zesty::def _options "-lineHSeparator" -validvalue formatVKVP -type struct -with {
            show    -validvalue formatVBool  -type any       -default "false"
            style   -validvalue formatStyle  -type any|none  -default ""
            char    -validvalue formatLChar  -type any       -default "─"
        }
        zesty::def _options "-minColumnWidth"         -validvalue formatMCWidth  -type num           -default 5
        zesty::def _options "-minBarWidth"            -validvalue formatMBWidth  -type num           -default 10
        zesty::def _options "-ellipsisThreshold"      -validvalue {}             -type num           -default 4
        zesty::def _options "-barChar"                -validvalue {}             -type str           -default "━"
        zesty::def _options "-bgBarChar"              -validvalue {}             -type str           -default "━"
        zesty::def _options "-leftBarDelimiter"       -validvalue {}             -type str|none      -default ""
        zesty::def _options "-rightBarDelimiter"      -validvalue {}             -type str|none      -default ""
        zesty::def _options "-indeterminateBarStyle"  -validvalue formatIBStyle  -type str           -default "bounce"
        zesty::def _options "-spinnerFrequency"       -validvalue formatSFreq    -type num           -default 100
        zesty::def _options "-indeterminateSpeed"     -validvalue formatIBSpeed  -type num           -default -2
        zesty::def _options "-colorBarChar"           -validvalue {}             -type str|num|none  -default "red"
        zesty::def _options "-colorBgBarChar"         -validvalue {}             -type str|num|none  -default "Gray80"
        zesty::def _options "-setColumns"             -validvalue {}             -type any|none      -default ""

        # Merge options and args
        set _options [zesty::merge $_options $args]

        # Default column configuration
        foreach {index type} {0 zName 1 zCount 2 zBar 3 zPercent 4 zElapsed 5 zRemaining} {
            my InitStandardColumn $index $type
        }
        
        # If setColumns option is defined, configure columns
        if {[dict get $_options setColumns] ne ""} {
            my ProcessSetColumns [dict get $_options setColumns]
        }

        # If setHeaders option is defined, configure headers
        if {
            [dict get $_options headers show] && 
            [dict get $_options headers set] ne ""
        } {
            my SetHeaders [dict get $_options headers set]
        }

        # Initialize terminal width + _handle (if Windows)
        my Init

        set _has_spinner_column [my HasSpinnerColumn]

    }
    
    destructor {
        # Cleanup progress bar system.
        #
        # Returns nothing
        classvar BARINSTANCE
        classvar ALLTASKS
        classvar TASK_POSITION
        classvar BARDISPLAY
        classvar MANAGING_INITIALIZED
        classvar INITIAL_CURSOR_POSITION
        classvar DISPLAYS_INITIALIZED
        
        if {[info exists BARINSTANCE] && ($BARINSTANCE > 0)} {
            incr BARINSTANCE -1
        }
        if {[info exists ALLTASKS] && ($ALLTASKS > 0)} {
            foreach taskId [dict keys $_tasks] {
                incr ALLTASKS -1
                if {!$ALLTASKS} {break}
            }
        }
        if {[info exists TASK_POSITION]} {
            foreach taskId [dict keys $_tasks] {
                set TASK_POSITION [dict remove $TASK_POSITION $taskId]
            }
        }
        if {[info exists BARDISPLAY] && ($BARDISPLAY > 0)} {
            incr BARDISPLAY -1
        }
        if {[info exists MANAGING_INITIALIZED] && ($MANAGING_INITIALIZED > 0)} {
            set MANAGING_INITIALIZED 0
        }
        
        if {[info exists DISPLAYS_INITIALIZED] && $DISPLAYS_INITIALIZED} {
            set DISPLAYS_INITIALIZED 0
        }
    }

    method getONSClass {} {
        # Returns the name of the internal namespace of the object.
        return [info object namespace [self class]]
    }

    method ConfigureHeader {column_num data} {
        # Configures header data for a specific column.
        # Throws error if column doesn't exist.
        #
        # column_num - column number to configure
        # data       - header configuration dictionary
        #
        # Returns: nothing.
        if {![dict exists $_column_configs $column_num]} {
            error "zesty(error): Column: '$column_num' does not exist."
        }
        dict set _header_configs $column_num $data
        
        return {}
    }

    method SetHeaders {config} {
        # Sets header configuration for multiple columns.
        # Throws error if headers not enabled or invalid format.
        #
        # config - dictionary of column headers in key-value pairs
        #
        # Returns: nothing.

        if {![dict get $_options headers show]} {
            error "zesty(error): Headers are not enabled"
        }

        foreach {key value} $config {
            my ConfigureHeader $key $value
        }
        
        return {}
    }

    method GetHeaderText {column_num} {
        # Header text configuration for a column.
        #
        # column_num - column number to get header for
        #
        # Returns header configuration dict with name, align, and style.
        # Uses default headers based on column type if not configured.

        if {[dict exists $_header_configs $column_num]} {
            return [dict get $_header_configs $column_num]
        }

        # Default headers according to type
        set type [dict get $_column_configs $column_num type]
        switch -exact -- $type {
            "zName"      {return {name "Task"     align left   style ""}}
            "zCount"     {return {name "Count"    align center style ""}}
            "zBar"       {return {name "Progress" align center style ""}}
            "zPercent"   {return {name "%"        align center style ""}}
            "zElapsed"   {return {name "Elapsed"  align left   style ""}}
            "zRemaining" {return {name "ETA"      align center style ""}}
            "zSpinner"   -
            "zSeparator" {return {name "" align center style ""}}
            default      {return [list name [string totitle $type] align left style ""]}
        }
    }

    method DisplayHeader {} {
        # Displays the header row with column titles.
        # Calculates column widths and formats header text according
        # to column configuration. Optionally displays separator line.
        #
        # Returns nothing

        set column_widths [my CalculateColumnWidths]
        
        # Create header line
        set header_line ""
        foreach {key value} $_column_configs {
            set config [dict get $_column_configs $key]
            if {[dict exists $config visible] && [dict get $config visible]} {
                set width [dict get $column_widths $key]
                set data  [my GetHeaderText $key]

                zesty::validateKeyValuePairs "data" $data
                
                if {![dict exists $data name]} {
                    error "zesty(error): header configuration\
                        must contain 'name' key"
                }

                set header_text [dict get $data name]
                
                if {![dict exists $data align]} {
                    set align "center"
                } else {
                    set align [dict get $data align]
                }

                zesty::validValue {} $header_text "formatAlign" $align
                
                # Special case for progress bar
                if {[dict get $config type] eq "zBar"} {
                    set l [dict get $_options leftBarDelimiter]
                    set r [dict get $_options rightBarDelimiter]
                    incr width [string length $l$r]
                }

                # Special case for separators
                if {[dict get $config type] eq "zSeparator"} {
                    set header_text ""
                    set align "center"
                }
                
                set frmtText [my FormatText $header_text $width $align]
                
                if {[dict exists $data style] && ([dict get $data style] ne "")} {
                    set frmtText [zesty::parseStyleDictToXML $frmtText [dict get $data style]]
                }

                append header_line $frmtText " "
            }
        }

        # Display header line
        zesty::echo $header_line
        
        # Optional separator line
        if {[dict get $_options lineHSeparator show]} {
            my DisplayHeaderLineSeparator
        }
        
        return {}
    }

    method DisplayHeaderLineSeparator {} {
        # Displays horizontal separator line under headers.
        # Creates line using configured separator character and style,
        # spanning the full width of all visible columns.
        #
        # Returns nothing

        set column_widths [my CalculateColumnWidths]
    
        foreach {key value} $_column_configs {
            set config [dict get $_column_configs $key]
            if {[dict exists $config visible] && [dict get $config visible]} {
                incr width [dict get $column_widths $key]
                
                # Special case for progress bar
                if {[dict get $config type] eq "zBar"} {
                    set l [dict get $_options leftBarDelimiter]
                    set r [dict get $_options rightBarDelimiter]
                    incr width [string length $l$r]
                }

                incr width 1
            }
        }
        incr width -1
        set style {}
        
        if {[dict get $_options lineHSeparator style] ne ""} {
            set style [dict get $_options lineHSeparator style]
        }
        
        set char [dict get $_options lineHSeparator char]
        zesty::echo [string repeat $char $width] -style $style
        
        return {}
    }
    
    method InitStandardColumn {index type} {
        # Initializes standard column configuration based on type.
        #
        # index - column index number
        # type  - column type
        #
        # Returns nothing
        switch -exact -- $type {
            "zName" {
                dict set _column_configs $index visible 1
                dict set _column_configs $index width 20
                dict set _column_configs $index type $type
                dict set _column_configs $index align left
            }
            "zCount" {
                dict set _column_configs $index visible 1
                dict set _column_configs $index width 15
                dict set _column_configs $index type $type
                dict set _column_configs $index align right
            }
            "zBar" {
                dict set _column_configs $index visible 1
                dict set _column_configs $index width 30
                dict set _column_configs $index type $type
                dict set _column_configs $index align left
            }
            "zPercent" {
                dict set _column_configs $index visible 1
                dict set _column_configs $index width 6
                dict set _column_configs $index type $type
                dict set _column_configs $index align right
            }
            "zElapsed" {
                dict set _column_configs $index visible 1
                dict set _column_configs $index width 15
                dict set _column_configs $index type $type
                dict set _column_configs $index align left
            }
            "zRemaining" {
                dict set _column_configs $index visible 1
                dict set _column_configs $index width 15
                dict set _column_configs $index type $type
                dict set _column_configs $index align right
            }
            "zSeparator" {
                dict set _column_configs $index visible 1
                dict set _column_configs $index width 1
                dict set _column_configs $index type $type
                dict set _column_configs $index char "|"
                dict set _column_configs $index align center
            }
            "zSpinner" {
                dict set _column_configs $index visible 1
                dict set _column_configs $index width 3
                dict set _column_configs $index type $type
                dict set _column_configs $index align center
                dict set _column_configs $index spinnerStyle "dots"
            }
            default {
                # Check if it's a command type
                if {[info commands $type] ne ""} {
                    dict set _column_configs $index visible 1
                    dict set _column_configs $index width 15
                    dict set _column_configs $index type $type
                    dict set _column_configs $index align left
                } else {
                    # Unknown type
                    error "zesty(error): A command must be associated\
                        with '$type' column type."
                }
            }
        }
        
        return {}
    }
    
    method RenderSpinner {task_id width} {
        # Renders animated spinner for a task.
        #
        # task_id - task identifier
        # width   - column width for spinner display
        #
        # Returns formatted spinner text centered in column width.

        set spinnerStyle "dots"
        # Check if specific style is defined for this column
        foreach num [dict keys $_column_configs] {
            if {[dict get $_column_configs $num type] eq "zSpinner"} {
                if {[dict exists $_column_configs $num spinnerStyle]} {
                    set spinnerStyle [dict get $_column_configs $num spinnerStyle]
                }
                break
            }
        }
        
        # Current position in animation
        set pos [dict get $_tasks $task_id anim_spin]
        
        if {![dict exists $::zesty::spinnerstyles $spinnerStyle]} {
            zesty::throwError "'$spinnerStyle' not supported."
        }
        
        set spinner_chars [dict get $::zesty::spinnerstyles $spinnerStyle]

        # Select current character in animation sequence
        set char_index   [expr {$pos % [llength $spinner_chars]}]
        set spinner_char [lindex $spinner_chars $char_index]
        
        # Use zesty::strLength to calculate visual width
        set visual_width [zesty::strLength $spinner_char]
        
        # If character's visual width exceeds available width,
        # return points.
        if {$visual_width > $width} {
            return [string repeat "." $width]
        }
        
        # Calculate padding taking visual width into account
        set total_padding [expr {$width - $visual_width}]
        set padding_left  [expr {int($total_padding / 2)}]
        set padding_right [expr {$total_padding - $padding_left}]
        
        # Create display with centered character
        set spinner_text ""
        append spinner_text [string repeat " " $padding_left]
        append spinner_text [lindex $spinner_chars $char_index]
        append spinner_text [string repeat " " $padding_right]
        
        # Using string length here because we want character length
        # to ensure our string is exactly $width characters
        set actual_length [zesty::strLength $spinner_text]
        
        if {$actual_length > $width} {
            # Truncate if too long
            set spinner_text [string range $spinner_text 0 $width-1]
        } elseif {$actual_length < $width} {
            # Add spaces if too short
            append spinner_text [string repeat " " [expr {$width - $actual_length}]]
        }
        
        return $spinner_text
    }
    
    method ProcessSetColumns {columns_list} {
        # Processes custom column configuration list.
        #
        # columns_list - list of column specifications, where each element
        #                can be either a simple type string or a list for
        #                separators with custom characters
        #
        # Returns nothing
        set _column_configs {}
        
        # Index for columns
        set num_col 0
        
        # Go through list of columns to configure
        foreach column $columns_list {
            # Check if it's a list or just a type
            if {[llength $column] > 1} {
                # If it's a list
                set first_elem [lindex $column 0]
                
                if {$first_elem ne "zSeparator"} {
                    error "zesty(error): Column '$num_col' should be a type 'zSeparator'"
                }
                # Format {zSeparator |} - separator with specified character
                set separator_char [lindex $column 1]
                
                # Create separator column
                dict set _column_configs $num_col visible 1
                dict set _column_configs $num_col width 1
                dict set _column_configs $num_col type "zSeparator"
                dict set _column_configs $num_col char $separator_char
                dict set _column_configs $num_col align center

            } else {
                # Simple format: just the type (zName, zCount, zBar, etc.)
                set column_type $column
                
                # Initialize standard column with specified type
                my InitStandardColumn $num_col $column_type
            }
            
            incr num_col
        }

        # Invalidate width cache
        set _cache_valid 0

        return {}
    }

    method Init {} {
        # Initializes the progress zBar system.
        # Sets up terminal detection, handles, display system,
        # and increments global instance counter.
        #
        # Returns nothing
        classvar BARINSTANCE

        set _isWindows [zesty::isWindows]

        if {$_isWindows} {
            set _handle [zesty::win32::getStdOutHandle]
        }

        lassign [zesty::getTerminalSize $_handle] _term_width _term_height

        # Ensure display system is initialized
        my InitDisplaySystem

        incr BARINSTANCE
        
        return {}
    }

    method configureColumn {numOrType args} {
        # Configures properties of an existing column.
        # Throws error if column doesn't exist or invalid options provided.
        #
        # numOrType  - column number or type to configure
        # args - configuration options in key-value pairs:
        #  -visible      - column visibility (boolean)
        #  -width        - column width (positive integer)
        #  -type         - column type
        #  -format       - custom format specification
        #  -align        - text alignment (left, right, center)
        #  -spinnerStyle - spinner animation style
        #  -style        - text styling options
        #
        # Returns nothing.

        set num "-"
        if {[string is integer -strict $numOrType]} {
            set num $numOrType
        } else {
            # Get column number from type
            foreach key [dict keys $_column_configs] {
                if {[dict get $_column_configs $key type] eq $numOrType} {
                    set num $key ; break
                }
            }
        }

        if {![dict exists $_column_configs $num]} {
            error "zesty(error): Column '$num' does not exist."
        }
        
        # Validate args
        zesty::validateKeyValuePairs "args" $args

        foreach {key value} $args {
            switch -exact -- $key {
                -visible {
                    zesty::validValue {} $key "formatVBool" $value
                    dict set _column_configs $num visible $value
                }
                -width   {
                    zesty::validValue {} $key "formatMCWidth" $value
                    dict set _column_configs $num width $value
                }
                -type   {dict set _column_configs $num type $value}
                -format {dict set _column_configs $num format $value}
                -align  {
                    zesty::validValue {} $key "formatAlign" $value
                    dict set _column_configs $num align $value
                } 
                -spinnerStyle {
                    if {![dict exists $::zesty::spinnerstyles $value]} {
                        error "zesty(error): spinnerStyle must be one of:\
                        [join [dict keys $::zesty::spinnerstyles] ","]"
                    }
                    dict set _column_configs $num spinnerStyle $value
                }
                -style {
                    zesty::validValue {} $key "formatStyle" $value
                    dict set _column_configs $num style $value
                }
                default  {error "zesty(error): Column option '$key' not supported"}
            }
        }

        set _has_spinner_column [my HasSpinnerColumn]
        set _cache_valid 0  ;# Invalidate cache
        
        return {}
    }
    
    method addColumn {num args} {
        # Creates new column with default settings and applies
        # provided configuration options.
        #
        # num  - column number (must not already exist)
        # args - configuration options (same as configureColumn)
        #        Must include -type option
        #
        # Returns nothing.
 
        if {[dict exists $_column_configs $num]} {
            error "zesty(error): Column '$num' already exists"
        }

        dict set _column_configs $num visible 1
        dict set _column_configs $num width 20
        dict set _column_configs $num align left
        
        my configureColumn $num {*}$args
        
        if {![dict exists $_column_configs $num type]} {
            error "zesty(error): Column 'type' must be specified\
                with '-type' option"
        }

        return {}
    }

    method addTask {args} {
        # Adds a new progress task to the display.
        #
        # args - task configuration options:
        #  -name      - task description/name
        #  -total     - total progress value (default: 100)
        #  -completed - current progress value (default: 0)
        #  -mode      - progress mode: "determinate" or "indeterminate"
        #  -animStyle - animation style for indeterminate mode
        #
        # Returns unique task identifier for future operations.
        classvar ALLTASKS
        classvar TASK_POSITION

        # Create new task ID
        incr _task_index ; incr ALLTASKS 
        set index   [self]::$_task_index
        set task_id [string cat "task" $index]
        
        set time [clock milliseconds]
        
        # Initialize task
        dict set _tasks $task_id description $task_id
        dict set _tasks $task_id total       100
        dict set _tasks $task_id completed   0
        dict set _tasks $task_id start_time  $time
        dict set _tasks $task_id last_update $time
        dict set _tasks $task_id mode        "determinate" ;# Default: determinate mode
        dict set _tasks $task_id anim_pos    0             ;# Animation position for indeterminate mode
        dict set _tasks $task_id anim_spin   0             ;# Animation position for spinner
        dict set _tasks $task_id animStyle  [dict get $_options indeterminateBarStyle] ;# Animation style
        dict set _tasks $task_id timer_running 0  ;# New flag to indicate if timer is running
        
        # Process constructor arguments
        foreach {key value} $args {
            switch -exact -- $key {
                -name  {dict set _tasks $task_id description $value}
                -total {
                    zesty::validValue {} $key "formatTTask" $value
                    dict set _tasks $task_id total $value
                }
                -completed {
                    zesty::validValue {} $key "formatCTask" $value
                    dict set _tasks $task_id completed $value
                }
                -mode  {
                    zesty::validValue {} $key "formatIBMode" $value
                    dict set _tasks $task_id mode $value
                }
                -animStyle {
                    zesty::validValue {} $key "formatIBStyle" $value
                    dict set _tasks $task_id animStyle $value
                }
                default {error "zesty(error): Task option '$key' not supported"}
            }
        }
        
        dict set TASK_POSITION $task_id [list row $ALLTASKS column 0]
        
        
        if {$_has_spinner_column || ([dict get $_tasks $task_id mode] eq "indeterminate")} {
            # Start automatic update for spinners and indeterminate bars
            after 16 [list [self] update $task_id]
        }
        
        return $task_id
    }

    method update {task_id args} {
        # Updates task progress and triggers display refresh.
        #
        # task_id - task identifier to update
        # args    - update options:
        #  -total       - new total value
        #  -completed   - new completed value
        #  -advance     - increment completed by this amount
        #  -mode        - change progress mode
        #  -description - update task description
        #
        # Returns nothing.

        if {![dict exists $_tasks $task_id]} {
            zesty::throwError "Task ID '$task_id' does not exist."
        }

        # Save old state to detect if task just completed
        set was_completed [expr {
            [dict get $_tasks $task_id completed] >= [dict get $_tasks $task_id total]
        }]

        foreach {key value} $args {
            switch -- $key {
                -total {
                    if {[catch {zesty::validValue {} $key "formatTTask" $value} err]} {
                        zesty::throwError $err
                    }
                    dict set _tasks $task_id total $value
                }
                -completed {
                    if {[catch {zesty::validValue {} $key "formatCTask" $value} err]} {
                        zesty::throwError $err
                    }
                    dict set _tasks $task_id completed $value
                    dict set _tasks $task_id mode "determinate"
                }
                -advance {
                    if {![string is integer -strict $value]} {
                        zesty::throwError "'$key' must be an integer"
                    }
                    dict set _tasks $task_id completed [expr {
                        [dict get $_tasks $task_id completed] + $value
                    }]
                }
                -mode  {
                    if {[catch {zesty::validValue {} $key "formatIBMode" $value} err]} {
                        zesty::throwError $err
                    }
                    dict set _tasks $task_id mode $value
                }
                -description {
                    dict set _tasks $task_id description $value
                }
                default {
                    zesty::throwError "Unknown key '$key'"
                }
            }
        }

        # Limit 'completed' to 'total'
        if {[dict get $_tasks $task_id completed] > [dict get $_tasks $task_id total]} {
            dict set _tasks $task_id completed [dict get $_tasks $task_id total]
        }

        # Update last update time
        dict set _tasks $task_id last_update [clock milliseconds]

        # Check if task just completed
        set is_completed [expr {
            [dict get $_tasks $task_id completed] >= [dict get $_tasks $task_id total]
        }]
        if {$is_completed && !$was_completed} {
            # Task just completed, record completion time
            dict set _tasks $task_id completion_time [clock milliseconds]
        }

        my Display

        return {}
    }
    
    method HasSpinnerColumn {} {
        # Checks if any spinner columns are visible.
        # Used to determine if spinner update timers needed.
        #
        # Returns 1 if at least one spinner column exists and is visible,
        # 0 otherwise.

        foreach num [dict keys $_column_configs] {
            if {
                [dict get $_column_configs $num type] eq "zSpinner" &&
                [dict exists $_column_configs $num visible] && 
                [dict get $_column_configs $num visible]
            } {
                return 1
            }
        }
        return 0
    }

    method advance {task_id {steps 1}} {
        # Advances task progress by specified number of steps.
        # Convenience method that calls update with -advance option.
        #
        # task_id - task identifier to advance
        # steps - number of steps to advance (default: 1)
        #
        # Returns nothing.
        if {![dict exists $_tasks $task_id]} {
            zesty::throwError "Task ID '$task_id' does not exist."
        }

        my update $task_id -advance $steps
        
        return {}
    }

    method percentage {task_id} {
        # Calculates completion percentage for a task.
        #
        # task_id - task identifier
        #
        # Returns percentage as floating point number (0.0-100.0)
        # or '0' if total is '0' or negative.

        if {[dict get $_tasks $task_id total] <= 0} {
            return 0
        }
        return [expr {
            (100.0 * [dict get $_tasks $task_id completed]) /
            double([dict get $_tasks $task_id total])
        }]
    }

    method elapsedTime {task_id} {
        # Calculates elapsed time for a task in seconds.
        #
        # task_id - task identifier
        #
        # Returns elapsed time as floating point seconds.

        if {[dict exists $_tasks $task_id completion_time]} {
            return [expr {
                ([dict get $_tasks $task_id completion_time] -
                [dict get $_tasks $task_id start_time]) / 1000.0
            }]
        } else {
            return [expr {
                ([clock milliseconds] - 
                [dict get $_tasks $task_id start_time]) / 1000.0
            }]
        }
    }

    method remainingTime {task_id} {
        # Estimates remaining time for task completion.
        #
        # task_id - task identifier
        #
        # Returns estimated remaining time in seconds as floating point,
        # or '0.0' if completed, '-1.0' if cannot estimate.
        
        set completed [dict get $_tasks $task_id completed]
        set total     [dict get $_tasks $task_id total]

        if {$completed >= $total} {return 0.0}

        set elapsed [my elapsedTime $task_id]
        if {$completed <= 0 || $elapsed <= 0} {
            return -1.0
        }

        set rate [expr {$completed / double($elapsed)}]

        return [expr {($total - $completed) / double($rate)}]
    }

    method formatTime {seconds} {
        # Formats time duration into readable string.
        #
        # seconds - time duration in seconds (floating point)
        #
        # Returns formatted string in HH:MM:SS.mmm format.

        if {$seconds < 0} {return "--:--:--.---"}

        set seconds_float $seconds
        set total_seconds [expr {int($seconds_float)}]
        set hours [expr {$total_seconds / 3600}]
        set remaining_seconds [expr {$total_seconds % 3600}]
        set minutes [expr {$remaining_seconds / 60}]
        set secs [expr {$remaining_seconds % 60}]
        set milliseconds [expr {int(round(($seconds_float - int($seconds_float)) * 1000))}]

        return [format "%d:%02d:%02d.%03d" $hours $minutes $secs $milliseconds]
    }

    method renderBar {task_id width percent bg_color fg_color} {
        # Renders progress bar for a task.
        #
        # task_id  - task identifier
        # width    - bar width in characters
        # percent  - completion percentage (0-100)
        # bg_color - background color
        # fg_color - foreground color
        #
        # Returns formatted progress bar string with colors applied.

        set mode [dict get $_tasks $task_id mode]
        
        if {$mode eq "determinate"} {
            # Determinate mode - existing code
            set completed_width [expr {int($width * $percent / 100.0)}]
            set ld [dict get $_options leftBarDelimiter]
            set rd [dict get $_options rightBarDelimiter]

            # Create bar
            set bar ""
            set b  [string repeat [dict get $_options barChar] $completed_width]
            set bg [string repeat [dict get $_options bgBarChar] [expr {$width - $completed_width}]]

            append bar [zesty::parseStyleDictToXML $b  [list fg $fg_color]]
            append bar [zesty::parseStyleDictToXML $bg [list fg $bg_color]]

            return ${ld}${bar}${rd}

        } else {
            # Indeterminate mode - different animation styles
            set anim_style [dict get $_tasks $task_id animStyle]
            set pos [dict get $_tasks $task_id anim_pos]
            set speed [dict get $_options indeterminateSpeed]
            
            # Call method corresponding to animation style
            switch -exact -- $anim_style {
                "bounce" {
                    return [my RenderBounceAnimation $task_id $width $pos $bg_color $fg_color $speed]
                }
                "pulse" {
                    return [my RenderPulseAnimation $task_id $width $pos $bg_color $fg_color $speed]
                }
                "wave" {
                    return [my RenderWaveAnimation $task_id $width $pos $bg_color $fg_color $speed]
                }
                default {
                    zesty::throwError "Unknown animation style: $anim_style"
                }
            }
        }
    }
    
    method RenderBounceAnimation {task_id width pos bg_color fg_color speed} {
        # Renders bouncing animation for indeterminate progress bar.
        #
        # task_id  - task identifier
        # width    - bar width
        # pos      - animation position
        # bg_color - background color
        # fg_color - foreground color
        # speed    - animation speed
        #
        # Returns animated bar with block bouncing left-right.

        set block_size [expr {max(int($width / 4), 3)}]

        # Slow down animation by dividing position
        if {$speed < 0} {
            set slow_pos [expr {$pos / abs($speed)}]
        } else {
            set slow_pos [expr {$pos * $speed}]
        }
        
        # Handle oscillating animation
        set cycle_length [expr {2 * $width}]
        set normalized_pos [expr {int($slow_pos) % $cycle_length}]
        
        if {$normalized_pos < $width} {
            set start_pos $normalized_pos
        } else {
            set start_pos [expr {2 * $width - $normalized_pos - $block_size}]
        }
        
        set start_pos [expr {max(0, min($start_pos, $width - $block_size))}]
        
        set ld [dict get $_options leftBarDelimiter]
        set rd [dict get $_options rightBarDelimiter]

        set result ""
        
        # Segment before animation
        if {$start_pos > 0} {
            set before_chars [string repeat [dict get $_options bgBarChar] $start_pos]
            append result [zesty::parseStyleDictToXML $before_chars [list fg $bg_color]]
        }
        
        # Animation segment
        set anim_chars [string repeat [dict get $_options barChar] $block_size]
        append result [zesty::parseStyleDictToXML $anim_chars [list fg $fg_color]]
        
        # Segment after animation
        set end_pos [expr {$start_pos + $block_size}]
        if {$end_pos < $width} {
            set after_length [expr {$width - $end_pos}]
            set after_chars [string repeat [dict get $_options bgBarChar] $after_length]
            append result [zesty::parseStyleDictToXML $after_chars [list fg $bg_color]]
        }
        
        return ${ld}${result}${rd}
    }

    method RenderPulseAnimation {task_id width pos bg_color fg_color speed} {
        # Renders pulsing animation for indeterminate progress bar.
        #
        # task_id  - task identifier
        # width    - bar width
        # pos      - animation position
        # bg_color - background color
        # fg_color - foreground color
        # speed    - animation speed
        #
        # Returns animated bar with pulsing block in center.

        set max_size [expr {int($width * 0.8)}]
        set min_size [expr {int($width * 0.2)}]

        if {$speed < 0} {
            set slow_pos [expr {$pos / abs($speed)}]
        } else {
            set slow_pos [expr {$pos * $speed}]
        }

        # Complete pulsation cycle (growth and shrinkage)
        set cycle_length 20
        set normalized_pos [expr {int($slow_pos) % $cycle_length}]
        
        # Calculate current block size
        if {$normalized_pos < [expr {$cycle_length / 2}]} {
            # Growth phase
            set ratio [expr {double($normalized_pos) / ($cycle_length / 2)}]
            set block_size [expr {int($min_size + ($max_size - $min_size) * $ratio)}]
        } else {
            # Shrinkage phase
            set ratio [expr {double($normalized_pos - $cycle_length / 2) / ($cycle_length / 2)}]
            set block_size [expr {int($max_size - ($max_size - $min_size) * $ratio)}]
        }
        
        # Calculate start position (center the block)
        set start_pos [expr {int(($width - $block_size) / 2)}]
        
        set ld [dict get $_options leftBarDelimiter]
        set rd [dict get $_options rightBarDelimiter]

        set result ""
        
        # Segment before animation (left)
        if {$start_pos > 0} {
            set before_chars [string repeat [dict get $_options bgBarChar] $start_pos]
            append result [zesty::parseStyleDictToXML $before_chars [list fg $bg_color]]
        }
        
        # Animation segment (center, pulsation)
        if {$block_size > 0} {
            set pulse_chars [string repeat [dict get $_options barChar] $block_size]
            append result [zesty::parseStyleDictToXML $pulse_chars [list fg $fg_color]]
        }
        
        # Segment after animation (right)
        set end_pos [expr {$start_pos + $block_size}]
        if {$end_pos < $width} {
            set after_length [expr {$width - $end_pos}]
            set after_chars [string repeat [dict get $_options bgBarChar] $after_length]
            append result [zesty::parseStyleDictToXML $after_chars [list fg $bg_color]]
        }
        
        return ${ld}${result}${rd}
    }

    method RenderWaveAnimation {task_id width pos bg_color fg_color speed {pattern_size 6}} {
        # Renders wave animation for indeterminate progress bar.
        #
        # task_id      - task identifier
        # width        - bar width
        # pos          - animation position
        # bg_color     - background color
        # fg_color     - foreground color
        # speed        - animation speed
        # pattern_size - size of wave pattern (default: 6)
        #
        # Returns animated bar with wave pattern moving left to right.

        set ld [dict get $_options leftBarDelimiter]
        set rd [dict get $_options rightBarDelimiter]
        
        set total_pattern_size [expr {$pattern_size * 2}]
        
        if {$speed < 0} {
            set slow_pos [expr {$pos / abs($speed)}]
        } else {
            set slow_pos [expr {$pos * $speed}]
        }
        
        # Reverse direction (left to right)
        set offset [expr {(-$slow_pos) % $total_pattern_size}]
        if {$offset < 0} {
            set offset [expr {$offset + $total_pattern_size}]
        }
        
        set result ""
        set current_pos 0
        
        while {$current_pos < $width} {
            # Calculate how many characters of this type we can put
            set pattern_pos [expr {($current_pos + $offset) % $total_pattern_size}]
            
            if {$pattern_pos < $pattern_size} {
                # Background segment
                set chars_in_this_segment [expr {$pattern_size - $pattern_pos}]
                set chars_to_add [expr {min($chars_in_this_segment, $width - $current_pos)}]
                
                if {$chars_to_add > 0} {
                    set segment_chars [string repeat [dict get $_options bgBarChar] $chars_to_add]
                    append result [zesty::parseStyleDictToXML $segment_chars [list fg $bg_color]]
                    set current_pos [expr {$current_pos + $chars_to_add}]
                }
            } else {
                # Foreground segment
                set chars_in_this_segment [expr {$total_pattern_size - $pattern_pos}]
                set chars_to_add [expr {min($chars_in_this_segment, $width - $current_pos)}]
                
                if {$chars_to_add > 0} {
                    set segment_chars [string repeat [dict get $_options barChar] $chars_to_add]
                    append result [zesty::parseStyleDictToXML $segment_chars [list fg $fg_color]]
                    set current_pos [expr {$current_pos + $chars_to_add}]
                }
            }
            
            # Safety to avoid infinite loops
            if {$chars_to_add == 0} {
                incr current_pos
            }
        }
        
        return ${ld}${result}${rd}
    }

    method FormatColumnContent {task_id num width} {
        # Formats content for a specific column and task.
        #
        # task_id - task identifier
        # num     - column number
        # width   - column width
        #
        # Returns formatted content string for the column.

        set key [dict get $_column_configs $num type]
        set align "left"

        if {[dict exists $_column_configs $num align]} {
            set align [dict get $_column_configs $num align]
        }
        
        set dictvalue [dict create \
            self [self] tasks $_tasks idTask $task_id col $num \
        ]
        
        # Rest of code remains same but with addition of align parameter
        # to each FormatText call
        switch -exact -- $key {
            "zSeparator" {
                # Handle zSeparator
                set sep_char "|" ; # Default character
                if {[dict exists $_column_configs $num char]} {
                    set sep_char [dict get $_column_configs $num char]
                }
                # Repeat character to fill width (usually 1)
                return [my FormatText $sep_char $width $align]
            }
            "zName" {
                set result [dict get $_tasks $task_id description]

                # Apply format if defined for custom commands too
                if {[dict exists $_column_configs $num format]} {
                    set formatCmd [dict get $_column_configs $num format]
                    dict set dictvalue result $result
                    set result [my ApplyFormat $dictvalue $formatCmd]
                }

                return [my FormatText $result $width $align]
            }
            "zCount" {
                if {[dict get $_tasks $task_id mode] eq "indeterminate"} {
                    set result "-"
                    if {[dict exists $_column_configs $num format]} {
                        set formatCmd [dict get $_column_configs $num format]
                        dict set dictvalue result $result
                        set result [my ApplyFormat $dictvalue $formatCmd]
                    }
                    return [my FormatText $result $width $align]

                } else {
                    set completed [dict get $_tasks $task_id completed]
                    set total [dict get $_tasks $task_id total]
                    set result "$completed/$total"

                    if {[dict exists $_column_configs $num format]} {
                        set formatCmd [dict get $_column_configs $num format]
                        dict set dictvalue result $result
                        set result [my ApplyFormat $dictvalue $formatCmd]
                    }

                    return [my FormatText $result $width $align]
                }
            }
            "zBar" {
                set percent [expr {int([my percentage $task_id])}]

                set colorBarChar   [dict get $_options colorBarChar]
                set colorBgBarChar [dict get $_options colorBgBarChar]
                set bar [my renderBar \
                    $task_id \
                    $width $percent \
                    $colorBgBarChar $colorBarChar \
                ]

                # Apply format if defined for custom commands too
                if {[dict exists $_column_configs $num format]} {
                    set formatCmd [dict get $_column_configs $num format]
                    dict set dictvalue result $percent
                    dict set dictvalue bar $bar
                    dict set dictvalue width $width
                    dict set dictvalue colorBgBarChar $colorBgBarChar
                    dict set dictvalue colorBarChar $colorBarChar
                    set bar [my ApplyFormat $dictvalue $formatCmd]
                }

                return $bar
            }
            "zPercent" {
                set result [my percentage $task_id]
            
                if {[dict get $_tasks $task_id mode] eq "indeterminate"} {
                
                    if {[dict exists $_column_configs $num format]} {
                        set formatCmd [dict get $_column_configs $num format]
                        dict set dictvalue result $result
                        set result [my ApplyFormat $dictvalue $formatCmd]
                    } else {
                        set result "-"
                    }
                    return [my FormatText $result $width $align]

                } else {
                    # Apply format if defined for custom commands too
                    dict set dictvalue result $result
                    if {[dict exists $_column_configs $num format]} {
                        set formatCmd [dict get $_column_configs $num format]
                        set result [my ApplyFormat $dictvalue $formatCmd]
                    } else {
                        set result [my ApplyFormat $dictvalue "%.0f%%"]
                    }
                    return [my FormatText $result $width $align]
                }
            }
            "zSpinner" {
                set spinner_text [my RenderSpinner $task_id $width]
                return [my FormatText $spinner_text $width $align]
            }
            "zElapsed" {
                set result [my formatTime [my elapsedTime $task_id]]

                # Apply format if defined for custom commands too
                if {[dict exists $_column_configs $num format]} {
                    set formatCmd [dict get $_column_configs $num format]
                    dict set dictvalue result $result
                    set result [my ApplyFormat $dictvalue $formatCmd]
                }
                
                return [my FormatText $result $width $align]
            }
            "zRemaining" {
                set result [my formatTime [my remainingTime $task_id]]
                
                # Apply format if defined for custom commands too
                if {[dict exists $_column_configs $num format]} {
                    set formatCmd [dict get $_column_configs $num format]
                    dict set dictvalue result $result
                    set result [my ApplyFormat $dictvalue $formatCmd]
                }
                
                return [my FormatText $result $width $align]

            }
            default {
                if {[info commands $key] eq ""} {
                    zesty::throwError "A command must be associated with '$key'"
                }
                
                set result [uplevel #0 [list \
                    {*}$key [self] $task_id \
                    [dict get $_tasks $task_id] \
                ]]

                return [my FormatText $result $width $align]
            }
        }
    }
    
    method ApplyFormat {dictvalue format_spec} {
        # Applies formatting specification to value.
        # Supports both traditional format
        # strings and apply command specifications.
        #
        # dictvalue   - dictionary containing values to format
        # format_spec - format specification (format string or apply command)
        #
        # Returns formatted string.

        if {$format_spec eq ""} {
            return [dict get $dictvalue result]
        }
        
        # Check if it's an apply command
        if {([llength $format_spec] >= 2) && ([lindex $format_spec 0] eq "apply")} {
            # It's an apply command
            set apply_spec [lindex $format_spec 1]
            
            # Execute apply command with the value(s)
            return [apply $apply_spec $dictvalue]
        } else {
            # It's a classic format
            return [format $format_spec [dict get $dictvalue result]]
        }
    }

    method FormatText {text width align} {
        # Formats text with style preservation and alignment.
        #
        # text  - text to format (may contain style tags)
        # width - target width
        # align - alignment type
        #
        # Returns formatted text with proper alignment and truncation.

        # Extract visible text to calculate true length
        set preserveStyles [string match {*<s*</s>*} $text]
        
        return [zesty::formatTextWithAlignment $text $width $align \
            $preserveStyles \
            [dict get $_options ellipsisThreshold] \
        ]
    }

    method CalculateColumnWidths {} {
        # Calculates column widths for current terminal size.
        #
        # Returns dictionary mapping column numbers to calculated widths.
 
        # Uses caching to avoid recalculation when not needed.
        if {$_cache_valid && [dict size $_column_widths_cache] > 0} {
            return $_column_widths_cache
        }

        # Get total available width (with safety margin)
        set available_width [expr {$_term_width - 4}]  ;# Keep 4 characters safety

        # Get visible columns
        set visible_columns {}
        foreach {key config} $_column_configs {
            if {[dict exists $config visible] && [dict get $config visible]} {
                lappend visible_columns $key
            }
        }
        
        if {[llength $visible_columns] == 0} {
            zesty::throwError "No visible columns"
        }

        # Check if everything fits with configured widths.
        set total_requested_width 0
        set spaces_between_columns [expr {[llength $visible_columns] - 1}]
        
        foreach col $visible_columns {
            set width [dict get $_column_configs $col width]
            
            # Add delimiter width for bars
            if {[dict get $_column_configs $col type] eq "zBar"} {
                set l [dict get $_options leftBarDelimiter]
                set r [dict get $_options rightBarDelimiter]
                incr width [string length $l$r]
            }
            
            incr total_requested_width $width
        }
        incr total_requested_width $spaces_between_columns
        
        if {$total_requested_width <= $available_width} {
            # Everything fits perfectly, use configured widths
            set colwidths {}
            foreach col $visible_columns {
                set width [dict get $_column_configs $col width]
                dict set colwidths $col $width
            }
            
            # Cache and return
            set _column_widths_cache $colwidths
            set _cache_valid 1
            return $colwidths
        }
        
        # CASE 2: Adjustment necessary - Separate rigid and flexible
        set rigid_columns {}
        set flexible_columns {}
        set rigid_total_width 0

        # Initialize with rigid columns
        set colwidths {}
        foreach col $visible_columns {
            set type [dict get $_column_configs $col type]
            
            switch -exact -- $type {
                "zSpinner" {
                    lappend rigid_columns $col
                    incr rigid_total_width [dict get $_column_configs $col width]
                    dict set colwidths $col [dict get $_column_configs $col width]
                }
                "zSeparator" {
                    set char_width 1
                    if {[dict exists $_column_configs $col char]} {
                        set char_width [string length [dict get $_column_configs $col char]]
                    }
                    lappend rigid_columns $col
                    incr rigid_total_width  $char_width
                    dict set colwidths $col $char_width
                }
                "zPercent" {
                    lappend rigid_columns $col
                    incr rigid_total_width  6
                    dict set colwidths $col 6
                }
                "zElapsed" -
                "zRemaining" {
                    lappend rigid_columns $col
                    incr rigid_total_width  14
                    dict set colwidths $col 14
                }
                default {
                    lappend flexible_columns $col
                }
            }
        }
        
        # Calculate available space for flexible columns
        set available_for_flexible [expr {
            $available_width - $rigid_total_width - $spaces_between_columns
        }]
        
        # Process flexible columns
        if {[llength $flexible_columns] == 0 || $available_for_flexible <= 0} {
            # No flexible columns or no space, force minimum
            foreach col $flexible_columns {
                dict set colwidths $col 1
            }
        } else {
            # Calculate requested widths for flexible ones
            set total_flexible_requested 0
            foreach col $flexible_columns {
                incr total_flexible_requested [dict get $_column_configs $col width]
            }
            
            if {$total_flexible_requested <= $available_for_flexible} {
                # Flexible ones fit in remaining space
                foreach col $flexible_columns {
                    set width [dict get $_column_configs $col width]
                    dict set colwidths $col $width
                }
            } else {
                # Proportional adjustment of flexible ones
                foreach col $flexible_columns {
                    set requested [dict get $_column_configs $col width]
                    set proportion [expr {double($requested) / double($total_flexible_requested)}]
                    set allocated [expr {int($available_for_flexible * $proportion)}]
                    
                    # Minimum width according to type
                    set min_width [dict get $_options minColumnWidth]
                    if {[dict get $_column_configs $col type] eq "zBar"} {
                        set min_width [expr {max($min_width, [dict get $_options minBarWidth])}]
                    }
                    
                    dict set colwidths $col [expr {max($min_width, $allocated)}]
                }
            }
        }

        set _column_widths_cache $colwidths
        set _cache_valid 1
        return $colwidths
    }

    method DisplayTask {task_id} {
        # Displays a single task row with all visible columns.
        # Renders all visible columns for the task in the correct order
        # with proper formatting and styling applied.
        #
        # task_id - task identifier to display
        #
        # Returns nothing.
        
        set column_widths [my CalculateColumnWidths]

        # Create output for each active column
        set output ""
        foreach {key value} $_column_configs {
            set config [dict get $_column_configs $key]
            if {[dict exists $config visible] && [dict get $config visible]} {
                set width [dict get $column_widths $key]

                set text [my FormatColumnContent $task_id $key $width]

                if {[dict exists $config style] && ([dict get $config style] ne "")} {
                    set text [zesty::parseStyleDictToXML $text [dict get $config style]]
                }
                append output $text " "
            }
        }

        zesty::echo $output -n
        flush stdout
        
        return {}
    }

    method updateColumn {task_id column_num} {
        # Updates a specific column for a task in-place.
        # Positions cursor and updates only the specified column content
        # without refreshing the entire display. Used for efficient
        # real-time updates of animated elements.
        #
        # task_id    - task identifier
        # column_num - column number to update
        #
        # Returns nothing.
        classvar TASK_POSITION
        classvar INITIAL_CURSOR_POSITION

        # Check if task exists
        if {![dict exists $_tasks $task_id]} {
            zesty::throwError "Task ID '$task_id' does not exist."
        }
        
        # Check if column exists and is visible
        if {
            ![dict exists $_column_configs $column_num] || 
            ![dict get $_column_configs $column_num visible]
        } {
            zesty::throwError "Column '$column_num' does not\
                exist or is not visible."
        }

        # Calculate column widths
        set column_widths [my CalculateColumnWidths]

        # Calculate horizontal position of column
        set pos_x 1
        for {set i 0} {$i < $column_num} {incr i} {
            if {
                [dict exists $_column_configs $i] && 
                [dict get $_column_configs $i visible]
            } {
                # Special case for progress zBar
                if {[dict get $_column_configs $i type] eq "zBar"} {
                    set l [dict get $_options leftBarDelimiter]
                    set r [dict get $_options rightBarDelimiter]
                    incr pos_x [string length $l$r]
                }
                set width [dict get $column_widths $i]
                incr pos_x [expr {$width + 1}]  ;# +1 for space between columns
            }
        }

        # Get display start for this instance
        lassign $INITIAL_CURSOR_POSITION x initial_y
        set row [dict get $TASK_POSITION $task_id row]
        set pos_y [expr {$initial_y + $row}]

        # Format column content
        set width   [dict get $column_widths $column_num]
        set content [my FormatColumnContent $task_id $column_num $width]
        
        # Position cursor and update column
        if {$_isWindows} {
            incr pos_x -1
            incr pos_y -1
        }
        my PositionCursor $pos_x $pos_y
        set style {}

        if {
            [dict exists $_column_configs $column_num style] &&
            ([dict get $_column_configs $column_num style] ne "")
        } {
            set style [dict get $_column_configs $column_num style]
        }
        
        # Display column content
        # Clear only the part to display
        if {[dict get $_column_configs $column_num type] ni {
            "zCount" "zPercent" "zBar" "zElapsed" "zRemaining" 
            "zSpinner" "zSeparator" "zName"
        } || 
            ([dict exists $_column_configs $column_num format] &&
            [dict get $_column_configs $column_num format] ne "")
        } {
            set width [dict get $_column_configs $column_num width]
            puts -nonewline "\033\[${width}X"
        }

        zesty::echo -n $content -style $style
        flush stdout

        # Always reposition cursor at end
        my PositionCursorToEnd 0 $initial_y
        
        return {}
    }

    method StartSpinnerTimer {} {
        # Starts separate update timer for spinner columns.
        # Cancels existing spinner timer and starts new one with
        # configured frequency.
        #
        # Returns nothing.

        if {$_spinner_timer_id ne ""} {
            after cancel $_spinner_timer_id
        }
        
        # Start new timer for spinners
        my updateSpinners
        
        return {}
    }
    
    method updateSpinners {} {
        # Updates all spinner columns for active tasks.
        # Advances spinner animation position and updates display
        # for all tasks with visible spinner columns. Continues
        # timer loop if any spinners are active.
        #
        # Returns nothing.
        set active 0
        
        # Go through all tasks
        foreach task_id [dict keys $_tasks] {
            set is_completed [expr {
                [dict get $_tasks $task_id completed] >= [dict get $_tasks $task_id total]
            }]
            
            if {!$is_completed} {
                # Update spinner animation counter
                set current_pos [dict get $_tasks $task_id anim_spin]

                # Update spinner column for this task
                foreach num [dict keys $_column_configs] {
                    set col_type [dict get $_column_configs $num type]
                    if {$col_type eq "zSpinner"} {
                        dict set _tasks $task_id anim_spin [expr {$current_pos + 1}]
                        my updateColumn $task_id $num
                        set active 1
                    }
                }
            }
        }
        
        # Continue loop if at least one spinner is active
        if {$active} {
            set time [dict get $_options spinnerFrequency]
            set _spinner_timer_id [after $time \
            [list [self] updateSpinners]]
        }
        
        return {}
    }

    method StartTimeTimer {} {
        # Starts separate update timer for time columns.
        #
        # Returns nothing.

        if {$_time_timer_id ne ""} {
            after cancel $_time_timer_id
        }
        
        # Start new timer for time columns
        my updateTimeColumns
        
        return {}
    }

    method updateTimeColumns {} {
        # Updates all time-related columns for active tasks.
        #
        # Returns nothing.
        set active 0
        
        # Go through all tasks
        foreach task_id [dict keys $_tasks] {
            set is_completed [expr {
                [dict get $_tasks $task_id completed] >= [dict get $_tasks $task_id total]
            }]
            
            if {!$is_completed} {
                set active 1
                
                # Update time columns for this task
                foreach num [dict keys $_column_configs] {
                    set col_type [dict get $_column_configs $num type]
                    if {$col_type in {"zElapsed" "zRemaining"}} {
                        my updateColumn $task_id $num
                    }
                }
            }
        }
        
        # Continue loop if at least one task is active
        if {$active} {
            set _time_timer_id [after 30 \
            [list [self] updateTimeColumns]]
        }
        
        return {}
    }

    method StartCountTimer {} {
        # Starts separate update timer for count columns.
        #
        # Returns nothing.
        if {$_count_timer_id ne ""} {
            after cancel $_count_timer_id
        }
        
        # Start new timer for count (faster)
        my updateCountColumn
        
        return {}
    }
    
    method updateCountColumn {} {
        # Updates all count-related columns for all tasks.
        #
        # Returns nothing.
        set active 0
        
        # Go through all tasks
        foreach task_id [dict keys $_tasks] {    
            # Update time columns for this task
            foreach num [dict keys $_column_configs] {
                set col_type [dict get $_column_configs $num type]
                if {$col_type in {"zCount" "zPercent"}} {
                    my updateColumn $task_id $num
                    set active 1
                } elseif {
                    ($col_type eq "zBar") &&
                    ([dict get $_tasks $task_id mode] ne "indeterminate")
                } {
                    my updateColumn $task_id $num
                    set active 1
                }
            }
        }
        
        # Continue loop if at least one task is active
        if {$active} {
            set _count_timer_id [after 30 \
            [list [self] updateCountColumn]]
        }
        
        return {}
    }
    
    method StartIndeterminateTimer {} {
        # Starts separate timer for indeterminate progress bars.
        #
        # Returns nothing.

        if {$_indeterminate_timer_id ne ""} {
            after cancel $_indeterminate_timer_id
            set _indeterminate_timer_id ""
        }
        
        my updateIndeterminateBars
        
        return {}
    }
    
    method updateIndeterminateBars {} {
        # Updates all indeterminate progress zBar animations.
        #
        # Returns nothing.
        set active 0
        
        foreach task_id [dict keys $_tasks] {
            if {[dict get $_tasks $task_id mode] eq "indeterminate"} {
                set is_completed [expr {
                    [dict get $_tasks $task_id completed] >= [dict get $_tasks $task_id total]
                }]
                
                if {!$is_completed} {
                    # Increment zBar animation position
                    set pos [dict get $_tasks $task_id anim_pos]
                    dict set _tasks $task_id anim_pos [incr pos]
                    
                    # Update zBar columns
                    foreach num [dict keys $_column_configs] {
                        if {[dict get $_column_configs $num type] eq "zBar" && 
                            [dict get $_column_configs $num visible]} {
                            my updateColumn $task_id $num
                            set active 1
                        }
                    }
                }
            }
        }
        
        if {$active} {
            # Fast timer for smooth bar animation
            set _indeterminate_timer_id [after 50 \
             [list [self] updateIndeterminateBars]]
        }
        
        return {}
    }

    method StartCustomTimer {} {
        # Starts separate timer for custom column procedures.
        #
        # Returns nothing.

        if {$_custom_timer_id ne ""} {
            after cancel $_custom_timer_id
            set _custom_timer_id ""
        }
        
        my updateCustomProcs
        
        return {}
    }

    method updateCustomProcs {} {
        # Updates all custom procedure columns.
        #
        # Returns nothing.

        set active 0
        set istext 1
        
        foreach task_id [dict keys $_tasks] {
            set is_completed [expr {
                [dict get $_tasks $task_id completed] >= [dict get $_tasks $task_id total]
            }]
                
            if {!$is_completed} {
                foreach num [dict keys $_column_configs] {
                    set col_type [dict get $_column_configs $num type]
                    if {$col_type ni {
                        "zCount" "zPercent" "zBar" "zElapsed" "zRemaining" "zSpinner"
                    } && [dict get $_column_configs $num visible]} {
                        my updateColumn $task_id $num
                        set active 1
                    }
                }
            }
        }

        if {$active} {
            set _custom_timer_id [after 100 \
            [list [self] updateCustomProcs]]
        }
        
        return {}
    }

    method Display {} {
        # Main display method that orchestrates progress bar rendering.
        # Manages terminal scrolling, initializes display system,
        # starts appropriate update timers, and handles task positioning.
        # Called automatically when tasks are updated.
        #
        # Returns nothing.
        classvar ALLTASKS
        classvar INITIAL_CURSOR_POSITION
        classvar TASK_POSITION
        classvar BARINSTANCE
        classvar BARDISPLAY

        if {$_all_tasks_completed} {return}
        
        # Handle terminal scrolling if necessary
        my ManageScrolling $ALLTASKS
        
        if {
            [info exists BARDISPLAY] &&
            ($BARDISPLAY == $BARINSTANCE)
        } {
            if {$_spinner_timer_id eq ""}       {my StartSpinnerTimer}
            if {$_time_timer_id eq ""}          {my StartTimeTimer}
            if {$_count_timer_id eq ""}         {my StartCountTimer}
            if {$_indeterminate_timer_id eq ""} {my StartIndeterminateTimer}
            if {$_custom_timer_id eq ""}        {my StartCustomTimer}
        } else {
            # Initial Y position of cursor
            lassign $INITIAL_CURSOR_POSITION x initial_y
            set modecontinue 0

            # To display my bars, but only at the beginning
            # then the start_* take over
            foreach task_id [dict keys $_tasks] {

                set row [dict get $TASK_POSITION $task_id row]
                set row_y [expr {$initial_y + $row}]
                
                if {$_isWindows} {
                    incr row_y -1
                }

                my PositionCursor 0 $row_y
                my DisplayTask $task_id

                if {
                    !$modecontinue && ($_has_spinner_column || 
                    ([dict get $_tasks $task_id mode] eq "indeterminate"))
                } {
                    set modecontinue 1
                }
            }

            # Always reposition cursor at end
            my PositionCursorToEnd 0 $initial_y
            
            incr BARDISPLAY

            if {($BARDISPLAY == $BARINSTANCE) && $modecontinue} {
                my Display
            }
        }

        # Update global completion state
        set _all_tasks_completed [my CheckCompletionStatus]

        # If all tasks completed, automatically call cleanup
        if {$_all_tasks_completed} {
            foreach task_id [dict keys $_tasks] {
                foreach colkeys [dict keys $_column_configs] {
                    my updateColumn $task_id $colkeys
                }
            }

            my cleanup
        }
        
        return {}
    }

    method PositionCursorToEnd {x y} {
        # Positions cursor at end of progress bar display.
        #
        # x - x coordinate
        # y - base y coordinate
        #
        # Returns nothing
        classvar ALLTASKS
        
        set y [expr {($y + 1) + $ALLTASKS}]
        if {$_isWindows} {
            set y [expr {$y - 1}]
        }
        my PositionCursor 0 $y
        
        return {}
    }

    method CheckCompletionStatus {} {
        # Checks if all tasks are completed.
        #
        # Returns 1 if all tasks have reached their total progress,
        # 0 if any task is still incomplete.
        foreach task_id [dict keys $_tasks] {
            if {
                [dict get $_tasks $task_id completed] <
                [dict get $_tasks $task_id total]
            } {
                return 0
            }
        }
        return 1
    }

    method PositionCursor {x y} {
        # Positions terminal cursor at specific coordinates.
        # Uses Windows API or ANSI escape sequences depending
        # on platform detection.
        #
        # x - column position (0-based)
        # y - row position (0-based)
        #
        # Returns nothing.

        if {$_isWindows} {
            # Use Windows API
            if {$_handle ne "null"} {
                zesty::win32::setConsoleCursorPosition $_handle $x $y
            }
        } else {
            # Use ANSI sequences
            puts -nonewline "\033\[${y};${x}H"
            flush stdout
        }
        
        return {}
    }
    
    method InitDisplaySystem {} {
        # Initializes the display system once per class.
        # Sets up header display if enabled and records initial
        # cursor position. Uses class variable to ensure single
        # initialization across all instances.
        #
        # Returns nothing.
        classvar DISPLAYS_INITIALIZED
        classvar INITIAL_CURSOR_POSITION
        
        # If already initialized, do nothing
        if {[info exists DISPLAYS_INITIALIZED] && $DISPLAYS_INITIALIZED} {
            return
        }
        
        # Mark as initialized
        set DISPLAYS_INITIALIZED 1
        
        if {[dict get $_options headers show]} {
            my DisplayHeader
        }

        # Remember initial cursor position
        lassign [zesty::getCursorPosition $_handle] x y
        if {!$_isWindows} {
            if {$y != $_term_height} {incr y -1}
        }

        set INITIAL_CURSOR_POSITION [list $x $y]
        
        return {}
    }

    method ManageScrolling {ALLTASKS} {
        # Manages terminal scrolling for progress bar display.
        # Handles case where progress bars exceed available terminal
        # space by adding empty lines and adjusting cursor position.
        # Prevents display overflow and ensures proper positioning.
        #
        # ALLTASKS - total number of tasks to display
        #
        # Returns nothing.
        classvar MANAGING_INITIALIZED
        classvar INITIAL_CURSOR_POSITION
        
        # If already initialized, do nothing
        if {[info exists MANAGING_INITIALIZED] && $MANAGING_INITIALIZED} {
            return
        }

        # Initial Y position of cursor
        lassign $INITIAL_CURSOR_POSITION x initial_y
        
        # Available space after initial position
        set available_space [expr {$_term_height - ($initial_y)}]

        if {$_isWindows} {
            set isAvailable [expr {$ALLTASKS > $available_space}]
        } else {
            set isAvailable [expr {$ALLTASKS >= $available_space}]
        }

        # Check if display exceeds available space
        if {$isAvailable} {
            if {$ALLTASKS > $_term_height} {
                zesty::throwError "Not supported ALLTASKS > Terminal height"
            }

            # Add empty lines to scroll
            for {set i 0} {$i <= $ALLTASKS} {incr i} {
                puts ""
            }

            if {$_isWindows && ![zesty::win32::isNewTerminal]} {
                set INITIAL_CURSOR_POSITION [list $x $initial_y] 
                if {$initial_y >= $_term_height} {
                    my PositionCursor 0 [expr {$initial_y + 1}]
                } else {
                    my PositionCursor 0 $initial_y
                }
            
            } else {
                
                # Calculate how many lines need to scroll
                set scroll_lines [expr {$ALLTASKS - $available_space}]
                set y [expr {$initial_y - ($scroll_lines + 1)}]

                # Update initial cursor position
                if {$_isWindows} {
                    set INITIAL_CURSOR_POSITION [list $x $y] 
                } else {
                    set INITIAL_CURSOR_POSITION [list $x [expr {$y - 1}]]
                }

                my PositionCursor 0 $y
            }
            set MANAGING_INITIALIZED 1
        }
        
        return {}
    }

    method cleanup {} {
        # Cleans up progress bar resources and timers.
        # Cancels all active update timers and resets internal state.
        # Called automatically when all tasks complete or can be
        # called manually to force cleanup.
        #
        # Returns nothing.
        foreach timer [list \
            $_spinner_timer_id $_time_timer_id \
            $_count_timer_id $_indeterminate_timer_id \
            $_custom_timer_id \
        ] {
            if {$timer ne ""} {
                after cancel $timer
                set $timer ""
            }
        }

        return {}
    }
}