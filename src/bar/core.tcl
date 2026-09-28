# Copyright (c) 2026 Nicolas ROBERT.
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
    variable _has_spinner_column
    variable _cache_valid
    variable _column_widths_cache

    variable _ownerBar
    variable _paused
    variable _cachedRows
    variable _customValues
    variable _customColumns
    variable _customGeneration
    variable _customFresh
    variable _collectCallbacks
    variable _callbackJobs

    constructor {owner args} {
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

        set _ownerBar $owner
        set _paused 0
        set _cachedRows {}
        set _customValues {}
        set _customColumns {}
        set _customGeneration 0
        set _customFresh 0
        set _collectCallbacks 0
        set _callbackJobs {}

        # Initialize variables
        set _tasks {}
        set _all_tasks_completed 0
        set _task_index 0
        set _cache_valid 0
        set _column_widths_cache {}
        set _header_configs {}
        set _column_configs {}

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

        lassign $::zesty::render::size _term_width _term_height
        my CustomColumns

        set _has_spinner_column [my HasSpinnerColumn]

    }

    method Display {} {
        # Invalidates the cached frame and updates the completion status.
        # The actual terminal write is done by the render thread timer.
        #
        # Returns: Nothing.
        set _paused 0
        set _cachedRows {}
        set _all_tasks_completed [my CheckCompletionStatus]
        return {}
    }

    method updateColumn {task_id column_num} {
        # Invalidates custom column values and refreshes the display.
        # Throws error if task doesn't exist or column is not visible.
        #
        # task_id    - task identifier
        # column_num - column number
        #
        # Returns: Nothing.
        if {![dict exists $_tasks $task_id]} {
            error "zesty(error): Task ID '$task_id' does not exist."
        }
        if {![dict exists $_column_configs $column_num visible] ||
            ![dict get $_column_configs $column_num visible]} {
            error "zesty(error): Column '$column_num' does not exist or is not visible."
        }
        set _customFresh 0
        my Display
        return {}
    }

    method cleanup {} {
        # Renders a final frame and pauses the bar, so that
        # subsequent frames reuse the cached rows.
        #
        # Returns: Nothing.
        if {!$_paused} {my lines [clock milliseconds] {*}$::zesty::render::size}
        set _paused 1
        return {}
    }

    method updateSpinners {} {
        # Invalidates the cached frame to redraw spinners.
        #
        # Returns: Nothing.
        my Display
    }

    method updateTimeColumns {} {
        # Invalidates the cached frame to redraw time columns.
        #
        # Returns: Nothing.
        my Display
    }

    method updateCountColumn {} {
        # Invalidates the cached frame to redraw count columns.
        #
        # Returns: Nothing.
        my Display
    }

    method updateIndeterminateBars {} {
        # Invalidates the cached frame to redraw indeterminate bars.
        #
        # Returns: Nothing.
        my Display
    }

    method updateCustomProcs {} {
        # Invalidates custom column values and the cached frame
        # to redraw custom columns.
        #
        # Returns: Nothing.
        set _customFresh 0
        my Display
    }

    method CustomColumns {} {
        # Rebuilds the list of visible columns requiring a callback
        # (custom column types or 'apply' format) and invalidates
        # previously collected callback values.
        #
        # Returns: Nothing.
        set _customColumns {}
        dict for {num config} $_column_configs {
            if {![dict get $config visible]} {continue}
            if {[dict get $config type] ni {
                zName zCount zBar zPercent zElapsed zRemaining zSpinner zSeparator
            } || ([dict exists $config format] &&
                  [lindex [dict get $config format] 0] eq "apply")} {
                lappend _customColumns $num
            }
        }
        incr _customGeneration
        set _customFresh 0
        set _customValues {}
    }

    method needsCallbacks {} {
        # Checks if column callbacks must be run by the owner thread.
        #
        # Returns: 1 if the bar is not paused, has custom columns and tasks,
        # and tasks are running or values are stale, 0 otherwise.
        return [expr {!$_paused && [llength $_customColumns] && [dict size $_tasks] &&
            (!$_all_tasks_completed || !$_customFresh)}]
    }

    method finished {} {
        # Checks if the bar has tasks and all of them are completed.
        #
        # Returns: 1 if all tasks are completed, 0 otherwise.
        return [expr {[dict size $_tasks] && $_all_tasks_completed}]
    }

    method callbackStatus {} {
        # Gets the callback status of the bar.
        #
        # Returns: A list {needsCallbacks fresh}.
        return [list [my needsCallbacks] $_customFresh]
    }


    method callbackJobs {} {
        # Collects the callback commands needed to format custom columns,
        # without executing them.
        #
        # Returns: A list {generation jobs} where jobs is a list of
        # {task_id column command} elements.
        set _callbackJobs {}
        set _collectCallbacks 1
        try {
            set widths [my CalculateColumnWidths]
            foreach task [dict keys $_tasks] {
                foreach num $_customColumns {
                    my FormatColumnContent $task $num [dict get $widths $num]
                }
            }
        } finally {
            set _collectCallbacks 0
        }
        return [list $_customGeneration $_callbackJobs]
    }

    method Callback {task num command} {
        # Records a callback job when collecting, and returns the last
        # value computed by the owner thread.
        #
        # task    - task identifier
        # num     - column number
        # command - command to evaluate in the owner interpreter
        #
        # Returns: The cached callback value, or an empty string.
        if {$_collectCallbacks} {lappend _callbackJobs [list $task $num $command]}
        if {[dict exists $_customValues $task $num]} {
            return [dict get $_customValues $task $num]
        }
        return ""
    }

    method callbacksReady {} {
        # Loads callback values computed by the owner thread from shared
        # storage, if they match the current layout generation.
        #
        # Returns: 1 if callbacks still need to run, 0 otherwise.
        lassign [tsv::get $::zesty::render::shared "custom:[self]"] generation values

        # A callback may have changed the column configuration or added a task.
        # Reject values prepared for an older layout, and retry on the next tick.
        if {$generation == $_customGeneration} {
            set _customValues $values
            set _customFresh 1
            set _cachedRows {}
        }
        if {$_all_tasks_completed} {::zesty::render::draw}
        return [my needsCallbacks]
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
        # Returns: Nothing.
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
        # Returns: Nothing.

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
        # Returns: Header configuration dict with name, align, and style.
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

    method InitStandardColumn {index type} {
        # Initializes standard column configuration based on type.
        #
        # index - column index number
        # type  - column type
        #
        # Returns: Nothing.
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
                # The application relay validates this command in its owner.
                dict set _column_configs $index visible 1
                dict set _column_configs $index width 15
                dict set _column_configs $index type $type
                dict set _column_configs $index align left
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
        # Returns: Formatted spinner text centered in column width.

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
        # Returns: Nothing.
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
        # Returns: Nothing.

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

        set config [dict get $_column_configs $num]
        foreach {key value} $args {
            switch -exact -- $key {
                -visible {
                    zesty::validValue {} $key "formatVBool" $value
                    dict set config visible $value
                }
                -width   {
                    zesty::validValue {} $key "formatMCWidth" $value
                    dict set config width $value
                }
                -type   {dict set config type $value}
                -format {dict set config format $value}
                -align  {
                    zesty::validValue {} $key "formatAlign" $value
                    dict set config align $value
                }
                -spinnerStyle {
                    if {![dict exists $::zesty::spinnerstyles $value]} {
                        error "zesty(error): spinnerStyle must be one of:\
                        [join [dict keys $::zesty::spinnerstyles] ","]"
                    }
                    dict set config spinnerStyle $value
                }
                -style {
                    zesty::validValue {} $key "formatStyle" $value
                    dict set config style $value
                }
                default  {error "zesty(error): Column option '$key' not supported"}
            }
        }

        dict set _column_configs $num $config
        set _has_spinner_column [my HasSpinnerColumn]
        set _cache_valid 0  ;# Invalidate cache
        my CustomColumns
        my Display

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
        # Returns: Nothing.

        if {[dict exists $_column_configs $num]} {
            error "zesty(error): Column '$num' already exists"
        }

        zesty::validateKeyValuePairs args $args
        if {![dict exists $args -type]} {
            error "zesty(error): Column 'type' must be specified with '-type' option"
        }
        dict set _column_configs $num [dict create visible 1 width 20 align left \
            type [dict get $args -type]]
        try {
            my configureColumn $num {*}$args
        } on error {message options} {
            dict unset _column_configs $num
            set _cache_valid 0
            return -options $options $message
        }

        return {}
    }

    method addTask {args} {
        # Adds a new task to the progress bar.
        #
        # args - configuration options in key-value pairs:
        #   -name      - task description
        #   -total     - total number of steps
        #   -completed - number of completed steps
        #   -mode      - progress mode (determinate, indeterminate)
        #   -animStyle - animation style for indeterminate mode
        #
        # Returns: The new task identifier.

        # Validate into a temporary dictionary: errors must not leave ghost tasks.
        zesty::validateKeyValuePairs "args" $args
        set now [clock milliseconds]
        set task_id "task[self]::[expr {$_task_index + 1}]"
        set task [dict create description $task_id total 100 completed 0 \
            start_time $now last_update $now mode determinate anim_pos 0 \
            anim_spin 0 animStyle [dict get $_options indeterminateBarStyle] \
            timer_running 0]
        foreach {key value} $args {
            switch -exact -- $key {
                -name {dict set task description $value}
                -total {
                    zesty::validValue {} $key formatTTask $value
                    dict set task total $value
                }
                -completed {
                    zesty::validValue {} $key formatCTask $value
                    dict set task completed $value
                }
                -mode {
                    zesty::validValue {} $key formatIBMode $value
                    dict set task mode $value
                }
                -animStyle {
                    zesty::validValue {} $key formatIBStyle $value
                    dict set task animStyle $value
                }
                default {error "zesty(error): Task option '$key' not supported"}
            }
        }
        if {[dict get $task completed] >= [dict get $task total]} {
            dict set task completed [dict get $task total]
            dict set task completion_time $now
        }
        incr _task_index
        dict set _tasks $task_id $task
        incr _customGeneration
        set _customFresh 0
        my Display
        return $task_id
    }

    method update {task_id args} {
        # Updates task properties.
        # Throws error if task doesn't exist or invalid options provided.
        #
        # task_id - task identifier
        # args    - configuration options in key-value pairs:
        #   -total       - total number of steps
        #   -completed   - number of completed steps
        #   -advance     - number of steps to advance
        #   -mode        - progress mode (determinate, indeterminate)
        #   -description - task description
        #
        # Returns: Nothing.

        # Mutations and queries execute on the same remote object, in order.
        if {![dict exists $_tasks $task_id]} {
            error "zesty(error): Task ID '$task_id' does not exist."
        }
        zesty::validateKeyValuePairs "args" $args
        set task [dict get $_tasks $task_id]
        set was_completed [expr {[dict get $task completed] >= [dict get $task total]}]
        foreach {key value} $args {
            switch -exact -- $key {
                -total {
                    zesty::validValue {} $key formatTTask $value
                    dict set task total $value
                }
                -completed {
                    zesty::validValue {} $key formatCTask $value
                    dict set task completed $value
                    dict set task mode determinate
                }
                -advance {
                    if {![string is integer -strict $value]} {
                        error "zesty(error): '$key' must be an integer"
                    }
                    dict incr task completed $value
                }
                -mode {
                    zesty::validValue {} $key formatIBMode $value
                    dict set task mode $value
                }
                -description {dict set task description $value}
                default {error "zesty(error): Unknown key '$key'"}
            }
        }
        dict set task completed [expr {max(0, min([dict get $task total], [dict get $task completed]))}]
        dict set task last_update [clock milliseconds]
        set is_completed [expr {[dict get $task completed] >= [dict get $task total]}]
        if {$is_completed && !$was_completed} {
            dict set task completion_time [clock milliseconds]
            set _customFresh 0
        } elseif {!$is_completed && [dict exists $task completion_time]} {
            dict unset task completion_time
        }
        dict set _tasks $task_id $task
        my Display
        return {}
    }

    method HasSpinnerColumn {} {
        # Checks if any spinner columns are visible.
        # Used to determine if spinner update timers needed.
        #
        # Returns: 1 if at least one spinner column exists and is visible,
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
        # Returns: Nothing.
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
        # Returns: Percentage as floating point number (0.0-100.0)
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
        # Returns: Elapsed time as floating point seconds.

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
        # Returns: Estimated remaining time in seconds as floating point,
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
        # Returns: Formatted string in HH:MM:SS.mmm format.

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
        # Returns: Formatted progress bar string with colors applied.

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
        # Returns: Animated bar with block bouncing left-right.

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
        # Returns: Animated bar with pulsing block in center.

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
        # Returns: Animated bar with wave pattern moving left to right.

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
        # Returns: Formatted content string for the column.

        set key [dict get $_column_configs $num type]
        set align "left"

        if {[dict exists $_column_configs $num align]} {
            set align [dict get $_column_configs $num align]
        }

        set dictvalue [dict create \
            self $_ownerBar tasks $_tasks idTask $task_id col $num \
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
                set result [my Callback $task_id $num [list \
                    {*}$key $_ownerBar $task_id \
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
        # Returns: Formatted string.

        if {$format_spec eq ""} {
            return [dict get $dictvalue result]
        }

        # Check if it's an apply command
        if {([llength $format_spec] >= 2) && ([lindex $format_spec 0] eq "apply")} {
            # It's an apply command
            set apply_spec [lindex $format_spec 1]

            # Execute apply command with the value(s)
            return [my Callback [dict get $dictvalue idTask] [dict get $dictvalue col] \
                [list apply $apply_spec $dictvalue]]
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
        # Returns: Formatted text with proper alignment and truncation.

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
        # Returns: Dictionary mapping column numbers to calculated widths.

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

    method CheckCompletionStatus {} {
        # Checks if all tasks are completed.
        #
        # Returns: 1 if all tasks have reached their total progress,
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

    method lines {now width height} {
        # Builds the display lines (header, separator and one line
        # per task) for the current frame.
        #
        # now    - current time in milliseconds
        # width  - terminal width
        # height - terminal height
        #
        # Returns: A list of styled lines.
        if {$width != $_term_width || $height != $_term_height} {
            set _term_width $width
            set _term_height $height
            set _cache_valid 0
            set _cachedRows {}
            set _customFresh 0
        }
        if {![dict size $_tasks]} {return {}}
        if {$_paused && [llength $_cachedRows]} {return $_cachedRows}
        set calculated [my CalculateColumnWidths]
        set widths {}
        # The width calculator groups rigid/flexible columns internally;
        # preserve the configured display order, not that grouping order.
        foreach num [dict keys $_column_configs] {
            if {[dict exists $calculated $num]} {
                dict set widths $num [dict get $calculated $num]
            }
        }
        set result {}
        if {[dict get $_options headers show]} {
            set line ""
            set totalWidth 0
            dict for {num width} $widths {
                set config [dict get $_column_configs $num]
                set data [my GetHeaderText $num]
                set text [dict get $data name]
                set align center
                if {[dict exists $data align]} {set align [dict get $data align]}
                if {[dict get $config type] eq "zBar"} {
                    incr width [string length [dict get $_options leftBarDelimiter]]
                    incr width [string length [dict get $_options rightBarDelimiter]]
                }
                if {[dict get $config type] eq "zSeparator"} {set text ""}
                set text [my FormatText $text $width $align]
                if {[dict exists $data style] && [dict get $data style] ne ""} {
                    set text [zesty::parseStyleDictToXML $text [dict get $data style]]
                }
                append line $text " "
                incr totalWidth [expr {$width + 1}]
            }
            lappend result $line
            if {[dict get $_options lineHSeparator show]} {
                set line [string repeat [dict get $_options lineHSeparator char] \
                    [expr {max(0, $totalWidth - 1)}]]
                lappend result [zesty::parseStyleDictToXML $line \
                    [dict get $_options lineHSeparator style]]
            }
        }
        dict for {task data} $_tasks {
            # Derive animation phase from elapsed time, not message count.
            set end $now
            if {[dict exists $data completion_time]} {set end [dict get $data completion_time]}
            set elapsed [expr {max(0, $end - [dict get $data start_time])}]
            dict set _tasks $task anim_spin [expr {$elapsed / max(1, [dict get $_options spinnerFrequency])}]
            dict set _tasks $task anim_pos [expr {$elapsed / 50}]
            set line ""
            dict for {num width} $widths {
                set text [my FormatColumnContent $task $num $width]
                if {[dict exists $_column_configs $num style] &&
                    [dict get $_column_configs $num style] ne ""} {
                    set text [zesty::parseStyleDictToXML $text [dict get $_column_configs $num style]]
                }
                append line $text " "
            }
            lappend result $line
        }
        set _cachedRows $result
        return $result
    }
}