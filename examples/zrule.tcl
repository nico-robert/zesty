#!/usr/bin/env tclsh

# Demonstrates the zesty::rule command (horizontal rules).

lappend auto_path [file dirname [file dirname [file normalize [info script]]]]
package require zesty

zesty::echo "\n• Full terminal width, without title:"
zesty::echo [zesty::rule]

zesty::echo "\n• Centered title:"
zesty::echo [zesty::rule -title {name "Centered title"}]

zesty::echo "\n• Title alignment:"
zesty::echo [zesty::rule -title {name "Left" align left} -width 50]
zesty::echo [zesty::rule -title {name "Center"} -width 50]
zesty::echo [zesty::rule -title {name "Right" align right} -width 50]

zesty::echo "\n• Styles:"
zesty::echo [zesty::rule -title {name "Cyan line"} -width 50 -style {fg cyan}]
zesty::echo [zesty::rule -title {name "Bold yellow title" style {fg yellow bold 1}} -width 50]
zesty::echo [zesty::rule -title {name "<s fg=red>Inline</s> <s fg=green>styles</s>"} -width 50]

zesty::echo "\n• Custom characters:"
# \u2550 is '═', written this way so that Tcl 8.6 reads the script
# correctly whatever the system encoding.
zesty::echo [zesty::rule -title {name "Double"} -char "\u2550" -width 50 -style {fg magenta}]
zesty::echo [zesty::rule -title {name "Dashes"} -char "-" -width 50]
zesty::echo [zesty::rule -title {name "Stars"} -char "*" -width 50]

zesty::echo "\n• Maximum width:"
zesty::echo [zesty::rule -title {name "20 columns"} -width 20]
zesty::echo [zesty::rule -title {name "Larger than the terminal: capped"} -width 9999]

zesty::echo "\n• Title longer than the rule (truncated):"
zesty::echo [zesty::rule -title {name "A very long title that does not fit in the rule"} -width 30]
