import SwiftUI
import UIKit

enum HighlightTextStyle {
    case standard
    case reader
}

enum HighlightTextBuilder {
    private struct TokenHighlightMeta {
        let actionWord: String
        let foregroundColor: UIColor
        let backgroundColor: UIColor
        let showsUnderline: Bool
    }

    static func baseAttributedText(
        text: String,
        font: UIFont,
        lineSpacing: CGFloat = 5,
        lineHeightMultiple: CGFloat = 1,
        textColor: UIColor = .label
    ) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: textColor,
                .paragraphStyle: paragraphStyle(
                    lineSpacing: lineSpacing,
                    lineHeightMultiple: lineHeightMultiple
                )
            ]
        )
    }

    static func makeAttributedText(
        text: String,
        contextWords: Set<String>,
        catalog: WordLabelCatalog,
        learningRecords: [String: LearningRecord],
        font: UIFont,
        lineSpacing: CGFloat = 5,
        lineHeightMultiple: CGFloat = 1,
        highlightStyle: HighlightTextStyle = .standard,
        textColor: UIColor = .label
    ) -> NSAttributedString {
        let attributed = NSMutableAttributedString(
            attributedString: baseAttributedText(
                text: text,
                font: font,
                lineSpacing: lineSpacing,
                lineHeightMultiple: lineHeightMultiple,
                textColor: textColor
            )
        )

        let nsText = text as NSString
        for match in WordPowerText.tokenMatches(in: text) {
            let token = nsText.substring(with: match.range)
            guard let meta = tokenHighlightMeta(
                token: token,
                contextWords: contextWords,
                catalog: catalog,
                learningRecords: learningRecords,
                highlightStyle: highlightStyle
            ) else {
                continue
            }

            attributed.addAttribute(.foregroundColor, value: meta.foregroundColor, range: match.range)
            attributed.addAttribute(.backgroundColor, value: meta.backgroundColor, range: match.range)
            if meta.showsUnderline {
                attributed.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
            }
            attributed.addAttribute(.link, value: actionURL(displayToken: token, targetWord: meta.actionWord), range: match.range)
        }

        return attributed
    }

    static func measureHeight(for attributedText: NSAttributedString, width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0 }

        let storage = NSTextStorage(attributedString: attributedText)
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.lineBreakMode = .byWordWrapping
        container.maximumNumberOfLines = 0

        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)

        return ceil(layoutManager.usedRect(for: container).height)
    }

    static func parseActionURL(_ url: URL) -> WordActionContext? {
        guard url.scheme == "wordpower" else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let targetWord = components.queryItems?.first(where: { $0.name == "word" })?.value ?? ""
        let displayToken = components.queryItems?.first(where: { $0.name == "token" })?.value ?? ""
        guard !targetWord.isEmpty, !displayToken.isEmpty else { return nil }
        return WordActionContext(displayToken: displayToken, targetWord: targetWord)
    }

    private static func actionURL(displayToken: String, targetWord: String) -> URL {
        var components = URLComponents()
        components.scheme = "wordpower"
        components.host = "action"
        components.queryItems = [
            URLQueryItem(name: "word", value: targetWord),
            URLQueryItem(name: "token", value: displayToken)
        ]
        return components.url ?? URL(string: "wordpower://action")!
    }

    private static func tokenHighlightMeta(
        token: String,
        contextWords: Set<String>,
        catalog: WordLabelCatalog,
        learningRecords: [String: LearningRecord],
        highlightStyle: HighlightTextStyle
    ) -> TokenHighlightMeta? {
        let normalizedToken = token.lowercased()
        let parts = normalizedToken
            .split(separator: "-")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let hasHyphen = parts.count > 1
        var selectedActionWord = ""
        var selectedFamiliarity = LearningDataCodec.maxFamiliarityLevel

        for (index, part) in parts.enumerated() {
            let normalizedPart = part.replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "’", with: "")
            if hasHyphen, index < parts.count - 1, ["co", "re", "pre", "pro", "anti", "non", "de"].contains(normalizedPart) {
                continue
            }

            let expanded = WordPowerText.expandContraction(part)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { $0.range(of: #"^[a-z]+$"#, options: .regularExpression) != nil }

            for word in expanded {
                let directFamiliarity = TextAnalysis.wordFamiliarity(word, learningRecords: learningRecords)
                let lemma = WordPowerText.simpleLemmatize(word, catalog: catalog, learningRecords: learningRecords, contextWords: contextWords)
                let lemmaFamiliarity = TextAnalysis.wordFamiliarity(lemma, learningRecords: learningRecords)
                let familiarity = max(directFamiliarity, lemmaFamiliarity)
                if familiarity < selectedFamiliarity {
                    selectedFamiliarity = familiarity
                    if lemma != word, (catalog.labels[lemma] != nil || learningRecords[lemma] != nil) {
                        selectedActionWord = lemma
                    } else {
                        selectedActionWord = word
                    }
                }
            }
        }

        guard !selectedActionWord.isEmpty, selectedFamiliarity < LearningDataCodec.maxFamiliarityLevel else {
            return nil
        }

        switch highlightStyle {
        case .standard:
            if selectedFamiliarity == 0 {
                return TokenHighlightMeta(
                    actionWord: selectedActionWord,
                    foregroundColor: .systemOrange,
                    backgroundColor: UIColor.systemOrange.withAlphaComponent(0.18),
                    showsUnderline: true
                )
            }

            let backgroundColor: UIColor
            switch selectedFamiliarity {
            case 1: backgroundColor = UIColor.systemRed.withAlphaComponent(0.16)
            case 2: backgroundColor = UIColor.systemOrange.withAlphaComponent(0.16)
            case 3: backgroundColor = UIColor.systemYellow.withAlphaComponent(0.18)
            default: backgroundColor = UIColor.systemGreen.withAlphaComponent(0.16)
            }

            return TokenHighlightMeta(
                actionWord: selectedActionWord,
                foregroundColor: .label,
                backgroundColor: backgroundColor,
                showsUnderline: true
            )
        case .reader:
            let foregroundColor: UIColor
            let backgroundColor: UIColor

            if selectedFamiliarity == 0 {
                foregroundColor = UIColor(red: 0.39, green: 0.10, blue: 0.10, alpha: 1)
                backgroundColor = UIColor(red: 0.96, green: 0.82, blue: 0.82, alpha: 1)
            } else {
                foregroundColor = UIColor(red: 0.29, green: 0.21, blue: 0.08, alpha: 1)
                switch selectedFamiliarity {
                case 1: backgroundColor = UIColor(red: 0.91, green: 0.78, blue: 0.45, alpha: 1)
                case 2: backgroundColor = UIColor(red: 0.95, green: 0.84, blue: 0.56, alpha: 1)
                case 3: backgroundColor = UIColor(red: 0.97, green: 0.89, blue: 0.68, alpha: 1)
                default: backgroundColor = UIColor(red: 0.99, green: 0.94, blue: 0.79, alpha: 1)
                }
            }

            return TokenHighlightMeta(
                actionWord: selectedActionWord,
                foregroundColor: foregroundColor,
                backgroundColor: backgroundColor,
                showsUnderline: false
            )
        }
    }

    private static func paragraphStyle(
        lineSpacing: CGFloat,
        lineHeightMultiple: CGFloat
    ) -> NSParagraphStyle {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = lineSpacing
        paragraphStyle.lineHeightMultiple = lineHeightMultiple
        return paragraphStyle
    }
}

struct InteractiveTextView: UIViewRepresentable {
    let attributedText: NSAttributedString
    var onAction: (WordActionContext) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onAction: onAction)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.maximumNumberOfLines = 0
        textView.textContainer.widthTracksTextView = true
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textView.linkTextAttributes = [:]
        textView.delegate = context.coordinator
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        textView.attributedText = attributedText
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let targetWidth = proposal.width ?? uiView.bounds.width
        guard targetWidth > 0 else { return nil }
        return CGSize(
            width: targetWidth,
            height: HighlightTextBuilder.measureHeight(for: attributedText, width: targetWidth)
        )
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        let onAction: (WordActionContext) -> Void

        init(onAction: @escaping (WordActionContext) -> Void) {
            self.onAction = onAction
        }

        @available(iOS 17.0, *)
        func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
            guard case let .link(url) = textItem.content,
                  let context = HighlightTextBuilder.parseActionURL(url) else {
                return defaultAction
            }

            return UIAction { [onAction] _ in
                onAction(context)
            }
        }
    }
}

struct StarRatingControl: View {
    let value: Int
    var maxValue: Int = 5
    var onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...maxValue, id: \.self) { index in
                Button {
                    onChange(value == index ? 0 : index)
                } label: {
                    Image(systemName: index <= value ? "star.fill" : "star")
                        .foregroundStyle(index <= value ? Color.yellow : Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct TagChip: View {
    let tag: WordTag

    var body: some View {
        Text(tag.rawValue)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tag.color.opacity(0.16), in: Capsule())
            .foregroundStyle(tag.color)
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(message)
        )
    }
}

struct MaterialOpenPromptView: View {
    let title: String
    let message: String
    let systemImage: String
    let buttonTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title3.weight(.semibold))
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }

            Button(action: action) {
                Label(buttonTitle, systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }
}

struct MaterialLibraryPickerSheet: View {
    @ObservedObject var appModel: AppModel

    let kind: MaterialKind
    let title: String

    @Environment(\.dismiss) private var dismiss

    @State private var errorMessage = ""

    private var materials: [MaterialRecord] {
        appModel.sortedMaterials.filter { $0.kind == kind }
    }

    var body: some View {
        NavigationStack {
            Group {
                if materials.isEmpty {
                    EmptyStateView(
                        title: emptyStateTitle,
                        message: emptyStateMessage,
                        systemImage: emptyStateSystemImage
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(24)
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(materials) { material in
                                Button {
                                    open(material)
                                } label: {
                                    MaterialLibraryRow(material: material)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(20)
                    }
                    .background(AppTheme.workspaceBackground)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Cannot Open Material", isPresented: errorBinding) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }

    private var emptyStateTitle: String {
        switch kind {
        case .video:
            return "No video materials yet"
        case .article:
            return "No article materials yet"
        }
    }

    private var emptyStateMessage: String {
        switch kind {
        case .video:
            return "Import a local video with subtitles from Library first, then choose it here."
        case .article:
            return "Import or save an article from Library first, then choose it here."
        }
    }

    private var emptyStateSystemImage: String {
        switch kind {
        case .video:
            return "play.rectangle"
        case .article:
            return "book"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { !errorMessage.isEmpty },
            set: { isPresented in
                if !isPresented {
                    errorMessage = ""
                }
            }
        )
    }

    private func open(_ material: MaterialRecord) {
        Task {
            do {
                try await appModel.reopenMaterial(material)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct MaterialLibraryRow: View {
    let material: MaterialRecord

    private static let lastUsedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: material.kind == .video ? "play.rectangle.fill" : "doc.text.fill")
                .font(.title2)
                .foregroundStyle(material.kind == .video ? Color.accentColor : Color.orange)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 6) {
                Text(material.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(detailLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(lastUsedLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.panelSecondaryBackground, in: RoundedRectangle(cornerRadius: 18))
    }

    private var detailLabel: String {
        switch material.kind {
        case .article:
            return "Article"
        case .video where material.hasVideo:
            return material.subtitleFileName
        case .video:
            return "Subtitle only · \(material.subtitleFileName)"
        }
    }

    private var lastUsedLabel: String {
        Self.lastUsedFormatter.string(from: Date(timeIntervalSince1970: material.lastUsedAt))
    }
}

struct WordActionSheet: View {
    @ObservedObject var appModel: AppModel
    let context: WordActionContext

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(context.displayToken)
                        .font(.title2.weight(.semibold))
                    Text(context.targetWord)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if !appModel.wordCatalog.tags(for: context.targetWord).isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(appModel.wordCatalog.tags(for: context.targetWord), id: \.self) { tag in
                                    TagChip(tag: tag)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Familiarity")
                        .font(.headline)
                    StarRatingControl(
                        value: TextAnalysis.wordFamiliarity(context.targetWord, learningRecords: appModel.learningRecords)
                    ) { newValue in
                        appModel.updateFamiliarity(for: context.targetWord, familiarity: newValue)
                    }
                }

                HStack {
                    Button("Copy Word") {
                        UIPasteboard.general.string = context.displayToken
                    }
                    .buttonStyle(.bordered)

                    Button("Clear Rating", role: .destructive) {
                        appModel.updateFamiliarity(for: context.targetWord, familiarity: 0)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .padding(24)
            .navigationTitle("Word Actions")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        appModel.dismissWordAction()
                    }
                }
            }
        }
    }
}
