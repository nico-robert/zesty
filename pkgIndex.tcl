# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

package ifneeded zesty 0.1 [list apply {dir {
    package require platform

    source [file join $dir zesty.tcl]
    
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
        source [file join $dir $file]
    }

    source [file join $dir parse.tcl]
    source [file join $dir colors.tcl]
    source [file join $dir utils.tcl]
    source [file join $dir style.tcl]
    source [file join $dir box.tcl]
    source [file join $dir json.tcl]
    source [file join $dir table.tcl]
    source [file join $dir progressbar.tcl]
 
}} $dir]