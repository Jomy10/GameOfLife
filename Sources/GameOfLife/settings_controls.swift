import SwiftCurses

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
    static let windowSize = Int32("\(UInt64.max) nanoseconds".count) + 2

    static func create(at: (Int32, Int32)) throws -> FrameTimeSettingWindow {
        try FrameTimeSettingWindow(rows: 5, cols: Self.windowSize, begin: at, settings: [])
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

        var name: String {
            switch self {
                case .nano: return "nanoseconds"
                case .mili: return "miliseconds"
                case .sec:  return "seconds"
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

        // clear the first line of the window
        try? self.print(row: 1, col: 1, Array(repeating: "", count: Int(Self.windowSize - 2)).joined(separator: " "))

        let mult = self.timestep.multiplier
        let result: Double = Double(FRAME_TIME) / Double(mult)
        try? self.print(row: 1, col: 1, "\(result) \(self.timestep.name)")
        try? self.print(row: 2, col: 1, "<jk> change frametime")
        try? self.print(row: 3, col: 1, "<hl> change timestep")
        self.refresh()
    }

    var timestep: Timestep = .nano

    override func onInit() {
        self.draw()
    }
}
