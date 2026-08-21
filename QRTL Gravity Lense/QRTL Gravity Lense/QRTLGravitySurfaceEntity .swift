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

        // ----------------------------------------------------
        // OUTPUT GRAVITY MEASUREMENT
        // ----------------------------------------------------
        //
        // 10^6 solar masses / star count = mass per star.
        // This is the mass figure now driving every occupied
        // cell's contribution to the gravity surface below.
        // ----------------------------------------------------

        print(field.gravityMeasurementReport)

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
        
        let testPositions: [SIMD3<Float>] = [
            SIMD3<Float>(0, 0, 0),
            SIMD3<Float>(0.1, 0, 0),
            SIMD3<Float>(0.5, 0, 0),
            SIMD3<Float>(1.0, 0, 0),
            SIMD3<Float>(5.0, 0, 0)
        ]

        for position in testPositions {

            let potential =
                field.gravitationalPotential(
                    at: position
                )

            let acceleration =
                field.qrtlLensingAcceleration(
                    at: position,
                    direction: SIMD3<Float>(1, 0, 0)
                )

            print(
                "QRTL TEST",
                "position:", position,
                "potential:", potential,
                "acceleration:", acceleration,
                "magnitude:", simd_length(acceleration)
            )
            let diagnosticPosition = SIMD3<Float>(0, 0, 0)

            print("")
            print("============================================================")
            print("QRTL FIELD PIPELINE DIAGNOSTIC")
            print("============================================================")

            print("Position:", diagnosticPosition)

            let density =
                field.massDensity(
                    at: diagnosticPosition
                )

            print("Mass density:", density)

            let normalizedDensity =
                field.normalizedDensity(
                    at: diagnosticPosition
                )

            print("Normalized density:", normalizedDensity)

            let influence =
                field.influence(
                    at: diagnosticPosition
                )

            print("QRTL influence:", influence)

            let source =
                field.qrtlSource(
                    at: diagnosticPosition
                )

            print("QRTL source:", source)

            let flux =
                field.bolgarinoFlux(
                    at: diagnosticPosition
                )

            print("Bolgarino flux:", flux)

            let currentDensity =
                field.qrtlCurrentDensity(
                    at: diagnosticPosition
                )

            print("QRTL current density:", currentDensity)

            let current =
                field.qrtlCurrent(
                    at: diagnosticPosition
                )

            print("QRTL current:", current)

            let energy =
                field.qrtlEnergyDensity(
                    at: diagnosticPosition
                )

            print("QRTL energy density:", energy)


            print("Gravitational potential:", potential)

            let gradient =
                field.indexGradient(
                    at: diagnosticPosition
                )

            print("Index gradient:", gradient)

          
            print("QRTL lensing acceleration:", acceleration)

            print("============================================================")
        }
    }
    
    // ============================================================
    // INDEPENDENT SURFACE CURVATURE VALIDATION
    // ============================================================

    private func validateSurfaceCurvature(
        radialSegments: Int,
        angularSegments: Int,
        positions: [SCNVector3]
    ) {

        guard
            radialSegments >= 3,
            angularSegments >= 3
        else {
            return
        }

        var radialHeights: [Float] = []

        radialHeights.reserveCapacity(
            radialSegments + 1
        )

        // Center height.
        radialHeights.append(
            positions[0].y
        )

        // Average each circular ring.
        for radialIndex in 1...radialSegments {

            let start =
                1
                +
                (radialIndex - 1)
                * angularSegments

            var sum: Float = 0.0
            var count = 0

            for angularIndex in 0..<angularSegments {

                let index =
                    start + angularIndex

                guard index < positions.count else {
                    continue
                }

                let y =
                    positions[index].y

                guard y.isFinite else {
                    continue
                }

                sum += y
                count += 1
            }

            if count > 0 {
                radialHeights.append(
                    sum / Float(count)
                )
            }
        }

        guard radialHeights.count >= 3 else {
            return
        }

        gravitySurfaceDiagnostics.centerDepth =
            radialHeights[0]

        gravitySurfaceDiagnostics.rimDepth =
            radialHeights.last ?? 0.0

        // --------------------------------------------------------
        // SECOND DIFFERENCE
        //
        // This measures geometric curvature of the radial profile.
        // It does NOT read the QRTL field.
        // --------------------------------------------------------

        var curvatureSum: Float = 0.0
        var curvatureCount = 0

        for index in 1..<(radialHeights.count - 1) {

            let previous =
                radialHeights[index - 1]

            let current =
                radialHeights[index]

            let next =
                radialHeights[index + 1]

            let secondDifference =
                next
                -
                2.0 * current
                +
                previous

            guard secondDifference.isFinite else {
                continue
            }

            curvatureSum +=
                abs(secondDifference)

            curvatureCount += 1
        }

        guard curvatureCount > 0 else {
            return
        }

        gravitySurfaceDiagnostics.curvatureSamples =
            curvatureCount

        gravitySurfaceDiagnostics.curvatureMagnitude =
            curvatureSum
            / Float(curvatureCount)

        // --------------------------------------------------------
        // BOWL TEST
        //
        // Center should be below its immediate radial neighbors.
        // --------------------------------------------------------

        if radialHeights.count >= 3 {

            let center =
                radialHeights[0]

            let firstRing =
                radialHeights[1]

            gravitySurfaceDiagnostics.concaveCenter =
                center < firstRing
        }
    }
    // ============================================================
    // SURFACE SYMMETRY VALIDATION
    // ============================================================

    private func validateSurfaceSymmetry(
        radialSamples: Int = 8,
        angularSamples: Int = 32
    ) {

        guard
            radialSamples > 0,
            angularSamples >= 4
        else {
            return
        }

        var totalError: Float = 0.0
        var maximumError: Float = 0.0
        var comparisonCount = 0

        let halfAngularCount =
            angularSamples / 2

        for radialIndex in 1...radialSamples {

            let radius =
                extent
                *
                Float(radialIndex)
                /
                Float(radialSamples)

            for angularIndex in 0..<halfAngularCount {

                let angle =
                    2.0
                    * Float.pi
                    * Float(angularIndex)
                    / Float(angularSamples)

                let oppositeAngle =
                    angle + Float.pi

                let positionA =
                    SIMD3<Float>(
                        radius * cos(angle),
                        0.0,
                        radius * sin(angle)
                    )

                let positionB =
                    SIMD3<Float>(
                        radius * cos(oppositeAngle),
                        0.0,
                        radius * sin(oppositeAngle)
                    )

                let intensityA =
                    sampleQRTLGravity(
                        at: positionA
                    )

                let intensityB =
                    sampleQRTLGravity(
                        at: positionB
                    )

                guard
                    intensityA.isFinite,
                    intensityB.isFinite
                else {
                    continue
                }

                let denominator =
                    max(
                        max(
                            intensityA,
                            intensityB
                        ),
                        1.0e-8
                    )

                let error =
                    abs(
                        intensityA
                        -
                        intensityB
                    )
                    / denominator

                totalError += error

                maximumError =
                    max(
                        maximumError,
                        error
                    )

                comparisonCount += 1
            }
        }

        guard comparisonCount > 0 else {
            return
        }

        gravitySurfaceDiagnostics.symmetryAverageError =
            totalError
            / Float(comparisonCount)

        gravitySurfaceDiagnostics.symmetryMaximumError =
            maximumError
    }
    // ============================================================
    // RADIAL QRTL FIELD VALIDATION
    // ============================================================

    private func validateRadialField(
        radiusSamples: Int = 16,
        angularSamples: Int = 32
    ) {

        var radialProfile:
            [(radius: Float, intensity: Float)] = []

        guard
            radiusSamples > 0,
            angularSamples > 0
        else {
            return
        }

        // Avoid treating the exact center as a directional
        // acceleration measurement.
        let minimumRadius =
            max(
                extent / Float(radiusSamples * 20),
                0.0001
            )

        for radialIndex in 1...radiusSamples {

            let radius =
                minimumRadius
                +
                (
                    extent - minimumRadius
                )
                *
                Float(radialIndex - 1)
                /
                Float(
                    max(
                        radiusSamples - 1,
                        1
                    )
                )

            var intensitySum: Float = 0.0
            var validCount = 0

            for angularIndex in 0..<angularSamples {

                let angle =
                    2.0
                    * Float.pi
                    * Float(angularIndex)
                    / Float(angularSamples)

                let position =
                    SIMD3<Float>(
                        radius * cos(angle),
                        0.0,
                        radius * sin(angle)
                    )

                let intensity =
                    sampleQRTLGravity(
                        at: position
                    )

                guard intensity.isFinite else {
                    continue
                }

                intensitySum += intensity
                validCount += 1
            }

            guard validCount > 0 else {
                continue
            }

            let averageIntensity =
                intensitySum
                / Float(validCount)

            radialProfile.append(
                (
                    radius: radius,
                    intensity: averageIntensity
                )
            )
        }

        gravitySurfaceDiagnostics.radialSamples =
            radialProfile

        guard radialProfile.count > 1 else {
            return
        }

        var decreasingViolations = 0
        var increasingViolations = 0

        for index in 1..<radialProfile.count {

            let previous =
                radialProfile[index - 1].intensity

            let current =
                radialProfile[index].intensity

            let tolerance =
                max(
                    previous * 0.01,
                    1.0e-8
                )

            if current > previous + tolerance {
                increasingViolations += 1
            }

            if current < previous - tolerance {
                decreasingViolations += 1
            }
        }

        gravitySurfaceDiagnostics.radialIncreasingViolations =
            increasingViolations

        gravitySurfaceDiagnostics.radialDecreasingViolations =
            decreasingViolations
    }
    // ============================================================
    // FIELD STATISTICS
    // ============================================================

    private func calculateFieldStatistics(
        samples: [Float]
    ) {

        guard !samples.isEmpty else {
            gravitySurfaceDiagnostics =
                GravitySurfaceDiagnostics()

            return
        }

        let validSamples =
            samples.filter {
                $0.isFinite
            }

        guard !validSamples.isEmpty else {
            gravitySurfaceDiagnostics =
                GravitySurfaceDiagnostics()

            return
        }

        let minimum =
            validSamples.min() ?? 0.0

        let maximum =
            validSamples.max() ?? 0.0

        let average =
            validSamples.reduce(
                0.0,
                +
            ) / Float(validSamples.count)

        gravitySurfaceDiagnostics.sampleCount =
            validSamples.count

        gravitySurfaceDiagnostics.minimumFieldIntensity =
            minimum

        gravitySurfaceDiagnostics.maximumFieldIntensity =
            maximum

        gravitySurfaceDiagnostics.averageFieldIntensity =
            average
    }
    // ============================================================
    // SAMPLE AUTHORITATIVE QRTL FIELD
    // ============================================================
    //
    // This measures the actual QRTL gravitational response.
    //
    // It does NOT use the visual surface height.
    //
    // Therefore this value is independent of how the surface
    // is rendered.
    //

    private func sampleQRTLGravity(
        at position: SIMD3<Float>
    ) -> Float {

        let response =
            field.qrtlLensingAcceleration(
                at: position,
                direction: SIMD3<Float>(
                    1.0,
                    0.0,
                    0.0
                )
            )

        let intensity =
            simd_length(response)

        guard intensity.isFinite else {
            return 0.0
        }

        return intensity
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
            max(radialSegments - 1, 0) *
            angularSegments * 6
        )

        // ============================================================
        // QRTL FIELD VALIDATION DATA
        // ============================================================

        var qrtlIntensities: [Float] = []

        qrtlIntensities.reserveCapacity(
            1 + radialSegments * angularSegments
        )

        var potentialMagnitudes: [Float] = []

        potentialMagnitudes.reserveCapacity(
            1 + radialSegments * angularSegments
        )

        var maximumPotential: Float = 0.0

        // ------------------------------------------------------------
        // GLOBAL QRTL STATISTICS
        // ------------------------------------------------------------

        var qrtlMinimum: Float = .greatestFiniteMagnitude
        var qrtlMaximum: Float = 0.0
        var qrtlSum: Double = 0.0
        var qrtlSampleCount: Int = 0

        // ------------------------------------------------------------
        // CENTER SAMPLE
        // ------------------------------------------------------------

        var centerQRTLIntensity: Float = 0.0

        // ------------------------------------------------------------
        // RADIAL VALIDATION
        //
        // One representative QRTL intensity is retained for each
        // radial ring. The angular average is used so that the radial
        // profile is independent of individual angular samples.
        // ------------------------------------------------------------

        var radialIntensityProfile: [Float] = []

        radialIntensityProfile.reserveCapacity(
            radialSegments + 1
        )

        // ============================================================
        // SAMPLE QRTL FIELD + POTENTIAL
        // ============================================================

        func sampleField(
            x: Float,
            z: Float
        ) -> (
            intensity: Float,
            potential: Float
        ) {

            let position =
                SIMD3<Float>(
                    x,
                    0.0,
                    z
                )

            // --------------------------------------------------------
            // AUTHORITATIVE QRTL GRAVITY RESPONSE
            // --------------------------------------------------------

            let qrtlResponse =
                field.qrtlLensingAcceleration(
                    at: position,
                    direction:
                        SIMD3<Float>(
                            1.0,
                            0.0,
                            0.0
                        )
                )

            let intensity =
                sanitize(
                    simd_length(
                        qrtlResponse
                    )
                )

            // --------------------------------------------------------
            // AUTHORITATIVE GRAVITATIONAL POTENTIAL
            // --------------------------------------------------------

            let potential =
                sanitize(
                    field.gravitationalPotential(
                        at: position
                    )
                )

            let potentialMagnitude =
                abs(
                    potential
                )

            maximumPotential =
                max(
                    maximumPotential,
                    potentialMagnitude
                )

            // --------------------------------------------------------
            // FIELD STATISTICS
            // --------------------------------------------------------

            qrtlMinimum =
                min(
                    qrtlMinimum,
                    intensity
                )

            qrtlMaximum =
                max(
                    qrtlMaximum,
                    intensity
                )

            qrtlSum +=
                Double(
                    intensity
                )

            qrtlSampleCount += 1

            return (
                intensity:
                    intensity,
                potential:
                    potentialMagnitude
            )
        }

        // ============================================================
        // CENTER SAMPLE
        // ============================================================

        let centerSample =
            sampleField(
                x: 0.0,
                z: 0.0
            )

        centerQRTLIntensity =
            centerSample.intensity

        qrtlIntensities.append(
            centerSample.intensity
        )

        potentialMagnitudes.append(
            centerSample.potential
        )

        radialIntensityProfile.append(
            centerSample.intensity
        )

        // ============================================================
        // SAMPLE CONCENTRIC RINGS
        // ============================================================

        for radialIndex in 1...radialSegments {

            let normalizedRadius =
                Float(radialIndex) /
                Float(radialSegments)

            let radius =
                normalizedRadius *
                bowlRadius

            var ringIntensitySum: Double = 0.0
            var ringSampleCount: Int = 0

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

                let sample =
                    sampleField(
                        x: x,
                        z: z
                    )

                qrtlIntensities.append(
                    sample.intensity
                )

                potentialMagnitudes.append(
                    sample.potential
                )

                ringIntensitySum +=
                    Double(
                        sample.intensity
                    )

                ringSampleCount += 1
            }

            // --------------------------------------------------------
            // RADIAL AVERAGE
            // --------------------------------------------------------

            let radialAverage: Float

            if ringSampleCount > 0 {

                radialAverage =
                    Float(
                        ringIntensitySum /
                        Double(
                            ringSampleCount
                        )
                    )

            } else {

                radialAverage = 0.0
            }

            radialIntensityProfile.append(
                radialAverage
            )
        }

        // ============================================================
        // VALIDATE GLOBAL FIELD STATISTICS
        // ============================================================

        let qrtlAverage: Float

        if qrtlSampleCount > 0 {

            qrtlAverage =
                Float(
                    qrtlSum /
                    Double(
                        qrtlSampleCount
                    )
                )

        } else {

            qrtlAverage = 0.0
        }

        if qrtlMinimum ==
            .greatestFiniteMagnitude {

            qrtlMinimum = 0.0
        }

        // ============================================================
        // RADIAL FIELD VALIDATION
        //
        // For the current symmetric surface, the radial profile should
        // generally decrease as distance from the center increases.
        //
        // This does NOT assume a 1/r² law.
        // ============================================================

        var radialDecreaseCount = 0
        var radialComparisonCount = 0

        if radialIntensityProfile.count > 1 {

            for i in 1..<radialIntensityProfile.count {

                let previous =
                    radialIntensityProfile[i - 1]

                let current =
                    radialIntensityProfile[i]

                if current <= previous {

                    radialDecreaseCount += 1
                }

                radialComparisonCount += 1
            }
        }

        let radialMonotonicity: Float

        if radialComparisonCount > 0 {

            radialMonotonicity =
                Float(
                    radialDecreaseCount
                ) /
                Float(
                    radialComparisonCount
                )

        } else {

            radialMonotonicity = 0.0
        }

        // ============================================================
        // SURFACE SYMMETRY VALIDATION
        //
        // Opposite angular samples at the same radius should have
        // similar QRTL intensity for a symmetric mass distribution.
        // ============================================================

        var symmetryErrorSum: Double = 0.0
        var symmetryComparisonCount = 0

        let halfAngularSegments =
            angularSegments / 2

        for radialIndex in 1...radialSegments {

            let ringStart =
                1 +
                (radialIndex - 1) *
                angularSegments

            for angularIndex in 0..<halfAngularSegments {

                let oppositeIndex =
                    angularIndex +
                    halfAngularSegments

                let indexA =
                    ringStart +
                    angularIndex

                let indexB =
                    ringStart +
                    oppositeIndex

                guard
                    indexA <
                        qrtlIntensities.count,
                    indexB <
                        qrtlIntensities.count
                else {
                    continue
                }

                let a =
                    qrtlIntensities[indexA]

                let b =
                    qrtlIntensities[indexB]

                let denominator =
                    max(
                        max(
                            abs(a),
                            abs(b)
                        ),
                        1.0e-12
                    )

                let relativeError =
                    abs(a - b) /
                    denominator

                symmetryErrorSum +=
                    Double(
                        relativeError
                    )

                symmetryComparisonCount += 1
            }
        }

        let qrtlSymmetryError: Float

        if symmetryComparisonCount > 0 {

            qrtlSymmetryError =
                Float(
                    symmetryErrorSum /
                    Double(
                        symmetryComparisonCount
                    )
                )

        } else {

            qrtlSymmetryError = 0.0
        }

        // ============================================================
        // POTENTIAL NORMALIZATION
        // ============================================================

        let normalization =
            max(
                maximumPotential,
                1.0e-30
            )

        // ============================================================
        // BUILD CENTER VERTEX
        // ============================================================

        let centerDepth =
            -min(
                max(
                    potentialMagnitudes[0] /
                    normalization,
                    0.0
                ),
                1.0
            ) *
            curvatureScale

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

        // ============================================================
        // BUILD CIRCULAR RINGS
        // ============================================================

        var potentialIndex = 1

        for radialIndex in 1...radialSegments {

            let normalizedRadius =
                Float(radialIndex) /
                Float(radialSegments)

            let radius =
                normalizedRadius *
                bowlRadius

            // --------------------------------------------------------
            // RIM FADE
            // --------------------------------------------------------

            let rimStart =
                max(
                    0.0,
                    1.0 -
                    rimFadeFraction
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

                let clampedT =
                    min(
                        max(
                            t,
                            0.0
                        ),
                        1.0
                    )

                rimFade =
                    1.0 -
                    clampedT *
                    clampedT *
                    (
                        3.0 -
                        2.0 *
                        clampedT
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

        // ============================================================
        // INDEPENDENT SURFACE CURVATURE VALIDATION
        //
        // Estimate radial curvature directly from the generated
        // surface heights.
        //
        // This is deliberately separate from the QRTL field value.
        //
        // The quantity being tested here is the geometry:
        //
        //      d²y / dr²
        //
        // It tells us whether the generated surface actually has
        // curvature rather than merely being displaced vertically.
        // ============================================================

        var curvatureMagnitudeSum: Double = 0.0
        var curvatureSampleCount = 0

        if radialSegments >= 2 {

            var radialHeights: [Float] = []

            radialHeights.reserveCapacity(
                radialSegments + 1
            )

            radialHeights.append(
                centerDepth
            )

            for radialIndex in 1...radialSegments {

                let ringStart =
                    1 +
                    (radialIndex - 1) *
                    angularSegments

                guard
                    ringStart <
                        positions.count
                else {
                    continue
                }

                var heightSum: Double = 0.0

                for angularIndex in 0..<angularSegments {

                    let vertex =
                        positions[
                            ringStart +
                            angularIndex
                        ]

                    heightSum +=
                        Double(
                            vertex.y
                        )
                }

                let averageHeight =
                    Float(
                        heightSum /
                        Double(
                            angularSegments
                        )
                    )

                radialHeights.append(
                    averageHeight
                )
            }

            if radialHeights.count >= 3 {

                let dr =
                    bowlRadius /
                    Float(
                        radialSegments
                    )

                if dr > 1.0e-12 {

                    for i in 1..<(radialHeights.count - 1) {

                        let previous =
                            radialHeights[i - 1]

                        let current =
                            radialHeights[i]

                        let next =
                            radialHeights[i + 1]

                        let secondDerivative =
                            (
                                next -
                                2.0 * current +
                                previous
                            ) /
                            (
                                dr * dr
                            )

                        if secondDerivative.isFinite {

                            curvatureMagnitudeSum +=
                                Double(
                                    abs(
                                        secondDerivative
                                    )
                                )

                            curvatureSampleCount += 1
                        }
                    }
                }
            }
        }

        let averageSurfaceCurvature: Float

        if curvatureSampleCount > 0 {

            averageSurfaceCurvature =
                Float(
                    curvatureMagnitudeSum /
                    Double(
                        curvatureSampleCount
                    )
                )

        } else {

            averageSurfaceCurvature = 0.0
        }

        // ============================================================
        // QRTL SURFACE DIAGNOSTIC REPORT
        // ============================================================

        print("")
        print("============================================================")
        print("QRTL GRAVITY SURFACE VALIDATION")
        print("============================================================")
    
        print("QRTL Surface Diagnostics")
        print("-------------------------")

        print(
            "QRTL sample count: " +
            "\(gravitySurfaceDiagnostics.sampleCount)"
        )

        print(
            "QRTL minimum field: " +
            "\(gravitySurfaceDiagnostics.minimumFieldIntensity)"
        )

        print(
            "QRTL maximum field: " +
            "\(gravitySurfaceDiagnostics.maximumFieldIntensity)"
        )

        print(
            "QRTL average field: " +
            "\(gravitySurfaceDiagnostics.averageFieldIntensity)"
        )

        print(
            "QRTL symmetry error: " +
            "\(gravitySurfaceDiagnostics.symmetryMaximumError)"
        )

        
        print(
            "Average surface curvature: " +
            "\(averageSurfaceCurvature)"
        )

        print(
            "============================================================"
        )

        print(
            "RADIAL QRTL PROFILE"
        )

        for i in 0..<radialIntensityProfile.count {

            let radius =
                Float(i) /
                Float(radialSegments) *
                bowlRadius

            print(
                "r = \(radius), " +
                "QRTL = \(radialIntensityProfile[i])"
            )
        }

        print(
            "============================================================"
        )

        // ============================================================
        // CREATE CENTER TRIANGLE FAN
        // ============================================================

        for angularIndex in 0..<angularSegments {

            let next =
                (
                    angularIndex + 1
                ) %
                angularSegments

            indices.append(0)

            indices.append(
                Int32(
                    1 + next
                )
            )

            indices.append(
                Int32(
                    1 + angularIndex
                )
            )
        }

        // ============================================================
        // CONNECT CONCENTRIC RINGS
        // ============================================================

        for radialIndex in 1..<radialSegments {

            let innerStart =
                1 +
                (
                    radialIndex - 1
                ) *
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

        // ============================================================
        // CALCULATE SMOOTH VERTEX NORMALS
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

            let faceNormal =
                simd_cross(
                    b - a,
                    c - a
                )

            accumulatedNormals[indexA] +=
                faceNormal

            accumulatedNormals[indexB] +=
                faceNormal

            accumulatedNormals[indexC] +=
                faceNormal
        }

        normals.removeAll(
            keepingCapacity: true
        )

        for accumulatedNormal
        in accumulatedNormals {

            let lengthSquared =
                simd_length_squared(
                    accumulatedNormal
                )

            let normal:
                SIMD3<Float>

            if lengthSquared > 1.0e-12 {

                normal =
                    simd_normalize(
                        accumulatedNormal
                    )

            } else {

                normal =
                    SIMD3<Float>(
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

        // ============================================================
        // CREATE SCENEKIT GEOMETRY
        // ============================================================

        let vertexSource =
            SCNGeometrySource(
                vertices:
                    positions
            )

        let normalSource =
            SCNGeometrySource(
                normals:
                    normals
            )

        let element =
            SCNGeometryElement(
                indices:
                    indices,
                primitiveType:
                    .triangles
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

        // ============================================================
        // MATERIAL
        // ============================================================

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

        material.isDoubleSided =
            true

        material.transparency =
            0.82

        material.lightingModel =
            .physicallyBased

        geometry.materials = [
            material
        ]

        return geometry
    }

}
