//
//  BrewiarzWebView.swift
//  MargaretkaApp
//
//  Created by Jacek Kałużny on 18/01/2026.
//

import SwiftUI
import WebKit

struct BrewiarzPrayerView: View {
    let key: BrewiarzPrayerKey

    @State private var resolvedURL: URL?
    @Binding var fullScreen: Bool

    var body: some View {
        ZStack {
            if let url = resolvedURL {
                WebView(url: url)
                    .ignoresSafeArea()
                    .padding(fullScreen ? -105.0 : 0.0)
                    .padding(.leading, fullScreen ? -165.0 : 0.0)
            } else {
                ProgressView("Ładowanie...")
            }
        }
        .ignoresSafeArea()
        .task(id: key) {
            resolvedURL = await BrewiarzURLResolver.shared.resolveURL(for: key)
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let scriptSource = """
        (function() {
          var style = document.createElement('style');
          style.type = 'text/css';
          style.appendChild(document.createTextNode(`
        html { -webkit-text-size-adjust: 200% !important; }
        body { font-size: 200% !important; line-height: 1.4 !important; }
        body, td, th, div, span, p, a, font { font-size: 24pt !important; line-height: 1.4 !important; }
        img { max-width: 100% !important; height: auto !important; }
          `));
          document.head.appendChild(style);
          document.documentElement.style.webkitTextSizeAdjust = '200%';
        })();
        """
        let script = WKUserScript(source: scriptSource, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        let view = WKWebView(frame: .zero, configuration: config)
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard uiView.url != url else { return }
        let request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData)
        uiView.load(request)
    }
}
