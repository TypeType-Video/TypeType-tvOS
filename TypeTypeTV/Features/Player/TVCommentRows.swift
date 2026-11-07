import SwiftUI

struct TVCommentRows: View {
  @ObservedObject var comments: LiveCommentsViewModel
  @ObservedObject var threads: LiveCommentThreads
  @FocusState private var focused: String?

  private static let prefetch = 3

  var body: some View {
    Group {
      switch comments.state {
      case .idle, .loading:
        status("Loading comments", systemImage: "ellipsis") {}
      case let .failed(message):
        status(LocalizedStringKey(message), systemImage: "arrow.clockwise") { Task { await comments.reload() } }
      case .hidden, .disabled:
        status("No comments to show for this video", systemImage: "text.bubble") {}
      case .loaded where comments.comments.isEmpty:
        status("No comments to show for this video", systemImage: "text.bubble") {}
      case .loaded:
        ForEach(Array(comments.comments.enumerated()), id: \.element.id) { index, comment in
          TVCommentCard(comment: comment, reply: false, repliesOpen: threads.thread(for: comment).isVisible) {
            Task { await threads.toggle(comment) }
          }
          .focused($focused, equals: comment.id)
          .onAppear {
            if index >= comments.comments.count - Self.prefetch { Task { await comments.loadMore() } }
          }
          replies(of: comment)
        }
        if comments.isLoadingMore { ProgressView().padding(.vertical, 12) }
      }
    }
    .task {
      await comments.prepare()
      focused = comments.comments.first?.id
    }
  }

  @ViewBuilder
  private func replies(of comment: LiveCommentItem) -> some View {
    let thread = threads.thread(for: comment)
    if thread.isVisible || thread.isLoading || thread.errorMessage != nil {
      ForEach(thread.replies) { reply in
        TVCommentCard(comment: reply, reply: true, repliesOpen: false) {}.padding(.leading, 28)
      }
      if thread.isLoading {
        status("Loading the replies", systemImage: "ellipsis", indent: true) {}
      } else if thread.errorMessage != nil {
        status(thread.replies.isEmpty ? "Could not load the replies. Press OK to try again."
               : "Could not load more replies. Press OK to try again.", systemImage: "arrow.clockwise", indent: true) {
          Task { await thread.replies.isEmpty ? threads.toggle(comment) : threads.loadMore(comment) }
        }
      } else {
        if thread.nextPage?.isEmpty == false {
          status("Show more replies", systemImage: "chevron.down", indent: true) { Task { await threads.loadMore(comment) } }
        }
        status("Hide the replies", systemImage: "chevron.up", indent: true) {
          Task {
            await threads.toggle(comment)
            focused = comment.id
          }
        }
      }
    }
  }

  private func status(
    _ text: LocalizedStringKey, systemImage: String, indent: Bool = false, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      Label(text, systemImage: systemImage).font(TVType.title).frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(TVReadingRowStyle())
    .padding(.leading, indent ? 28 : 0)
  }
}

private struct TVCommentCard: View {
  let comment: LiveCommentItem
  let reply: Bool
  let repliesOpen: Bool
  let onSelect: () -> Void

  var body: some View {
    let canOpen = !reply && comment.repliesPage?.isEmpty == false
    Button(action: onSelect) {
      VStack(alignment: .leading, spacing: 10) {
        HStack(spacing: 14) {
          ZStack {
            Circle().fill(TVPalette.surfaceRaised)
            Text(verbatim: String(comment.author.prefix(1)).uppercased()).font(TVType.label)
            TVRemoteImage(url: comment.authorAvatar).clipShape(Circle())
          }
          .frame(width: reply ? 40 : 48, height: reply ? 40 : 48)
          Text(verbatim: comment.author).font(TVType.title).lineLimit(1)
          Text(verbatim: comment.publishedDisplay).font(TVType.meta).foregroundStyle(TVPalette.textMid).lineLimit(1)
          Spacer(minLength: 0)
          if comment.isPinned { Image(systemName: "pin.fill").foregroundStyle(TVPalette.accentSoft) }
          if comment.isHeartedByUploader { Image(systemName: "heart.fill").foregroundStyle(TVPalette.accent) }
        }
        Text(verbatim: comment.displayText).font(TVType.body).lineLimit(reply ? 6 : 8)
        HStack(spacing: 20) {
          if comment.likeCount > 0 { Text("\(comment.textualLikeCount) likes") }
          if !reply, comment.replyCount > 0 {
            Text(comment.replyCount == 1 ? "\(comment.replyCount) reply" : "\(comment.replyCount) replies")
          }
          if canOpen { Image(systemName: repliesOpen ? "chevron.up" : "chevron.down").foregroundStyle(TVPalette.accentSoft) }
        }
        .font(TVType.meta)
        .foregroundStyle(TVPalette.textMid)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .buttonStyle(TVReadingRowStyle())
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(Text(verbatim: "\(comment.author): \(comment.displayText)"))
    .accessibilityHint(canOpen && !repliesOpen ? Text("Press OK to show the replies.") : Text(verbatim: ""))
  }
}

private struct TVReadingRowStyle: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    TVReadingRowLabel(configuration: configuration)
  }
}

private struct TVReadingRowLabel: View {
  let configuration: ButtonStyleConfiguration
  @Environment(\.isFocused) private var isFocused

  var body: some View {
    configuration.label
      .foregroundStyle(TVPalette.textHigh)
      .padding(.leading, 24).padding(.trailing, 20).padding(.vertical, 16)
      .background(isFocused ? TVPalette.surfaceRaised : TVPalette.ink.opacity(0.6))
      .overlay(alignment: .leading) { Rectangle().fill(isFocused ? TVPalette.accent : .clear).frame(width: 6) }
      .clipShape(RoundedRectangle(cornerRadius: TVDimens.panelRadius))
      .scaleEffect(isFocused ? 1.01 : 1)
      .animation(.easeOut(duration: 0.14), value: isFocused)
  }
}
