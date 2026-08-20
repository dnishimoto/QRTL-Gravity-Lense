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

import Foundation
import SceneKit
import simd
import UIKit

// ============================================================
// QRTL GRAVITY SURFACE ENTITY
// ============================================================
//
// This object IS an SCNNode.
//
// Coordinate system:
//
//                 Y
//                 ↑
//                 |
//                 |       spacetime surface
//                 |      /---------\
//                 |    /             \
//                 |  /                 \
//                 | /        ↓          \
//                 |/      gravity        \
//                 +------------------------→ X
//                /
//               Z
//
// The QRTL gravity well is a NEGATIVE Y displacement.
// The center of the globular cluster is the bottom of the bowl.
//
// ============================================================

final class QRTLGravitySurfaceEntity: SCNNode {

    // ============================================================
    // CONFIGURATION
    // ============================================================

    let field: QRTLField
    let gridSize: Int
    let extent: Float
    let numberOfStars: Int
    let photonSteps: Int
    let curvatureScale: Float

    // ============================================================
    // SCENE CONTENT
    // ============================================================

    private(set) var surfaceNode: SCNNode?
    private(set) var photonANode: SCNNode?
    private(set) var photonBNode: SCNNode?
    private(set) var galaxyANode: SCNNode?
    private(set) var galaxyBNode: SCNNode?

    // ============================================================
    // PHOTON RESULTS
    // ============================================================

    private(set) var photonPathsA: [[SIMD3<Double>]] = []
    private(set) var photonPathsB: [[SIMD3<Double>]] = []
    private(set) var galaxyAProjectionPositions: [SIMD3<Double>] = []
    private(set) var galaxyBProjectionPositions: [SIMD3<Double>] = []

    // ============================================================
    // INITIALIZATION
    // ============================================================

    init(
        field: QRTLField,
        gridSize: Int = 64,
        extent: Float = 2.0,
        numberOfStars: Int = 220,
        photonSteps: Int = 500,
        curvatureScale: Float = 1.0
    ) {
        self.field = field
        self.gridSize = max(gridSize, 4)
        self.extent = max(extent, 0.001)
        self.numberOfStars = max(numberOfStars, 1)
        self.photonSteps = max(photonSteps, 10)
        self.curvatureScale = max(curvatureScale, 0.0001)

        super.init()
        buildScene()
    }

    required init?(coder: NSCoder) {
        fatalError("QRTLGravitySurfaceEntity does not support NSCoder initialization.")
    }

    // ============================================================
    // BUILD COMPLETE ENTITY
    // ============================================================

    func buildScene() {
        childNodes.forEach { $0.removeFromParentNode() }

        surfaceNode = nil
        photonANode = nil
        photonBNode = nil
        galaxyANode = nil
        galaxyBNode = nil

        photonPathsA.removeAll(keepingCapacity: true)
        photonPathsB.removeAll(keepingCapacity: true)
        galaxyAProjectionPositions.removeAll(keepingCapacity: true)
        galaxyBProjectionPositions.removeAll(keepingCapacity: true)

        // Build the GR spacetime surface
        let surface = makeSurfaceNode()
        surfaceNode = surface
        addChildNode(surface)

        // Trace photons and build projections
        computeGalaxyProjections()

        let photonAGeometry = makePhotonGeometry(paths: photonPathsA, color: .cyan)
        let photonAGraphicsNode = SCNNode(geometry: photonAGeometry)
        photonANode = photonAGraphicsNode
        addChildNode(photonAGraphicsNode)

        let photonBGeometry = makePhotonGeometry(paths: photonPathsB, color: .magenta)
        let photonBGraphicsNode = SCNNode(geometry: photonBGeometry)
        photonBNode = photonBGraphicsNode
        addChildNode(photonBGraphicsNode)

        let galaxyA = makeProjectionNode(positions: galaxyAProjectionPositions, color: .cyan)
        galaxyANode = galaxyA
        addChildNode(galaxyA)

        let galaxyB = makeProjectionNode(positions: galaxyBProjectionPositions, color: .magenta)
        galaxyBNode = galaxyB
        addChildNode(galaxyB)
    }
    // ============================================================
    // PROJECTED GALAXY
    // ============================================================
    //
    // Creates a group of glowing spheres at the ray hit locations
    // on the positive-X projection plane.
    //

    private func makeProjectionNode(
        positions: [SIMD3<Double>],
        color: UIColor
    ) -> SCNNode {
        let parent = SCNNode()

        let radius = max(
            0.012,
            Double(extent) /
            Double(gridSize) *
            0.55
        )

        let projectionOffset: Float = 0.003

        for position in positions {
            guard position.x.isFinite,
                  position.y.isFinite,
                  position.z.isFinite
            else {
                continue
            }

            let sphere = SCNSphere(
                radius: CGFloat(radius)
            )

            let material = SCNMaterial()
            material.diffuse.contents = color
            material.emission.contents = color
            material.specular.contents = UIColor.white
            material.isDoubleSided = true
            material.lightingModel = .constant

            sphere.materials = [
                material
            ]

            let node = SCNNode(
                geometry: sphere
            )

            node.position = SCNVector3(
                Float(position.x) + projectionOffset,
                Float(position.y),
                Float(position.z)
            )

            parent.addChildNode(node)
        }

        return parent
    }
    // ============================================================
    // PHOTON PATH GEOMETRY
    // ============================================================

    private func makePhotonGeometry(
        paths: [[SIMD3<Double>]],
        color: UIColor
    ) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []

        for path in paths {
            guard path.count > 1 else {
                continue
            }

            let startIndex = Int32(vertices.count)

            for point in path {
                guard point.x.isFinite,
                      point.y.isFinite,
                      point.z.isFinite
                else {
                    continue
                }

                vertices.append(
                    SCNVector3(
                        Float(point.x),
                        Float(point.y),
                        Float(point.z)
                    )
                )
            }

            let validCount =
                vertices.count -
                Int(startIndex)

            guard validCount > 1 else {
                continue
            }

            for i in 0..<(validCount - 1) {
                indices.append(
                    startIndex +
                    Int32(i)
                )

                indices.append(
                    startIndex +
                    Int32(i + 1)
                )
            }
        }

        guard vertices.count > 1,
              indices.count >= 2
        else {
            return SCNGeometry()
        }

        let source = SCNGeometrySource(
            vertices: vertices
        )

        let element = SCNGeometryElement(
            indices: indices,
            primitiveType: .line
        )

        let geometry = SCNGeometry(
            sources: [
                source
            ],
            elements: [
                element
            ]
        )

        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color
        material.isDoubleSided = true
        material.lightingModel = .constant

        geometry.materials = [
            material
        ]

        return geometry
    }
    // ============================================================
    // PROJECTION POINT
    // ============================================================
    //
    // Finds where a traced photon path crosses the projection plane
    // at x = extent. The intersection is linearly interpolated
    // between two adjacent photon path samples.
    //

    private func projectionPoint(
        from path: [SIMD3<Double>]
    ) -> SIMD3<Double>? {
        guard path.count >= 2 else {
            return nil
        }

        let planeX = Double(extent)

        for i in 1..<path.count {
            let previous = path[i - 1]
            let current = path[i]

            let crossesProjectionPlane =
                previous.x <= planeX &&
                current.x >= planeX

            guard crossesProjectionPlane else {
                continue
            }

            let dx = current.x - previous.x

            guard abs(dx) > 1.0e-12 else {
                return current
            }

            let t = (planeX - previous.x) / dx

            let clampedT = min(
                max(t, 0.0),
                1.0
            )

            return previous +
                (current - previous) *
                clampedT
        }

        if let finalPoint = path.last,
           abs(finalPoint.x - planeX) < 1.0e-5
        {
            return finalPoint
        }

        return nil
    }
    // ============================================================
    // SAFE FLOAT
    // ============================================================

    private func sanitize(_ value: Float) -> Float {
        guard value.isFinite else {
            return 0.0
        }

        return value
    }
    // ============================================================
    // GALAXY PHOTON PIPELINE
    // ============================================================

    func computeGalaxyProjections() { // -------------------------------------------------------- // CLEAR PREVIOUS RESULTS // -------------------------------------------------------- photonPathsA.removeAll( keepingCapacity: true ) photonPathsB.removeAll( keepingCapacity: true ) galaxyAProjectionPositions.removeAll( keepingCapacity: true ) galaxyBProjectionPositions.removeAll( keepingCapacity: true ) // -------------------------------------------------------- // CANONICAL PHOTON TRACER // -------------------------------------------------------- let tracer = QRTLPhotonTracer( field: field ) // -------------------------------------------------------- // GALAXY A SOURCE CENTER // -------------------------------------------------------- let galaxyACenter = SIMD3<Float>( -extent, 0.0, -0.70 * extent ) // -------------------------------------------------------- // GALAXY B SOURCE CENTER // -------------------------------------------------------- let galaxyBCenter = SIMD3<Float>( -extent, 0.0, 0.70 * extent ) // -------------------------------------------------------- // SOURCE GALAXY RADIUS // -------------------------------------------------------- let galaxyRadius = 0.25 * extent // ======================================================== // TRACE EVERY SOURCE STAR // ======================================================== for i in 0..<numberOfStars { let angle = 2.0 * Double.pi * Double(i) / Double(numberOfStars) // ==================================================== // GALAXY A // ==================================================== let localA = SIMD3<Float>( Float(cos(angle)), Float(sin(angle)), 0.0 ) let sourceA = galaxyACenter + galaxyRadius * localA let startA = SIMD3<Double>( Double(sourceA.x), Double(sourceA.y), Double(sourceA.z) ) let directionA = SIMD3<Double>( 1.0, 0.0, 0.0 ) // ---------------------------------------------------- // CANONICAL TRACE // // ALL propagation parameters come from `parameters`. // ---------------------------------------------------- let resultA = tracer.tracePhoton( start: startA, direction: directionA, parameters: parameters ) // ---------------------------------------------------- // STORE PHOTON A PATH // ---------------------------------------------------- let pathA = resultA.positions if pathA.count > 1 { photonPathsA.append( pathA ) } // ---------------------------------------------------- // STORE AUTHORITATIVE PROJECTION // // Prefer PhotonTraceResult.projectionPosition. // Do not recalculate the projection here. // ---------------------------------------------------- if resultA.hitProjection, let projectionA = resultA.projectionPosition { galaxyAProjectionPositions.append( projectionA ) } // ==================================================== // GALAXY B // ==================================================== let localB = SIMD3<Float>( Float(sin(angle)), Float(cos(angle)), 0.0 ) let sourceB = galaxyBCenter + galaxyRadius * localB let startB = SIMD3<Double>( Double(sourceB.x), Double(sourceB.y), Double(sourceB.z) ) let directionB = SIMD3<Double>( 1.0, 0.0, 0.0 ) // ---------------------------------------------------- // CANONICAL TRACE // ---------------------------------------------------- let resultB = tracer.tracePhoton( start: startB, direction: directionB, parameters: parameters ) // ---------------------------------------------------- // STORE PHOTON B PATH // ---------------------------------------------------- let pathB = resultB.positions if pathB.count > 1 { photonPathsB.append( pathB ) } // ---------------------------------------------------- // STORE AUTHORITATIVE PROJECTION // ---------------------------------------------------- if resultB.hitProjection, let projectionB = resultB.projectionPosition { galaxyBProjectionPositions.append( projectionB ) } } }
    }
    // ============================================================
    // SURFACE NODE
    // ============================================================

    private func makeSurfaceNode() -> SCNNode {
        let node = SCNNode()
        node.geometry = makeSurfaceGeometry()

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
    // CURVILINEAR GRAVITY SURFACE  (GR-style embedding)
    // ============================================================
    //
    // Height is driven by a potential-like quantity derived from
    // the mass density of the globular cluster(s):
    //
    //     y = –Φ · curvatureScale
    //
    // This produces the classic smooth GR spacetime bowl / funnel.
    // ============================================================

    // ============================================================
    // CLASSIC RUBBER-SHEET + BOWLING BALL
    // ============================================================
    //
    // Flat sheet with a deep circular indentation in the center.
    // This is the exact visual you described.
    // ============================================================

    private func makeSurfaceGeometry() -> SCNGeometry {
        let radialSegments = max(gridSize / 2, 16)
        let angularSegments = max(gridSize, 32)

        let bowlRadius = extent
        let rimFadeFraction: Float = 0.18

        var positions: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []

        positions.reserveCapacity(
            1 + radialSegments * angularSegments
        )

        normals.reserveCapacity(
            1 + radialSegments * angularSegments
        )

        indices.reserveCapacity(
            angularSegments * 3 +
            max(radialSegments - 1, 0) * angularSegments * 6
        )

        // ------------------------------------------------------------
        // SAMPLE POTENTIAL MAGNITUDES ON THE CIRCULAR BOWL DOMAIN
        // ------------------------------------------------------------

        var potentialMagnitudes: [Float] = []
        potentialMagnitudes.reserveCapacity(
            1 + radialSegments * angularSegments
        )

        var maximumMagnitude: Float = 0.0

        func samplePotentialMagnitude(
            x: Float,
            z: Float
        ) -> Float {

            let position =
                SIMD3<Float>(
                    x,
                    0.0,
                    z
                )

            let potential =
                field.gravitationalPotential(
                    at: position
                )

            let safePotential =
                sanitize(
                    potential
                )

            let magnitude =
                abs(
                    safePotential
                )

            maximumMagnitude =
                max(
                    maximumMagnitude,
                    magnitude
                )

            return magnitude
        }
        // Center vertex.
        let centerMagnitude = samplePotentialMagnitude(
            x: 0.0,
            z: 0.0
        )

        potentialMagnitudes.append(centerMagnitude)

        // Concentric circular rings.
        for radialIndex in 1...radialSegments {
            let normalizedRadius =
                Float(radialIndex) /
                Float(radialSegments)

            let radius = normalizedRadius * bowlRadius

            for angularIndex in 0..<angularSegments {
                let angle =
                    2.0 * Float.pi *
                    Float(angularIndex) /
                    Float(angularSegments)

                let x = radius * cos(angle)
                let z = radius * sin(angle)

                let magnitude = samplePotentialMagnitude(
                    x: x,
                    z: z
                )

                potentialMagnitudes.append(magnitude)
            }
        }

        let normalization = max(
            maximumMagnitude,
            1.0e-30
        )

        // ------------------------------------------------------------
        // BUILD THE CENTER VERTEX
        // ------------------------------------------------------------

        let centerDepth =
            -min(
                max(
                    potentialMagnitudes[0] / normalization,
                    0.0
                ),
                1.0
            ) * curvatureScale

        positions.append(
            SCNVector3(
                0.0,
                centerDepth,
                0.0
            )
        )

        normals.append(
            SCNVector3(
                0.0,
                1.0,
                0.0
            )
        )

        // ------------------------------------------------------------
        // BUILD THE CIRCULAR RINGS
        // ------------------------------------------------------------

        var potentialIndex = 1

        for radialIndex in 1...radialSegments {
            let normalizedRadius =
                Float(radialIndex) /
                Float(radialSegments)

            let radius = normalizedRadius * bowlRadius

            // Smoothly forces the outer rim toward y = 0.
            let rimStart = max(
                0.0,
                1.0 - rimFadeFraction
            )

            let rimFade: Float

            if normalizedRadius <= rimStart {
                rimFade = 1.0
            } else {
                let t =
                    (normalizedRadius - rimStart) /
                    max(rimFadeFraction, 1.0e-6)

                let clampedT = min(max(t, 0.0), 1.0)

                // Smoothstep transition from bowl depth to flat rim.
                rimFade =
                    1.0 -
                    clampedT * clampedT *
                    (3.0 - 2.0 * clampedT)
            }

            for angularIndex in 0..<angularSegments {
                let angle =
                    2.0 * Float.pi *
                    Float(angularIndex) /
                    Float(angularSegments)

                let x = radius * cos(angle)
                let z = radius * sin(angle)

                let normalizedPotential =
                    min(
                        max(
                            potentialMagnitudes[potentialIndex] /
                            normalization,
                            0.0
                        ),
                        1.0
                    )

                let y =
                    -normalizedPotential *
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

        // ------------------------------------------------------------
        // CREATE CENTER TRIANGLE FAN
        // ------------------------------------------------------------

        for angularIndex in 0..<angularSegments {
            let next =
                (angularIndex + 1) %
                angularSegments

            indices.append(0)
            indices.append(Int32(1 + next))
            indices.append(Int32(1 + angularIndex))
        }

        // ------------------------------------------------------------
        // CONNECT CONCENTRIC RINGS
        // ------------------------------------------------------------

        for radialIndex in 1..<radialSegments {
            let innerStart =
                1 + (radialIndex - 1) * angularSegments

            let outerStart =
                1 + radialIndex * angularSegments

            for angularIndex in 0..<angularSegments {
                let next =
                    (angularIndex + 1) %
                    angularSegments

                let innerA =
                    Int32(innerStart + angularIndex)

                let innerB =
                    Int32(innerStart + next)

                let outerA =
                    Int32(outerStart + angularIndex)

                let outerB =
                    Int32(outerStart + next)

                indices.append(innerA)
                indices.append(outerA)
                indices.append(innerB)

                indices.append(innerB)
                indices.append(outerA)
                indices.append(outerB)
            }
        }

        // ------------------------------------------------------------
        // CALCULATE SMOOTH VERTEX NORMALS FROM TRIANGLE FACES
        // ------------------------------------------------------------

        var accumulatedNormals = Array(
            repeating: SIMD3<Float>(0.0, 0.0, 0.0),
            count: positions.count
        )

        for triangleStart in stride(
            from: 0,
            to: indices.count,
            by: 3
        ) {
            let indexA = Int(indices[triangleStart])
            let indexB = Int(indices[triangleStart + 1])
            let indexC = Int(indices[triangleStart + 2])

            let a = SIMD3<Float>(
                positions[indexA].x,
                positions[indexA].y,
                positions[indexA].z
            )

            let b = SIMD3<Float>(
                positions[indexB].x,
                positions[indexB].y,
                positions[indexB].z
            )

            let c = SIMD3<Float>(
                positions[indexC].x,
                positions[indexC].y,
                positions[indexC].z
            )

            let faceNormal = simd_cross(
                b - a,
                c - a
            )

            accumulatedNormals[indexA] += faceNormal
            accumulatedNormals[indexB] += faceNormal
            accumulatedNormals[indexC] += faceNormal
        }

        normals.removeAll(
            keepingCapacity: true
        )

        for accumulatedNormal in accumulatedNormals {
            let lengthSquared = simd_length_squared(
                accumulatedNormal
            )

            let normal: SIMD3<Float>

            if lengthSquared > 1.0e-12 {
                normal = simd_normalize(
                    accumulatedNormal
                )
            } else {
                normal = SIMD3<Float>(
                    0.0,
                    1.0,
                    0.0
                )
            }

            normals.append(
                SCNVector3(
                    normal.x,
                    normal.y,
                    normal.z
                )
            )
        }

        // ------------------------------------------------------------
        // CREATE SCENEKIT GEOMETRY
        // ------------------------------------------------------------

        let vertexSource = SCNGeometrySource(
            vertices: positions
        )

        let normalSource = SCNGeometrySource(
            normals: normals
        )

        let element = SCNGeometryElement(
            indices: indices,
            primitiveType: .triangles
        )

        let geometry = SCNGeometry(
            sources: [
                vertexSource,
                normalSource
            ],
            elements: [
                element
            ]
        )

        let material = SCNMaterial()

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
        material.lightingModel = .physicallyBased

        geometry.materials = [
            material
        ]
        
   

        return geometry
    }
}
