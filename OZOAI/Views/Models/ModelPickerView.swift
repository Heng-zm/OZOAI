import Foundation
import SwiftUI

struct ModelPickerView: View {
    let selectedID: String
    let onSelect: (AIModel) -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var settings: AppSettings
    @State private var query = ""

    private var filteredModels: [AIModel] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return AIModel.all }
        return AIModel.all.filter { model in
            model.name.localizedCaseInsensitiveContains(needle)
                || model.shortName.localizedCaseInsensitiveContains(needle)
                || model.vendor.localizedCaseInsensitiveContains(needle)
                || model.tagline.localizedCaseInsensitiveContains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    hero

                    if filteredModels.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24, weight: .light))
                                .foregroundStyle(.tertiary)
                            Text("No models match “\(query)”")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                    } else {
                        ForEach(filteredModels) { model in
                            let isAvailable = model.isAvailable(on: settings.provider)

                            Button {
                                guard isAvailable else { return }
                                Haptics.tap(settings.hapticsEnabled)
                                onSelect(model)
                                dismiss()
                            } label: {
                                modelRow(model)
                            }
                            .buttonStyle(OZOPressStyle(scale: 0.985))
                            .disabled(!isAvailable)
                        }
                    }

                    footnote
                }
                .padding(.horizontal, 15)
                .padding(.top, 6)
                .padding(.bottom, 22)
            }
            .background(OZOTheme.groupedBackground)
            .navigationTitle("Choose a model")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(
                text: $query,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Search models"
            )
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
        .presentationCornerRadius(28)
    }

    // MARK: - Hero

    private var hero: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Ten models. One place.")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Text(settings.provider == .openCode
                     ? "Pick the brain that fits your task. All ten models are free on OpenCode Zen."
                     : "Pick the brain that fits your task. Free and paid OpenRouter models are marked below.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            ZStack {
                Circle()
                    .fill(OZOTheme.brandGradient)
                    .frame(width: 46, height: 46)
                Image(systemName: "sparkles")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .shadow(color: OZOTheme.accent.opacity(0.3), radius: 10, y: 4)
        }
        .padding(15)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(OZOTheme.accent.opacity(0.065))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(OZOTheme.accent.opacity(0.16), lineWidth: 0.8)
        )
        .padding(.bottom, 4)
    }

    // MARK: - Row

    private func modelRow(_ model: AIModel) -> some View {
        let isSelected = model.id == selectedID
        let isAvailable = model.isAvailable(on: settings.provider)

        return HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(model.tint.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: model.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(model.tint)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(model.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let badge = model.badgeText(on: settings.provider) {
                        OZOBadge(text: badge, tint: badgeTint(for: badge))
                    }
                }

                Text(model.vendor.uppercased())
                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.tertiary)

                Text(model.tagline)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)

                if !isAvailable, let note = model.availabilityNote(on: settings.provider) {
                    Text(note)
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 4) {
                    ForEach(model.badges, id: \.self) { badge in
                        OZOBadge(text: badge, tint: model.tint)
                    }
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 3)

            selectionIndicator(isSelected: isSelected, tint: model.tint)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? model.tint.opacity(0.065) : OZOTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    isSelected ? model.tint.opacity(0.42) : OZOTheme.hairline,
                    lineWidth: isSelected ? 1.1 : 0.8
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .opacity(isAvailable ? 1 : 0.58)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(model.name), \(model.tagline)")
        .accessibilityValue(
            isSelected
                ? "Selected"
                : (isAvailable ? "Not selected" : "Not available on \(settings.provider.displayName)")
        )
    }

    private func badgeTint(for badge: String) -> Color {
        switch badge {
        case "Free": return .green
        case "Credits": return .orange
        case "OpenCode only": return .gray
        default: return OZOTheme.accent
        }
    }

    private func selectionIndicator(isSelected: Bool, tint: Color) -> some View {
        ZStack {
            Circle()
                .strokeBorder(
                    isSelected ? tint : Color.secondary.opacity(0.25),
                    lineWidth: 1.7
                )
                .frame(width: 20, height: 20)

            if isSelected {
                Circle()
                    .fill(tint)
                    .frame(width: 10, height: 10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(width: 22, height: 24)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isSelected)
    }

    private var footnote: some View {
        VStack(spacing: 4) {
            Text(settings.provider == .openCode
                 ? "All ten models are free on OpenCode Zen."
                 : "Free OpenRouter models are marked. Big Pickle and LongCat 2.5 Preview are OpenCode-only.")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Text("A bullet marks the model currently in use.")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .padding(.top, 10)
    }
}
