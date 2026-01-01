# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {
    namespace eval win32 {
        # twapi backend
        if {![catch {package require twapi}]} {

            proc setTitle {text} {
                # Sets console title.
                #
                # text - title text
                #
                # Returns: nothing.
                ::twapi::set_console_title $text
                return {}
            }

            proc getInfoConsole {handle} {
                # Gets console screen buffer information.
                #
                # handle - console handle
                #
                # Returns: console screen buffer info dictionary or throws error
                # if the operation fails.
                return [::twapi::get_console_screen_buffer_info $handle -all]
            }

            proc isNewTerminal {} {
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

                set parentPid [::twapi::get_process_parent [::twapi::get_current_process_id]]
                set cmdline [::twapi::get_process_commandline $parentPid]

                if {[string match -nocase "*cmd.exe*" $cmdline]} {
                    return 0
                }

                return 1
            }

            proc getStdOutHandle {} {
                # Gets the standard output handle.
                #
                # Returns: the stdout handle.
                return [::twapi::get_console_handle stdout]
            }

            proc setConsoleMode {} {
                # Sets console mode to enable virtual terminal processing.
                # Enables processed output and virtual
                # terminal processing for ANSI escape sequence support.
                #
                # Returns: nothing
                set handle [getStdOutHandle]
                ::twapi::SetConsoleMode $handle 5

                return {}
            }

            proc setColorDefaultConsole {} {
                # Restores console colors to their default state.
                #
                # Returns: nothing or throws error if operation fails.
                set handle [getStdOutHandle]
                set info   [getInfoConsole $handle]
                set attr   [dict get $info -textattr]

                ::twapi::set_console_default_attr $handle {*}$attr

                return {}
            }

            proc setConsoleCursorPosition {handle x y} {
                # Sets the console cursor position to specified coordinates.
                #
                # handle - console handle
                # x - horizontal position (column)
                # y - vertical position (row)
                #
                # Returns: nothing.
                ::twapi::set_console_cursor_position $handle [list $x $y]

                return {}
            }

            proc getConsoleCursorPosition {handle} {
                # Gets the current console cursor position.
                #
                # handle - console handle
                #
                # Returns: list containing X and Y coordinates of cursor position
                # or throws error if operation fails.
                return [::twapi::get_console_cursor_position $handle]
            }

            proc getConsoleHeight {handle} {
                # Gets the console window height.
                #
                # handle - console handle
                #
                # Returns: the height in character rows of the visible console
                # window area.
                set info [getInfoConsole $handle]

                set windowlocation [dict get $info -windowlocation]
                lassign $windowlocation Left Top Right Bottom
                set srWindowBottom $Bottom
                set srWindowTop    $Top

                return [expr {$srWindowBottom - $srWindowTop}]

            }

            proc getConsoleWidth {handle} {
                # Gets the console window width.
                #
                # handle - console handle
                #
                # Returns: the width in character columns of the visible console
                # window area.
                set info [getInfoConsole $handle]

                set windowlocation [dict get $info -windowlocation]
                lassign $windowlocation Left Top Right Bottom
                set srWindowRight $Right
                set srWindowLeft  $Left

                return [expr {$srWindowRight - $srWindowLeft}]

            }

        # cffi backend
        } elseif {![catch {package require cffi 2.0}]} {

            # win32 console
            ::cffi::alias load C
            ::cffi::alias load win32

            namespace eval k32 {

                # load cffi wrapper library.
                ::cffi::Wrapper create K32 Kernel32.dll

                ::cffi::enum define stdenum_ {
                    STD_INPUT_HANDLE  -10
                    STD_OUTPUT_HANDLE -11
                    STD_ERROR_HANDLE  -12
                }

                ::cffi::alias define STDFLAGS {DWORD {enum stdenum_}}

                ::cffi::Struct create COORD {
                    X SHORT 
                    Y SHORT
                }

                ::cffi::Struct create SMALL_RECT {
                    Left   SHORT 
                    Top    SHORT
                    Right  SHORT
                    Bottom SHORT
                }

                ::cffi::Struct create CONSOLE_CURSOR_INFO {
                    dwSize   struct.COORD
                    bVisible BOOL
                }

                ::cffi::enum define color_ {
                    FOREGROUND_BLACK           0x0000
                    FOREGROUND_BLUE            0x0001
                    FOREGROUND_GREEN           0x0002	
                    FOREGROUND_CYAN            0x0003	
                    FOREGROUND_RED             0x0004
                    FOREGROUND_MAGENTA         0x0005
                    FOREGROUND_YELLOW          0x0006
                    FOREGROUND_WHITE           0x0007
                    FOREGROUND_INTENSITY       0x0008
                    BACKGROUND_BLUE            0x0010
                    BACKGROUND_GREEN           0x0020
                    BACKGROUND_CYAN            0x0030
                    BACKGROUND_RED             0x0040
                    BACKGROUND_MAGENTA         0x0050
                    BACKGROUND_YELLOW          0x0060
                    BACKGROUND_WHITE           0x0070
                    BACKGROUND_INTENSITY       0x0080
                    COMMON_LVB_LEADING_BYTE    0x0100
                    COMMON_LVB_TRAILING_BYTE   0x0200
                    COMMON_LVB_GRID_HORIZONTAL 0x0400
                    COMMON_LVB_GRID_LVERTICAL  0x0800
                    COMMON_LVB_GRID_RVERTICAL  0x1000
                    COMMON_LVB_REVERSE_VIDEO   0x4000
                    COMMON_LVB_UNDERSCORE      0x8000
                }

                ::cffi::alias define DWC {WORD {enum color_}}

                ::cffi::Struct create CONSOLE_SCREEN_BUFFER_INFO {
                    dwSize              struct.COORD 
                    dwCursorPosition    struct.COORD 
                    wAttributes         {DWC bitmask}
                    srWindow            struct.SMALL_RECT
                    dwMaximumWindowSize struct.COORD
                }

                ::cffi::enum define stdmode_ {
                    ENABLE_ECHO_INPUT                  0x0004
                    ENABLE_INSERT_MODE                 0x0020
                    ENABLE_LINE_INPUT                  0x0002
                    ENABLE_MOUSE_INPUT                 0x0010
                    ENABLE_PROCESSED_INPUT             0x0001
                    ENABLE_QUICK_EDIT_MODE             0x0040
                    ENABLE_WINDOW_INPUT                0x0008
                    ENABLE_VIRTUAL_TERMINAL_INPUT      0x0200
                    ENABLE_PROCESSED_OUTPUT            0x0001
                    ENABLE_WRAP_AT_EOL_OUTPUT          0x0002
                    ENABLE_VIRTUAL_TERMINAL_PROCESSING 0x0004
                    DISABLE_NEWLINE_AUTO_RETURN        0x0008
                    ENABLE_LVB_GRID_WORLDWIDE          0x0010
                }

                ::cffi::enum define dwFlags_ [list \
                    TH32CS_INHERIT      0x80000000 \
                    TH32CS_SNAPALL      [expr {0x00000001 | 0x00000008 | 0x00000002 | 0x00000004}] \
                    TH32CS_SNAPHEAPLIST 0x00000001 \
                    TH32CS_SNAPMODULE   0x00000008 \
                    TH32CS_SNAPMODULE32 0x00000010 \
                    TH32CS_SNAPPROCESS  0x00000002 \
                    TH32CS_SNAPTHREAD   0x00000004 \
                ]

                ::cffi::alias define STDMODE  {DWORD {enum stdmode_}}
                ::cffi::alias define DWFLAGS  {DWORD {enum dwFlags_}}
                ::cffi::alias define TCHAR    uchar
                ::cffi::alias define LPCTSTR  winstring

                ::cffi::Struct create PROCESSENTRY32 {
                    dwSize              struct.COORD
                    cntUsage            DWORD
                    th32ProcessID       DWORD
                    th32DefaultHeapID   ULONG_PTR
                    th32ModuleID        DWORD
                    cntThreads          DWORD
                    th32ParentProcessID DWORD
                    pcPriClassBase      LONG
                    dwFlags             DWFLAGS
                    szExeFile           chars[256]
                }

                K32 stdcall CreateToolhelp32Snapshot HANDLE {
                    flags         DWFLAGS
                    th32ProcessID DWORD
                }

                K32 stdcall GetCurrentProcessId DWORD {}

                K32 stdcall CloseHandle BOOL {
                    hObject HANDLE
                }

                K32 stdcall Process32First BOOL {
                    hSnapshot HANDLE
                    lppe {struct.PROCESSENTRY32 out}
                }

                K32 stdcall Process32Next BOOL {
                    hSnapshot HANDLE
                    lppe {struct.PROCESSENTRY32 out}
                }

                K32 stdcall GetStdHandle HANDLE {
                    nStdHandle STDFLAGS
                }

                K32 stdcall GetConsoleMode BOOL {
                    hConsoleHandle HANDLE
                    lpMode         {pointer.LPDWORD out}
                }

                K32 stdcall FillConsoleOutputCharacterW BOOL {
                    hConsoleOutput         HANDLE
                    cCharacter             TCHAR
                    nLength                DWORD
                    dwWriteCoord           struct.COORD
                    lpNumberOfCharsWritten {pointer.LPDWORD out}
                }

                K32 stdcall FillConsoleOutputAttribute BOOL {
                    hConsoleOutput         HANDLE
                    wAttribute             DWC
                    nLength                DWORD
                    dwWriteCoord           struct.COORD
                    lpNumberOfAttrsWritten {pointer.LPDWORD out}
                }

                K32 stdcall SetConsoleTextAttribute BOOL {
                    hConsoleOutput HANDLE
                    wAttributes    {DWC bitmask}
                }

                K32 stdcall GetConsoleScreenBufferInfo BOOL {
                    hConsoleOutput            HANDLE
                    lpConsoleScreenBufferInfo {struct.CONSOLE_SCREEN_BUFFER_INFO out}
                }

                K32 stdcall SetConsoleCursorPosition BOOL {
                    hConsoleOutput   HANDLE
                    dwCursorPosition struct.COORD
                }

                K32 stdcall GetConsoleCursorInfo BOOL {
                    hConsoleOutput      HANDLE
                    lpConsoleCursorInfo {struct.CONSOLE_CURSOR_INFO out}
                }

                K32 stdcall SetConsoleCursorInfo BOOL {
                    hConsoleOutput      HANDLE
                    lpConsoleCursorInfo pointer.CONSOLE_CURSOR_INFO
                }

                K32 stdcall SetConsoleTitleW BOOL {
                    lpConsoleTitle LPCTSTR
                }

                K32 stdcall SetConsoleMode BOOL {
                    hConsoleHandle HANDLE
                    dwMode         {STDMODE  bitmask}
                }

                K32 stdcall SetConsoleOutputCP BOOL {
                    wCodePageID UINT
                }

                K32 stdcall SetConsoleCP BOOL {
                    wCodePageID UINT
                }
            }

            proc setTitle {text} {
                # See twapi procedure for details.
                #
                if {![k32::SetConsoleTitleW $text]} {
                    error "zesty(error): Console title fails."
                }

                return {}
            }

            proc getInfoConsole {handle} {
                # See twapi procedure for details.
                #
                if {![k32::GetConsoleScreenBufferInfo $handle default]} {
                    error "zesty(error): Getting console screen buffer\
                        information fails."
                }
                return $default
            }

            proc getInfoProcess {pid} {
                # Gets process information by process ID.
                #
                # pid - process ID to lookup
                #
                # Returns: list containing parent process ID and executable name,
                # or "null" if process not found or error occurs.
                set handle [k32::CreateToolhelp32Snapshot TH32CS_SNAPPROCESS 0]

                if {[::cffi::pointer isnull $handle]} {
                    error "zesty(error): Process snapshot 'handle' is null."
                }

                k32::Process32First $handle dictinfo
                if {[dict get $dictinfo th32ProcessID] != $pid} {
                    while 1 {
                        k32::Process32Next $handle dictinfo
                        if {[dict get $dictinfo th32ProcessID] == $pid} {
                            k32::CloseHandle $handle
                            return [list [dict get $dictinfo th32ParentProcessID] \
                                [dict get $dictinfo szExeFile]]
                        }
                        if {[incr i] > 1000} {
                            k32::CloseHandle $handle
                            return null
                        }
                    }
                } else {
                    return [list [dict get $dictinfo th32ParentProcessID] \
                        [dict get $dictinfo szExeFile]]
                }
            }

            proc isNewTerminal {} {
                # See twapi procedure for details.
                #
                if {
                    ([info exists ::env(WT_SESSION)] && ($::env(WT_SESSION) ne "")) ||
                    ([info exists ::env(WT_PROFILE_ID)] && ($::env(WT_PROFILE_ID) ne ""))
                } {
                    return 1
                }

                set name "null"
                set parentPid [getInfoProcess [k32::GetCurrentProcessId]]

                set limit 0
                while {$limit < 6} {
                    if {$parentPid ne "null"} {
                        set pidP [lindex $parentPid 0]
                        set parentPid [getInfoProcess $pidP]
                        set name [lindex $parentPid end]
                        if {[string match -nocase "*Terminal*" $name]} {
                            return 1
                        }
                    }
                    incr limit
                }

                return 0
            }

            proc getStdOutHandle {} {
                # See twapi procedure for details.
                #
                set handle [k32::GetStdHandle STD_OUTPUT_HANDLE]

                if {[::cffi::pointer isnull $handle]} {
                    error "zesty(error): 'stdout' handle is null."
                }

                return $handle
            }

            proc setConsoleMode {} {
                # See twapi procedure for details.
                #
                set handle [getStdOutHandle]

                k32::SetConsoleMode $handle {
                    ENABLE_PROCESSED_OUTPUT 
                    ENABLE_VIRTUAL_TERMINAL_PROCESSING
                }

                return {}
            }

            proc setColorDefaultConsole {} {
                # See twapi procedure for details.
                #
                set handle [getStdOutHandle]
                set info   [getInfoConsole $handle]
                set attr   [dict get $info wAttributes]

                if {![k32::SetConsoleTextAttribute $handle $attr]} {
                    error "zesty(error): Setting console text attribute fails."
                }

                return {}
            }

            proc setConsoleCursorPosition {handle x y} {
                # See twapi procedure for details.
                #
                if {![k32::SetConsoleCursorPosition $handle [list X $x Y $y]]} {
                    throwError "Console cursor position fails."
                }
                return {}
            }

            proc getConsoleCursorPosition {handle} {
                # See twapi procedure for details.
                #
                if {![k32::GetConsoleScreenBufferInfo $handle info]} {
                    throwError "Could not get console screen buffer info"
                }

                return [list \
                    [dict get $info dwCursorPosition X] \
                    [dict get $info dwCursorPosition Y] \
                ]
            }

            proc getConsoleHeight {handle} {
                # See twapi procedure for details.
                #
                set info           [getInfoConsole $handle]
                set srWindowBottom [dict get $info srWindow Bottom]
                set srWindowTop    [dict get $info srWindow Top]

                return [expr {$srWindowBottom - $srWindowTop}]
            }

            proc getConsoleWidth {handle} {
                # See twapi procedure for details.
                #
                set info          [getInfoConsole $handle]
                set srWindowRight [dict get $info srWindow Right]
                set srWindowLeft  [dict get $info srWindow Left]

                return [expr {$srWindowRight - $srWindowLeft}]
            }

        } else {
            error "package 'twapi' or 'cffi >= 2.0'\
                should be present for Windows platform."
        }
    }
}

# SetConsoleMode
if {![zesty::win32::isNewTerminal]} zesty::win32::setConsoleMode