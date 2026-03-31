//
//  QueueModeView.swift
//  iFux
//
//  Created on 18.03.26.
//

import SwiftUI

struct QueueModeView: View {
    @ObservedObject var controller: FuxController
    @State private var isQueueDrawerExpanded = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Effects List
            EffectsListView(
                effects: Effect.availableEffects,
                onEffectTap: { effect in
                    controller.addToQueue(effect: effect)
                    withAnimation(.spring(response: 0.3)) {
                        isQueueDrawerExpanded = true
                    }
                }
            )
            .padding(.bottom, isQueueDrawerExpanded ? 250 : 80)
            
            // Queue Drawer
            QueueDrawer(
                queue: controller.queue,
                isExpanded: $isQueueDrawerExpanded,
                currentEffect: controller.currentEffect,
                onClearQueue: {
                    controller.clearQueue()
                }
            )
        }
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Effects List View
struct EffectsListView: View {
    let effects: [Effect]
    let onEffectTap: (Effect) -> Void
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("Available Effects")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                    .padding(.top)
                
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ], spacing: 16) {
                    ForEach(effects) { effect in
                        EffectCard(effect: effect, onTap: {
                            onEffectTap(effect)
                        })
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Effect Card
struct EffectCard: View {
    let effect: Effect
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            onTap()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = false
                }
            }
        }) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(effectGradient)
                        .frame(width: 60, height: 60)
                    
                    Image(systemName: effectIcon)
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                
                Text(effect.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(uiColor: .secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var effectGradient: LinearGradient {
        switch effect.name {
        case "diamond_pulse":
            return LinearGradient(
                colors: [Color.blue, Color.purple],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case "rainbow_pulse":
            return LinearGradient(
                colors: [Color.red, Color.orange, Color.yellow, Color.green, Color.blue, Color.purple],
                startPoint: .leading,
                endPoint: .trailing
            )
        case "color_waves":
            return LinearGradient(
                colors: [Color.cyan, Color.blue],
                startPoint: .top,
                endPoint: .bottom
            )
        case "aurora":
            return LinearGradient(
                colors: [Color.green, Color.teal, Color.blue],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color.gray, Color.gray.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var effectIcon: String {
        switch effect.name {
        case "diamond_pulse":
            return "diamond.fill"
        case "rainbow_pulse":
            return "sparkles"
        case "color_waves":
            return "waveform"
        case "aurora":
            return "sparkle"
        default:
            return "star.fill"
        }
    }
}

// MARK: - Queue Drawer
struct QueueDrawer: View {
    let queue: [Effect]
    @Binding var isExpanded: Bool
    let currentEffect: String?
    let onClearQueue: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Drawer Handle
            DrawerHandle(isExpanded: $isExpanded, queueCount: queue.count)
            
            // Queue Content
            if isExpanded {
                queueContent
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        )
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isExpanded)
    }
    
    @ViewBuilder
    private var queueContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Clear Button
            HStack {
                Text("Queue (\(queue.count))")
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
            
            // Queue Items
            if queue.isEmpty {
                emptyQueueView
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(Array(queue.enumerated()), id: \.element.id) { index, effect in
                            QueueItemRow(
                                effect: effect,
                                index: index + 1,
                                isCurrentlyPlaying: effect.name == currentEffect
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(height: 150)
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
        .frame(height: 100)
    }
}

// MARK: - Drawer Handle
struct DrawerHandle: View {
    @Binding var isExpanded: Bool
    let queueCount: Int
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }) {
            VStack(spacing: 8) {
                // Drag Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 40, height: 5)
                
                // Queue Info
                HStack {
                    Image(systemName: "list.bullet")
                        .font(.subheadline)
                    
                    Text("Queue (\(queueCount))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
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
    let isCurrentlyPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Index Badge
            ZStack {
                Circle()
                    .fill(isCurrentlyPlaying ? Color.accentColor : Color(uiColor: .tertiarySystemFill))
                    .frame(width: 28, height: 28)
                
                if isCurrentlyPlaying {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                } else {
                    Text("\(index)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            
            // Effect Name
            Text(effect.displayName)
                .font(.subheadline)
                .fontWeight(isCurrentlyPlaying ? .semibold : .regular)
                .foregroundColor(isCurrentlyPlaying ? .accentColor : .primary)
            
            Spacer()
            
            // Playing Indicator
            if isCurrentlyPlaying {
                HStack(spacing: 2) {
                    ForEach(0..<3) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor)
                            .frame(width: 3, height: 12)
                            .animation(
                                .easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(i) * 0.15),
                                value: isCurrentlyPlaying
                            )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .tertiarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isCurrentlyPlaying ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Preview
struct QueueModeView_Previews: PreviewProvider {
    static var previews: some View {
        QueueModeView(controller: FuxController())
    }
}
