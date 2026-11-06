import AppKit
import KrasnotchKit
import Observation
import SwiftUI

@MainActor
@Observable
final class ThreadPillModel {
  var title = ""
  var state: GlowState = .done
  var style = GlowStyle.defaultStyle(for: .done)
  var hasTarget = false
  var visible = false
  var hovering = false
  /// The pill's layout frame in the window, top-left origin. Hover is hit-tested against it.
  var pillRect = CGRect.zero
}

/// The pill that drops out of the notch when a thread finishes or needs you, painted like that state's glow.
struct ThreadPillView: View {
  static let maxTitleWidth: CGFloat = 220
  private static let fontSize: CGFloat = 12
  private static let ink = Color(red: 0x0C / 255, green: 0x0E / 255, blue: 0x11 / 255)

  let model: ThreadPillModel
  let onClick: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    let shown = model.visible
    let style = model.style
    Button(action: onClick) {
      Text(model.title)
        .font(.system(size: Self.fontSize, weight: .semibold))
        .lineLimit(1)
        .truncationMode(.tail)
        .frame(width: titleWidth, alignment: .leading)
        .id(model.title)
        .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
        .foregroundStyle(style.prefersDarkText ? Self.ink : .white)
        .opacity(shown ? 1 : 0)
        .animation(shown ? .smooth(duration: 0.3).delay(0.06) : .smooth(duration: 0.12), value: shown)
        .padding(.horizontal, 11)
        .frame(height: 26)
        .background { PillSurface(style: style, animate: shown && !reduceMotion) }
        .contentShape(Capsule())
    }
    .buttonStyle(PillPressStyle(hovering: model.hovering, reduceMotion: reduceMotion))
    // SwiftUI's onHover stays silent while Krasnotch isn't the active app; the hosting view tracks hover instead.
    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { model.pillRect = $0 }
    .animation(.snappy(duration: 0.22), value: model.hovering)
    .animation(.smooth(duration: 0.3), value: model.title)
    .animation(.smooth(duration: 0.3), value: style)
    // The pill glows in its palette, like the notch does; Magic makes the glow fuller.
    .shadow(color: style.primaryColor.opacity(shown ? glowOpacity : 0), radius: style.magic ? 11 : 7)
    // Tucked up behind the notch until shown; the window's top edge clips it, so it appears to drop out.
    .scaleEffect(reduceMotion || shown ? 1 : 0.55, anchor: .top)
    .offset(y: reduceMotion || shown ? 0 : -12)
    .blur(radius: reduceMotion || shown ? 0 : 6)
    .opacity(shown ? 1 : 0)
    .animation(shown ? .spring(duration: 0.45, bounce: 0.32) : .spring(duration: 0.28, bounce: 0), value: shown)
    .padding(.top, 5)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .accessibilityLabel(model.state == .needsInput ? "\(model.title) needs you" : "\(model.title) is done")
    .accessibilityHint(model.hasTarget ? "Opens the thread" : "Dismisses")
  }

  private var glowOpacity: Double {
    let intensity = min(max(model.style.intensity, 0), 1)
    return model.style.magic ? 0.45 + 0.4 * intensity : 0.25 + 0.35 * intensity
  }

  /// The pill hugs short titles and truncates long ones; measured so width changes animate.
  private var titleWidth: CGFloat {
    let font = NSFont.systemFont(ofSize: Self.fontSize, weight: .semibold)
    let width = (model.title as NSString).size(withAttributes: [.font: font]).width
    return min(ceil(width) + 1, Self.maxTitleWidth)
  }
}

private struct PillPressStyle: ButtonStyle {
  let hovering: Bool
  let reduceMotion: Bool

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(reduceMotion ? 1 : configuration.isPressed ? 0.96 : hovering ? 1.04 : 1)
      .animation(.snappy(duration: 0.18), value: configuration.isPressed)
  }
}
