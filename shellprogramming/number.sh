#!/bin/bash
# Xiang Wang @ 2016-03-19 00:32:04

n=1
while [ $n -le 6 ]; do
    echo $n
    let n++
done

y=1
while [ $y -le 12 ]; do
    x=1
    while [ $x -le 12 ]; do
        printf "% 4d" $(( $x *$y ))
        let x++
    done
    echo ""
    let y++
done
