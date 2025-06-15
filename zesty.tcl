# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.
# zesty : A Tcl library for rich terminal output.

# 15-Jun-2025 : v1.0 Initial release

package require Tcl 8.6-

namespace eval zesty {
    variable version 0.1
}

package provide zesty $::zesty::version