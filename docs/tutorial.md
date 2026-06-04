# SwiftFormatRuleStudio — Tutorial

This is a hands-on first session. In about fifteen minutes you'll go from a fresh
install to a saved `.swiftformat` configuration and an impact report for one of
your own projects. Each step builds on the last.

If you'd rather read about a feature than work through it, jump to the
[User's Guide](users-guide.md).

---

## Step 0 — Install SwiftFormat

The app drives the `swiftformat` command-line tool, so install it first:

```bash
brew install swiftformat
```

Verify it's available:

```bash
swiftformat --version
```

If that prints a version number, you're ready.

---

## Step 1 — Launch and confirm detection

Open SwiftFormatRuleStudio. Look at the status bar along the bottom of the
window. Within a moment it should read something like:

> ✓ SwiftFormat 0.55.x · 170 rules

That confirms the app found SwiftFormat and loaded its rule catalog. If instead
you see "SwiftFormat not found", revisit Step 0 — the binary isn't on your
`PATH`.

---

## Step 2 — Explore a rule

Click the **Rules** tab.

1. In the search field, type `redundantSelf`.
2. Select the rule in the list.
3. Read the detail pane on the right. Notice:
   - the **description** of what the rule does,
   - any **related options** that tune it,
   - the **Example**, a before/after snippet where removed code is red and added
     code is green.

Now try the filters at the top of the list:

- Switch the availability control to **Opt-in** to see the rules SwiftFormat
  leaves off by default (they're marked with a dashed circle in the list).
- Pick a single **category** — say, **Redundancy** — to focus the list.

Spend a minute browsing. The goal is to get a feel for what SwiftFormat can do
before you turn anything on.

---

## Step 3 — Watch code reformat live

Click the **Live Preview** tab. The left pane is preloaded with some messy
sample code; the right pane shows how SwiftFormat would clean it up.

1. Look at the diff on the right and the change count in the result header.
2. Now make it your own: select all in the left editor and paste in a chunk of
   your own Swift.
3. As you stop typing, the right pane updates. The header tells you how many
   lines would change — or says **Already formatted** if your code is clean.

This pane is a safe scratchpad: it formats text in memory and never writes to
disk. Use it whenever you want to see precisely what a rule or option does.

---

## Step 4 — Open a project's configuration

Click the **Config** tab, then **Choose Folder…**, and select one of your own
project folders (its root, where a `.swiftformat` file would live).

- If the project already has a `.swiftformat`, its options load in.
- If not, you start from an empty configuration.

The left panel lists every option; the right panel will show a diff once you make
a change.

---

## Step 5 — Apply a preset as a baseline

Rather than set options one at a time, start from a preset:

1. Open the **Presets** menu in the toolbar.
2. Choose **Standard** (SwiftFormat's defaults with 4-space indentation).
3. Watch the right panel fill with the pending diff — the lines that would be
   written to `.swiftformat`.

Don't save yet. First, let's adjust one thing.

---

## Step 6 — Change an option and see the diff

In the options list on the left:

1. Search for `indent`.
2. If you prefer two-space indentation, change the value to `2`.
3. The diff on the right updates to reflect your change.

Notice that if you set an option back to its default, it disappears from the
diff — the app keeps your configuration minimal, recording only real deviations
from SwiftFormat's defaults.

---

## Step 7 — Turn a rule on

Go back to the **Rules** tab and pick an opt-in rule you liked in Step 2 (for
example, `isEmpty`). Flip the **Enabled in config** switch at the top of the
detail pane.

Return to the **Config** tab: the diff now includes an `--enable` entry for that
rule. The Rules tab and the Config tab are two views of the same configuration.

---

## Step 8 — Save

Back in **Config**, click **Save** (or press ⌘S). The app writes `.swiftformat`
to your project folder. The save is atomic, and your previous file (if any) is
backed up first, so it's safe to experiment.

If you change your mind before saving, **Revert** discards your edits and reloads
the file from disk.

---

## Step 9 — Audit the project

Now see the real-world impact of the configuration you just saved.

1. Click the **Audit** tab and **Choose Folder…** — the same project.
2. Wait for the run to finish.
3. Read the summary: how many rules have findings, how many files are affected,
   and the total number of findings.
4. Scan the per-rule list, ranked by how many files each rule would change. The
   bars make the heavy hitters obvious.

This is your "how big is this change?" answer before you run `swiftformat` for
real across the codebase.

---

## Step 10 — Export the report

Open the **Export** menu in the Audit toolbar and choose **CSV** or **HTML**.
Pick a location to save. Share the HTML with your team, or pull the CSV into a
spreadsheet to track formatting debt over time.

---

## Where to go next

You've now used every part of the app. To go deeper:

- The [User's Guide](users-guide.md) describes each tab and control in full.
- The [Reference Manual](reference-manual.md) lists the rule categories, the
  option kinds and their controls, the contents of each preset, and the exact
  `swiftformat` commands the app runs under the hood.

A good habit: edit in **Config**, sanity-check a rule in **Live Preview**, then
confirm scope in **Audit** before committing a formatting change.
