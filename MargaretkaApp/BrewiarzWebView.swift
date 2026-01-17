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
                    .padding(fullScreen ? -35.0 : 0.0)
                    .padding(.leading, fullScreen ? -265.0 : 0.0)
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
        html { -webkit-text-size-adjust: 160% !important; }
        body { font-size: 110% !important; line-height: 1.1 !important; }
        body, td, th, div, span, p, a, font { font-size: 18pt !important; line-height: 1.1 !important; }
        .ilg-indent, .ilg-noindent {
          background-repeat: no-repeat !important;
          background-size: 2px calc(100% - 0.3em) !important;
          background-position: 0 0.15em !important;
          text-indent: 0 !important;
        }
        .ilg-indent { background-image: linear-gradient(#1f8a3b, #1f8a3b) !important; }
        .ilg-noindent { background-image: linear-gradient(#1b5faa, #1b5faa) !important; }
        img { max-width: 100% !important; height: auto !important; }
          `));
          document.head.appendChild(style);
          document.documentElement.style.webkitTextSizeAdjust = '160%';
          var blocks = document.querySelectorAll('div.a, div.b, div.c, div.d, div.cd, div.cdx, div.ww');
          blocks.forEach(function(el) {
            if (el.classList.contains('b') || el.classList.contains('d')) {
              el.classList.add('ilg-indent');
              return;
            }
            if (el.classList.contains('a') || el.classList.contains('c')) {
              el.classList.add('ilg-noindent');
              return;
            }
            var cs = window.getComputedStyle(el);
            var marginLeft = parseFloat(cs.marginLeft) || 0;
            var paddingLeft = parseFloat(cs.paddingLeft) || 0;
            var textIndent = parseFloat(cs.textIndent) || 0;
            var indent = Math.max(marginLeft, paddingLeft, textIndent);
            if (indent > 6) {
              el.classList.add('ilg-indent');
            } else {
              el.classList.add('ilg-noindent');
            }
          });
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
