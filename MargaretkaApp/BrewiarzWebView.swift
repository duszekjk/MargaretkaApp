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
          background-position: -2px 0.15em !important;
        }
        .ilg-noindent {
          background-image: linear-gradient(#1f8a3b, #1f8a3b) !important;
          text-indent: 0 !important;
        }
        .ilg-indent { background-image: linear-gradient(#1b5faa, #1b5faa) !important; }
        img { max-width: 100% !important; height: auto !important; }
          `));
          document.head.appendChild(style);
          document.documentElement.style.webkitTextSizeAdjust = '160%';
          var scope = document.querySelector('td[width="560"]');
          if (!scope) {
            return;
          }
          var psalmAnchor = scope.querySelector('a[name="psalm"]');
          var readingAnchor = scope.querySelector('a[name="czyt"]');
          if (!psalmAnchor || !readingAnchor) {
            return;
          }
          var walker = document.createTreeWalker(scope, NodeFilter.SHOW_ELEMENT, null);
          var inPsalm = false;
          var nodes = [];
          while (walker.nextNode()) {
            var node = walker.currentNode;
            if (node === psalmAnchor) {
              inPsalm = true;
            }
            if (node === readingAnchor) {
              break;
            }
            if (inPsalm && node.matches && node.matches('div.a, div.b, div.c, div.d')) {
              nodes.push(node);
            }
          }
          nodes.forEach(function(el) {
            if (el.classList.contains('b') || el.classList.contains('d')) {
              el.classList.add('ilg-indent');
            } else if (el.classList.contains('a') || el.classList.contains('c')) {
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
