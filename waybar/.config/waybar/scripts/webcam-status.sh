#!/bin/bash
# Reports webcam in-use state for waybar custom/webcam.
# /dev/video* are character devices; open/close don't emit inotify events,
# so this polls with fuser (cheap; user has ACL access via systemd-logind uaccess).

icon=$''

if fuser /dev/video0 /dev/video1 >/dev/null 2>&1; then
    printf '{"text":"%s","class":"active","tooltip":"Webcam en uso"}\n' "$icon"
else
    printf '{"text":"%s","class":"inactive","tooltip":"Webcam libre"}\n' "$icon"
fi
