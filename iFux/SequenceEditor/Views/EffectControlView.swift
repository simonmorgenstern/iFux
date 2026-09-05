//
//  EffectControlView.swift
//  iFux
//
//  Created on 18.03.26.
//

import SwiftUI
import UIKit
import AVFoundation

// MARK: - Main View

struct EffectControlView: View {
    @StateObject private var controller = FuxController()
    @State private var showConnectionSheet = false

    var body: some View {
        VStack(spacing: 0) {
            ConnectionStatusBar(
                status: controller.connectionStatus,
                host: controller.savedHost,
                onTap: { showConnectionSheet = true },
                onRetry: { controller.retryConnection() }
            )

            if let error = controller.errorMessage {
                ErrorBanner(message: error) { controller.errorMessage = nil }
            }

            Picker("Mode", selection: Binding(
                get: { controller.currentMode },
                set: { controller.setMode($0) }
            )) {
                ForEach(ControlMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            modeContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear { controller.connect() }
        .onDisappear { controller.disconnect() }
        .sheet(isPresented: $showConnectionSheet) {
            ConnectionSettingsSheet(controller: controller)
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch controller.currentMode {
        case .off:
            SimpleModeView(
                icon: "power",
                title: "Off",
                subtitle: "The fux is turned off"
            )
        case .random:
            SimpleModeView(
                icon: "shuffle",
                title: "Random",
                subtitle: "Effects will play in random order"
            )
        case .idle:
            EffectsGridView(controller: controller) { effect in
                controller.playEffect(effect)
            }
        case .queue:
            QueueModeView(controller: controller)
        case .casino:
            CasinoModeView(controller: controller)
        case .music:
            MusicModeView(controller: controller)
        }
    }
}

// MARK: - Music Mode View

/// Shows what Spotify is playing, whether the LEDs are beat-locked to it, and
/// the manual phase nudge. BPM only gives the beat period — nothing free tells
/// the backend where the true downbeat sits — so the offset is dialled in by eye
/// and then remembered for that track.
struct MusicModeView: View {
    @ObservedObject var controller: FuxController
    @State private var manualBpm: String = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let music = controller.music, music.configured, music.authorized {
                    nowPlayingCard(music)
                    syncCard(music)
                    offsetCard(music)
                    if music.bpm == nil {
                        manualBpmCard
                    }
                } else {
                    setupCard
                }

                if let error = controller.music?.error {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding()
        }
        .onAppear { controller.requestState() }
    }

    // MARK: Now playing

    @ViewBuilder
    private func nowPlayingCard(_ music: MusicStateDTO) -> some View {
        card {
            if let title = music.title, !title.isEmpty {
                HStack(spacing: 14) {
                    BeatIndicator(anchor: controller.beatAnchor)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(title)
                            .font(.headline)
                            .lineLimit(1)
                        Text(music.artist ?? "")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: music.playing ? "play.fill" : "pause.fill")
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .foregroundColor(.secondary)
                    Text("Nothing playing on Spotify")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
    }

    // MARK: Sync

    @ViewBuilder
    private func syncCard(_ music: MusicStateDTO) -> some View {
        card {
            HStack {
                Circle()
                    .fill(music.synced ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                Text(music.synced ? "Beat-locked" : "Not beat-locked")
                    .font(.subheadline)
                Spacer()
                if let bpm = music.bpm {
                    Text("\(Int(bpm.rounded())) BPM")
                        .font(.system(.subheadline, design: .monospaced))
                }
            }
            if let source = music.bpmSource, music.bpm != nil {
                Text("Tempo from \(source)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if !music.synced {
                Text(music.playing
                     ? "No tempo found for this track — playing an ambient effect instead."
                     : "Start playback in Spotify and the LEDs will follow.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Offset calibration

    @ViewBuilder
    private func offsetCard(_ music: MusicStateDTO) -> some View {
        card {
            HStack {
                Text("Beat offset")
                    .font(.subheadline)
                Spacer()
                Text("\(music.offsetMs > 0 ? "+" : "")\(music.offsetMs) ms")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundColor(music.offsetMs == 0 ? .secondary : .primary)
            }

            HStack(spacing: 8) {
                nudgeButton("−50", -50)
                nudgeButton("−10", -10)
                Button("Reset") { controller.resetBeatOffset() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                nudgeButton("+10", 10)
                nudgeButton("+50", 50)
            }

            Text("Nudge until the flashes land on the beat. The correction is saved for this track.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .disabled(music.trackId == nil)
    }

    private func nudgeButton(_ label: String, _ deltaMs: Int) -> some View {
        Button(label) { controller.nudgeBeatOffset(deltaMs) }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity)
    }

    // MARK: Manual tempo

    private var manualBpmCard: some View {
        card {
            Text("Set the tempo manually")
                .font(.subheadline)
            HStack {
                TextField("BPM", text: $manualBpm)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("Apply") {
                    if let bpm = Double(manualBpm), bpm > 0 {
                        controller.setMusicBpm(bpm)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(Double(manualBpm) == nil)
            }
            Text("Remembered for this track, so it only has to be entered once.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: Setup

    private var setupCard: some View {
        card {
            Image(systemName: "music.note.list")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)

            if controller.music?.configured == false {
                Text("Spotify not configured")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                Text("Create ~/.fux/spotify.json on the fux with the client id and secret of a Spotify developer app, then restart it.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Connect Spotify")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                Text("Music mode reads what you are playing and syncs the LEDs to it. This only has to be approved once.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                if let url = controller.spotifyLoginURL {
                    Link(destination: url) {
                        Text("Open the login page")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button("Check again") { controller.requestState() }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(UIColor.secondarySystemBackground))
        )
    }
}

// MARK: - Beat Indicator

/// Pulses in time with the music. The backend pushes STATE about once a second,
/// far too coarse to animate from directly, so this interpolates from the last
/// reported phase using the track's tempo — the same trick the backend's beat
/// clock uses between Spotify polls.
struct BeatIndicator: View {
    let anchor: (phase: Double, bpm: Double, at: Date)?

    var body: some View {
        TimelineView(.animation(paused: anchor == nil)) { context in
            let scale = 0.65 + 0.35 * (1.0 - envelope(at: context.date))
            Circle()
                .fill(anchor == nil ? Color.secondary.opacity(0.3) : Color.accentColor)
                .frame(width: 22, height: 22)
                .scaleEffect(scale)
                .opacity(anchor == nil ? 0.5 : 0.45 + 0.55 * (1.0 - envelope(at: context.date)))
        }
        .frame(width: 24, height: 24)
    }

    /// 0 right on the beat, rising to 1 just before the next one.
    private func envelope(at date: Date) -> Double {
        guard let anchor = anchor, anchor.bpm > 0 else { return 1 }
        let beatsElapsed = date.timeIntervalSince(anchor.at) * anchor.bpm / 60.0
        let phase = (anchor.phase + beatsElapsed).truncatingRemainder(dividingBy: 1.0)
        return phase < 0 ? phase + 1 : phase
    }
}

// MARK: - Casino Mode View

// Classic roulette: a green zero plus alternating red/black pockets.
private let casinoPocketColors: [Color] = [
    .green,
    .red, .black, .red, .black, .red, .black, .red, .black,
    .red, .black, .red, .black, .red, .black, .red, .black, .red
]
private var casinoSegmentDegrees: Double { 360.0 / Double(casinoPocketColors.count) }

// Spin speeds expressed as seconds per full revolution. Wheel rotates clockwise,
// ball counter-clockwise — classic roulette feel.
private let casinoWheelPeriod: Double = 1.8
private let casinoBallPeriod: Double = 1.1
// Target deceleration time. The real duration is derived so the wheel lands
// exactly on a pocket while preserving the spin velocity at the handoff.
private let casinoTargetLandingDuration: Double = 2.5

struct CasinoModeView: View {
    @ObservedObject var controller: FuxController

    enum SpinPhase { case idle, rolling, landing, settled }

    /// Linear-deceleration plan: angle interpolates from startAngle to endAngle
    /// using the curve `2τ − τ²` (τ ∈ [0,1]). The initial slope of that curve
    /// is `2·(end−start)/duration`, so when distance and duration are chosen so
    /// that this matches the current spin velocity, the handoff is seamless.
    struct LandingPlan {
        var startDate: Date = .distantPast
        var startAngle: Double = 0
        var endAngle: Double = 0
        var duration: Double = 1
    }

    @State private var phase: SpinPhase = .idle
    @State private var lastOutcome: CasinoOutcome?
    @State private var rollStartDate: Date = .distantPast
    @State private var rollingWheelStart: Double = 0
    @State private var rollingBallStart: Double = 0
    @State private var wheelLanding = LandingPlan()
    @State private var ballLanding = LandingPlan()
    @State private var spinPlayer: AVAudioPlayer?
    @State private var outcomePlayer: AVAudioPlayer?

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 8)

            // TimelineView drives both wheel and ball from `Date`, so we can
            // read the *live* displayed angles when the user commits a color.
            TimelineView(.animation(paused: phase == .idle || phase == .settled)) { context in
                let now = context.date
                RouletteWheel(
                    wheelRotation: computeWheelAngle(now: now),
                    ballRotation: computeBallAngle(now: now),
                    isRolling: phase == .rolling || phase == .landing
                )
                .frame(width: 240, height: 240)
            }

            outcomeBadge

            // Roll
            Button(action: roll) {
                Label("Roll", systemImage: "die.face.5.fill")
                    .font(.title2.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentColor)
            .padding(.horizontal, 24)

            // Red / Green / Black
            HStack(spacing: 12) {
                CasinoButton(title: "Red", color: .red) { commit(.red) }
                CasinoButton(title: "Green", color: .green) { commit(.green) }
                CasinoButton(title: "Black", color: .black) { commit(.black) }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .padding(.vertical)
        .onDisappear {
            phase = .idle
            stopSpinSound()
        }
    }

    @ViewBuilder
    private var outcomeBadge: some View {
        if let outcome = lastOutcome, phase == .settled {
            HStack(spacing: 10) {
                Circle()
                    .fill(outcomeColor(outcome))
                    .frame(width: 22, height: 22)
                    .overlay(Circle().stroke(Color.primary.opacity(0.2), lineWidth: 1))
                Text("Result: \(outcome.rawValue.capitalized)")
                    .font(.title3.weight(.bold))
            }
        } else if phase == .rolling || phase == .landing {
            Text("Rolling…")
                .font(.title3.weight(.semibold))
                .foregroundColor(.secondary)
        } else {
            Text("Tap Roll to start")
                .font(.title3)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Angle computation (time-driven)

    private func computeWheelAngle(now: Date) -> Double {
        switch phase {
        case .idle:    return 0
        case .rolling: return rollingWheelStart + (now.timeIntervalSince(rollStartDate) / casinoWheelPeriod) * 360
        case .landing: return landingAngle(now: now, plan: wheelLanding)
        case .settled: return wheelLanding.endAngle
        }
    }

    private func computeBallAngle(now: Date) -> Double {
        switch phase {
        case .idle:    return 0
        case .rolling: return rollingBallStart - (now.timeIntervalSince(rollStartDate) / casinoBallPeriod) * 360
        case .landing: return landingAngle(now: now, plan: ballLanding)
        case .settled: return ballLanding.endAngle
        }
    }

    private func landingAngle(now: Date, plan: LandingPlan) -> Double {
        let elapsed = now.timeIntervalSince(plan.startDate)
        let t = max(0, min(1, elapsed / plan.duration))
        let eased = 2 * t - t * t // linear deceleration (initial slope 2, final 0)
        return plan.startAngle + (plan.endAngle - plan.startAngle) * eased
    }

    // MARK: - Actions

    private func roll() {
        guard phase != .landing else { return } // ignore mid-deceleration
        lastOutcome = nil
        // Continue from wherever we last settled so there's no visual jump.
        rollingWheelStart = (phase == .settled) ? wheelLanding.endAngle : 0
        rollingBallStart  = (phase == .settled) ? ballLanding.endAngle  : 0
        rollStartDate = Date()
        phase = .rolling
        controller.casinoRoll()
        startSpinSound()
    }

    private func commit(_ outcome: CasinoOutcome) {
        guard phase == .rolling else { return }
        let now = Date()
        let wheelAngleNow = computeWheelAngle(now: now)
        let ballAngleNow  = computeBallAngle(now: now)

        let targetIndex = randomPocketIndex(for: outcome)

        // Wheel: find smallest forward delta that lands pocket `targetIndex` at
        // 12 o'clock, then add full revolutions so distance ≈ v0·T/2, the
        // distance the wheel would cover decelerating linearly from its current
        // velocity v0 over the target duration. With linear deceleration the
        // initial slope equals exactly v0, so no speed-up / direction reversal.
        let v0Wheel = 360.0 / casinoWheelPeriod
        let targetMod = positiveMod(360.0 - (Double(targetIndex) + 0.5) * casinoSegmentDegrees, 360)
        let currentModW = positiveMod(wheelAngleNow, 360)
        var minDeltaW = positiveMod(targetMod - currentModW, 360)
        if minDeltaW < 1 { minDeltaW += 360 } // never land instantly
        let wantW = v0Wheel * casinoTargetLandingDuration / 2
        let wrapsW = max(0, Int(((wantW - minDeltaW) / 360).rounded()))
        let wheelDistance = minDeltaW + Double(wrapsW) * 360
        let wheelDuration = 2 * wheelDistance / v0Wheel
        wheelLanding = LandingPlan(
            startDate: now,
            startAngle: wheelAngleNow,
            endAngle: wheelAngleNow + wheelDistance,
            duration: wheelDuration
        )

        // Ball: same logic but in the negative direction; lands at any multiple
        // of 360° (= 12 o'clock).
        let v0Ball = 360.0 / casinoBallPeriod
        let currentModB = positiveMod(ballAngleNow, 360)
        var minDeltaB = -currentModB // ∈ (-360, 0]
        if minDeltaB > -1 { minDeltaB -= 360 }
        let wantB = -(v0Ball * casinoTargetLandingDuration / 2)
        let wrapsB = max(0, Int(((wantB - minDeltaB) / -360).rounded()))
        let ballDistance = minDeltaB - Double(wrapsB) * 360
        let ballDuration = 2 * abs(ballDistance) / v0Ball
        ballLanding = LandingPlan(
            startDate: now,
            startAngle: ballAngleNow,
            endAngle: ballAngleNow + ballDistance,
            duration: ballDuration
        )

        phase = .landing

        let maxDuration = max(wheelDuration, ballDuration)
        DispatchQueue.main.asyncAfter(deadline: .now() + maxDuration) {
            // Only settle if we're still landing (user could have re-rolled).
            guard phase == .landing else { return }
            phase = .settled
            lastOutcome = outcome
            stopSpinSound()
            playOutcomeSound(for: outcome)
            controller.casinoResult(outcome)
        }
    }

    // MARK: - Spin sound

    private func startSpinSound() {
        if spinPlayer == nil {
            // Looks for casino_spin.mp3 / .wav / .m4a / .caf in the app bundle.
            let extensions = ["mp3", "wav", "m4a", "caf"]
            let url = extensions.lazy
                .compactMap { Bundle.main.url(forResource: "casino_spin", withExtension: $0) }
                .first
            guard let url else { return }
            // Ducks other audio (Spotify etc.) instead of stopping it; keeps
            // playing even if the silent switch is on.
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try? AVAudioSession.sharedInstance().setActive(true)
            spinPlayer = try? AVAudioPlayer(contentsOf: url)
            spinPlayer?.numberOfLoops = -1
            spinPlayer?.prepareToPlay()
        }
        spinPlayer?.currentTime = 0
        spinPlayer?.play()
    }

    private func stopSpinSound() {
        spinPlayer?.stop()
    }

    private func playOutcomeSound(for outcome: CasinoOutcome) {
        let resource: String?
        switch outcome {
        case .red:   resource = "success"
        case .black: resource = "fail"
        case .green: resource = nil
        }
        guard let resource else { return }
        let extensions = ["mp3", "wav", "m4a", "caf"]
        let url = extensions.lazy
            .compactMap { Bundle.main.url(forResource: resource, withExtension: $0) }
            .first
        guard let url else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        outcomePlayer = try? AVAudioPlayer(contentsOf: url)
        outcomePlayer?.prepareToPlay()
        outcomePlayer?.play()
    }

    // MARK: - Helpers

    private func outcomeColor(_ outcome: CasinoOutcome) -> Color {
        switch outcome {
        case .red:   return .red
        case .green: return .green
        case .black: return .black
        }
    }

    private func randomPocketIndex(for outcome: CasinoOutcome) -> Int {
        let target: Color
        switch outcome {
        case .green: return 0
        case .red:   target = .red
        case .black: target = .black
        }
        let candidates = casinoPocketColors.indices.filter { casinoPocketColors[$0] == target }
        return candidates.randomElement() ?? 1
    }

    private func positiveMod(_ value: Double, _ modulus: Double) -> Double {
        let r = value.truncatingRemainder(dividingBy: modulus)
        return r < 0 ? r + modulus : r
    }
}

// MARK: - Cartoon Roulette Wheel

private struct RouletteWheel: View {
    let wheelRotation: Double
    let ballRotation: Double
    let isRolling: Bool

    private var pocketColors: [Color] { casinoPocketColors }
    private var segmentCount: Int { pocketColors.count }

    var body: some View {
        ZStack {
            // Wooden outer rim
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.55, green: 0.30, blue: 0.10),
                            Color(red: 0.30, green: 0.15, blue: 0.05)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
                .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 3))
                .shadow(color: .black.opacity(0.35), radius: 8, x: 0, y: 4)

            // Gold inner ring
            Circle()
                .strokeBorder(
                    LinearGradient(
                        colors: [Color(red: 1.0, green: 0.85, blue: 0.3), Color(red: 0.7, green: 0.5, blue: 0.1)],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 8
                )
                .frame(width: 215, height: 215)

            // Pockets (the spinning part)
            ZStack {
                ForEach(0..<segmentCount, id: \.self) { i in
                    Wedge(
                        start: .degrees(Double(i) * 360.0 / Double(segmentCount) - 90),
                        end:   .degrees(Double(i + 1) * 360.0 / Double(segmentCount) - 90)
                    )
                    .fill(pocketColors[i])
                    .overlay(
                        Wedge(
                            start: .degrees(Double(i) * 360.0 / Double(segmentCount) - 90),
                            end:   .degrees(Double(i + 1) * 360.0 / Double(segmentCount) - 90)
                        )
                        .stroke(Color(red: 1.0, green: 0.85, blue: 0.3), lineWidth: 1.5)
                    )
                }

                // Cross spokes
                Capsule()
                    .fill(Color(red: 0.85, green: 0.65, blue: 0.15))
                    .frame(width: 8, height: 130)
                Capsule()
                    .fill(Color(red: 0.85, green: 0.65, blue: 0.15))
                    .frame(width: 130, height: 8)

                // Center hub
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(red: 1.0, green: 0.9, blue: 0.4),
                                Color(red: 0.65, green: 0.45, blue: 0.05)
                            ],
                            center: .center, startRadius: 2, endRadius: 32
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(Circle().stroke(Color.black.opacity(0.5), lineWidth: 2))

                Circle()
                    .fill(Color.black.opacity(0.85))
                    .frame(width: 14, height: 14)
            }
            .frame(width: 200, height: 200)
            .clipShape(Circle())
            .rotationEffect(.degrees(wheelRotation))

            // Ball — small white sphere on the outer track, spins opposite the wheel
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(white: 0.75)],
                        center: .topLeading, startRadius: 0, endRadius: 10
                    )
                )
                .frame(width: 14, height: 14)
                .shadow(color: .black.opacity(0.4), radius: 2, x: 1, y: 1)
                .offset(y: -108)
                .rotationEffect(.degrees(ballRotation))
                .opacity(isRolling ? 1.0 : 0.85)
        }
    }
}

private struct Wedge: Shape {
    let start: Angle
    let end: Angle
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }
}

private struct CasinoButton: View {
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundColor(color == .black ? .white : .black.opacity(0.85))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.15), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Simple Mode View (Off / Random)

struct SimpleModeView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Effects Grid View (Idle / Queue)

struct EffectsGridView: View {
    @ObservedObject var controller: FuxController
    let onEffectTap: (Effect) -> Void
    @State private var editingEffect: Effect?

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        switch controller.effectsLoadingState {
        case .idle, .loading:
            VStack(spacing: 12) {
                Spacer()
                ProgressView()
                Text("Loading effects…")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
        case .failed(let error):
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.orange)
                Text("Failed to load effects")
                    .fontWeight(.semibold)
                Text(error)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button("Retry") { controller.loadEffects() }
                    .buttonStyle(.bordered)
                Spacer()
            }
        case .loaded:
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(controller.availableEffects) { effect in
                        EffectPreviewCard(
                            effect: effect,
                            previewImage: controller.previewImages[effect.name],
                            isCurrentlyPlaying: effect.name == controller.currentEffect
                        ) {
                            onEffectTap(effect)
                        }
                        .onLongPressGesture(minimumDuration: 0.5) {
                            editingEffect = effect
                        }
                    }
                }
                .padding()
            }
            .sheet(item: $editingEffect) { effect in
                EffectEditorSheet(effect: effect, controller: controller)
            }
        }
    }
}

// MARK: - Effect Preview Card

struct EffectPreviewCard: View {
    let effect: Effect
    let previewImage: UIImage?
    let isCurrentlyPlaying: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            // Preview area
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.tertiarySystemFill))

                if let img = previewImage {
                    GIFImageView(image: img)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    placeholderGradient
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if isCurrentlyPlaying {
                    Label("Playing", systemImage: "play.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.accentColor)
                        .clipShape(Capsule())
                        .padding(6)
                }
            }
            .frame(maxWidth: .infinity)
            .aspectRatio(1.2, contentMode: .fit)

            Text(effect.displayName)
                .font(.system(size: 11, weight: isCurrentlyPlaying ? .semibold : .regular))
                .foregroundColor(isCurrentlyPlaying ? .accentColor : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isCurrentlyPlaying ? Color.accentColor.opacity(0.5) : Color.clear,
                    lineWidth: 1.5
                )
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
    }

    private var placeholderGradient: some View {
        let hash = abs(effect.name.hash)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = (hue1 + 0.3).truncatingRemainder(dividingBy: 1.0)
        return LinearGradient(
            colors: [
                Color(hue: hue1, saturation: 0.6, brightness: 0.75),
                Color(hue: hue2, saturation: 0.6, brightness: 0.55)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Error Banner

struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .lineLimit(2)
            Spacer()
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.12))
    }
}

// MARK: - Connection Status Bar

struct ConnectionStatusBar: View {
    let status: ConnectionStatus
    let host: String
    let onTap: () -> Void
    let onRetry: () -> Void

    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(statusText)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            if status == .ConnectionFailed || status == .NotConnected {
                Button(action: onRetry) {
                    Label("Reconnect", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(status == .ConnectionFailed ? .red : .blue)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .onTapGesture { onTap() }
    }

    private var statusColor: Color {
        switch status {
        case .Connected:        return .green
        case .Connecting:       return .yellow
        case .ConnectionFailed: return .red
        case .NotConnected:     return .gray
        }
    }

    private var statusText: String {
        switch status {
        case .Connected:        return "Connected to \(host)"
        case .Connecting:       return "Connecting…"
        case .ConnectionFailed: return "Connection Failed"
        case .NotConnected:     return "Not Connected"
        }
    }
}

// MARK: - Connection Settings Sheet

struct ConnectionSettingsSheet: View {
    @ObservedObject var controller: FuxController
    @Environment(\.dismiss) private var dismiss
    @State private var customURL: String = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Connection Status")) {
                    HStack {
                        Text("Status")
                        Spacer()
                        ConnectionStatusIndicator(status: controller.connectionStatus)
                    }
                }
                Section(header: Text("Server Address")) {
                    Picker("Server", selection: Binding(
                        get: { controller.savedHost },
                        set: { controller.setHost($0) }
                    )) {
                        ForEach(FuxController.knownHosts, id: \.self) { host in
                            Text(host).tag(host)
                        }
                    }
                    .pickerStyle(.inline)

                    HStack {
                        TextField("Custom host", text: $customURL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        Button("Connect") {
                            controller.setHost(customURL)
                        }
                        .disabled(customURL.isEmpty)
                    }
                }
                Section(header: Text("Actions")) {
                    Button("Request State") { controller.requestState() }
                        .disabled(controller.connectionStatus != .Connected)
                    Button("Disconnect", role: .destructive) { controller.disconnect() }
                        .disabled(controller.connectionStatus == .NotConnected)
                }
            }
            .navigationTitle("Connection Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Connection Status Indicator

struct ConnectionStatusIndicator: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusText)
                .font(.subheadline)
        }
    }

    private var statusColor: Color {
        switch status {
        case .Connected:        return .green
        case .Connecting:       return .yellow
        case .ConnectionFailed: return .red
        case .NotConnected:     return .gray
        }
    }

    private var statusText: String {
        switch status {
        case .Connected:        return "Connected"
        case .Connecting:       return "Connecting"
        case .ConnectionFailed: return "Failed"
        case .NotConnected:     return "Not Connected"
        }
    }
}

// MARK: - Effect Editor Sheet

struct EffectEditorSheet: View {
    let effect: Effect
    @ObservedObject var controller: FuxController
    @Environment(\.dismiss) private var dismiss
    @State private var editedValues: [String: String] = [:]
    @State private var isSaving = false
    @State private var saveError: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Effect")) {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(effect.displayName)
                            .foregroundColor(.secondary)
                    }
                    if let desc = effect.description {
                        HStack {
                            Text("Description")
                            Spacer()
                            Text(desc)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }

                if let params = effect.parameters, !params.isEmpty {
                    Section(header: Text("Parameters")) {
                        ForEach(params) { param in
                            parameterRow(param)
                        }
                    }
                }

                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Edit \(effect.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { save() }
                        .font(.body.weight(.semibold))
                        .disabled(isSaving)
                }
            }
            .onAppear { initializeValues() }
        }
    }

    @ViewBuilder
    private func parameterRow(_ param: EffectParameter) -> some View {
        let key = param.name
        switch param.type {
        case "boolean":
            Toggle(paramLabel(key), isOn: Binding(
                get: { editedValues[key] == "true" },
                set: { editedValues[key] = $0 ? "true" : "false" }
            ))
        case "string":
            HStack {
                Text(paramLabel(key))
                Spacer()
                TextField("Value", text: binding(for: key))
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
            }
        case "array":
            HStack {
                Text(paramLabel(key))
                Spacer()
                TextField("Values (comma-separated)", text: binding(for: key))
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 200)
                    .font(.system(.body, design: .monospaced))
            }
        default: // number
            HStack {
                Text(paramLabel(key))
                Spacer()
                TextField("Value", text: binding(for: key))
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 120)
                    .font(.system(.body, design: .monospaced))
            }
        }
    }

    private func paramLabel(_ name: String) -> String {
        name.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { editedValues[key] ?? "" },
            set: { editedValues[key] = $0 }
        )
    }

    private func initializeValues() {
        guard let params = effect.parameters else { return }
        for param in params {
            if let defaultValue = param.defaultValue {
                editedValues[param.name] = defaultValue.displayString
            }
        }
    }

    private func save() {
        guard let params = effect.parameters else { return }
        isSaving = true
        saveError = nil

        // Build typed parameter dictionary
        var typedParams: [String: Any] = [:]
        for param in params {
            guard let strValue = editedValues[param.name] else { continue }
            switch param.type {
            case "number":
                if let num = Double(strValue) {
                    // Send as Int if it's a whole number
                    if num == num.rounded() && !strValue.contains(".") {
                        typedParams[param.name] = Int(num)
                    } else {
                        typedParams[param.name] = num
                    }
                }
            case "boolean":
                typedParams[param.name] = (strValue == "true")
            case "array":
                let components = strValue.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                // Try parsing as numbers first
                let numbers = components.compactMap { Double($0) }
                if numbers.count == components.count {
                    // Check if all are whole numbers
                    if numbers.allSatisfy({ $0 == $0.rounded() }) && !strValue.contains(".") {
                        typedParams[param.name] = numbers.map { Int($0) }
                    } else {
                        typedParams[param.name] = numbers
                    }
                } else {
                    typedParams[param.name] = components
                }
            default:
                typedParams[param.name] = strValue
            }
        }

        print("Saving effect \(effect.name) with params: \(typedParams)")

        Task {
            do {
                let updated = try await controller.apiClient.updateEffectParameters(
                    name: effect.id,
                    parameters: typedParams
                )
                await MainActor.run {
                    // Update the effect in the controller's list
                    if let idx = controller.availableEffects.firstIndex(where: { $0.id == effect.id }) {
                        controller.availableEffects[idx] = Effect(from: updated)
                    }
                    // Clear cached preview so it regenerates with new params
                    controller.apiClient.invalidatePreviewCache(for: effect.name)
                    controller.previewImages.removeValue(forKey: effect.name)
                    isSaving = false
                    dismiss()
                }
                // Reload preview for this effect
                if let image = try? await controller.apiClient.fetchPreview(for: effect.name) {
                    await MainActor.run {
                        controller.previewImages[effect.name] = image
                    }
                }
            } catch {
                print("Save failed for \(effect.name): \(error)")
                await MainActor.run {
                    saveError = "Failed to save: \(error.localizedDescription)"
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Preview

struct EffectControlView_Previews: PreviewProvider {
    static var previews: some View {
        EffectControlView()
    }
}
