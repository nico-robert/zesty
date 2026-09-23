#!/usr/bin/env tclsh

# Test file for zesty::codeHighlights command.
# This file demonstrates various features and capabilities of the zesty::codeHighlights system.

lappend auto_path [file dirname [file dirname [file normalize [info script]]]]

package require zesty

proc getInfoCmd {name} {
    append result "proc $name {[info args $name]} {"
    append result [info body $name]
    append result "}"

    return $result
}

set code [getInfoCmd zesty::parseStyleDictToXML]

# Simple usage, no options
set result [zesty::codeHighlights -code $code -linesNumber {show false}]
# Similar to the Tcl puts command
zesty::echo -raw $result

# Using options : show whitespace characters
set result [zesty::codeHighlights -code $code \
    -whiteSpace {show true style {fg orange}} \
    -verticalGuides {show true} \
]
zesty::echo -raw $result

# Using options : show vertical guides + custom style for particular words.
set result [zesty::codeHighlights -code $code \
    -verticalGuides {show true} \
    -words {map string} \
    -linesNumber {show false} \
    -style {custom {fg red}} \
]

zesty::echo -raw $result