import KrasnotchKit
import SwiftUI

/// Top row of the menu: what the glow is showing right now.
struct MenuStatusRow: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    HStack(spacing: 10) {
      StatusDot(color: model.liveState.map { model.config[$0].primaryColor } ?? .secondary, lit: model.liveState != nil)
      VStack(alignment: .leading, spacing: 1) {
        Text(model.liveState?.title ?? "Idle")
          .font(.system(size: 13, weight: .semibold))
        Text(subtitle)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }
      Spacer()
    }
    .padding(.horizontal, 14)
    .frame(maxHeight: .infinity)
  }

  private var subtitle: String {
    if let error = model.serverError { return error }
    let agents = model.hooksInstalled ? "Claude Code connected" : "No agent connected"
    switch model.sessionCount {
    case 0: return agents
    case 1: return "1 session · \(agents)"
    default: return "\(model.sessionCount) sessions · \(agents)"
    }
  }
}

/// Brightness slider between two sun glyphs, like a volume row.
struct MenuBrightnessRow: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    HStack(spacing: 8) {
      Image(systemName: "sun.min.fill").foregroundStyle(.secondary)
      Slider(value: $model.config.brightness, in: 0.2...1)
        .controlSize(.small)
      Image(systemName: "sun.max.fill").foregroundStyle(.secondary)
    }
    .padding(.horizontal, 14)
    .frame(maxHeight: .infinity)
  }
}

struct StatusDot: View {
  let color: Color
  let lit: Bool

  var body: some View {
    Circle()
      .fill(color)
      .frame(width: 10, height: 10)
      .shadow(color: lit ? color.opacity(0.9) : .clear, radius: 5)
      .padding(4)
  }
}

extension GlowStyle {
  var swiftUIColors: [Color] {
    let parsed = colors.compactMap(RGBA.init(hex:)).map { Color(cgColor: $0.cgColor) }
    return parsed.isEmpty ? [.white] : parsed
  }

  var primaryColor: Color { swiftUIColors[0] }
}
