extension Collection {
	func forEachAsync(_ inner: @escaping (Element) async throws -> ()) async throws {
        var handles = Array<Task<(), any Error>>()
        handles.reserveCapacity(self.count)
		for element in self {
            handles.append(Task { try await inner(element) })
		}
        for handle in handles {
            if case .failure(let error) = await handle.result {
                throw error
            }
        }
	}
    
    func forEachAsyncEnumerated(_ inner: @escaping (Int, Element) async throws -> ()) async throws {
       var handles = Array<Task<(), any Error>>()
        handles.reserveCapacity(self.count)
        for (idx, element) in self.enumerated() {
            handles.append(Task { try await inner(idx, element) })
        }
        for handle in handles {
            if case .failure(let error) = await handle.result {
                throw error
            }
        }
    }
}
