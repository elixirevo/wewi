import SwiftUI

@MainActor
struct WebsiteCookieSheet: View {
    let scope: WebsiteCookieScope
    let service: WebsiteCookieService
    @Environment(\.dismiss) private var dismiss
    @State private var isClearing = false
    @State private var result: WebsiteCookieService.Result?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(appText(result == nil ? "Clear website cookies?" : "Cookie removal finished"),
                  systemImage: result == nil ? "trash" : "checkmark.circle")
                .font(.title2.bold())
            Text(scope.hosts.joined(separator: "\n"))
                .font(.headline).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
            if let result {
                Text(String(format: appText("Deleted %d cookies."), result.deleted))
                if result.remaining > 0 {
                    Text(appText("Some cookies are still present or were recreated by an open page. You can close the site's widgets and try again."))
                        .foregroundStyle(.secondary)
                }
                Text(appText("Reload the widget to update the displayed session. Cookies alone may not clear a login saved in local storage. Open websites can create cookies again."))
                    .foregroundStyle(.secondary)
            } else {
                Text(appText("Remove cookies that apply to these websites in wewi, including shared parent-domain cookies. Other widgets that share those cookies may be signed out."))
                Text(appText("Cookies from unrelated websites, cached files, and local storage are kept. The page will not reload automatically."))
                    .foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                if isClearing {
                    ProgressView().controlSize(.small)
                    Text(appText("Removing cookies…"))
                } else if result != nil {
                    Button(appText("Done")) { dismiss() }.keyboardShortcut(.defaultAction)
                } else {
                    Button(appText("Cancel")) { dismiss() }.keyboardShortcut(.cancelAction)
                    Button(appText("Clear Cookies"), role: .destructive) {
                        isClearing = true
                        Task { @MainActor in
                            result = await service.clear(scope)
                            isClearing = false
                        }
                    }.disabled(scope.hosts.isEmpty)
                }
            }
        }.padding(24).frame(width: 460)
            .interactiveDismissDisabled(isClearing)
    }
}
