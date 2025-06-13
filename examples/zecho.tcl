#!/usr/bin/env tclsh

# Test file for zesty::echo command.
# This file demonstrates various features and capabilities of the zesty::echo system.

lappend auto_path [file dirname [file dirname [file normalize [info script]]]]

package require zesty

proc test_basic_echo {} {
    zesty::echo "\n=== Test 1: Basic Echo Functionality ==="
    
    # Basic text output
    zesty::echo "Simple text output"
    
    # Echo without newline
    zesty::echo -n "Text without newline: "
    zesty::echo "continuation on same line"
    
    # Echo with explicit newline control
    zesty::echo "Line 1" -n
    zesty::echo " - Line 1 continued"
    
    zesty::echo "Basic echo test completed"
}

proc test_color_output {} {
    zesty::echo "\n=== Test 2: Color Output ==="
    
    # Basic colors
    zesty::echo "Red text" -style {fg red}
    zesty::echo "Green text" -style {fg green}
    zesty::echo "Blue text" -style {fg blue}
    zesty::echo "Yellow text" -style {fg yellow}
    zesty::echo "Cyan text" -style {fg cyan}
    zesty::echo "Magenta text" -style {fg magenta}
    zesty::echo "White text" -style {fg white}
    zesty::echo "Black text" -style {fg black}
    
    # Background colors
    zesty::echo "Red background" -style {bg red}
    zesty::echo "Green background" -style {bg green}
    zesty::echo "Blue background" -style {bg blue}
    
    # Combined foreground and background
    zesty::echo "White on red" -style {fg white bg red}
    zesty::echo "Yellow on blue" -style {fg yellow bg blue}
    
    zesty::echo "Color output test completed"
}

proc test_text_styles {} {
    zesty::echo "\n=== Test 3: Text Styles ==="
    
    # Text formatting
    zesty::echo "Bold text" -style {bold 1}
    zesty::echo "Italic text" -style {italic 1}
    zesty::echo "Underlined text" -style {underline 1}
    zesty::echo "Strikethrough text" -style {strikethrough 1}
    zesty::echo "Dim text" -style {dim 1}
    
    # Combined styles
    zesty::echo "Bold and italic" -style {bold 1 italic 1}
    zesty::echo "Bold red text" -style {bold 1 fg red}
    zesty::echo "Underlined blue text" -style {underline 1 fg blue}
    
    # Reset to normal
    zesty::echo "Normal text after styles"
    
    zesty::echo "Text styles test completed"
}

proc test_hex_colors {} {
    zesty::echo "\n=== Test 4: Hex Color Support ==="
    
    # Hex color codes
    zesty::echo "Custom red (#FF0000)" -style {fg "#FF0000"}
    zesty::echo "Custom green (#00FF00)" -style {fg "#00FF00"}
    zesty::echo "Custom blue (#0000FF)" -style {fg "#0000FF"}
    zesty::echo "Custom purple (#800080)" -style {fg "#800080"}
    zesty::echo "Custom orange (#FFA500)" -style {fg "#FFA500"}
    
    # Hex background colors
    zesty::echo "Hex background (#333333)" -style {bg "#333333" fg "#FFFFFF"}
    zesty::echo "Another hex combo" -style {bg "#FFE4B5" fg "#8B4513"}
    
    # Mixed hex and named colors
    zesty::echo "Mixed colors" -style {fg "#FF6347" bg blue}
    
    zesty::echo "Hex color test completed"
}

proc test_complex_styling {} {
    zesty::echo "\n=== Test 5: Complex Style Combinations ==="
    
    # Multiple style attributes
    zesty::echo "Bold red underlined" -style {bold 1 fg red underline 1}
    zesty::echo "Italic blue on yellow" -style {italic 1 fg blue bg yellow}
    zesty::echo "All styles combined" -style {bold 1 italic 1 underline 1 fg white bg black}
    
    # Gradient-like effect with different colors
    zesty::echo -n "Rainbow: "
    zesty::echo -n "R" -style {fg red}
    zesty::echo -n "a" -style {fg "#FF4500"}
    zesty::echo -n "i" -style {fg yellow}
    zesty::echo -n "n" -style {fg green}
    zesty::echo -n "b" -style {fg blue}
    zesty::echo -n "o" -style {fg "#4B0082"}
    zesty::echo "w" -style {fg "#8B00FF"}
    
    zesty::echo "Complex styling test completed"
}

proc test_embedded_styles {} {
    zesty::echo "\n=== Test 6: Embedded Style Tags ==="
    
    # Text with embedded style tags
    set styled_text "This is <s fg=red>red text</s> and this is <s fg=blue bold=1>bold blue</s>"
    zesty::echo $styled_text
    
    # Nested styles
    set nested_text "Normal <s bold=1>bold</s><s fg=red> and red</s> back to bold normal"
    zesty::echo $nested_text
    
    # Complex embedded styling
    set complex_text "Mix of <s fg=green>green</s>, <s bg=yellow fg=black>highlighted</s>, and <s underline=1 fg=blue>underlined blue</s> text"
    zesty::echo $complex_text
    
    zesty::echo "Embedded styles test completed"
}

proc test_special_characters {} {
    zesty::echo "\n=== Test 7: Special Characters and Unicode ==="
    
    # Unicode characters
    zesty::echo "Unicode symbols: ★ ♦ ♠ ♣ ♥ ♪ ☀ ☂ ⚡ ❤" -style {fg yellow}
    zesty::echo "Arrows: ← ↑ → ↓ ↖ ↗ ↘ ↙ ⇄ ⇅" -style {fg cyan}
    zesty::echo "Box drawing: ┌─┐ │ │ └─┘ ╭─╮ │ │ ╰─╯" -style {fg green}
    
    # Progress indicators
    zesty::echo "Progress bars: ▁▂▃▄▅▆▇█ ░▒▓█ ⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏" -style {fg blue}
    
    # Emoji (if supported)
    zesty::echo "Emojis: 😀 😎 🚀 ⭐ 🎉 💻 🔥 ✅" -style {fg magenta}
    
    zesty::echo "Special characters test completed"
}

proc test_performance {} {
    zesty::echo "\n=== Test 8: Performance Test ==="
    
    set start_time [clock milliseconds]
    
    # Test rapid output
    for {set i 0} {$i < 100} {incr i} {
        zesty::echo -n "." -style {fg green}
        if {$i % 50 == 49} {
            zesty::echo ""  # New line every 50 dots
        }
    }
    
    set end_time [clock milliseconds]
    set duration [expr {$end_time - $start_time}]
    
    zesty::echo "\nPerformance test: 100 styled outputs in ${duration}ms" -style {fg yellow}
    
    zesty::echo "Performance test completed"
}

proc test_error_handling {} {
    zesty::echo "\n=== Test 9: Error Handling ==="
    
    # Test invalid color names
    if {[catch {zesty::echo "Invalid color" -style {fg invalidcolor}} msg]} {
        zesty::echo "✓ Caught invalid color error: $msg"
    } else {
        zesty::echo "✗ Failed to catch invalid color error"
    }
    
    # Test invalid style attributes
    if {[catch {zesty::echo "Invalid style" -style {invalidattr 1}} msg]} {
        zesty::echo "✓ Caught invalid style error: $msg"
    } else {
        zesty::echo "✗ Failed to catch invalid style error"
    }
    
    # Test malformed style dictionary
    if {[catch {zesty::echo "Malformed style" -style {fg}} msg]} {
        zesty::echo "✓ Caught malformed style error: $msg"
    } else {
        zesty::echo "✗ Failed to catch malformed style error"
    }
    
    zesty::echo "Error handling test completed"
}

proc test_interactive_demo {} {
    zesty::echo "\n=== Test 10: Interactive Style Demo ==="
    
    # Create a colorful banner
    zesty::echo "╔══════════════════════════════════════╗" -style {fg cyan}
    zesty::echo "║          ZESTY ECHO DEMO             ║" -style {fg cyan}
    zesty::echo "╚══════════════════════════════════════╝" -style {fg cyan}
    
    # Status indicators
    zesty::echo "✅ Success message" -style {fg green bold 1}
    zesty::echo "⚠️  Warning message" -style {fg yellow bold 1}
    zesty::echo "❌ Error message" -style {fg red bold 1}
    zesty::echo "ℹ️  Info message" -style {fg blue bold 1}
    
    # Progress simulation
    zesty::echo -n "Loading: " -style {fg white}
    for {set i 0} {$i < 10} {incr i} {
        zesty::echo -n "█" -style {fg green}
        after 100
    }
    zesty::echo " Complete!" -style {fg green bold 1}
    
    # Gradient effect
    zesty::echo -n "Gradient: "
    set colors {"#FF0000" "#FF3300" "#FF6600" "#FF9900" "#FFCC00" "#FFFF00" "#CCFF00" "#99FF00" "#66FF00" "#33FF00" "#00FF00"}
    foreach color $colors {
        zesty::echo -n "█" -style [list fg $color]
    }
    zesty::echo ""
    
    zesty::echo "Interactive demo completed"
}

proc test_logging_simulation {} {
    zesty::echo "\n=== Test 11: Log Message Simulation ==="
    
    # Simulate different log levels
    zesty::echo {[INFO]  Application started successfully} -style {fg blue}
    zesty::echo {[DEBUG] Loading configuration from config.ini} -style {fg gray}
    zesty::echo {[WARN]  Deprecated function used in module X} -style {fg yellow}
    zesty::echo {[ERROR] Failed to connect to database} -style {fg red bold 1}
    zesty::echo {[FATAL] Critical system failure} -style {fg white bg red bold 1}
    
    # Timestamped logs
    set timestamp [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"]
    zesty::echo "$timestamp \[SUCCESS] Operation completed" -style {fg green}
    
    zesty::echo "Logging simulation completed"
}

proc test_gradient {} {
    zesty::echo "\n=== Test 11: Gradient ==="
    
    # Simulate different log levels
    zesty::echo [zesty::gradient "Hello zesty World !" "green" "yellow"]
    
    
    zesty::echo "Gradient completed"
}

proc run_all_tests {} {
    zesty::echo "Starting zesty::echo comprehensive tests...\n"
    
    test_basic_echo
    test_color_output
    test_text_styles
    test_hex_colors
    test_complex_styling
    test_embedded_styles
    test_special_characters
    test_performance
    test_error_handling
    test_interactive_demo
    test_logging_simulation
    
    zesty::echo "\n=== All tests completed! ==="
}

# Color palette demonstration
proc show_color_palette {} {
    zesty::echo "\n=== Color Palette Demonstration ==="
    
    # Standard colors
    zesty::echo "Standard colors:"
    set std_colors {black red green yellow blue magenta cyan white}
    foreach color $std_colors {
        zesty::echo -n "  $color  " -style [list bg $color fg white]
    }
    zesty::echo ""
    
    # Bright colors (if supported)
    zesty::echo "\nBright colors:"
    set bright_colors {gray brightred brightgreen brightyellow brightblue brightmagenta brightcyan brightwhite}
    foreach color $bright_colors {
        if {[catch {zesty::echo -n "  $color  " -style [list bg $color fg black]} err]} {
            # Fallback if bright colors not supported
            zesty::echo -n "  $color  " -style [list fg $color]
        }
    }
    zesty::echo ""
    
    # Hex color gradient
    zesty::echo "\nHex color gradient:"
    set hex_colors {"#000000" "#330000" "#660000" "#990000" "#CC0000" "#FF0000" "#FF3333" "#FF6666" "#FF9999" "#FFCCCC" "#FFFFFF"}
    foreach color $hex_colors {
        zesty::echo -n "██" -style [list fg $color]
    }
    zesty::echo ""
    
    zesty::echo "Color palette demonstration completed"
}

# Interactive test menu
proc interactive_menu {} {
    zesty::echo "\n=== Interactive Test Menu ==="
    zesty::echo "1.  Basic Echo" -filters {num {fg cyan}}
    zesty::echo "2.  Color Output" -filters {num {fg cyan}}
    zesty::echo "3.  Text Styles" -filters {num {fg cyan}}
    zesty::echo "4.  Hex Colors" -filters {num {fg cyan}}
    zesty::echo "5.  Complex Styling" -filters {num {fg cyan}}
    zesty::echo "6.  Embedded Styles" -filters {num {fg cyan}}
    zesty::echo "7.  Special Characters" -filters {num {fg cyan}}
    zesty::echo "8.  Performance Test" -filters {num {fg cyan}}
    zesty::echo "9. Error Handling" -filters {num {fg cyan}}
    zesty::echo "10. Interactive Demo" -filters {num {fg cyan}}
    zesty::echo "11. Logging Simulation" -filters {num {fg cyan}}
    zesty::echo "12. Color Palette" -filters {num {fg cyan}}
    zesty::echo "13. Gradient" -filters {num {fg cyan}}
    zesty::echo "0.  Exit" -filters {num {fg cyan}}
    
    zesty::echo -n "Enter choice (0-13): "
    flush stdout
    gets stdin choice
    
    switch -- $choice {
        1  { test_basic_echo }
        2  { test_color_output }
        3  { test_text_styles }
        4  { test_hex_colors }
        5  { test_complex_styling }
        6  { test_embedded_styles }
        7  { test_special_characters }
        8  { test_performance }
        9 { test_error_handling }
        10 { test_interactive_demo }
        11 { test_logging_simulation }
        12 { show_color_palette }
        13 { test_gradient }
        0  { zesty::echo "Exiting..."; return }
        default { zesty::echo "Invalid choice. Please try again." }
    }
    
    # Return to menu unless exiting
    if {$choice ne "0"} {
        interactive_menu
    }
}
# Main execution
if {[info exists argv0] && $argv0 eq [info script]} {
    zesty::echo "zesty::echo Test Suite"
    zesty::echo "====================="
    
    if {[llength $argv] > 0} {
        switch -- [lindex $argv 0] {
            "-all" { run_all_tests }
            "-interactive" { interactive_menu }
            "-palette" { show_color_palette }
            default {
                zesty::echo "Usage: $argv0 \[-all|-interactive|-palette\]"
                zesty::echo "  -all         : Run all tests automatically"
                zesty::echo "  -interactive : Show interactive menu"
                zesty::echo "  -palette     : Show color palette"
                zesty::echo 0
            }
        }
    } else {
        interactive_menu
    }
}