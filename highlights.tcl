# Copyright (c) 2026 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {

    variable listTclOOcmds {
        oo::class oo::object oo::define oo::objdefine oo::copy
        constructor destructor method self superclass mixin filter
        forward export unexport variable deletemethod renamemethod
        my next
    }
}

proc zesty::codeHighlights {args} {
    # Main function for code highlighting
    #
    # args - variable arguments supporting:
    #   -code {code}           - code to highlight
    #   -style {key value ...} - style specifications
    #   -linesNumber           - show line numbers
    #   -scmFile {file}        - scm file to use for syntax highlighting
    #   -whiteSpace            - show whitespace characters
    #
    # Returns highlighted code string
    variable listTclOOcmds

    package require tst 0.19 ;# Tree-sitter tcl extension

    # Default options
    zesty::def options "-code" -validvalue {} -type any|none -default {}
    zesty::def options "-style" -validvalue formatVKVP -type struct -with {
        keyword     -validvalue formatStyle  -type any|none -default {fg 6 bold 1}
        expression  -validvalue formatStyle  -type any|none -default {fg 1}
        string      -validvalue formatStyle  -type any|none -default {fg green}
        number      -validvalue formatStyle  -type any|none -default {fg magenta}
        tcloo       -validvalue formatStyle  -type any|none -default {fg 135 bold 1}
        function    -validvalue formatStyle  -type any|none -default {fg yellow bold 1}
        comment     -validvalue formatStyle  -type any|none -default {fg 8 italic 1}
        pBrace      -validvalue formatStyle  -type any|none -default {fg 3 bold 1}
        pBracket    -validvalue formatStyle  -type any|none -default {fg 4 bold 1}
        delimiter   -validvalue formatStyle  -type any|none -default {fg 4 bold 1}
        parent      -validvalue formatStyle  -type any|none -default {fg 8}
        conditional -validvalue formatStyle  -type any|none -default {fg 66 bold 1}
        namespace   -validvalue formatStyle  -type any|none -default {fg 32 bold 1}
        custom      -validvalue formatStyle  -type any|none -default {}
    }
    zesty::def options "-linesNumber" -validvalue formatVKVP -type struct -with {
        show    -validvalue formatVBool -type any      -default "true"
        style   -validvalue formatStyle -type any|none -default {fg 8}
    }
    zesty::def options "-whiteSpace" -validvalue formatVKVP -type struct -with {
        show    -validvalue formatVBool -type any      -default "false"
        style   -validvalue formatStyle -type any|none -default {fg 240}
    }
    zesty::def options "-verticalGuides" -validvalue formatVKVP -type struct -with {
        show  -validvalue formatVBool -type any      -default "false"
        style -validvalue formatStyle -type any|none -default {fg 240}
    }

    zesty::def options "-scmFile" -validvalue {}          -type any|none -default {}
    zesty::def options "-isUTF8"  -validvalue formatVBool -type any      -default "false"

    zesty::def options "-words"   -validvalue {}          -type any|none -default {}
    zesty::def options "-maxlen"  -validvalue formatPad   -type num|none -default {}

    # Merge options and args
    set options [zesty::merge $options $args]

    set code [dict get $options code]
    if {$code eq {}} {error "zesty(error): code data is empty."}

    set handle "null"
    if {[zesty::isWindows]} {
        set handle [zesty::win32::getStdOutHandle]
    }

    set term_width [zesty::getTermWidth $handle]
    set maxlen [dict get $options maxlen]
    if {($maxlen ne "") && ($term_width > $maxlen)} {
        set term_width $maxlen
    }

    # Limit code to terminal width.
    set limit [expr {$term_width - 4}]
    set result {}
    foreach line [split $code "\n"] {
        if {[string length $line] > $limit} {
            set line "[string range $line 0 $limit]..."
        }
        lappend result $line
    }

    set code [join $result "\n"]

    set result {}
    set last_pos 0
    set reset [zesty::resetANSIStyle]

    foreach {key val} [dict get $options style] {
        set style_${key} [zesty::parseStyleDictToANSI $val]
    }

    set words  [dict get $options words]

    set scm      [dict get $options scmFile]
    set is_utf8  [dict get $options isUTF8]
    set query    [tst::getQueryTokens $code $is_utf8 $scm]
    set codeUTF8 [dict get $query codeUTF8]
    set tokens   [dict get $query tokens]

    foreach token [lsort -integer -index 3 $tokens] {
        set textUTF8  [dict get $token text]
        set type      [dict get $token type]
        set startByte [dict get $token start]
        set endByte   [dict get $token end]

        # Ignore tokens before the current position
        if {$startByte < $last_pos} {continue}

        # Convert UTF-8 text to native encoding
        set text [encoding convertfrom "utf-8" $textUTF8]

        # Adds text before the current token
        set range [string range $codeUTF8 $last_pos $startByte-1]
        append result [encoding convertfrom utf-8 $range]

        switch -exact -- $type {
            "keyword"     {
                set style $style_keyword
                if {$text in $listTclOOcmds} {
                    set style $style_tcloo
                }
                if {$words ne {}} {
                    if {$text in $words} {
                        set style $style_custom
                    }
                }
            }
            "conditional" {set style $style_conditional}
            "expression"  {set style $style_expression}
            "string"      {set style $style_string}
            "number"      {set style $style_number}
            "brace" -
            "function"    {set style $style_function}
            "comment"     {set style $style_comment}
            "namespace"   {set style $style_namespace}
            "punctuation" {
                switch -exact -- $text {
                    "{" - "}" {set style $style_pBrace}
                    "[" - "]" {set style $style_pBracket}
                    "(" - ")" {set style $style_parent}
                    ";"       {set style $style_delimiter}
                    default   {set style {}}
                }
            }
            default {
                set style {}
                if {$words ne {}} {
                    if {$text in $words} {
                        set style $style_custom
                    }
                }
            }
        }

        append result "${style}${text}${reset}"
        set last_pos $endByte
    }

    set range [string range $codeUTF8 $last_pos end]
    append result [encoding convertfrom utf-8 $range]

    # Apply whitespace visualization if requested.
    if {[dict get $options whiteSpace show]} {
        set value [dict get $options whiteSpace style]
        set style [zesty::parseStyleDictToANSI $value]
        set result [zesty::visualizeWhitespace $result $style $reset]
    }

    # Apply vertical guide visualization if requested.
    if {[dict get $options verticalGuides show]} {
        set value [dict get $options verticalGuides style]
        set style [zesty::parseStyleDictToANSI $value]
        set result [zesty::visualizeVerticalGuides $result $style $reset]
    }

    # Apply line number visualization if requested.
    if {[dict get $options linesNumber show]} {
        set value [dict get $options linesNumber style]
        set style [zesty::parseStyleDictToANSI $value]
        set result [zesty::visualizeLinesNumber $result $style $reset]
    }

    return $result
}

proc zesty::visualizeLinesNumber {text style reset} {
    # Visualize line numbers
    #
    # text  - text to process
    # style - ANSI style for line number symbols
    # reset - ANSI reset code
    #
    # Returns text with line numbers
    set lines [split $text "\n"]
    set totalLines [llength $lines]
    set len [string length $totalLines]

    set result {}
    set separator " "

    foreach line $lines {
        set format [format "%*d " $len [incr lineNum]]
        set lineNumStr ${style}${format}${reset}${separator}
        set line ${lineNumStr}${line}

        lappend result $line
    }

    return [join $result "\n"]
}

proc zesty::visualizeWhitespace {text style reset} {
    # Visualize whitespace characters
    #
    # text  - text to process
    # style - ANSI style for whitespace symbols
    # reset - ANSI reset code
    #
    # Returns text with visible whitespace symbols
    set map [list " " "${style}·${reset}" "\t" "${style}→${reset}"]
    set result {}

    foreach line [split $text "\n"] {
        # Spaces at the beginning
        if {[regexp {^(\s+)} $line match debut]} {
            set debut_vis [string map $map $debut]
            regsub {^\s+} $line $debut_vis line
        }

        # Spaces at the end
        if {[regexp {(\s+)$} $line match fin]} {
            set fin_vis [string map $map $fin]
            regsub {\s+$} $line $fin_vis line
        }

        lappend result $line
    }

    return [join $result "\n"]
}

proc zesty::visualizeVerticalGuides {text style reset} {
    # Visualize vertical indent guides for code blocks.
    #
    # text  - text to process
    # style - ANSI style for guide lines
    # reset - ANSI reset code
    #
    # Returns text with vertical indent guides
    set lines [split $text "\n"]
    set guide_char "│"
    set indent_size 4

    # Determine indentation size
    foreach line $lines {
        if {[string trim $line] eq "" || [string index [string trimleft $line] 0] eq "#"} {
            continue
        }
        if {[regexp {^(\s+)} $line -> sp]} {
            set len [string length [string map {"\t" "    "} $sp]]
            if {$len >= 2 && $len <= 8} {set indent_size $len; break}
        }
    }

    # Compute style strings
    set s_sp [string repeat " " $indent_size]
    set s_gd "${style}${guide_char}${reset}[string repeat " " [expr {$indent_size - 1}]]"

    array set blocks {}
    set last_lvl 0
    set result {}

    foreach line $lines {
        # Compute indentation level
        set i_lvl 0
        if {[regexp {^(\s+)} $line -> sp]} {
            set i_lvl [expr {[string length [string map {"\t" "    "} $sp]] / $indent_size}]
        }

        set trimmed [string trimleft $line]
        set is_empty [expr {$trimmed eq ""}]
        set is_comment [expr {!$is_empty && [string index $trimmed 0] eq "#"}]
        set is_code [expr {!$is_empty && !$is_comment}]

        if {$is_code} {
            # If on a new indentation level, reset blocks.
            if {$i_lvl < $last_lvl} {
                foreach lvl [array names blocks] { if {$lvl >= $i_lvl} {unset blocks($lvl)} }
            }
            set last_lvl $i_lvl

            set clean_line [regsub -all {#.*$} $line {}]
            if {[string length [string trim $clean_line]] > 0} {
                foreach lvl [array names blocks] {
                    append blocks($lvl) $clean_line "\n"
                    if {[string first "\}" $clean_line] >= 0 && [info complete $blocks($lvl)]} {
                        unset blocks($lvl)
                    }
                }
            }

            # new block?
            if {![info exists blocks($i_lvl)] && [string first "\{" $clean_line] >= 0} {
                if {![info complete "$clean_line\n"]} { set blocks($i_lvl) "$clean_line\n" }
            }
        }

        # Build display level
        set disp_lvl $i_lvl
        if {$is_empty || $is_comment} {
            set disp_lvl [expr {$last_lvl > 0 ? $last_lvl : 0}]
            if {$is_comment && $i_lvl > $disp_lvl} { set disp_lvl $i_lvl }
        }

        set prefix ""
        for {set i 0} {$i < $disp_lvl} {incr i} {
            if {$is_empty || [info exists blocks($i)] || $i < $i_lvl} {
                append prefix $s_gd
            } else {
                append prefix $s_sp
            }
        }
        lappend result "${prefix}${trimmed}"
    }

    return [join $result "\n"]
}