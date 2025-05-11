#Requires AutoHotkey v2
#SingleInstance Force

class DetectPixelChange {
    radius := 10

    pixelMap := []
    pxColorOld := ""
    pxColorNew := ""
    guiCreated := 0
    isStarted := 0

    dragging := false
    dragOffsetX := 0
    dragOffsetY := 0
    dragWindow := ""

    dx := 0
    dy := 0

    __New(x := 0, y:= 0) {
        CoordMode("Pixel", "Screen")
        CoordMode("Mouse", "Screen")

        this.x := x
        this.y := y

        this.DoDragTimer := this.DoDrag.Bind(this)

        OnMessage(0x201, ObjBindMethod(this, "WM_LBUTTONDOWN")) ; WM_LBUTTONDOWN
        OnMessage(0x202, ObjBindMethod(this, "WM_LBUTTONUP"))   ; WM_LBUTTONUP
    }

    BoxCoord() {
        try {
            for guis in this.maskGuis
                guis.destroy
        }

        this.maskGuis := []

        for name in ["TL", "BL", "TR", "BR"] {
            g := this.GuiCreate("+AlwaysOnTop -Caption +ToolWindow +E0x20 +border")
            ; g := this.GuiCreate("-Caption +ToolWindow +E0x20 +border")
            g.BackColor := "Black"
            this.%name% := g
            this.maskGuis.Push(g)
        }
        this.MoveBox()
    }

    MoveBox() {

        this.border := border := 1
        radius := this.radius

        x1 := this.x - radius
        y1 := this.y - radius

        x2 := this.x + radius
        y2 := this.y + radius

        for name in this.maskGuis {
            name.BackColor := this.pxColorNew
        }

        this.TL.Show("x" x1               " y" y1               " w" radius - border -1 " h" radius - border -1 " NoActivate")
        this.BL.Show("x" x1               " y" this.y + border  " w" radius - border -1 " h" radius - border -1 " NoActivate")

        this.TR.Show("x" this.x + border  " y" y1               " w" radius - border -1 " h" radius - border -1 " NoActivate")
        this.BR.Show("x" this.x + border  " y" this.y + border  " w" radius - border -1 " h" radius - border -1 " NoActivate")
    }

    GuiCreate(options := "") {
        return Gui(Options)
    }

    WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
            MouseGetPos &mx, &my
            this.dragging := true

            this.dx := mx - this.x
            this.dy := my - this.y
            SetTimer(this.DoDragTimer, 10)
    }
    DoDrag() {
        if !this.dragging
            return

        MouseGetPos(&mx, &my)
        this.x := mx - this.dx
        this.y := my - this.dy
        this.moveBox()
    }

    WM_LBUTTONUP(*) {
        this.dragging := false
        SetTimer(this.DoDragTimer, 0)
    }

    RemoveBox() {
        for box in this.maskGuis
            box.Destroy()
        this.maskGuis := []
    }

    Coord(x := 0, y := 0) {
        this.x := x
        this.y := y
        return 1
    }
    start(timer := 15) {
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

    end() {
        this.stop()
    }
    stop() {
        if !(this.isStarted)
            return

        SetTimer(this.Timer, 0)
        this.RemoveBox()
        this.displayGUI()
        this.isStarted := 0
    }

    DetectColor() {

        this.pxColorNew := PixelGetColor(this.x, this.y)

        if (this.pxColorNew = this.pxColorOld)
            return

        this.pxColorOld := this.pxColorNew
        currentTime := A_Hour ":" A_MIN ":" A_SEC "." A_MSec
        this.pixelMap.Push(Map("time", currentTime, "color", this.pxColorNew))
    }

    displayGUI() {

        this.MakeGui()
        this.Show()
        return this.pixelMap
    }

    MakeGui() {

        if (this.guiCreated = 1)
            this.pixGui.destroy

        this.guiCreated := 1

        this.pixGui := Gui()

        this.lv := this.pixGui.Add("ListView", "w400 r10 +LV0x0001", ["", "Time", "Color"])

        ; Create and assign image list to the ListView
        this.hIL := DllCall("Comctl32.dll\ImageList_Create", "Int", 16, "Int", 16, "UInt", 0x00, "Int", 10, "Int", 10, "Ptr")

        LVSIL_SMALL := 1
        DllCall("SendMessage", "Ptr", this.lv.Hwnd, "UInt", 0x1003, "Ptr", LVSIL_SMALL, "Ptr", this.hIL)  ; LVM_SETIMAGELIST


        ; Populate the list
        for item in this.pixelMap {
            color := Integer(item["color"])

            ; Create bitmap and add to image list
            hbm := this.CreateSolidColorBitmap(16, 16, color)
            iconIndex := DllCall("Comctl32.dll\ImageList_Add", "Ptr", this.hIL, "Ptr", hbm, "Ptr", 0, "Int") + 1
            DllCall("DeleteObject", "Ptr", hbm)

            this.lv.Add("Icon" iconIndex, "", item["time"], Format("0x{:06X}", color))
        }

        ; Auto-adjust columns
        colCount := this.lv.GetCount("Column")
        Loop colCount
            this.lv.ModifyCol(A_Index, "AutoHdr")

        this.lv.OnEvent("DoubleClick", (lv, row) => (row ? A_Clipboard := lv.GetText(row, 3) : ""))

    }

    CreateSolidColorBitmap(w, h, color) {
        hdc := DllCall("GetDC", "ptr", 0, "ptr")
        memDC := DllCall("CreateCompatibleDC", "ptr", hdc, "ptr")
        hbm := DllCall("CreateCompatibleBitmap", "ptr", hdc, "int", w, "int", h, "ptr")
        DllCall("ReleaseDC", "ptr", 0, "ptr", hdc)

        oldObj := DllCall("SelectObject", "ptr", memDC, "ptr", hbm, "ptr")
        brush := DllCall("CreateSolidBrush", "uint", color, "ptr")

        ; RECT structure for FillRect
        rc := Buffer(16, 0)
        NumPut("int", 0, rc, 0)           ; left
        NumPut("int", 0, rc, 4)           ; top
        NumPut("int", w, rc, 8)           ; right
        NumPut("int", h, rc, 12)          ; bottom

        DllCall("FillRect", "ptr", memDC, "ptr", rc, "ptr", brush)

        DllCall("DeleteObject", "ptr", brush)
        DllCall("SelectObject", "ptr", memDC, "ptr", oldObj)
        DllCall("DeleteDC", "ptr", memDC)

        return hbm
    }

    Show() {
        this.pixGui.Show()
    }
}
