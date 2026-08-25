//
// QRTLGravitySurfaceEntity.swift
// QRTL Gravity Lense
//
// Consumer / Renderer of the authoritative QRTL physics.
//
// QRTLField
//      ↓
// authoritative gravity potential
//
// QRTLPhotonTracer
//      ↓
// authoritative photon propagation
//
// QRTLGravitySurfaceEntity
//      ↓
// visualization only
//

import Foundation
import SceneKit
import simd
import UIKit

// ============================================================
// QRTL GRAVITY SURFACE ENTITY
// ============================================================

final class QRTLGravitySurfaceEntity: SCNNode {

    // ============================================================
    // AUTHORITATIVE PHYSICS
    // ============================================================

    private let field: QRTLField

    // ============================================================
    // RENDERING CONFIGURATION
    // ============================================================

    private let gridSize: Int
    private let extent: Float
    private let numberOfStars: Int
    private let curvatureScale: Float

    // ============================================================
    // SCENE CONTENT
    // ============================================================

    private(set) var surfaceNode: SCNNode?
    private(set) var photonNode: SCNNode?
    private(set) var galaxyNode: SCNNode?

    // ============================================================
    // AUTHORITATIVE PHOTON RESULTS
    // ============================================================

    private(set) var photonPaths: [[SIMD3<Double>]] = []

    private(set) var galaxyProjectionPositions:
        [SIMD3<Double>] = []

    private let lensingParameters = LensingParameters()

    // ============================================================
    // VISUALIZATION STATE
    // ============================================================

    private var maximumPotential: Float = 0.0

    // ============================================================
    // INITIALIZATION
    // ============================================================

    init(
        field: QRTLField,
        gridSize: Int = 64,
        extent: Float = 2.0,
        numberOfStars: Int = 220,
        curvatureScale: Float = 1.0
    ) {

        self.field = field

        self.gridSize = max(
            gridSize,
            4
        )

        self.extent = max(
            extent,
            0.001
        )

        self.numberOfStars = max(
            numberOfStars,
            1
        )

        self.curvatureScale = max(
            curvatureScale,
            0.0001
        )

        super.init()

        buildScene(
            lensingParameters: lensingParameters
        )
    }

    required init?(coder: NSCoder) {

        fatalError(
            "QRTLGravitySurfaceEntity does not support NSCoder initialization."
        )
    }

    // ============================================================
    // BUILD SCENE
    // ============================================================

    func buildScene(
        lensingParameters: LensingParameters
    ) {

        clearScene()

        maximumPotential = 0.0

        // ========================================================
        // FLAT CIRCULAR GRAVITY VISUALIZATION PLANE
        // ========================================================
        //
        // This is visualization only.
        //
        // It does NOT represent physical spacetime coordinates.
        //
        // It does NOT modify photon positions.
        //
        // ========================================================

        let surface = makeSurfaceNode()

        surfaceNode = surface

        addChildNode(surface)

        // ========================================================
        // PHOTONS ARE ADDED ONLY THROUGH:
        //
        // setPhotonPathsForDisplay(...)
        //
        // ========================================================
    }

    // ============================================================
    // AUTHORITATIVE POTENTIAL SAMPLE
    // ============================================================

    func samplePotentialMagnitude(
        x: Float,
        z: Float
    ) -> Float {

        let displayRadius =
            sqrt(
                x * x +
                z * z
            )

        let normalizedRadius =
            min(
                max(
                    displayRadius / extent,
                    0.0
                ),
                1.0
            )

        let physicalRadius =
            Double(normalizedRadius) *
            Double(field.clusterRadiusMeters)

        let potential =
            field.interpolateRadialPotential(
                radius: physicalRadius
            )

        guard potential.isFinite else {
            return 0.0
        }

        return Float(
            abs(potential)
        )
    }

    // ============================================================
    // SURFACE HEIGHT
    // ============================================================
    //
    // The plane is intentionally FLAT.
    //
    // There is no radial bowl.
    //
    // ============================================================

    func surfaceHeight(
        x: Float,
        z: Float
    ) -> Float {

        return 0.0
    }

    // ============================================================
    // CURVATURE INTENSITY
    // ============================================================
    //
    // Used only for visualization/color.
    //
    // This does NOT change photon position.
    //
    // ============================================================

    func curvatureIntensity(
        x: Float,
        z: Float
    ) -> Float {

        let potential =
            samplePotentialMagnitude(
                x: x,
                z: z
            )

        let normalization =
            max(
                maximumPotential,
                1.0e-30
            )

        let normalized =
            min(
                max(
                    potential / normalization,
                    0.0
                ),
                1.0
            )

        return pow(
            normalized,
            0.45
        )
    }

    // ============================================================
    // CURVATURE COLOR
    // ============================================================

    static func curvatureColor(
        intensity: Float,
        calmColor: UIColor,
        hotColor: UIColor = .white
    ) -> UIColor {

        let t =
            CGFloat(
                min(
                    max(
                        intensity,
                        0.0
                    ),
                    1.0
                )
            )

        var calmRed: CGFloat = 0.0
        var calmGreen: CGFloat = 0.0
        var calmBlue: CGFloat = 0.0
        var calmAlpha: CGFloat = 0.0

        calmColor.getRed(
            &calmRed,
            green: &calmGreen,
            blue: &calmBlue,
            alpha: &calmAlpha
        )

        var hotRed: CGFloat = 0.0
        var hotGreen: CGFloat = 0.0
        var hotBlue: CGFloat = 0.0
        var hotAlpha: CGFloat = 0.0

        hotColor.getRed(
            &hotRed,
            green: &hotGreen,
            blue: &hotBlue,
            alpha: &hotAlpha
        )

        return UIColor(
            red:
                calmRed +
                (hotRed - calmRed) * t,

            green:
                calmGreen +
                (hotGreen - calmGreen) * t,

            blue:
                calmBlue +
                (hotBlue - calmBlue) * t,

            alpha: 1.0
        )
    }

    // ============================================================
    // CLEAR SCENE
    // ============================================================

    private func clearScene() {

        childNodes.forEach {
            $0.removeFromParentNode()
        }

        surfaceNode = nil
        photonNode = nil
        galaxyNode = nil

        photonPaths.removeAll(
            keepingCapacity: true
        )

        galaxyProjectionPositions.removeAll(
            keepingCapacity: true
        )
    }

    // ============================================================
    // FLAT CIRCULAR SURFACE
    // ============================================================
    //
    // This replaces the old radial bowl.
    //
    // The geometry is physically flat:
    //
    //                 Y
    //                 ↑
    //
    //        ┌─────────────────┐
    //        │                 │
    //        │   FLAT PLANE    │
    //        │                 │
    //        └─────────────────┘
    //
    // No potential is added to Y.
    //
    // ============================================================

    private func makeSurfaceNode() -> SCNNode {

        let node = SCNNode()

        let radius =
            CGFloat(extent)

        let geometry =
            SCNCylinder(
                radius: radius,
                height: 0.001
            )

        // ========================================================
        // MATERIAL
        // ========================================================

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor.systemGreen.withAlphaComponent(
                0.82
            )

        material.specular.contents =
            UIColor.white.withAlphaComponent(
                0.45
            )

        material.emission.contents =
            UIColor.systemGreen.withAlphaComponent(
                0.10
            )

        material.isDoubleSided = true

        material.transparency = 0.82

        material.lightingModel =
            .physicallyBased

        geometry.materials = [
            material
        ]

        node.geometry =
            geometry

        // ========================================================
        // FLAT PLANE POSITION
        // ========================================================

        node.position =
            SCNVector3(
                0.0,
                0.0,
                0.0
            )

        return node
    }

    // ============================================================
    // INITIALIZE POTENTIAL RANGE
    // ============================================================
    //
    // Because the radial bowl has been removed, we must calculate
    // maximumPotential independently.
    //
    // This samples the same radial potential used by the flat
    // visualization.
    //
    // ============================================================

    private func calculateMaximumPotential() {

        maximumPotential = 0.0

        let sampleCount =
            max(
                gridSize,
                32
            )

        for index in 0...sampleCount {

            let normalizedRadius =
                Float(index) /
                Float(sampleCount)

            let physicalRadius =
                Double(normalizedRadius) *
                Double(field.clusterRadiusMeters)

            let potential =
                field.interpolateRadialPotential(
                    radius: physicalRadius
                )

            guard potential.isFinite else {
                continue
            }

            let magnitude =
                Float(abs(potential))

            maximumPotential =
                max(
                    maximumPotential,
                    magnitude
                )
        }

        print(
            """
            QRTL Gravity Surface Entity
            ============================================================
            QRTL FLAT SURFACE POTENTIAL RANGE
            ============================================================

            maximumPotential = \(maximumPotential)

            clusterRadiusMeters =
                \(field.clusterRadiusMeters)

            extent =
                \(extent)

            ============================================================
            """
        )
    }

    // ============================================================
    // PHOTON PIPELINE
    // ============================================================

    /// Visualization only.
    ///
    /// Paths must already come from QRTLPhotonTracer.
    ///
    /// No second photon propagation occurs here.

    func setPhotonPathsForDisplay(
        _ paths: [[SIMD3<Float>]],
        projectionHits: [SIMD3<Float>] = []
    ) {

        photonPaths =
            paths.map { path in

                path.map {

                    SIMD3<Double>(
                        Double($0.x),
                        Double($0.y),
                        Double($0.z)
                    )
                }
            }

        galaxyProjectionPositions =
            projectionHits.map {

                SIMD3<Double>(
                    Double($0.x),
                    Double($0.y),
                    Double($0.z)
                )
            }

        // ========================================================
        // REMOVE OLD PHOTON GRAPHICS
        // ========================================================

        photonNode?.removeFromParentNode()

        galaxyNode?.removeFromParentNode()

        // ========================================================
        // PHOTONS
        // ========================================================

        let photonGraphicsNode =
            makeTravelingPhotonParticles(
                paths: photonPaths,
                color: .white
            )

        photonNode =
            photonGraphicsNode

        addChildNode(
            photonGraphicsNode
        )

        // ========================================================
        // PROJECTION
        // ========================================================

        let galaxy =
            makeProjectionNode(
                positions:
                    galaxyProjectionPositions,
                color: .white
            )

        galaxyNode =
            galaxy

        addChildNode(
            galaxy
        )
    }

    // ============================================================
    // RAW TRAVELING PHOTON PARTICLES
    // ============================================================

    private func makeTravelingPhotonParticles(
        paths: [[SIMD3<Double>]],
        color: UIColor
    ) -> SCNNode {

        let parent =
            SCNNode()

        let particleRadius =
            max(
                0.008,
                Double(extent) /
                Double(gridSize) *
                0.35
            )

        let secondsPerPoint =
            0.012

        for path in paths {

            guard path.count > 1 else {
                continue
            }

            let validPoints =
                path.filter {

                    $0.x.isFinite &&
                    $0.y.isFinite &&
                    $0.z.isFinite
                }

            guard validPoints.count > 1 else {
                continue
            }

            let sphere =
                SCNSphere(
                    radius:
                        CGFloat(
                            particleRadius
                        )
                )

            let material =
                SCNMaterial()

            let initialIntensity =
                curvatureIntensity(
                    x:
                        Float(
                            validPoints[0].x
                        ),
                    z:
                        Float(
                            validPoints[0].z
                        )
                )

            let initialColor =
                Self.curvatureColor(
                    intensity:
                        initialIntensity,
                    calmColor:
                        color
                )

            material.diffuse.contents =
                initialColor

            material.emission.contents =
                initialColor

            material.isDoubleSided =
                true

            material.lightingModel =
                .constant

            sphere.materials = [
                material
            ]

            let particleNode =
                SCNNode(
                    geometry:
                        sphere
                )

            // ====================================================
            // RAW INITIAL POSITION
            // ====================================================

            particleNode.position =
                SCNVector3(
                    Float(
                        validPoints[0].x
                    ),
                    Float(
                        validPoints[0].y
                    ),
                    Float(
                        validPoints[0].z
                    )
                )

            // ====================================================
            // RAW TRACE SEQUENCE
            // ====================================================

            var moves:
                [SCNAction] = []

            moves.reserveCapacity(
                validPoints.count - 1
            )

            for index in
                1..<validPoints.count {

                let point =
                    validPoints[index]

                let destination =
                    SCNVector3(
                        Float(point.x),
                        Float(point.y),
                        Float(point.z)
                    )

                let moveAction =
                    SCNAction.move(
                        to:
                            destination,
                        duration:
                            secondsPerPoint
                    )

                // =================================================
                // VISUAL COLOR ONLY
                // =================================================

                let intensity =
                    curvatureIntensity(
                        x:
                            Float(point.x),
                        z:
                            Float(point.z)
                    )

                let stepColor =
                    Self.curvatureColor(
                        intensity:
                            intensity,
                        calmColor:
                            color
                    )

                let colorAction =
                    SCNAction.run { _ in

                        material.diffuse.contents =
                            stepColor

                        material.emission.contents =
                            stepColor
                    }

                moves.append(
                    SCNAction.group(
                        [
                            moveAction,
                            colorAction
                        ]
                    )
                )
            }

            guard !moves.isEmpty else {
                continue
            }

            let travel =
                SCNAction.sequence(
                    moves
                )

            let loop =
                SCNAction.repeatForever(
                    travel
                )

            particleNode.runAction(
                loop
            )

            parent.addChildNode(
                particleNode
            )
        }

        return parent
    }

    // ============================================================
    // PROJECTED GALAXY
    // ============================================================

    private func makeProjectionNode(
        positions: [SIMD3<Double>],
        color: UIColor
    ) -> SCNNode {

        let parent =
            SCNNode()

        let radius =
            max(
                0.012,
                Double(extent) /
                Double(gridSize) *
                0.55
            )

        let projectionOffset:
            Float = 0.003

        for position in positions {

            guard
                position.x.isFinite,
                position.y.isFinite,
                position.z.isFinite
            else {
                continue
            }

            let sphere =
                SCNSphere(
                    radius:
                        CGFloat(radius)
                )

            let material =
                SCNMaterial()

            material.diffuse.contents =
                color

            material.emission.contents =
                color

            material.specular.contents =
                UIColor.white

            material.isDoubleSided =
                true

            material.lightingModel =
                .constant

            sphere.materials = [
                material
            ]

            let node =
                SCNNode(
                    geometry:
                        sphere
                )

            node.position =
                SCNVector3(
                    Float(position.x) +
                        projectionOffset,
                    Float(position.y),
                    Float(position.z)
                )

            parent.addChildNode(
                node
            )
        }

        return parent
    }
}
