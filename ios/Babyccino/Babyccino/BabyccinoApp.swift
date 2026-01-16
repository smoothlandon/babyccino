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

    var body: some Scene {
        WindowGroup {
            ChatView(serverClient: serverClient)
                .task {
                    // Check server health on launch
                    _ = try? await serverClient.checkHealth()
                }
        }
    }
}
