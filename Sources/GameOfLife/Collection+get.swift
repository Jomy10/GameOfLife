extension Collection where Index == Int {
    @_transparent func get(_ idx: Int) -> Element? {
        if idx > 0 && idx < self.count {
            return self[idx]
        }
        return nil
    }
}
