# SwiftFormatRuleStudio — Reference Manual

A complete reference for SwiftFormatRuleStudio: its requirements, the tabs and
their controls, rule categories and filters, the option model, built-in presets,
the `.swiftformat` file it reads and writes, export formats, and the underlying
`swiftformat` commands it runs.

For prose explanations see the [User's Guide](users-guide.md); for a guided
walkthrough see the [Tutorial](tutorial.md).

---

## 1. Requirements

| Requirement | Detail |
|---|---|
| Platform | macOS 14 (Sonoma) or later |
| External tool | `swiftformat` on `PATH` (`brew install swiftformat`) |
| Network | None — the app runs entirely locally |

The app does not bundle SwiftFormat. It detects the binary at launch by checking
the common Homebrew (Apple-silicon and Intel) and system install locations. The
detected version and rule count are shown in the status bar.

---

## 2. Tabs

| Tab | Purpose | Needs a project folder? |
|---|---|---|
| Rules | Browse, search, and read rules; toggle a rule in the active config | No (toggling writes to the config opened in the Config tab) |
| Live Preview | Reformat code in memory and view a colored diff | No |
| Config | Edit, preview, and save a project's `.swiftformat` | Yes |
| Audit | Rank rules by how much they'd change a project | Yes |

All tabs share one loaded catalog and one active configuration. Editing the
configuration in **Config** updates **Live Preview** and the next **Audit** run.

---

## 3. Rule browser (Rules tab)

### Filters

| Control | Values | Effect |
|---|---|---|
| Search field | free text | Filters rules by name |
| Availability | All · Default · Opt-in | Filters by default enablement |
| Category | All categories, or one category | Filters by app-assigned category |

`Default` shows rules SwiftFormat applies unless told otherwise. `Opt-in` shows
rules SwiftFormat marks `(disabled)` — off until explicitly enabled.

### Row markers

| Marker | Meaning |
|---|---|
| Dashed-circle icon | Opt-in rule (off by default) |
| "deprecated" label | Rule is deprecated in this SwiftFormat version |

### Detail pane

| Element | Source |
|---|---|
| Title + badges | Rule name; `Category`, `Opt-in`, `Deprecated` badges |
| Enabled in config | Toggle that adds/removes the rule in the active config |
| Description | SwiftFormat's `--ruleinfo` summary |
| Related options | Options that tune the rule |
| Example | Before/after diff from `--ruleinfo` (red = removed, green = added) |

---

## 4. Rule categories

SwiftFormat does not expose categories natively; the app assigns each rule to one
of the buckets below for sectioning and filtering.

| Category | Covers |
|---|---|
| **Spacing** | Whitespace, blank lines, and indentation |
| **Wrapping** | Line wrapping and brace placement |
| **Redundancy** | Removing redundant, unused, or unnecessary code |
| **Organization** | Sorting, marks, declaration order, access-control placement, hoisting |
| **Imports** | Import statements |
| **Comments** | Comments, doc comments, file headers, and TODOs |
| **Testing** | Test-specific rules |
| **Idiomatic** | Idiomatic syntax preferences that don't fit the buckets above |

---

## 5. Options (Config tab)

Each SwiftFormat option is rendered with a control chosen by its kind:

| Kind | Control | Notes |
|---|---|---|
| `boolean` | Switch | Stored as `true` / `false` |
| `enumeration` | Pop-up menu | Limited to the option's allowed values |
| `integer` | Text field | Numeric value |
| `list` | Text field | Comma-separated values |
| `string` | Text field | Free text; placeholder shows the default |

### Minimal-config behavior

Setting an option to its default value **removes** it from `.swiftformat`. The
written file therefore contains only deviations from SwiftFormat's defaults.

---

## 6. Built-in presets

Applied from the **Presets** menu in the Config tab. A preset replaces the
current configuration with its starter content.

| Preset | Summary | Contents |
|---|---|---|
| **Standard** | SwiftFormat's defaults with 4-space indentation | `--swift-version 5.10`, `--indent 4` |
| **Compact** | 2-space indentation | `--swift-version 5.10`, `--indent 2` |
| **Opinionated** | Defaults plus selected opt-in rules and explicit-self removal | `--swift-version 5.10`, `--indent 4`, `--self remove`, `--enable isEmpty,organizeDeclarations,blankLineAfterSwitchCase,wrapEnumCases` |

---

## 7. The `.swiftformat` file

SwiftFormat configuration is a flat list of command-line arguments, one per line,
read from a `.swiftformat` file at the project root. The app reads and writes this
format directly.

```
# Comments begin with '#'
--swift-version 5.10
--indent 4
--self remove
--enable isEmpty,organizeDeclarations
--disable redundantReturn
```

| Directive | Meaning |
|---|---|
| `--<option> <value>` | Set a formatting option |
| `--enable <rule>[,<rule>…]` | Turn on opt-in rules |
| `--disable <rule>[,<rule>…]` | Turn off default rules |
| `# …` | Comment |

### Saving

- **Atomic** — the file is written in full or not at all.
- **Backed up** — the previous version is preserved before overwrite.
- **Shortcut** — ⌘S saves; **Revert** reloads from disk and discards edits.

> **Set `--swift-version`.** Without it, SwiftFormat conservatively disables some
> rules, which makes Live Preview and Audit under-report changes.

---

## 8. Audit report

| Field | Meaning |
|---|---|
| rules | Number of rules with at least one finding |
| files affected | Number of distinct files that would change |
| findings | Total number of individual findings |
| Per-rule impact | Each rule's file count and finding count, ranked and bar-charted by file count |

A project with no findings reports **Already formatted**.

### Export formats

| Format | Extension | Use |
|---|---|---|
| CSV | `.csv` | Import into a spreadsheet |
| HTML | `.html` | Styled, shareable report |

Default export filename: `swiftformat-impact`.

---

## 9. Underlying `swiftformat` commands

The app is a thin UI over these commands. Knowing them helps when reproducing a
result in a terminal or a CI script.

| App feature | Command |
|---|---|
| Detect version (status bar) | `swiftformat --version` |
| Load rule list | `swiftformat --rules` |
| Load a rule's description + example | `swiftformat --ruleinfo <rule>` |
| Load option catalog | `swiftformat --options` |
| Live Preview | `swiftformat stdin <config args>` (source piped to stdin) |
| Audit | `swiftformat <path> --lint --reporter json <config args>` |
| (CLI equivalent) count files that would change | `swiftformat <path> --dryrun` |

`<config args>` are the arguments derived from the active configuration, so the
preview and audit reflect exactly what you've set in the Config tab.

### Exit-code handling

SwiftFormat's `--lint` mode exits `1` when it finds issues, which the app treats
as a successful run with findings (not an error). This is configured through the
shared CLI runner's per-tool success exit codes (`[0, 1]` for SwiftFormat).

---

## 10. Keyboard shortcuts

| Shortcut | Action | Where |
|---|---|---|
| ⌘S | Save configuration | Config tab |

---

## 11. Architecture note

The app's logic lives in the `SwiftFormatRuleStudioCore` Swift package (catalog
loading, parsing, config engine, audit, export), which is independently testable
via `swift test`. The SwiftUI views are thin bindings over that package. CLI
execution (path detection, run/capture, timeout, exit-code policy) is provided by
the shared **LintStudioUI** package's `CLIToolActor`. See
[`implementation-plan.md`](implementation-plan.md) and
[`shared-package-extraction.md`](shared-package-extraction.md) for the full design.

---

## See also

- [User's Guide](users-guide.md)
- [Tutorial](tutorial.md)
