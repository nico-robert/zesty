#!/usr/bin/env tclsh

lappend auto_path [file dirname [file dirname [file normalize [info script]]]]
package require zesty

# Each key is a node, its value is the dictionary of its children.
set project {
    src {
        bar {core.tcl {} live.tcl {} render.tcl {}}
        utils.tcl {}
    }
    examples {zrule.tcl {} zstatus.tcl {}}
    README.md {}
}

zesty::echo "\n• Simple tree with a root:"
zesty::echo [zesty::tree $project -root "zesty"]

zesty::echo "\n• Without root:"
zesty::echo [zesty::tree $project]

zesty::echo "\n• Guide types (same as tables):"
foreach type {single rounded thick double ascii} {
    zesty::echo "\n-type $type"
    zesty::echo [zesty::tree {a {b {} c {}} d {}} -root "root" -type $type]
}

zesty::echo "\n• Styled guides and nodes:"
zesty::echo [zesty::tree {
    "<s fg=blue bold=1>src/</s>" {
        "<s fg=blue bold=1>bar/</s>" {core.tcl {} live.tcl {}}
        utils.tcl {}
    }
    "<s fg=green>README.md</s>" {}
} -root "<s fg=yellow bold=1>zesty</s>" -style {fg gray}]

# The user builds the dictionary from a real directory.
if {[package vsatisfies [package provide Tcl] 9-]} {
    set folder "\U0001F4C1"
    set doc    "\U0001F4C4"
} else {
    set folder [encoding convertfrom utf-8 "\xF0\x9F\x93\x81"]
    set doc    [encoding convertfrom utf-8 "\xF0\x9F\x93\x84"]
}

proc dirTree {dir} {
    global folder doc
    set tree {}
    foreach sub [lsort [glob -nocomplain -types d -directory $dir *]] {
        lappend tree "$folder <s fg=blue bold=1>[file tail $sub]/</s>" [dirTree $sub]
    }
    foreach file [lsort [glob -nocomplain -types f -directory $dir *]] {
        lappend tree "$doc [file tail $file]" {}
    }
    return $tree
}

zesty::echo "\n• Tree built from a directory:"
set root [file dirname [file dirname [file normalize [info script]]]]
zesty::echo [zesty::tree [dirTree [file join $root src]] \
    -root "$folder <s fg=yellow bold=1>src/</s>" -type rounded -style {fg cyan}]
