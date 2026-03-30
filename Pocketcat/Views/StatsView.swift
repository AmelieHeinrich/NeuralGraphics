//
//  StatsView.swift
//  Pocketcat
//
//  Created by Amélie Heinrich on 30/03/2026.
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var stats: FrameStats

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                statsSection("FRAME") {
                    statRow("FPS", value: String(format: "%.1f", stats.fps))
                    statRow("Frame time", value: String(format: "%.2f ms", stats.frameTimeMs))
                    statRow("Render res", value: "\(stats.renderWidth) × \(stats.renderHeight)")
                    statRow("Output res", value: "\(stats.outputWidth) × \(stats.outputHeight)")
                    statRow("Scale", value: String(format: "%.2f", stats.renderScale))
                    statRow("Timeline", value: stats.activeTimeline)
                }

                sectionDivider()

                statsSection("GPU TIMINGS") {
                    if stats.passTimings.isEmpty {
                        Text("No data yet")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(Array(stats.passTimings.enumerated()), id: \.offset) { _, timing in
                            passTimingRow(timing)
                        }
                    }
                }

                sectionDivider()

                statsSection("DRAW CALLS") {
                    statRow("Execute indirect", value: "\(stats.executeIndirectCount)")
                    statRow("Direct draws", value: "\(stats.directDrawCount)")
                    statRow("Compute dispatches", value: "\(stats.computeDispatchCount)")
                }

                sectionDivider()

                statsSection("MEMORY") {
                    statRow("GPU allocated", value: String(format: "%.1f MB", stats.gpuAllocatedMB))
                }
            }
            .padding(.bottom, 12)
        }
    }

    @ViewBuilder
    private func statsSection<Content: View>(
        _ title: String, @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 4)
            content()
        }
    }

    private func sectionDivider() -> some View {
        Divider().opacity(0.3).padding(.horizontal, 12)
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }

    private func passTimingRow(_ timing: PassTimingSample) -> some View {
        HStack(spacing: 4) {
            Text(timing.name)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            if timing.gpuMs > 0 {
                Text(String(format: "%.2f ms", timing.gpuMs))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.primary)
            } else {
                Text("—")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Text(String(format: "cpu %.2f", timing.cpuMs))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
}
