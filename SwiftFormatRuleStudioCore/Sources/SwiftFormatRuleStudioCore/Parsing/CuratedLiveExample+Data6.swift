//
//  CuratedLiveExample+Data6.swift
//  SwiftFormatRuleStudio
//

import Foundation

/// Option-gated rules: these do nothing at default (their controlling option is
/// "off" — e.g. `--max-width none`, `--header ignore`), so the Before/After shows
/// "unchanged" until you set the option in the panel, then the transformation
/// appears. The snippet is chosen so setting that option produces a clear diff.
extension CuratedLiveExample {
    static let dataPart6: [String: String] = [
        // Set --max-width (e.g. 40) to wrap the long call.
        "wrap": """
        let message = service.format(name: userName, salutation: preferredSalutation, locale: currentLocale)
        """,

        // Set --func-attributes / --type-attributes to prev-line to wrap.
        "wrapAttributes": """
        @objc func reload() {}

        @available(iOS 15, *) func refresh() {}
        """,

        // Set --max-width (e.g. 50) to wrap the long trailing comment.
        "wrapSingleLineComments": """
        let x = 1 // a very long trailing comment that should wrap once a maximum width is configured here
        """,

        // Set --url-macro (e.g. "#URL,URLFoundation") to migrate the force-unwrapped URL.
        "urlMacro": """
        let endpoint = URL(string: "https://example.com")!
        """,

        // Set --header (e.g. "Copyright Acme Corp.") to insert/replace the file header.
        "fileHeader": """
        import Foundation

        struct Foo {}
        """
    ]
}
