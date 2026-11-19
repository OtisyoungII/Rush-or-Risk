import GameController
import Foundation

final class InputController {
    var onMove: ((Double) -> Void)?
    var onPause: (() -> Void)?
    private var observers: [NSObjectProtocol] = []

    init() {
        observers.append(NotificationCenter.default.addObserver(forName: .GCControllerDidConnect, object: nil, queue: .main) { [weak self] note in
            if let controller = note.object as? GCController { self?.configure(controller) }
        })
        GCController.controllers().forEach(configure)
        GCController.startWirelessControllerDiscovery()
    }

    private func configure(_ controller: GCController) {
        controller.extendedGamepad?.leftThumbstick.xAxis.valueChangedHandler = { [weak self] _, value in
            self?.onMove?(Double(value))
        }
        controller.extendedGamepad?.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.onPause?() }
        }
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}
