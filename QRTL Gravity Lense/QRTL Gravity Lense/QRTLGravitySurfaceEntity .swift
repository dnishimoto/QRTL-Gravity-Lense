//
//  QRTLGravitySurfaceEntity.swift
//  QRTL Gravity Lense
//
//  Complete curvilinear QRTL gravity surface,
//  photon tracing, and dual galaxy projection entity.
//
//  FIXED: Gravity surface is now a proper GR spacetime bowl
//         created by the mass of the globular cluster(s).
//

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
    // SURFACE NODE
    // ============================================================

    private func makeSurfaceNode() -> SCNNode {
        let node = SCNNode()
        node.geometry = makeSurfaceGeometry()

        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemTeal.withAlphaComponent(0.70)
        material.specular.contents = UIColor.white.withAlphaComponent(0.35)
        material.emission.contents = UIColor.systemTeal.withAlphaComponent(0.08)
        material.isDoubleSided = true
        material.transparency = 0.70
        material.lightingModel = .physicallyBased

        node.geometry?.materials = [material]
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

    private func makeSurfaceGeometry()
        -> SCNGeometry
    {
        let n =
            gridSize

        let size =
            extent

        let start =
            -size

        let step =
            (2.0 * size) /
            Float(n - 1)

        var positions:
            [SCNVector3] = []

        positions.reserveCapacity(
            n * n
        )

        var heights =
            [Float](
                repeating: 0.0,
                count: n * n
            )

        var indices:
            [Int32] = []

        indices.reserveCapacity(
            (n - 1) *
            (n - 1) *
            6
        )

        // ============================================================
        // SAMPLE THE ACTUAL QRTL / MASS POTENTIAL
        // ============================================================

        var maximumMagnitude:
            Double = 0.0

        var potentialValues =
            [Double](
                repeating: 0.0,
                count: n * n
            )

        for j in 0..<n {

            for i in 0..<n {

                let x =
                    start +
                    Float(i) * step

                let z =
                    start +
                    Float(j) * step

                let position =
                    SIMD3<Float>(
                        x,
                        0.0,
                        z
                    )

                let effectiveEnergyDensity =
                    field.qrtlEnergyDensity(
                        at: position
                    )

                let potential =
                    field.gravitationalPotential(
                        at: position,
                        effectiveEnergyDensity:
                            effectiveEnergyDensity
                    )

                let safePotential =
                    potential.isFinite
                    ? potential
                    : 0.0

                let arrayIndex =
                    j * n + i

                potentialValues[
                    arrayIndex
                ] =
                    Double(safePotential)

                maximumMagnitude =
                    max(
                        maximumMagnitude,
                        Double(abs(safePotential))
                    )
                 
            }
        }

        // ============================================================
        // NORMALIZE POTENTIAL
        // ============================================================

        let normalization =
            max(
                maximumMagnitude,
                1.0e-30
            )

        for j in 0..<n {

            for i in 0..<n {

                let arrayIndex =
                    j * n + i

                let potential =
                    potentialValues[
                        arrayIndex
                    ]

                // ----------------------------------------------------
                // GRAVITATIONAL POTENTIAL IS NEGATIVE.
                //
                // Convert magnitude into a positive normalized
                // curvature strength.
                // ----------------------------------------------------

                let normalized =
                    min(
                        max(
                            abs(potential) /
                            normalization,
                            0.0
                        ),
                        1.0
                    )

                // ----------------------------------------------------
                // CREATE THE BOWL.
                //
                // Center = negative Y
                // Exterior = approximately zero
                // ----------------------------------------------------

                let y =
                    -Float(normalized) *
                    curvatureScale

                heights[
                    arrayIndex
                ] =
                    y

                let x =
                    start +
                    Float(i) * step

                let z =
                    start +
                    Float(j) * step

                positions.append(
                    SCNVector3(
                        x,
                        y,
                        z
                    )
                )
            }
        }

        // ============================================================
        // CALCULATE VERTEX NORMALS
        // ============================================================

        var normals:
            [SCNVector3] = []

        normals.reserveCapacity(
            n * n
        )

        for j in 0..<n {

            for i in 0..<n {

                let left =
                    max(i - 1, 0)

                let right =
                    min(i + 1, n - 1)

                let down =
                    max(j - 1, 0)

                let up =
                    min(j + 1, n - 1)

                let hLeft =
                    heights[
                        j * n + left
                    ]

                let hRight =
                    heights[
                        j * n + right
                    ]

                let hDown =
                    heights[
                        down * n + i
                    ]

                let hUp =
                    heights[
                        up * n + i
                    ]

                let dx =
                    max(
                        Float(
                            right - left
                        ) * step,
                        1.0e-6
                    )

                let dz =
                    max(
                        Float(
                            up - down
                        ) * step,
                        1.0e-6
                    )

                let slopeX =
                    (hRight - hLeft) /
                    dx

                let slopeZ =
                    (hUp - hDown) /
                    dz

                let normal =
                    simd_normalize(
                        SIMD3<Float>(
                            -slopeX,
                            1.0,
                            -slopeZ
                        )
                    )

                normals.append(
                    SCNVector3(
                        normal.x,
                        normal.y,
                        normal.z
                    )
                )
            }
        }

        // ============================================================
        // TRIANGULATE
        // ============================================================
        //
        // IMPORTANT:
        //
        // Winding is CCW when viewed from +Y.
        //
        // ============================================================

        for j in 0..<(n - 1) {

            for i in 0..<(n - 1) {

                let index =
                    Int32(
                        j * n + i
                    )

                let row =
                    Int32(n)

                // ----------------------------------------------------
                // TRIANGLE 1
                // ----------------------------------------------------

                indices.append(
                    index
                )

                indices.append(
                    index + row
                )

                indices.append(
                    index + 1
                )

                // ----------------------------------------------------
                // TRIANGLE 2
                // ----------------------------------------------------

                indices.append(
                    index + 1
                )

                indices.append(
                    index + row
                )

                indices.append(
                    index + row + 1
                )
            }
        }

        // ============================================================
        // GEOMETRY SOURCES
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
                sources:
                    [
                        vertexSource,
                        normalSource
                    ],
                elements:
                    [
                        element
                    ]
            )

        // ============================================================
        // MATERIAL
        // ============================================================

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor.systemTeal.withAlphaComponent(
                0.70
            )

        material.specular.contents =
            UIColor.white.withAlphaComponent(
                0.35
            )

        material.emission.contents =
            UIColor.systemTeal.withAlphaComponent(
                0.08
            )

        material.isDoubleSided =
            false

        material.transparency =
            0.70

        material.lightingModel =
            .physicallyBased

        geometry.materials =
            [material]

        return geometry
    }
    // ============================================================
    // SAFE FLOAT
    // ============================================================

    private func sanitize(_ value: Float) -> Float {
        guard value.isFinite else { return 0.0 }
        return value
    }

    // ============================================================
    // GALAXY PHOTON PIPELINE
    // ============================================================

    func computeGalaxyProjections() {
        photonPathsA.removeAll(keepingCapacity: true)
        photonPathsB.removeAll(keepingCapacity: true)
        galaxyAProjectionPositions.removeAll(keepingCapacity: true)
        galaxyBProjectionPositions.removeAll(keepingCapacity: true)

        let tracer = QRTLPhotonTracer(field: field)

        let galaxyAcenter = SIMD3<Float>(-extent, 0.0, -0.70 * extent)
        let galaxyBcenter = SIMD3<Float>(-extent, 0.0,  0.70 * extent)
        let galaxyRadius = 0.25 * extent

        let stepSize = (2.0 * Double(extent)) / Double(photonSteps)
        let totalDistance = 2.0 * Double(extent)

        for i in 0..<numberOfStars {
            let angle = 2.0 * Double.pi * Double(i) / Double(numberOfStars)

            // Galaxy A
            let localA = SIMD3<Float>(Float(cos(angle)), Float(sin(angle)), 0.0)
            let sourceA = galaxyAcenter + galaxyRadius * localA

            let pathA = tracer.trace(
                start: SIMD3<Double>(Double(sourceA.x), Double(sourceA.y), Double(sourceA.z)),
                direction: SIMD3<Double>(1.0, 0.0, 0.0),
                totalDistance: totalDistance,
                stepSize: stepSize
            )

            if pathA.count > 1 {
                photonPathsA.append(pathA)
                if let projection = projectionPoint(from: pathA) {
                    galaxyAProjectionPositions.append(projection)
                }
            }

            // Galaxy B
            let localB = SIMD3<Float>(Float(sin(angle)), Float(cos(angle)), 0.0)
            let sourceB = galaxyBcenter + galaxyRadius * localB

            let pathB = tracer.trace(
                start: SIMD3<Double>(Double(sourceB.x), Double(sourceB.y), Double(sourceB.z)),
                direction: SIMD3<Double>(1.0, 0.0, 0.0),
                totalDistance: totalDistance,
                stepSize: stepSize
            )

            if pathB.count > 1 {
                photonPathsB.append(pathB)
                if let projection = projectionPoint(from: pathB) {
                    galaxyBProjectionPositions.append(projection)
                }
            }
        }
    }

    // ============================================================
    // PROJECTION POINT
    // ============================================================

    private func projectionPoint(from path: [SIMD3<Double>]) -> SIMD3<Double>? {
        guard path.count >= 2 else { return nil }

        let planeX = Double(extent)

        for i in 1..<path.count {
            let previous = path[i - 1]
            let current = path[i]

            if previous.x <= planeX && current.x >= planeX {
                let dx = current.x - previous.x
                guard abs(dx) > 1.0e-12 else { return current }

                let t = (planeX - previous.x) / dx
                let clampedT = min(max(t, 0.0), 1.0)
                return previous + (current - previous) * clampedT
            }
        }

        if let finalPoint = path.last, abs(finalPoint.x - planeX) < 1.0e-5 {
            return finalPoint
        }
        return nil
    }

    // ============================================================
    // PHOTON PATH GEOMETRY
    // ============================================================

    private func makePhotonGeometry(paths: [[SIMD3<Double>]], color: UIColor) -> SCNGeometry {
        var vertices: [SCNVector3] = []
        var indices: [Int32] = []

        for path in paths {
            guard path.count > 1 else { continue }

            let startIndex = Int32(vertices.count)

            for point in path {
                guard point.x.isFinite, point.y.isFinite, point.z.isFinite else { continue }
                vertices.append(SCNVector3(Float(point.x), Float(point.y), Float(point.z)))
            }

            let validCount = vertices.count - Int(startIndex)
            guard validCount > 1 else { continue }

            for i in 0..<(validCount - 1) {
                indices.append(startIndex + Int32(i))
                indices.append(startIndex + Int32(i + 1))
            }
        }

        guard vertices.count > 1, indices.count >= 2 else {
            return SCNGeometry()
        }

        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [source], elements: [element])

        let material = SCNMaterial()
        material.diffuse.contents = color
        material.emission.contents = color
        material.isDoubleSided = true
        geometry.materials = [material]

        return geometry
    }

    // ============================================================
    // PROJECTED GALAXY
    // ============================================================

    private func makeProjectionNode(positions: [SIMD3<Double>], color: UIColor) -> SCNNode {
        let parent = SCNNode()
        let radius = max(0.012, Double(extent) / Double(gridSize) * 0.55)
        let projectionOffset = 0.003

        for position in positions {
            let sphere = SCNSphere(radius: radius)
            let material = SCNMaterial()
            material.diffuse.contents = color
            material.emission.contents = color
            material.isDoubleSided = true
            sphere.materials = [material]

            let node = SCNNode(geometry: sphere)
            node.position = SCNVector3(Float(position.x), Float(position.y), Float(position.z))
            node.position.x += Float(projectionOffset)
            parent.addChildNode(node)
        }
        return parent
    }

    // ============================================================
    // CAMERA
    // ============================================================

    func makeCameraNode() -> SCNNode {
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.zNear = 0.001
        camera.zFar = Double(extent) * 20.0
        camera.fieldOfView = 55.0
        cameraNode.camera = camera

        cameraNode.position = SCNVector3(0.0, extent * 0.70, extent * 2.30)
        cameraNode.eulerAngles = SCNVector3(-0.38, 0.0, 0.0)
        return cameraNode
    }

    // ============================================================
    // VISIBILITY & CLEANUP
    // ============================================================

    func setPhotonPathsVisible(_ visible: Bool) {
        photonANode?.isHidden = !visible
        photonBNode?.isHidden = !visible
    }

    func setSurfaceVisible(_ visible: Bool) {
        surfaceNode?.isHidden = !visible
    }

    func setGalaxyAVisible(_ visible: Bool) {
        galaxyANode?.isHidden = !visible
    }

    func setGalaxyBVisible(_ visible: Bool) {
        galaxyBNode?.isHidden = !visible
    }

    func removePhotonPaths() {
        photonANode?.removeFromParentNode()
        photonBNode?.removeFromParentNode()
        photonANode = nil
        photonBNode = nil
    }

    func removeProjectedGalaxies() {
        galaxyANode?.removeFromParentNode()
        galaxyBNode?.removeFromParentNode()
        galaxyANode = nil
        galaxyBNode = nil
    }

    func removeSurface() {
        surfaceNode?.removeFromParentNode()
        surfaceNode = nil
    }

    func rebuild() {
        buildScene()
    }

    func rebuildPhotonProjection() {
        photonANode?.removeFromParentNode()
        photonBNode?.removeFromParentNode()
        galaxyANode?.removeFromParentNode()
        galaxyBNode?.removeFromParentNode()

        photonANode = nil
        photonBNode = nil
        galaxyANode = nil
        galaxyBNode = nil

        computeGalaxyProjections()

        let photonA = SCNNode(geometry: makePhotonGeometry(paths: photonPathsA, color: .cyan))
        photonANode = photonA
        addChildNode(photonA)

        let photonB = SCNNode(geometry: makePhotonGeometry(paths: photonPathsB, color: .magenta))
        photonBNode = photonB
        addChildNode(photonB)

        let galaxyA = makeProjectionNode(positions: galaxyAProjectionPositions, color: .cyan)
        galaxyANode = galaxyA
        addChildNode(galaxyA)

        let galaxyB = makeProjectionNode(positions: galaxyBProjectionPositions, color: .magenta)
        galaxyBNode = galaxyB
        addChildNode(galaxyB)
    }
}
