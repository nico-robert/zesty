#!/usr/bin/env tclsh

lappend auto_path [file dirname [file dirname [file normalize [info script]]]]
package require zesty

set ok   "<s fg=green>\u2714</s>"
set fail "<s fg=red>\u2718</s>"

zesty::echo "\n• Simple status (blocking work):"
zesty::status "Connecting to database..." {
    after 1500
}
zesty::echo "$ok Connected"

zesty::echo "\n• Styled message:"
zesty::status "Loading <s fg=cyan bold=1>configuration</s> from <s fg=yellow>config.ini</s>..." {
    after 1000
}

zesty::echo "\n• Result of the script:"
set count [zesty::status "Counting example files..." {
    after 800
    llength [glob -nocomplain -directory [file dirname [info script]] *.tcl]
}]
zesty::echo "$ok $count example files found"

zesty::echo "\n• Messages while working:"
zesty::status "Installing packages..." {
    foreach pkg {alpha beta gamma} {
        after 500
        zesty::echo "  installed $pkg"
    }
}

zesty::echo "\n• Spinner styles:"
foreach style [dict keys $zesty::spinnerstyles] {
    zesty::status -spinner $style "Spinner style '$style'..." {
        after 800
    }
}

zesty::echo "\n• Error handling (the user adds its own mark):"
if {[catch {
    zesty::status "Sending report..." {
        after 700
        error "SMTP server unreachable"
    }
} msg]} {
    zesty::echo "$fail Report not sent: $msg"
}

zesty::echo "\n• Several commands inside one status:"
set report [zesty::status "Analyzing example files..." {
    set files [glob -nocomplain -directory [file dirname [info script]] *.tcl]
    set lines 0
    set procs 0
    foreach file $files {
        set fh [open $file]
        set data [read $fh]
        close $fh
        incr lines [llength [split $data \n]]
        incr procs [regexp -all -line {^\s*proc } $data]
        after 150   ;# slow down to see the spinner
    }
    format "%d files, %d lines, %d procs" [llength $files] $lines $procs
}]
zesty::echo "$ok $report"

# Variables set inside the script live in the caller's context.
zesty::echo "  Variables created inside the script are still available: [llength $files] files"
