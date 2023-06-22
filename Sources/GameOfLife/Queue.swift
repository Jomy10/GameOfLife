struct Queue<Element> {
    var list = [Element]()

    mutating func enqueue(_ element: Element) {
        self.list.append(element)
    }
    
    mutating func dequeue() -> Element? {
        if !self.list.isEmpty {
            return self.list.removeFirst()
        } else {
            return nil
        }
    }
    
    mutating func dequeueing(_ fn: (Element) throws -> ()) rethrows {
        try self.list.forEach(fn)
        self.list.removeAll(keepingCapacity: true)
    }
}
