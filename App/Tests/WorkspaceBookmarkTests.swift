//
//  WorkspaceBookmarkTests.swift
//  SwiftFormatRuleStudioTests
//

import Foundation
@testable import SwiftFormatRuleStudio
import Testing

/// An in-memory `BookmarkStoring` that records what was asked of it.
///
/// The real API only means anything inside a signed, sandboxed process, so these
/// tests assert the *decisions* — whether Reopen is offered, whether the previous
/// folder's access was released, whether a bookmark was persisted — and leave the
/// round trip itself to the manual check in `docs/sandbox-bookmarks-scope.md` §6.
final class MockBookmarkStore: BookmarkStoring, @unchecked Sendable {
    /// Bookmark data to hand back, or `nil` to simulate a folder we can't bookmark
    /// (what happens when access isn't held).
    var bookmarkToReturn: Data?
    /// What `resolve` should produce, or `nil` for a folder that's gone.
    var resolution: ResolvedBookmark?

    private(set) var startedURLs: [URL] = []
    private(set) var bookmarkedURLs: [URL] = []
    private(set) var resolvedCount = 0
    private(set) var releasedURLs: [URL] = []

    init(bookmarkToReturn: Data? = Data("bookmark".utf8), resolution: ResolvedBookmark? = nil) {
        self.bookmarkToReturn = bookmarkToReturn
        self.resolution = resolution
    }

    func bookmark(for url: URL) -> Data? {
        bookmarkedURLs.append(url)
        return bookmarkToReturn
    }

    func startAccess(_ url: URL) -> Bool {
        startedURLs.append(url)
        return true
    }

    func resolve(_: Data) -> ResolvedBookmark? {
        resolvedCount += 1
        return resolution
    }

    func release(_ url: URL) {
        releasedURLs.append(url)
    }
}

@Suite("WorkspaceModel bookmarks")
@MainActor
struct WorkspaceBookmarkTests {
    private static let bookmarkKey = "lastProjectFolderBookmark"
    private static let legacyKey = "lastProjectFolderPath"
    private let folder = URL(fileURLWithPath: "/proj", isDirectory: true)
    private let other = URL(fileURLWithPath: "/other", isDirectory: true)

    private func defaults() -> UserDefaults {
        WorkspaceModelTests.scratchDefaults()
    }

    @Test("With no stored bookmark there is nothing to reopen")
    func noBookmarkNoReopen() {
        let store = MockBookmarkStore()
        let workspace = WorkspaceModel(bookmarks: store, defaults: defaults())
        #expect(workspace.lastFolder == nil)
        #expect(store.resolvedCount == 0)
    }

    @Test("A bookmark that resolves is what makes Reopen available")
    func resolvedBookmarkOffersReopen() {
        let store = MockBookmarkStore(resolution: ResolvedBookmark(url: folder, isStale: false))
        let suite = defaults()
        suite.set(Data("stored".utf8), forKey: Self.bookmarkKey)

        let workspace = WorkspaceModel(bookmarks: store, defaults: suite)
        #expect(workspace.lastFolder == folder)
        #expect(store.resolvedCount == 1)
    }

    @Test("A bookmark that no longer resolves offers nothing")
    func unresolvableBookmarkOffersNothing() {
        // The folder was moved or deleted: resolution throws rather than reporting
        // staleness, and `fileExists` would still say true. See §1 of the scope doc.
        let store = MockBookmarkStore(resolution: nil)
        let suite = defaults()
        suite.set(Data("stored".utf8), forKey: Self.bookmarkKey)

        let workspace = WorkspaceModel(bookmarks: store, defaults: suite)
        #expect(workspace.lastFolder == nil)
    }

    @Test("Stale bookmark data is refreshed at launch")
    func staleBookmarkIsRewritten() {
        let store = MockBookmarkStore(
            bookmarkToReturn: Data("fresh".utf8),
            resolution: ResolvedBookmark(url: folder, isStale: true)
        )
        let suite = defaults()
        suite.set(Data("stale".utf8), forKey: Self.bookmarkKey)

        _ = WorkspaceModel(bookmarks: store, defaults: suite)
        #expect(suite.data(forKey: Self.bookmarkKey) == Data("fresh".utf8))
    }

    @Test("Opening a picked folder persists its bookmark")
    func openPersistsBookmark() {
        let store = MockBookmarkStore(bookmarkToReturn: Data("new".utf8))
        let suite = defaults()
        let workspace = WorkspaceModel(bookmarks: store, defaults: suite)

        workspace.open(folder)

        #expect(workspace.selectedFolder == folder)
        #expect(workspace.hasCompletedStartup)
        #expect(store.startedURLs == [folder])
        #expect(store.bookmarkedURLs == [folder])
        #expect(suite.data(forKey: Self.bookmarkKey) == Data("new".utf8))
    }

    @Test("A folder we can't bookmark leaves no Reopen for next launch")
    func unbookmarkableFolderClearsStoredData() {
        let store = MockBookmarkStore(bookmarkToReturn: nil)
        let suite = defaults()
        suite.set(Data("previous".utf8), forKey: Self.bookmarkKey)
        let workspace = WorkspaceModel(bookmarks: store, defaults: suite)

        workspace.open(folder)

        // Offering Reopen for a folder we failed to bookmark is a button that fails.
        #expect(suite.data(forKey: Self.bookmarkKey) == nil)
        #expect(workspace.selectedFolder == folder)
    }

    @Test("Reopening the remembered folder keeps the access its bookmark granted")
    func reopeningRememberedKeepsAccess() {
        let store = MockBookmarkStore(resolution: ResolvedBookmark(url: folder, isStale: false))
        let suite = defaults()
        suite.set(Data("stored".utf8), forKey: Self.bookmarkKey)
        let workspace = WorkspaceModel(bookmarks: store, defaults: suite)

        workspace.open(folder)

        // Releasing here would revoke the access and replace it with a grant this
        // launch never received — the folder would go unreadable mid-session.
        #expect(store.releasedURLs.isEmpty)
        // And it doesn't re-bookmark what it already has.
        #expect(store.bookmarkedURLs.isEmpty)
        #expect(workspace.selectedFolder == folder)
    }

    @Test("Every scope taken is released exactly once as folders change")
    func scopesAreBalanced() {
        let store = MockBookmarkStore(resolution: ResolvedBookmark(url: folder, isStale: false))
        let suite = defaults()
        suite.set(Data("stored".utf8), forKey: Self.bookmarkKey)
        let workspace = WorkspaceModel(bookmarks: store, defaults: suite)

        workspace.open(other)
        workspace.open(other)

        // Launch resolved `folder` (one scope); each open of `other` takes another and
        // hands the previous one back. Starts and releases must stay paired — an
        // unbalanced start leaks a sandbox extension.
        #expect(store.startedURLs == [other, other])
        #expect(store.releasedURLs == [folder, other])
        #expect(store.releasedURLs.filter { $0 == folder }.count == 1)
        #expect(workspace.selectedFolder == other)
    }

    @Test("A path remembered by a pre-sandbox build is dropped")
    func legacyPathIsDropped() {
        let suite = defaults()
        suite.set("/old/project", forKey: Self.legacyKey)

        let workspace = WorkspaceModel(bookmarks: MockBookmarkStore(), defaults: suite)

        // It can't be upgraded — bookmarking needs access we no longer have — so the
        // user re-picks once rather than being offered a Reopen that fails.
        #expect(suite.string(forKey: Self.legacyKey) == nil)
        #expect(workspace.lastFolder == nil)
    }
}
