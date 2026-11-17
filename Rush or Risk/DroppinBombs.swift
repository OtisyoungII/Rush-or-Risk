import SpriteKit

// Historical compatibility shim. Spawning is now owned by GameScene's
// frame-rate-independent update loop rather than a Foundation Timer.
final class DroppinBombs {
    weak var scene: GameScene?

    init(scene: GameScene) { self.scene = scene }
    func startBombTimer() {}
    func update() {}
    func pause() {}
    func resume() {}
    func stopAllBombs() {}
    func explodeBombsInOrder() {}
    func cleanup() {}
}
