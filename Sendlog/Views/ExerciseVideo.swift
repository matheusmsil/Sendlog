import SwiftUI
import WebKit

/// A ▶︎ button that plays an exercise's execution video, or nothing when there's no video.
struct VideoButton: View {
    let url: URL?
    let title: String
    @State private var isPresented = false
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let url {
            Button {
                // YouTube plays in the small window; any other link opens in Safari.
                if YouTube.videoID(from: url) != nil { isPresented = true } else { openURL(url) }
            } label: {
                Image(systemName: "play.rectangle.fill")
                    .font(.title3)
                    .accessibilityLabel("Ver execução")
            }
            .buttonStyle(.borderless)
            .sheet(isPresented: $isPresented) {
                VideoPlayerSheet(url: url, title: title)
            }
        }
    }
}

/// A half-height window that plays the video in place, leaving the workout usable above it.
/// Only used for YouTube links, which play in the embedded player.
struct VideoPlayerSheet: View {
    let url: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        if let videoID = YouTube.videoID(from: url) {
            VStack(spacing: 12) {
                HStack {
                    Text(title).font(.headline).lineLimit(1)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Fechar")
                    }
                    .buttonStyle(.plain)
                }

                YouTubePlayer(videoID: videoID)
                    .aspectRatio(9 / 16, contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 12))
                    .frame(maxWidth: .infinity)

                Button("Abrir no YouTube", systemImage: "arrow.up.right.square") { openURL(url) }
                    .font(.footnote)
            }
            .padding()
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            // Keep the workout behind the window usable, e.g. to tick off sets while watching.
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
    }
}

enum YouTube {
    /// The video ID from youtube.com/shorts/ID, youtube.com/watch?v=ID, youtu.be/ID or youtube.com/embed/ID links.
    static func videoID(from url: URL) -> String? {
        guard let host = url.host()?.lowercased() else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        if host.hasSuffix("youtu.be") { return parts.first }
        guard host.hasSuffix("youtube.com") else { return nil }
        if let index = parts.firstIndex(where: { ["shorts", "embed", "live"].contains($0) }), index + 1 < parts.count {
            return parts[index + 1]
        }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "v" }?.value
    }
}

/// YouTube's embedded player in a web view, playing inline and starting automatically.
struct YouTubePlayer: UIViewRepresentable {
    let videoID: String

    /// YouTube's embed refuses to play without an origin/referrer, so the page gets one.
    private static let origin = "https://com.matheus.sendlog"

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        return webView
    }

    final class Coordinator {
        var loadedVideoID: String?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only load once per video; reloading on every SwiftUI update would restart playback.
        guard context.coordinator.loadedVideoID != videoID else { return }
        context.coordinator.loadedVideoID = videoID
        let html = """
        <!doctype html>
        <html><head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
        <style>html,body{margin:0;height:100%;background:#000}iframe{border:0;width:100%;height:100%}</style>
        </head><body>
        <iframe src="https://www.youtube-nocookie.com/embed/\(videoID)?playsinline=1&autoplay=1&rel=0&modestbranding=1&origin=\(Self.origin)"
          allow="autoplay; encrypted-media; picture-in-picture; fullscreen"
          referrerpolicy="strict-origin-when-cross-origin" allowfullscreen></iframe>
        </body></html>
        """
        webView.loadHTMLString(html, baseURL: URL(string: Self.origin))
    }
}

/// An alert for pasting your own video link for an exercise.
struct VideoLinkAlert: ViewModifier {
    @Binding var isPresented: Bool
    @Binding var link: String
    @State private var draft = ""

    func body(content: Content) -> some View {
        content.alert("Link do vídeo", isPresented: $isPresented) {
            TextField("https://youtube.com/…", text: $draft)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
            Button("Salvar") { link = draft.trimmingCharacters(in: .whitespaces) }
            if !link.isEmpty {
                Button("Remover link", role: .destructive) { link = "" }
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Cole o link de um vídeo mostrando a execução.")
        }
        .onChange(of: isPresented) { if isPresented { draft = link } }
    }
}

extension View {
    func videoLinkAlert(isPresented: Binding<Bool>, link: Binding<String>) -> some View {
        modifier(VideoLinkAlert(isPresented: isPresented, link: link))
    }
}
