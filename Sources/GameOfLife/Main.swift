import SwiftCurses
import Foundation

func main(scr: inout Window) async throws {
    var ch: WideChar? = nil

    var shouldUpdate = false
    var justToggledUpdate = true
    var previousCursorPos: Coordinate? = nil

    try MouseEvent.register(.button1Clicked)
    var settingsWindow: SettingsWindow? = nil
    var frametimeWindow: FrameTimeSettingWindow? = nil

    while (true) {
        let startTime = CFAbsoluteTimeGetCurrent()
        try handleInput(
            ch: ch,
            shouldUpdate: &shouldUpdate,
            justToggledUpdate: &justToggledUpdate,
            previousCursorPos: &previousCursorPos,
            settingsWindow: &settingsWindow,
            frametimeWindow: &frametimeWindow,
            scr: &scr
        )

        let canvasChanged = setGrid(maxYX: scr.maxYX.tuple)
        if shouldUpdate { try await updateQueue() }
        if !canvasChanged {
            try queue.dequeueing { instruction in
                grid[instruction.coordinate.y][instruction.coordinate.x] = instruction.newValue
                // Ony redraw changed cells
                try scr.addChar(
                    row: Int32(instruction.coordinate.y),
                    col: Int32(instruction.coordinate.x),
                    instruction.newValue ? C_ALIVE : C_DEAD)
            }
        } else {
            queue.dequeueing { instruction in
                grid[instruction.coordinate.y][instruction.coordinate.x] = instruction.newValue
            }
            try drawAll(scr: &scr)
        }

        if justToggledUpdate || canvasChanged { // only draw when needed (updated)
            let pos: Coordinate
            if let previousCursorPos = previousCursorPos {
                if justToggledUpdate {
                    pos = previousCursorPos
                } else {
                    pos = scr.yx
                }
            } else {
                pos = scr.yx
            }

            drawStatus(simulationPaused: !shouldUpdate, inMenu: settingsWindow != nil, maxYX: scr.maxYX.tuple, scr: &scr)
            try? scr.move(row: pos.y, col: pos.x)
        }

        scr.refresh()

        do {
            ch = try scr.getChar()
        } catch {
            ch = nil
        }

        justToggledUpdate = false

        frametimeWindow?.refresh()

        // elapsed time in milliseconds
        let elapsedTime: UInt64 =  UInt64((CFAbsoluteTimeGetCurrent() - startTime) * 1_000_000_000)
        let shouldSleepNANOS: UInt64 = FRAME_TIME - (elapsedTime > FRAME_TIME ? FRAME_TIME : elapsedTime)
        try await Task.sleep(nanoseconds: shouldSleepNANOS)
    }
}

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
