import XCTest

// Run serially: the pinned Dependencies library has process-global mutable storage.
final class SyncRegressionTests: XCTestCase {
    private var sync: SyncRegressionDriver!

    override func setUpWithError() throws {
        sync = try SyncRegressionDriver(testCase: self)
    }

    override func tearDownWithError() throws {
        try sync?.close()
        sync = nil
    }

    func testReferenceCollectionsFetchConcurrentlyAndUploadsRemainOrdered() async throws {
        try await sync.synchronizeReferenceCollections()

        sync.shouldHaveOrderedReferenceUploads()
        sync.shouldHaveRemappedRelationshipChain()
    }

    func testEditDuringConcurrentReferenceFetchIsUploadedWithoutLoss() async throws {
        try await sync.editProjectDuringReferenceFetch()

        sync.shouldHaveUploadedLatestReferenceEdit()
        sync.shouldHaveRemappedRelationshipChain()
    }

    func testFailedReferenceFetchCancelsSiblingsWithoutAcknowledgingChanges() async throws {
        try await sync.rejectReferenceFetch()

        sync.shouldHaveUnchangedReferenceChanges()
    }

    func testAccountSwitchDuringReferenceFetchCannotApplySnapshots() async throws {
        try await sync.switchAccountDuringReferenceFetch()

        sync.shouldHaveUnchangedReferenceChanges()
    }

    func testInvalidatedReferenceFetchCancelsAllRequests() async throws {
        try await sync.cancelReferenceFetch()

        sync.shouldHaveUnchangedReferenceChanges()
    }

    func testFailedFetchPreservesCachedRecordsAndPendingEdits() async throws {
        try sync.cacheRecord(1, named: "cached")
        try sync.cacheRecord(2, named: "original")
        try sync.editRecord(2, named: "offline edit")
        sync.failNextFetch()

        await sync.shouldRejectSync()

        sync.shouldHaveRecord(1, named: "cached")
        sync.shouldHaveRecord(2, named: "offline edit")
        sync.shouldHavePendingUpdate(2)
        sync.shouldHaveUploadedNothing()
    }

    func testLaterPageFailureDoesNotReconcilePartialSnapshot() async throws {
        try sync.cacheRecord(99, named: "last page cached")
        sync.usePaginatedRemote(totalPages: "2", failSecondPage: true)

        await sync.shouldRejectSync()

        sync.shouldHaveRecord(99, named: "last page cached")
        sync.shouldHaveRequestedPages([1, 2])
    }

    func testMissingPaginationMetadataDoesNotAuthorizeDeletion() async throws {
        try sync.cacheRecord(99, named: "unseen cached")
        sync.usePaginatedRemote(totalPages: nil)

        await sync.shouldRejectSync()

        sync.shouldHaveRecord(99, named: "unseen cached")
    }

    func testMalformedPaginationMetadataDoesNotAuthorizeDeletion() async throws {
        try sync.cacheRecord(99, named: "unseen cached")
        sync.usePaginatedRemote(totalPages: "not-a-number")

        await sync.shouldRejectSync()

        sync.shouldHaveRecord(99, named: "unseen cached")
    }

    func testHTTPErrorWithDecodableBodyCannotReconcile() async throws {
        try sync.cacheRecord(99, named: "cached")
        sync.usePaginatedRemote(totalPages: "1", status: 401)

        await sync.shouldRejectSync()

        sync.shouldHaveRecord(99, named: "cached")
    }

    func testPaginationUsesBoundedConcurrencyAndStableResultOrder() async throws {
        sync.usePaginatedRemote(totalPages: "8", delayed: true)

        try await sync.synchronize()

        sync.shouldHaveBoundedConcurrentPageRequests()
        sync.shouldHaveRequestedAllPages(8)
    }

    func testTimesheetQueryUsesPageSizeOrderAndUTCCheckpoint() {
        sync.shouldSendBoundedIncrementalQuery()
    }

    func testAuthenticationAndOriginStayBoundToTheirAccount() {
        sync.shouldKeepRequestBoundToAccount()
    }

    func testExistingAccountDatabaseCannotBeReboundToAnotherServer() throws {
        try sync.shouldRejectDifferentServerForAccountDatabase()
    }

    func testOldSyncCompletionCannotReplaceNewAccountState() {
        sync.shouldIgnoreStaleCompletion()
    }

    func testOverlappingWholeAppSyncIsRejected() async throws {
        try await sync.shouldRejectOverlappingAppSyncs()
    }

    func testInvalidatedAppSyncCannotContinueIntoNextStage() async throws {
        try await sync.shouldCancelInvalidatedAppSync()
    }

    func testTimesheetCheckpointPersistsAndFetchesOnlyChangesAfterReopen() async throws {
        sync.useIncrementalTimesheetRemote()
        try await sync.synchronizeIncrementalTimesheets()
        try await sync.synchronizeIncrementalTimesheets()
        try sync.reopenCurrentAccount()
        sync.recreateIncrementalTimesheetService()

        try await sync.synchronizeIncrementalTimesheets()

        sync.shouldHaveUsedIncrementalCheckpoint()
        sync.shouldHaveRetainedHistoryAndMergedDelta()
    }

    func testFailedDeltaDoesNotAdvanceCheckpoint() async throws {
        sync.useIncrementalTimesheetRemote(failThird: true)
        try await sync.synchronizeIncrementalTimesheets()
        try await sync.synchronizeIncrementalTimesheets()
        await sync.shouldRejectIncrementalSync()

        try await sync.synchronizeIncrementalTimesheets()

        sync.shouldHaveRetriedSameCheckpoint()
        sync.shouldHaveRetainedHistoryAndMergedDelta()
    }

    func testServerClockRollbackForcesFullTimesheetRefresh() async throws {
        sync.useIncrementalTimesheetRemote(rollbackThird: true)
        try await sync.synchronizeIncrementalTimesheets()
        try await sync.synchronizeIncrementalTimesheets()

        try await sync.synchronizeIncrementalTimesheets()

        sync.shouldHaveRefetchedAfterClockRollback()
        sync.shouldHaveRetainedHistoryAndMergedDelta()
    }

    func testEmptyZeroPageSnapshotIsValidButCannotDeleteCache() async throws {
        try sync.cacheRecord(99, named: "cached")
        sync.usePaginatedRemote(totalPages: "0", empty: true)

        try await sync.synchronize()

        sync.shouldHaveRecord(99, named: "cached")
    }

    func testIncrementalTimesheetsPeriodicallyRefreshFullHistory() async throws {
        sync.useIncrementalTimesheetRemote()

        try await sync.repeatIncrementalSync(22)

        sync.shouldPeriodicallyRefreshFullHistory()
    }

    func testCompletePaginationPersistsEveryPage() async throws {
        sync.usePaginatedRemote(totalPages: "2")

        try await sync.synchronize()

        sync.shouldHaveRecord(1, named: "page 1")
        sync.shouldHaveRecord(2, named: "page 2")
        sync.shouldHaveRequestedPages([1, 2])
    }

    func testEditDuringUploadSurvivesOlderAcknowledgement() async throws {
        try sync.cacheRecord(1, named: "original")
        try sync.editRecord(1, named: "first edit")
        sync.editAgainDuringUpload(1, named: "newer edit")

        try await sync.synchronize()

        sync.shouldHaveRecord(1, named: "newer edit")
        sync.shouldHavePendingUpdate(1)
    }

    func testLocalAndRemoteIDCollisionKeepsBothRecords() async throws {
        try sync.createRecord(named: "offline create")
        sync.addRemoteRecord(1, named: "other device create")
        sync.assignNextServerID(10)

        try await sync.synchronize()

        sync.shouldHaveRecord(1, named: "other device create")
        sync.shouldHaveRecord(10, named: "offline create")
        sync.shouldHaveNoPendingChanges()
    }

    func testParentServerIDIsUsedForChildUploadAndPersistence() async throws {
        try sync.createRelatedOfflineRecords()

        try await sync.synchronizeRelatedRecords()

        sync.shouldHaveUploadedChildWithParent(101)
        sync.shouldHavePersistedChildWithParent(101)
    }

    func testCustomerTeamsRemainAvailableOfflineAfterReopen() async throws {
        sync.prepareCustomerWithTeam()
        try await sync.synchronizeCustomerTeams()
        try sync.reopenCurrentAccount()

        sync.shouldHavePersistedCustomerTeam()
    }

    func testFullRelationshipChainIsRemappedBeforeUpload() async throws {
        try sync.createRelatedOfflineRecords()

        try await sync.synchronizeRelatedRecords()

        sync.shouldHaveRemappedRelationshipChain()
    }

    func testHideUsingPreUploadProjectIdentityQueuesVisibilityUpdate() async throws {
        try sync.createRelatedOfflineRecords()
        try await sync.synchronizeRelatedRecords()

        try sync.hideProjectUsingPreUploadIdentity()

        sync.shouldHaveHiddenAcknowledgedProject()
    }

    func testStaleCustomerSelectionIsResolvedForNewOfflineProject() async throws {
        try sync.createRelatedOfflineRecords()
        try await sync.synchronizeRelatedRecords()

        try sync.createProjectUsingPreUploadCustomerIdentity()

        sync.shouldHaveResolvedNewProjectRelationship()
    }

    func testProjectHideAndActivityRelationshipReachRequestPayload() {
        sync.shouldSendVisibilityAndActivityRelationship()
    }

    func testInterruptedUploadDoesNotRepeatAcknowledgedCreateAfterReopen() async throws {
        try sync.createRecord(named: "first create")
        try sync.createRecord(named: "second create")
        sync.failSecondUploadOnce()

        await sync.shouldRejectSync()
        try sync.reopenCurrentAccount()
        try await sync.synchronize()

        sync.shouldHaveCreatedExactlyOnce("first create")
        sync.shouldHaveCreatedExactlyOnce("second create")
        sync.shouldHaveNoPendingChanges()
    }

    func testFailedLocalMergeDoesNotAcknowledgePendingEdit() async throws {
        try sync.cacheRecord(1, named: "original")
        try sync.editRecord(1, named: "offline edit")
        try sync.rejectRecordUpdates()

        await sync.shouldRejectSync()

        sync.shouldHaveRecord(1, named: "offline edit")
        sync.shouldHavePendingUpdate(1)
    }

    func testRecordAndPendingOperationAreAtomicOnDatabaseFailure() throws {
        try sync.rejectPendingOperationWrites()

        sync.shouldRejectCreate(named: "must not become untracked")

        try sync.shouldHaveNoUntrackedLocalCreate()
    }

    func testAccountSwitchDuringFetchCannotWriteIntoNewAccount() async throws {
        try sync.cacheRecord(1, named: "account A")
        sync.switchAccount(to: "b")
        try sync.cacheRecord(1, named: "account B")
        sync.switchAccount(to: "a")
        sync.switchToAccountDuringFetch("b")

        await sync.finishSyncAllowingCancellation()

        sync.shouldHaveRecord(1, named: "account B")
        sync.switchAccount(to: "a")
        sync.shouldHaveRecord(1, named: "account A")
    }

    func testAccountCachesRemainSeparateAcrossSwitchAndReopen() throws {
        try sync.cacheRecord(1, named: "account A")
        sync.switchAccount(to: "b")
        try sync.cacheRecord(1, named: "account B")
        try sync.reopenCurrentAccount()

        sync.shouldHaveRecord(1, named: "account B")
        sync.switchAccount(to: "a")
        sync.shouldHaveRecord(1, named: "account A")
    }
}
