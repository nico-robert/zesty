#!/usr/bin/env tclsh

# Test file for zesty::box command.
# This file demonstrates various features and capabilities of the zesty::box system.

lappend auto_path [file dirname [file dirname [file normalize [info script]]]]

package require zesty

zesty::echo "1. BASIC BOXES"
zesty::echo "─────────────────"

# Simple box without title
zesty::echo "\n• Simple box without title:"
set bb [zesty::box -content {text "Basic box without title"}]
zesty::echo $bb

# Box with simple title
zesty::echo "\n• Box with simple title:"
set bb [zesty::box \
    -title {name "My Title"} \
    -content {text "Content with basic title"}
]
zesty::echo $bb

# Box with multiline content
zesty::echo "\n• Box with multiline content:"
set bb [zesty::box \
    -title {name "Multiline"} \
    -content {text "Line 1\nLine 2\nLine 3\nLine 4"}
]
zesty::echo $bb

zesty::echo "\n\n2. BORDER STYLES"
zesty::echo "────────────────────"

set test_content "Border style test"

# Default style (rounded)
zesty::echo "\n• Rounded style (default):"
set bb [zesty::box \
    -title {name "Rounded"} \
    -content [list text $test_content] \
    -box {type "rounded"}
]
zesty::echo $bb

# Thick style
zesty::echo "\n• Thick style:"
set bb [zesty::box \
    -title {name "Thick"} \
    -content [list text $test_content] \
    -box {type "thick"}
]
zesty::echo $bb

# Double style
zesty::echo "\n• Double style:"
set bb [zesty::box \
    -title {name "Double"} \
    -content [list text $test_content] \
    -box {type "double"}
]
zesty::echo $bb

# ASCII style
zesty::echo "\n• ASCII style:"
set bb [zesty::box \
    -title {name "ASCII"} \
    -content [list text $test_content] \
    -box {type "ascii"}
]
zesty::echo $bb

zesty::echo "\n\n3. TITLE ANCHORS"
zesty::echo "────────────────────"

# North anchors (top)
zesty::echo "\n• North anchors (top):"

zesty::echo "\n  - nw (north west):"
set bb [zesty::box \
    -title {name "North West" anchor "nw"} \
    -content {text "Title anchored at top left"}
]
zesty::echo $bb

zesty::echo "\n  - nc (north center):"
set bb [zesty::box \
    -title {name "North Center" anchor "nc"} \
    -content {text "Title anchored at top center"}
]
zesty::echo $bb

zesty::echo "\n  - ne (north east):"
set bb [zesty::box \
    -title {name "North East" anchor "ne"} \
    -content {text "Title anchored at top right"}
]
zesty::echo $bb

# South anchors (bottom)
zesty::echo "\n• South anchors (bottom):"

zesty::echo "\n  - sw (south west):"
set bb [zesty::box \
    -title {name "South West" anchor "sw"} \
    -content {text "Title anchored at bottom left"}
]
zesty::echo $bb

zesty::echo "\n  - sc (south center):"
set bb [zesty::box \
    -title {name "South Center" anchor "sc"} \
    -content {text "Title anchored at bottom center"}
]
zesty::echo $bb

zesty::echo "\n  - se (south east):"
set bb [zesty::box \
    -title {name "South East" anchor "se"} \
    -content {text "Title anchored at bottom right"}
]
zesty::echo $bb

# West anchors (left) - Vertical titles
zesty::echo "\n• West anchors (left) - Vertical titles:"

zesty::echo "\n  - wn (west north):"
set bb [zesty::box \
    -title {name "MENU" anchor "wn"} \
    -content {text "Option 1\nOption 2\nOption 3\nOption 4\nOption 5"} \
    -paddingX 2 \
    -paddingY 2
]
zesty::echo $bb

zesty::echo "\n  - wc (west center):"
set bb [zesty::box \
    -title {name "INFO" anchor "wc"} \
    -content {text "Centered data\nLine 2\nLine 3"} \
    -paddingX 2 \
    -paddingY 1
]
zesty::echo $bb

zesty::echo "\n  - ws (west south):"
set bb [zesty::box \
    -title {name "LOG" anchor "ws"} \
    -content {text "Messages\nErrors\nWarnings"} \
    -paddingX 2 \
    -paddingY 1
]
zesty::echo $bb

# East anchors (right) - Vertical titles
zesty::echo "\n• East anchors (right) - Vertical titles:"

zesty::echo "\n  - en (east north):"
set bb [zesty::box \
    -title {name "STAT" anchor "en"} \
    -content {text "Statistics\nCPU: 45%\nRAM: 60%\nDisk: 30%"} \
    -paddingX 2 \
    -paddingY 2
]
zesty::echo $bb

zesty::echo "\n  - ec (east center):"
set bb [zesty::box \
    -title {name "HELP" anchor "ec"} \
    -content {text "Contextual help\nF1: Help\nF2: Menu\nF3: Exit"} \
    -paddingX 2 \
    -paddingY 1
]
zesty::echo $bb

zesty::echo "\n  - es (east south):"
set bb [zesty::box \
    -title {name "TIME" anchor "es"} \
    -content {text "System clock\n14:30:45\n2024-01-15"} \
    -paddingX 2 \
    -paddingY 1
]
zesty::echo $bb


zesty::echo "\n\n4. CONTENT ALIGNMENTS"
zesty::echo "─────────────────────────"

set multi_content "Short line\nMuch longer line here\nMedium"

zesty::echo "\n• Left alignment:"
set bb [zesty::box \
    -title {name "Left"} \
    -content [list text $multi_content align "left"] \
    -paddingX 2
]
zesty::echo $bb

zesty::echo "\n• Center alignment:"
set bb [zesty::box \
    -title {name "Center"} \
    -content [list text $multi_content align "center"] \
    -paddingX 2
]
zesty::echo $bb

zesty::echo "\n• Right alignment:"
set bb [zesty::box \
    -title {name "Right"} \
    -content [list text $multi_content align "right"] \
    -paddingX 2
]
zesty::echo $bb

zesty::echo "\n\n5. PADDING MANAGEMENT"
zesty::echo "───────────────────────"

set test_text "Padding test"

zesty::echo "\n• Padding X = 0, Y = 0:"
set bb [zesty::box \
    -title {name "Pad 0,0"} \
    -content [list text $test_text] \
    -paddingX 0 \
    -paddingY 0
]
zesty::echo $bb

zesty::echo "\n• Padding X = 1, Y = 1:"
set bb [zesty::box \
    -title {name "Pad 1,1"} \
    -content [list text $test_text] \
    -paddingX 1 \
    -paddingY 1
]
zesty::echo $bb

zesty::echo "\n• Padding X = 3, Y = 2:"
set bb [zesty::box \
    -title {name "Pad 3,2"} \
    -content [list text $test_text] \
    -paddingX 3 \
    -paddingY 2
]
zesty::echo $bb

zesty::echo "\n\n6. CUSTOM SIZES"
zesty::echo "─────────────────────────"

zesty::echo "\n• Fixed size 30x8:"
set bb [zesty::box \
    -title {name "Fixed size"} \
    -content {text "Content in a box\nwith fixed size 30x8"} \
    -box {size {30 8}}
]
zesty::echo $bb

zesty::echo "\n• Fixed size 40x6 with long content:"
set bb [zesty::box \
    -title {name "Truncated content"} \
    -content {text "Line 1\nLine 2\nLine 3\nLine 4\nLine 5\nLine 6\nLine 7\nLine 8"} \
    -box {size {40 6}} \
    -paddingX 2
]
zesty::echo $bb

zesty::echo "\n• Size with title too long (horizontal truncation):"
set bb [zesty::box \
    -title {name "EXTREMELY_LONG_TITLE_THAT_WILL_BE_TRUNCATED"} \
    -content {text "Title truncation test"} \
    -box {size {25 5}}
]
zesty::echo $bb

zesty::echo "\n\n7. STYLED TITLES"
zesty::echo "────────────────"

zesty::echo "\n• Title with simple style:"
set bb [zesty::box \
    -title {
        name "Styled Title"
        style {fg "red" bg "yellow"}
    } \
    -content {text "Content with styled title"}
]
zesty::echo $bb

zesty::echo "\n• Styled title with truncation:"
set bb [zesty::box \
    -title {
        name "<s fg=red>RED</s> <s fg=blue>BLUE</s> <s fg=green>GREEN</s> <s fg=yellow>YELLOW</s>"
        anchor "nc"
    } \
    -content {text "Smart truncation test"} \
    -box {size {20 4}}
]
zesty::echo $bb

zesty::echo "\n\n8. VERTICAL TRUNCATIONS"
zesty::echo "─────────────────────────"

zesty::echo "\n• Vertical title too long (left):"
set bb [zesty::box \
    -title {name "VERY_LONG_VERTICAL_TITLE" anchor "wc"} \
    -content {text "Short content"} \
    -paddingX 1 \
    -paddingY 0
]
zesty::echo $bb

zesty::echo "\n• Vertical title too long (right):"
set bb [zesty::box \
    -title {name "LONG_VERTICAL_TITLE" anchor "ec"} \
    -content {text "Line 1\nLine 2"} \
    -paddingX 1 \
    -paddingY 0
]
zesty::echo $bb

zesty::echo "\n\n9. FULL SCREEN MODE"
zesty::echo "──────────────────"

set bb [zesty::box \
    -title {name "Full Screen"} \
    -content {text "Full screen content"} \
    -box {fullScreen "true"}
]
zesty::echo $bb

zesty::echo "\n\n10. COMBINED TESTS AND EDGE CASES"
zesty::echo "─────────────────────────────────"

zesty::echo "\n• Very small box:"
set bb [zesty::box \
    -title {name "XS"} \
    -content {text "Mini"} \
    -box {size {8 3}}
]
zesty::echo $bb

zesty::echo "\n• Empty content:"
set bb [zesty::box \
    -title {name "Empty"} \
    -content {text ""}
]
zesty::echo $bb

zesty::echo "\n• Empty title:"
set bb [zesty::box \
    -title {name ""} \
    -content {text "No title"}
]
zesty::echo $bb

zesty::echo "\n• Complex combination:"
set bb [zesty::box \
    -title {
        name "DASHBOARD"
        anchor "wc"
        style {fg "cyan"}
    } \
    -content {
        text "CPU: 45%\nRAM: 2.1/8.0 GB\nDisk: 120/500 GB\nNetwork: 15 Mb/s\nUptime: 2d 14h"
        align "left"
    } \
    -box {
        type "double"
        style {fg "yellow"}
    } \
    -paddingX 3 \
    -paddingY 1
]
zesty::echo $bb

proc truncMessage {lines_deleted} {

    set msg "-> Customized message in italic red !!"

    return [zesty::parseStyleDictToXML $msg {italic 1 fg red}]
    
}

zesty::echo "\n• Truncation with custom message:"
set bb [zesty::box \
    -title {name "2D Truncation"} \
    -content {text "<s fg=red>Red line 1</s>\n<s fg=blue>Blue line 2</s>\n<s fg=green>Very long green line 3 that overflows</s>\n<s fg=yellow>Yellow line 4</s>\n<s fg=purple>Purple line 5</s>"} \
    -box {size {30 4}} \
    -paddingX 1 \
    -paddingY 0 \
    -formatCmdBoxMsgtruncated {truncMessage}
]

zesty::echo $bb

zesty::echo "\n• Truncation with default message:"
set bb [zesty::box \
    -title {name "2D Truncation"} \
    -content {text "<s fg=red>Red line 1</s>\n<s fg=blue>Blue line 2</s>\n<s fg=green>Very long green line 3 that overflows</s>\n<s fg=yellow>Yellow line 4</s>\n<s fg=purple>Purple line 5</s>"} \
    -box {size {30 4}} \
    -paddingX 1 \
    -paddingY 0
]

zesty::echo $bb

zesty::echo "\n• CLI Table:"
set data {
    {"-p" "--print" "Displays the result in the <s fg=red>console</s>"}
    {"-v" "--verbose" "Enables verbose mode with details"}
    {"-h" "--help" "Shows help and available options"}
    {"-f" "--file" "Specifies the input file to process"}
    {"-o" "--output" "Defines the output file"}
    {"-c" "--config" "Uses a custom configuration file"}
    {"-d" "--debug" "Enables advanced debugging mode"}
    {"-q" "--quiet" "Suppresses output messages"}
    {"-r" "--recursive" "Recursive processing of <s fg=235>subdirectories</s>"}
    {"-n" "--dry-run" "Simulation without actual execution"}
    {"-a" "--all" "Shows all hidden elements"}
    {"-l" "--list" "Detailed list format"}
    {"-s" "--size" "Shows file sizes"}
    {"-t" "--time" "Sorts by modification date"}
    {"-R" "--reverse" "Reverses sort order"}
    {"-u" "--user" "Specifies the user"}
    {"-g" "--group" "Shows groups"}
    {"-m" "--mode" "Defines the execution <s fg=235>mode</s>"}
    {"-i <s fg=235>mode</s>" "--interactive" "Interactive mode with confirmations"}
    {"-b" "--backup" "Creates backup before modification"}
}

zesty::echo [zesty::box \
    -title {name "Options" anchor "nw" style {fg 159}} \
    -box {style {bold 1 fg gray}} \
    -content [list \
        text $data \
        table {
            enabled "true"
            columns {20 20 40}
            alignments {"left" "left" "left"}
            separator ""
            styles {
                {bold 1 fg 101}
                {bold 1 fg 159}
                {italic 1}
            }
        } \
    ]
]