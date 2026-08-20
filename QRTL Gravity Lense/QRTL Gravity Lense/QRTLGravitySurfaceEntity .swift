//
//  QRTLGravitySurfaceEntity.swift
//  QRTL Gravity Lense
//
//  Controller-pipeline entity for:
//  - QRTL gravitational surface
//  - one-million-solar-mass cluster
//  - photon A tracing
//  - photon B tracing
//  - projected galaxy A
//  - projected galaxy B
//
//  The entity does NOT perform SwiftUI rendering.
//  It produces an SCNScene that can be inserted into the
//  controller pipeline.
//

import Foundation
import SceneKit
import simd
import UIKit

//
//  QRTLGravitySurfaceEntity.swift
//  QRTL Gravity Lense
//
//  Complete curvilinear QRTL gravity surface,
//  photon tracing, and dual galaxy projection entity.
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
// Therefore:
//
//     scene.rootNode.addChildNode(surface)
//
// and:
//
//     surface.removeFromParentNode()
//
// work directly.
//
// The entity contains:
//
//     QRTL field
//          ↓
//     curvilinear gravity surface
//          ↓
//     source galaxy A/B
//          ↓
//     photon tracing
//          ↓
//     transverse QRTL lensing
//          ↓
//     projection plane
//          ↓
//     projected galaxy A/B
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

    private(set) var surfaceNode:
        SCNNode?

    private(set) var photonANode:
        SCNNode?

    private(set) var photonBNode:
        SCNNode?

    private(set) var galaxyANode:
        SCNNode?

    private(set) var galaxyBNode:
        SCNNode?

    // ============================================================
    // PHOTON RESULTS
    // ============================================================

    private(set) var photonPathsA:
        [[SIMD3<Double>]] = []

    private(set) var photonPathsB:
        [[SIMD3<Double>]] = []

    private(set) var galaxyAProjectionPositions:
        [SIMD3<Double>] = []

    private(set) var galaxyBProjectionPositions:
        [SIMD3<Double>] = []

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

        self.field =
            field

        self.gridSize =
            max(
                gridSize,
                4
            )

        self.extent =
            max(
                extent,
                0.001
            )

        self.numberOfStars =
            max(
                numberOfStars,
                1
            )

        self.photonSteps =
            max(
                photonSteps,
                10
            )

        self.curvatureScale =
            max(
                curvatureScale,
                0.0001
            )

        super.init()

        buildScene()
    }

    // ============================================================
    // NSCODER
    // ============================================================

    required init?(
        coder:
            NSCoder
    ) {

        fatalError(
            "QRTLGravitySurfaceEntity does not support NSCoder initialization."
        )
    }

    // ============================================================
    // BUILD COMPLETE ENTITY
    // ============================================================

    func buildScene() {

        // --------------------------------------------------------
        // REMOVE PREVIOUS CONTENT
        // --------------------------------------------------------

        childNodes.forEach {
            $0.removeFromParentNode()
        }

        surfaceNode =
            nil

        photonANode =
            nil

        photonBNode =
            nil

        galaxyANode =
            nil

        galaxyBNode =
            nil

        photonPathsA.removeAll(
            keepingCapacity:
                true
        )

        photonPathsB.removeAll(
            keepingCapacity:
                true
        )

        galaxyAProjectionPositions.removeAll(
            keepingCapacity:
                true
        )

        galaxyBProjectionPositions.removeAll(
            keepingCapacity:
                true
        )

        // --------------------------------------------------------
        // BUILD GRAVITY SURFACE
        // --------------------------------------------------------

        let surface =
            makeSurfaceNode()

        surfaceNode =
            surface

        addChildNode(
            surface
        )

        // --------------------------------------------------------
        // TRACE GALAXIES
        // --------------------------------------------------------

        computeGalaxyProjections()

        // --------------------------------------------------------
        // PHOTON A
        // --------------------------------------------------------

        let photonAGeometry =
            makePhotonGeometry(
                paths:
                    photonPathsA,
                color:
                    .cyan
            )

        let photonAGraphicsNode =
            SCNNode(
                geometry:
                    photonAGeometry
            )

        photonANode =
            photonAGraphicsNode

        addChildNode(
            photonAGraphicsNode
        )

        // --------------------------------------------------------
        // PHOTON B
        // --------------------------------------------------------

        let photonBGeometry =
            makePhotonGeometry(
                paths:
                    photonPathsB,
                color:
                    .magenta
            )

        let photonBGraphicsNode =
            SCNNode(
                geometry:
                    photonBGeometry
            )

        photonBNode =
            photonBGraphicsNode

        addChildNode(
            photonBGraphicsNode
        )

        // --------------------------------------------------------
        // PROJECTED GALAXY A
        // --------------------------------------------------------

        let galaxyA =
            makeProjectionNode(
                positions:
                    galaxyAProjectionPositions,
                color:
                    .cyan
            )

        galaxyANode =
            galaxyA

        addChildNode(
            galaxyA
        )

        // --------------------------------------------------------
        // PROJECTED GALAXY B
        // --------------------------------------------------------

        let galaxyB =
            makeProjectionNode(
                positions:
                    galaxyBProjectionPositions,
                color:
                    .magenta
            )

        galaxyBNode =
            galaxyB

        addChildNode(
            galaxyB
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

        node.geometry =
            geometry

        // --------------------------------------------------------
        // MATERIAL
        // --------------------------------------------------------

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor.systemTeal
                .withAlphaComponent(
                    0.76
                )

        material.specular.contents =
            UIColor.white

        material.emission.contents =
            UIColor.systemTeal
                .withAlphaComponent(
                    0.15
                )

        material.isDoubleSided =
            true

        material.transparency =
            0.76

        geometry.materials =
            [
                material
            ]

        return node
    }

    // ============================================================
    // CURVILINEAR GRAVITY SURFACE
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
            (
                2.0 *
                size
            )
            /
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
            )
            *
            (
                n - 1
            )
            *
            6
        )

        // ========================================================
        // CREATE GRID
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

                let position =
                    SIMD3<Float>(
                        x,
                        0.0,
                        z
                    )

                // =================================================
                // MASS DENSITY
                // =================================================

                let density =
                    field.normalizedDensity(
                        at:
                            position
                    )

                // =================================================
                // BOLGARINO FLOW
                // =================================================

                let flow =
                    field.bolgarinoFlux(
                        at:
                            position
                    )

                let flowMagnitude =
                    simd_length(
                        flow
                    )

                let normalizedFlow:
                    Float

                if flowMagnitude.isFinite &&
                    flowMagnitude > 0.0
                {

                    normalizedFlow =
                        min(
                            flowMagnitude /
                            (
                                flowMagnitude +
                                1.0
                            ),
                            1.0
                        )

                } else {

                    normalizedFlow =
                        0.0
                }

                // =================================================
                // COMBINED CURVATURE
                // =================================================

                let curvature =
                    (
                        0.65 *
                        density
                    )
                    +
                    (
                        0.35 *
                        normalizedFlow
                    )

                let safeCurvature =
                    curvature.isFinite
                    ? curvature
                    : 0.0

                let y =
                    safeCurvature *
                    curvatureScale

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
                    contentsOf:
                    [
                        index,
                        index + 1,
                        index +
                            Int32(n),

                        index + 1,
                        index + 1 +
                            Int32(n),
                        index +
                            Int32(n)
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
            sources:
                [
                    source
                ],
            elements:
                [
                    element
                ]
        )
    }

    // ============================================================
    // GALAXY PHOTON PIPELINE
    // ============================================================
    //
    // Every source star produces one photon.
    //
    // Galaxy A:
    //
    //     source star
    //          ↓
    //     QRTLPhotonTracer
    //          ↓
    //     QRTL central lensing potential
    //          ↓
    //     transverse influence
    //          ↓
    //     accumulated photon deflection
    //          ↓
    //     observation plane
    //
    // Galaxy B follows the same pipeline.
    //
    // IMPORTANT:
    //
    // The photon does NOT simply follow the QRTL radial field
    // vector. The tracer is responsible for accumulating the
    // transverse lensing influence along the photon direction.
    //
    // ============================================================

    func computeGalaxyProjections() {

        photonPathsA.removeAll(
            keepingCapacity:
                true
        )

        photonPathsB.removeAll(
            keepingCapacity:
                true
        )

        galaxyAProjectionPositions.removeAll(
            keepingCapacity:
                true
        )

        galaxyBProjectionPositions.removeAll(
            keepingCapacity:
                true
        )

        // --------------------------------------------------------
        // PHOTON TRACER
        // --------------------------------------------------------

        let tracer =
            QRTLPhotonTracer(
                field:
                    field
            )

        // ========================================================
        // SOURCE GALAXY CENTERS
        // ========================================================

        let galaxyAcenter =
            SIMD3<Float>(
                -extent,
                0.0,
                -0.7 *
                extent
            )

        let galaxyBcenter =
            SIMD3<Float>(
                -extent,
                0.0,
                0.7 *
                extent
            )

        let galaxyRadius =
            0.25 *
            extent

        // ========================================================
        // PHOTON INTEGRATION
        // ========================================================

        let stepSize =
            (
                2.0 *
                Double(extent)
            )
            /
            Double(
                photonSteps
            )

        let totalDistance =
            2.0 *
            Double(extent)

        // ========================================================
        // TRACE EVERY SOURCE STAR
        // ========================================================

        for i in 0..<numberOfStars {

            let angle =
                2.0 *
                Double.pi *
                Double(i) /
                Double(
                    numberOfStars
                )

            // ====================================================
            // GALAXY A STAR
            // ====================================================

            let localA =
                SIMD3<Float>(
                    Float(
                        cos(angle)
                    ),
                    Float(
                        sin(angle)
                    ),
                    0.0
                )

            let sourceA =
                galaxyAcenter +
                galaxyRadius *
                localA

            let pathA =
                tracer.trace(
                    start:
                        SIMD3<Double>(
                            Double(
                                sourceA.x
                            ),
                            Double(
                                sourceA.y
                            ),
                            Double(
                                sourceA.z
                            )
                        ),

                    direction:
                        SIMD3<Double>(
                            1.0,
                            0.0,
                            0.0
                        ),

                    totalDistance:
                        totalDistance,

                    stepSize:
                        stepSize
                )

            if pathA.count > 1 {

                photonPathsA.append(
                    pathA
                )

                if let projection =
                    projectionPoint(
                        from:
                            pathA
                    )
                {

                    galaxyAProjectionPositions.append(
                        projection
                    )
                }
            }

            // ====================================================
            // GALAXY B STAR
            // ====================================================

            let localB =
                SIMD3<Float>(
                    Float(
                        sin(angle)
                    ),
                    Float(
                        cos(angle)
                    ),
                    0.0
                )

            let sourceB =
                galaxyBcenter +
                galaxyRadius *
                localB

            let pathB =
                tracer.trace(
                    start:
                        SIMD3<Double>(
                            Double(
                                sourceB.x
                            ),
                            Double(
                                sourceB.y
                            ),
                            Double(
                                sourceB.z
                            )
                        ),

                    direction:
                        SIMD3<Double>(
                            1.0,
                            0.0,
                            0.0
                        ),

                    totalDistance:
                        totalDistance,

                    stepSize:
                        stepSize
                )

            if pathB.count > 1 {

                photonPathsB.append(
                    pathB
                )

                if let projection =
                    projectionPoint(
                        from:
                            pathB
                    )
                {

                    galaxyBProjectionPositions.append(
                        projection
                    )
                }
            }
        }
    }

    // ============================================================
    // PROJECTION POINT
    //
    // Observation plane:
    //
    //     x = +extent
    //
    // Interpolate between the final two photon points so the
    // projection remains valid even when the integration step
    // crosses the plane.
    // ============================================================

    private func projectionPoint(
        from path:
            [SIMD3<Double>]
    )
        -> SIMD3<Double>?
    {

        guard path.count >= 2
        else {
            return nil
        }

        let planeX =
            Double(
                extent
            )

        for i in 1..<path.count {

            let previous =
                path[
                    i - 1
                ]

            let current =
                path[
                    i
                ]

            if previous.x <= planeX &&
                current.x >= planeX
            {

                let dx =
                    current.x -
                    previous.x

                guard abs(dx) >
                    1.0e-12
                else {
                    return current
                }

                let t =
                    (
                        planeX -
                        previous.x
                    )
                    /
                    dx

                return
                    previous +
                    (
                        current -
                        previous
                    )
                    *
                    t
            }
        }

        return nil
    }

    // ============================================================
    // PHOTON PATH GEOMETRY
    // ============================================================

    private func makePhotonGeometry(
        paths:
            [[SIMD3<Double>]],
        color:
            UIColor
    )
        -> SCNGeometry
    {

        var vertices:
            [SCNVector3] = []

        var indices:
            [Int32] = []

        // ========================================================
        // BUILD ALL PATHS INTO ONE LINE GEOMETRY
        // ========================================================

        for path in paths {

            guard path.count > 1
            else {
                continue
            }

            let startIndex =
                Int32(
                    vertices.count
                )

            // ----------------------------------------------------
            // VERTICES
            // ----------------------------------------------------

            for point in path {

                vertices.append(
                    SCNVector3(
                        Float(
                            point.x
                        ),
                        Float(
                            point.y
                        ),
                        Float(
                            point.z
                        )
                    )
                )
            }

            // ----------------------------------------------------
            // LINE SEGMENTS
            // ----------------------------------------------------

            for i in 0..<(path.count - 1) {

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

        // ========================================================
        // EMPTY PATH PROTECTION
        // ========================================================

        guard vertices.count > 1
        else {
            return SCNGeometry()
        }

        // ========================================================
        // GEOMETRY
        // ========================================================

        let source =
            SCNGeometrySource(
                vertices:
                    vertices
            )

        let element =
            SCNGeometryElement(
                indices:
                    indices,
                primitiveType:
                    .line
            )

        let geometry =
            SCNGeometry(
                sources:
                    [
                        source
                    ],
                elements:
                    [
                        element
                    ]
            )

        // ========================================================
        // MATERIAL
        // ========================================================

        let material =
            SCNMaterial()

        material.diffuse.contents =
            color

        material.emission.contents =
            color

        material.isDoubleSided =
            true

        geometry.materials =
            [
                material
            ]

        return geometry
    }

    // ============================================================
    // PROJECTED GALAXY
    // ============================================================

    private func makeProjectionNode(
        positions:
            [SIMD3<Double>],
        color:
            UIColor
    )
        -> SCNNode
    {

        let parent =
            SCNNode()

        let radius =
            max(
                0.012,
                Double(extent)
                /
                Double(gridSize)
                *
                0.55
            )

        // ========================================================
        // CREATE PROJECTED STARS
        // ========================================================

        for position in positions {

            let sphere =
                SCNSphere(
                    radius:
                        radius
                )

            let material =
                SCNMaterial()

            material.diffuse.contents =
                color

            material.emission.contents =
                color

            material.isDoubleSided =
                true

            sphere.materials =
                [
                    material
                ]

            let node =
                SCNNode(
                    geometry:
                        sphere
                )

            node.position =
                SCNVector3(
                    Float(
                        position.x
                    ),
                    Float(
                        position.y
                    ),
                    Float(
                        position.z
                    )
                )

            parent.addChildNode(
                node
            )
        }

        return parent
    }

    // ============================================================
    // CAMERA
    // ============================================================

    func makeCameraNode()
        -> SCNNode
    {

        let cameraNode =
            SCNNode()

        let camera =
            SCNCamera()

        camera.zNear =
            0.001

        camera.zFar =
            Double(
                extent
            )
            *
            20.0

        cameraNode.camera =
            camera

        cameraNode.position =
            SCNVector3(
                0.0,
                extent *
                    0.7,
                extent *
                    2.3
            )

        cameraNode.eulerAngles =
            SCNVector3(
                -0.38,
                0.0,
                0.0
            )

        return cameraNode
    }

    // ============================================================
    // VISIBILITY
    // ============================================================

    func setPhotonPathsVisible(
        _ visible:
            Bool
    ) {

        photonANode?.isHidden =
            !visible

        photonBNode?.isHidden =
            !visible
    }

    // ============================================================
    // VISIBILITY — SURFACE
    // ============================================================

    func setSurfaceVisible(
        _ visible:
            Bool
    ) {

        surfaceNode?.isHidden =
            !visible
    }

    // ============================================================
    // VISIBILITY — GALAXY A
    // ============================================================

    func setGalaxyAVisible(
        _ visible:
            Bool
    ) {

        galaxyANode?.isHidden =
            !visible
    }

    // ============================================================
    // VISIBILITY — GALAXY B
    // ============================================================

    func setGalaxyBVisible(
        _ visible:
            Bool
    ) {

        galaxyBNode?.isHidden =
            !visible
    }

    // ============================================================
    // REMOVE PHOTON PATHS
    // ============================================================

    func removePhotonPaths() {

        photonANode?.removeFromParentNode()

        photonBNode?.removeFromParentNode()

        photonANode =
            nil

        photonBNode =
            nil
    }

    // ============================================================
    // REMOVE PROJECTED GALAXIES
    // ============================================================

    func removeProjectedGalaxies() {

        galaxyANode?.removeFromParentNode()

        galaxyBNode?.removeFromParentNode()

        galaxyANode =
            nil

        galaxyBNode =
            nil
    }

    // ============================================================
    // REMOVE SURFACE
    // ============================================================

    func removeSurface() {

        surfaceNode?.removeFromParentNode()

        surfaceNode =
            nil
    }

    // ============================================================
    // REBUILD
    // ============================================================

    func rebuild() {

        buildScene()
    }

    // ============================================================
    // REBUILD PHOTON / GALAXY OUTPUT
    //
    // Useful if the field itself has not changed but the visual
    // photon/galaxy representation needs to be regenerated.
    // ============================================================

    func rebuildPhotonProjection() {

        // --------------------------------------------------------
        // REMOVE OLD PHOTON NODES
        // --------------------------------------------------------

        photonANode?.removeFromParentNode()

        photonBNode?.removeFromParentNode()

        galaxyANode?.removeFromParentNode()

        galaxyBNode?.removeFromParentNode()

        photonANode =
            nil

        photonBNode =
            nil

        galaxyANode =
            nil

        galaxyBNode =
            nil

        // --------------------------------------------------------
        // RECOMPUTE
        // --------------------------------------------------------

        computeGalaxyProjections()

        // --------------------------------------------------------
        // PHOTON A
        // --------------------------------------------------------

        let photonAGeometry =
            makePhotonGeometry(
                paths:
                    photonPathsA,
                color:
                    .cyan
            )

        let photonA =
            SCNNode(
                geometry:
                    photonAGeometry
            )

        photonANode =
            photonA

        addChildNode(
            photonA
        )

        // --------------------------------------------------------
        // PHOTON B
        // --------------------------------------------------------

        let photonBGeometry =
            makePhotonGeometry(
                paths:
                    photonPathsB,
                color:
                    .magenta
            )

        let photonB =
            SCNNode(
                geometry:
                    photonBGeometry
            )

        photonBNode =
            photonB

        addChildNode(
            photonB
        )

        // --------------------------------------------------------
        // GALAXY A
        // --------------------------------------------------------

        let galaxyA =
            makeProjectionNode(
                positions:
                    galaxyAProjectionPositions,
                color:
                    .cyan
            )

        galaxyANode =
            galaxyA

        addChildNode(
            galaxyA
        )

        // --------------------------------------------------------
        // GALAXY B
        // --------------------------------------------------------

        let galaxyB =
            makeProjectionNode(
                positions:
                    galaxyBProjectionPositions,
                color:
                    .magenta
            )

        galaxyBNode =
            galaxyB

        addChildNode(
            galaxyB
        )
    }
}
