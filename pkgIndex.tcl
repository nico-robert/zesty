# Copyright (c) 2025-2026 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

package ifneeded zesty 0.2 [list apply {dir {
    package require platform
    package require Thread

    source -encoding utf-8 [file join $dir zesty.tcl]
    
    if {[platform::generic] eq "win32-x86_64"} {
        package require registry
        source -encoding utf-8 [file join $dir src win32.tcl]
    }

    source -encoding utf-8 [file join $dir src parse.tcl]
    source -encoding utf-8 [file join $dir src colors.tcl]
    source -encoding utf-8 [file join $dir src utils.tcl]
    source -encoding utf-8 [file join $dir src style.tcl]
    source -encoding utf-8 [file join $dir src format.tcl]
    source -encoding utf-8 [file join $dir src common.tcl]
    source -encoding utf-8 [file join $dir src box.tcl]
    source -encoding utf-8 [file join $dir src json.tcl]
    source -encoding utf-8 [file join $dir src table.tcl]
    source -encoding utf-8 [file join $dir src progressbar.tcl]
    source -encoding utf-8 [file join $dir src highlights.tcl]
 
}} $dir]