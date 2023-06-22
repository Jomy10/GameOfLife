import SwiftCurses

var grid = Array(repeating: Array(repeating: false, count: W), count: H)
struct Instruction {
    let coordinate: (y: Int, x: Int)
    let newValue: Bool
}

/// Resizes the grid
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

/// Update the queue with instructions for the grid
@_transparent func updateQueue() async throws {
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

/// Draw the whole grid from scratch
func drawAll(scr: inout Window) throws {
    for (y, row) in grid.enumerated() {
        for (x, alive) in row.enumerated() {
            try scr.addChar(row: Int32(y), col: Int32(x), alive ? C_ALIVE : C_DEAD)
        }
    }
}
