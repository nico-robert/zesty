#!/usr/bin/env tclsh

# Test file for Table class.
# This file demonstrates various features and capabilities of the Table system.

lappend auto_path [file dirname [file dirname [file normalize [info script]]]]

package require zesty

proc test_basic_table {} {
    zesty::echo "\n=== BASIC TABLE DEMO ==="
    
    # Create a simple table with default settings
    set table [zesty::Table new]
    
    # Add columns with different configurations
    $table addColumn -name "ID" -justify "center" -width 5
    $table addColumn -name "Product Name" -justify "left" -maxWidth 20
    $table addColumn -name "Price" -justify "right" -width 10
    $table addColumn -name "Stock" -justify "center" -width 8
    
    # # Add some sample data rows
    $table addRow "001" "Laptop Computer" "\$1,299.99" "15"
    $table addRow "002" "Wireless Mouse" "\$29.99" "125"
    $table addRow "003" "Mechanical Keyboard" "\$89.99" "45"
    $table addRow "004" "USB-C Hub" "\$49.99" "78"
    
    # Display the basic table
    $table display
    
    # Clean up
    $table destroy
}

proc test_styled_table {} {
    zesty::echo "\n=== STYLED TABLE DEMO ==="
    
    # Create table with custom styling
    set table [zesty::Table new \
        -title   {name "Sales Report Q4 2024" justify "center" style {bold 1 fg "blue"}} \
        -caption {name "Generated on 2025-01-01" justify "right" style {italic 1 fg "gray"}} \
        -box     {type "double" style {fg "green"}} \
        -header  {show "true" style {bold 1 bg "yellow" fg "black"}} \
        -lines   {show "true" style {fg "cyan"}} \
        -padding 2 \
    ]
    
    # Add columns with individual styling
    $table addColumn -name "Region" -justify "left" \
        -style {bold 1 fg "blue"} -width 15
    $table addColumn -name "Revenue" -justify "right" \
        -style {fg "green"} -width 12
    $table addColumn -name "Growth" -justify "center" \
        -style {fg "red"} -width 10
    $table addColumn -name "Status" -justify "center" \
        -style {bold 1} -width 12
    
    # Add data with formatting
    $table addRow "North America" "\$2,450,000" "+12.5%" "Excellent"
    $table addRow "Europe" "\$1,890,000" "+8.3%" "Good"
    $table addRow "Asia Pacific" "\$3,120,000" "+15.7%" "Outstanding"
    $table addRow "Latin America" "\$890,000" "+5.1%" "Fair"
    
    $table display
    $table destroy
}

proc test_text_wrapping {} {
    zesty::echo "\n=== TEXT WRAPPING DEMO ==="
    
    # Create table with different wrapping behaviors
    set table [zesty::Table new \
        -title {name "Product Descriptions" justify "center"} \
        -box {type "rounded"} \
    ]
    
    # Different column width configurations
    $table addColumn -name "Code" -width 8 -noWrap "true"
    $table addColumn -name "Description" -maxWidth 30 -justify "left"
    $table addColumn -name "Features" -width 25
    $table addColumn -name "Notes" -minWidth 15 -maxWidth 20
    
    # Add rows with long text content
    $table addRow "PROD001" \
        "High-performance laptop computer with advanced features" \
        "Intel i7, 16GB RAM, 512GB SSD, 4K Display, USB-C ports" \
        "Limited time offer with extended warranty"
    
    $table addRow "PROD002" \
        "Wireless ergonomic mouse with precision tracking" \
        "2.4GHz wireless, 1600 DPI, ergonomic design, long battery life" \
        "Best seller in office supplies category"
    
    $table addRow "PROD003" \
        "Mechanical gaming keyboard with RGB lighting and programmable keys" \
        "Cherry MX switches, RGB per-key lighting, macro support, aluminum frame" \
        "Popular among gamers and developers alike"
    
    $table display
    $table destroy
}

proc test_vertical_alignment {} {
    zesty::echo "\n=== VERTICAL ALIGNMENT DEMO ==="
    
    set table [zesty::Table new \
        -title {name "Multi-line Content Alignment" justify "center"} \
        -box {type "thick"} \
    ]
    
    # Columns with different vertical alignments
    $table addColumn -name "Top Aligned"    -vertical "top"    -width 15
    $table addColumn -name "Middle Aligned" -vertical "middle" -width 15  
    $table addColumn -name "Bottom Aligned" -vertical "bottom" -width 15
    
    # Add rows with varying content heights
    $table addRow "Short text" \
        "This is a medium length text that spans multiple lines" \
        "This is a very long text content that will definitely span multiple lines and demonstrate bottom alignment behavior"
    
    $table addRow "Line 1\nLine 2\nLine 3" \
        "Single line" \
        "Two lines\nof content"
    
    $table display
    $table destroy
}

proc test_box_styles {} {
    zesty::echo "\n=== BOX STYLES DEMO ==="
    
    set styles {"single" "double" "rounded" "thick" "ascii"}
    
    foreach style $styles {
        zesty::echo "\nBox style: $style"
        set table [zesty::Table new -box [list type $style]]
        
        $table addColumn -name "Column 1" -width 12
        $table addColumn -name "Column 2" -width 12
        $table addColumn -name "Column 3" -width 12
        
        $table addRow "Data 1" "Data 2" "Data 3"
        $table addRow "Value A" "Value B" "Value C"
        
        $table display
        $table destroy
    }
}

proc test_scrolling_table {} {
    zesty::echo "\n=== SCROLLING TABLE DEMO ==="
    
    # Create a large table that will require scrolling
    set table [zesty::Table new \
        -title {name "Large Dataset - Employee Directory" justify "center"} \
        -maxVisibleLines 20 \
        -pageScroll "true" \
        -keyPgup "p" \
        -keyPgdn "n" \
        -keyQuit "q" \
    ]
    
    $table addColumn  -name "EmpID"       -width 8
    $table addColumn  -name "Name"        -width 20
    $table addColumn  -name "Department"  -width 15
    $table addColumn  -name "Position"    -width 18
    $table addColumn  -name "Salary"      -width 12  -justify "right"
    
    # Generate many rows of sample data
    set departments {"Engineering" "Sales" "Marketing" "HR" "Finance" "Operations"}
    set positions {"Manager" "Senior" "Junior" "Lead" "Director" "Analyst"}
    
    for {set i 1} {$i <= 50} {incr i} {
        set empId [format "EMP%03d" $i]
        set name "Employee $i"
        set dept [lindex $departments [expr {$i % [llength $departments]}]]
        set pos [lindex $positions [expr {$i % [llength $positions]}]]
        set salary [format {$%d,0} [expr {40000 + ($i * 1000)}]]
        
        $table addRow $empId $name $dept $pos $salary
    }
    
    zesty::echo "Note: This table will show pagination controls."
    zesty::echo "Use 'n' for next page, 'p' for previous, 'q' to quit."
    
    $table display
    $table destroy
}

proc test_responsive_width {} {
    zesty::echo "\n=== RESPONSIVE WIDTH DEMO ==="
    
    # This demo shows how tables adapt to terminal width
    set table [zesty::Table new \
        -title {name "Responsive Table - Adapts to Terminal Width" justify "center"} \
    ]
    
    # Add many columns to test width adaptation
    $table addColumn  -name "Col1"                       -minWidth 8
    $table addColumn  -name "Column 2"                   -minWidth 10
    $table addColumn  -name "Very Long Column Header 3"  -minWidth 12
    $table addColumn  -name "Col4"                       -minWidth 8
    $table addColumn  -name "Column 5 Data"              -minWidth 15
    $table addColumn  -name "Last Column"                -minWidth 10
    
    # Add sample data
    $table addRow "A1" "B1" "C1 with long content" "D1" "E1 data" "F1"
    $table addRow "A2" "B2 extended" "C2" "D2 value" "E2" "F2 content"
    $table addRow "A3 long" "B3" "C3" "D3" "E3 extended data" "F3"
    
    zesty::echo "This table will automatically adjust column widths based on your terminal size."
    
    $table display
    $table destroy
}

proc test_borderless_table {} {
    zesty::echo "\n=== BORDERLESS TABLE DEMO ==="
    
    set table [zesty::Table new \
        -showEdge "false" \
        -lines {show "false"} \
        -header {show "true" style {bold 1 underline 1}} \
        -padding 3 \
    ]
    
    $table addColumn -name "Name" -width 20
    $table addColumn -name "Age" -width 8 -justify "center"
    $table addColumn -name "City" -width 15
    
    $table addRow "Alice Johnson" "28" "New York"
    $table addRow "Bob Smith" "34" "Los Angeles"  
    $table addRow "Carol Davis" "29" "Chicago"
    
    $table display
    $table destroy
}

proc test_continuous_scroll {} {
    zesty::echo "\n=== CONTINUOUS SCROLL DEMO ==="
    
    set table [zesty::Table new \
        -title {name "Continuous Scroll Mode" justify "center"} \
        -continuousScroll "true" \
        -keyPgup "u" \
        -keyPgdn "d" \
        -keyQuit "q" \
    ]
    
    $table addColumn -name "Line#" -width 8
    $table addColumn -name "Content" -width 40
    $table addColumn -name "Status" -width 12
    
    # Generate content for scrolling
    for {set i 1} {$i <= 30} {incr i} {
        $table addRow [format "%03d" $i] \
            "This is line $i with some sample content to demonstrate scrolling" \
            [expr {$i % 2 ? "Active" : "Inactive"}]
    }
    
    zesty::echo "This will demonstrate line-by-line scrolling."
    zesty::echo "Use 'u' for up, 'd' for down, 'q' to quit."
    
    $table display
    $table destroy
}

proc test_table {} {

    zesty::echo "\n=== TABLE ==="

    set table [zesty::Table new \
        -title {name "Assessment of <s fg=blue>Products</s>" style {fg red}} \
        -caption {name "⭐ = Poor, ⭐⭐ = Average, ⭐⭐⭐ = Good, ⭐⭐⭐⭐ = Very Good, ⭐⭐⭐⭐⭐ = Excellent" style {fg green}} \
        -box {type "rounded"} \
        -header {style {fg blue}} \
        -lines {style {fg Magenta}} \
    ]

    # Add columns
    $table addColumn -name "Product" -justify "left" -minWidth 20 -vertical "middle" -style {fg yellow}
    $table addColumn -name "<s fg=yellow>Description</s>" -justify "left" -vertical "top" -noWrap "true"
    $table addColumn -name "Price" -justify "right" -vertical "middle" -noWrap "true"
    $table addColumn -name "Rating" -justify "center" -vertical "middle"
    $table addColumn -name "Status" -justify "center" -vertical "middle" -minWidth 10 -noWrap "true"

    # Add rows
    $table addRow "DELL 4K Monitor" \
        "Professional monitor with exceptional color accuracy for graphic designers." \
        649 \
        "⭐⭐⭐⭐⭐"

    $table addRow "Mechanical Keyboard" \
        "Gaming keyboard with RGB backlight and mechanical switches." \
        129 \
        "⭐⭐⭐⭐"

    $table addRow "Wireless Mouse" \
        "Ergonomic mouse with precision sensor and long battery life." \
        79 \
        "⭐⭐⭐"

    $table addRow "2.1 Speakers" \
        "Compact audio\nsystem with subwoofer\nfor desktop use." \
        99 \
        "⭐⭐"

    # Example with different emojis
    $table addRow "Bluetooth Headphones" \
        "Over-ear headphones with active <s fg=yellow>noise</s> cancellation and built-in microphone." \
        199 \
        "⭐⭐⭐⭐" \
        "✅ In Stock"

    $table addRow "HD Webcam" \
        "1080p webcam with autofocus and integrated microphone." \
        59 \
        "⭐⭐⭐" \
        "❌ Out of Stock"

    # Display the table
    $table display
}

proc test_nowrap_truncation {} {
    zesty::echo "\n=== TEXT TRUNCATION (noWrap) DEMO ==="
    
    set table [zesty::Table new \
        -title {name "Text Truncation Comparison - noWrap vs Normal" justify "center"} \
        -box {type "single"} \
    ]
    
    # Columns with different noWrap settings
    $table addColumn  -name "Normal Wrap"      -width 15  -noWrap "false"
    $table addColumn  -name "Truncated"        -width 15  -noWrap "true"
    $table addColumn  -name "Short Truncated"  -width 8   -noWrap "true"
    $table addColumn  -name "Very Short"       -width 5   -noWrap "true"
    
    # Add rows with progressively longer text to show truncation behavior
    $table addRow \
        "Short text" \
        "Short text" \
        "Short text" \
        "Short text"
    
    $table addRow \
        "This is a medium length text" \
        "This is a medium length text" \
        "This is a medium length text" \
        "This is a medium length text"
    
    $table addRow \
        "This is a very long text that will demonstrate the difference between wrapping and truncation" \
        "This is a very long text that will demonstrate the difference between wrapping and truncation" \
        "This is a very long text that will demonstrate the difference between wrapping and truncation" \
        "This is a very long text that will demonstrate the difference between wrapping and truncation"
    
    $table addRow \
        "Super extremely long content that goes on and on to show maximum truncation behavior" \
        "Super extremely long content that goes on and on to show maximum truncation behavior" \
        "Super extremely long content that goes on and on to show maximum truncation behavior" \
        "Super extremely long content that goes on and on to show maximum truncation behavior"
    
    zesty::echo "This demo shows the difference between:"
    zesty::echo "- Column 1: Normal text wrapping (noWrap = 0)"
    zesty::echo "- Columns 2-4: Text truncation with ellipsis (noWrap = 1)"
    zesty::echo "- Notice how truncated columns show '...' when text is too long"
    
    $table display
    $table destroy
}

proc test_mixed_nowrap {} {
    zesty::echo "\n=== MIXED noWrap SETTINGS DEMO ==="
    
    set table [zesty::Table new \
        -title {name "Product Catalog - Mixed Text Handling" justify "center"} \
        -box {type "rounded"} \
        -header {show "true" style {bold 1 bg "blue" fg "white"}} \
    ]
    
    # Mix of wrapping and truncation for different data types
    $table addColumn  -name "SKU"           -width 10  -noWrap "true"   -justify "center"
    $table addColumn  -name "Product Name"  -width 20  -noWrap "false"  -justify "left"
    $table addColumn  -name "Category"      -width 12  -noWrap "true"   -justify "center"
    $table addColumn  -name "Price"         -width 8   -noWrap "true"   -justify "right"
    $table addColumn  -name "Description"   -width 25  -noWrap "false"  -justify "left"
    $table addColumn  -name "Status"        -width 10  -noWrap "true"   -justify "center"
    
    # Add sample product data
    $table addRow \
        "LAP001" \
        "Professional Gaming Laptop with RGB Keyboard" \
        "Electronics" \
        "\$1,299.99" \
        "High-performance laptop designed for gaming and professional work with advanced cooling system" \
        "In Stock"
    
    $table addRow \
        "MOUSE002" \
        "Wireless Ergonomic Mouse" \
        "Accessories" \
        "\$29.99" \
        "Comfortable wireless mouse with precision tracking and long battery life" \
        "Low Stock"
    
    $table addRow \
        "KB003MECH" \
        "Mechanical Gaming Keyboard with Cherry MX Blue Switches" \
        "Gaming Gear" \
        "\$89.99" \
        "Professional mechanical keyboard with tactile switches, RGB lighting, and programmable macros" \
        "Out of Stock"
    
    $table addRow \
        "MON004UHD" \
        "4K Ultra HD Monitor" \
        "Displays" \
        "\$399.99" \
        "32-inch 4K UHD monitor with IPS panel, HDR support, and multiple connectivity options" \
        "Available"
    
    zesty::echo "This demo shows strategic use of noWrap:"
    zesty::echo "- SKU, Category, Price, Status: truncated (noWrap = 1) - fixed-width data"
    zesty::echo "- Product Name, Description: wrapped (noWrap = 0) - variable content"
    
    $table display
    $table destroy
}

proc run_all_tests {} {
    # Run all demonstration functions
    test_basic_table
    test_styled_table  
    test_text_wrapping
    test_vertical_alignment
    test_box_styles
    test_borderless_table
    test_table
    test_nowrap_truncation
    test_mixed_nowrap
}

# Interactive test menu
proc interactive_menu {} {
    zesty::echo "\n=== Interactive Test Menu ==="
    zesty::echo "1. Basic table creation" -filters {num {fg green}}
    zesty::echo "2. Styled Table" -filters {num {fg green}}
    zesty::echo "3. Text Wrapping" -filters {num {fg green}}
    zesty::echo "4. Vertical Alignment" -filters {num {fg green}}
    zesty::echo "5. Box Styles" -filters {num {fg green}}
    zesty::echo "6. Scrolling Table" -filters {num {fg green}}
    zesty::echo "7. Responsive Width" -filters {num {fg green}}
    zesty::echo "8. Borderless Table" -filters {num {fg green}}
    zesty::echo "9. Continuous Scroll" -filters {num {fg green}}
    zesty::echo "10. Table" -filters {num {fg green}}
    zesty::echo "11. Text truncation with ellipsis" -filters {num {fg green}}
    zesty::echo "12. Mixed wrap/truncation strategies" -filters {num {fg green}}
    zesty::echo "13. Run All Demos" -filters {num {fg green}}
    zesty::echo "0. Exit" -filters {num {fg red}}
    
    zesty::echo -n "Enter choice (0-13): "
    flush stdout
    gets stdin choice
    
    switch -- $choice {
        1 { zesty::resetTerminal ; test_basic_table }
        2 { zesty::resetTerminal ; test_styled_table }
        3 { zesty::resetTerminal ; test_text_wrapping }
        4 { zesty::resetTerminal ; test_vertical_alignment }
        5 { zesty::resetTerminal ; test_box_styles }
        6 { zesty::resetTerminal ; test_scrolling_table }
        7 { zesty::resetTerminal ; test_responsive_width }
        8 { zesty::resetTerminal ; test_borderless_table }
        9 { zesty::resetTerminal ; test_continuous_scroll }
        10 { zesty::resetTerminal ; test_table }
        11 { zesty::resetTerminal ; test_nowrap_truncation }
        12 { zesty::resetTerminal ; test_mixed_nowrap }
        13 { zesty::resetTerminal ; run_all_tests }
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
    zesty::echo "zesty::Table Test Suite"
    zesty::echo "===================="
    
    if {[llength $argv] > 0} {
        switch -- [lindex $argv 0] {
            "-all" { run_all_tests }
            "-interactive" { interactive_menu }
            default {
                zesty::echo "Usage: $argv0 \[-all|-interactive]"
                zesty::echo "  -all         : Run all tests automatically"
                zesty::echo "  -interactive : Show interactive menu"
                exit 1
            }
        }
    } else {
        interactive_menu
    }
}