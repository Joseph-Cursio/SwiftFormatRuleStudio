//
//  ScopedFolder.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// A bookmark resolved back into a usable folder.
nonisolated struct ResolvedBookmark: Sendable {
    let url: URL
    /// macOS wants the bookmark rewritten (the folder moved, or the OS changed its
    /// encoding). Access still works; the stored data should be refreshed.
    let isStale: Bool
}

/// Creating and resolving the security-scoped bookmark that lets the app reopen a
/// project across launches.
///
/// Injected because the real APIs only mean anything inside a signed, sandboxed
/// process — unsandboxed, and in tests, they succeed without proving anything. Tests
/// assert the *decisions* (offer Reopen or not, release the old folder, persist or
/// drop the bookmark) against an in-memory conformer; the round trip itself is checked
/// by hand. See `docs/sandbox-bookmarks-scope.md` §6.
nonisolated protocol BookmarkStoring: Sendable {
    /// Bookmark data for `url`, or `nil` when one can't be made — which is what
    /// happens if access to `url` isn't currently held.
    func bookmark(for url: URL) -> Data?
    /// Resolves `data` and *starts* scoped access, or `nil` if either step fails.
    /// A successful resolve must be balanced by ``release(_:)``.
    func resolve(_ data: Data) -> ResolvedBookmark?
    /// Starts scoped access for a URL that came from the file picker. Must be
    /// balanced by ``release(_:)``.
    func startAccess(_ url: URL) -> Bool
    /// Ends the access a successful ``resolve(_:)`` started.
    func release(_ url: URL)
}

/// The production store, over Foundation's security-scoped bookmark API.
nonisolated struct SecurityScopedBookmarkStore: BookmarkStoring {
    func bookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    func resolve(_ data: Data) -> ResolvedBookmark? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            // A deleted folder throws here rather than reporting staleness, so this
            // is also the "is the remembered project still there?" test.
            return nil
        }
        guard url.startAccessingSecurityScopedResource() else { return nil }
        return ResolvedBookmark(url: url, isStale: isStale)
    }

    func startAccess(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func release(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

/// Holds a project folder open for as long as the app is working in it.
///
/// Sandboxed, access ends the instant the scope is released — the same directory
/// listing that worked a line earlier throws. So this is not bookkeeping: whoever owns
/// the folder owns the ability to read it, and must outlive every tab that reads a
/// file. `WorkspaceModel` is that owner.
///
/// Both initializers start scoped access and must be balanced by ``release()``.
///
/// That is *not* optional for the picked-folder case, however much it looks like it:
/// SwiftUI's `.fileImporter` hands back a security-scoped URL that grants nothing until
/// it is started — unlike `NSOpenPanel`, whose URLs are usable immediately. Reads
/// happen to work either way; the write of `.swiftformat` is what fails, and it fails
/// with a permission error naming the project folder. See
/// `docs/sandbox-bookmarks-scope.md` §2.
@MainActor
final class ScopedFolder {
    let url: URL
    /// Bookmark data to persist, or `nil` if one couldn't be made.
    let bookmark: Data?

    private let store: any BookmarkStoring
    private let startedAccess: Bool
    private var isReleased = false

    /// A folder the user just chose in the file picker. Takes scoped access and
    /// records a bookmark so the next launch can get back in without asking.
    init(granting url: URL, store: any BookmarkStoring) {
        self.url = url
        self.store = store
        self.startedAccess = store.startAccess(url)
        // Bookmarked *after* access is held: without it, creation fails.
        self.bookmark = store.bookmark(for: url)
    }

    /// A folder recovered from stored bookmark data. `nil` when it can't be resolved
    /// or access can't be started — the folder was moved, deleted, or never granted.
    init?(resolving data: Data, store: any BookmarkStoring) {
        guard let resolved = store.resolve(data) else { return nil }
        self.url = resolved.url
        self.store = store
        self.startedAccess = true
        // Refresh the stored data when macOS says it's stale; otherwise keep what we
        // already have rather than rewriting defaults on every launch.
        self.bookmark = resolved.isStale ? store.bookmark(for: resolved.url) : nil
    }

    /// Ends scoped access, if this folder started any. Idempotent.
    ///
    /// There's deliberately no `deinit` doing this: process exit releases everything,
    /// and an explicit call is the thing tests can observe.
    func release() {
        guard startedAccess, !isReleased else { return }
        isReleased = true
        store.release(url)
    }
}
