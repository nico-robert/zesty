# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {}

proc zesty::SetTitle {text} {
    # Sets console title.
    #
    # text - title text
    #
    # Returns: nothing.
    twapi::set_console_title $text
    
    return {}
}

proc zesty::getInfoConsole {handle} {
    # Gets console screen buffer information.
    #
    # handle - console handle
    #
    # Returns: console screen buffer info dictionary or throws error
    # if the operation fails.
    return [twapi::get_console_screen_buffer_info $handle -all]
}

proc zesty::isNewTerminal {} {
    # Checks if running in a new Windows Terminal.
    # Traverses parent process hierarchy looking for Terminal
    # process name.
    #
    # Returns: 1 if running in Windows Terminal, 0 otherwise.

    # Checks if environment variable WT_SESSION or WT_PROFILE_ID is set.
    if {
        ([info exists ::env(WT_SESSION)] && ($::env(WT_SESSION) ne "")) ||
        ([info exists ::env(WT_PROFILE_ID)] && ($::env(WT_PROFILE_ID) ne ""))
    } {
        return 1
    }

    set parentPid [twapi::get_process_parent [twapi::get_current_process_id]]
    set cmdline [twapi::get_process_commandline $parentPid]
    
    if {[string match -nocase "*cmd.exe*" $cmdline]} {
        return 0
    }

    return 1
}

proc zesty::GetStdOutHandle {} {
    # Gets the standard output handle.
    #
    # Returns: the stdout handle.
    return [twapi::get_console_handle stdout]

}

proc zesty::SetConsoleMode {} {
    # Sets console mode to enable virtual terminal processing.
    # Enables processed output and virtual
    # terminal processing for ANSI escape sequence support.
    #
    # Returns: nothing
    set handle [zesty::GetStdOutHandle]
    twapi::SetConsoleMode $handle 5
    
    return {}
}

proc zesty::setColorDefaultConsole {} {
    # Restores console colors to their default state.
    #
    # Returns: nothing or throws error if operation fails.

    set handle [zesty::GetStdOutHandle]
    set info   [zesty::getInfoConsole $handle]
    set attr   [dict get $info -textattr]

    twapi::set_console_default_attr $handle {*}$attr
    
    return {}
}

proc zesty::SetConsoleCursorPosition {handle x y} {
    # Sets the console cursor position to specified coordinates.
    #
    # handle - console handle
    # x - horizontal position (column)
    # y - vertical position (row)
    #
    # Returns: nothing.

    twapi::set_console_cursor_position $handle [list $x $y]
    
    return {}
}

proc zesty::getConsoleCursorPosition {handle} {
    # Gets the current console cursor position.
    #
    # handle - console handle
    #
    # Returns: list containing X and Y coordinates of cursor position
    # or throws error if operation fails.

    return [twapi::get_console_cursor_position $handle]
}

proc zesty::getConsoleHeight {handle} {
    # Gets the console window height.
    #
    # handle - console handle
    #
    # Returns: the height in character rows of the visible console
    # window area.

    set info [zesty::getInfoConsole $handle]

    set windowlocation [dict get $info -windowlocation]
    lassign $windowlocation Left Top Right Bottom
    set srWindowBottom $Bottom
    set srWindowTop    $Top
    
    return [expr {$srWindowBottom - $srWindowTop}]

}

proc zesty::getConsoleWidth {handle} {
    # Gets the console window width.
    #
    # handle - console handle
    #
    # Returns: the width in character columns of the visible console
    # window area.

    set info [zesty::getInfoConsole $handle]

    set windowlocation [dict get $info -windowlocation]
    lassign $windowlocation Left Top Right Bottom
    set srWindowRight $Right
    set srWindowLeft  $Left
    
    return [expr {$srWindowRight - $srWindowLeft}]

}

# SetConsoleMode
if {![zesty::isNewTerminal]} zesty::SetConsoleMode