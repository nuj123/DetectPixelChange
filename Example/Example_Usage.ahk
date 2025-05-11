#Requires AutoHotkey v2
#SingleInstance Force

#include DetectPixelChange.ahk  ; path to the library

; manually define coordinates 
x := 100
y := 200

; start the class. Note, you can also skip the X/Y declaration above, and just do: 
; px := DetectPixelChange(100, 200)
px := DetectPixelChange(x,y)

; use the .Start() method with the class to start recording
F1::px.start()

; use the .Stop() to stop recording
f2::px.stop()

; Displays a moveable bounding box for the coordinate location specified.
F3::px.boxCoord()

; Press F12 to exit 
*F12::ExitApp