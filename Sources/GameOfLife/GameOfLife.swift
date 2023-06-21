import SwiftCurses

let W = 100
let H = 100
let ALIVE = true
let DEAD = false
let C_ALIVE: Character = "#"
let C_DEAD: Character = " "

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

    // grid[5][5] = true
    // grid[5][6] = true
    // grid[5][7] = true

    // grid[0 + 10][2 + 10] = true
    // grid[1 + 10][0 + 10] = true
    // grid[1 + 10][2 + 10] = true
    // grid[2 + 10][1 + 10] = true
    // grid[2 + 10][2 + 10] = true

    var shouldUpdate = false
    var justToggledUpdate = true
    var previousCursorPos: Coordinate? = nil

    try MouseEvent.register(.button1Clicked)

    // TODO: keyboard input for drawing cells as well
    // + show mouse when drawing (simulation not started), hide when not
    while (true) {
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
                case "h": try? scr.move(.left)
                case "j": try? scr.move(.down)
                case "k": try? scr.move(.up)
                case "l": try? scr.move(.right)
                case "i":
                    grid[Int(scr.yx.y)][Int(scr.yx.x)] = true
                    try scr.addChar(at: scr.yx, C_ALIVE)
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
            try queue.dequeueing { instruction in
                grid[instruction.coordinate.y][instruction.coordinate.x] = instruction.newValue
            }
            try drawAll(scr: &scr)
        }

        if justToggledUpdate { // only draw when needed (updated)
            if let previousCursorPos = previousCursorPos {
                try scr.move(row: previousCursorPos.y, col: previousCursorPos.x)
            }
        
            let pos = scr.yx
            drawStatus(simulationPaused: !shouldUpdate, maxYX: scr.maxYX.tuple, scr: &scr)
            try? scr.move(row: pos.y, col: pos.x)
        }
        
        scr.refresh()

        do {
            ch = try scr.getChar()
        } catch {
            ch = nil
        }

        justToggledUpdate = false
    }
}

func drawStatus(simulationPaused: Bool, maxYX: (row: Int32, col: Int32), scr: inout Window) {
    if simulationPaused { 
        try? scr.print(row: 0, col: 0, "Simulation paused")
    }

    let controlsShowStatus = simulationPaused ? " / <hjkl> move / <enter> add cell" : ""

    // TODO: clean line when simulationPaused changes
    for i in 0..<maxYX.col {
        try? scr.addChar(row: maxYX.row - 1, col: i, " ")
    }
    try? scr.print(
        row: maxYX.row - 1,
        col: 0,
        "<p> toggle simulation / <click> add cell\(controlsShowStatus) / <Ctrl + C> exit"
    )
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
    }
}
