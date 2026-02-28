//
//  ContentView.swift
//  NeuralGraphics
//
//  Created by Amélie Heinrich on 22/02/2026.
//

import SwiftUI
import Metal

// MARK: - Panel Edge

enum PanelEdge {
    case left, right, top, bottom

    var insertionTransition: AnyTransition {
        switch self {
        case .left:   return .move(edge: .leading).combined(with: .opacity)
        case .right:  return .move(edge: .trailing).combined(with: .opacity)
        case .top:    return .move(edge: .top).combined(with: .opacity)
        case .bottom: return .move(edge: .bottom).combined(with: .opacity)
        }
    }
}

// MARK: - HUD Action Model

struct HUDAction: Identifiable {
    let id: String
    let icon: String
    let label: String
    let color: Color
    let edge: PanelEdge
}

// MARK: - HUD Button

private struct HUDButton: View {
    let action: HUDAction
    let isActive: Bool
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 5) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            isActive
                                ? action.color.opacity(0.30)
                                : (isHovered ? action.color.opacity(0.18) : action.color.opacity(0.08))
                        )
                        .frame(width: 46, height: 46)

                    Image(systemName: action.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(
                            isActive ? action.color : (isHovered ? action.color : action.color.opacity(0.7))
                        )
                        .scaleEffect(isActive ? 1.1 : 1.0)
                }

                Text(action.label)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(
                        isActive ? action.color : (isHovered ? .primary : .secondary)
                    )
            }
            .frame(width: 60, height: 64)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.13), value: isHovered)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
        .help(action.label)
    }
}

// MARK: - HUD Pill

private struct HUDPill: View {
    let actions: [HUDAction]
    @Binding var activePanel: String?
    @Binding var isExpanded: Bool

    var body: some View {
        HStack(spacing: 2) {
            ForEach(actions) { item in
                HUDButton(
                    action: item,
                    isActive: activePanel == item.id
                ) {
                    withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) {
                        activePanel = (activePanel == item.id) ? nil : item.id
                    }
                }

                if item.id != actions.last?.id {
                    Divider()
                        .frame(height: 28)
                        .opacity(0.25)
                        .padding(.horizontal, 2)
                }
            }

            Divider()
                .frame(height: 28)
                .opacity(0.25)
                .padding(.horizontal, 2)

            // Dismiss button
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                    activePanel = nil
                    isExpanded = false
                }
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Hide toolbar")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.13), lineWidth: 1))
        .shadow(color: .black.opacity(0.40), radius: 20, y: 8)
    }
}

// MARK: - Reveal Button

private struct RevealButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 13, weight: .bold))
                Text("Menu")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(isHovered ? .primary : .secondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(isHovered ? 0.22 : 0.10), lineWidth: 1))
            .shadow(color: .black.opacity(0.30), radius: 10, y: 4)
            .opacity(isHovered ? 1.0 : 0.72)
            .scaleEffect(isHovered ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .help("Show toolbar")
    }
}

// MARK: - Panel Container

private struct PanelContainer<Content: View>: View {
    let title: String
    let color: Color
    let edge: PanelEdge
    let onClose: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                        .shadow(color: color.opacity(0.8), radius: 4)
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(0.07), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().opacity(0.3)

            // Panel content
            content()
        }
        .background(.ultraThinMaterial)
        .overlay(
            panelBorder
        )
        .clipShape(panelShape)
        .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 6)
    }

    @ViewBuilder
    private var panelBorder: some View {
        panelShape
            .strokeBorder(.white.opacity(0.12), lineWidth: 1)
    }

    private var panelShape: some InsettableShape {
        switch edge {
        case .left:
            return UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 0,
                bottomTrailingRadius: 16, topTrailingRadius: 16
            )
        case .right:
            return UnevenRoundedRectangle(
                topLeadingRadius: 16, bottomLeadingRadius: 16,
                bottomTrailingRadius: 0, topTrailingRadius: 0
            )
        case .top:
            return UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: 16,
                bottomTrailingRadius: 16, topTrailingRadius: 0
            )
        case .bottom:
            return UnevenRoundedRectangle(
                topLeadingRadius: 16, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: 16
            )
        }
    }
}

// MARK: - ContentView

struct ContentView: View {

    @State private var renderer: MetalViewDelegate = {
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("This device does not support Metal.")
        }
        return Renderer(device: device)
    }()

    @State private var isHUDExpanded = false
    @State private var activePanel: String? = nil

    // MARK: Panel definitions
    private let actions: [HUDAction] = [
        HUDAction(id: "about",    icon: "info.circle",       label: "About",    color: .cyan,   edge: .left),
        HUDAction(id: "settings", icon: "gearshape",         label: "Settings", color: .indigo, edge: .right),
        HUDAction(id: "training", icon: "brain.head.profile", label: "Training", color: .pink,   edge: .top),
        HUDAction(id: "stats",    icon: "chart.bar.xaxis",   label: "Stats",    color: .orange, edge: .bottom),
    ]

    private func action(for id: String) -> HUDAction? {
        actions.first { $0.id == id }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // Full-screen Metal render view
            MetalView(delegate: renderer)
                .ignoresSafeArea()

            // Left panel (About)
            if let panel = action(for: "about"), activePanel == "about" {
                HStack(spacing: 0) {
                    PanelContainer(title: panel.label, color: panel.color, edge: .left) {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) { activePanel = nil }
                    } content: {
                        AboutView()
                    }
                    .frame(width: 260)
                    .frame(maxHeight: .infinity)
                    Spacer()
                }
                .transition(panel.edge.insertionTransition)
            }

            // Right panel (Settings)
            if let panel = action(for: "settings"), activePanel == "settings" {
                HStack(spacing: 0) {
                    Spacer()
                    PanelContainer(title: panel.label, color: panel.color, edge: .right) {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) { activePanel = nil }
                    } content: {
                        PlaceholderPanelView(title: panel.label, icon: panel.icon, color: panel.color, description: "Renderer settings will appear here.")
                    }
                    .frame(width: 260)
                    .frame(maxHeight: .infinity)
                }
                .transition(panel.edge.insertionTransition)
            }

            // Top panel (Training)
            if let panel = action(for: "training"), activePanel == "training" {
                VStack(spacing: 0) {
                    PanelContainer(title: panel.label, color: panel.color, edge: .top) {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) { activePanel = nil }
                    } content: {
                        PlaceholderPanelView(title: panel.label, icon: panel.icon, color: panel.color, description: "Neural network training controls will appear here.")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    Spacer()
                }
                .transition(panel.edge.insertionTransition)
            }

            // Bottom panel (Stats) — sits above the HUD bar
            if let panel = action(for: "stats"), activePanel == "stats" {
                VStack(spacing: 0) {
                    Spacer()
                    PanelContainer(title: panel.label, color: panel.color, edge: .bottom) {
                        withAnimation(.spring(response: 0.36, dampingFraction: 0.74)) { activePanel = nil }
                    } content: {
                        PlaceholderPanelView(title: panel.label, icon: panel.icon, color: panel.color, description: "GPU timing and frame statistics will appear here.")
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    // Leave room for the HUD pill
                    .padding(.bottom, 86)
                }
                .transition(panel.edge.insertionTransition)
            }

            // Bottom HUD overlay
            VStack {
                Spacer()

                if isHUDExpanded {
                    HUDPill(actions: actions, activePanel: $activePanel, isExpanded: $isHUDExpanded)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.80, anchor: .bottom)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(y: 12)),
                                removal: .scale(scale: 0.80, anchor: .bottom)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(y: 12))
                            )
                        )
                }

                if !isHUDExpanded {
                    RevealButton {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
                            isHUDExpanded = true
                        }
                    }
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 6)),
                            removal:   .opacity.combined(with: .offset(y: 6))
                        )
                    )
                }
            }
            .padding(.bottom, 18)
        }
    }
}

// MARK: - Placeholder Panel View

struct PlaceholderPanelView: View {
    let title: String
    let icon: String
    let color: Color
    let description: String

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(color)
            }
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Text(description)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
