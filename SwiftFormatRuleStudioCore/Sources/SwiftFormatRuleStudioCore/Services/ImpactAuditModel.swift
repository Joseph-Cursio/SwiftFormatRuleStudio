//
//  ImpactAuditModel.swift
//  SwiftFormatRuleStudio
//

import Foundation
import Observation

/// Observable model for the impact audit (M5): run `swiftformat --lint` over a
/// workspace and rank rules by how much code each would change.
///
/// In Core so the orchestration is unit-testable; the SwiftFormat heavy lifting
/// is offloaded to the `SwiftFormatCLIActor`.
@MainActor
@Observable
public final class ImpactAuditModel {
    /// Lifecycle of an audit run.
    public enum AuditState: Equatable, Sendable {
        case idle
        case running
        case completed
        case failed(String)
    }

    /// The current audit state.
    public private(set) var state: AuditState = .idle
    /// The most recent report, or `nil` until an audit completes.
    public private(set) var report: ImpactReport?
    /// The folder the report was produced from.
    public private(set) var auditedPath: URL?

    /// Swift version passed as `--swift-version` (rules vary by version).
    public var swiftVersion: String?
    /// Extra arguments — typically the active config's `commandLineArguments`.
    public var extraArguments: [String] = []

    private let cli: any SwiftFormatCLIProtocol

    /// Creates an audit model backed by the given CLI.
    public init(cli: any SwiftFormatCLIProtocol = SwiftFormatCLIActor(), swiftVersion: String? = "5.10") {
        self.cli = cli
        self.swiftVersion = swiftVersion
    }

    /// The arguments passed to `swiftformat <path>` for the audit.
    ///
    /// No `--quiet`: we want SwiftFormat's `N/M files require formatting` summary
    /// on stderr (for the files-checked count). The JSON reporter still writes the
    /// findings to stdout, so dropping `--quiet` doesn't affect parsing.
    var auditArguments: [String] {
        var arguments = ["--lint", "--reporter", "json"]
        if let swiftVersion, !swiftVersion.isEmpty {
            arguments += ["--swift-version", swiftVersion]
        }
        arguments += extraArguments
        return arguments
    }

    /// Runs the audit over `path`, populating `report` and `state`.
    public func runAudit(path: URL) async {
        state = .running
        auditedPath = path
        do {
            let result = try await cli.lint(path: path.path, arguments: auditArguments)
            let findings = LintReportParser.parse(result.reporterOutput)
            report = ImpactReport.from(
                findings: findings,
                filesChecked: Self.filesChecked(inSummary: result.summary)
            )
            state = .completed
        } catch {
            report = nil
            state = .failed(error.localizedDescription)
        }
    }

    /// Pulls the files-checked count from SwiftFormat's run summary, e.g.
    /// `"26/26 files require formatting, 3 files skipped."` → 26 (the denominator),
    /// or `"0/1 files require formatting."` → 1. `nil` when the line is absent.
    static func filesChecked(inSummary summary: String) -> Int? {
        guard let match = summary.firstMatch(of: /(\d+)\/(\d+) files? require/) else {
            return nil
        }
        return Int(match.output.2)
    }
}
