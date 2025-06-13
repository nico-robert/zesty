#!/usr/bin/env tclsh

# Test file for zesty::jsonDecode command.
# This file demonstrates the capabilities of the zesty::jsonDecode system.

lappend auto_path [file dirname [file dirname [file normalize [info script]]]]

package require zesty

set json {
    {
    "backgroundColor": "rgba(0,0,0,0)",
    "color": [
        "#5470c6",
        "#91cc75",
        "#fac858",
        "#ee6666",
        "#73c0de",
        "#3ba272",
        "#fc8452",
        "#9a60b4",
        "#ea7ccc"
    ],
    "animation": true,
    "animationDuration": 1000,
    "animationDurationUpdate": 500,
    "animationEasing": "cubicInOut",
    "animationEasingUpdate": "cubicInOut",
    "animationThreshold": 2000,
    "progressiveThreshold": 3000,
    "useUTC": null
    }

}

zesty::echo [zesty::jsonDecode -json $json -style {str {fg cyan} num {fg red}}]
