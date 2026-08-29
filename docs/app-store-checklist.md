# Mac App Store submission — what's left

> Written 2026-08-29, after the sandbox track closed
> ([`sandbox-scope.md`](sandbox-scope.md) §8 steps 1–3, PRs #8/#10/#11).
> Everything here needs an Apple Developer account, artwork, or App Store Connect —
> which is why it is a checklist rather than a commit.

## Already done

| | |
|---|---|
| App Sandbox | on for both configurations (`ENABLE_APP_SANDBOX = YES`) |
| Entitlements | `SwiftFormatRuleStudio.entitlements` — sandbox, user-selected read-write, app-scope bookmarks |
| No subprocess dependency | SwiftFormat is linked and run in-process; the CLI backend is ignored under sandbox |
| Persistent folder access | security-scoped bookmarks (#10), verified across relaunch |
| App category | `public.app-category.developer-tools` |
| Version / build | `MARKETING_VERSION = 1.0.0`, `CURRENT_PROJECT_VERSION = 1` |
| Asset catalog | `App/Sources/Assets.xcassets` with an `AppIcon` set wired to `ASSETCATALOG_COMPILER_APPICON_NAME` — **slots defined, artwork missing** |

## 1. The icon

The catalog exists and builds clean; it just has no images. Ten PNGs are needed —
16/32/128/256/512 pt at @1x and @2x, i.e. 16 … 1024 px.

Draw (or commission) **one 1024×1024 master**, then:

```bash
Scripts/make_app_icon.sh path/to/icon-1024.png
```

That slices all ten with `sips` and fills in the filenames in
`AppIcon.appiconset/Contents.json`. Nothing to install; verified end to end on a
generated master, including a clean build with the images present.

Design notes worth knowing before drawing: macOS icons are not full-bleed — they sit on
a rounded-rect with margin, and Apple's own template is the reference. The 16 px slot is
where detail dies; check it early rather than after.

## 2. Signing and the team

Three settings, in both Debug and Release of the app target:

| Setting | Now | For submission |
|---|---|---|
| `DEVELOPMENT_TEAM` | `""` | your Team ID (Organization enrollment) |
| `CODE_SIGN_STYLE` | `Manual` | `Automatic` |
| `CODE_SIGN_IDENTITY[sdk=macosx*]` | `"-"` (ad hoc) | Apple Distribution, via the profile |

They are deliberately left as-is: setting `CODE_SIGN_STYLE = Automatic` with an empty
team makes the project fail to build for anyone without that account, and ad-hoc signing
is what keeps `xcodebuild` working today.

In Xcode: **Signing & Capabilities → Team**, with *Automatically manage signing* checked,
creates the Mac App Distribution profile. App Store Connect needs a matching bundle ID
record for `com.josephcursio.SwiftFormatRuleStudio`.

`ENABLE_HARDENED_RUNTIME = YES` is set. It is required for Developer ID/notarized
distribution and harmless for the App Store, so it can stay either way.

## 3. Metadata still blank

- `INFOPLIST_KEY_NSHumanReadableCopyright` is `""`. It should name the copyright holder
  — the LLC, presumably, whose exact legal name isn't recorded in this repo, which is why
  it is not filled in here.
- App Store Connect needs: description, keywords, support URL, marketing URL (optional),
  privacy policy URL, and the privacy "nutrition label". The app collects nothing and
  makes no network calls, which makes that questionnaire short but not automatic.
- Screenshots: 1280×800, 1440×900, 2560×1600, or 2880×1800. The Rules browser with a
  rule selected, the live Preview diff, and the Impact audit are the three that show what
  the app is for.

## 4. The first signed build is where surprises land

Everything verified so far was **ad-hoc signed**. That is not the same environment as a
distribution-signed build, and two things in particular were never exercised:

- **The `bookmarks.app-scope` entitlement.** It was *not* enforced in the ad-hoc test
  ([`sandbox-bookmarks-scope.md`](sandbox-bookmarks-scope.md) §2) — the app worked
  identically without it. It is in the entitlements file because Apple documents it as
  required; whether a distribution profile enforces it is untested.
- **Archive → validate.** `xcodebuild archive` plus App Store Connect's validation checks
  entitlement/profile agreement, which ad-hoc signing never examines.

Do a full `Product → Archive` → *Validate App* pass before writing any store metadata.
That surfaces signing and entitlement mismatches in minutes, while metadata is an hour
that a rejection wastes.

## 5. Suggested order

1. Icon master → `Scripts/make_app_icon.sh` → verify the 16 px slot looks deliberate.
2. Team + automatic signing; bundle ID record in App Store Connect.
3. `Product → Archive` → **Validate App**. Fix whatever it names before going further.
4. Copyright string, screenshots, description, privacy answers.
5. Submit.
