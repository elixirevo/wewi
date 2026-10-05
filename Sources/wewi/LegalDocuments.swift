import Foundation
import MacAppCore
import MacAppSettings
import SwiftUI

enum LegalDocuments {
    static let version = "2026-10-05"
    static func text(_ name: String, language: String = AppLocalizer.current.languageCode) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "txt", subdirectory: nil, localization: language) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let text = try String(contentsOf: url, encoding: .utf8)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw CocoaError(.fileReadCorruptFile) }
        return text
    }
}

struct LegalSection: View {
    let terms: String
    let privacy: String
    @State private var selected: String?
    var body: some View {
        SettingsSection(appText("Legal Documents")) {
            Button(appText("Terms of Use")) { selected = "terms" }
            Button(appText("Privacy Policy")) { selected = "privacy" }
            Button(appText("Open Source Licenses")) { selected = "licenses" }
        }
        .sheet(isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } })) {
            VStack(alignment: .leading, spacing: 16) {
                Text(appText(selected == "terms" ? "Terms of Use" : selected == "privacy" ? "Privacy Policy" : "Open Source Licenses")).font(.title2)
                ScrollView {
                    Text(content).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                }
                HStack { Spacer(); Button(appText("Done")) { selected = nil }.keyboardShortcut(.cancelAction) }
            }.padding(24).frame(width: 600, height: 500)
        }
    }
    private var content: String {
        if selected == "terms" { return terms }
        if selected == "privacy" { return privacy }
        guard let url = Bundle.module.url(forResource: "ThirdPartyNotices", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return appText("Document unavailable.") }
        return text
    }
}
