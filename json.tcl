# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {}

proc zesty::jsonDecode {args} {
    # Decodes and stylizes JSON data with customizable formatting
    # and styling options.
    #
    # args - variable arguments supporting:
    #  -json            - JSON data to decode
    #  -dumpJSONOptions - formatting huddle options
    #  -style           - styling specifications
    #  -showLinesNumber - whether to show line numbers
    #
    # Returns formatted and styled JSON string with optional line
    # numbers and custom colors for different JSON element types.
    package require huddle::json

    # Default options
    set options {
        json            {}
        dumpJSONOptions {
            offset "  " newline "\n" begin ""
        }
        style {
            key     {fg 10}
            str     {fg 10}
            num     {fg 11}
            null    {fg 4}
            boolean {fg 5 italic 1}
            lineNum {fg 254 reverse 1}
        }
        showLinesNumber true
    }

    # Process constructor arguments with validation
    zesty::validateKeyValuePairs "args" $args

    foreach {key value} $args {
        switch -exact -- $key {
            -json            {dict set options json $value}
            -dumpJSONOptions {
                zesty::validateKeyValuePairs "$key" $value

                foreach {dumpkey dumpvalue} $value {
                    switch -exact -- $dumpkey {
                        offset  -
                        newline -
                        begin   {dict set options dumpJSONOptions $dumpkey $dumpvalue}
                        default {zesty::throwError "'$dumpkey' not supported."}  
                    }
                }
            }
            -style {
                zesty::validateKeyValuePairs "$key" $value
                foreach {skey svalue} $value {
                    zesty::validateKeyValuePairs "$skey" $svalue
                    switch -exact -- $skey {
                        key     -
                        str     -
                        num     -
                        null    -
                        boolean {dict set options style $skey $svalue}
                        default {zesty::throwError "'$skey' not supported."}  
                    }
                }
            }
            -showLinesNumber {dict set options showLinesNumber $value}
            default {zesty::throwError "'$key' not supported."}  
        }
    }

    if {[dict get $options json] eq ""} {
        zesty::throwError "No json provided"
    }

    set json [dict get $options json]
    set json2h [huddle::json2huddle $json]

    set offset    [dict get $options dumpJSONOptions offset]
    set newline   [dict get $options dumpJSONOptions newline]
    set begin     [dict get $options dumpJSONOptions begin]
    set jsonStyle [dict get $options style]

    set result [zesty::jsondump $json2h $jsonStyle $offset $newline $begin]

    if {[dict get $options showLinesNumber]} {
        set totalLines [llength [split $json "\n"]]
        set formattedLines {}
        set len [string length $totalLines]
        set color [dict get $jsonStyle lineNum]
        set separator ""

        foreach line [split $result $newline] {
            incr lineNum
            set lineNumStr [zesty::parseStyleDictToXML \
                [format "%*d " $len $lineNum] $color \
            ]$separator
            lappend formattedLines "${lineNumStr}${line}"
        }
        
        return [join $formattedLines $newline]

    } else {
        return $result
    }
}

proc zesty::jsondump {huddle_object style {offset "  "} {newline "\n"} {begin ""}} {
    # Recursively dumps huddle object to styled JSON format.
    # Based on 'jsondump' procedures in huddle.tcl file (BSD-style license)
    # Copyright (c) 2008-2011 KATO Kanryu <kanryu6@users.sourceforge.net>
    # Copyright (c) 2015 Miguel Martínez López <aplicacionamedida@gmail.com>
    # according to my needs for styling extensions.
    #
    # huddle_object - huddle data structure to convert
    # style         - style dictionary for different JSON element types
    # offset        - indentation string
    # newline       - line separator
    # begin         - prefix string for indentation
    #
    # Returns: styled JSON string representation of the huddle object.

    set nextoff "$begin$offset"
    set nlof "$newline$nextoff"
    set sp " "
    if {[string equal $offset ""]} {set sp ""}

    set type [huddle type $huddle_object]

    switch -- $type {
        boolean {
            set boolstyle [dict get $style boolean]
            set boolvalue [huddle get_stripped $huddle_object]
            return [zesty::parseStyleDictToXML $boolvalue $boolstyle]
        }
        number {
            set numstyle [dict get $style num]
            set numvalue [huddle get_stripped $huddle_object]
            return [zesty::parseStyleDictToXML $numvalue $numstyle]
        }
        null {
            set nullstyle [dict get $style null]
            return [zesty::parseStyleDictToXML "null" $nullstyle]
        }
        string {
            set data [huddle get_stripped $huddle_object]
            # JSON permits only oneline string
            set data [string map {
                    \n \\n
                    \t \\t
                    \r \\r
                    \b \\b
                    \f \\f
                    \\ \\\\
                    \" \\\"
                    / \\/
                } $data
            ]
            set strstyle [dict get $style str]
            return [zesty::parseStyleDictToXML "'$data'" $strstyle]
        }
        list {
            set inner {}
            set len [huddle llength $huddle_object]
            for {set i 0} {$i < $len} {incr i} {
                set subobject [huddle get $huddle_object $i]
                lappend inner [zesty::jsondump $subobject $style $offset $newline $nextoff]
            }
            if {[llength $inner] == 1} {
                return "\[[lindex $inner 0]\]"
            }
            return "\[$nlof[join $inner ,$nlof]$newline$begin\]"
        }
        dict {
            set inner {}
            set keyStyle [dict get $style key]
            foreach {key} [huddle keys $huddle_object] {
                set skey [zesty::parseStyleDictToXML "'$key'" $keyStyle]
                lappend inner [subst {$skey:$sp[zesty::jsondump \
                    [huddle get $huddle_object $key] $style $offset $newline $nextoff]}]
            }
            if {[llength $inner] == 1} {
                return $inner
            }
            return "\{$nlof[join $inner ,$nlof]$newline$begin\}"
        }
        default {
            zesty::throwError "Callback not supported with zesty::jsondump: '$type'"
        }
    }
}