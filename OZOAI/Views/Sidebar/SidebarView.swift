import Foundation
import SwiftUI

struct SidebarView: View {
    let topInset: CGFloat
    let bottomInset: CGFloat
    let onClose: () -> Void
    let onOpenSettings: () -> Void

    @EnvironmentObject private var store: ChatStore
    @EnvironmentObject private var settings: AppSettings

    @State private var searchText = ""
    @State private var renameTarget: Conversation?
    @State private var renameText = ""
    @State private var showRenameAlert = false
    @State private var deleteTarget: Conversation?
    @State private var showDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            header
            newChatButton
            searchField
            conversationList
            footer
        }
        .alert("Rename chat", isPresented: $showRenameAlert) {
            TextField("Chat name", text: $renameText)
            Button("Cancel", role: .cancel) { renameTarget = nil }
            Button("Save") {
                if let target = renameTarget {
                    store.rename(target, to: renameText)
                    Haptics.success(settings.hapticsEnabled)
                }
                renameTarget = nil
            }
        }
        .confirmationDialog(
            "Delete this chat?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let target = deleteTarget {
                    store.delete(target)
                    Haptics.success(settings.hapticsEnabled)
                }
                deleteTarget = nil
            }
            Button("Cancel", role: .cancel) { deleteTarget = nil }
        } message: {
            Text(deleteTarget?.title ?? "This conversation will be permanently removed.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                OZOWordmark(compact: true)

                HStack(spacing: 4) {
                    Circle()
                        .fill(settings.hasAPIKey ? OZOTheme.positive : OZOTheme.warning)
                        .frame(width: 4.5, height: 4.5)

                    Text(settings.hasAPIKey
                         ? "\(settings.provider.shortName) · \(store.conversations.count) chats"
                         : "Add your API key")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.leading, 2)
            }

            Spacer()

            Button {
                Haptics.tap(settings.hapticsEnabled)
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(Color.primary.opacity(0.055)))
                    .overlay(Circle().strokeBorder(OZOTheme.hairline, lineWidth: 0.7))
            }
            .buttonStyle(OZOPressStyle())
            .accessibilityLabel("Close chats")
        }
        .padding(.top, topInset + 10)
        .padding(.horizontal, 16)
        .padding(.bottom, 13)
    }

    // MARK: - New chat + search

    private var newChatButton: some View {
        Button {
            Haptics.tap(settings.hapticsEnabled)
            store.newChat()
            onClose()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .semibold))

                Text("New chat")
                    .font(.system(size: 14, weight: .semibold))

                Spacer()

                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 13)
            .padding(.vertical, 11)
            .background(
                OZOTheme.brandGradient,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.13), lineWidth: 0.7)
            )
            .shadow(color: OZOTheme.accent.opacity(0.22), radius: 12, y: 5)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(OZOPressStyle())
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }

    private var searchField: some View {
        HStack(spacing: 7) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.tertiary)

            TextField("Search chats", text: $searchText)
                .font(.system(size: 13))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.primary.opacity(0.038))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(OZOTheme.hairline, lineWidth: 0.7)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Conversations

    @ViewBuilder
    private var conversationList: some View {
        if groups.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(groups) { group in
                        HStack(spacing: 5) {
                            Text(group.title.uppercased())
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .tracking(0.9)
                                .foregroundStyle(.tertiary)

                            Text("\(group.conversations.count)")
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .foregroundStyle(.quaternary)
                                .padding(.horizontal, 4.5)
                                .padding(.vertical, 1.5)
                                .background(Color.primary.opacity(0.04), in: Capsule())

                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 13)
                        .padding(.bottom, 5)

                        ForEach(group.conversations) { conversation in
                            conversationRow(conversation)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private func conversationRow(_ conversation: Conversation) -> some View {
        let isSelected = conversation.id == store.currentID
        let model = AIModel.model(for: conversation.modelID)

        return HStack(spacing: 0) {
            Button {
                Haptics.soft(settings.hapticsEnabled)
                withAnimation(.easeOut(duration: 0.2)) {
                    store.select(conversation)
                }
                onClose()
            } label: {
                HStack(alignment: .center, spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill((isSelected ? OZOTheme.accent : model.tint).opacity(0.12))
                            .frame(width: 30, height: 30)

                        Image(systemName: model.symbol)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(isSelected ? OZOTheme.accent : model.tint)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(conversation.title)
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Text(model.shortName)
                                .lineLimit(1)
                            Text("·")
                            Text(conversation.updatedAt.ozoRelativeLabel)
                        }
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                    }

                    Spacer(minLength: 2)
                }
                .contentShape(Rectangle())
                .padding(.leading, 9)
                .padding(.vertical, 7)
            }
            .buttonStyle(.plain)

            Menu {
                Button {
                    renameTarget = conversation
                    renameText = conversation.title
                    showRenameAlert = true
                } label: {
                    Label("Rename", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    deleteTarget = conversation
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.secondary : Color.secondary.opacity(0.55))
                    .frame(width: 27, height: 34)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(conversation.title)")
        }
        .padding(.trailing, 4)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? OZOTheme.accent.opacity(0.095) : Color.clear)
        )
        .overlay(alignment: .leading) {
            if isSelected {
                Capsule()
                    .fill(OZOTheme.accent)
                    .frame(width: 3, height: 22)
                    .padding(.leading, 1)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .contextMenu {
            Button {
                renameTarget = conversation
                renameText = conversation.title
                showRenameAlert = true
            } label: {
                Label("Rename", systemImage: "pencil")
            }

            Button(role: .destructive) {
                deleteTarget = conversation
                showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .animation(.easeOut(duration: 0.18), value: isSelected)
    }

    private var emptyState: some View {
        VStack(spacing: 11) {
            Spacer(minLength: 30)

            ZStack {
                Circle()
                    .fill(OZOTheme.accent.opacity(0.10))
                    .frame(width: 58, height: 58)

                Circle()
                    .strokeBorder(OZOTheme.accent.opacity(0.14), lineWidth: 1)
                    .frame(width: 44, height: 44)

                Image(systemName: searchText.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass")
                    .font(.system(size: 21, weight: .light))
                    .foregroundStyle(searchText.isEmpty ? OZOTheme.accent : Color.secondary)
            }

            Text(searchText.isEmpty ? "No chats yet" : "No matches")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(searchText.isEmpty
                 ? "Start a conversation and it will appear here."
                 : "Try a different search term.")
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(OZOTheme.hairline)
                .frame(height: 0.5)

            Button(action: onOpenSettings) {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(OZOTheme.accent.opacity(0.10))
                            .frame(width: 32, height: 32)

                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(OZOTheme.accent)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Settings")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)

                        HStack(spacing: 4) {
                            Circle()
                                .fill(settings.hasAPIKey ? OZOTheme.positive : OZOTheme.warning)
                                .frame(width: 4.5, height: 4.5)

                            Text(settings.hasAPIKey
                                 ? "\(settings.provider.shortName) connected"
                                 : "Add your API key")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("OZO AI 1.0 · \(settings.provider.displayName)")
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(.quaternary)
                .padding(.bottom, max(bottomInset, 10))
                .padding(.top, 1)
        }
    }

    // MARK: - Grouping

    private var groups: [ConversationGroup] {
        let filtered = store.sortedConversations.filter { $0.matches(searchText) }
        let calendar = Calendar.current

        var today: [Conversation] = []
        var yesterday: [Conversation] = []
        var week: [Conversation] = []
        var older: [Conversation] = []

        for conversation in filtered {
            let date = conversation.updatedAt
            if calendar.isDateInToday(date) {
                today.append(conversation)
            } else if calendar.isDateInYesterday(date) {
                yesterday.append(conversation)
            } else if let days = calendar.dateComponents([.day], from: date, to: Date()).day, days < 7 {
                week.append(conversation)
            } else {
                older.append(conversation)
            }
        }

        var result: [ConversationGroup] = []
        if !today.isEmpty { result.append(ConversationGroup(id: "today", title: "Today", conversations: today)) }
        if !yesterday.isEmpty { result.append(ConversationGroup(id: "yesterday", title: "Yesterday", conversations: yesterday)) }
        if !week.isEmpty { result.append(ConversationGroup(id: "week", title: "Previous 7 days", conversations: week)) }
        if !older.isEmpty { result.append(ConversationGroup(id: "older", title: "Older", conversations: older)) }
        return result
    }

    private struct ConversationGroup: Identifiable {
        let id: String
        let title: String
        let conversations: [Conversation]
    }
}
