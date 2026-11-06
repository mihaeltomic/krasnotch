import KrasnotchKit
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
  case glow, general, agents, about

  var id: String { rawValue }

  var title: String {
    switch self {
    case .glow: "Glow"
    case .general: "General"
    case .agents: "Agents"
    case .about: "About"
    }
  }

  var symbol: String {
    switch self {
    case .glow: "sparkles"
    case .general: "gearshape.fill"
    case .agents: "terminal.fill"
    case .about: "info"
    }
  }

  var tint: Color {
    switch self {
    case .glow: .purple
    case .general: .gray
    case .agents: .orange
    case .about: .blue
    }
  }
}

struct SettingsView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    NavigationSplitView {
      List(SettingsPane.allCases, selection: selection) { pane in
        HStack(spacing: 9) {
          SidebarIcon(symbol: pane.symbol, tint: pane.tint)
          Text(pane.title)
        }
        .padding(.vertical, 3)
          .tag(pane)
      }
      .navigationSplitViewColumnWidth(min: 180, ideal: 190, max: 220)
    } detail: {
      ScrollView {
        Group {
          switch model.settingsPane {
          case .glow: GlowPane()
          case .general: GeneralPane()
          case .agents: AgentsPane()
          case .about: AboutPane()
          }
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 28)
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
      }
      .navigationTitle(model.settingsPane.title)
    }
    .frame(minWidth: 720, minHeight: 520)
  }

  private var selection: Binding<SettingsPane?> {
    Binding { model.settingsPane } set: { if let pane = $0 { model.settingsPane = pane } }
  }
}

struct GeneralPane: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    @Bindable var model = model
    VStack(alignment: .leading, spacing: 22) {
      SettingsCard(title: "Glow") {
        SettingsRow(title: "Show glow", subtitle: "Pause without quitting Krasnotch") {
          Toggle("", isOn: $model.config.enabled).labelsHidden().toggleStyle(.switch)
        }
        CompactSlider(title: "Brightness", value: $model.config.brightness, in: 0.2...1) { "\(Int($0 * 100))%" }
          .padding(12)
        CompactSlider(title: "Keep “Done” visible", value: $model.config.doneDuration, in: 1...15) { String(format: "%.0fs", $0) }
          .padding(12)
      }

      SettingsCard(title: "Done Pill", footer: "When an agent finishes, a pill with the thread’s name drops out of the notch. Click it to jump back.") {
        SettingsRow(title: "Show thread pill when done") {
          Toggle("", isOn: $model.config.showDonePill).labelsHidden().toggleStyle(.switch)
        }
        if model.config.showDonePill {
          CompactSlider(title: "Keep pill visible", value: $model.config.donePillDuration, in: 4...30) { String(format: "%.0fs", $0) }
            .padding(12)
        }
      }

      SettingsCard(title: "Notch", footer: "Rounds the glow’s inner corners to sit flush with your MacBook’s notch.") {
        CompactSlider(title: "Corner radius", value: $model.config.notchCornerRadius, in: 0...16) { String(format: "%.0fpt", $0) }
          .padding(12)
      }

      SettingsCard(title: "System") {
        SettingsRow(title: "Hide from screen sharing", help: "Keeps the glow out of screenshots, recordings and screen shares, so it only ever lights up your own screen.") {
          Toggle("", isOn: $model.config.hideFromScreenCapture).labelsHidden().toggleStyle(.switch)
        }
        SettingsRow(title: "Open at login") {
          Toggle("", isOn: $model.launchAtLogin).labelsHidden().toggleStyle(.switch)
        }
      }
    }
  }
}

struct AboutPane: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    VStack(spacing: 14) {
      NotchPreview(style: model.config.working, scale: 1)
        .frame(width: 300, height: 120)
        .shadow(color: model.config.working.primaryColor.opacity(0.25), radius: 24, y: 8)
      Text("Krasnotch").font(.system(size: 26, weight: .bold))
      Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
        .font(.system(size: 12)).foregroundStyle(.secondary)
      Text("A neon glow around your notch that shows what your coding agents are doing: working, waiting on you, or done.")
        .font(.system(size: 13))
        .multilineTextAlignment(.center)
        .foregroundStyle(.secondary)
        .frame(maxWidth: 360)
    }
    .frame(maxWidth: .infinity)
    .padding(.top, 24)
  }
}
