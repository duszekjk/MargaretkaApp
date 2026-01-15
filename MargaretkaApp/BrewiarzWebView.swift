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

    var body: some View {
        ZStack {
            if let url = resolvedURL {
                WebView(url: url)
            } else {
                ProgressView("Ładowanie...")
            }
        }
        .task(id: key) {
            resolvedURL = await BrewiarzURLResolver.shared.resolveURL(for: key)
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.allowsBackForwardNavigationGestures = true
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard uiView.url != url else { return }
        let request = URLRequest(url: url, cachePolicy: .reloadRevalidatingCacheData)
        uiView.load(request)
    }
}
