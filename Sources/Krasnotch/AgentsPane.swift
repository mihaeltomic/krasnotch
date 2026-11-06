import AppKit
import KrasnotchKit
import SwiftUI

struct AgentsPane: View {
  @Environment(AppModel.self) private var model
  @State private var copied = false

  private var command: String {
    "curl --unix-socket \"\(EventServer.shellSocketPath)\" \"http://localhost/state?session=my-agent&value=working\""
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 22) {
      SettingsCard(title: "Claude Code", footer: "Adds hooks to ~/.claude/settings.json and keeps a backup next to it. Your other hooks are left untouched. New sessions pick up the change.") {
        SettingsRow(title: "Claude Code", subtitle: model.hooksInstalled ? "Hooks installed" : "Not connected") {
          HStack(spacing: 10) {
            StatusBadge(text: model.hooksInstalled ? "Connected" : "Off", color: model.hooksInstalled ? .green : .secondary)
            Button(model.hooksInstalled ? "Disconnect" : "Connect") { model.setHooksInstalled(!model.hooksInstalled) }
          }
        }
        if let error = model.hookError ?? model.serverError {
          SettingsRow(title: "Problem", subtitle: error) { EmptyView() }
        }
      }

      SettingsCard(title: "Active Sessions") {
        if model.sessions.isEmpty {
          SettingsRow(title: "No agents running", subtitle: "Sessions show up here while they report in") { EmptyView() }
        } else {
          ForEach(model.sessions, id: \.id) { session in
            SettingsRow(title: session.displayName, subtitle: String(session.id.suffix(12))) {
              HStack(spacing: 10) {
                StatusBadge(text: session.state.title, color: model.config[session.state].primaryColor)
                if let origin = session.origin {
                  Button("Show") { origin.activate() }
                }
              }
            }
          }
          SettingsRow(title: "Reset") {
            Button("Clear Sessions") { model.clearSessions() }
          }
        }
      }

      SettingsCard(title: "Any Other Tool", footer: "Values: working, needsInput, done, idle. Use a distinct session name per agent.") {
        HStack(alignment: .top, spacing: 10) {
          Text(command)
            .font(.system(size: 11.5, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
          Button(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
            copied = true
            Task { try? await Task.sleep(for: .seconds(1.5)); copied = false }
          }
          .labelStyle(.iconOnly)
          .buttonStyle(.borderless)
          .contentTransition(.symbolEffect(.replace))
        }
        .padding(14)
      }
    }
  }
}
