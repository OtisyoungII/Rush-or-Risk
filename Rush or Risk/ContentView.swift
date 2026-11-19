import SwiftUI

struct ContentView: View {
    @State private var highestUnlocked = ProgressStore().highestUnlockedLevel
    @State private var endlessUnlocked = ProgressStore().endlessUnlocked

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    MenuBackground()
                    if geometry.size.width > geometry.size.height {
                        HStack(spacing: 34) {
                            menuBranding
                                .frame(maxWidth: .infinity)
                            ScrollView {
                                menuActions
                                    .padding(.vertical, 12)
                            }
                            .scrollIndicators(.hidden)
                            .frame(maxWidth: 390)
                        }
                        .padding(.horizontal, max(24, geometry.safeAreaInsets.leading + 16))
                    } else {
                        ScrollView {
                            VStack(spacing: 24) {
                                menuBranding
                                menuActions
                            }
                            .padding(.horizontal, 26)
                            .padding(.vertical, 24)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                highestUnlocked = ProgressStore().highestUnlockedLevel
                endlessUnlocked = ProgressStore().endlessUnlocked
                let settings = SettingsStore().value
                AudioManager.shared.apply(settings)
                AudioManager.shared.startMusic(.menu)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var menuBranding: some View {
        VStack(spacing: 8) {
            Text("RUSH & RISK").font(.system(size: 40, weight: .black, design: .rounded)).foregroundStyle(.white).shadow(radius: 8)
            Text("DETROIT ARCADE MIX").font(.headline).tracking(4).foregroundStyle(.cyan)
        }
    }

    private var menuActions: some View {
        VStack(spacing: 10) {
            FullScreenGameLink(mode: .level(highestUnlocked)) { Text("PLAY") }.menuButton(primary: true)
            NavigationLink("LEVEL SELECT", destination: LevelSelectView(highestUnlocked: highestUnlocked)).menuButton()
            if endlessUnlocked {
                FullScreenGameLink(mode: .endless) { Text("ENDLESS MODE") }.menuButton()
            } else {
                Label("ENDLESS — COMPLETE LEVEL 20", systemImage: "lock.fill").menuButton(disabled: true)
            }
            NavigationLink("HIGH SCORES", destination: HighScoresView()).menuButton()
            NavigationLink("SETTINGS", destination: SettingsView()).menuButton()
        }
    }
}

struct MenuBackground: View {
    var body: some View {
        ZStack {
            Image("RushorRiskHome").resizable().scaledToFill().ignoresSafeArea().accessibilityHidden(true)
            LinearGradient(colors: [.black.opacity(0.25), .black.opacity(0.88)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        }
    }
}

private extension View {
    func menuButton(primary: Bool = false, disabled: Bool = false) -> some View {
        self.font(.system(size: 18, weight: .heavy, design: .rounded))
            .foregroundStyle(disabled ? .gray : .white)
            .frame(maxWidth: 350).frame(height: 46)
            .background(primary ? Color.blue.opacity(0.95) : Color.black.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(disabled ? .gray : .white.opacity(0.8), lineWidth: 1.5))
            .accessibilityAddTraits(.isButton)
    }
}

struct LevelSelectView: View {
    let highestUnlocked: Int
    private let columns = [GridItem(.adaptive(minimum: 82), spacing: 12)]
    var body: some View {
        ZStack {
            LinearGradient(colors: [.black, Color(red: 0.02, green: 0.15, blue: 0.28)], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 12) {
                    Text("LEVEL SELECT").font(.title.bold()).foregroundStyle(.white)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(LevelDefinition.all) { level in
                            if level.id <= highestUnlocked {
                                FullScreenGameLink(mode: .level(level.id)) {
                                    levelCard(level, locked: false)
                                }
                            } else { levelCard(level, locked: true) }
                        }
                    }
                }.padding(.horizontal).padding(.bottom)
            }
        }.navigationTitle("").navigationBarTitleDisplayMode(.inline)
    }

    private func levelCard(_ level: LevelDefinition, locked: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: locked ? "lock.fill" : "music.note").font(.title2)
            Text("\(level.id)").font(.title.bold())
            Text(level.theme.rawValue).font(.caption2).lineLimit(1)
        }.foregroundStyle(locked ? .gray : .white).frame(maxWidth: .infinity).frame(height: 88)
            .background(locked ? Color.gray.opacity(0.15) : Color.blue.opacity(0.55)).clipShape(RoundedRectangle(cornerRadius: 14))
            .accessibilityLabel(locked ? "Level \(level.id), locked" : "Level \(level.id), \(level.theme.rawValue), \(level.objectiveText)")
    }
}

struct FullScreenGameLink<Label: View>: View {
    let mode: GameMode
    @ViewBuilder let label: () -> Label
    @State private var isPresented = false

    var body: some View {
        Button(action: {
            AudioManager.shared.stopMusic()
            isPresented = true
        }, label: label)
            .buttonStyle(.plain)
            .fullScreenCover(isPresented: $isPresented, onDismiss: {
                AudioManager.shared.apply(SettingsStore().value)
                AudioManager.shared.startMusic(.menu)
            }) {
                GameViewControllerWrapper(mode: mode)
                    .ignoresSafeArea()
                    .statusBarHidden(true)
            }
    }
}

struct HighScoresView: View {
    private let scores = HighScoreStore().scores
    var body: some View {
        List {
            Section("LOCAL TOP RUNS") {
                if scores.isEmpty { Text("Play a level to set your first score.") }
                ForEach(Array(scores.enumerated()), id: \.element.id) { index, run in
                    HStack {
                        Text("#\(index + 1)").font(.headline).frame(width: 38)
                        VStack(alignment: .leading) { Text("\(run.score) points").bold(); Text("Level \(run.level) • Combo \(run.highestCombo)").font(.caption) }
                        Spacer(); Text(run.date, style: .date).font(.caption2)
                    }
                }
            }
        }.navigationTitle("High Scores")
    }
}

struct SettingsView: View {
    @State private var settings = SettingsStore().value
    var body: some View {
        Form {
            Section("AUDIO") {
                Toggle("Enable Audio", isOn: $settings.audioEnabled)
                Text(settings.audioEnabled ? "Audio follows the iPhone Silent switch." : "Audio is muted until you enable it here.")
                    .font(.footnote).foregroundStyle(.secondary)
                VStack(alignment: .leading) { Text("Music Volume"); Slider(value: $settings.musicVolume, in: 0...0.25) }.disabled(!settings.audioEnabled)
                VStack(alignment: .leading) { Text("Effects Volume"); Slider(value: $settings.effectsVolume, in: 0...0.3) }.disabled(!settings.audioEnabled)
            }
            Section("FEEDBACK") {
                Toggle("Haptics", isOn: $settings.hapticsEnabled)
                Toggle("Reduce Motion", isOn: $settings.reducedMotion)
            }
            Section { Text("Audio uses conservative gain and remains permanently disabled during automated testing. Settings, scores, and unlocked levels are stored only on this device.").font(.footnote) }
        }.navigationTitle("Settings").onChange(of: settings) { _, value in
            SettingsStore().value = value
            AudioManager.shared.apply(value)
            if value.audioEnabled { AudioManager.shared.startMusic(.menu) }
        }
    }
}

#Preview { ContentView() }
