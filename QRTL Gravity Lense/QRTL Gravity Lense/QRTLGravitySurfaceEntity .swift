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

    private let lensingParameters =
        LensingParameters()

    // ============================================================
    // INITIALIZATION
    // ============================================================

    init(
        field: QRTLField,
        gridSize: Int = 64,
        extent: Float = 2.0,
        numberOfStars: Int = 220
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
    //
    // The gravity visualization is now a FLAT circular plane.
    //
    // The plane is visualization only.
    //
    // It does NOT:
    //
    // - bend photons
    // - modify photon coordinates
    // - act as spacetime
    // - generate photon trajectories
    //
    // QRTLPhotonTracer remains the sole authority for photon
    // propagation.
    //
    // ============================================================

    func buildScene(
        lensingParameters: LensingParameters
    ) {

        clearScene()

        // --------------------------------------------------------
        // FLAT CIRCULAR VISUALIZATION PLANE
        // --------------------------------------------------------

        let surface = makeFlatCircularPlane()

        surfaceNode = surface

        addChildNode(
            surface
        )

        // --------------------------------------------------------
        // PHOTONS AND PROJECTION RESULTS
        //
        // Added later through:
        //
        // setPhotonPathsForDisplay(...)
        // --------------------------------------------------------
    }

    // ============================================================
    // FLAT CIRCULAR PLANE
    // ============================================================
    //
    // This replaces the former radial gravity bowl.
    //
    // The plane remains geometrically flat.
    //
    // The QRTL field is represented by the photon trajectories
    // and projection results rather than by deforming this plane.
    //
    // ============================================================

    private func makeFlatCircularPlane() -> SCNNode {

        let node = SCNNode()

        let geometry = SCNCylinder(
            radius: CGFloat(extent),
            height: 0.001
        )

        let material = SCNMaterial()

        material.diffuse.contents =
            UIColor.systemGreen.withAlphaComponent(
                0.30
            )

        material.emission.contents =
            UIColor.systemGreen.withAlphaComponent(
                0.05
            )

        material.specular.contents =
            UIColor.white.withAlphaComponent(
                0.15
            )

        material.isDoubleSided = true

        material.transparency = 0.82

        material.lightingModel =
            .physicallyBased

        geometry.materials = [
            material
        ]

        node.geometry = geometry

        // SCNCylinder is vertical by default.
        //
        // Rotate it so the circular surface lies in
        // the X-Z plane.

        node.eulerAngles = SCNVector3(
            Float.pi / 2.0,
            0.0,
            0.0
        )

        node.position = SCNVector3(
            0.0,
            0.0,
            0.0
        )

        return node
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
    // PHOTON PIPELINE
    // ============================================================
    //
    // Visualization only.
    //
    // The paths MUST already have been calculated by
    // QRTLPhotonTracer.
    //
    // This class does NOT:
    //
    // - calculate gravity
    // - calculate potential
    // - calculate photon deflection
    // - modify photon paths
    // - add surface curvature
    //
    // ============================================================

    func setPhotonPathsForDisplay(
        _ paths: [[SIMD3<Float>]],
        projectionHits: [SIMD3<Float>] = []
    ) {

        photonPaths = paths.map { path in

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

        // --------------------------------------------------------
        // REMOVE PREVIOUS PHOTON GRAPHICS
        // --------------------------------------------------------

        photonNode?.removeFromParentNode()

        galaxyNode?.removeFromParentNode()

        // --------------------------------------------------------
        // PHOTON PATHS
        // --------------------------------------------------------

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

        // --------------------------------------------------------
        // PROJECTED GALAXY
        // --------------------------------------------------------

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
    //
    // CRITICAL:
    //
    // The photon path is rendered exactly as returned by
    // QRTLPhotonTracer.
    //
    // NO surfaceHeight()
    //
    // NO gravity-bowl displacement.
    //
    // NO additional curvature.
    //
    // NO coordinate modification.
    //
    // ============================================================

    private func makeTravelingPhotonParticles(
        paths: [[SIMD3<Double>]],
        color: UIColor
    ) -> SCNNode {

        let parent =
            SCNNode()

        // --------------------------------------------------------
        // PHOTON VISUAL SIZE
        // --------------------------------------------------------

        let particleRadius =
            max(
                0.008,
                Double(extent) /
                Double(gridSize) *
                0.35
            )

        // --------------------------------------------------------
        // ANIMATION SPEED
        // --------------------------------------------------------

        let secondsPerPoint =
            0.012

        // --------------------------------------------------------
        // EACH PHOTON PATH
        // --------------------------------------------------------

        for path in paths {

            guard path.count > 1
            else {
                continue
            }

            // ----------------------------------------------------
            // REMOVE INVALID TRACE POINTS
            // ----------------------------------------------------

            let validPoints =
                path.filter {

                    $0.x.isFinite &&
                    $0.y.isFinite &&
                    $0.z.isFinite
                }

            guard validPoints.count > 1
            else {
                continue
            }

            // ----------------------------------------------------
            // PHOTON SPHERE
            // ----------------------------------------------------

            let sphere =
                SCNSphere(
                    radius:
                        CGFloat(
                            particleRadius
                        )
                )

            let material =
                SCNMaterial()

            material.diffuse.contents =
                color

            material.emission.contents =
                color

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
            //
            // IMPORTANT:
            //
            // These coordinates must already be in SceneKit
            // coordinates when supplied by QRTLPhotonTracer.
            //
            // This renderer does NOT convert or deform them.
            //
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

                moves.append(
                    moveAction
                )
            }

            guard !moves.isEmpty
            else {
                continue
            }

            // ----------------------------------------------------
            // TRAVEL
            // ----------------------------------------------------

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
    //
    // These positions come from the authoritative photon
    // projection results.
    //
    // No additional lensing calculation occurs here.
    //
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

            // ----------------------------------------------------
            // PROJECTED STAR
            // ----------------------------------------------------

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

            // ----------------------------------------------------
            // PROJECTION POSITION
            // ----------------------------------------------------

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
