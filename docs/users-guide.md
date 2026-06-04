# SwiftFormatRuleStudio — User's Guide

SwiftFormatRuleStudio is a macOS app for exploring and configuring
[SwiftFormat](https://github.com/nicklockwood/SwiftFormat). It lets you browse
every rule with a real before/after example, edit a project's `.swiftformat`
configuration with live feedback, paste code and watch it reformat as you type,
and audit a whole project to see which rules would change the most code.

This guide explains each part of the app. If you're opening it for the first
time, start with the [Tutorial](tutorial.md); for an exhaustive list of options,
categories, and command mappings, see the [Reference Manual](reference-manual.md).

---

## Before you start

The app is a front end for the `swiftformat` command-line tool — it does not
bundle its own copy. You need SwiftFormat installed and on your `PATH`:

```bash
brew install swiftformat
```

The app looks for `swiftformat` in the usual Homebrew and system locations. If it
can't find it, the status bar at the bottom of the window shows an install hint
and the rule list stays empty.

---

## The window at a glance

The app is organized into four tabs, with a status bar pinned along the bottom:

| Tab | Icon | What it's for |
|---|---|---|
| **Rules** | list | Browse and search every SwiftFormat rule; read what it does; see a before/after example; toggle it in your config. |
| **Live Preview** | wand | Type or paste Swift and watch it reformat live as a colored diff. |
| **Config** | sliders | Open a project's `.swiftformat`, edit options, preview the pending diff, and save. |
| **Audit** | bar chart | Run SwiftFormat across a folder and rank rules by how much they'd change. |

All four tabs share the same loaded rule catalog and the same edited
configuration, so a change you make in **Config** is immediately reflected in
**Live Preview** and **Audit**.

### The status bar

The bottom bar tells you the state of the catalog:

- **Loading rules…** — the app is querying `swiftformat` at launch.
- **SwiftFormat _x.y.z_ · _N_ rules** — loaded successfully; shows the detected
  version and rule count.
- **SwiftFormat not found — install with: brew install swiftformat** — the binary
  couldn't be located.

---

## The Rules tab

The Rules tab is a two-pane browser: a list of rules on the left, details on the
right.

### Finding a rule

- **Search** — type in the search field to filter rules by name.
- **Availability filter** — the segmented control at the top of the list narrows
  to **All**, **Default** (rules on by default), or **Opt-in** (rules SwiftFormat
  leaves off until you enable them).
- **Category filter** — pick a single category (Spacing, Wrapping, Redundancy,
  Organization, Imports, Comments, Testing, Idiomatic) or **All categories**.
  These categories are an app convenience — SwiftFormat itself doesn't group its
  rules.

The list is sectioned by category, and each section header shows how many rules
it contains. In each row:

- An **opt-in** rule is marked with a dashed-circle icon (it's off until you
  enable it).
- A **deprecated** rule is labelled accordingly.

### Reading a rule

Select a rule to see its detail pane:

- **Title and badges** — the rule name, its category, and `Opt-in` / `Deprecated`
  badges where applicable.
- **Enabled in config** — a switch that adds or removes this rule from the
  configuration you're editing in the **Config** tab. (See "How enabling a rule
  works" below.)
- **Description** — SwiftFormat's own one-line summary of the rule.
- **Related options** — the `.swiftformat` options that tune this rule's
  behavior, if any.
- **Example** — a before/after snippet showing exactly how the rule rewrites
  code. Removed lines are red, added lines are green.

### How enabling a rule works

The **Enabled in config** switch writes through to your active configuration:

- Turning **on** an opt-in rule adds it to the config's enabled set.
- Turning **off** a default rule adds it to the disabled set.
- Returning a rule to its default state removes the entry again, keeping your
  `.swiftformat` minimal.

You need a project open in the **Config** tab for the switch to have somewhere to
save to.

---

## The Live Preview tab

This is the app's headline feature. The pane is split in two:

- **Source** (left) — an editor preloaded with a small, deliberately messy
  sample. Replace it with your own code.
- **Result** (right) — the reformatted output, shown as a colored diff against
  your source.

As you type, the app re-runs SwiftFormat (debounced, so it waits for you to pause)
and updates the diff. The header of the result pane shows the status:

- **_N_ changes** — that many lines would change.
- **No changes** / **Already formatted** — your code already matches the rules.
- **Error** — SwiftFormat rejected the input (for example, a syntax error); the
  pane shows the message.

The preview honors whatever configuration you've set in the **Config** tab, so
you can toggle an option there and watch the preview update.

> Live Preview formats text in memory through `swiftformat stdin`. It never
> touches files on disk.

---

## The Config tab

This is where you edit a real project's `.swiftformat` file.

### Opening a project

Click **Choose Folder…** (in the toolbar or the empty-state prompt) and pick your
project's root. The app reads the `.swiftformat` file there if one exists, or
starts from an empty configuration if not.

### Editing options

The left panel lists every SwiftFormat option. Search to narrow the list. Each
option shows its name, a short summary, and the right control for its type:

- **Boolean** options get a switch.
- **Enumeration** options get a pop-up menu of the allowed values.
- **Integer**, **list**, and **string** options get a text field (the field's
  placeholder is the default value).

Setting an option back to its default value removes it from the file, so your
`.swiftformat` only ever contains the things you've actually changed.

### Previewing and saving

The right panel shows a live diff of the pending changes to `.swiftformat`. The
toolbar provides:

- **Presets** — apply a starter configuration (Standard, Compact, or
  Opinionated) as a baseline. See the [Reference Manual](reference-manual.md) for
  what each contains.
- **Revert** — discard unsaved edits and reload the file from disk.
- **Save** (⌘S) — write the file. The save is atomic and the previous version is
  backed up first.

If a save fails, the reason appears in red at the top of the diff panel.

---

## The Audit tab

The Audit tab answers "if I adopted these rules, how much of my project would
change?"

### Running an audit

Click **Choose Folder…** and pick a project. The app runs SwiftFormat in lint
mode across the folder and collects machine-readable results. While it runs you
see a progress indicator; large projects take a moment.

### Reading the report

The report has two parts:

- **Summary** — the number of rules with findings, the number of files affected,
  and the total number of findings.
- **Per-rule impact** — a list of rules ranked by how many files each would
  change, with a bar visualizing relative impact and the file/finding counts.

If nothing would change, the audit reports **Already formatted**.

The audit reflects your active configuration, so enabling or disabling rules in
the **Config** tab changes the results on the next run.

### Exporting

Use the **Export** menu to save the report as **CSV** (for spreadsheets) or
**HTML** (a styled, shareable page). Pick a format and choose where to save it.

Use **Re-run** to repeat the audit after changing your configuration.

---

## Tips

- Keep a project open in **Config** so the **Enabled in config** switches,
  **Live Preview**, and **Audit** all work against the same settings.
- Set `--swift-version` (in **Config**) to match your project. Without it,
  SwiftFormat conservatively disables some rules, and your preview and audit will
  under-report changes.
- Use **Live Preview** as a scratchpad to understand a single rule before
  enabling it project-wide; use **Audit** to gauge the blast radius before you
  commit.

---

## See also

- [Tutorial](tutorial.md) — a guided first session.
- [Reference Manual](reference-manual.md) — every category, option kind, preset,
  and the underlying `swiftformat` commands.
