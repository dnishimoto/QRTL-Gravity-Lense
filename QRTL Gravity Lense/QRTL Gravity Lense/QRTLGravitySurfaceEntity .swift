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

    private(set) var photonPaths:
        [[SIMD3<Double>]] = []

    private(set) var galaxyProjectionPositions:
        [SIMD3<Double>] = []

    private let lensingParameters =
        LensingParameters()

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

        // ========================================================
        // AUTHORITATIVE SCENE ↔ PHYSICAL CONVERSION
        // ========================================================

        MetersPerSceneUnit.configure(
            clusterRadiusMeters:
                Double(field.clusterRadiusMeters),
            extentSceneUnits:
                Double(self.extent)
        )

        super.init()

        buildScene(
            lensingParameters:
                lensingParameters
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

        // --------------------------------------------------------
        // CALCULATE AUTHORITATIVE POTENTIAL RANGE FIRST
        // --------------------------------------------------------

        calculateMaximumPotential()

        // --------------------------------------------------------
        // CURVED GRAVITY SURFACE
        // --------------------------------------------------------

        let surface =
            makeSurfaceNode()

        surfaceNode =
            surface

        addChildNode(
            surface
        )

        // --------------------------------------------------------
        // IMPORTANT:
        //
        // NO PHOTON PROPAGATION OCCURS HERE.
        //
        // Photon paths are supplied separately by
        // QRTLPhotonTracer through:
        //
        // setPhotonPathsForDisplay(...)
        //
        // --------------------------------------------------------
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

        // --------------------------------------------------------
        // Clamp in SceneKit space.
        // --------------------------------------------------------

        let clampedDisplayRadius =
            min(
                max(
                    displayRadius,
                    0.0
                ),
                extent
            )

        // --------------------------------------------------------
        // Convert SceneKit units → physical meters.
        // --------------------------------------------------------

        let physicalRadius =
            MetersPerSceneUnit.sceneUnitsToMeters(
                clampedDisplayRadius
            )

        // --------------------------------------------------------
        // Authoritative radial potential.
        // --------------------------------------------------------

        let potential =
            field.interpolateRadialPotential(
                radius:
                    physicalRadius
            )

        guard potential.isFinite else {
            return 0.0
        }

        // Gravitational potential is negative.
        // Surface depth uses its positive magnitude.
        return Float(
            abs(potential)
        )
    }

    // ============================================================
    // SURFACE HEIGHT
    // ============================================================
    //
    // The surface represents a gravitational well.
    //
    // At the center:
    //
    //     |Phi| = maximum
    //     Y    = negative maximum depth
    //
    // Far from the source:
    //
    //     |Phi| → smaller
    //     Y    → 0
    //
    // Therefore:
    //
    //     center = LOWEST point
    //     edge   = HIGHER point
    //
    // ============================================================

    func surfaceHeight(
        x: Float,
        z: Float
    ) -> Float {

        let potentialMagnitude =
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
                    potentialMagnitude /
                        normalization,
                    0.0
                ),
                1.0
            )

        // --------------------------------------------------------
        // Curvilinear visual mapping.
        //
        // The exponent controls visual compression only.
        // It does not alter the authoritative potential.
        // --------------------------------------------------------

        let curvature =
            pow(
                normalized,
                0.45
            )

        // --------------------------------------------------------
        // IMPORTANT:
        //
        // Negative sign makes gravity depth DOWNWARD.
        //
        // Without this sign the bowl is inverted.
        // --------------------------------------------------------

        let depth =
            -curvature *
            curvatureScale

        guard depth.isFinite else {
            return 0.0
        }

        return depth
    }

    // ============================================================
    // CURVATURE INTENSITY
    // ============================================================
    //
    // Visualization/color only.
    //
    // This does not modify photon propagation.
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
                    potential /
                        normalization,
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
    // CURVILINEAR GRAVITY SURFACE
    // ============================================================
    //
    // X/Z are the spatial coordinates.
    //
    // Y is the visual depth produced by the gravitational
    // potential.
    //
    //                 Y
    //                 ↑
    //
    //        \                 /
    //         \               /
    //          \             /
    //           \           /
    //            \         /
    //             \       /
    //              \     /
    //               \   /
    //                \_/
    //                 ●
    //              center
    //
    // The center is the deepest point.
    //
    // ============================================================

    private func makeSurfaceGeometry()
        -> SCNGeometry
    {

        let n =
            max(
                gridSize,
                4
            )

        let size =
            extent

        let start =
            -size

        let step =
            (
                2.0 *
                size
            ) /
            Float(
                n - 1
            )

        var positions:
            [SCNVector3] = []

        positions.reserveCapacity(
            n * n
        )

        var indices:
            [Int32] = []

        indices.reserveCapacity(
            (
                n - 1
            ) *
            (
                n - 1
            ) *
            6
        )

        // ========================================================
        // CREATE CURVED GRID
        // ========================================================

        for j in 0..<n {

            for i in 0..<n {

                let x =
                    start +
                    Float(i) *
                    step

                let z =
                    start +
                    Float(j) *
                    step

                let y =
                    surfaceHeight(
                        x: x,
                        z: z
                    )

                positions.append(
                    SCNVector3(
                        x,
                        y,
                        z
                    )
                )
            }
        }

        // ========================================================
        // TRIANGULATE GRID
        // ========================================================

        for j in 0..<(n - 1) {

            for i in 0..<(n - 1) {

                let index =
                    Int32(
                        j * n + i
                    )

                indices.append(
                    contentsOf: [
                        index,
                        index + 1,
                        index + Int32(n),

                        index + 1,
                        index + 1 +
                            Int32(n),
                        index + Int32(n)
                    ]
                )
            }
        }

        // ========================================================
        // GEOMETRY SOURCES
        // ========================================================

        let source =
            SCNGeometrySource(
                vertices:
                    positions
            )

        let element =
            SCNGeometryElement(
                indices:
                    indices,
                primitiveType:
                    .triangles
            )

        return SCNGeometry(
            sources: [
                source
            ],
            elements: [
                element
            ]
        )
    }

    // ============================================================
    // SURFACE NODE
    // ============================================================

    private func makeSurfaceNode()
        -> SCNNode
    {

        let node =
            SCNNode()

        let geometry =
            makeSurfaceGeometry()

        // ========================================================
        // MATERIAL
        // ========================================================

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor.systemGreen
                .withAlphaComponent(
                    0.82
                )

        material.specular.contents =
            UIColor.white
                .withAlphaComponent(
                    0.45
                )

        material.emission.contents =
            UIColor.systemGreen
                .withAlphaComponent(
                    0.10
                )

        material.isDoubleSided =
            true

        material.transparency =
            0.82

        material.lightingModel =
            .physicallyBased

        geometry.materials = [
            material
        ]

        node.geometry =
            geometry

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

    private func calculateMaximumPotential() {

        maximumPotential =
            0.0

        let sampleCount =
            max(
                gridSize * 8,
                512
            )

        for index in 0...sampleCount {

            let normalizedRadius =
                Float(index) /
                Float(sampleCount)

            let physicalRadius =
                Double(
                    normalizedRadius
                ) *
                Double(
                    field.clusterRadiusMeters
                )

            let potential =
                field.interpolateRadialPotential(
                    radius:
                        physicalRadius
                )

            guard potential.isFinite else {
                continue
            }

            let magnitude =
                Float(
                    abs(
                        potential
                    )
                )

            maximumPotential =
                max(
                    maximumPotential,
                    magnitude
                )
        }
    }

    // ============================================================
    // DIAGNOSTIC PHYSICS SAMPLE
    // ============================================================

    func diagnosticSample(
        field: QRTLField,
        positionMeters: SIMD3<Float>
    ) -> QRTLGravitySurfaceSample {

        let density =
            field.physicalMassDensity(
                at:
                    positionMeters
            )

        let normalizedDensity =
            Double(
                field.normalizedDensity(
                    at:
                        positionMeters
                )
            )

        let influence =
            Double(
                field.influence(
                    at:
                        positionMeters
                )
            )

        let potential =
            field.gravitationalPotential(
                at:
                    positionMeters
            )

        let c =
            299_792_458.0

        let normalizedPotential =
            potential /
            (c * c)

        return QRTLGravitySurfaceSample(
            positionMeters:
                positionMeters,

            massDensity:
                density,

            normalizedDensity:
                normalizedDensity,

            qrtlInfluence:
                influence,

            gravitationalPotential:
                potential,

            normalizedPotential:
                normalizedPotential
        )
    }

    // ============================================================
    // PHOTON PATH DISPLAY
    // ============================================================
    //
    // IMPORTANT:
    //
    // This class does NOT calculate photon trajectories.
    //
    // QRTLPhotonTracer is authoritative.
    //
    // This method only receives already calculated paths and
    // renders them.
    //
    // ============================================================

    func setPhotonPathsForDisplay(
        _ paths: [[SIMD3<Float>]],
        projectionHits:
            [SIMD3<Float>] = []
    ) {

        photonPaths =
            paths.map {
                path in

                path.map {
                    point in

                    SIMD3<Double>(
                        Double(point.x),
                        Double(point.y),
                        Double(point.z)
                    )
                }
            }

        galaxyProjectionPositions =
            projectionHits.map {
                point in

                SIMD3<Double>(
                    Double(point.x),
                    Double(point.y),
                    Double(point.z)
                )
            }

        // ========================================================
        // REMOVE OLD GRAPHICS
        // ========================================================

        photonNode?
            .removeFromParentNode()

        galaxyNode?
            .removeFromParentNode()

        // ========================================================
        // PHOTON PATHS
        // ========================================================

        let photonGraphicsNode =
            makeTravelingPhotonParticles(
                paths:
                    photonPaths,
                color:
                    .white
            )

        photonNode =
            photonGraphicsNode

        addChildNode(
            photonGraphicsNode
        )

        // ========================================================
        // PROJECTED GALAXY
        // ========================================================

        let galaxy =
            makeProjectionNode(
                positions:
                    galaxyProjectionPositions,
                color:
                    .white
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
        paths:
            [[SIMD3<Double>]],
        color:
            UIColor
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
                    point in

                    point.x.isFinite &&
                    point.y.isFinite &&
                    point.z.isFinite
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
            // INITIAL POSITION
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
            // TRACE SEQUENCE
            // ====================================================

            var moves:
                [SCNAction] = []

            moves.reserveCapacity(
                validPoints.count - 1
            )

            for index in
                1..<validPoints.count
            {

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
                    SCNAction.run {
                        _ in

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
        positions:
            [SIMD3<Double>],
        color:
            UIColor
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
                        CGFloat(
                            radius
                        )
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

    // ============================================================
    // SCENE → METERS EXAMPLE
    // ============================================================
    //
    // SceneKit coordinates must be converted before they are
    // passed into the authoritative physical field.
    //
    // Example:
    //
    // let scenePosition =
    //     SIMD3<Float>(
    //         x,
    //         0.0,
    //         z
    //     )
    //
    // let positionMeters =
    //     SIMD3<Float>(
    //         Float(
    //             MetersPerSceneUnit
    //                 .sceneUnitsToMeters(
    //                     scenePosition.x
    //                 )
    //         ),
    //
    //         Float(
    //             MetersPerSceneUnit
    //                 .sceneUnitsToMeters(
    //                     scenePosition.y
    //                 )
    //         ),
    //
    //         Float(
    //             MetersPerSceneUnit
    //                 .sceneUnitsToMeters(
    //                     scenePosition.z
    //                 )
    //         )
    //     )
    //
    // Then:
    //
    // let density =
    //     field.physicalMassDensity(
    //         at:
    //             positionMeters
    //     )
    //
    // let potential =
    //     field.gravitationalPotential(
    //         at:
    //             positionMeters
    //     )
    //
    // ============================================================
}
