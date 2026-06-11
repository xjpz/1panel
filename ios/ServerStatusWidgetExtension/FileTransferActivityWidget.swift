import ActivityKit
import SwiftUI
import WidgetKit

@available(iOSApplicationExtension 16.1, *)
struct FileTransferActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: FileTransferActivityAttributes.self) { context in
      FileTransferActivityView(context: context, compact: false)
        .activityBackgroundTint(Color(.systemBackground))
        .activitySystemActionForegroundColor(.accentColor)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          FileTransferIslandTitle(context: context)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(percent(context.state.progress))
            .font(.system(.headline, design: .rounded).weight(.semibold))
            .monospacedDigit()
        }
        DynamicIslandExpandedRegion(.bottom) {
          FileTransferActivityView(context: context, compact: true)
        }
      } compactLeading: {
        Image(systemName: iconName(context.attributes.direction))
          .foregroundStyle(tintColor(context.attributes.direction))
      } compactTrailing: {
        Text(percent(context.state.progress))
          .font(.system(.caption2, design: .rounded).weight(.semibold))
          .monospacedDigit()
      } minimal: {
        Image(systemName: iconName(context.attributes.direction))
          .foregroundStyle(tintColor(context.attributes.direction))
      }
      .keylineTint(tintColor(context.attributes.direction))
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct FileTransferActivityView: View {
  let context: ActivityViewContext<FileTransferActivityAttributes>
  let compact: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 6 : 10) {
      HStack(spacing: 10) {
        Image(systemName: iconName(context.attributes.direction))
          .font(.system(size: compact ? 15 : 18, weight: .semibold))
          .foregroundStyle(tintColor(context.attributes.direction))
          .frame(width: compact ? 18 : 24)

        VStack(alignment: .leading, spacing: 2) {
          Text(title(context.attributes.direction, status: context.state.status))
            .font(compact ? .caption.weight(.semibold) : .headline.weight(.semibold))
          Text(context.attributes.fileName)
            .font(compact ? .caption2 : .subheadline)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        Text(percent(context.state.progress))
          .font(.system(compact ? .caption : .headline, design: .rounded).weight(.semibold))
          .monospacedDigit()
      }

      ProgressView(value: context.state.progress)
        .tint(tintColor(context.attributes.direction))

      HStack {
        Text(byteProgress(context.state))
        Spacer()
        if context.state.status == "running" {
          Text(speed(context.state.speedBytesPerSecond))
        } else {
          Text(statusText(context.state.status))
        }
      }
      .font(.caption2)
      .foregroundStyle(.secondary)
      .monospacedDigit()
    }
    .padding(
      compact
        ? EdgeInsets()
        : EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
    )
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct FileTransferIslandTitle: View {
  let context: ActivityViewContext<FileTransferActivityAttributes>

  var body: some View {
    HStack(spacing: 6) {
      Image(systemName: iconName(context.attributes.direction))
        .foregroundStyle(tintColor(context.attributes.direction))
      Text(title(context.attributes.direction, status: context.state.status))
        .font(.subheadline.weight(.semibold))
        .lineLimit(1)
    }
  }
}

private func title(_ direction: String, status: String) -> String {
  if status == "completed" {
    return localized("transfer.activity.completed")
  }
  if status == "failed" {
    return localized("transfer.activity.failed")
  }
  if status == "cancelled" {
    return localized("transfer.activity.cancelled")
  }
  if status == "preparing" {
    return localized("transfer.activity.preparing")
  }
  return direction == "upload"
    ? localized("transfer.activity.uploading")
    : localized("transfer.activity.downloading")
}

private func statusText(_ status: String) -> String {
  switch status {
  case "completed":
    return localized("transfer.activity.completed")
  case "failed":
    return localized("transfer.activity.failed")
  case "cancelled":
    return localized("transfer.activity.cancelled")
  case "preparing":
    return localized("transfer.activity.preparing")
  default:
    return localized("transfer.activity.running")
  }
}

private func iconName(_ direction: String) -> String {
  direction == "upload" ? "arrow.up.circle.fill" : "arrow.down.circle.fill"
}

private func tintColor(_ direction: String) -> Color {
  direction == "upload" ? .green : .blue
}

private func percent(_ progress: Double) -> String {
  let value = min(max(progress, 0), 1) * 100
  return "\(Int(value.rounded()))%"
}

@available(iOSApplicationExtension 16.1, *)
private func byteProgress(
  _ state: FileTransferActivityAttributes.ContentState
) -> String {
  guard state.totalBytes > 0 else {
    return bytes(state.transferredBytes)
  }
  return "\(bytes(state.transferredBytes)) / \(bytes(state.totalBytes))"
}

private func speed(_ value: Double) -> String {
  "\(bytes(Int64(value)))\(localized("transfer.activity.per_second"))"
}

private func bytes(_ value: Int64) -> String {
  let units = ["B", "KB", "MB", "GB", "TB"]
  var amount = Double(max(value, 0))
  var index = 0
  while amount >= 1024, index < units.count - 1 {
    amount /= 1024
    index += 1
  }
  if index == 0 || amount >= 10 {
    return "\(Int(amount.rounded()))\(units[index])"
  }
  return String(format: "%.1f%@", amount, units[index])
}

private func localized(_ key: String) -> String {
  NSLocalizedString(key, bundle: .main, comment: "")
}

@available(iOSApplicationExtension 16.1, *)
struct TerminalActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: TerminalActivityAttributes.self) { context in
      TerminalActivityView(context: context)
        .activityBackgroundTint(Color(.systemBackground))
        .activitySystemActionForegroundColor(.accentColor)
    } dynamicIsland: { context in
      DynamicIsland {
        // Expanded Regions
        DynamicIslandExpandedRegion(.leading) {
          HStack(spacing: 6) {
            Image(systemName: "terminal.fill")
              .foregroundStyle(.green)
            Text(context.state.title)
              .font(.subheadline.weight(.bold))
              .lineLimit(1)
          }
        }
        DynamicIslandExpandedRegion(.trailing) {
          HStack(spacing: 4) {
            Circle()
              .fill(context.state.status == "connected" ? Color.green : Color.red)
              .frame(width: 6, height: 6)
            Text(context.state.status.uppercased())
              .font(.system(.caption2, design: .rounded).weight(.bold))
              .foregroundStyle(context.state.status == "connected" ? .green : .secondary)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 4) {
            Text(context.state.subtitle)
              .font(.system(.footnote, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
            HStack {
              Spacer()
              Text("Tap to return to session")
                .font(.system(.caption2).weight(.medium))
                .foregroundStyle(.tertiary)
            }
          }
        }
      } compactLeading: {
        Image(systemName: "terminal.fill")
          .foregroundStyle(.green)
      } compactTrailing: {
        Text("RUN")
          .font(.system(.caption2, design: .rounded).weight(.bold))
          .foregroundStyle(.green)
      } minimal: {
        Image(systemName: "terminal.fill")
          .foregroundStyle(.green)
      }
      .keylineTint(.green)
    }
  }
}

@available(iOSApplicationExtension 16.1, *)
private struct TerminalActivityView: View {
  let context: ActivityViewContext<TerminalActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 10) {
        Image(systemName: "terminal.fill")
          .font(.system(size: 18, weight: .semibold))
          .foregroundStyle(.green)
          .frame(width: 24)

        VStack(alignment: .leading, spacing: 2) {
          Text(context.state.title)
            .font(.headline.weight(.semibold))
          Text(context.state.subtitle)
            .font(.system(.subheadline, design: .monospaced))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }

        Spacer(minLength: 8)

        HStack(spacing: 4) {
          Circle()
            .fill(context.state.status == "connected" ? Color.green : Color.red)
            .frame(width: 6, height: 6)
          Text(context.state.status.uppercased())
            .font(.system(.caption, design: .rounded).weight(.bold))
            .foregroundStyle(context.state.status == "connected" ? .green : .secondary)
        }
      }
    }
    .padding(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
  }
}

