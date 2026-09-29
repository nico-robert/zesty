# Copyright (c) 2026 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {}

proc zesty::rule {args} {
    # Creates a horizontal rule, with an optional title.
    #
    # args - variable arguments supporting:
    #  -title {options} - title configuration (name, style, align)
    #  -style {style}   - style of the line
    #  -char {char}     - character used to draw the line
    #  -width {number}  - maximum width (defaults to the terminal width)
    #
    # Returns: The rule as a string, to be displayed with zesty::echo.

    zesty::def options "-title" -validvalue formatVKVP -type struct -with {
        name   -validvalue {}           -type any|none  -default ""
        style  -validvalue formatStyle  -type any|none  -default ""
        align  -validvalue formatAlign  -type str       -default "center"
    }
    zesty::def options "-style" -validvalue formatStyle -type any|none -default ""
    zesty::def options "-char"  -validvalue formatLChar -type str      -default "─"
    zesty::def options "-width" -validvalue formatPad   -type num|none -default ""

    # Merge options and args
    set options [zesty::merge $options $args]

    # One spare column avoids the terminal autowrap on the last column.
    lassign [zesty::getTerminalSize] terminal_width
    set width [expr {$terminal_width - 1}]
    if {[dict get $options width] ne ""} {
        set width [expr {min($width, [dict get $options width])}]
    }

    set char  [dict get $options char]
    set style [dict get $options style]
    set name  [dict get $options title name]

    # The title needs at least its surrounding spaces, a line character
    # on each side and room for an ellipsis.
    set max_title [expr {$width - 4}]
    if {$name eq "" || $max_title < 4} {
        return [zesty::parseStyleDictToXML [string repeat $char $width] $style]
    }

    set title_width [zesty::strLength [zesty::extractVisibleText $name]]
    if {$title_width > $max_title} {
        set name [zesty::smartTruncateStyledText $name $max_title 1]
        set title_width $max_title
    }
    set title " [zesty::parseStyleDictToXML $name [dict get $options title style]] "

    # Line characters left on both sides of the title.
    set rest [expr {$width - $title_width - 2}]
    switch -exact -- [dict get $options title align] {
        left    {set left [expr {min(2, $rest - 1)}]}
        right   {set left [expr {$rest - min(2, $rest - 1)}]}
        default {set left [expr {$rest / 2}]}
    }
    set right [expr {$rest - $left}]

    return [join [list \
        [zesty::parseStyleDictToXML [string repeat $char $left] $style] \
        $title \
        [zesty::parseStyleDictToXML [string repeat $char $right] $style] \
    ] ""]
}
