import AppKit
import SwiftUI

/// Titled group of rows on a rounded, softly lit surface.
struct SettingsCard<Content: View>: View {
  var title: String?
  var footer: String?
  @ViewBuilder var content: Content

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      if let title {
        Text(title)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.secondary)
          .padding(.leading, 4)
      }
      VStack(spacing: 0) {
        Group(subviews: content) { rows in
          ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
            if index > 0 { Divider().padding(.leading, 14) }
            row
          }
        }
      }
      .background(.background.secondary, in: .rect(cornerRadius: 12))
      .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
      if let footer {
        Text(footer)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .padding(.horizontal, 4)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }
}

/// Label on the left, control on the right, optional subtitle and help popover.
struct SettingsRow<Control: View>: View {
  let title: String
  var subtitle: String?
  var help: String?
  @ViewBuilder var control: Control

  var body: some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: 4) {
          Text(title).font(.system(size: 13))
          if let help { InfoButton(text: help) }
        }
        if let subtitle {
          Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
        }
      }
      Spacer(minLength: 12)
      control
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(minHeight: 44)
  }
}

/// A slider that is also its own label: the fill is the value, the text sits inside the track.
struct CompactSlider: View {
  let title: String
  @Binding var value: Double
  let range: ClosedRange<Double>
  let format: (Double) -> String

  @State private var dragging = false

  init(title: String, value: Binding<Double>, in range: ClosedRange<Double>, format: @escaping (Double) -> String) {
    self.title = title
    _value = value
    self.range = range
    self.format = format
  }

  var body: some View {
    GeometryReader { geometry in
      let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
      ZStack(alignment: .leading) {
        RoundedRectangle(cornerRadius: 8).fill(.quaternary.opacity(0.6))
        RoundedRectangle(cornerRadius: 8)
          .fill(.tint.opacity(dragging ? 0.42 : 0.3))
          .frame(width: max(0, geometry.size.width * fraction))
        HStack {
          Text(title)
          Spacer()
          Text(format(value)).monospacedDigit().foregroundStyle(.secondary)
        }
        .font(.system(size: 12, weight: .medium))
        .padding(.horizontal, 12)
      }
      .contentShape(.rect)
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { gesture in
            dragging = true
            let position = min(max(gesture.location.x / geometry.size.width, 0), 1)
            let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * position
            if (newValue == range.lowerBound || newValue == range.upperBound), newValue != value {
              NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
            }
            value = newValue
          }
          .onEnded { _ in dragging = false }
      )
    }
    .frame(height: 32)
    .animation(.snappy(duration: 0.15), value: dragging)
    .accessibilityElement()
    .accessibilityLabel(title)
    .accessibilityValue(format(value))
    .accessibilityAdjustableAction { direction in
      let step = (range.upperBound - range.lowerBound) / 20
      value = min(max(value + (direction == .increment ? step : -step), range.lowerBound), range.upperBound)
    }
  }
}

struct InfoButton: View {
  let text: String
  @State private var shown = false

  var body: some View {
    Button { shown.toggle() } label: {
      Image(systemName: "info.circle").foregroundStyle(.secondary)
    }
    .buttonStyle(.plain)
    .onHover { shown = $0 }
    .popover(isPresented: $shown, arrowEdge: .top) {
      Text(text)
        .font(.system(size: 12))
        .frame(width: 240, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(12)
    }
    .accessibilityLabel("More info")
  }
}

/// System Settings–style colored rounded square behind a white glyph.
struct SidebarIcon: View {
  let symbol: String
  let tint: Color

  var body: some View {
    Image(systemName: symbol)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(.white)
      .frame(width: 22, height: 22)
      .background(tint.gradient, in: .rect(cornerRadius: 6))
  }
}

struct StatusBadge: View {
  let text: String
  let color: Color

  var body: some View {
    Text(text)
      .font(.system(size: 11, weight: .semibold))
      .foregroundStyle(color)
      .padding(.horizontal, 8)
      .padding(.vertical, 3)
      .background(color.opacity(0.14), in: .capsule)
  }
}
