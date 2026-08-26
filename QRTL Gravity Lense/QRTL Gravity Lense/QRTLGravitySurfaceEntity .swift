
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

// Uses MetersPerSceneUnit.swift for authoritative scene-to-meters conversion.

// ============================================================
// QRTL GRAVITY SURFACE ENTITY
// ============================================================

final class QRTLGravitySurfaceEntity: SCNNode {

    // ============================================================
    // AUTHORITATIVE SCENE↔PHYSICAL CONVERSION
    // ============================================================
    //
    // Configured in init() from the real field.clusterRadiusMeters
    // and the real extent this surface is drawn at.
    //
    // Every scene-to-meter conversion in this file goes through
    // MetersPerSceneUnit.
    //
    // ============================================================

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

        // ========================================================
        // CONFIGURE AUTHORITATIVE SCENE↔PHYSICAL CONVERSION
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

        // ========================================================
        // AUTHORITATIVE POTENTIAL RANGE
        // ========================================================

        calculateMaximumPotential()

        // ========================================================
        // EINSTEIN CURVILINEAR SPATIAL SURFACE
        // ========================================================
        //
        // X/Y are the coordinate-plane directions.
        //
        // Z is the embedding/depth direction generated from the
        // relativistic radial spatial metric.
        //
        // Photon propagation remains authoritative in
        // QRTLPhotonTracer.
        //
        // ========================================================

        let surface = makeSurfaceNode()

        surfaceNode = surface

        addChildNode(surface)
    }

    // ============================================================
    // AUTHORITATIVE POTENTIAL SAMPLE
    // ============================================================

    func samplePotentialMagnitude(
        x: Float,
        z: Float
    ) -> Float {

        let displayRadius = sqrt(
            x * x +
            z * z
        )

        let clampedDisplayRadius = min(
            max(
                displayRadius,
                0.0
            ),
            extent
        )

        let physicalRadius =
            MetersPerSceneUnit.sceneUnitsToMeters(
                clampedDisplayRadius
            )

        let potential =
            field.interpolateRadialPotential(
                radius:
                    physicalRadius
            )

        guard potential.isFinite else {
            return 0.0
        }

        return Float(
            abs(potential)
        )
    }

    // ============================================================
    // EINSTEIN CURVILINEAR SPATIAL METRIC
    // ============================================================
    //
    // For the static spherical spatial metric:
    //
    //     ds_r² = g_rr dr²
    //
    // with
    //
    //     g_rr = 1 / (1 + 2Φ/c²)
    //
    // where Φ is the authoritative QRTL gravitational potential.
    //
    // The corresponding embedding surface satisfies:
    //
    //     dz/dr = sqrt(g_rr - 1)
    //
    // Therefore Z is calculated by integrating the relativistic
    // spatial metric instead of assigning normalized potential
    // directly to a visual height.
    //
    // ============================================================

    private func relativisticRadialMetric(
        radiusMeters: Double
    ) -> Double {

        let c = 299_792_458.0

        let potential =
            field.interpolateRadialPotential(
                radius:
                    max(
                        radiusMeters,
                        0.0
                    )
            )

        guard potential.isFinite else {
            return 1.0
        }

        let phiOverC2 =
            potential /
            (c * c)

        let denominator =
            1.0 +
            2.0 *
            phiOverC2

        guard
            denominator.isFinite,
            denominator > 0.0
        else {
            return 1.0
        }

        let metric =
            1.0 /
            denominator

        guard
            metric.isFinite,
            metric >= 1.0
        else {
            return 1.0
        }

        return metric
    }

    // ============================================================
    // RADIAL EMBEDDING DEPTH
    // ============================================================
    //
    // Integrates:
    //
    //     dz/dr = sqrt(g_rr - 1)
    //
    // from the center to the requested radial coordinate.
    //
    // ============================================================

    private func radialEmbeddingDepthMeters(
        radiusMeters: Double
    ) -> Double {

        guard
            radiusMeters.isFinite,
            radiusMeters > 0.0
        else {
            return 0.0
        }

        let integrationSteps =
            max(
                gridSize * 2,
                128
            )

        let dr =
            radiusMeters /
            Double(integrationSteps)

        var depthMeters = 0.0

        for index in 1...integrationSteps {

            let r0 =
                Double(index - 1) *
                dr

            let r1 =
                Double(index) *
                dr

            let rm =
                0.5 *
                (r0 + r1)

            let metric =
                relativisticRadialMetric(
                    radiusMeters:
                        rm
                )

            let slope =
                sqrt(
                    max(
                        metric - 1.0,
                        0.0
                    )
                )

            if slope.isFinite {

                depthMeters +=
                    slope *
                    dr
            }
        }

        return depthMeters
    }

    // ============================================================
    // SURFACE DEPTH
    // ============================================================
    //
    // X/Y define radial distance in the coordinate plane.
    //
    // Z is the Einstein curvilinear embedding depth.
    //
    // ============================================================

    private func surfaceDepth(
        x: Float,
        y: Float
    ) -> Float {

        let displayRadius =
            sqrt(
                x * x +
                y * y
            )

        let clampedDisplayRadius =
            min(
                max(
                    displayRadius,
                    0.0
                ),
                extent
            )

        let radiusMeters =
            MetersPerSceneUnit.sceneUnitsToMeters(
                clampedDisplayRadius
            )

        let depthMeters =
            radialEmbeddingDepthMeters(
                radiusMeters:
                    radiusMeters
            )

        // MetersPerSceneUnit does not require a second conversion
        // implementation. Obtain the configured meters represented
        // by one SceneKit unit and invert that scale.

        let metersPerSceneUnit =
            MetersPerSceneUnit.sceneUnitsToMeters(
                1.0
            )

        guard
            metersPerSceneUnit.isFinite,
            metersPerSceneUnit > 0.0
        else {
            return 0.0
        }

        let depthSceneUnits =
            depthMeters /
            metersPerSceneUnit

        guard depthSceneUnits.isFinite else {
            return 0.0
        }

        // Negative Z places the gravitational embedding toward
        // negative depth.
        //
        // The magnitude comes from the Einstein metric.
        //
        return -Float(depthSceneUnits) *
            curvatureScale
    }

    // ============================================================
    // SURFACE HEIGHT
    // ============================================================
    //
    // Backward-compatible entry point.
    //
    // The parameter historically named "z" is treated as the
    // second coordinate of the radial surface.
    //
    // The returned value is now Einstein-metric embedding depth.
    //
    // ============================================================

    func surfaceHeight(
        x: Float,
        z: Float
    ) -> Float {

        return surfaceDepth(
            x: x,
            y: z
        )
    }

    // ============================================================
    // CURVATURE INTENSITY
    // ============================================================
    //
    // Used only for visualization/color.
    //
    // This does not change photon position.
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
    // EINSTEIN CURVILINEAR SURFACE MESH
    // ============================================================
    //
    // X/Y form the coordinate plane.
    //
    // Z is the embedding/depth coordinate.
    //
    // Each vertex follows:
    //
    //     X/Y radius
    //          ↓
    //     physical radius
    //          ↓
    //     QRTL potential Φ
    //          ↓
    //     g_rr
    //          ↓
    //     sqrt(g_rr - 1)
    //          ↓
    //     radial integration
    //          ↓
    //     Z depth
    //
    // ============================================================

    private func makeSurfaceNode() -> SCNNode {

        let node = SCNNode()

        let resolution =
            max(
                gridSize,
                4
            )

        let vertexCount =
            resolution + 1

        var vertices:
            [SCNVector3] = []

        var normals:
            [SCNVector3] = []

        var indices:
            [Int32] = []

        vertices.reserveCapacity(
            vertexCount *
            vertexCount
        )

        normals.reserveCapacity(
            vertexCount *
            vertexCount
        )

        indices.reserveCapacity(
            resolution *
            resolution *
            6
        )

        // ========================================================
        // BUILD CURVED VERTICES
        // ========================================================

        for row in 0...resolution {

            let y =
                -extent +
                (2.0 * extent) *
                Float(row) /
                Float(resolution)

            for column in 0...resolution {

                let x =
                    -extent +
                    (2.0 * extent) *
                    Float(column) /
                    Float(resolution)

                let radius =
                    sqrt(
                        x * x +
                        y * y
                    )

                let z: Float

                if radius <= extent {

                    z =
                        surfaceDepth(
                            x: x,
                            y: y
                        )

                } else {

                    z = 0.0
                }

                vertices.append(
                    SCNVector3(
                        x,
                        y,
                        z
                    )
                )

                normals.append(
                    SCNVector3(
                        0.0,
                        0.0,
                        1.0
                    )
                )
            }
        }

        // ========================================================
        // BUILD TRIANGLES
        // ========================================================

        for row in 0..<resolution {

            for column in 0..<resolution {

                let topLeft =
                    Int32(
                        row *
                        vertexCount +
                        column
                    )

                let topRight =
                    topLeft + 1

                let bottomLeft =
                    Int32(
                        (row + 1) *
                        vertexCount +
                        column
                    )

                let bottomRight =
                    bottomLeft + 1

                indices.append(
                    topLeft
                )

                indices.append(
                    topRight
                )

                indices.append(
                    bottomLeft
                )

                indices.append(
                    topRight
                )

                indices.append(
                    bottomRight
                )

                indices.append(
                    bottomLeft
                )
            }
        }

        // ========================================================
        // CALCULATE SMOOTH SURFACE NORMALS
        // ========================================================

        for row in 0...resolution {

            for column in 0...resolution {

                let leftColumn =
                    max(
                        column - 1,
                        0
                    )

                let rightColumn =
                    min(
                        column + 1,
                        resolution
                    )

                let upperRow =
                    max(
                        row - 1,
                        0
                    )

                let lowerRow =
                    min(
                        row + 1,
                        resolution
                    )

                let left =
                    vertices[
                        row *
                        vertexCount +
                        leftColumn
                    ]

                let right =
                    vertices[
                        row *
                        vertexCount +
                        rightColumn
                    ]

                let upper =
                    vertices[
                        upperRow *
                        vertexCount +
                        column
                    ]

                let lower =
                    vertices[
                        lowerRow *
                        vertexCount +
                        column
                    ]

                let dx =
                    SIMD3<Float>(
                        right.x - left.x,
                        right.y - left.y,
                        right.z - left.z
                    )

                let dy =
                    SIMD3<Float>(
                        lower.x - upper.x,
                        lower.y - upper.y,
                        lower.z - upper.z
                    )

                let crossProduct =
                    simd_cross(
                        dx,
                        dy
                    )

                let length =
                    simd_length(
                        crossProduct
                    )

                if
                    length.isFinite &&
                    length > 1.0e-12
                {

                    let normal =
                        crossProduct /
                        length

                    normals[
                        row *
                        vertexCount +
                        column
                    ] =
                        SCNVector3(
                            normal.x,
                            normal.y,
                            normal.z
                        )
                }
            }
        }

        // ========================================================
        // GEOMETRY SOURCES
        // ========================================================

        let vertexSource =
            SCNGeometrySource(
                vertices:
                    vertices
            )

        let normalSource =
            SCNGeometrySource(
                normals:
                    normals
            )

        let indexData =
            indices.withUnsafeBufferPointer {
                Data(
                    buffer: $0
                )
            }

        let element =
            SCNGeometryElement(
                data:
                    indexData,

                primitiveType:
                    .triangles,

                primitiveCount:
                    indices.count / 3,

                bytesPerIndex:
                    MemoryLayout<Int32>.size
            )

        let geometry =
            SCNGeometry(
                sources: [
                    vertexSource,
                    normalSource
                ],

                elements: [
                    element
                ]
            )

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
                    radius:
                        physicalRadius
                )

            guard potential.isFinite else {
                continue
            }

            let magnitude =
                Float(
                    abs(potential)
                )

            maximumPotential =
                max(
                    maximumPotential,
                    magnitude
                )
        }
    }

    // ============================================================
    // DIAGNOSTIC SAMPLE
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
    // PHOTON PIPELINE
    // ============================================================
    //
    // Visualization only.
    //
    // Paths must already come from QRTLPhotonTracer.
    //
    // No second photon propagation occurs here.
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

        photonNode?
            .removeFromParentNode()

        galaxyNode?
            .removeFromParentNode()

        // ========================================================
        // PHOTONS
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
        // PROJECTION
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
    // EXAMPLE:
    // CONVERTING SCENE POSITION TO METERS
    // ============================================================
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
    //
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
