# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {}

# Entry point: load the real class in the display thread, or the
# application-side relay otherwise. Each target file keeps a single,
# fixed role, so there is no dual-purpose sourcing.
set bar_dir [file dirname [info script]]
if {[info exists ::zesty::render::shared]} {
    source -encoding utf-8 [file join $bar_dir bar core.tcl]
} else {
    source -encoding utf-8 [file join $bar_dir bar live.tcl]
}