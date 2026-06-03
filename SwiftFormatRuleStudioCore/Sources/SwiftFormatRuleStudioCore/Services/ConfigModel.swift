//
//  ConfigModel.swift
//  SwiftFormatRuleStudio
//

import Foundation
import Observation
import LintStudioCore

/// Observable model for editing a `.swiftformat` file (M4): load, edit options
/// and rule overrides, preview the diff, and save atomically with a backup.
///
/// In Core so the load/edit/diff/save logic is unit-testable; the Options panel
/// is a thin binding.
@MainActor
@Observable
public final class ConfigModel {
    public private(set) var configPath: URL?
    /// The text last loaded from / saved to disk — the diff baseline.
    public private(set) var originalText: String = ""
    /// The working (possibly edited) config.
    public private(set) var config: SwiftFormatConfig = SwiftFormatConfig()
    public private(set) var lastError: String?

    public init() {}

    // MARK: - Load / save

    /// Loads the config at `url`. A missing/unreadable file yields an empty
    /// config rooted at `url` (so a first save creates it).
    public func load(from url: URL?) {
        configPath = url
        if let url, let text = try? String(contentsOf: url, encoding: .utf8) {
            originalText = text
            config = SwiftFormatConfig.parse(text)
        } else {
            originalText = ""
            config = SwiftFormatConfig()
        }
        lastError = nil
    }

    /// Atomically writes the config (creating a timestamped `.backup`), and
    /// resets the diff baseline. Returns `false` and sets `lastError` on failure.
    @discardableResult
    public func save() -> Bool {
        guard let configPath else {
            lastError = "No config file location is set."
            return false
        }
        do {
            let text = config.serialized()
            try SafeFileWriter.write(text, to: configPath, createBackup: true)
            originalText = text
            lastError = nil
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    /// Discards edits, reverting to the last loaded/saved text.
    public func revert() {
        config = SwiftFormatConfig.parse(originalText)
        lastError = nil
    }

    // MARK: - Derived state

    public var isDirty: Bool {
        config.serialized() != originalText
    }

    public var canSave: Bool {
        configPath != nil && isDirty
    }

    /// The pending change as a before/after diff for preview.
    public var diff: [PreviewDiffLine] {
        PreviewDiffLine.lines(from: UnifiedDiffEngine.computeDiff(before: originalText, after: config.serialized()))
    }

    /// CLI arguments representing the current (edited) config, for live preview.
    public var commandLineArguments: [String] {
        config.commandLineArguments
    }

    // MARK: - Editing

    public func setOption(key: String, value: String) {
        config.setOption(key: key, value: value)
    }

    public func removeOption(key: String) {
        config.removeOption(key: key)
    }

    /// Sets a rule's desired enabled state, keeping the config minimal: when the
    /// desired state equals the rule's default, the override is cleared instead
    /// of written.
    public func setRuleEnabled(_ name: String, enabled: Bool, isOptIn: Bool) {
        let defaultEnabled = !isOptIn
        if enabled == defaultEnabled {
            config.clearRuleOverride(name)
        } else if enabled {
            config.enableRule(name)
        } else {
            config.disableRule(name)
        }
    }

    /// The effective enabled state of a rule given its default and any override.
    public func isRuleEnabled(_ name: String, isOptIn: Bool) -> Bool {
        if config.disabledRules.contains(name) { return false }
        if config.enabledRules.contains(name) { return true }
        return !isOptIn
    }
}
