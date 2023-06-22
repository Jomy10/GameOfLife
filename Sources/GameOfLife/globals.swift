// constants
let W = 100
let H = 100
let ALIVE = true
let DEAD = false
let C_ALIVE: Character = "#"
let C_DEAD: Character = " "

// variables
var FRAME_TIME: UInt64 = UInt64(0.16 * 1_000_000_000)
var queue: Queue<Instruction> = Queue()
