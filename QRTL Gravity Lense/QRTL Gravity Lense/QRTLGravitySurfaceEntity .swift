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
        // GRAVITY SURFACE ONLY
        //
        // Do not trace photons here.
        // Controller: SourceGalaxy → QRTLPhotonTracer → paths,
        // then setPhotonPathsForDisplay(...).
        // --------------------------------------------------------

        let surface = makeSurfaceNode()

        surfaceNode = surface

        addChildNode(surface)

        // photonNode / galaxyNode remain nil until
        // setPhotonPathsForDisplay is called.
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

        return physicalCurvatureHeight(
            x: x,
            z: z
        )
    }

    // ============================================================
    // PHYSICAL CURVATURE HEIGHT (FIXED SCALE — NOT NORMALIZED)
    // ============================================================
    //
    // PREVIOUS BEHAVIOR (removed):
    //
    //     normalized = potential / maximumPotential   // self-relative
    //     visualPotential = pow(normalized, 0.45)      // compresses contrast
    //     height = -visualPotential * curvatureScale
    //
    // maximumPotential was always the CENTER sample itself (the
    // potential is highest at r = 0 by construction), so the center
    // vertex was pinned to exactly -curvatureScale on every rebuild
    // regardless of how strong the underlying field actually was —
    // increasing the physical well depth could never make the bowl
    // visibly deeper. The pow(x, 0.45) curve then pulled distant,
    // physically-weak points UP toward the same height as the
    // center, flattening the bowl into a shallow, wide dish instead
    // of a localized dip.
    //
    // FIXED APPROACH:
    //
    // Use the same fixed-scale linear mapping already proven correct
    // for the heatmap/bottom-plane surface in
    // LensingSceneController.addDeformedSpacetimeSurface — the
    // standard weak-field relationship
    //
    //     curvature ∝ -2Φ/c²
    //
    // multiplied by a constant visual amplification factor, with NO
    // division by any per-frame maximum. Absolute changes in Φ now
    // translate directly into absolute changes in displayed height,
    // and the falloff shape reflects the real density profile
    // instead of being renormalized away.
    // ============================================================

    private func physicalCurvatureHeight(
        x: Float,
        z: Float
    ) -> Float {

        // --------------------------------------------------------
        // SCENE → PHYSICAL
        //
        // Same canonical conversion QRTLPhotonTracer and
        // samplePotentialMagnitude use: a scene-unit distance is a
        // fraction of `extent`, which is a fraction of
        // field.clusterRadiusMeters.
        // --------------------------------------------------------

        let metersPerSceneUnit =
            Float(field.clusterRadiusMeters) /
            extent

        let physicalPosition =
            SIMD3<Float>(
                x * metersPerSceneUnit,
                0.0,
                z * metersPerSceneUnit
            )

        let potential =
            field.gravitationalPotential(
                at: physicalPosition
            )

        guard potential.isFinite else {
            return 0.0
        }

        let potentialValue =
            Float(potential)

        guard potentialValue.isFinite else {
            return 0.0
        }

        // --------------------------------------------------------
        // WEAK-FIELD CURVATURE, FIXED VISUAL AMPLIFICATION
        //
        // Matches LensingSceneController.addDeformedSpacetimeSurface
        // exactly, so the bowl mesh and the heatmap plane agree on
        // what "deep" means.
        // --------------------------------------------------------

        let speedOfLightSquared: Float =
            299_792_458.0 * 299_792_458.0

        let visualizationHeightScale: Float =
            1.0e6

        let physicalCurvatureScale =
            -2.0 *
            visualizationHeightScale /
            speedOfLightSquared

        let height =
            potentialValue *
            physicalCurvatureScale *
            curvatureScale

        guard height.isFinite else {
            return 0.0
        }

        return height
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

        // --------------------------------------------------------
        // CENTER VERTEX
        //
        // Height comes directly from the fixed-scale physical
        // mapping (physicalCurvatureHeight) — NOT from
        // centerPotential / maximumPotential. maximumPotential is
        // still computed above because curvatureIntensity() (used
        // for surface coloring) legitimately wants a relative
        // 0...1 scale; but the center of a radially-decreasing
        // potential is ALWAYS the maximum sample, so dividing the
        // center's own height by that same maximum would pin it to
        // 1.0 every time regardless of the field's real strength.
        // --------------------------------------------------------

        let centerY =
            physicalCurvatureHeight(
                x: 0.0,
                z: 0.0
            )

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

                // ------------------------------------------------
                // RING VERTEX HEIGHT
                //
                // Same fixed-scale physical mapping as the center
                // vertex — no per-frame normalization, no
                // contrast-flattening pow() curve. rimFade is kept:
                // it's an intentional edge taper, not part of the
                // normalization bug.
                // ------------------------------------------------

                let y =
                    physicalCurvatureHeight(
                        x: x,
                        z: z
                    ) *
                    rimFade

                positions.append(
                    SCNVector3(
                        x,
                        y,
                        z
                    )
                )
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

    /// Visualization only. Paths must already come from QRTLPhotonTracer
    /// using SourceGalaxy origins. Do not generate a second galaxy here.
    func setPhotonPathsForDisplay(
        _ paths: [[SIMD3<Float>]],
        projectionHits: [SIMD3<Float>] = []
    ) {
        photonPaths = paths.map { path in
            path.map {
                SIMD3<Double>(Double($0.x), Double($0.y), Double($0.z))
            }
        }

        galaxyProjectionPositions = projectionHits.map {
            SIMD3<Double>(Double($0.x), Double($0.y), Double($0.z))
        }

        // Rebuild only photon + projection graphics (not the gravity bowl)
        photonNode?.removeFromParentNode()
        galaxyNode?.removeFromParentNode()

        let photonGraphicsNode = makeTravelingPhotonParticles(
            paths: photonPaths,
            color: .white   // or .cyan if you prefer
        )
        photonNode = photonGraphicsNode
        addChildNode(photonGraphicsNode)

        let galaxy = makeProjectionNode(
            positions: galaxyProjectionPositions,
            color: .white
        )
        galaxyNode = galaxy
        addChildNode(galaxy)
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
