import SwiftCurses
import Foundation

let W = 100
let H = 100
let ALIVE = true
let DEAD = false
let C_ALIVE: Character = "#"
let C_DEAD: Character = " "
var FRAME_TIME: UInt64 = UInt64(0.16 * 1_000_000_000)

var grid = Array(repeating: Array(repeating: false, count: W), count: H)
struct Instruction {
    let coordinate: (y: Int, x: Int)
    let newValue: Bool
}
var queue: Queue<Instruction> = Queue()

func setGrid(maxYX: (row: Int32, col: Int32)) -> Bool {
    let diff = grid.count - Int(maxYX.row - 1) // Leave the last row blank
    switch diff {
    case 1...:
        grid.removeLast(diff)
    case ..<0:
        let w = grid[0].count
        grid.reserveCapacity(grid.count - diff)
        for _ in 0..<(-diff) {
            grid.append(Array(repeating: false, count: w))
        }
    default: break
    }
    
    let diffX = grid[0].count - Int(maxYX.col)
    switch diffX {
    case 1...:
        for i in 0..<grid.count {
            grid[i].removeLast(diffX)
        }
    case ..<0:
        let count = grid[0].count
        for i in 0..<grid.count {
            grid[i].reserveCapacity(count - diffX)
            for _ in 0..<(-diffX) {
                grid[i].append(false)
            }
        }
    default: break
    }

    return diff != 0 || diffX != 0
}

/// Update the grid
func updateQueue() async throws {
    grid.enumerated().forEach { y, row in
        // TODO: check for bounds in neighbours !!!
        var neighbours: [Bool] = []
        neighbours.reserveCapacity(8)
        
        for (x, alive) in row.enumerated() {
            neighbours = [
                grid.get(y)?.get(x - 1) ?? false,
                grid.get(y)?.get(x + 1) ?? false,
                grid.get(y - 1)?.get(x - 1) ?? false,
                grid.get(y + 1)?.get(x - 1) ?? false,
                grid.get(y + 1)?.get(x + 1) ?? false,
                grid.get(y - 1)?.get(x + 1) ?? false,
                grid.get(y + 1)?.get(x) ?? false,
                grid.get(y - 1)?.get(x) ?? false,
            ]
            
            let aliveNeighbours = neighbours.filter { $0 }.count
           
            if alive {
                switch aliveNeighbours {
                case ..<2:
                    queue.enqueue(Instruction(
                        coordinate: (y: y, x: x),
                        newValue: DEAD))
                case 4...:
                    queue.enqueue(Instruction(
                        coordinate: (y: y, x: x),
                        newValue: DEAD))
                default: break
                }
            } else {
                if aliveNeighbours == 3 {
                    queue.enqueue(Instruction(
                        coordinate: (y: y, x: x),
                        newValue: ALIVE))
                }
            }
        }
    }
}

func drawAll(scr: inout Window) throws {
    for (y, row) in grid.enumerated() {
        for (x, alive) in row.enumerated() {
            try scr.addChar(row: Int32(y), col: Int32(x), alive ? C_ALIVE : C_DEAD)
        }
    }
}

func main(scr: inout Window) async throws {
    var ch: WideChar? = nil

    var shouldUpdate = false
    var justToggledUpdate = true
    var previousCursorPos: Coordinate? = nil

    try MouseEvent.register(.button1Clicked)
    var settingsWindow: SettingsWindow? = nil
    var frametimeWindow: FrameTimeSettingWindow? = nil

    // TODO: key to kill a cell
    while (true) {
        let startTime = CFAbsoluteTimeGetCurrent()
        // handle input
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
                            }
                        }
                    }
                default: break
                }
            }
        }
    
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
        let shouldSleepNANOS: UInt64 = FRAME_TIME - elapsedTime
        try await Task.sleep(nanoseconds: shouldSleepNANOS > 0 ? shouldSleepNANOS : 0)
    }
}

func setFrameTime(nanoseconds: UInt64) {
    FRAME_TIME = nanoseconds
}

func drawStatus(simulationPaused: Bool, inMenu: Bool, maxYX: (row: Int32, col: Int32), scr: inout Window) {
    if simulationPaused { 
        try? scr.print(row: 0, col: 0, "Simulation paused")
    }

    let controlsShowStatus = (simulationPaused && !inMenu) ? " / <hjkl> move / <i> add cell / <u> remove cell" : ""

    // TODO: clean line when simulationPaused changes
    for i in 0..<maxYX.col {
        try? scr.addChar(row: maxYX.row - 1, col: i, " ")
    }
    try? scr.print(
        row: maxYX.row - 1,
        col: 0,
        "<p> toggle simulation \(inMenu ? "" : "/ <click> add cell")\(controlsShowStatus) / <s>\(inMenu ? " close" : "") settings / <Ctrl + C> exit"
    )
}

class SettingsWindow: ManagedWindow {
    static var settings = [
        // (SettingName, characterToUnderline)
        ("frametime", 0)
    ]

    func draw() {
        self.border()
        Self.settings.enumerated().forEach { (idx, setting) in
            try? self.printSetting(row: Int32(1 + idx), setting.0, underlineIndex: setting.1)
        }
        self.refresh()
    }

    override func onInit() {
        self.draw()
    }

    private func printSetting(row: Int32, _ text: String, underlineIndex: Int = 0) throws {
        let lowerEnd = text.index(text.startIndex, offsetBy: underlineIndex)
        let upperStart = text.index(lowerEnd, offsetBy: 1)
        let lowerString = String(text[..<lowerEnd])
        let actionChar = String(text[lowerEnd]).first!
        try self.print(row: row, col: 1, String(text[..<lowerEnd]))
        try self.withAttrs(.underline) {
            try self.addChar(row: row, col: 1 + Int32(lowerString.count), actionChar)
        }
        try self.print(row: row, col: 1 + Int32(lowerString.count) + 1, String(text[upperStart...]))
    }
}

class FrameTimeSettingWindow: ManagedWindow {
    static func create(at: (Int32, Int32)) throws -> FrameTimeSettingWindow {
        try FrameTimeSettingWindow(rows: 5, cols: Int32("\(UInt64.max) nanoseconds".count) + 2, begin: at, settings: [])
    }

    enum Timestep: Int8 {
        case nano
        case mili
        case sec

        var multiplier: UInt64 {
            switch self {
                case .nano: return 1
                case .mili: return 1_000_000
                case .sec:  return 1_000_000_000
            }
        }

        mutating func down() {
            self = Self(rawValue: self.rawValue - 1) ?? self
        }

        mutating func up() {
            self = Self(rawValue: self.rawValue + 1) ?? self
        }
    }

    func draw() {
        self.border()
        try? self.print(row: 0, col: 1, "frametime")
        // calculate FRAME_TIME / multiplier without converting the large FRAME_TIME number to Double
        let mult = self.timestep.multiplier
        let result: Double = Double(FRAME_TIME / mult) + (Double(FRAME_TIME % mult) / Double(mult))
        try? self.print(row: 1, col: 1, "\(result) nanoseconds")
        try? self.print(row: 2, col: 1, "<jk> change frametime")
        try? self.print(row: 3, col: 1, "<hl> change timestep")
        self.refresh()
    }

    var timestep: Timestep = .nano 

    override func onInit() {
        self.draw()
    }
}

@main
struct GameOfLifeApp {
    static func main() async {
       do {
            try await initScreenAsync(settings: [
                .noEcho,
                .cbreak,
                .timeout(0), // don't wait for input
             ], windowSettings: [.keypad(true)]) { scr in
                try await GameOfLife.main(scr: &scr)
            }
        } catch let error as CursesError {
            print(error.kind)
            if let help = error.help {
                print("Help: \(help)")
            }
        } catch {
            print(error)
        }

        cursorSet(.normal)
    }
}
