# Copyright (c) 2026 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {}

proc zesty::tree {data args} {
    # Creates a tree view from a nested dictionary.
    #
    # data - nested dictionary: each key is a node, its value is the
    #        dictionary of its children (empty for a leaf).
    # args - variable arguments supporting:
    #  -root {text}   - root label displayed on the first line
    #  -type {type}   - guides type, same as tables (single, double,
    #                   rounded, thick, ascii)
    #  -style {style} - style of the guides
    #
    # Returns: The tree as a string, to be displayed with zesty::echo.
    variable tablestyles

    zesty::def options "-root"  -validvalue {}          -type any|none -default ""
    zesty::def options "-type"  -validvalue {}          -type str      -default "single"
    zesty::def options "-style" -validvalue formatStyle -type any|none -default ""

    # Merge options and args
    set options [zesty::merge $options $args]

    set type [dict get $options type]
    if {![dict exists $tablestyles $type]} {
        error "zesty(error): type must be one of:\
            [join [dict keys $tablestyles] ", "]"
    }

    # Tree guides built from the table style characters.
    lassign [dict get $tablestyles $type] - - bottom_left - vertical horizontal - - - left_tee
    set style [dict get $options style]
    set line [string repeat $horizontal 2]
    set guides {}
    foreach guide [list "$left_tee$line " "$bottom_left$line " "$vertical   " "    "] {
        lappend guides [zesty::parseStyleDictToXML $guide $style]
    }

    set lines {}
    if {[dict get $options root] ne ""} {
        lappend lines [dict get $options root]
    }
    zesty::TreeLines $data "" $guides lines

    return [join $lines \n]
}

proc zesty::TreeLines {data prefix guides linesVar} {
    # Appends the lines of a tree level, recursively.
    #
    # data     - dictionary of the nodes of this level
    # prefix   - guides drawn before the nodes of this level
    # guides   - styled guides {branch last vertical empty}
    # linesVar - name of the list of lines in the caller
    #
    # Returns: Nothing.
    upvar 1 $linesVar lines
    lassign $guides branch last vertical empty

    if {[llength $data] % 2} {
        error "zesty(error): tree data must be a dictionary\
            (node children pairs): '$data'"
    }
    set count [expr {[llength $data] / 2}]
    set i 0
    # foreach rather than dict for: keeps order and duplicate names.
    foreach {name children} $data {
        set isLast [expr {[incr i] == $count}]
        lappend lines "$prefix[expr {$isLast ? $last : $branch}]$name"
        if {$children ne ""} {
            zesty::TreeLines $children \
                "$prefix[expr {$isLast ? $empty : $vertical}]" $guides lines
        }
    }

    return {}
}
