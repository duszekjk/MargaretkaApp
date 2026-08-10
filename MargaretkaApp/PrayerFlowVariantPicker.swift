//
//  PrayerFlowVariantPicker.swift
//  MargaretkaApp
//

import SwiftUI
#if os(macOS)
import AppKit
#endif

struct PrayerFlowVariantPopupOption: Identifiable {
    let id: AnyHashable
    let title: String
    let language: String
    let isSelected: Bool
    let select: () -> Void
}

struct PrayerFlowVariantPopupState {
    let sourceID: String
    let anchor: CGRect
    let selectedTitle: String
    let options: [PrayerFlowVariantPopupOption]
}

private struct PrayerFlowVariantPopupContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct PrayerFlowVariantPicker<Item: Identifiable>: View where Item.ID: Equatable {
    let items: [Item]
    let selectedID: Item.ID?
    let selectedTitle: String
    let title: (Item) -> String
    let language: (Item) -> String
    let select: (Item) -> Void
    let namespace: Namespace.ID
    let sourceID: String
    let isPresented: Bool
    let popup: PrayerFlowVariantPopupState?
    let isExpanded: Bool
    let isOffsetExpanded: Bool
    let present: (PrayerFlowVariantPopupState) -> Void
    let dismiss: () -> Void
    @State private var anchor = CGRect.zero
    @State private var popupContentHeight: CGFloat = 0

    private var selectorWidth: CGFloat {
#if os(macOS)
        180
#else
        UIDevice.current.userInterfaceIdiom == .pad ? 180 : 122
#endif
    }

    private let selectorHeight: CGFloat = 44

    var body: some View {
        GlassEffectContainer(spacing: 24) {
            ZStack(alignment: .topLeading) {
                if let popup, popup.sourceID == sourceID {
                    localPopup(popup)
                        .zIndex(0)
                }

                Button {
                    withAnimation(.spring(response: 0.72, dampingFraction: 0.86)) {
                        if !isPresented {
                            present(PrayerFlowVariantPopupState(
                                sourceID: sourceID,
                                anchor: anchor,
                                selectedTitle: selectedTitle,
                                options: items.map { item in
                                    PrayerFlowVariantPopupOption(
                                        id: AnyHashable(item.id),
                                        title: title(item),
                                        language: language(item),
                                        isSelected: item.id == selectedID,
                                        select: { select(item) }
                                    )
                                }
                            ))
                        } else {
                            dismiss()
                        }
                    }
                } label: {
                    VStack()
                    {
                        Text(selectedTitle)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .padding(12)
                    }
                    .frame(width: selectorWidth, height: selectorHeight)
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                guard !isPresented else { return }
                                anchor = proxy.frame(in: .global)
                            }
                            .onChange(of: proxy.frame(in: .global)) { frame in
                                guard !isPresented else { return }
                                anchor = frame
                            }
                    }
                }
                .glassEffect(in: .rect(cornerRadius: 12))
                .glassEffectID("\(sourceID)-trigger", in: namespace)
                .zIndex(1)
            }
            .frame(
                width: selectorWidth,
                height: selectorHeight,
                alignment: .topLeading
            )
        }
    }

    @ViewBuilder
    private func localPopup(_ popup: PrayerFlowVariantPopupState) -> some View {
#if os(macOS)
        let screen = NSScreen.main?.frame ?? .zero
#else
        let screen = UIScreen.main.bounds
#endif
        let expandedWidth = min(280, max(200, screen.width - 32))
        let availableHeight = max(120, screen.maxY - popup.anchor.maxY - 24)
        let options = min(CGFloat(popup.options.count), 9.0)
        let expandedHeight = min(CGFloat(options)*54.0+14.0, availableHeight)
        let horizontalOffset = min(0, screen.maxX - popup.anchor.minX - expandedWidth - 16)
        let collapsedWidth = selectorWidth
        let collapsedHeight = selectorHeight
        let estimatedHeight = max(54, CGFloat(popup.options.count) * 52 + 20)
        let preferredHeight = expandedHeight
//        min(
//            expandedHeight,
//            max(collapsedHeight, popupContentHeight > 0 ? popupContentHeight : estimatedHeight)
//        )

        PrayerFlowVariantPopup(
            state: popup,
            namespace: namespace,
            showsContent: isExpanded,
            onContentHeightChange: { popupContentHeight = $0 },
            dismiss: dismiss
        )
        .frame(
            width: isExpanded ? expandedWidth : collapsedWidth,
            height: isExpanded ? preferredHeight : collapsedHeight
        )
        .animation(.spring(response: 0.72, dampingFraction: 0.86), value: isExpanded)
        .offset(
            x: isExpanded ? horizontalOffset : 0,
            y: isOffsetExpanded ? collapsedHeight + 9 : -1
        )
        .animation(.spring(response: 1.44, dampingFraction: 0.86), value: isOffsetExpanded)
        .allowsHitTesting(isExpanded)
    }
}

private struct PrayerFlowVariantPopup: View {
    let state: PrayerFlowVariantPopupState
    let namespace: Namespace.ID
    let showsContent: Bool
    let onContentHeightChange: (CGFloat) -> Void
    let dismiss: () -> Void
    @State private var expandedLanguage: String

    init(
        state: PrayerFlowVariantPopupState,
        namespace: Namespace.ID,
        showsContent: Bool,
        onContentHeightChange: @escaping (CGFloat) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.state = state
        self.namespace = namespace
        self.showsContent = showsContent
        self.onContentHeightChange = onContentHeightChange
        self.dismiss = dismiss
        _expandedLanguage = State(initialValue: state.options.first(where: \.isSelected)?.language ?? state.options.first?.language ?? "")
    }

    private var languages: [String] {
        Array(Set(state.options.map(\.language))).sorted { lhs, rhs in
            let order = ["pl", "en", "la"]
            return (order.firstIndex(of: lhs) ?? order.count) < (order.firstIndex(of: rhs) ?? order.count)
        }
    }

    private var listOptions: [PrayerFlowVariantPopupOption] {
        state.options
    }

    var body: some View {
        ZStack {
            Color.clear

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 0) {
                    if state.options.count > 5 {
                        ForEach(languages, id: \.self) { language in
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    expandedLanguage = expandedLanguage == language ? "" : language
                                }
                            } label: {
                                HStack {
                                    Text(language)
                                        .font(.caption2.monospaced().weight(.semibold))
                                    Spacer(minLength: 2.0)
                                    Image(systemName: expandedLanguage == language ? "chevron.up" : "chevron.down")
                                        .font(.caption.weight(.semibold))
                                }
                                .frame(height: 32.0)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if expandedLanguage == language {
                                ForEach(listOptions.filter { $0.language == language }) { option in
                                    optionRow(option)
                                }
                            }
                        }
                    } else {
                        ForEach(listOptions) { option in
                            optionRow(option)
                        }
                    }
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: PrayerFlowVariantPopupContentHeightKey.self,
                            value: proxy.size.height
                        )
                    }
                }
            }
        }
        .opacity(showsContent ? 1 : 0)
        .onPreferenceChange(PrayerFlowVariantPopupContentHeightKey.self) { height in
            guard height > 0 else { return }
            onContentHeightChange(height)
        }
        .glassEffect(in: .rect(cornerRadius: 6))
        .glassEffectID("\(state.sourceID)-panel", in: namespace)
        .glassEffectTransition(.matchedGeometry)
    }

    @ViewBuilder
    private func optionRow(_ option: PrayerFlowVariantPopupOption) -> some View {
        Button {
            option.select()
            dismiss()
        } label: {
            HStack(alignment: .center, spacing: 2) {
                Text(option.title)
                    .fontWeight(option.isSelected ? .bold : .regular)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 2)
                Text(option.language)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
//                    .padding(.top, 3)
            }
            .minimumScaleFactor(0.7)
            .frame(height: 48)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
