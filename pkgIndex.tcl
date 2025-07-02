# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

package ifneeded zesty 0.1 [list apply {dir {
    package require platform

    source -encoding utf-8 [file join $dir zesty.tcl]
    
    if {[platform::generic] eq "win32-x86_64"} {
        package require registry
        source -encoding utf-8 [file join $dir win32.tcl]
    }

    source -encoding utf-8 [file join $dir parse.tcl]
    source -encoding utf-8 [file join $dir colors.tcl]
    source -encoding utf-8 [file join $dir utils.tcl]
    source -encoding utf-8 [file join $dir style.tcl]
    source -encoding utf-8 [file join $dir format.tcl]
    source -encoding utf-8 [file join $dir common.tcl]
    source -encoding utf-8 [file join $dir box.tcl]
    source -encoding utf-8 [file join $dir json.tcl]
    source -encoding utf-8 [file join $dir table.tcl]
    source -encoding utf-8 [file join $dir progressbar.tcl]
 
}} $dir]