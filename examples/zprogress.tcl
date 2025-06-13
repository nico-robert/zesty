#!/usr/bin/env tclsh

# Test file for progress bar class.
# This file demonstrates various features and capabilities of the progress bar system.

lappend auto_path [file dirname [file dirname [file normalize [info script]]]]

package require zesty

proc test_basic_progress {} {
    zesty::echo "\n=== Test 1: Basic Progress Bar ==="
    
    # Create a simple progress bar with default columns
    set bar [zesty::Bar new]
    
    # Add a task
    set task1 [$bar addTask -name "Downloading" -total 100]

    zesty::loop -start 0 -end 100 -delay 100 {
        $bar advance $task1 1
    }
    
    $bar destroy

    zesty::echo "Basic progress test completed"
}

proc test_multiple_tasks {} {
    zesty::echo "\n=== Test 2: Multiple Tasks ==="
    
    set bar [zesty::Bar new \
        -headers {
            show true
            set {
                0 {name "Task Name" align left style {fg blue}}
                1 {name "Count" align center style {fg green}}
                2 {name "Bar" align center style {fg yellow}}
                3 {name "%" align right style {fg cyan}}
            }
        }
    ]
    
    # Add multiple tasks
    set task1 [$bar addTask -name "Downloading" -total 100]
    set task2 [$bar addTask -name "Installing" -total 80]
    set task3 [$bar addTask -name "Configuring" -total 50]

    zesty::loop -start 0 -end 100 -delay 100 {
        $bar advance $task1 1
        $bar advance $task2 8
        $bar advance $task3 15
    }
    
    $bar destroy

    zesty::echo "Multiple tasks test completed"
}

proc test_custom_columns {} {
    zesty::echo "\n=== Test 3: Custom Column Layout ==="
    
    # Create bar with custom column layout
    set bar [zesty::Bar new \
        -setColumns {zName zCount {zSeparator •} zBar {zSeparator •} zPercent} \
        -headers {
            show true
            set {
                0 {name "Task" align left}
                1 {name "Count" align center}
                3 {name "Progress" align center}
                5 {name "%" align right}
            }
        } \
        -lineHSeparator {
            show true
        }
    ]
    
    set task1 [$bar addTask -name "Processing data..." -total 200]

    zesty::loop -start 0 -end 200 -delay 20 {
        $bar advance $task1 1
    }
    
    $bar destroy

    zesty::echo "Custom columns test completed"
}

proc test_spinner_columns {} {
    zesty::echo "\n=== Test 4: Spinner Animations ==="
    
    # Test different spinner styles
    set styles {dots line circle emoji arrows bars moon}
    foreach style $styles {
        zesty::echo "Testing spinner style: $style"
        incr mystyle
        
        set bar [zesty::Bar new \
            -setColumns {zName zSpinner zBar zPercent} \
            -headers {
                show true
            }
        ]
        
        # Configure spinner style
        $bar configureColumn 1 -spinnerStyle $style
        
        set task1 [$bar addTask -name "Loading: <s fg=${mystyle}>$style</s>" -total 100]

        zesty::loop -start 0 -end 100 -delay 30 {
            $bar advance $task1 1
        }

        $bar destroy
    }

    zesty::echo "Spinner animations test completed"
}

proc test_indeterminate_modes {} {
    zesty::echo "\n=== Test 5: Indeterminate Progress Modes ==="
    
    set anim_styles {bounce pulse wave}
    
    foreach style $anim_styles {
        zesty::echo "Testing indeterminate style: $style"
        
        set bar [zesty::Bar new \
            -indeterminateBarStyle $style \
            -headers {
                show true
            }
        ]
        
        set task1 [$bar addTask -name "Processing..." -mode indeterminate -animStyle $style]

        # Pause
        after 3500 {set forever 1}
        vwait forever

        $bar update $task1 -mode determinate

        # Switch to determinate and complete
        zesty::loop -start 0 -end 100 -delay 30 {
            $bar advance $task1 1
        }
        
        $bar destroy
    }
    
    zesty::echo "Indeterminate modes test completed"
}

proc test_custom_formatting {} {
    zesty::echo "\n=== Test 6: Custom Formatting ==="
    
    set bar [zesty::Bar new]

    $bar configureColumn zName -width 25
    
    # Custom format for percentage (show as fraction)
    $bar configureColumn zPercent -width 10 -format [list apply {{dict} {
        set result [dict get $dict result]

        return [format {%.1f/100} $result]
    }}]
    
    # Custom format for count
    $bar configureColumn zCount -width 10 -format [list apply {{dict} {
        set tasks [dict get $dict tasks]
        set task_id [dict get $dict idTask]
        set completed [dict get $tasks $task_id completed]
        set total [dict get $tasks $task_id total]
        return "($completed of $total)"
    }}]
    
    set task1 [$bar addTask -name "Custom format test..." -total 50]
    
    zesty::loop -start 0 -end 50 -delay 100 {
        $bar advance $task1 1
    }

    $bar destroy

    zesty::echo "Custom formatting test completed"
}

proc test_styling {} {
    zesty::echo "\n=== Test 7: Column Styling ==="
    
    set bar [zesty::Bar new \
        -colorBarChar "green" \
        -colorBgBarChar "gray"
    ]
    
    # Style different columns
    $bar configureColumn 0 -style {fg blue bold 1}
    $bar configureColumn 1 -style {fg yellow}
    $bar configureColumn 3 -style {fg red bold 1}
    
    set task1 [$bar addTask -name "Styled progress..." -total 75]
    
    zesty::loop -start 0 -end 75 -delay 100 {
        $bar advance $task1 1
    }

    $bar destroy

    zesty::echo "Styling test completed"
}

proc test_mixed_modes {} {
    zesty::echo "\n=== Test 8: Mixed Determinate/Indeterminate ==="
    
    set bar [zesty::Bar new]
    
    set task1 [$bar addTask -name "Scanning..." -mode indeterminate]
    set task2 [$bar addTask -name "Processing..." -total 100]

    zesty::loop -start 0 -end 100 -delay 100 {
        $bar advance $task2 1
    }

    $bar cleanup
    $bar destroy

    zesty::echo "Mixed modes test completed"
}

# Custom command for testing custom column types
proc custom_status_command {bar_obj task_id task_dict} {
    set completed [dict get $task_dict completed]
    set total     [dict get $task_dict total]
    
    if {$completed < 5} {
        return "Waiting..."
    } elseif {$completed < $total} {
        return "Running..."
    } else {
        return "Complete!"
    }
}

proc test_custom_command_column {} {
    zesty::echo "\n=== Test 9: Custom Command Column ==="
    
    set bar [zesty::Bar new \
        -setColumns {zName zCount zBar zPercent custom_status_command} \
        -headers {
            show true
            set {
                0 {name "Task" align left}
                1 {name "Count" align center}
                2 {name "Progress" align center}
                3 {name "%" align right}
                4 {name "Status" align center}
            }
        }
    ]
    
    set task1 [$bar addTask -name "Task with custom status..." -total 100]
    
    zesty::loop -start 0 -end 100 -delay 100 {
        $bar advance $task1 1
    }

    $bar destroy

    zesty::echo "Custom command column test completed"
}

# Performance test
proc test_performance {} {
    zesty::echo "\n=== Test 10: Performance Test ==="
    
    set bar [zesty::Bar new]
    set start_time [clock milliseconds]
    
    set task1 [$bar addTask -name "Performance test..." -total 1000]
    
    zesty::loop -start 0 -end 1000 -delay 1 {
        $bar advance $task1 1
    }
    
    set end_time [clock milliseconds]
    set duration [expr {$end_time - $start_time}]
    
    $bar destroy
    
    zesty::echo "Performance test: 1000 updates in ${duration}ms"
}

# Error handling test
proc test_error_handling {} {
    zesty::echo "\n=== Error Handling Test ==="
    
    set bar [zesty::Bar new]
    
    # Test various error conditions
    set tests {
        {catch {$bar update "nonexistent_task" -completed 50} msg} "Invalid task ID"
        {catch {$bar configureColumn 999 -width 10} msg} "Invalid column number"
        {catch {$bar addTask -total -5} msg} "Invalid total value"
        {catch {zesty::Bar new -minBarWidth 2} msg} "Invalid minBarWidth"
        {catch {$bar configureColumn 0 -align "invalid"} msg} "Invalid alignment"
    }
    
    foreach {test description} $tests {
        if {[eval $test]} {
            zesty::echo "✓ Caught error for: $description"
        } else {
            zesty::echo "✗ Failed to catch error for: $description"
        }
    }
    
    zesty::echo "Error handling test completed"
}

proc run_all_tests {} {
    zesty::echo "Starting zesty::Bar comprehensive tests...\n"
    
    test_basic_progress
    test_multiple_tasks
    test_custom_columns
    test_spinner_columns
    test_indeterminate_modes
    test_custom_formatting
    test_styling
    test_mixed_modes
    test_custom_command_column
    
    zesty::echo "\n=== All tests completed! ==="
}

# Interactive test menu
proc interactive_menu {} {
    zesty::echo "\n=== Interactive Test Menu ==="
    zesty::echo "1. Basic Progress" -filters {num {fg green}}
    zesty::echo "2. Multiple Tasks" -filters {num {fg green}}
    zesty::echo "3. Custom Columns" -filters {num {fg green}}
    zesty::echo "4. Spinner Animations" -filters {num {fg green}}
    zesty::echo "5. Indeterminate Modes" -filters {num {fg green}}
    zesty::echo "6. Custom Formatting" -filters {num {fg green}}
    zesty::echo "7. Styling" -filters {num {fg green}}
    zesty::echo "8. Mixed Modes" -filters {num {fg green}}
    zesty::echo "9. Custom Command Column" -filters {num {fg green}}
    zesty::echo "10. Performance Test" -filters {num {fg green}}
    zesty::echo "11. Error Handling" -filters {num {fg green}}
    zesty::echo "0. Exit" -filters {num {fg red}}
    
    zesty::echo -n "Enter choice (0-11): "
    flush stdout
    gets stdin choice
    
    switch -- $choice {
        1 { zesty::resetTerminal ; test_basic_progress }
        2 { zesty::resetTerminal ; test_multiple_tasks }
        3 { zesty::resetTerminal ; test_custom_columns }
        4 { zesty::resetTerminal ; test_spinner_columns }
        5 { zesty::resetTerminal ; test_indeterminate_modes }
        6 { zesty::resetTerminal ; test_custom_formatting }
        7 { zesty::resetTerminal ; test_styling }
        8 { zesty::resetTerminal ; test_mixed_modes }
        9 { zesty::resetTerminal ; test_custom_command_column }
        10 { zesty::resetTerminal ; test_performance }
        11 { zesty::resetTerminal ; test_error_handling }
        0 { zesty::echo "Exiting..."; return }
        default { zesty::echo "Invalid choice. Please try again." }
    }
    
    # Return to menu unless exiting
    if {$choice ne "0"} {
        interactive_menu
    }
}

# Main execution
if {[info exists argv0] && $argv0 eq [info script]} {
    zesty::echo "zesty::Bar Test Suite"
    zesty::echo "===================="
    
    if {[llength $argv] > 0} {
        switch -- [lindex $argv 0] {
            "-all" { run_all_tests }
            "-interactive" { interactive_menu }
            "-performance" { test_performance }
            "-errors" { test_error_handling }
            default {
                zesty::echo "Usage: $argv0 \[-all|-interactive|-performance|-errors\]"
                zesty::echo "  -all         : Run all tests automatically"
                zesty::echo "  -interactive : Show interactive menu"
                zesty::echo "  -performance : Run performance test only"
                zesty::echo "  -errors      : Run error handling test only"
                exit 1
            }
        }
    } else {
        interactive_menu
    }
}