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
          position: relative !important;
          overflow: visible !important;
        }
        .ilg-indent::before, .ilg-noindent::before {
          content: '';
          position: absolute;
          left: 0;
          top: 0.15em;
          bottom: 0.15em;
          width: 2px;
          border-radius: 2px;
          pointer-events: none;
          transform: translateX(-4px);
        }
        .ilg-noindent::before { background: #1f8a3b; }
        .ilg-indent::before { background: #1b5faa; }
        img { max-width: 100% !important; height: auto !important; }
          `));
          document.head.appendChild(style);
          document.documentElement.style.webkitTextSizeAdjust = '160%';
          var scope = document.querySelector('td[width="560"]');
          if (!scope) {
            return;
          }
          function normalizeLabel(text) {
            return text.replace(/\\s+/g, ' ').trim().toUpperCase();
          }
          function findHeading(label) {
            var target = normalizeLabel(label);
            var candidates = scope.querySelectorAll('font, b');
            for (var i = 0; i < candidates.length; i++) {
              var candidate = candidates[i];
              if (normalizeLabel(candidate.textContent || '') === target) {
                return candidate;
              }
            }
            return scope.querySelector('a[name="' + label.toLowerCase() + '"]');
          }
          function applyMarkers(startNode, endNode) {
            if (!startNode || !endNode) {
              return;
            }
            var walker = document.createTreeWalker(scope, NodeFilter.SHOW_ELEMENT, null);
            var inSection = false;
            var nodes = [];
            while (walker.nextNode()) {
              var node = walker.currentNode;
              if (node === startNode) {
                inSection = true;
              }
              if (node === endNode) {
                break;
              }
              if (inSection && node.matches && node.matches('div.a, div.b, div.c, div.d')) {
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
          }
          var psalmStart = findHeading('PSALMODIA');
          var psalmEnd = findHeading('CZYTANIE');
          if (psalmStart && psalmStart.closest) {
            psalmStart = psalmStart.closest('div') || psalmStart;
          }
          if (psalmEnd && psalmEnd.closest) {
            psalmEnd = psalmEnd.closest('div') || psalmEnd;
          }
          applyMarkers(psalmStart, psalmEnd);
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
