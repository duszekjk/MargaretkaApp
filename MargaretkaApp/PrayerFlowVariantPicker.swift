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
    @State private var triggerSize = CGSize.zero
    @State private var popupContentHeight: CGFloat = 0

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
                    Text(selectedTitle).lineLimit(1).minimumScaleFactor(0.75).padding(12)
                }
                .background {
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear {
                                guard !isPresented else { return }
                                anchor = proxy.frame(in: .global)
                                triggerSize = proxy.size
                            }
                            .onChange(of: proxy.frame(in: .global)) { frame in
                                guard !isPresented else { return }
                                anchor = frame
                                triggerSize = frame.size
                            }
                    }
                }
                .glassEffect(in: .rect(cornerRadius: 12))
                .glassEffectID("\(sourceID)-trigger", in: namespace)
                .zIndex(1)
            }
            .frame(
                width: triggerSize.width > 0 ? triggerSize.width : nil,
                height: triggerSize.height > 0 ? triggerSize.height : nil,
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
        let expandedWidth = min(270, max(200, screen.width - 32))
        let availableHeight = max(120, screen.maxY - popup.anchor.maxY - 24)
        let expandedHeight = min(460, availableHeight)
        let horizontalOffset = min(0, screen.maxX - popup.anchor.minX - expandedWidth - 16)
        let collapsedWidth = max(1, triggerSize.width)
        let collapsedHeight = max(1, triggerSize.height)
        let estimatedHeight = max(54, CGFloat(popup.options.count - 1) * 52 + 20)
        let preferredHeight = min(
            expandedHeight,
            max(collapsedHeight, popupContentHeight > 0 ? popupContentHeight : estimatedHeight)
        )

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
        .offset(
            x: isExpanded ? horizontalOffset : 0,
            y: isOffsetExpanded ? collapsedHeight + 6 : -1
        )
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
        state.options.filter { !$0.isSelected }
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
                                    Spacer()
                                    Image(systemName: expandedLanguage == language ? "chevron.up" : "chevron.down")
                                        .font(.caption.weight(.semibold))
                                }
                                .padding(.horizontal, 16)
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
            .opacity(showsContent ? 1 : 0)
        }
        .onPreferenceChange(PrayerFlowVariantPopupContentHeightKey.self) { height in
            guard height > 0 else { return }
            onContentHeightChange(height)
        }
        .glassEffect(in: .rect(cornerRadius: 6))
        .glassEffectID("\(state.sourceID)-panel", in: namespace)
        .glassEffectTransition(.materialize)
    }

    @ViewBuilder
    private func optionRow(_ option: PrayerFlowVariantPopupOption) -> some View {
        Button {
            option.select()
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text(option.title)
                    .fontWeight(option.isSelected ? .bold : .regular)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Text(option.language)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.top, 3)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
