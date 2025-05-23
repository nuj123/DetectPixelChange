#Requires AutoHotkey v2
#SingleInstance Force

/*
    ===========================================
    DetectPixelChange Class Documentation
    ===========================================

    Main Purpose:
    -------------
    Tracks pixel color changes at screen coordinates (x, y),
    displays a movable 10×10 mask around the target pixel, and
    logs all changes with timestamps in a GUI ListView.

    Constructor:
    ------------
    __New(x := 0, y := 0)
        Initializes the class with the specified pixel coordinate.
        Sets up mouse messages for dragging and binds timers.

    Public Methods:
    ---------------
    start(timer := 15)
        Starts pixel monitoring at the given interval (ms).
        Initializes the visual box and clears previous logs.

    stop()
        Stops pixel monitoring and displays the change log GUI.

    end()
        Alias for stop().

    Coord(x, y)
        Updates the pixel coordinate to track.

    displayGUI()
        Builds and shows the ListView GUI containing change logs.

    Private/Internal Methods:
    -------------------------
    BoxCoord()
        Creates 4 GUI windows to frame the pixel with a 10×10 mask
        that leaves the center exposed.

    MoveBox()
        Positions the 4 mask GUIs around the current pixel coordinate.

    RemoveBox()
        Destroys all 4 mask GUIs.

    DetectColor()
        Called periodically via SetTimer; records pixel color if changed.

    MakeGui()
        Constructs the ListView window and populates it with swatch icons,
        timestamps, and color codes.

    CreateSolidColorBitmap(w, h, color)
        Generates an HBITMAP of solid color (used for swatch icons).

    Show()
        Displays the ListView GUI window.

    Dragging Support (via OnMessage):
    ---------------------------------
    WM_LBUTTONDOWN()
        Starts drag tracking when mask GUI is clicked.

    DoDrag()
        Actively moves the box with the mouse using SetTimer.

    WM_LBUTTONUP()
        Ends dragging.

*/

class DetectPixelChange {
    ; Half-width of the 20x20 visual mask (center pixel exposed)
    radius := 10

    ; State fields
    pixelMap := []          ; Stores detected pixel color changes with timestamps
    pxColorOld := ""        ; Previously recorded pixel color
    pxColorNew := ""        ; Current pixel color
    guiCreated := 0         ; Whether the GUI log window has been built
    isStarted := 0          ; Flag to indicate active monitoring

    ; Dragging fields
    dragging := false

    dx := 0                 ; Offset from mouse to mask center when dragging starts
    dy := 0

    ; Constructor: sets coordinates and drag timer
    __New(x := A_ScreenWidth // 2, y:= A_ScreenHeight // 2) {
        CoordMode("Pixel", "Screen")
        CoordMode("Mouse", "Screen")

        this.x := x
        this.y := y

        this.DoDragTimer := this.DoDrag.Bind(this)

        OnMessage(0x201, ObjBindMethod(this, "WM_LBUTTONDOWN")) ; WM_LBUTTONDOWN
        OnMessage(0x202, ObjBindMethod(this, "WM_LBUTTONUP"))   ; WM_LBUTTONUP
    }

    ; Creates 4 GUIs to mask the area around the pixel with only center exposed
    BoxCoord() {
        try {
            for guis in this.maskGuis
                guis.destroy
        }

        this.maskGuis := []
        this.maskGuisHwnd := []
        ; name choice:
            ; TL = Top Left
            ; TR = Top Right
            ; BL = Bottom Left
            ; BR = Bottom Right

        ; Create 4 GUIs to mask the area around the pixel with only center exposed
        for name in ["TL", "BL", "TR", "BR"] {
            g := this.GuiCreate("+AlwaysOnTop -Caption +ToolWindow +E0x20 +border")
            ; g := this.GuiCreate("-Caption +ToolWindow +E0x20 +border")
            g.BackColor := "Black"
            this.%name% := g
            this.maskGuis.Push(g)
            this.maskGuisHwnd.Push(g.hwnd)
        }
        this.MoveBox()
    }

    ; Moves the 4 mask windows to surround the target pixel with a 10x10 box
    MoveBox() {
        ; for index, hwnd in this.maskGuisHwnd {
        ;     if !WinExist("ahk_id" hwnd)
        ;         return
        ; }

        this.border := border := 1
        radius := this.radius

        x1 := this.x - radius
        y1 := this.y - radius

        x2 := this.x + radius
        y2 := this.y + radius

        for name in this.maskGuis {
            name.BackColor := this.pxColorNew
        }

        ; Show each quadrant mask GUI
        this.TL.Show("x" x1               " y" y1               " w" radius - border -1 " h" radius - border -1 " NoActivate")
        this.BL.Show("x" x1               " y" this.y + border  " w" radius - border -1 " h" radius - border -1 " NoActivate")

        this.TR.Show("x" this.x + border  " y" y1               " w" radius - border -1 " h" radius - border -1 " NoActivate")
        this.BR.Show("x" this.x + border  " y" this.y + border  " w" radius - border -1 " h" radius - border -1 " NoActivate")
    }

    ; Helper to create GUIs with options. Gui() was bugging out in the BoxCoord() method for some reason.
    GuiCreate(options := "") {
        return Gui(Options)
    }
    
    ; Mouse down: Start drag mode, store offset
    WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
        ; Only process if the click was on one of our mask windows
        isMaskWindow := false
        for index, maskHwnd in this.maskGuisHwnd {
            if (hwnd = maskHwnd) {
                isMaskWindow := true
                break
            }
        }
        
        if (!isMaskWindow)
            return
            
        MouseGetPos(&mx, &my)
        this.dragging := true
        this.dx := mx - this.x
        this.dy := my - this.y
        SetTimer(this.DoDragTimer, 10)
    }

    ; While dragging: update position based on mouse movement
    DoDrag() {
        if !this.dragging
            return

        MouseGetPos(&mx, &my)
        this.x := mx - this.dx
        this.y := my - this.dy
        this.moveBox()
    }

    ; Mouse up: Stop drag mode
    WM_LBUTTONUP(*) {
        this.dragging := false
        SetTimer(this.DoDragTimer, 0)
    }

    ; Remove the 4 mask GUIs
    RemoveBox() {
        for box in this.maskGuis
            box.Destroy()
        this.maskGuis := []
        this.maskGuisHwnd := []
    }

    ; Set the pixel coordinates to watch for
    Coord(x := 0, y := 0) {
        this.x := x
        this.y := y
        return 1
    }

    ; Start monitoring the pixel color changes
    ; timer: time in ms between checks
    start(timer := 30) {
        this.isStarted := 1
        this.BoxCoord()
        this.pxColorOld := ""
        this.pixelMap := []

        try {
            this.pixgui.Destroy
            this.guiCreated := 0
        }

        this.Timer := ObjBindMethod(this, "DetectColor")
        SetTimer(this.Timer, timer)
    }

    ; Alias for stop()
    end() {
        this.stop()
    }

    ; Stops monitoring and shows result GUI
    stop() {
        if !(this.isStarted)
            return

        SetTimer(this.Timer, 0)
        this.RemoveBox()
        this.displayGUI()
        this.isStarted := 0
    }

    ; Checks current pixel color and logs any change
    DetectColor() {

        this.pxColorNew := PixelGetColor(this.x, this.y)

        if (this.pxColorNew = this.pxColorOld)
            return
        this.pxColorOld := this.pxColorNew
        currentTime := A_Hour ":" A_MIN ":" A_SEC "." A_MSec
        this.pixelMap.Push(Map("time", currentTime, "color", this.pxColorNew))
    }

    ; Displays the GUI with the color log
    displayGUI() {

        this.MakeGui()
        this.Show()
        return this.pixelMap
    }

    ; Builds GUI containing ListView of all color changes
    MakeGui() {

        if (this.guiCreated = 1)
            this.pixGui.destroy

        this.guiCreated := 1

        this.pixGui := Gui()

        this.lv := this.pixGui.Add("ListView", "w400 r10 +LV0x0001", ["", "Time", "Color"])

        ; Create and assign image list to the ListView
        ; this.hIL := DllCall("Comctl32.dll\ImageList_Create", "Int", 16, "Int", 16, "UInt", 0x00, "Int", 10, "Int", 10, "Ptr")
        this.hIl := IL_Create(this.pixelMap.Length)

        LVSIL_SMALL := 1
        this.LV.SetImageList(this.hIL)
        ; DllCall("SendMessage", "Ptr", this.lv.Hwnd, "UInt", 0x1003, "Ptr", LVSIL_SMALL, "Ptr", this.hIL)  ; LVM_SETIMAGELIST


        ; Populate the list
        for index, item in this.pixelMap {
            RGB := item["color"]

            if (Type(RGB) = "String")
                RGB := Integer(RGB)

            ; Convert RGB → BGR for GDI
            BGR := ((RGB & 0xFF) << 16) | (RGB & 0xFF00) | ((RGB >> 16) & 0xFF)

            hbm := this.CreateSolidColorBitmap(16, 16, BGR)
            iconIndex := IL_Add(this.hIl, "HBITMAP:" hbm)
            DllCall("DeleteObject", "Ptr", hbm)

            this.lv.Add("Icon" iconIndex, "", item["time"], Format("0x{:06X}",item["color"]))
        }

        ; Auto-adjust columns
        colCount := this.lv.GetCount("Column")
        Loop colCount
            this.lv.ModifyCol(A_Index, "AutoHdr")

        this.lv.OnEvent("DoubleClick", (lv, row) => (row ? A_Clipboard := lv.GetText(row, 3) : ""))

    }

    ; Creates a solid bitmap with the given color (used for swatches)
    ; TY ChatGPT. I have no clue how this works, but you made it work.
    ; I just wanted a solid color bitmap to use as an icon in the ListView.
    CreateSolidColorBitmap(width := 16, height := 16, color := 0x000000) {
        hdc := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
        hbm := DllCall("CreateBitmap", "Int", width, "Int", height, "UInt", 1, "UInt", 32, "Ptr", 0, "Ptr")
        obm := DllCall("SelectObject", "Ptr", hdc, "Ptr", hbm, "Ptr")

        hBrush := DllCall("CreateSolidBrush", "UInt", color, "Ptr")
        DllCall("SelectObject", "Ptr", hdc, "Ptr", hBrush)
        DllCall("PatBlt", "Ptr", hdc, "Int", 0, "Int", 0, "Int", width, "Int", height, "UInt", 0x42)  ; PATCOPY

        DllCall("SelectObject", "Ptr", hdc, "Ptr", obm)
        DllCall("DeleteObject", "Ptr", hBrush)
        DllCall("DeleteDC", "Ptr", hdc)

        return hbm
    }

    ; Shows the GUI window with the ListView of the pixel changes.
    Show() {
        this.pixGui.Show()
    }
}
