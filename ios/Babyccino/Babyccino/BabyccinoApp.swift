//
//  BabyccinoApp.swift
//  Babyccino
//
//  Created by Joseph Landon on 1/16/26.
//

import SwiftUI

@main
struct BabyccinoApp: App {
    @StateObject private var serverClient = ServerClient()
    @State private var showOnboarding = !hasCompletedOnboarding()

    var body: some Scene {
        WindowGroup {
            if showOnboarding {
                OnboardingView(isComplete: $showOnboarding)
            } else {
                ChatView(serverClient: serverClient)
                    .task {
                        // Check server health on launch
                        _ = try? await serverClient.checkHealth()
                    }
            }
        }
    }

    private static func hasCompletedOnboarding() -> Bool {
        return UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }
}
