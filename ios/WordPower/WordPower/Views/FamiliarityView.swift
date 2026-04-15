import SwiftUI

struct FamiliarityView: View {
    @ObservedObject var appModel: AppModel

    @State private var pendingDeleteWord: String?

    private let contentMaxWidth: CGFloat = AppLayout.standardContentMaxWidth
    private let filters: [Int?] = [nil, 1, 2, 3, 4]
    private let wordColumnWidth: CGFloat = 260
    private let ratingColumnWidth: CGFloat = 150
    private let tagColumnWidth: CGFloat = 120
    private let updatedAtColumnWidth: CGFloat = 120
    private let rowColumnSpacing: CGFloat = 20

    var body: some View {
        Group {
            if appModel.learningRecords.isEmpty {
                EmptyStateView(
                    title: "No familiarity data yet",
                    message: "Rate words in Vocabulary, Reader, or Player to review them here.",
                    systemImage: "star"
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Familiarity Review")
                                .font(.title2.weight(.semibold))
                            Text("Browse your 1-star to 4-star words and adjust their level anytime.")
                                .foregroundStyle(.secondary)
                            Picker("Filter", selection: familiarityFilterBinding) {
                                Text("All 1-4").tag(Int?.none)
                                Text("1 Star").tag(Int?.some(1))
                                Text("2 Stars").tag(Int?.some(2))
                                Text("3 Stars").tag(Int?.some(3))
                                Text("4 Stars").tag(Int?.some(4))
                            }
                            .pickerStyle(.segmented)
                        }

                        if appModel.familiarityRows.isEmpty {
                            EmptyStateView(
                                title: "No words in this bucket",
                                message: "Try another star filter or rate more words.",
                                systemImage: "tray"
                            )
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(appModel.familiarityRows) { row in
                                    familiarityRow(row)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.panelBackground, in: RoundedRectangle(cornerRadius: 18))
                                }
                            }
                        }
                    }
                    .frame(maxWidth: contentMaxWidth, alignment: .leading)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .alert(
            "Delete familiarity?",
            isPresented: deleteConfirmationPresented,
            presenting: pendingDeleteWord
        ) { word in
            Button("Delete", role: .destructive) {
                appModel.updateFamiliarity(for: word, familiarity: 0)
                pendingDeleteWord = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteWord = nil
            }
        } message: { word in
            Text("Delete the familiarity record for \"\(word)\"?")
        }
    }

    private var familiarityFilterBinding: Binding<Int?> {
        Binding(
            get: { appModel.selectedFamiliarityFilter },
            set: { appModel.selectedFamiliarityFilter = $0 }
        )
    }

    private var deleteConfirmationPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteWord != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteWord = nil
                }
            }
        )
    }

    private func familiarityRow(_ row: FamiliarityReviewRow) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: rowColumnSpacing) {
                Text(row.word)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: wordColumnWidth, alignment: .leading)

                StarRatingControl(value: row.familiarity) { newValue in
                    appModel.updateFamiliarity(for: row.word, familiarity: newValue)
                }
                .frame(width: ratingColumnWidth, alignment: .leading)

                familiarityLabel(for: row)
                    .frame(width: tagColumnWidth, alignment: .leading)

                Spacer(minLength: 0)

                if !row.updatedAt.isEmpty {
                    Text(row.updatedAt)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(width: updatedAtColumnWidth, alignment: .trailing)
                }

                clearFamiliarityButton(for: row.word)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    Text(row.word)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !row.updatedAt.isEmpty {
                        Text(row.updatedAt)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    clearFamiliarityButton(for: row.word)
                }

                HStack(spacing: rowColumnSpacing) {
                    StarRatingControl(value: row.familiarity) { newValue in
                        appModel.updateFamiliarity(for: row.word, familiarity: newValue)
                    }
                    .frame(width: ratingColumnWidth, alignment: .leading)

                    familiarityLabel(for: row)
                        .frame(width: tagColumnWidth, alignment: .leading)

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func clearFamiliarityButton(for word: String) -> some View {
        Button {
            pendingDeleteWord = word
        } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Delete familiarity for \(word)")
    }

    private func familiarityLabel(for row: FamiliarityReviewRow) -> some View {
        let primaryTag = row.tags.first ?? .offList

        return Text(primaryTag.rawValue)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(primaryTag.color.opacity(0.14), in: Capsule())
            .foregroundStyle(primaryTag.color)
    }
}
