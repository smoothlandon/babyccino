//
//  OnboardingView.swift
//  Babyccino
//
//  Onboarding flow for mandatory model download on first launch
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var modelManager = ModelManager.shared
    @State private var selectedModel: ModelInfo?
    @State private var isDownloading = false
    @State private var downloadError: String?
    @Binding var isComplete: Bool

    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("Welcome to Babyccino")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("An intelligent Python function designer")
                    .font(.headline)
                    .foregroundColor(.gray)
            }
            .padding(.top, 40)

            Spacer()

            // Model Selection
            VStack(alignment: .leading, spacing: 16) {
                Text("Choose Your AI Model")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Select a model to power your conversations. Models run locally on your device for privacy.")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                // Model list
                ForEach(ModelInfo.availableModels) { model in
                    OnboardingModelCard(
                        model: model,
                        isSelected: selectedModel?.id == model.id,
                        isDownloading: isDownloading && selectedModel?.id == model.id,
                        downloadProgress: getDownloadProgress(for: model.id),
                        onSelect: {
                            if !isDownloading {
                                selectedModel = model
                            }
                        }
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Error message
            if let error = downloadError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
            }

            Spacer()

            // Continue button
            Button(action: downloadAndContinue) {
                HStack {
                    if isDownloading {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(isDownloading ? "Downloading..." : "Get Started")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedModel != nil && !isDownloading ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(selectedModel == nil || isDownloading)
            .padding(.bottom, 40)
        }
        .padding(.horizontal, 30)
    }

    private func getDownloadProgress(for modelId: String) -> Double? {
        if case .downloading(let progress) = modelManager.downloadStates[modelId] {
            return progress
        }
        return nil
    }

    private func downloadAndContinue() {
        guard let model = selectedModel else { return }

        isDownloading = true
        downloadError = nil

        Task {
            do {
                print("📥 Starting download for \(model.displayName)")
                try await modelManager.downloadModel(model)

                // Select the model
                modelManager.selectModel(model.id)

                // Mark onboarding as complete
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")

                print("✅ Onboarding complete with model: \(model.displayName)")

                // Transition to main app
                await MainActor.run {
                    isComplete = true
                }

            } catch {
                print("❌ Download failed: \(error)")
                await MainActor.run {
                    downloadError = "Download failed: \(error.localizedDescription). Please try again."
                    isDownloading = false
                }
            }
        }
    }
}

struct OnboardingModelCard: View {
    let model: ModelInfo
    let isSelected: Bool
    let isDownloading: Bool
    let downloadProgress: Double?
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                // Selection indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.blue : Color.gray, lineWidth: 2)
                        .frame(width: 24, height: 24)

                    if isSelected {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 12, height: 12)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(model.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        // Quality stars
                        HStack(spacing: 2) {
                            ForEach(0..<5) { i in
                                Image(systemName: i < model.quality ? "star.fill" : "star")
                                    .font(.caption2)
                                    .foregroundColor(i < model.quality ? .yellow : .gray)
                            }
                        }

                        // Speed badge
                        Text(model.speed.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(speedColor.opacity(0.2))
                            .foregroundColor(speedColor)
                            .cornerRadius(4)

                        // Size
                        Text("\(model.sizeInMB) MB")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Text(model.description)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(2)

                    // Download progress
                    if isDownloading, let progress = downloadProgress {
                        VStack(alignment: .leading, spacing: 4) {
                            ProgressView(value: progress)
                            Text("\(Int(progress * 100))%")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .padding(.top, 4)
                    }
                }

                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var speedColor: Color {
        switch model.speed {
        case .fast: return .green
        case .medium: return .orange
        case .slow: return .red
        }
    }
}
