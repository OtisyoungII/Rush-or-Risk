import SpriteKit
import UIKit

final class EffectsCoordinator {
    private weak var scene: SKScene?
    private let reducedMotion: Bool
    init(scene: SKScene, reducedMotion: Bool) { self.scene = scene; self.reducedMotion = reducedMotion }

    func catchBurst(at point: CGPoint, points: Int, combo: Int) {
        guard let scene else { return }
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = combo > 1 ? "+\(points)  x\(combo)" : "+\(points)"
        label.fontSize = 21; label.fontColor = .yellow; label.position = point; label.zPosition = 40
        scene.addChild(label)
        label.run(.sequence([.group([.moveBy(x: 0, y: reducedMotion ? 20 : 48, duration: 0.4), .fadeOut(withDuration: 0.4)]), .removeFromParent()]))
        guard !reducedMotion else { return }
        for index in 0..<7 {
            let dot = SKShapeNode(circleOfRadius: 3); dot.fillColor = index.isMultiple(of: 2) ? .systemBlue : .yellow
            dot.strokeColor = .clear; dot.position = point; dot.zPosition = 35; scene.addChild(dot)
            let angle = CGFloat(index) / 7 * .pi * 2
            dot.run(.sequence([.group([.moveBy(x: cos(angle) * 38, y: sin(angle) * 38, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        }
    }

    func shake(_ node: SKNode) {
        guard !reducedMotion else { return }
        node.run(.sequence([.moveBy(x: -5, y: 0, duration: 0.035), .moveBy(x: 10, y: 0, duration: 0.07), .moveBy(x: -5, y: 0, duration: 0.035)]))
    }

    func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType, enabled: Bool) {
        if enabled { UINotificationFeedbackGenerator().notificationOccurred(type) }
    }
}
