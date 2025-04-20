#!/bin/bash
# Xiang Wang(ramwin@qq.com)


ffmpeg -i mp4.mp4  -i mp3.mp3 -map 0:v:0 -map 1:a:0 -acodec copy -shortest result.mp4
