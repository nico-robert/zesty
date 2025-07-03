# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.
# zesty : A Tcl library for rich terminal output.

# 15-Jun-2025 : v1.0 Initial release
# 03-Jul-2025 : v0.2
                # Improved `Windows` Terminal detection
                # Enhanced args parsing.
                # Merged `cwin32.tcl` and `twin32.tcl` into `win32.tcl`
                # Adds -encoding `utf-8` option to `source` command for 
                # compatibility with `Windows` Tcl8.6 support.
                # Adds `common.tcl` file to facilitate common functions.
                # Adds `footer` support for class `Table`.
                # Major code refactoring.
                # Fixes minor bugs.

package require Tcl 8.6-

namespace eval zesty {
    variable version 0.2
}

package provide zesty $::zesty::version