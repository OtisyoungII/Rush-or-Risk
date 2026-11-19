//
//  GameControllerWrapper.swift
//  Rush or Risk
//
//  Created by Otis Young on 3/30/25.
//

import SwiftUI
import UIKit

struct GameViewControllerWrapper: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    let mode: GameMode

    init(mode: GameMode = .level(1)) { self.mode = mode }

    func makeUIViewController(context: Context) -> GameViewController {
        let controller = GameViewController(mode: mode)
        controller.onExit = { dismiss() }
        return controller
    }

    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {
    }
}
