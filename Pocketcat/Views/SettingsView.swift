//
//  SettingsView.swift
//  Pocketcat
//
//  Created by Amélie Heinrich on 02/03/2026.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var registry: SettingsRegistry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ForEach(registry.orderedSections(), id: \.0) { section, keys in
                    SettingsSectionView(section: section, keys: keys, registry: registry)
                }
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SettingsSectionView: View {
    let section: String
    let keys: [String]
    @ObservedObject var registry: SettingsRegistry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(section)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            ForEach(keys, id: \.self) { key in
                SettingRowView(key: key, registry: registry)
            }
        }
    }
}

private struct SettingRowView: View {
    let key: String
    @ObservedObject var registry: SettingsRegistry

    var body: some View {
        if let entry = registry.entry(for: key) {
            switch entry.metadata {
            case .bool:
                HStack {
                    Text(entry.label)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Toggle("", isOn: registry.binding(bool: key))
                        .toggleStyle(.switch)
                        .labelsHidden()
                }

            case .int(let range):
                HStack {
                    Text(entry.label)
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("\(registry.int(key))")
                        .font(.system(size: 12).monospacedDigit())
                        .foregroundStyle(.secondary)
                    Stepper("", value: registry.binding(int: key), in: range)
                        .labelsHidden()
                }

            case .float(let range, let step):
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(entry.label)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text(String(format: "%.2f", registry.float(key)))
                            .font(.system(size: 12).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: registry.binding(float: key), in: range, step: step)
                        .tint(.indigo)
                }

            case .enumType:
                if case .enumCase(_, let labels) = registry.entry(for: key)?.value {
                    HStack {
                        Text(entry.label)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Picker("", selection: registry.bindingIndex(key)) {
                            ForEach(Array(labels.enumerated()), id: \.offset) { idx, label in
                                Text(label).tag(idx)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: 120)
                    }
                }
            }
        }
    }
}
