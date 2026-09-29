# Copyright (c) 2026 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {}

proc zesty::status {args} {
    # Displays an animated spinner followed by a message while a script
    # runs in the caller's context. When the script ends, the spinner is
    # removed and the message stays on screen.
    #
    # args - ?options? message script
    #   options:
    #   -spinner {style} - spinner style (default: dots). Available styles
    #                      are the keys of zesty::spinnerstyles (dots, line,
    #                      circle, emoji, arrows, bars, moon).
    #   message - message to display (may contain style tags)
    #   script  - script to evaluate in the caller's context
    #
    # Returns: The result of the script. Errors are propagated.
    if {[llength $args] < 2} {
        error "zesty(error): wrong # args: should be\
            \"zesty::status ?-spinner style? message script\""
    }
    lassign [lrange $args end-1 end] message script

    zesty::def options "-spinner" -validvalue {} -type str -default "dots"
    set options [zesty::merge $options [lrange $args 0 end-2]]

    # Checked before creating the bar, so an error leaves nothing on screen.
    set spinner [dict get $options spinner]
    if {![dict exists $::zesty::spinnerstyles $spinner]} {
        error "zesty(error): spinner must be one of:\
            [join [dict keys $::zesty::spinnerstyles] ", "]"
    }

    set bar [zesty::Bar new -setColumns {zSpinner zName}]
    $bar configureColumn zSpinner -spinnerStyle $spinner
    $bar configureColumn zName -width [expr {
        max(1, [zesty::strLength [zesty::extractVisibleText $message]])
    }]
    $bar addTask -name $message -mode indeterminate
    try {
        return [uplevel 1 $script]
    } finally {
        $bar configureColumn zSpinner -visible 0
        $bar destroy
    }
}
