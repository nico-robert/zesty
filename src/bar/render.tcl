# Copyright (c) 2026 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty::render {
    variable shared
    variable objects {}
    variable timer ""
    variable rows 0
    variable previous {}
    variable interactive 0
    variable partial 0
    variable size {80 24}
    variable sizeDue 0
    variable frames 0
}

proc zesty::render::start {directory arrayName} {
    # Sources zesty in the display thread, measures the terminal
    # and starts the render loop.
    #
    # directory - zesty root directory
    # arrayName - name of the shared (tsv) array
    #
    # Returns: Nothing.
    variable shared
    set shared $arrayName
    # The worker sources the same package files; progressbar.tcl loads the real
    # class here because shared is already set. No class definitions are copied.
    uplevel #0 [list source -encoding utf-8 [file join $directory zesty.tcl]]
    if {$::tcl_platform(platform) eq "windows"} {
        package require registry
        uplevel #0 [list source -encoding utf-8 [file join $directory src win32.tcl]]
    }
    foreach file {parse colors utils style format common progressbar} {
        uplevel #0 [list source -encoding utf-8 [file join $directory src $file.tcl]]
    }

    zesty::render::measure
    tsv::set $shared frames 0
    zesty::render::tick
}

proc zesty::render::measure {} {
    # Measures the terminal size and detects if output is interactive.
    #
    # Returns: Nothing.
    variable size
    variable sizeDue
    variable interactive
    variable shared

    set sizeDue [expr {[clock milliseconds] + 500}]
    set measured [apply {{} {
        if {[catch {zesty::getTerminalSize} result]} { 
            return {} 
        } 
        return $result
    }}]
    set interactive [expr {[llength $measured] == 2}]
    if {$interactive} {
        set size $measured
    }
    tsv::set $shared size $size
}

proc zesty::render::add {owner args} {
    # Creates the worker-side bar associated with owner.
    #
    # owner - [zesty::Bar] application-side object
    # args  - bar configuration options
    #
    # Returns: The worker-side [zesty::Bar] object.
    variable objects

    set bar [zesty::Bar new $owner {*}$args]
    dict set objects $owner $bar

    return $bar
}

proc zesty::render::call {bar spinnerstyles method args} {
    # Calls a method on a worker-side bar, and draws immediately
    # on cleanup or completion.
    #
    # bar           - worker-side [zesty::Bar] object
    # spinnerstyles - spinner styles dictionary
    # method        - method name
    # args          - method arguments
    #
    # Returns: A list {result needsCallbacks fresh}.
    set ::zesty::spinnerstyles $spinnerstyles
    set result [$bar $method {*}$args]
    # Completion and cleanup must be visible before returning to the caller.
    if {$method eq "cleanup" || [$bar finished]} {draw}
    return [list $result {*}[$bar callbackStatus]]
}

proc zesty::render::recordError {message options} {
    # Stores an error in shared storage so the owner thread can rethrow it.
    #
    # message - error message
    # options - error options dictionary
    #
    # Returns: Nothing.
    variable shared

    tsv::set $shared error [list $message $options]
}

proc ::zesty::render::tick {} {
    # Render loop: draws the frame every 50 ms and records errors.
    #
    # Returns: Nothing.
    variable timer

    set timer ""
    if {[catch {zesty::render::draw} message options]} {
        zesty::render::recordError $message $options
    }
    set timer [after 50 ::zesty::render::tick]
}

proc zesty::render::draw {{force 0}} {
    # Draws all bars in the terminal, only if lines have changed.
    #
    # force - redraw even if lines are unchanged
    #
    # Returns: Nothing.
    variable shared
    variable objects
    variable rows
    variable previous
    variable interactive
    variable partial
    variable size
    variable sizeDue
    variable frames

    set now [clock milliseconds]
    if {$now >= $sizeDue} {
        zesty::render::measure
    }

    lassign $size width height
    set lines {}
    dict for {name object} $objects {
        foreach line [$object lines $now $width $height] {
            # Keep each task/header on one physical terminal line. Leave one
            # spare column to avoid autowrap, including on narrow terminals.
            set line [string map [list \n " " \r " " \t " "] $line]
            set line [zesty::smartTruncateStyledText $line [expr {max(1, $width - 1)}] 1]
            if {$interactive} {
                lappend lines [zesty::parseStyle $line {}]
            } else {
                lappend lines [zesty::extractVisibleText $line]
            }
        }
    }
    if {$interactive} {
        set lines [lrange $lines end-[expr {max(1, $height - 1) - 1}] end]
    }
    # Internal diagnostics used by tests; memory is bounded to one last frame.
    tsv::set $shared lines $lines
    if {$partial} {return}
    if {$lines eq $previous && !$force} {return}
    if {!$interactive} {
        # Redirected output is a final snapshot, not an animation log.
        if {$force && [llength $lines]} {
            puts stdout [join $lines \n]
            flush stdout
        }
        set previous $lines
        return
    }
    set output "\r"
    if {$rows} {
        append output "\033\[${rows}A"
    }
    foreach line $lines {
        append output $line "\033\[0m" "\033\[K" "\r\n"
    }
    if {[llength $lines] < $rows} {
        append output "\033\[J"
    }

    puts -nonewline stdout $output
    flush stdout
    set rows [llength $lines]
    set previous $lines
    tsv::set $shared frames [incr frames]
}

proc zesty::render::erase {} {
    # Erases the live region from the terminal.
    #
    # Returns: Nothing.
    variable rows
    variable previous
    variable interactive

    if {$interactive && $rows} {
        puts -nonewline stdout "\r\033\[${rows}A\033\[J"
        flush stdout
    }
    set rows 0
    set previous {}
}

proc zesty::render::withMessage {text newline} {
    # Erases the live region, writes a message formatted by the
    # application thread, then redraws the bars below it.
    #
    # text    - formatted text
    # newline - 1 to append a newline, 0 otherwise
    #
    # Returns: Nothing.
    zesty::render::erase
    try {
        if {$newline} {
            zesty::echo -raw $text
        } else {
            zesty::echo -raw -n $text
        }
    } finally {
        flush stdout
        zesty::render::messageWritten $text $newline
        zesty::render::draw
    }
    return {}
}

proc zesty::render::messageWritten {text newline} {
    # Tracks whether the last message left an unfinished line,
    # in which case drawing is suspended.
    #
    # text    - written text
    # newline - 1 if a newline was appended
    #
    # Returns: Nothing.
    variable partial
    # Style resets after a newline do not make that line unfinished.
    regsub -all {\x1b\[[0-9;]*m} $text {} text
    if {$newline || [string index $text end] eq "\n"} {
        set partial 0
    } elseif {$text ne ""} {
        set partial 1
    }
}

proc zesty::render::remove {name} {
    # Destroys the worker-side bar associated with name and redraws
    # the remaining bars.
    #
    # name - [zesty::Bar] application-side object
    #
    # Returns: Nothing.
    variable objects
    variable rows
    variable previous
    variable interactive
    variable size
    variable shared

    if {![dict exists $objects $name]} {
        return
    }
    try {
        zesty::render::draw
        if {!$interactive} {
            # Each removed bar gets exactly one final snapshot in a pipe/file.
            foreach line [[dict get $objects $name] lines [clock milliseconds] {*}$size] {
                puts stdout [zesty::extractVisibleText [string map [list \n " " \r " " \t " "] $line]]
            }
            flush stdout
        }
    } finally {
        set bar [dict get $objects $name]
        $bar destroy
        # The key only exists if this bar has used custom/callback columns.
        catch {tsv::unset $shared "custom:$bar"}
        dict unset objects $name
        if {[dict size $objects]} {
            zesty::render::draw
        } else {
            # Leave the final frame on screen; the next display starts below it.
            set rows 0
            set previous {}
        }
    }
}

proc zesty::render::stop {} {
    # Cancels the render loop timer and flushes stdout.
    #
    # Returns: Nothing.
    variable timer
    if {$timer ne ""} {
        after cancel $timer
        set timer ""
    }
    flush stdout
}