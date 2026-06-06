#!/usr/bin/env python3
"""Audit which rule options visibly change the rule's live example.

For every rule that has a live example AND related options, test each option:
re-format the example with `--rules <rule> --<opt> <value>` for a few candidate
values and see if ANY value changes the output vs the baseline (rule at defaults).
Options where nothing changes are "dead" — the example lacks the construct that
option governs. Mirrors the app's RuleLiveExampleView logic.
"""
import re
import subprocess
import sys
from pathlib import Path

REPO = Path("/Users/josephcursio/xcode_projects/SwiftFormatRuleStudio")
MD_DIR = REPO / "SwiftFormatRuleStudioCore" / "CuratedExamples"
SWIFT_VERSION = "6.0"
FENCE = re.compile(r"```swift\n(.*?)\n```", re.DOTALL)


def sf(args, stdin):
    try:
        p = subprocess.run(["swiftformat"] + args, input=stdin,
                           capture_output=True, text=True, timeout=30)
    except Exception:
        return None
    if p.returncode != 0:
        return None
    return p.stdout


def curated_snippet(rule):
    path = MD_DIR / f"{rule}.md"
    if not path.exists():
        return None
    m = FENCE.search(path.read_text())
    return m.group(1).rstrip("\n") if m else None


def reconstruct_before(example):
    """Port of FormatRule.exampleBeforeSource."""
    if not example:
        return None
    hunks, cur = [], []
    for line in example.split("\n"):
        if line.strip() == "":
            if cur:
                hunks.append(cur); cur = []
        else:
            cur.append(line)
    if cur:
        hunks.append(cur)
    hunk = next((h for h in hunks if any(l.startswith(("+", "-")) for l in h)), None)
    if hunk is None:
        return None
    before = "\n".join((l if l == "" else l[1:]) for l in hunk if not l.startswith("+"))
    return None if before.strip() == "" else before


def live_example(rule, ruleinfo):
    snip = curated_snippet(rule)
    if snip is not None:
        return snip
    # reconstruct from --ruleinfo Examples section
    ex = parse_example(ruleinfo)
    return reconstruct_before(ex)


def parse_example(ruleinfo):
    lines = ruleinfo.split("\n")
    out, started, in_ex = [], False, False
    for line in lines:
        t = line.strip()
        if t == "Examples:":
            in_ex = True
            continue
        if not in_ex:
            continue
        if started and t and not line.startswith(("+", "-", " ", "\t")):
            break  # left-aligned prose ends the block
        if t:
            started = True
        if started:
            out.append(line)
    while out and out[0].strip() == "":
        out.pop(0)
    while out and out[-1].strip() == "":
        out.pop()
    return "\n".join(out) if out else None


def parse_related_options(ruleinfo):
    lines = ruleinfo.split("\n")
    opts, in_opts = [], False
    for line in lines:
        t = line.strip()
        if t == "Options:":
            in_opts = True
            continue
        if t == "Examples:":
            in_opts = False
            continue
        if in_opts and t.startswith("--"):
            opts.append(t.split()[0])
    return opts


def candidate_values(flag, blurb):
    vals = set(re.findall(r'"([^"]+)"', blurb))
    low = blurb.lower()
    if "true" in low or "false" in low:
        vals.update(["true", "false"])
    if "enabled" in low or "disabled" in low:
        vals.update(["enabled", "disabled"])
    if any(w in low for w in ["number", "width", "threshold", "defaults to", "spaces", "length", "limit", "group"]):
        vals.update(["0", "1", "2", "4", "8", "none"])
    if "tab" in low:
        vals.add("tab")
    if "uppercase" in low or "lowercase" in low:
        vals.update(["uppercase", "lowercase"])
    # Free-form list/string options: craft a plausible non-default value so the
    # option is actually exercised rather than skipped.
    if "modifiers in preferred order" in low or "preferred order" in low:
        vals.add("lazy,weak,final,public,override,private(set),convenience,static,class")
    if "comma-delimited list of functions" in low or "list of functions" in low:
        vals.update(["foo", "bar", "map", "async", "withAnimation"])
    return [v for v in vals if v and " " not in v]


def main():
    only = set(sys.argv[1:])  # optional: limit to these rule names
    rules_out = sf(["--rules"], "")
    if rules_out is None:
        print("swiftformat not available", file=sys.stderr)
        return 1
    rule_names = []
    for line in rules_out.split("\n"):
        t = line.strip()
        if not t:
            continue
        name = t.split()[0]
        if only and name not in only:
            continue
        rule_names.append(name)

    # option blurbs from --options
    opts_out = sf(["--options"], "") or ""
    blurbs = {}
    cur_flag = None
    for line in opts_out.split("\n"):
        m = re.match(r"\s*(--[\w-]+)\s*(.*)", line)
        if m:
            cur_flag = m.group(1)
            blurbs[cur_flag] = m.group(2).strip()
        elif cur_flag and line.strip():
            blurbs[cur_flag] += " " + line.strip()

    dead_report = {}
    live_report = {}
    untested_report = {}
    no_example_with_opts = []

    for rule in rule_names:
        info = sf(["--ruleinfo", rule], "")
        if info is None:
            continue
        related = parse_related_options(info)
        if not related:
            continue
        before = live_example(rule, info)
        if not before:
            no_example_with_opts.append(rule)
            continue
        base = sf(["stdin", "--rules", rule, "--swift-version", SWIFT_VERSION], before)
        if base is None:
            base = sf(["stdin", "--rules", rule, "--fragment", "true",
                       "--swift-version", SWIFT_VERSION], before)
        if base is None:
            continue
        dead, live, untested = [], [], []
        for flag in related:
            key = flag.lstrip("-")
            blurb = blurbs.get(flag, "")
            cands = candidate_values(flag, blurb)
            if not cands:
                untested.append(flag)
                continue
            changed = False
            for v in cands:
                out = sf(["stdin", "--rules", rule, f"--{key}", v,
                          "--swift-version", SWIFT_VERSION], before)
                if out is None:
                    out = sf(["stdin", "--rules", rule, f"--{key}", v, "--fragment", "true",
                              "--swift-version", SWIFT_VERSION], before)
                if out is not None and out != base:
                    changed = True
                    break
            (live if changed else dead).append(flag)
        if dead:
            dead_report[rule] = dead
        if live:
            live_report[rule] = live
        if untested:
            untested_report[rule] = untested

    print("=" * 70)
    print(f"OPTION-EFFECT AUDIT — {len(rule_names)} rules")
    print("=" * 70)
    print(f"\nRules with >=1 GENUINELY DEAD option (tried values, no change): {len(dead_report)}\n")
    for rule in sorted(dead_report):
        print(f"  {rule}")
        print(f"      DEAD: {dead_report[rule]}")
        if rule in live_report:
            print(f"      live: {live_report[rule]}")
        if rule in untested_report:
            print(f"      untested(free-form): {untested_report[rule]}")
    print(f"\n--- Untested-only rules (free-form opts, no auto candidate; verify by eye) ---")
    for rule in sorted(untested_report):
        if rule not in dead_report:
            print(f"  {rule}: {untested_report[rule]}")
    print(f"\nRules with options but no usable example: {len(no_example_with_opts)}  {no_example_with_opts}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
