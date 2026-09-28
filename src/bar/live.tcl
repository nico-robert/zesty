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

    constructor {args} {
        set _remoteBar ""
        set _refreshing 0
        set _timer ""
        set _due 0
        set _pending 0
        zesty::live::validateColumns {*}$args
        set _remoteBar [zesty::live::acquire [self] {*}$args]
    }

    destructor {
        if {[info exists _timer] && $_timer ne ""} {
            after cancel $_timer
        }
        if {[info exists _remoteBar] && $_remoteBar ne ""} {
            zesty::live::release [self]
        }
    }

    # Calling destroy from a callback would invalidate its in-flight results.
    method destroy {} {
        if {$_refreshing} {
            error "zesty(error): destroy cannot run inside a column callback"
        }
        next
    }

    method Call {method args} {
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
        if {$_timer ne ""} {
            after cancel $_timer
            set _timer ""
        }
        if {$_pending && !$_refreshing} {
            set _timer [after 100 [list [self] tick]]
        }
    }

    method tick {} {
        set _timer ""
        my Refresh
        my Schedule
    }

    method Refresh {} {
        if {$_refreshing || !$_pending || [clock milliseconds] < $_due} {return}
        set _refreshing 1
        try {
            zesty::live::check
            lassign [thread::send $::zesty::live::tid \
                [list $_remoteBar callbackJobs]] generation jobs
            set values {}
            foreach job $jobs {
                lassign $job task column command
                dict set values $task $column [uplevel #0 $command]
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
    }

    method getONSClass {} {return [info object namespace [self class]]}
}

proc zesty::live::active {} {
    variable tid
    return [expr {$tid ne ""}]
}

proc zesty::live::check {} {
    variable tid
    variable shared
    if {$tid eq "" || ![thread::exists $tid]} {
        error "zesty(error): display thread is not running"
    }
    if {[tsv::exists $shared error]} {
        lassign [tsv::get $shared error] message options
        return -options $options $message
    }
}

proc zesty::live::stop {} {
    variable tid
    variable shared
    if {$tid eq ""} {return}
    thread::send $tid {zesty::render::stop}
    thread::release $tid
    thread::join $tid
    tsv::unset $shared
    set tid ""
    set shared ""
}

proc zesty::live::acquire {owner args} {
    variable directory
    variable tid
    variable shared
    variable bars
    variable serial

    try {
        if {$tid eq ""} {
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
}

# Resolve user commands where they are defined; never copy procedure bodies or
# guess which globals, packages or objects a callback might depend on.
proc zesty::live::columnType {type} {
    if {$type ni {zName zCount zBar zPercent zElapsed zRemaining zSpinner zSeparator} &&
        [uplevel #0 [list namespace which -command $type]] eq ""} {
        error "zesty(error): A command must be associated with '$type' column type."
    }
    return $type
}

proc zesty::live::validateColumns {args} {
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