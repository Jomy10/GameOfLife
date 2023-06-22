import SwiftCurses

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
