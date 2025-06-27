# Copyright (c) 2025 Nicolas ROBERT.
# Distributed under MIT license. Please see LICENSE for details.

namespace eval zesty {}

proc zesty::validValue {type key validvalue value} {
    # Check if value is valid.
    # 
    # type     - type
    # key      - key
    # validvalue - valid value
    # value    - value
    #
    # Returns nothing or an error message if invalid.
    variable boxstyles
    variable titleAnchor
    variable tablestyles

    if {$validvalue eq "" || $type eq "none"} {
        return {}
    }

    switch -exact -- $validvalue {

        formatStyle {
            zesty::validateKeyValuePairs $key $value
        }

        formatHSets {
            zesty::validateKeyValuePairs $key $value
            foreach {skey svalue} $value {
                zesty::validateKeyValuePairs $skey $svalue
            }
        }

        formatAlign {
            if {$value ni {"left" "right" "center"}} {
                error "zesty(error): value '$value' should be\
                    'left', 'right', or 'center' for\
                    this key '$key'."
            }
        }

        formatIBStyle {
            if {$value ni {"bounce" "pulse" "wave"}} {
                error "zesty(error): value '$value' should be\
                    'bounce', 'pulse', or 'wave' for\
                    this key '$key'."
            }
        }

        formatVertical {
            if {$value ni {"top" "bottom" "middle"}} {
                error "zesty(error): value '$value' should be\
                    'top', 'bottom', or 'middle' for\
                    this key '$key'."
            }
        }

        formatTitleAnchor {
            if {$value ni $titleAnchor} {
                set keyType [format {%s or %s.} \
                    [join [lrange $titleAnchor 0 end-1] ", "] \
                    [lindex $titleAnchor end] \
                ]
                error "zesty(error): '$value' must be one of: $keyType\
                    for this key '$key'."
            }
        }

        formatTypeTable {
            set keys [dict keys $tablestyles]
            if {$value ni $keys} {
                set keyType [format {%s or %s.} \
                    [join [lrange $keys 0 end-1] ", "] \
                    [lindex $keys end] \
                ]
                error "zesty(error): '$value' must be one of: $keyType\
                    for this key '$key'."
            }
        }

        formatTypeBox {
            set keys [dict keys $boxstyles]
            if {$value ni $keys} {
                set keyType [format {%s or %s.} \
                    [join [lrange $keys 0 end-1] ", "] \
                    [lindex $keys end] \
                ]
                error "zesty(error): '$value' must be one of: $keyType\
                    for this key '$key'."
            }
        }
        formatMVL -
        formatPad {
            zesty::isPositiveIntegerValue $key $value
        }

        formatIBSpeed {
            if {$value == 0} {
                error "zesty(error): '$key' should not be equal to '0'"
            }
        }

        formatColums {
            foreach col $value {
                if {([zesty::typeOf $col] ne "num") || ($col == 0)} {
                    error "zesty(error): Column widths must be integers or\
                        width equal to -1 for column width auto."
                }
            }
        }

        formatAlignements {
            foreach align $value {
                if {$align ni {"left" "right" "center"}} {
                    error "zesty(error): Align column table must be one of\
                        : left, right, center"
                }
            }
        }

        formatStyles {
            foreach style $value {
                zesty::validateKeyValuePairs "style" $style
            }
        }

        formatSizeBox {
            if {[llength $value] != 2} {
                error "zesty(error): '$key' must be a list of two\
                    integers {width height}"
            }

            lassign $value width height
            zesty::isPositiveIntegerValue $key $width
            zesty::isPositiveIntegerValue $key $height

        }

        formatSFreq -
        formatMCWidth {
            zesty::isPositiveIntegerValue $key $value 1
        }

        formatMBWidth {
            zesty::isPositiveIntegerValue $key $value 5
        }

        formatLChar {
            if {[zesty::strLength $value] != 1} {
                error "zesty(error): This 'key' should be one character."
            }
        }

        formatVKVP {
            zesty::validateKeyValuePairs $key $value
        }

        formatVBool {
            if {![string is boolean -strict $value]} {
                error "zesty(error): '$key' must be a boolean value."
            }
        }

    }
}