// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RushRiskCore",
    platforms: [.macOS(.v13)],
    products: [.library(name: "RushRiskCore", targets: ["RushRiskCore"])],
    targets: [
        .target(
            name: "RushRiskCore",
            path: "Rush or Risk",
            exclude: [
                "Assets.xcassets", "Audio", "Preview Content", "BossMoves.swift", "ContentView.swift",
                "DroppinBombs.swift", "GameControllerWrapper.swift", "GameScene.swift",
                "GamesViewController.swift", "PaddleMoves.swift", "PausedLogic.swift",
                "Rush_or_RiskApp.swift", "AudioManager.swift", "EffectsCoordinator.swift",
                "InputController.swift"
            ],
            sources: [
                "GameSession.swift", "GameDifficulty.swift", "LevelDefinition.swift", "HazardSystem.swift", "ChallengeDirector.swift", "AudioLifecycle.swift",
                "SpawnDirector.swift", "ScoreManager.swift", "LocalStores.swift", "GameplayLayout.swift"
            ]
        ),
        .testTarget(
            name: "RushRiskCoreTests",
            dependencies: ["RushRiskCore"],
            path: "Tests/RushRiskCoreTests"
        )
    ]
)
