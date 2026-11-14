import Dependencies
import OfflineSyncCore
import OfflineSyncServices
import Moya

import KimaiCore

extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var addedDict = [Element: Bool]()

        return filter {
            addedDict.updateValue(true, forKey: $0) == nil
        }
    }

    func removeDuplicates() -> Self {
        return self.removingDuplicates()
    }
}

public struct KimaiCustomerService {
    var customerRepository: DatabaseRepository<KimaiCustomer>
    var teamRepository: DatabaseRepository<KimaiTeam>
    
    var requestService: any RequestServiceProtocol<KimaiCustomerDTO>
    var customerSyncService: SyncService<KimaiCustomer>
    
    public init(
        customerRepository: DatabaseRepository<KimaiCustomer>,
        teamRepository: DatabaseRepository<KimaiTeam>,
        requestService: any RequestServiceProtocol<KimaiCustomerDTO>
    ) {
        self.customerRepository = customerRepository
        self.teamRepository = teamRepository
        self.requestService = requestService
        
        self.customerSyncService = .init(
            repository: customerRepository,
            remoteInsert: { try await requestService.insert( KimaiCustomerDTO(from: $0) ).toModel() },
            remoteUpdate: { try await requestService.update( KimaiCustomerDTO(from: $0) ).toModel() },
            remoteDelete: nil
        )
    }
    
    public func getCustomers() throws -> [KimaiCustomer] {
        return try customerRepository.get()
    }
    public func getCustomer(_ id: Int) throws -> KimaiCustomer? { try customerRepository.get(by: id) }

    public func getTeams() throws -> [KimaiTeam] {
        return try teamRepository.get()
    }
    
    public func createCustomer(_ model: KimaiCustomer) throws {
        try customerRepository.create(model)
    }
    
    public func updateCustomer(_ model: KimaiCustomer) throws {
        try customerRepository.update(model, isTrack: true)
    }
    
    public func deleteCustomer(_ id: Int) throws {
        try customerRepository.delete(id, isTrack: true)
    }
    
    public func fetch() async throws -> ([KimaiCustomer], [KimaiTeam]) {
        let records = try await requestService.fetch()
        
        let customers = records.map { $0.toModel() }
        let teams = records.flatMap {$0.teams}.removeDuplicates()
        
        return (customers, teams)
    }
    
    public func sync() async throws -> ([KimaiCustomer], [KimaiTeam]) {
        let session = try SyncSession(connection: customerRepository.connection())
        let (remoteCustomers, remoteTeams) = try await fetch()
        try session.check()
        let syncedCustomers = try await customerSyncService.sync(remoteRecords: remoteCustomers, session: session)
        try session.check()
        try teamRepository.replaceSnapshot(remoteTeams, on: session.connection)
        return (syncedCustomers, remoteTeams)
    }
    
    public func getCustomerChanges() throws -> [DatabaseChange] {
        return try customerRepository.getChanges()
    }
    
    public func setPlugins(_ plugins: [PluginType]) {
        requestService.setPlugins(plugins)
    }
    
    
}

public extension KimaiCustomerService {
    static var live: Self {
        return .init(
            customerRepository: .init("kimai_customers"),
            teamRepository: .init("kimai_teams"),
            requestService: RequestService.live(
                fetchMethod: {KimaiAPI.getCustomers},
                insertMethod: KimaiAPI.insertCustomer,
                updateMethod: KimaiAPI.updateCustomer
            )
        )
    }
    
    static var mock: Self {
        return .init(
            customerRepository: .init("kimai_customers"),
            teamRepository: .init("kimai_teams"),
            requestService: RequestService.mock(
                fetchMethod: {KimaiAPI.getCustomers},
                insertMethod: KimaiAPI.insertCustomer,
                updateMethod: KimaiAPI.updateCustomer
            )
        )
    }
}
