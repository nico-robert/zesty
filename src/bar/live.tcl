# Copyright (c) 2026 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty::live {
    variable directory [file dirname \
    [file dirname [file dirname [file normalize [info script]]]]]
    variable tid ""
    variable shared ""
    variable bars {}
    variable serial 0
}

oo::class create zesty::Bar {
    variable _remoteBar 
    variable _refreshing 
    variable _timer 
    variable _due 
    variable _pending
    variable _callbackErrors

    constructor {args} {
        # Creates the application-side proxy of the progress bar and its
        # remote counterpart in the display thread.
        #
        # args - configuration options (see zesty::Bar constructor in core.tcl)

        set _remoteBar ""
        set _refreshing 0
        set _timer ""
        set _due 0
        set _pending 0
        set _callbackErrors {}
        zesty::live::validateColumns {*}$args
        set _remoteBar [zesty::live::acquire [self] {*}$args]
    }

    destructor {
        # Cancels the pending refresh timer and releases the remote bar.

        if {[info exists _timer] && $_timer ne ""} {
            after cancel $_timer
        }
        if {[info exists _remoteBar] && $_remoteBar ne ""} {
            zesty::live::release [self]
        }
    }

    method destroy {} {
        # Destroys the object.
        # Throws error if called from inside a column callback.
        #
        # Returns: Nothing.
        if {$_refreshing} {
            error "zesty(error): destroy cannot run inside a column callback"
        }
        next

        return {}
    }

    method Call {method args} {
        # Relays a method call to the remote bar in the display thread,
        # then runs pending column callbacks if needed.
        #
        # method - method name
        # args   - method arguments
        #
        # Returns: The result of the remote method.
        if {$method eq "cleanup" && $_refreshing} {
            error "zesty(error): cleanup cannot run inside a column callback"
        }
        if {$method in {configureColumn addColumn}} {
            zesty::live::validateColumns {*}[lrange $args 1 end]
        }
        zesty::live::check
        lassign [thread::send $::zesty::live::tid [list zesty::render::call \
        $_remoteBar $::zesty::spinnerstyles $method {*}$args]] result _pending fresh
        if {$method in {percentage elapsedTime remainingTime formatTime renderBar}} {
            return $result
        }
        if {!$fresh || $method eq "updateColumn"} {set _due 0}
        if {
            $method in {update advance updateColumn updateCustomProcs
                        updateSpinners updateTimeColumns updateCountColumn
                        updateIndeterminateBars}
        } {
            my Refresh
        }
        my Schedule

        return $result
    }

    method Schedule {} {
        # (Re)schedules the refresh timer while callbacks are pending.
        #
        # Returns: Nothing.
        if {$_timer ne ""} {
            after cancel $_timer
            set _timer ""
        }
        if {$_pending && !$_refreshing} {
            set _timer [after 100 [list [self] tick]]
        }

        return {}
    }

    method tick {} {
        # Timer handler: refreshes column callbacks and reschedules.
        #
        # Returns: Nothing.
        set _timer ""
        my Refresh
        my Schedule

        return {}
    }

    method Refresh {} {
        # Evaluates column callbacks in the owner interpreter and sends
        # their results to the display thread through shared storage.
        #
        # Returns: Nothing.
        if {$_refreshing || !$_pending || [clock milliseconds] < $_due} {return}
        set _refreshing 1
        try {
            zesty::live::check
            lassign [thread::send $::zesty::live::tid \
                [list $_remoteBar callbackJobs]] generation jobs
            set values {}
            foreach job $jobs {
                lassign $job task column command
                if {[catch {uplevel #0 $command} value options] == 1} {
                    my ReportCallbackError $task $column $value $options
                    set value "ERR"
                } else {
                    dict unset _callbackErrors $column
                }
                dict set values $task $column $value
            }
            # TSV carries only callback results. Task state belongs solely to
            # the remote object, and no worker ever waits for the owner.
            tsv::set $::zesty::live::shared "custom:$_remoteBar" \
                [list $generation $values]
            set _pending [thread::send $::zesty::live::tid \
                [list $_remoteBar callbacksReady]]
            set _due [expr {[clock milliseconds] + 100}]
        } finally {
            set _refreshing 0
        }

        return {}
    }

    method ReportCallbackError {task column message options} {
        # Reports a column callback error once per column, through the
        # standard background error mechanism (interp bgerror).
        #
        # task    - task identifier
        # column  - column number
        # message - error message returned by catch
        # options - error options dictionary returned by catch
        #
        # Returns: Nothing.
        if {[dict exists $_callbackErrors $column]} {return}
        dict set _callbackErrors $column 1
        set message "zesty(error): callback of column '$column'\
            (task '$task') failed: $message"
        dict append options -errorinfo \
            "\n    (zesty::Bar column '$column' callback, task '$task')"
        # Deferred: the report must not interrupt the current refresh.
        after 0 [list return -options $options $message]

        return {}
    }

    method getONSClass {} {
        # Returns the name of the internal namespace of the object.
        return [info object namespace [self class]]
    }
}

proc zesty::live::active {} {
    # Checks if the display thread is running.
    #
    # Returns: 1 if the display thread is running, 0 otherwise.
    variable tid

    return [expr {$tid ne ""}]
}

proc zesty::live::check {} {
    # Checks that the display thread is running and rethrows
    # any error recorded by it.
    #
    # Returns: Nothing.
    variable tid
    variable shared
    if {$tid eq "" || ![thread::exists $tid]} {
        error "zesty(error): display thread is not running"
    }
    if {[tsv::exists $shared error]} {
        lassign [tsv::get $shared error] message options
        return -options $options $message
    }

    return {}
}

proc zesty::live::stop {} {
    # Stops the display thread and frees the shared storage.
    #
    # Returns: Nothing.
    variable tid
    variable shared
    if {$tid eq ""} {return}
    thread::send $tid {zesty::render::stop}
    thread::release $tid
    thread::join $tid
    tsv::unset $shared
    set tid ""
    set shared ""

    return {}
}

proc zesty::live::write {text newline} {
    # Sends a formatted message to the display thread, which writes it
    # above the live region.
    #
    # text    - formatted text (with ANSI codes)
    # newline - 1 to append a newline, 0 otherwise
    #
    # Returns: Nothing.
    variable tid
    zesty::live::check
    thread::send $tid [list zesty::render::withMessage $text $newline]

    return {}
}

proc zesty::live::acquire {owner args} {
    # Starts the display thread if needed and creates the remote
    # bar associated with owner.
    #
    # owner - [zesty::Bar] application-side object
    # args  - bar configuration options
    #
    # Returns: The name of the remote bar object.
    variable directory
    variable tid
    variable shared
    variable bars
    variable serial

    try {
        if {$tid eq ""} {
            # Thread is only needed by progress bars: load it on first use.
            if {[catch {package require Thread} msg]} {
                error "zesty(error): progress bars require the Thread package: $msg"
            }
            set shared "zesty-display-[thread::id]-[incr serial]"
            ::flush stdout
            set tid [thread::create -joinable -preserved]
            thread::send $tid [list set auto_path $::auto_path]
            thread::send $tid [list fconfigure stdout \
                -encoding [fconfigure stdout -encoding] \
                -translation [fconfigure stdout -translation]]
            thread::send $tid [list source -encoding utf-8 \
            [file join $directory src bar render.tcl]]
            thread::send $tid [list zesty::render::start $directory $shared]
        }
        zesty::live::check
        thread::send $tid [list set zesty::spinnerstyles $::zesty::spinnerstyles]
        set remote [thread::send $tid [list zesty::render::add $owner {*}$args]]
        dict set bars $owner $remote
        return $remote
    } on error {message options} {
        if {![dict size $bars]} {
            zesty::live::stop
        }
        return -options $options $message
    }
}

proc zesty::live::release {owner} {
    # Removes the remote bar associated with owner, and stops the
    # display thread when no bar remains.
    #
    # owner - [zesty::Bar] application-side object
    #
    # Returns: Nothing.
    variable tid
    variable bars

    if {![dict exists $bars $owner]} {return}
    try {
        thread::send $tid [list zesty::render::remove $owner]
    } finally {
        dict unset bars $owner
        if {![dict size $bars]} {
            zesty::live::stop
        }
    }

    return {}
}

proc zesty::live::columnType {type} {
    # Checks that a custom column type is associated with a command.
    #
    # type - column type
    #
    # Returns: The column type.
    if {$type ni {zName zCount zBar zPercent zElapsed zRemaining zSpinner zSeparator} &&
        [uplevel #0 [list namespace which -command $type]] eq ""} {
        error "zesty(error): A command must be associated with '$type' column type."
    }

    return $type
}

proc zesty::live::validateColumns {args} {
    # Validates custom column types found in -type and -setColumns options.
    #
    # args - configuration options in key-value pairs
    #
    # Returns: Nothing.
    zesty::validateKeyValuePairs args $args
    foreach {key value} $args {
        if {$key eq "-type"} {
            zesty::live::columnType $value
        }
        if {$key eq "-setColumns"} {
            foreach column $value {
                if {[llength $column] == 1} {
                    zesty::live::columnType $column
                }
            }
        }
    }

    return {}
}

# Keep public method discovery useful. All task operations use the same relay.
foreach method {
    addTask update advance configureColumn addColumn updateColumn
    percentage elapsedTime remainingTime formatTime renderBar cleanup
    updateSpinners updateTimeColumns updateCountColumn
    updateIndeterminateBars updateCustomProcs
} {
    oo::define zesty::Bar method $method {args} \
    [format {return [my Call %s {*}$args]} $method]
}