#!/usr/bin/env tclsh

lappend auto_path [file dirname [file dirname [file normalize [info script]]]]
package require zesty

proc countPrimesInRange {start end} {
    set count 0
    for {set n $start} {$n <= $end} {incr n} {
        if {$n < 2} {continue}
        set isPrime 1
        for {set d 2} {$d * $d <= $n} {incr d} {
            if {$n % $d == 0} {set isPrime 0; break}
        }
        if {$isPrime} {incr count}
    }
    return $count
}

set bar [zesty::Bar new \
    -setColumns {zSpinner zName zCount zBar zPercent zElapsed}]

set chunkSize   2000
set totalChunks 500
set task [$bar addTask -name "Counting primes" -total $totalChunks]

set totalPrimes 0
try {
    for {set i 0} {$i < $totalChunks} {incr i} {
        set start [expr {$i * $chunkSize + 1}]
        set end   [expr {$start + $chunkSize - 1}]

        # Blocking computation in the application's interpreter.
        incr totalPrimes [countPrimesInRange $start $end]

        $bar advance $task
    }
} finally {
    $bar destroy
}
zesty::echo "Finished: $totalPrimes primes found below [expr {$totalChunks * $chunkSize}]."