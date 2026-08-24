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

        // --------------------------------------------------------
        // GRAVITY SURFACE
        // --------------------------------------------------------

        let surface = makeSurfaceNode()

        surfaceNode = surface

        addChildNode(surface)

        // --------------------------------------------------------
        // AUTHORITATIVE PHOTON TRACING
        // --------------------------------------------------------

        computeGalaxyProjections(
            lensingParameters: lensingParameters
        )

        // --------------------------------------------------------
        // RAW PHOTON PATHS
        // --------------------------------------------------------

        let photonGraphicsNode =
            makeTravelingPhotonParticles(
                paths: photonPaths,
                color: .cyan
            )

        photonNode = photonGraphicsNode

        addChildNode(
            photonGraphicsNode
        )

        // --------------------------------------------------------
        // PROJECTED GALAXY
        // --------------------------------------------------------

        let galaxy =
            makeProjectionNode(
                positions: galaxyProjectionPositions,
                color: .cyan
            )

        galaxyNode = galaxy

        addChildNode(
            galaxy
        )
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

        return Float(
            abs(potential)
        )
    }

    // ============================================================
    // VISUAL SURFACE HEIGHT
    // ============================================================
    //
    // IMPORTANT:
    //
    // This function belongs ONLY to the gravity-surface mesh.
    //
    // It MUST NOT be added to a photon position.
    //
    // ============================================================

    func surfaceHeight(
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

        let visualPotential =
            pow(
                normalized,
                0.45
            )

        return
            -visualPotential *
            curvatureScale
    }

    // ============================================================
    // CURVATURE INTENSITY
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
            red: calmRed +
                (hotRed - calmRed) * t,

            green: calmGreen +
                (hotGreen - calmGreen) * t,

            blue: calmBlue +
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
    // SURFACE NODE
    // ============================================================

    private func makeSurfaceNode() -> SCNNode {

        let node = SCNNode()

        node.geometry =
            makeSurfaceGeometry()

        let material = SCNMaterial()

        material.diffuse.contents =
            UIColor.systemGreen.withAlphaComponent(0.82)

        material.specular.contents =
            UIColor.white.withAlphaComponent(0.45)

        material.emission.contents =
            UIColor.systemGreen.withAlphaComponent(0.10)

        material.isDoubleSided = true
        material.transparency = 0.82
        material.lightingModel = .physicallyBased

        node.geometry?.materials = [
            material
        ]

        return node
    }

    // ============================================================
    // GRAVITY SURFACE GEOMETRY
    // ============================================================

    private func makeSurfaceGeometry() -> SCNGeometry {

        maximumPotential = 0.0

        let radialSegments =
            max(
                gridSize / 2,
                16
            )

        let angularSegments =
            max(
                gridSize,
                32
            )

        let bowlRadius =
            extent

        let rimFadeFraction: Float =
            0.18

        var positions: [SCNVector3] = []
        var indices: [Int32] = []
        var potentialMagnitudes: [Float] = []

        positions.reserveCapacity(
            1 +
            radialSegments *
            angularSegments
        )

        potentialMagnitudes.reserveCapacity(
            1 +
            radialSegments *
            angularSegments
        )

        indices.reserveCapacity(
            angularSegments * 3 +
            max(radialSegments - 1, 0) *
            angularSegments * 6
        )

        // --------------------------------------------------------
        // CENTER
        // --------------------------------------------------------

        let centerPotential =
            samplePotentialMagnitude(
                x: 0.0,
                z: 0.0
            )

        potentialMagnitudes.append(
            centerPotential
        )

        // --------------------------------------------------------
        // RINGS
        // --------------------------------------------------------

        for radialIndex in 1...radialSegments {

            let normalizedRadius =
                Float(radialIndex) /
                Float(radialSegments)

            let radius =
                normalizedRadius *
                bowlRadius

            for angularIndex in 0..<angularSegments {

                let angle =
                    2.0 *
                    Float.pi *
                    Float(angularIndex) /
                    Float(angularSegments)

                let x =
                    radius *
                    cos(angle)

                let z =
                    radius *
                    sin(angle)

                let potential =
                    samplePotentialMagnitude(
                        x: x,
                        z: z
                    )

                potentialMagnitudes.append(
                    potential
                )
            }
        }

        // --------------------------------------------------------
        // MAXIMUM
        // --------------------------------------------------------

        maximumPotential =
            potentialMagnitudes.max() ??
            0.0

        print(
            "QRTL GRAVITY SURFACE:",
            "maximumPotential =",
            maximumPotential,
            "samples =",
            potentialMagnitudes.count
        )

        let normalization =
            max(
                maximumPotential,
                1.0e-30
            )

        // --------------------------------------------------------
        // CENTER VERTEX
        // --------------------------------------------------------

        let centerNormalized =
            min(
                max(
                    centerPotential /
                    normalization,
                    0.0
                ),
                1.0
            )

        let centerVisualPotential =
            pow(
                centerNormalized,
                0.45
            )

        let centerY =
            -centerVisualPotential *
            curvatureScale

        positions.append(
            SCNVector3(
                0.0,
                centerY,
                0.0
            )
        )

        // --------------------------------------------------------
        // RING VERTICES
        // --------------------------------------------------------

        var potentialIndex = 1

        for radialIndex in 1...radialSegments {

            let normalizedRadius =
                Float(radialIndex) /
                Float(radialSegments)

            let radius =
                normalizedRadius *
                bowlRadius

            let rimStart =
                max(
                    0.0,
                    1.0 - rimFadeFraction
                )

            let rimFade: Float

            if normalizedRadius <= rimStart {

                rimFade = 1.0

            } else {

                let t =
                    (
                        normalizedRadius -
                        rimStart
                    ) /
                    max(
                        rimFadeFraction,
                        1.0e-6
                    )

                let clamped =
                    min(
                        max(
                            t,
                            0.0
                        ),
                        1.0
                    )

                rimFade =
                    1.0 -
                    clamped *
                    clamped *
                    (
                        3.0 -
                        2.0 * clamped
                    )
            }

            for angularIndex in 0..<angularSegments {

                let angle =
                    2.0 *
                    Float.pi *
                    Float(angularIndex) /
                    Float(angularSegments)

                let x =
                    radius *
                    cos(angle)

                let z =
                    radius *
                    sin(angle)

                let normalizedPotential =
                    min(
                        max(
                            potentialMagnitudes[
                                potentialIndex
                            ] /
                            normalization,
                            0.0
                        ),
                        1.0
                    )

                let visualPotential =
                    pow(
                        normalizedPotential,
                        0.45
                    )

                let y =
                    -visualPotential *
                    curvatureScale *
                    rimFade

                positions.append(
                    SCNVector3(
                        x,
                        y,
                        z
                    )
                )

                potentialIndex += 1
            }
        }

        // --------------------------------------------------------
        // CENTER FAN
        // --------------------------------------------------------

        for angularIndex in 0..<angularSegments {

            let next =
                (
                    angularIndex + 1
                ) %
                angularSegments

            indices.append(0)
            indices.append(
                Int32(1 + next)
            )
            indices.append(
                Int32(1 + angularIndex)
            )
        }

        // --------------------------------------------------------
        // RING CONNECTIONS
        // --------------------------------------------------------

        if radialSegments > 1 {

            for radialIndex in 1..<radialSegments {

                let innerStart =
                    1 +
                    (radialIndex - 1) *
                    angularSegments

                let outerStart =
                    1 +
                    radialIndex *
                    angularSegments

                for angularIndex in 0..<angularSegments {

                    let next =
                        (
                            angularIndex + 1
                        ) %
                        angularSegments

                    let innerA =
                        Int32(
                            innerStart +
                            angularIndex
                        )

                    let innerB =
                        Int32(
                            innerStart +
                            next
                        )

                    let outerA =
                        Int32(
                            outerStart +
                            angularIndex
                        )

                    let outerB =
                        Int32(
                            outerStart +
                            next
                        )

                    indices.append(innerA)
                    indices.append(outerA)
                    indices.append(innerB)

                    indices.append(innerB)
                    indices.append(outerA)
                    indices.append(outerB)
                }
            }
        }

        // --------------------------------------------------------
        // NORMALS
        // --------------------------------------------------------

        var accumulatedNormals =
            Array(
                repeating:
                    SIMD3<Float>(
                        0.0,
                        0.0,
                        0.0
                    ),
                count:
                    positions.count
            )

        for triangleStart in stride(
            from: 0,
            to: indices.count,
            by: 3
        ) {

            let indexA =
                Int(
                    indices[
                        triangleStart
                    ]
                )

            let indexB =
                Int(
                    indices[
                        triangleStart + 1
                    ]
                )

            let indexC =
                Int(
                    indices[
                        triangleStart + 2
                    ]
                )

            let a =
                SIMD3<Float>(
                    positions[indexA].x,
                    positions[indexA].y,
                    positions[indexA].z
                )

            let b =
                SIMD3<Float>(
                    positions[indexB].x,
                    positions[indexB].y,
                    positions[indexB].z
                )

            let c =
                SIMD3<Float>(
                    positions[indexC].x,
                    positions[indexC].y,
                    positions[indexC].z
                )

            let normal =
                simd_cross(
                    b - a,
                    c - a
                )

            accumulatedNormals[indexA] += normal
            accumulatedNormals[indexB] += normal
            accumulatedNormals[indexC] += normal
        }

        var normals: [SCNVector3] = []

        normals.reserveCapacity(
            positions.count
        )

        for accumulated in accumulatedNormals {

            let lengthSquared =
                simd_length_squared(
                    accumulated
                )

            if lengthSquared > 1.0e-12 {

                let normal =
                    simd_normalize(
                        accumulated
                    )

                normals.append(
                    SCNVector3(
                        normal.x,
                        normal.y,
                        normal.z
                    )
                )

            } else {

                normals.append(
                    SCNVector3(
                        0.0,
                        1.0,
                        0.0
                    )
                )
            }
        }

        // --------------------------------------------------------
        // SCENEKIT GEOMETRY
        // --------------------------------------------------------

        let vertexSource =
            SCNGeometrySource(
                vertices: positions
            )

        let normalSource =
            SCNGeometrySource(
                normals: normals
            )

        let element =
            SCNGeometryElement(
                indices: indices,
                primitiveType: .triangles
            )

        return SCNGeometry(
            sources: [
                vertexSource,
                normalSource
            ],
            elements: [
                element
            ]
        )
    }

    // ============================================================
    // PHOTON PIPELINE
    // ============================================================

    func computeGalaxyProjections(
        lensingParameters: LensingParameters
    ) {

        photonPaths.removeAll(
            keepingCapacity: true
        )

        galaxyProjectionPositions.removeAll(
            keepingCapacity: true
        )

        // --------------------------------------------------------
        // SINGLE AUTHORITATIVE TRACER
        // --------------------------------------------------------

        let tracer =
            QRTLPhotonTracer(
                field: field
            )

        // --------------------------------------------------------
        // SOURCE GALAXY
        // --------------------------------------------------------

        let galaxyCenter =
            SIMD3<Float>(
                -extent,
                0.0,
                0.0
            )

        let galaxyRadius =
            0.25 *
            extent

        // --------------------------------------------------------
        // EXPLICIT SCENE → PHYSICAL SCALE
        // --------------------------------------------------------

        let sceneToPhysicalScale =
            Float(
                field.clusterRadiusMeters
            ) /
            extent

        // --------------------------------------------------------
        // TRACE SOURCE STARS
        // --------------------------------------------------------

        for i in 0..<numberOfStars {

            let angle =
                2.0 *
                Float.pi *
                Float(i) /
                Float(numberOfStars)

            let local =
                SIMD3<Float>(
                    0.0,
                    cos(angle),
                    sin(angle)
                )

            let source =
                galaxyCenter +
                galaxyRadius *
                local

            let direction =
                SIMD3<Float>(
                    1.0,
                    0.0,
                    0.0
                )

            let result =
                tracer.tracePhoton(
                    origin: source,
                    direction: direction,
                    parameters: lensingParameters,
                    sceneToPhysicalScale: sceneToPhysicalScale
                )

            // ----------------------------------------------------
            // RAW PHYSICAL / SCENE TRACE
            //
            // DO NOT MODIFY THESE POINTS.
            // ----------------------------------------------------

            if result.positions.count > 1 {

                let path =
                    result.positions.map { point in

                        SIMD3<Double>(
                            Double(point.x),
                            Double(point.y),
                            Double(point.z)
                        )
                    }

                photonPaths.append(
                    path
                )
            }

            // ----------------------------------------------------
            // PROJECTION HIT
            // ----------------------------------------------------

            if result.hitProjection,
               let projection =
                    result.projectionCoordinates {

                galaxyProjectionPositions.append(
                    SIMD3<Double>(
                        Double(projection.x),
                        0.0,
                        Double(projection.y)
                    )
                )
            }
        }

        print(
            "QRTL LENSING:",
            "photon paths =",
            photonPaths.count,
            "projection hits =",
            galaxyProjectionPositions.count
        )
    }

    // ============================================================
    // RAW TRAVELING PHOTON PARTICLES
    // ============================================================
    //
    // CRITICAL:
    //
    // The path is rendered exactly as returned by
    // QRTLPhotonTracer.
    //
    // NO surfaceHeight() is added.
    //
    // The gravity surface is a visualization of the potential.
    // It is not a physical coordinate transformation.
    //
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

            guard
                path.count > 1
            else {
                continue
            }

            let validPoints =
                path.filter {
                    $0.x.isFinite &&
                    $0.y.isFinite &&
                    $0.z.isFinite
                }

            guard
                validPoints.count > 1
            else {
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

            // ----------------------------------------------------
            // RAW INITIAL POSITION
            // ----------------------------------------------------

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

            // ----------------------------------------------------
            // RAW TRACE SEQUENCE
            // ----------------------------------------------------

            var moves:
                [SCNAction] = []

            moves.reserveCapacity(
                validPoints.count - 1
            )

            for index in
                1..<validPoints.count {

                let point =
                    validPoints[index]

                // ------------------------------------------------
                // RAW PHOTON POSITION
                // ------------------------------------------------

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

                // ------------------------------------------------
                // CURVATURE VISUALIZATION
                //
                // This changes only appearance.
                // It does NOT modify position.
                // ------------------------------------------------

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

            guard
                !moves.isEmpty
            else {
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
