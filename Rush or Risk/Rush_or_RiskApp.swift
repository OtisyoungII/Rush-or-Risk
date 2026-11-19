//
//  Rush_or_RiskApp.swift
//  Rush or Risk
//
//  Created by Otis Young on 3/30/25.
//

import SwiftUI

@main
struct Rush_or_RiskApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.arguments.contains("-startGame") {
                GameViewControllerWrapper(mode: Self.developerMode)
                    .ignoresSafeArea()
                    .statusBarHidden(true)
            } else {
                ContentView()
            }
        }
    }

    private static var developerMode: GameMode {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-endless") { return .endless }
        if let index = args.firstIndex(of: "-level"), args.indices.contains(index + 1), let value = Int(args[index + 1]) {
            return .level(value)
        }
        return .level(1)
    }
}
