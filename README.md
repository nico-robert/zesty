zesty
<div align="center">
Afficher l'image
Afficher l'image
Afficher l'image
A modern terminal UI library for Tcl
Create beautiful command-line interfaces with styled text, progress bars, tables, and boxes.
</div>
✨ Features

🎨 Rich Text Styling - 256 colors, text formatting, gradients
📊 Progress Bars - Multiple tasks, animations, custom columns
📋 Tables - Auto-sizing, text wrapping, scrolling, styling
📦 Boxes - Multiple border styles, title positioning, padding
🎯 Cross-Platform - Windows, Linux, macOS support
🚀 Performance - Optimized rendering and updates

📦 Installation
bash# Clone the repository
git clone https://github.com/yourusername/zesty.git

# Add to your Tcl script
lappend auto_path /path/to/zesty
package require zesty
🚀 Quick Start
Echo with Style
tcl# Basic styled text
zesty::echo "Hello World!" -style {fg red bold 1}

# Inline style tags
zesty::echo "This is <s fg=red>red</s> and <s fg=blue bold=1>bold blue</s>"

# Gradient effect
zesty::echo [zesty::gradient "Rainbow Text" "red" "yellow"]
Progress Bars
tcl# Simple progress bar
set bar [zesty::ProgressBar]
set task [$bar addTask -name "Downloading..." -total 100]

for {set i 0} {$i < 100} {incr i} {
    $bar advance $task
    after 50
}
Tables
tcl# Create a styled table
set table [zesty::Table new \
    -title {name "Sales Report" style {fg blue bold 1}} \
    -box {type "rounded"}
]

$table addColumn -name "Product" -width 20
$table addColumn -name "Price" -justify "right"
$table addColumn -name "Stock" -justify "center"

$table addRow "Laptop" "$1,299" "15"
$table addRow "Mouse" "$29" "125"

$table display
Boxes
tcl# Simple box with title
zesty::echo [zesty::box \
    -title {name "Info" anchor "nc"} \
    -content {text "Your content here"} \
    -padding 2
]
📖 Documentation
Echo Command
The zesty::echo command provides styled console output:
tclzesty::echo text ?options?

Options:
  -style {key value ...}  # Style specifications
  -n                      # No newline
  -noreset               # Don't reset formatting
  -filters {type style}   # Apply filters (num, email, url)
Style Options:

fg / bg - Foreground/background color (name, number, or hex)
bold, italic, underline, strikethrough - Text decorations
dim, reverse, blink - Additional effects

Progress Bars
Create multi-task progress displays with animations:
tclset bar [zesty::ProgressBar ?options?]

Options:
  -setColumns {columns...}        # Column layout
  -headers {show true set {...}}  # Header configuration
  -colorBarChar "color"           # Progress bar color
  -indeterminateBarStyle "style"  # Animation style (bounce, pulse, wave)
  -spinnerFrequency ms            # Spinner update rate
Column Types:

zName - Task description
zBar - Progress bar
zPercent - Percentage
zCount - Current/Total
zElapsed - Elapsed time
zRemaining - ETA
zSpinner - Animated spinner
zSeparator - Column separator

Tables
Create formatted tables with automatic sizing:
tclset table [zesty::Table new ?options?]

Options:
  -title {name "text" justify "position" style {...}}
  -box {type "style" style {...}}
  -padding n
  -headers {show bool style {...}}
  -lines {show bool style {...}}
  -maxVisibleLines n     # Enable scrolling
  -pageScroll bool       # Page-based scrolling
  -continuousScroll bool # Line-by-line scrolling
Box Styles: single, double, rounded, thick, ascii
Boxes
Create styled text boxes:
tclzesty::box ?options?

Options:
  -title {name "text" anchor "position" style {...}}
  -content {text "content" align "alignment" style {...}}
  -padding n          # Uniform padding
  -paddingX/Y n      # Directional padding
  -box {type "style" size {w h} fullScreen bool style {...}}
Title Anchors:

North: nw, nc, ne
South: sw, sc, se
East: en, ec, es
West: wn, wc, ws

🎨 Color Support
zesty supports multiple color formats:
tcl# Named colors
-style {fg "red"}

# 256-color palette (0-255)
-style {fg 196}

# Hex colors
-style {fg "#FF5733"}

# Find colors
zesty::findColorByName "blue"    # Search by name pattern
zesty::findColorByHex "#FF"      # Search by hex pattern
zesty::colorInfo "red"           # Show color details
📋 Examples
Dashboard Example
tcl# Create a dashboard layout
set stats [zesty::box \
    -title {name "System Stats" anchor "nc" style {fg cyan}} \
    -content {text "CPU: 45%\nRAM: 8.2GB\nDisk: 120GB"} \
    -box {type "double"}
]

set progress [zesty::ProgressBar -headers {show true}]
set task [$progress addTask -name "Processing..." -total 100]

zesty::echo $stats
# Update progress in loop...
Download Manager
tclproc download_file {filename size} {
    set pb [zesty::ProgressBar \
        -colorBarChar "green" \
        -setColumns {zName zBar zPercent zElapsed download_speed}
    ]
    
    set task [$pb addTask -name $filename -total $size]
    # Simulate download...
}
Interactive Menu
tclset table [zesty::Table new -box {type "rounded"}]
$table addColumn -name "Option" -width 20
$table addColumn -name "Description" -width 40

$table addRow "1. New" "Create new project"
$table addRow "2. Open" "Open existing project"
$table addRow "3. Exit" "Exit application"

$table display
🧪 Running Tests
The package includes comprehensive test suites:
bash# Test echo functionality
tclsh tests/zecho.tcl -interactive

# Test progress bars
tclsh tests/zprogress.tcl -all

# Test tables
tclsh tests/ztable.tcl -interactive

# Test boxes
tclsh tests/zbox.tcl
🛠️ Requirements

Tcl 8.6 or higher
Platform-specific requirements:

Windows: twapi or cffi >= 2.0
Unix/Linux: Terminal with ANSI escape sequence support



📄 License
This project is licensed under the MIT License - see the LICENSE file for details.
🤝 Contributing
Contributions are welcome! Please feel free to submit a Pull Request.
🙏 Acknowledgments

Inspired by modern CLI tools and libraries
Built with love for the Tcl community


<div align="center">
Made with ❤️ by Nicolas ROBERT
</div>