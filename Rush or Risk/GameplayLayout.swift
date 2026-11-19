import Foundation

struct GameplayLayout: Equatable {
    let safeRect: CGRect
    let arenaRect: CGRect
    let hudHeight: CGFloat

    init(viewSize: CGSize, safeInsets: EdgeInsets = .zero) {
        safeRect = CGRect(
            x: safeInsets.left,
            y: safeInsets.bottom,
            width: max(1, viewSize.width - safeInsets.left - safeInsets.right),
            height: max(1, viewSize.height - safeInsets.top - safeInsets.bottom)
        )
        hudHeight = safeRect.width < 680 ? min(78, max(66, safeRect.height * 0.22)) : min(62, max(48, safeRect.height * 0.16))
        arenaRect = CGRect(
            x: safeRect.minX + 8,
            y: safeRect.minY + 8,
            width: max(1, safeRect.width - 16),
            height: max(1, safeRect.height - hudHeight - 14)
        )
    }

    func boundedCatcherX(_ proposedX: CGFloat, catcherWidth: CGFloat) -> CGFloat {
        min(max(proposedX, arenaRect.minX + catcherWidth / 2), arenaRect.maxX - catcherWidth / 2)
    }

    func nextCatcherX(current: CGFloat, target: CGFloat, catcherWidth: CGFloat, deltaTime: TimeInterval) -> CGFloat {
        let boundedTarget = boundedCatcherX(target, catcherWidth: catcherWidth)
        let delta = boundedTarget - current
        let maximumStep = arenaRect.width * 2.6 * CGFloat(max(0, min(deltaTime, 0.1)))
        guard abs(delta) > maximumStep else { return boundedTarget }
        return current + (delta < 0 ? -maximumStep : maximumStep)
    }
}

struct EdgeInsets: Equatable {
    let top: CGFloat
    let left: CGFloat
    let bottom: CGFloat
    let right: CGFloat

    static let zero = EdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
}
