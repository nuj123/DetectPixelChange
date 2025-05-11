# DetectPixelChange (AutoHotkey v2)

A pixel monitoring and screen masking tool written in AutoHotkey v2. This script continuously tracks the color of a screen pixel and logs every change with a timestamp. It also visually highlights the pixel using a movable and color-changing 10×10 bounding box with a visible border. It uses the native `PixelGetColor()` function from AHK v2.

---

## ✨ Features

- Monitors a specific screen pixel (`x`, `y`) at a configurable interval
- Records timestamped color changes to a ListView
- Visually masks a 20×20 square area around the pixel with the center exposed
- Box is draggable via mouse (even though it's composed of 4 transparent GUIs)
- Color history (with timestamps!) can be viewed in a GUI with copyable values
- Double-click any row to copy the hex color to clipboard

---

## 📦 Usage

1. Install [**AutoHotkey v2**](https://www.autohotkey.com/download/ahk-v2.exe)
2. Modify the initial coordinates in the script if needed:
   ```autohotkey
   x := 100
   y := 200
   ```
   You can also do: 
   ```
   px := DetectPixelChange(100, 200) ; x = 100, y = 200
   ```

3. To start, do `.start()`
4. To stop, do `.stop()`
5. To adjust the pixel manually by mouse, do `.boxCoord()`

## Example: 

```
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
```
