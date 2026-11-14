import Foundation
import Dependencies
import OfflineSyncCore
import OfflineSyncServices
import Moya


public class PageRequestService<Model: TableProtocol, API: TargetType>: RequestService<Model, API> {
    var fetchPageMethod: (Int) -> API
    private(set) var observedServerDate: Date?
    
    init(
        fetchMethod: @escaping (Int) -> API,
        insertMethod: ((Model) -> API)? = nil,
        updateMethod: ((Model) -> API)? = nil,
        deleteMethod: ((Int) -> API)? = nil,
        
        provider: MoyaProvider<API>,
        _setPlugins: @escaping ([PluginType]) -> MoyaProvider<API>
    ) {
        self.fetchPageMethod = fetchMethod
        
        super.init(
            fetchMethod: nil,
            insertMethod: insertMethod,
            updateMethod: updateMethod,
            deleteMethod: deleteMethod,
            
            provider: provider,
            _setPlugins: _setPlugins
        )
    }
    
    override public func fetch() async throws -> [Model] {
        observedServerDate = nil
        let client = provider
        let first = try await requestResponse(client, fetchPageMethod(1))
        if let date = first.response?.value(forHTTPHeaderField: "Date") {
            let parser = DateFormatter()
            parser.locale = Locale(identifier: "en_US_POSIX")
            parser.calendar = Calendar(identifier: .gregorian)
            parser.timeZone = TimeZone(secondsFromGMT: 0)
            parser.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            observedServerDate = parser.date(from: date)
        }
        guard let value = first.response?.value(forHTTPHeaderField: "X-Total-Pages"),
              let pages = Int(value), (0...100_000).contains(pages) else { throw ServiceError.invalidPagination }
        let initial = try JSONDecoder().decode([Model].self, from: first.data)
        if pages == 0 {
            guard initial.isEmpty else { throw ServiceError.invalidPagination }
            return []
        }
        var batches = [1: initial]
        if pages > 1 {
            // Bound outstanding requests rather than creating one task per history page.
            try await withThrowingTaskGroup(of: (Int, [Model]).self) { group in
                var next = 2
                func enqueue(_ page: Int) {
                    group.addTask {
                        let response = try await self.requestResponse(client, self.fetchPageMethod(page))
                        guard response.response?.value(forHTTPHeaderField: "X-Total-Pages") == value else {
                            throw ServiceError.invalidPagination
                        }
                        return (page, try JSONDecoder().decode([Model].self, from: response.data))
                    }
                }
                while next <= min(pages, 5) { enqueue(next); next += 1 }
                while let (page, records) = try await group.next() {
                    batches[page] = records
                    if next <= pages { enqueue(next); next += 1 }
                }
            }
        }
        let records = (1...pages).flatMap { batches[$0] ?? [] }
        guard Set(records.map(\.id)).count == records.count else { throw ServiceError.invalidPagination }
        return records
    }
}

public extension PageRequestService {
    static func live(
        fetchMethod: @escaping (Int) -> API,
        insertMethod: ((Model) -> API)? = nil,
        updateMethod: ((Model) -> API)? = nil,
        deleteMethod: ((Int) -> API)? = nil
    ) -> PageRequestService {
        return .init(
            fetchMethod: fetchMethod,
            insertMethod: insertMethod,
            updateMethod: updateMethod,
            deleteMethod: deleteMethod,
            provider: MoyaProvider<API>(),
            _setPlugins: { plugins in
                return MoyaProvider<API>(plugins: plugins)
            }
        )
    }
    
    static func mock(
        fetchMethod: @escaping (Int) -> API,
        insertMethod: ((Model) -> API)? = nil,
        updateMethod: ((Model) -> API)? = nil,
        deleteMethod: ((Int) -> API)? = nil
    ) -> PageRequestService {
        return .init(
            fetchMethod: fetchMethod,
            insertMethod: insertMethod,
            updateMethod: updateMethod,
            deleteMethod: deleteMethod,
            provider: MoyaProvider<API>(stubClosure: MoyaProvider.immediatelyStub),
            _setPlugins: { plugins in
                return MoyaProvider<API>(stubClosure: MoyaProvider.immediatelyStub, plugins: plugins)
            }
        )
    }
}
