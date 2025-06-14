#!/usr/bin/env tclsh

# Test file for progress bar extended class.
# This file demonstrates various features and capabilities of the progress bar system.

lappend auto_path [file dirname [file dirname [file normalize [info script]]]]

package require zesty

proc mycmd {self tid task} {
    set elapsed [$self elapsedTime $tid]
    if {$elapsed <= 0} {
        return [zesty::parseStyleDictToXML 0 {fg "#0000ff" bold true}]
    }
    set rate [expr {[dict get $task completed] / $elapsed}]

    if {$rate <= 0} {
        return [zesty::parseStyleDictToXML 0 {fg "#0000ff" bold true}]
    }

    return [format %0.3f $rate]
}

proc test_progress_extended {} {

    set pb [zesty::Bar new \
        -minColumnWidth 6 \
        -minBarWidth 20 \
        -barChar "#" \
        -bgBarChar " " \
        -headers {
            show true
        } \
        -lineHSeparator {
            show true
            style {fg green}
        } \
        -indeterminateBarStyle "bounce" \
        -leftBarDelimiter "|" \
        -rightBarDelimiter "|" \
        -setColumns {zSpinner zName zCount zBar zPercent zElapsed mycmd {zSeparator •} zRemaining {zSeparator •}} \
    ]


    set pb1 [zesty::Bar new \
        -minColumnWidth 6 \
        -minBarWidth 20 \
        -barChar "\u2588" \
        -bgBarChar "\u2591" \
        -leftBarDelimiter "|" \
        -rightBarDelimiter "|" \
        -indeterminateBarStyle "pulse" \
        -setColumns {zSpinner zName zCount zBar zPercent zElapsed mycmd {zSeparator •} zRemaining {zSeparator •}} \
    ]


    $pb1 configureColumn 0 -style {fg green} -spinnerStyle bars
    $pb1 configureColumn 1 -style {fg cyan bold 1}
    $pb1 configureColumn 4 -style {fg yellow bold 1}

    $pb1 configureColumn 2 -format [list apply {{dictvalue} {

        set tasks   [dict get $dictvalue tasks]
        set task_id [dict get $dictvalue idTask]
        set self    [dict get $dictvalue self]
        set value   [dict get $dictvalue result]


        set is_completed [expr {
            [dict get $tasks $task_id completed] >= [dict get $tasks $task_id total]
        }]

        if {$is_completed} {
            $self update $task_id -description "Completed"
            $self updateColumn $task_id 1
        }
        return $value
    }}]

    $pb1 configureColumn 3 -format [list apply {{dictvalue} {
        set value          [dict get $dictvalue result]
        set bar            [dict get $dictvalue bar]
        set self           [dict get $dictvalue self]
        set task_id        [dict get $dictvalue idTask]
        set width          [dict get $dictvalue width]
        set colorBgBarChar [dict get $dictvalue colorBgBarChar]

        if {$value >= 100} {
            return [$self renderBar \
                $task_id \
                $width $value \
                $colorBgBarChar "Yellow" \
            ]
        }
        return $bar
    }}]

    set mytask [$pb1 addTask -mode indeterminate]
    $pb1 addTask -total 100 -completed 0
    $pb1 addTask -total 100 -completed 0
    $pb1 addTask -total 100 -completed 0
    $pb1 addTask -total 100 -completed 0
    $pb1 addTask -total 100 -completed 0
    $pb1 addTask -total 100 -completed 0
    $pb1 addTask -total 100 -completed 0
    $pb1 addTask -total 100 -completed 0
    set task1_id [$pb1 addTask -total 100 -completed 0]
    $pb addTask -total 100 -mode indeterminate -animStyle wave
    set task2_id [$pb1 addTask -total 100 -completed 0]

    after 3000 [list $pb1 update $mytask -mode "determinate"]
    after 6000 [list $pb1 advance $mytask 100]

    # Standard usage - the script will automatically wait for completion
    zesty::loop -start 0 -end 100 -delay 100 {
        $pb1 advance $task1_id 1
        $pb1 advance $task2_id 2
    }

    $pb cleanup
    $pb1 cleanup
    $pb destroy
    $pb1 destroy

    zesty::echo "Extended progress test completed"
}

# Function to calculate download speed
proc download_speed {args} {
    global current_speed
    
    # Format speed in KB/s or MB/s
    if {$current_speed < 1024} {
        return "[format "%.1f" $current_speed] KB/s"
    } else {
        return "[format "%.2f" [expr {$current_speed / 1024.0}]] MB/s"
    }
}

# Function to simulate file download
proc download_file {filename size {speed 512}} {
    global current_speed

    set color "red"

    if {$speed == 512} {
        set color "green"
    } elseif {$speed == 1024} {
        set color "yellow"
    }

    # Create a ProgressBar instance with custom configuration
    set pb [zesty::Bar new \
        -minColumnWidth 10 \
        -minBarWidth 30 \
        -barChar "█" \
        -bgBarChar "░" \
        -leftBarDelimiter "\[" \
        -rightBarDelimiter "\]" \
        -colorBarChar $color
    ]
    
    
    # Configure columns
    $pb configureColumn 0 -width 25  ;# Filename
    $pb configureColumn 2 -width 40  ;# Progress bar
    $pb configureColumn 3 -width 8   ;# Percentage
    $pb configureColumn 4 -width 15 ;# Elapsed time
    $pb configureColumn 5 -width 15 ;# Remaining time
    
    # Add custom column for download speed
    $pb addColumn 6 -width 15 -type download_speed
    
    # Create download task
    set task_id [$pb addTask -total $size -completed 0 -name "Download: $filename"]
    
    # Variables to track download
    set downloaded 0
    set start_time [clock milliseconds]
    set last_update [clock milliseconds]
    set last_downloaded 0
    set current_speed 0
    

    # Simulate download by blocks
    while {$downloaded < $size} {
        set forever 0
        # Calculate amount to download for this iteration
        # (with variation to simulate network fluctuations)
        set variation [expr {int(rand() * $speed * 0.5)}]
        set download_amount [expr {$speed + $variation - int(rand() * $speed * 0.3)}]
        
        # Don't exceed total size
        if {$downloaded + $download_amount > $size} {
            set download_amount [expr {$size - $downloaded}]
        }
        
        # Update download counter
        incr downloaded $download_amount
        
        # Calculate current speed (KB/s)
        set now [clock milliseconds]
        if {$now - $last_update > 500} {  # Update speed every 500ms
            set time_diff [expr {($now - $last_update) / 1000.0}]
            set data_diff [expr {$downloaded - $last_downloaded}]
            set current_speed [expr {$data_diff / $time_diff}]
            
            set last_update $now
            set last_downloaded $downloaded
        }
        
        # Update progress bar
        $pb update $task_id -completed $downloaded
        
        # Pause to simulate download time
        after [expr {int(1000 * rand())}] {set forever 1}
        vwait forever
    }
    
    # Display success message
    zesty::echo "\nDownload of $filename completed:\
    $size KB in [format "%.1f" [expr {([clock milliseconds] - $start_time) / 1000.0}]] seconds"
    
    # Free resources
    $pb cleanup
    $pb destroy
}

test_progress_extended

# Simulate downloading different files
download_file "document.pdf" 5120 256 ;# 5MB at 256KB/s
download_file "image.jpg" 1024 512    ;# 1MB at 512KB/s  
download_file "video.mp4" 20480 1024  ;# 20MB at 1MB/s