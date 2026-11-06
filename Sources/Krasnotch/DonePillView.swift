import AppKit
import Observation
import SwiftUI

@MainActor
@Observable
final class DonePillModel {
  var title = ""
  var hasTarget = false
  var visible = false
  var hovering = false
  /// The pill's layout frame in the window, top-left origin. Hover is hit-tested against it.
  var pillRect = CGRect.zero
  /// Bumped on every new Done, so the arrow bounces once per arrival.
  var arrivals = 0
}

/// The lime pill that drops out of the notch when a thread finishes.
struct DonePillView: View {
  static let maxTitleWidth: CGFloat = 220
  private static let fontSize: CGFloat = 12

  let model: DonePillModel
  let onClick: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private static let volt = Color(red: 0xC4 / 255, green: 0xFF / 255, blue: 0x3A / 255)
  private static let ink = Color(red: 0x0C / 255, green: 0x0E / 255, blue: 0x11 / 255)

  var body: some View {
    let shown = model.visible
    Button(action: onClick) {
      HStack(spacing: 5) {
        Text(model.title)
          .font(.system(size: Self.fontSize, weight: .semibold))
          .lineLimit(1)
          .truncationMode(.tail)
          .frame(width: titleWidth, alignment: .leading)
          .id(model.title)
          .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))
        if model.hasTarget {
          Image(systemName: "arrow.right.circle")
            .font(.system(size: 14, weight: .medium))
            .offset(x: model.hovering && !reduceMotion ? 1.5 : 0)
            .symbolEffect(.bounce, value: model.arrivals)
        }
      }
      .foregroundStyle(Self.ink)
      .opacity(shown ? 1 : 0)
      .animation(shown ? .smooth(duration: 0.3).delay(0.06) : .smooth(duration: 0.12), value: shown)
      .padding(.leading, 11)
      .padding(.trailing, model.hasTarget ? 6 : 11)
      .frame(height: 26)
      .background(Self.volt, in: Capsule())
      .contentShape(Capsule())
    }
    .buttonStyle(PillPressStyle(hovering: model.hovering, reduceMotion: reduceMotion))
    // SwiftUI's onHover stays silent while Krasnotch isn't the active app; the hosting view tracks hover instead.
    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { model.pillRect = $0 }
    .animation(.snappy(duration: 0.22), value: model.hovering)
    .animation(.smooth(duration: 0.3), value: model.title)
    .shadow(color: .black.opacity(shown ? 0.35 : 0), radius: 8, y: 4)
    // Tucked up behind the notch until shown; the window's top edge clips it, so it appears to drop out.
    .scaleEffect(reduceMotion || shown ? 1 : 0.55, anchor: .top)
    .offset(y: reduceMotion || shown ? 0 : -12)
    .blur(radius: reduceMotion || shown ? 0 : 6)
    .opacity(shown ? 1 : 0)
    .animation(shown ? .spring(duration: 0.45, bounce: 0.32) : .spring(duration: 0.28, bounce: 0), value: shown)
    .padding(.top, 5)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .accessibilityLabel("\(model.title) is done")
    .accessibilityHint(model.hasTarget ? "Opens the thread" : "Dismisses")
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
