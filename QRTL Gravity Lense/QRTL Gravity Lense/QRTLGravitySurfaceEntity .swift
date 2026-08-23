/*
 For a globular cluster bending photon paths, the most useful Einstein and general relativity gravity surfaces begin with the cluster’s three dimensional mass and potential structure. The gravitational potential surfaces are level sets where the potential remains constant. In the weak field limit, photons bend wherever the potential changes spatially, so the gradient of the potential determines the local deflection. For a nearly spherical globular cluster, these potential surfaces are approximately concentric spherical shells, with the deeper potential near the denser central core producing stronger bending. In an effective refractive index ray tracer, the refractive index rises toward the deeper gravitational well, so constant index surfaces are operationally the same kind of gravity surface: rays continuously bend toward the spatial gradient of the index.

 Isodensity surfaces are the companion geometry. They are shells on which the stellar and dark or modeled mass density is constant. In a Gaussian, King, Plummer, or similar cluster-density model, these surfaces show where the gravitating material is concentrated and where the potential gradient is built up. A useful related boundary is the escape or binding surface, which separates regions in which a test particle has enough energy to escape the cluster from those in which it remains gravitationally bound. For photon lensing, however, no sharp physical boundary is required. The photon accumulates deflection smoothly while traversing the changing potential associated with all of the density shells.

 The lensing-specific surfaces are defined by the mapping between the source, lens, and observer planes. The Einstein ring is the circular image that occurs when a source, a spherical lens, and an observer are almost perfectly aligned. Its angular radius depends on the lens mass and the source, lens, and observer distances. In a symmetric globular cluster model, the corresponding critical curve is approximately a circle on the lens or image plane. A critical curve marks locations where the idealized lens magnification becomes extremely large. Mapping that critical curve backward onto the source plane produces a caustic. The caustic is the important structure for deciding whether a background galaxy appears once, twice, or in multiple distorted images. A source crossing a caustic changes the number and arrangement of observable images.

 The time delay surface, also called the Fermat potential surface, provides another way to understand the paths. It combines geometric path length with gravitational delay. The observed photon paths correspond to stationary points on that surface. In practical lensing terms, different stationary points represent different lensed images, and the differences in their Fermat potential correspond to differences in arrival time. A smooth refractive gradient can bend a ray, but multiple distinct images require the lens mapping to become multi-valued, which is governed by the critical-curve and caustic structure rather than by bending alone.

 Along an individual photon trajectory, several three dimensional geometric constructs are useful. The deflection plane is the plane containing the incoming ray direction and the cluster center; for an axisymmetric lens, the instantaneous bending occurs within that plane. The impact-parameter cylinder groups rays by their perpendicular distance from the central line of sight. Rays with the same impact parameter experience comparable integrated deflection in a spherical mass distribution. The closest-approach sphere identifies the radius at which the ray passes nearest the cluster center, where the potential gradient and local bending rate are usually greatest. A globular cluster remains overwhelmingly in the weak-field regime, unlike the strong-field environment surrounding a black hole photon sphere, so its rays are gently deflected and are not expected to orbit or become trapped.

 A photon’s journey can be viewed as beginning at the source plane with a fixed incoming direction and impact parameter. It enters progressively denser isodensity surfaces and deeper equipotential shells, where the potential and effective refractive index change. The ray bends continuously as it approaches periapsis, reaches its maximum local deflection rate near its minimum radius, and then continues accumulating a net angular deflection while exiting the same family of shells. It ultimately reaches the observer or projection plane at a position corresponding to a lensed image. Whether there is one image, two images, or several images depends on the source’s position relative to the caustic structure.

 For a practical globular-cluster visualization, the cleanest representation is a spherical weak-field lens. Draw a cluster center, then render several nested isodensity spheres or equipotential spheres as the visible gravity surfaces. Trace photon polylines through those shells, with the curvature increasing toward the central region. Add an Einstein ring as a circular feature on a front-facing image or projection plane, and use hit points or a brightness accumulation map to display the resulting lensed images. For a concentrated mass distribution and a ray passing sufficiently far from the core, the total deflection is approximately four times the gravitational constant times the enclosed lens mass divided by the speed of light squared times the impact parameter.

 The essential hierarchy is therefore the three dimensional density, potential, and effective refractive-index surfaces that continuously bend rays; the closest-approach and impact-parameter geometry that determines the strength of that bending; and the two dimensional critical-curve and caustic structure that determines image multiplicity.
 */

//
//  QRTLGravitySurfaceEntity.swift
//  QRTL Gravity Lense
//
//  Consumer / Renderer of the authoritative QRTL physics.
//
//  QRTLField          -> authoritative gravity physics
//  QRTLPhotonTracer   -> authoritative photon propagation
//  QRTLGravitySurfaceEntity -> visualization only
//

import Foundation
import SceneKit
import simd
import UIKit


// ============================================================
// QRTL GRAVITY SURFACE ENTITY
// ============================================================
//
// This class is a CONSUMER of the QRTL physics.
//
// Physics:
//     QRTLField
//     QRTLPhotonTracer
//
// Rendering:
//     QRTLGravitySurfaceEntity
//
// COORDINATE SYSTEM
//
// Physical QRTL coordinates:
//
//     X = photon propagation direction
//     Y = transverse direction
//     Z = transverse direction
//
// Photons travel:
//
//     +X
//
// Gravity surface:
//
//     physical X = 0
//
// Mapping:
//
//     physical Y -> visual X
//     physical Z -> visual Z
//     gravitational potential -> visual negative Y
//
// The QRTL field and radial lookup remain completely unchanged.
//
// pow(..., 0.45) and curvatureScale are visualization only.
// ============================================================

final class QRTLGravitySurfaceEntity: SCNNode {

    // ============================================================
    // AUTHORITATIVE QRTL PHYSICS
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
    // PHOTON RESULTS
    // ============================================================
    //
    // A single source galaxy. Every photon path stored here is the
    // raw, unmodified output of QRTLPhotonTracer.tracePhoton — no
    // spline fitting or smoothing is applied anywhere downstream.
    // ============================================================

    private(set) var photonPaths: [[SIMD3<Double>]] = []

    private(set) var galaxyProjectionPositions:
        [SIMD3<Double>] = []

    private let lensingParameters = LensingParameters()

    // ============================================================
    // VISUALIZATION STATE
    // ============================================================

    // Maximum absolute QRTL potential encountered while building
    // the current surface.
    //
    // This is used ONLY for visualization normalization.
    //
    // It never modifies QRTL physics.
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

        // Reset visualization state.
        maximumPotential = 0.0

        // ========================================================
        // GRAVITY SURFACE
        // ========================================================

        let surface = makeSurfaceNode()

        surfaceNode = surface

        addChildNode(
            surface
        )

        // ========================================================
        // PHOTON PROJECTION
        // ========================================================

        computeGalaxyProjections(
            lensingParameters: lensingParameters
        )

        // ========================================================
        // PHOTON PARTICLES
        //
        // Each particle is the raw path returned by
        // QRTLPhotonTracer.tracePhoton — a real photon traveling
        // from the source galaxy, through the deformed spacetime
        // surface, onto the projection plane. No spline fitting,
        // no smoothing: the particle moves through exactly the
        // positions the tracer calculated.
        // ========================================================

        let photonGraphicsNode = makeTravelingPhotonParticles(
            paths: photonPaths,
            color: .cyan
        )

        photonNode = photonGraphicsNode

        addChildNode(
            photonGraphicsNode
        )

        // ========================================================
        // PROJECTED GALAXY
        // ========================================================

        let galaxy = makeProjectionNode(
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
    //
    // This is the ONLY surface potential sampling function.
    //
    // Visual coordinates:
    //
    //     x -> physical Y
    //     z -> physical Z
    //
    // Physical cross-section:
    //
    //     physical X = 0
    //
    // Therefore:
    //
    //     r = sqrt(
    //         X² + Y² + Z²
    //     )
    //
    // with X = 0.
    //
    // The actual potential comes exclusively from:
    //
    //     field.interpolateRadialPotential(radius:)
    //
    // No gravity physics is performed here.
    // ============================================================

    func samplePotentialMagnitude(
        x: Float,
        z: Float
    ) -> Float {

        // ============================================================
        // DISPLAY SPACE
        //
        // x and z are SceneKit/display coordinates.
        // They are NOT physical meters.
        // ============================================================

        let displayRadius =
            sqrt(
                x * x +
                z * z
            )

        // ============================================================
        // MAP DISPLAY RADIUS → PHYSICAL RADIUS
        //
        // The displayed surface has radius `extent`.
        //
        // displayRadius = 0
        //     → physical radius = 0
        //
        // displayRadius = extent
        //     → physical radius = clusterRadiusMeters
        // ============================================================

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
        // ============================================================
        // AUTHORITATIVE RADIAL QRTL POTENTIAL
        // ============================================================

        let potential =
            field.interpolateRadialPotential(
                radius: physicalRadius
            )

        // ============================================================
        // VISUAL MAGNITUDE
        // ============================================================

        return Float(abs(
            potential
        ))
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
    //
    // The surface is generated directly from the radial QRTL
    // potential lookup.
    //
    // Physical:
    //
    //     X = 0
    //     Y = transverse
    //     Z = transverse
    //
    // Visual:
    //
    //     X = physical Y
    //     Z = physical Z
    //     Y = negative normalized potential
    //
    // gridSize remains 64 by default.
    //
    // No independent gravity field is constructed here.
    // ============================================================

    private func makeSurfaceGeometry() -> SCNGeometry {

        // ============================================================
        // RESET VISUALIZATION MAXIMUM
        // ============================================================

        maximumPotential = 0.0

        // ============================================================
        // SURFACE RESOLUTION
        //
        // gridSize remains 64.
        //
        // radialSegments controls the number of concentric rings.
        // angularSegments controls the circumference resolution.
        // ============================================================

        let radialSegments = max(
            gridSize / 2,
            16
        )

        let angularSegments = max(
            gridSize,
            32
        )

        // ============================================================
        // VISUAL SURFACE EXTENT
        // ============================================================

        let bowlRadius = extent

        // ============================================================
        // VISUAL RIM FADE
        //
        // This is purely cosmetic.
        // ============================================================

        let rimFadeFraction: Float = 0.18

        // ============================================================
        // STORAGE
        // ============================================================

        var positions: [SCNVector3] = []

        var indices: [Int32] = []

        var potentialMagnitudes: [Float] = []

        positions.reserveCapacity(
            1 +
            radialSegments * angularSegments
        )

        potentialMagnitudes.reserveCapacity(
            1 +
            radialSegments * angularSegments
        )

        indices.reserveCapacity(
            angularSegments * 3 +
            max(radialSegments - 1, 0) *
            angularSegments *
            6
        )

        // ============================================================
        // CENTER POTENTIAL
        //
        // physical:
        //
        // X = 0
        // Y = 0
        // Z = 0
        //
        // Therefore radius = 0.
        // ============================================================

        let centerPotential =
            samplePotentialMagnitude(
                x: 0.0,
                z: 0.0
            )

        potentialMagnitudes.append(
            centerPotential
        )

        // ============================================================
        // RING POTENTIALS
        //
        // Every sample remains on:
        //
        // physical X = 0
        //
        // visual X → physical Y
        // visual Z → physical Z
        // ============================================================

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

                // ====================================================
                // VISUAL SURFACE COORDINATES
                // ====================================================

                let x =
                    radius *
                    cos(angle)

                let z =
                    radius *
                    sin(angle)

                // ====================================================
                // SAMPLE AUTHORITATIVE QRTL POTENTIAL
                // ====================================================

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

        // ============================================================
        // VERIFY LOOKUP RESULT
        // ============================================================

        print(
            "QRTL GRAVITY SURFACE:",
            "maximumPotential =",
            maximumPotential,
            "samples =",
            potentialMagnitudes.count
        )

        // ============================================================
        // SAFE NORMALIZATION
        //
        // Visualization only.
        //
        // This does NOT alter QRTL physics.
        // ============================================================

        let normalization =
            max(
                maximumPotential,
                1.0e-30
            )

        // ============================================================
        // CENTER VERTEX
        // ============================================================

        let centerNormalized =
            min(
                max(
                    centerPotential /
                    normalization,
                    0.0
                ),
                1.0
            )

        // ============================================================
        // NONLINEAR VISUALIZATION ENHANCEMENT
        //
        // This is NOT part of QRTL gravity.
        // ============================================================

        let centerVisualPotential =
            pow(
                centerNormalized,
                0.45
            )

        // ============================================================
        // GRAVITY → NEGATIVE VISUAL Y
        // ============================================================

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

        // ============================================================
        // RING VERTICES
        // ============================================================

        var potentialIndex = 1

        for radialIndex in 1...radialSegments {

            let normalizedRadius =
                Float(radialIndex) /
                Float(radialSegments)

            let radius =
                normalizedRadius *
                bowlRadius

            // ========================================================
            // COSMETIC RIM FADE
            // ========================================================

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

            // ========================================================
            // ANGULAR VERTICES
            // ========================================================

            for angularIndex in 0..<angularSegments {

                let angle =
                    2.0 *
                    Float.pi *
                    Float(angularIndex) /
                    Float(angularSegments)

                // ====================================================
                // VISUAL X/Z
                // ====================================================

                let x =
                    radius *
                    cos(angle)

                let z =
                    radius *
                    sin(angle)

                // ====================================================
                // NORMALIZED QRTL POTENTIAL
                // ====================================================

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

                // ====================================================
                // VISUAL ENHANCEMENT ONLY
                // ====================================================

                let visualPotential =
                    pow(
                        normalizedPotential,
                        0.45
                    )

                // ====================================================
                // POTENTIAL → NEGATIVE VISUAL Y
                //
                // This is the actual bowl deformation.
                // ====================================================

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

        // ============================================================
        // CENTER FAN
        // ============================================================

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

        // ============================================================
        // CONNECT RINGS
        // ============================================================

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

        // ============================================================
        // NORMALS
        // ============================================================

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

        // ============================================================
        // SCENEKIT GEOMETRY
        // ============================================================

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

        return geometry
    }
    // ============================================================
    // PHOTON PIPELINE
    // ============================================================


    func computeGalaxyProjections(
        lensingParameters: LensingParameters
    ) {

        // ============================================================
        // CLEAR PREVIOUS RESULTS
        // ============================================================

        photonPaths.removeAll(
            keepingCapacity: true
        )

        galaxyProjectionPositions.removeAll(
            keepingCapacity: true
        )

        // ============================================================
        // AUTHORITATIVE QRTL PHOTON TRACER
        // ============================================================

        let tracer =
            QRTLPhotonTracer(
                field: field
            )

        // ============================================================
        // SOURCE GALAXY CONFIGURATION
        //
        // Physical coordinate system:
        //
        //     X = photon propagation direction
        //     Y = transverse coordinate
        //     Z = transverse coordinate
        //
        // The source galaxy is a disk in the physical Y-Z plane.
        // ============================================================

        let galaxyCenter =
            SIMD3<Float>(
                -extent,
                0.0,
                0.0
            )

        let galaxyRadius =
            0.25 * extent

        // ============================================================
        // TRACE EVERY SOURCE STAR
        // ============================================================

        for i in 0..<numberOfStars {

            let angle =
                2.0 *
                Float.pi *
                Float(i) /
                Float(numberOfStars)

            // ========================================================
            // SOURCE POINT
            //
            // Disk lies in physical Y-Z plane.
            //
            // X = 0 offset
            // Y = cos(angle)
            // Z = sin(angle)
            // ========================================================

            let local =
                SIMD3<Float>(
                    0.0,
                    cos(angle),
                    sin(angle)
                )

            let source =
                galaxyCenter +
                galaxyRadius * local

            // ========================================================
            // PHOTON TRAVELS +X, THROUGH THE SPACETIME SURFACE,
            // ONTO THE PROJECTION PLANE.
            // ========================================================

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
                    parameters: lensingParameters
                )

            // ========================================================
            // STORE THE RAW TRACED PATH
            // ========================================================

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

            // ========================================================
            // STORE GALAXY PROJECTION
            //
            // Projection plane:
            //
            //     visual X = projection.x
            //     visual Y = 0
            //     visual Z = projection.y
            // ========================================================

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
    }
 

    // ============================================================
    // TRAVELING PHOTON PARTICLES
    //
    // Each traced path becomes ONE particle that physically moves
    // through the exact sequence of positions QRTLPhotonTracer
    // calculated — from the source galaxy, through the deformed
    // spacetime surface, onto the projection plane. No spline
    // fitting or smoothing is applied; the particle's motion IS
    // the raw tracePhoton output.
    // ============================================================

    private func makeTravelingPhotonParticles(
        paths: [[SIMD3<Double>]],
        color: UIColor
    ) -> SCNNode {

        let parent = SCNNode()

        let particleRadius =
            max(
                0.008,
                Double(extent) /
                Double(gridSize) *
                0.35
            )

        // Total travel time is shared across every particle so
        // faster (shorter) paths and slower (longer, more bent)
        // paths animate at a comparable, readable pace.
        let secondsPerPoint = 0.012

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
                    radius: CGFloat(particleRadius)
                )

            let material =
                SCNMaterial()

            material.diffuse.contents = color
            material.emission.contents = color
            material.isDoubleSided = true
            material.lightingModel = .constant

            sphere.materials = [
                material
            ]

            let particleNode =
                SCNNode(
                    geometry: sphere
                )

            particleNode.position =
                SCNVector3(
                    Float(validPoints[0].x),
                    Float(validPoints[0].y),
                    Float(validPoints[0].z)
                )

            // ----------------------------------------------------
            // BUILD THE TRAVEL SEQUENCE
            //
            // One move action per consecutive pair of traced
            // positions — the particle passes through every
            // point tracePhoton produced, in order.
            // ----------------------------------------------------

            var moves: [SCNAction] = []

            for index in 1..<validPoints.count {

                let point = validPoints[index]

                let moveAction =
                    SCNAction.move(
                        to: SCNVector3(
                            Float(point.x),
                            Float(point.y),
                            Float(point.z)
                        ),
                        duration: secondsPerPoint
                    )

                moves.append(
                    moveAction
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

        let parent = SCNNode()

        let radius =
            max(
                0.012,
                Double(extent) /
                Double(gridSize) *
                0.55
            )

        let projectionOffset: Float = 0.003

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
                    radius: CGFloat(radius)
                )

            let material =
                SCNMaterial()

            material.diffuse.contents = color
            material.emission.contents = color
            material.specular.contents =
                UIColor.white

            material.isDoubleSided = true
            material.lightingModel = .constant

            sphere.materials = [
                material
            ]

            let node =
                SCNNode(
                    geometry: sphere
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

