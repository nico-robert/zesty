# Copyright (c) 2025-2026 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.
# zesty : A Tcl library for rich terminal output.

# 15-Jun-2025 : v0.1 Initial release
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
# 29-Sep-2026 : v0.3
                # Adds `zesty::codeHighlights` command (Tcl syntax highlighting with tree-sitter).
                # Adds `zesty::rule`, `zesty::status` and `zesty::tree` commands.
                # Adds clickable links for urls, emails and inline tags.
                # Adds `-raw` and `-escape_map` options to `zesty::echo`.
                # Adds `-padding` option to `zesty::box` (fix #1, thanks @Hoffenbar).
                # Adds `zesty::setTerminalTitle` (camelCase name).
                # Adds `NO_COLOR` environment variable support.
                # Progress bars run in a dedicated display thread.
                # Errors no longer clear the terminal screen.
                # Fixes `win32.tcl` loading on all Windows platforms.
                # Fixes `zesty::echo -command` with multi-word commands.
                # Fixes extra trailing space in `zesty::echo`.
                # New examples: `zprogress_threaded`, `zrule`, `zstatus`, `ztree`.
# xx-xxx-2026 : v0.4
                # Adds nested style tags support.
                # Adds `separator` option to `-header` and `-footer` of class `Table`.
                # Adds multi-line headers and footers for class `Table`.
                # Table column widths respect `-minWidth`, `-maxWidth` and `-noWrap`.
                # Tabs are expanded in tables, boxes, rules and status messages.
                # Text width of emoji sequences, combining marks and symbols.
                # Terminal size falls back to `COLUMNS`/`LINES` or 80x24.
                # `zesty::jsonDecode` accepts JSON objects only.
                # Fixes `-box style` of class `Table` being ignored.
                # Fixes `zesty::codeHighlights` truncating code before parsing.
                # Fixes Windows console size, console mode and redirection detection.
                # Fixes many `Table`, `Bar`, `box`, `rule` and style parsing bugs.

package require Tcl 8.6-

namespace eval zesty {
    variable version 0.5a0
}

package provide zesty $::zesty::version