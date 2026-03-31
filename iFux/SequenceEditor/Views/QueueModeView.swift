//
//  QueueModeView.swift
//  iFux
//
//  Created on 18.03.26.
//

import SwiftUI
import UIKit

struct QueueModeView: View {
    @ObservedObject var controller: FuxController
    @State private var isQueueDrawerExpanded = false
    @State private var selectedEffect: Effect?

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Effects Content
                effectsContent
                    .padding(.bottom, isQueueDrawerExpanded ? 250 : 80)
            }

            // Queue Drawer
            QueueDrawer(
                queue: controller.queue,
                isExpanded: $isQueueDrawerExpanded,
                currentEffect: controller.currentEffect,
                remainingSeconds: controller.remainingSeconds,
                onClearQueue: {
                    controller.clearQueue()
                }
            )
        }
        .background(Color(UIColor.systemBackground))
        .sheet(item: $selectedEffect) { effect in
            EffectDetailSheet(
                effect: effect,
                previewImage: controller.previewImages[effect.name],
                onAddToQueue: {
                    controller.addToQueue(effect: effect)
                    withAnimation(.spring(response: 0.3)) {
                        isQueueDrawerExpanded = true
                    }
                }
            )
        }
    }

    @ViewBuilder
    private var effectsContent: some View {
        switch controller.effectsLoadingState {
        case .idle:
            Spacer()
        case .loading:
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading effects...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        case .loaded:
            if controller.availableEffects.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "sparkles")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No effects available")
                        .font(.headline)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        Text("Available Effects (\(controller.availableEffects.count))")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top)

                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                            GridItem(.flexible(), spacing: 8),
                        ], spacing: 8) {
                            ForEach(controller.availableEffects) { effect in
                                EffectCard(
                                    effect: effect,
                                    previewImage: controller.previewImages[effect.name],
                                    onTap: {
                                        controller.addToQueue(effect: effect)
                                        withAnimation(.spring(response: 0.3)) {
                                            isQueueDrawerExpanded = true
                                        }
                                    },
                                    onLongPress: {
                                        selectedEffect = effect
                                    }
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .refreshable {
                    controller.refreshEffects()
                }
            }
        case .failed(let message):
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                Text("Failed to load effects")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button {
                    controller.loadEffects()
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.subheadline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Effect Card
struct EffectCard: View {
    let effect: Effect
    let previewImage: UIImage?
    let onTap: () -> Void
    let onLongPress: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
            onTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
            }
        }) {
            VStack(spacing: 6) {
                // Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(UIColor.tertiarySystemFill))
                    if let image = previewImage {
                        GIFImageView(image: image)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1.2, contentMode: .fit)

                Text(effect.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.primary)
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
                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture {
            onLongPress()
        }
    }
}

// MARK: - Effect Detail Sheet
struct EffectDetailSheet: View {
    let effect: Effect
    let previewImage: UIImage?
    let onAddToQueue: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Preview
                    if let image = previewImage {
                        GIFImageView(image: image)
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 12) {
                        if let desc = effect.description {
                            Text(desc)
                                .font(.body)
                                .foregroundColor(.secondary)
                        }

                        // Tags
                        if let tags = effect.tags, !tags.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(
                                            Capsule()
                                                .fill(Color.accentColor.opacity(0.15))
                                        )
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }

                        // Metadata
                        VStack(alignment: .leading, spacing: 8) {
                            if let type = effect.type {
                                DetailRow(label: "Type", value: type.capitalized)
                            }
                            if let algorithm = effect.algorithm {
                                DetailRow(label: "Algorithm", value: algorithm)
                            }
                            if let fps = effect.fps {
                                DetailRow(label: "FPS", value: "\(fps)")
                            }
                            if let version = effect.version {
                                DetailRow(label: "Version", value: version)
                            }
                        }
                    }

                    // Parameters
                    if let params = effect.parameters, !params.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Parameters")
                                .font(.headline)

                            ForEach(params) { param in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(param.name)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text("Type: \(param.type)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    if let defaultVal = param.defaultValue {
                                        Text(defaultVal.displayString)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color(UIColor.tertiarySystemGroupedBackground))
                                )
                            }
                        }
                    }

                    // Add to Queue Button
                    Button(action: {
                        onAddToQueue()
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add to Queue")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(14)
                    }
                }
                .padding()
            }
            .navigationTitle(effect.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Queue Drawer
struct QueueDrawer: View {
    let queue: [Effect]
    @Binding var isExpanded: Bool
    let currentEffect: String?
    let remainingSeconds: Double?
    let onClearQueue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DrawerHandle(
                isExpanded: $isExpanded,
                queueCount: queue.count,
                currentEffect: currentEffect,
                remainingSeconds: remainingSeconds
            )

            if isExpanded {
                queueContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(UIColor.secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }

    @ViewBuilder
    private var queueContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let effect = currentEffect {
                NowPlayingRow(effectName: effect, remainingSeconds: remainingSeconds)
                    .padding(.horizontal)
                Divider()
            }

            HStack {
                Text("Up Next (\(queue.count))")
                    .font(.headline)
                Spacer()
                if !queue.isEmpty {
                    Button(action: onClearQueue) {
                        Label("Clear", systemImage: "trash")
                            .font(.subheadline)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal)

            Divider()

            if queue.isEmpty {
                emptyQueueView
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(queue.enumerated()), id: \.offset) { index, effect in
                            QueueItemRow(effect: effect, index: index + 1)
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 130)
            }
        }
        .padding(.vertical)
    }

    private var emptyQueueView: some View {
        VStack(spacing: 8) {
            Image(systemName: "list.bullet")
                .font(.system(size: 30))
                .foregroundColor(.secondary)
            Text("Queue is empty")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Tap effects above to add them")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 90)
    }
}

// MARK: - Now Playing Row
struct NowPlayingRow: View {
    let effectName: String
    let remainingSeconds: Double?

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 2) {
                ForEach(0..<3) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.accentColor)
                        .frame(width: 3, height: 12)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(i) * 0.15),
                            value: effectName
                        )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Now Playing")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(effectName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentColor)
            }

            Spacer()

            if let secs = remainingSeconds {
                Text("\(Int(secs.rounded()))s")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Drawer Handle
struct DrawerHandle: View {
    @Binding var isExpanded: Bool
    let queueCount: Int
    let currentEffect: String?
    let remainingSeconds: Double?

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }) {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)

                HStack {
                    Image(systemName: "list.bullet")
                        .font(.subheadline)

                    if let effect = currentEffect {
                        Text(effect)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        if let secs = remainingSeconds {
                            Text("\u{00B7} \(Int(secs.rounded()))s")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    } else {
                        Text("Queue (\(queueCount))")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .foregroundColor(.primary)
                .padding(.horizontal)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Queue Item Row
struct QueueItemRow: View {
    let effect: Effect
    let index: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(width: 28, height: 28)
                Text("\(index)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }

            Text(effect.displayName)
                .font(.subheadline)

            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(UIColor.tertiarySystemGroupedBackground))
        )
    }
}

// MARK: - Preview
struct QueueModeView_Previews: PreviewProvider {
    static var previews: some View {
        QueueModeView(controller: FuxController())
    }
}
