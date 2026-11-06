import AppKit
import KrasnotchKit
import SwiftUI

struct GlowPane: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    let state = model.editingState

    VStack(alignment: .leading, spacing: 22) {
      HStack(spacing: 12) {
        ForEach(GlowState.allCases) { option in
          StateCard(state: option, style: model.config[option], selected: option == state) {
            model.editingState = option
          }
        }
      }

      SettingsCard(title: "Motion") {
        SettingsRow(title: "Animation") {
          Picker("Animation", selection: $model.config[state].motion) {
            ForEach(GlowAnimation.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) }
          }
          .labelsHidden()
          .fixedSize()
        }
        CompactSlider(title: "Cycle length", value: $model.config[state].speed, in: 0.3...12) { String(format: "%.1fs", $0) }
          .padding(12)
        MagicRow(isOn: $model.config[state].magic)
        SettingsRow(title: "Preview on notch", help: "While this window is open, your real notch shows the state you’re editing.") {
          Toggle("", isOn: $model.livePreview).labelsHidden().toggleStyle(.switch)
        }
      }

      SettingsCard(title: "Color") {
        PaletteRow(colors: $model.config[state].colors)
        SwatchRow(colors: $model.config[state].colors)
      }

      SettingsCard(title: "Shape") {
        CompactSlider(title: "Thickness", value: $model.config[state].thickness, in: 1...12) { String(format: "%.1fpt", $0) }
          .padding(12)
        CompactSlider(title: "Glow intensity", value: $model.config[state].intensity, in: 0...1) { "\(Int($0 * 100))%" }
          .padding(12)
        SettingsRow(title: "Dithered glow", help: "Renders the soft haze with a fine ordered-dither pattern for a retro, pixel-lit look.") {
          Toggle("", isOn: $model.config[state].dither).labelsHidden().toggleStyle(.switch)
        }
      }

      HStack {
        Spacer()
        Button("Reset \(state.title) to Default") { model.config[state] = .defaultStyle(for: state) }
          .disabled(model.config[state] == .defaultStyle(for: state))
      }
    }
  }
}

private struct StateCard: View {
  let state: GlowState
  let style: GlowStyle
  let selected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 8) {
        NotchPreview(style: style)
          .frame(height: 64)
        HStack(spacing: 5) {
          Image(systemName: state.symbol).foregroundStyle(style.primaryColor)
          Text(state.title).font(.system(size: 12, weight: .semibold))
          Spacer()
          Text(style.motion.title).font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 4)
      }
      .padding(8)
      .background(.background.secondary, in: .rect(cornerRadius: 14))
      .overlay(
        RoundedRectangle(cornerRadius: 14)
          .strokeBorder(selected ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.6), lineWidth: selected ? 2 : 0.5)
      )
      .contentShape(.rect(cornerRadius: 14))
    }
    .buttonStyle(.plain)
    .accessibilityLabel("\(state.title), \(style.motion.title)")
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

private struct PaletteRow: View {
  @Binding var colors: [String]

  static let palettes: [(name: String, colors: [String])] = [
    ("Siri", ["#2EA8FF", "#8E5CFF", "#FF4FA3", "#FF9A3D"]),
    ("Ocean", ["#00C6FF", "#0072FF", "#7B61FF"]),
    ("Sunset", ["#FF5F6D", "#FF9A3D", "#FFC371"]),
    ("Mint", ["#30D158", "#7CF5B0", "#64D2FF"]),
    ("Ember", ["#FF375F", "#FF9F0A"]),
    ("Mono", ["#FFFFFF", "#8E8E93"]),
    ("Gold", ["#FFD36E", "#FFF1B8", "#FFB347", "#FFE08A"]),
    ("Rainbow", ["#FF5F6D", "#FFC371", "#7CF5B0", "#64D2FF", "#8E5CFF", "#FF4FA3"]),
  ]

  var body: some View {
    SettingsRow(title: "Palette") {
      HStack(spacing: 8) {
        ForEach(Self.palettes, id: \.name) { palette in
          let active = palette.colors == colors
          Button { colors = palette.colors } label: {
            Circle()
              .fill(AngularGradient(colors: palette.colors.compactMap(RGBA.init(hex:)).map { Color(cgColor: $0.cgColor) } + [Color(cgColor: RGBA(hex: palette.colors[0])!.cgColor)], center: .center))
              .frame(width: 20, height: 20)
              .padding(3)
              .overlay(Circle().strokeBorder(active ? Color.accentColor : .clear, lineWidth: 2))
          }
          .buttonStyle(.plain)
          .help(palette.name)
          .accessibilityLabel(palette.name)
        }
      }
    }
  }
}

private struct SwatchRow: View {
  @Binding var colors: [String]

  var body: some View {
    SettingsRow(title: "Colors", subtitle: "Right-click a color to remove it") {
      HStack(spacing: 6) {
        ForEach(colors.indices, id: \.self) { index in
          ColorPicker("Color \(index + 1)", selection: binding(at: index), supportsOpacity: false)
            .labelsHidden()
            .contextMenu {
              Button("Remove", role: .destructive) { colors.remove(at: index) }
                .disabled(colors.count <= 1)
            }
        }
        Button("Add Color", systemImage: "plus") { colors.append(colors.last ?? "#FFFFFF") }
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
          .disabled(colors.count >= 6)
      }
    }
  }

  private func binding(at index: Int) -> Binding<Color> {
    Binding {
      guard colors.indices.contains(index), let rgba = RGBA(hex: colors[index]) else { return .white }
      return Color(cgColor: rgba.cgColor)
    } set: { color in
      guard colors.indices.contains(index), let srgb = NSColor(color).usingColorSpace(.sRGB) else { return }
      colors[index] = RGBA(red: srgb.redComponent, green: srgb.greenComponent, blue: srgb.blueComponent).hex
    }
  }
}

/// "Magic?": a wand stroke with glitter on top of any animation. The label shimmers, quietly.
private struct MagicRow: View {
  @Binding var isOn: Bool

  var body: some View {
    HStack(spacing: 12) {
      HStack(spacing: 4) {
        ShimmerText("Magic?")
        InfoButton(text: "Adds a golden wand stroke that arcs around the notch and sheds glitter, on top of whichever animation you pick. Try it with the Gold or Rainbow palette.")
      }
      Spacer(minLength: 12)
      Toggle("", isOn: $isOn).labelsHidden().toggleStyle(.switch)
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 10)
    .frame(minHeight: 44)
  }
}

/// Text with a soft golden highlight that sweeps across the letters every few seconds.
/// Subtle by design: one pass of about a second, then a long rest; still with Reduce Motion.
struct ShimmerText: View {
  let text: String
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  init(_ text: String) { self.text = text }

  var body: some View {
    let label = Text(text).font(.system(size: 13))
    label
      .overlay {
        if !reduceMotion {
          TimelineView(.animation(minimumInterval: 1.0 / 30)) { context in
            GeometryReader { geometry in
              let period = 3.6, sweep = 1.1
              let local = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
              let progress = min(local / sweep, 1)
              let band = geometry.size.width * 0.9
              LinearGradient(
                colors: [.clear, Color(red: 1, green: 0.83, blue: 0.43).opacity(0.85), .white.opacity(0.9),
                         Color(red: 1, green: 0.7, blue: 0.28).opacity(0.85), .clear],
                startPoint: .leading, endPoint: .trailing
              )
              .frame(width: band)
              .offset(x: -band + (geometry.size.width + band) * progress)
              .opacity(local < sweep ? 1 : 0)
            }
            .mask(label)
          }
          .allowsHitTesting(false)
        }
      }
      .accessibilityLabel(text)
  }
}
