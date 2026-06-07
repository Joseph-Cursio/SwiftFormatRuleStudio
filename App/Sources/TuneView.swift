//
//  TuneView.swift
//  SwiftFormatRuleStudio
//

import SwiftFormatRuleStudioCore
import SwiftUI

/// The marginal-impact scan (planned — docs/audit-redesign.md, layer C): try each
/// candidate config change one at a time — enable a disabled rule, or change an
/// enabled rule's option value — measure how much of the project it would touch,
/// and surface the zero-churn wins for one-click adoption. Placeholder for now.
struct TuneView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Tune your config", systemImage: "sparkles")
        } description: {
            Text("Find rules you can adopt with zero churn, and see what each "
                + "option value would change — coming soon.")
        }
        .navigationTitle("Tune")
    }
}
