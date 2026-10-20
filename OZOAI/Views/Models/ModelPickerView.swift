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

    private var availableModels: [AIModel] {
        filteredModels.filter { $0.isAvailable(on: settings.provider) }
    }

    private var unavailableModels: [AIModel] {
        filteredModels.filter { !$0.isAvailable(on: settings.provider) }
    }

    private var availableCount: Int {
        AIModel.all.filter { $0.isAvailable(on: settings.provider) }.count
    }

    private var freeCount: Int {
        AIModel.all.filter {
            $0.isAvailable(on: settings.provider) && $0.isFree(on: settings.provider)
        }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    providerSummary

                    if filteredModels.isEmpty {
                        emptyState
                    } else {
                        if !availableModels.isEmpty {
                            modelGroup(
                                title: availableGroupTitle,
                                models: availableModels
                            )
                        }

                        if !unavailableModels.isEmpty {
                            modelGroup(
                                title: "Not available on \(settings.provider.shortName)",
                                models: unavailableModels
                            )
                        }
                    }

                    footnote
                }
                .padding(.horizontal, 15)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(background.ignoresSafeArea())
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

    // MARK: - Provider summary

    private var providerSummary: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(providerTint.opacity(0.13))
                    .frame(width: 44, height: 44)

                Image(systemName: settings.provider.symbol)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(providerTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(settings.provider.displayName)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(providerSummaryText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 4)

            VStack(spacing: 1) {
                Text("\(availableCount)")
                    .font(.system(size: 19, weight: .bold, design: .rounded))
                    .foregroundStyle(providerTint)
                Text("of \(AIModel.all.count)")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(providerTint.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
        .padding(13)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [providerTint.opacity(0.075), OZOTheme.violet.opacity(0.035)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(providerTint.opacity(0.16), lineWidth: 0.8)
        )
    }

    private var providerSummaryText: String {
        switch settings.provider {
        case .openCode:
            return "All ten Zen models are included and free for a limited time."
        case .openRouter:
            return "\(availableCount) supported models · \(freeCount) free, \(availableCount - freeCount) use credits."
        case .anthropic:
            return "Four Claude models, billed through your Anthropic account."
        }
    }

    private var providerTint: Color {
        switch settings.provider {
        case .openCode: return OZOTheme.accent
        case .openRouter: return OZOTheme.violet
        case .anthropic: return Color(hex: 0xEA580C)
        }
    }

    private var availableGroupTitle: String {
        switch settings.provider {
        case .openCode: return "All OpenCode models"
        case .openRouter: return "Available on OpenRouter"
        case .anthropic: return "Available on Claude"
        }
    }

    // MARK: - Groups

    private func modelGroup(title: String, models: [AIModel]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                    .tracking(0.9)
                    .foregroundStyle(.tertiary)

                Text("\(models.count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.quaternary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1.5)
                    .background(Color.primary.opacity(0.04), in: Capsule())

                Spacer()
            }
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(models) { model in
                    modelButton(model)
                }
            }
        }
    }

    @ViewBuilder
    private func modelButton(_ model: AIModel) -> some View {
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
                    Label(note, systemImage: "lock.fill")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.orange)
                        .padding(.top, 1)
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
        .opacity(isAvailable ? 1 : 0.56)
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
        case "OpenCode only", "Claude only", "Unavailable": return .gray
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
        .accessibilityHidden(true)
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .light))
                .foregroundStyle(.tertiary)
                .frame(width: 48, height: 48)
                .background(Color.primary.opacity(0.04), in: Circle())

            Text("No models match “\(query)”")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Try a model name, maker or capability.")
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
    }

    private var footnoteText: String {
        switch settings.provider {
        case .openCode:
            return "All ten Zen models are free on OpenCode Zen. Claude models are Anthropic-only."
        case .openRouter:
            return "Free OpenRouter models are marked. Claude models are Anthropic-only."
        case .anthropic:
            return "Claude usage is billed by Anthropic. OpenCode and OpenRouter models are unavailable here."
        }
    }

    private var footnote: some View {
        VStack(spacing: 4) {
            Text(footnoteText)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Text("A filled bullet marks the model currently in use.")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    private var background: some View {
        ZStack {
            OZOTheme.groupedBackground

            RadialGradient(
                colors: [providerTint.opacity(0.055), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )
        }
    }
}
