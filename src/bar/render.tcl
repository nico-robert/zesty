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
    variable objects

    set bar [zesty::Bar new $owner {*}$args]
    dict set objects $owner $bar

    return $bar
}

proc zesty::render::call {bar spinnerstyles method args} {
    set ::zesty::spinnerstyles $spinnerstyles
    set result [$bar $method {*}$args]
    # Completion and cleanup must be visible before returning to the caller.
    if {$method eq "cleanup" || [$bar finished]} {draw}
    return [list $result {*}[$bar callbackStatus]]
}

proc zesty::render::recordError {message options} {
    variable shared

    tsv::set $shared error [list $message $options]
}

proc ::zesty::render::tick {} {
    variable timer

    set timer ""
    if {[catch {zesty::render::draw} message options]} {
        zesty::render::recordError $message $options
    }
    set timer [after 50 ::zesty::render::tick]
}

proc zesty::render::draw {{force 0}} {
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

# Coordinate the live region; zesty::echo remains the only message formatter
# and writer. No calls back into the owner are made from this interpreter.
proc zesty::render::withMessage {args result} {
    variable callbackResult
    set callbackResult $result
    zesty::render::erase
    try {
        zesty::echo {*}$args
    } finally {
        unset callbackResult
        flush stdout
        zesty::render::draw
    }
}

proc zesty::render::echoCallback {text} {
    variable callbackResult
    return $callbackResult
}

proc zesty::render::messageWritten {text newline} {
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
    variable timer
    if {$timer ne ""} {
        after cancel $timer
        set timer ""
    }
    flush stdout
}