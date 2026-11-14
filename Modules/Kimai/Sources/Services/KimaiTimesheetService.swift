import Dependencies
import Moya
import OfflineSyncServices
import KimaiCore

struct KimaiTimesheetService {
    static var live: RecordService<KimaiTimesheet> {
        TimesheetSyncService(repository: .init("kimai_timesheets"), pages: .live(
            fetchMethod: { KimaiAPI.getTimesheets($0) },
            insertMethod: KimaiAPI.insertTimesheet,
            updateMethod: KimaiAPI.updateTimesheet,
            deleteMethod: KimaiAPI.deleteTimesheet
        ))
    }

    static var mock: RecordService<KimaiTimesheet> {
        TimesheetSyncService(repository: .init("kimai_timesheets"), pages: .mock(
            fetchMethod: { KimaiAPI.getTimesheets($0) },
            insertMethod: KimaiAPI.insertTimesheet,
            updateMethod: KimaiAPI.updateTimesheet,
            deleteMethod: KimaiAPI.deleteTimesheet
        ))
    }
}
