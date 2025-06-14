# 🍋 zesty
Create beautiful command-line interfaces with styled text, progress bars, tables, boxes, and JSON formatting.

#### ✨ Features :

- 🎨 Rich Text Styling - 256 colors, text formatting, gradients.   
- 📊 Progress Bars - Multiple tasks, animations, custom columns.  
- 📋 Tables - Auto-sizing, text wrapping, scrolling, styling.  
- 📦 Boxes - Multiple border styles, title positioning, padding.  
- 🔧 JSON Decoder - Pretty-print JSON with syntax highlighting
- 🎯 Cross-Platform - Windows, Linux, macOS support.  

## 🛠️ Requirements :
- [Tcl](https://www.tcl.tk/) 8.6 or higher
- Platform-specific requirements:
  - Windows: 
    - [twapi](https://github.com/apnadkarni/twapi) or [tcl-cffi](https://github.com/apnadkarni/tcl-cffi) >= 2.0
  - Unix/Linux: 
    - Terminal with ANSI escape sequence support
- huddle::json package from [Tcllib](https://core.tcl-lang.org/tcllib/doc/trunk/embedded/index.md) (optional for JSON formatting)

> [!NOTE]  
> I have mainly tested this package on Windows (new `Terminal` and legacy `cmd.exe`) and macOS, it should work on Linux (I hope so !)
## 🚀 Quick Start :

Echo
```tcl
# Basic styled text
zesty::echo "Hello World!" -style {fg red bold 1}

# Inline style tags
zesty::echo "This is <s fg=red>red color</s> and <s fg=blue bold=1>bold blue</s>"

# Gradient effect
zesty::echo [zesty::gradient "Rainbow Text" "red" "yellow"]

# import echo command :
namespace import zesty::echo

# Apply a filter to the numerical values.
echo "1. Basic Echo" -filters {num {fg cyan}}

```
📊 Progress Bars
```tcl
# Simple progress bar
set bar [zesty::Bar new]
set task [$bar addTask -name "Downloading..." -total 100]

# Practical procedure for managing the Tcl event loop :
zesty::loop -start 0 -end 100 -delay 50 {
    $bar advance $task1 1
}

```
📋 Tables
```tcl
# Create a styled table
set table [zesty::Table new \
    -title {name "Sales Report" style {fg blue bold 1}} \
    -box {type "rounded"}
]

$table addColumn -name "Product" -width 20
$table addColumn -name "Price" -justify "right"
$table addColumn -name "Stock" -justify "center"

$table addRow "Laptop" "\$1,299" "15"
$table addRow "Mouse" "\$29" "125"

$table display
```
Boxes
```tcl
# Simple box with title
set box [zesty::box \
    -title {name "Info" anchor "nc"} \
    -content {text "Your content here"} \
    -padding 2
]
```
JSON Formatting
```tcl
# Pretty-print JSON with syntax highlighting
set json {{"name": "John", "age": 30, "active": true}}
zesty::echo [zesty::jsonDecode -json $json]

# Custom styling for JSON elements
zesty::echo [zesty::jsonDecode -json $json -showLinesNumber 1 -style {
    key {fg cyan}
    str {fg yellow}
    num {fg green}
    null {fg red}
    boolean {fg blue bold 1}
    lineNum {fg 254 reverse 1}
}]
```
## 📖 Documentation :

### Echo command
The `zesty::echo` command provides styled console output:
```tcl
zesty::echo text ?options?
````
#### Options:
| args           | Description               
| ------         | ------                    
| _-style_       | Style specifications      
| _-n_           | No newline        
| _-noreset_     | Don't reset formatting      
| _-filters_     | Apply style filters (num, email, url)    

#### Style Options:
args                                        |Description
| ------                                    | ------                    
| _fg,bg_                                   | Foreground/background color (name, number or hexcolor)   
| _bold, italic, underline, strikethrough_  | Text decorations       
| _dim, reverse, blink_                     | Additional effects     
 
###  Progress Bars
> [!IMPORTANT]    
> The `zesty::Bar` class relies heavily on Tcl's event loop for rendering updates and animations. This has critical implications for your application design .Any blocking operation (e.g., after ms, vwait, synchronous I/O) will suspend the event loop and freeze progress bar updates.

The progress bar uses after idle callbacks to schedule rendering operations. 

Create multi-task progress displays with animations:
```tcl
set bar [zesty::Bar new ?options?]
```
#### Options:
| args                      | Description               
| ------                    | ------                    
|_-minColumnWidth_          | minimum column width
|_-minBarWidth_             | minimum progress bar width 
|_-ellipsisThreshold_       | threshold for ellipsis display
|_-barChar_                 | character for progress bar fill
|_-bgBarChar_               | character for progress bar background
|_-leftBarDelimiter_        | left delimiter for progress bar
|_-rightBarDelimiter_       | right delimiter for progress bar
|_-indeterminateBarStyle_   | animation style (bounce, pulse, wave)
|_-spinnerFrequency_        | spinner update frequency in ms
|_-indeterminateSpeed_      | animation speed
|_-setColumns_              | custom column configuration
|_-colorBarChar_            | color for progress bar fill
|_-colorBgBarChar_          | color for progress bar background
|_-headers_                 | custom header configuration
|_-lineHSeparator_          | custom header separator configuration

#### Default column types are:

- zName - Task description
- zBar - Progress bar
- zPercent - Percentage
- zCount - Current/Total
- zElapsed - Elapsed time
- zRemaining - ETA
- zSpinner - Animated spinner
- zSeparator - Column separator

> [!TIP]    
> - You can create your own column types.   

### Tables
Create formatted tables with automatic sizing:
```tcl
set table [zesty::Table new ?options?]
```
#### Options:
args                  |Description
| ------              | ------                    
|_-title_             | Table title
|_-caption_           | Table caption
|_-box_               | Table box style
|_-padding_           | Table padding
|_-showEdge_          | Show table edge
|_-lines_             | Show table lines
|_-header_            | Show table header
|_-keyPgup_           | Key for page up
|_-keyPgdn_           | Key for page down
|_-keyQuit_           | Key for quit
|_-maxVisibleLines_   | Maximum number of visible lines
|_-autoScroll_        | Enable auto-scrolling
|_-pageScroll_        | Enable page scrolling
|_-continuousScroll_  | Enable continuous scrolling

### Boxes
Create styled text boxes:
```tcl
zesty::box ?options?
```
#### Options:
args                            |Description
| ------                        | ------                    
|_-title_                       | title configuration
|_-content_                     | content configuration
|_-box_                         | box appearance settings
|_-padding_                     | uniform padding
|_-paddingX_                    | horizontal padding
|_-paddingY_                    | vertical padding
|_-formatCmdBoxMsgtruncated_    | truncation callback command

### JSON decoder
The `zesty::jsonDecode` command formats JSON with syntax highlighting:
```tcl
zesty::jsonDecode ?options?
```
#### Options:
args                            |Description
| ------                        | ------                    
|_-json_                        | JSON data to decode
|_-dumpJSONOptions_             | formatting huddle options
|_-style_                       | styling specifications
|_-showLinesNumber_             | whether to show line numbers

### 🎨 Color support :  
`zesty` supports multiple color formats:
```tcl
# Named colors
-style {fg "red"}
# 256-color palette (0-255)
-style {fg 196}
# Hex colors
-style {fg "#FF5733"}
```
## 👀 Examples :
See the **[examples](/examples)** folder for all demos.

## 📄 License : 
**zesty** is covered under the terms of the [MIT](LICENSE) license.

## 🙏 Acknowledgments :
Inspired by modern CLI tools and libraries