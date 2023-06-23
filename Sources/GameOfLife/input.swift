import SwiftCurses

@_transparent func handleInput(
    ch: WideChar?, 
    shouldUpdate: inout Bool,
    justToggledUpdate: inout Bool,
    previousCursorPos: inout Coordinate?,
    settingsWindow: inout SettingsWindow?,
    frametimeWindow: inout FrameTimeSettingWindow?,
    scr: inout Window
) throws {
    if let ch = ch {
        switch ch {
        case .char(let char):
            switch char {
            case "p":
                shouldUpdate.toggle()
                justToggledUpdate = true

                // TODO: why is cursor not moving back to the right position?
                if shouldUpdate {
                    cursorSet(.invisible)
                    previousCursorPos = scr.yx
                } else {
                    cursorSet(.normal)
                }

                // clean status message
                let maxYX = scr.maxYX
                for i in 0..<maxYX.col {
                    try scr.addChar(row: 0, col: i, " ")
                    // draw cells underneath the text in the grid
                    try scr.addChar(row: 0, col: i, grid[0][Int(i)] ? C_ALIVE : C_DEAD)
                }
            case "h": 
                if let win = frametimeWindow {
                    win.timestep.up()
                    frametimeWindow?.draw()
                } else {
                    if settingsWindow != nil { break }
                    try? scr.move(.left)
                }
            case "j":
                if let win = frametimeWindow {
                    FRAME_TIME -= win.timestep.multiplier
                    frametimeWindow?.draw()
                } else {
                    if settingsWindow != nil { break }
                    try? scr.move(.down)
                }
            case "k":
                if let win = frametimeWindow {
                    FRAME_TIME += win.timestep.multiplier
                    frametimeWindow?.draw()
                } else {
                    if settingsWindow != nil { break }
                    try? scr.move(.up)
                }
            case "l":
                if let win = frametimeWindow {
                    win.timestep.down()
                    frametimeWindow?.draw()
                } else {
                    if settingsWindow != nil { break }
                    try? scr.move(.right)
                }
            case "i":
                if settingsWindow != nil { break }
                grid[Int(scr.yx.y)][Int(scr.yx.x)] = true
                try scr.addChar(C_ALIVE)
                try scr.move(.left)
            case "u":
                if settingsWindow != nil { break }
                grid[Int(scr.yx.y)][Int(scr.yx.x)] = false
                try scr.addChar(C_DEAD)
                try scr.move(.left)
            case "s":
                if settingsWindow == nil {
                    justToggledUpdate = true // update the menu bar
                    settingsWindow = try SettingsWindow(
                        rows: 1 + 2,
                        cols: Int32(SettingsWindow.settings.map { $0.0.count }.max() ?? 10) + 2,
                        begin: (10, 10),
                        settings: [])

                    cursorSet(.invisible)
                } else {
                    justToggledUpdate = true // update the menu bar
                    settingsWindow = nil
                    frametimeWindow = nil

                    if !shouldUpdate {
                        cursorSet(.normal)
                    }
                }

            case "f":
                if settingsWindow == nil { break } // check if settings menu is open
                // open frametime window
                if frametimeWindow == nil {
                    frametimeWindow = try FrameTimeSettingWindow.create(at: (10, 10 + (settingsWindow?.cols ?? 0)))
                } else {
                    frametimeWindow = nil
                    settingsWindow?.draw()
                }
            default: break
            }
        case .code(let code):
            switch code {
            case KeyCode.mouse:
                if let event = MouseEvent.get() {
                    if event.isClicked(.button1) {
                        if event.y > 0 && event.y < grid.count && event.x > 0 && event.x < grid[0].count {
                            grid[Int(event.y)][Int(event.x)] = true
                            try scr.addChar(row: event.y, col: event.x, C_ALIVE)
                            try scr.move(.left)
                        }
                    }
                }
            default: break
            }
        }
    }
}
