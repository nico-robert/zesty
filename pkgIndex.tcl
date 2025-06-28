# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

package ifneeded zesty 0.1 [list apply {dir {
    package require platform

    source -encoding utf-8 [file join $dir zesty.tcl]
    
    if {[platform::generic] eq "win32-x86_64"} {
        package req registry

        if {![catch {package req twapi}]} {
            set file twin32.tcl
        } elseif {![catch {package req cffi 2.0}]} {
            set file cwin32.tcl
        } else {
            error "package 'twapi' or 'cffi >= 2.0'\
            should be present for Windows platform"
        }
        source -encoding utf-8 [file join $dir $file]
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