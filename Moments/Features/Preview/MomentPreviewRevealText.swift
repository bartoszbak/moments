import SwiftUI

struct WordRevealText: View {
    let text: String
    let font: Font
    let color: Color
    var alignment: HorizontalAlignment = .leading
    var fontDesignOverride: Font.Design? = .rounded
    var verticalSpacing: CGFloat = 4
    var paragraphSpacing: CGFloat = 18
    var onRevealCompleted: (() -> Void)? = nil

    @State private var availableWidth: CGFloat = 0
    @State private var measuredLineHeight: CGFloat = 0
    @State private var revealedWordCount = 0
    @State private var revealTask: Task<Void, Never>?

    private var normalizedText: String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
    }

    private var paragraphs: [Paragraph] {
        let rawParagraphs = normalizedText
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let effectiveParagraphs = rawParagraphs.isEmpty ? [normalizedText] : rawParagraphs
        var startIndex = 0

        return effectiveParagraphs.compactMap { paragraph in
            let tokens = paragraph
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }

            guard !tokens.isEmpty else { return nil }
            defer { startIndex += tokens.count }
            return Paragraph(tokens: tokens, startIndex: startIndex)
        }
    }

    private var totalTokenCount: Int {
        paragraphs.reduce(0) { $0 + $1.tokens.count }
    }

    var body: some View {
        VStack(
            alignment: alignment == .center ? .center : .leading,
            spacing: paragraphSpacing
        ) {
            ForEach(Array(paragraphs.enumerated()), id: \.offset) { _, paragraph in
                FlowTextLayout(horizontalSpacing: 5, verticalSpacing: verticalSpacing) {
                    ForEach(Array(paragraph.tokens.enumerated()), id: \.offset) { index, token in
                        let globalIndex = paragraph.startIndex + index

                        Text(token)
                            .font(font)
                            .fontDesign(fontDesignOverride)
                            .foregroundStyle(color)
                            .opacity(globalIndex < revealedWordCount ? 1 : 0)
                            .blur(radius: globalIndex < revealedWordCount ? 0 : 14)
                            .offset(y: globalIndex < revealedWordCount ? 0 : 8)
                            .animation(
                                .easeOut(duration: 0.42).delay(Double(globalIndex) * 0.045),
                                value: revealedWordCount
                            )
                            .frame(
                                height: measuredLineHeight > 0 ? measuredLineHeight : nil,
                                alignment: .bottomLeading
                            )
                            .fixedSize()
                    }
                }
                .frame(
                    width: availableWidth > 0 ? availableWidth : nil,
                    alignment: alignment == .center ? .center : .leading
                )
                .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
                .padding(.bottom, measuredLineHeight > 0 ? max(measuredLineHeight * 0.08, 1) : 0)
            }
        }
        .font(nil)
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
        .overlay(alignment: .topLeading) {
            Text("Agjp")
                .font(font)
                .opacity(0.001)
                .background(HeightMeasurementView(height: $measuredLineHeight))
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background {
            GeometryReader { proxy in
                Color.clear
                    .task(id: proxy.size.width) {
                        guard abs(availableWidth - proxy.size.width) > 0.5 else { return }
                        availableWidth = proxy.size.width
                    }
            }
        }
        .onAppear {
            restartReveal()
        }
        .onChange(of: text) { _, _ in
            restartReveal()
        }
        .onDisappear {
            revealTask?.cancel()
        }
    }

    private func restartReveal() {
        revealTask?.cancel()
        revealedWordCount = 0

        guard totalTokenCount > 0 else { return }

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(35))
            guard !Task.isCancelled else { return }
            revealedWordCount = totalTokenCount

            let trailingDelay = Double(max(totalTokenCount - 1, 0)) * 0.045
            let completionDelay = trailingDelay + 0.42
            try? await Task.sleep(for: .seconds(completionDelay))
            guard !Task.isCancelled else { return }
            onRevealCompleted?()
        }
    }

    private struct Paragraph {
        let tokens: [String]
        let startIndex: Int
    }
}

struct NativeRevealText: View {
    let text: String
    let font: Font
    let color: Color
    var alignment: TextAlignment = .leading
    var fontDesignOverride: Font.Design? = .rounded
    var lineSpacing: CGFloat = 0
    var onRevealCompleted: (() -> Void)? = nil

    @State private var isRevealed = false
    @State private var revealTask: Task<Void, Never>?

    var body: some View {
        Text(text)
            .font(font)
            .fontDesign(fontDesignOverride)
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
            .lineSpacing(lineSpacing)
            .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
            .opacity(isRevealed ? 1 : 0)
            .blur(radius: isRevealed ? 0 : 14)
            .offset(y: isRevealed ? 0 : 8)
            .animation(.easeOut(duration: 0.42), value: isRevealed)
            .onAppear {
                restartReveal()
            }
            .onChange(of: text) { _, _ in
                restartReveal()
            }
            .onDisappear {
                revealTask?.cancel()
            }
    }

    private func restartReveal() {
        revealTask?.cancel()
        isRevealed = false

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        revealTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(35))
            guard !Task.isCancelled else { return }
            isRevealed = true

            try? await Task.sleep(for: .seconds(0.42))
            guard !Task.isCancelled else { return }
            onRevealCompleted?()
        }
    }
}

struct LoopingLetterRevealText: View {
    let text: String
    let font: Font
    let color: Color

    @State private var revealedCharacterCount = 0
    @State private var revealTask: Task<Void, Never>?

    private var characters: [String] {
        text.map(String.init)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(characters.enumerated()), id: \.offset) { index, character in
                Text(character)
                    .font(font)
                    .foregroundStyle(color)
                    .opacity(index < revealedCharacterCount ? 1 : 0)
                    .blur(radius: index < revealedCharacterCount ? 0 : 12)
                    .offset(y: index < revealedCharacterCount ? 0 : 4)
                    .animation(
                        .easeOut(duration: 0.28).delay(Double(index) * 0.028),
                        value: revealedCharacterCount
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .onAppear {
            startLoop()
        }
        .onChange(of: text) { _, _ in
            startLoop()
        }
        .onDisappear {
            revealTask?.cancel()
        }
    }

    private func startLoop() {
        revealTask?.cancel()
        revealedCharacterCount = 0

        guard !characters.isEmpty else { return }

        revealTask = Task { @MainActor in
            while !Task.isCancelled {
                revealedCharacterCount = 0
                try? await Task.sleep(for: .milliseconds(45))
                guard !Task.isCancelled else { return }

                revealedCharacterCount = characters.count
                try? await Task.sleep(for: .seconds(1.4))
                guard !Task.isCancelled else { return }
            }
        }
    }
}
