//
//  TextSizeStepTests.swift
//  SwiftFormatRuleStudioTests
//

@testable import SwiftFormatRuleStudio
import SwiftUI
import Testing

/// The arithmetic that was inside three menu-command closures.
///
/// `Unreachable Effect Closure` reported the closures; each carried its own copy of the clamp and
/// none stated what the clamp guarantees. These are the statements that could not be made before.
@Suite("Text-size step")
struct TextSizeStepTests {
    @Test("Stepping stays inside the range for every input", arguments: [-100, -4, -3, 0, 5, 6, 7, 100])
    func steppingIsTotal(start: Int) {
        for delta in [-2, -1, 0, 1, 2] {
            let result = TextSizeStep.stepping(start, by: delta)
            #expect(TextSizeStep.range.contains(result))
        }
    }

    @Test("Stepping up from the ceiling is the ceiling")
    func idempotentAtTheCeiling() {
        let ceiling = TextSizeStep.range.upperBound
        #expect(TextSizeStep.stepping(ceiling, by: 1) == ceiling)
        #expect(TextSizeStep.stepping(ceiling, by: 99) == ceiling)
    }

    @Test("Stepping down from the floor is the floor")
    func idempotentAtTheFloor() {
        let floor = TextSizeStep.range.lowerBound
        #expect(TextSizeStep.stepping(floor, by: -1) == floor)
        #expect(TextSizeStep.stepping(floor, by: -99) == floor)
    }

    @Test("Inside the range, stepping is exactly addition")
    func additionInsideTheRange() {
        #expect(TextSizeStep.stepping(0, by: 1) == 1)
        #expect(TextSizeStep.stepping(0, by: -1) == -1)
        #expect(TextSizeStep.stepping(2, by: 3) == 5)
    }

    @Test("Stepping is monotonic in the current step")
    func monotonic() {
        for step in TextSizeStep.range.dropLast() {
            #expect(TextSizeStep.stepping(step, by: 1) >= TextSizeStep.stepping(step, by: 0))
        }
    }

    @Test("Actual size is inside the range and maps to 100%")
    func actualSizeIsUnitScale() {
        #expect(TextSizeStep.range.contains(TextSizeStep.actualSize))
        #expect(CGFloat.uiTextScale(forStep: TextSizeStep.actualSize) == 1.0)
    }

    @Test("The scale clamp never fires for a step the menu can produce")
    func theSecondClampIsDead() {
        // Two clamps existed and only one was live. `uiTextScale` clamps to 0.6…2.0; the widest
        // scale `TextSizeStep.range` can ask for is 0.64…1.72. Nothing said so until now, and a
        // later widening of `range` would silently start engaging the other clamp.
        for step in TextSizeStep.range {
            let scale = CGFloat.uiTextScale(forStep: step)
            let unclamped = 1.0 + CGFloat(step) * 0.12
            #expect(scale == unclamped)
        }
    }
}
