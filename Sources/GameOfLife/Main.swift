
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