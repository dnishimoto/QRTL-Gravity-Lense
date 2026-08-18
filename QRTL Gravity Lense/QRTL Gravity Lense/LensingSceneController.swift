//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/17/26.
//

import Foundation
import SwiftUI
import SceneKit
import Combine

final class LensingSceneController:
    ObservableObject {
    
    private(set) var values: [Float]
    
    let resolution: Int
    
    var maximumValue: Float {
        values.max() ?? 0.0
    }

    let clusterSceneRadius: Double = 0.75
    
    private var globularClusterNode: SCNNode?
    
    let scene =
        SCNScene()

    private var pathNodes:
        [SCNNode] =
        []

    private var sourceGalaxyNodes:
        [SCNNode] =
        []

    private var massNode:
        SCNNode?

    private var frontPlaneNode:
        SCNNode?

    private var bottomPlaneNode:
        SCNNode?

    private var photonPathNodes:
        [SCNNode] =
        []
    let sourceX: Float = -6.0
    let lensX: Float = 0.0
    let frontPlaneX: Float = 10.0

    let bottomY: Float = -5.0

    // Make the target substantially larger.
    let planeHalfExtent: Float = 8.0
    let heatmapHalfExtent: Float = 5.0
   

    // ========================================================
    // PHYSICAL LENSING DISTANCE
    //
    // These are deliberately separated from the visual scene.
    //
    // The compact SceneKit scene represents the geometry,
    // while the physics can use much larger distances.
    // ========================================================

    let physicalSourceDistance:
        Double =
        10.0 *
        PhysicalConstants.solarRadius

    let physicalObserverDistance:
        Double =
        10.0 *
        PhysicalConstants.solarRadius

    var sourcePhysicalX:
        Double {

        -physicalSourceDistance
    }

    var frontPlanePhysicalX:
        Double {

        physicalObserverDistance
    }

    var totalPhysicalDistance:
        Double {

        physicalObserverDistance +
        physicalSourceDistance
    }
    private var projectionAccumulator =
        LensingProjectionAccumulator()

    private let accumulator: ProjectionAccumulator
    
    private var projectionNode: SCNNode?
    private var projectionNodes: [SCNNode] = []
    var photons: [PhotonTraceResult] = []
    

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init(resolution: Int = 128) {
        self.resolution = resolution
        self.values = Array(repeating: 0.0, count: resolution * resolution)

        self.accumulator = ProjectionAccumulator(
            resolution: resolution,
            halfExtent: Double(planeHalfExtent)   // use the same units as the scene
        )

        setupCameraLights()
        addAxes()
        addBottomPlaceholder()
        addFrontProjectionPlane(empty: true)      // ← create it immediately
    }
    // =============================================================
    // REMOVE PREVIOUS PROJECTION
    // =============================================================
    //
    // Removes only the previously rendered projection.
    // It does not remove:
    //   - source galaxy
    //   - globular cluster
    //   - photon paths
    //   - lensing field
    //
    // =============================================================

    func removePreviousProjection() {

        // ---------------------------------------------------------
        // Remove previous projection container
        // ---------------------------------------------------------

        projectionNode?.removeFromParentNode()
        projectionNode = nil


        // ---------------------------------------------------------
        // Remove any individually rendered projection nodes
        // ---------------------------------------------------------

        for node in projectionNodes {

            node.removeFromParentNode()
        }

        projectionNodes.removeAll(
            keepingCapacity: true
        )


        // ---------------------------------------------------------
        // Clear accumulated projection data
        // ---------------------------------------------------------

        projectionAccumulator.reset()
    }
    private func projectionPlaneIntersection(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        parameters: LensingParameters
    ) -> SIMD3<Float>? {

        // =========================================================
        // PROJECTION PLANE
        //
        // The front projection plane is perpendicular to Z.
        //
        // Plane equation:
        //
        //     z = projectionDistance
        //
        // =========================================================

        let planeZ =
            parameters.projectionDistance

        let planeHalfExtent =
            parameters.projectionPlaneHalfExtent


        // =========================================================
        // VALIDATE PARAMETERS
        // =========================================================

        guard planeZ.isFinite,
              planeHalfExtent.isFinite,
              planeHalfExtent > 0.0
        else {
            return nil
        }


        // =========================================================
        // VALIDATE PHOTON POSITIONS
        // =========================================================

        guard start.x.isFinite,
              start.y.isFinite,
              start.z.isFinite,
              end.x.isFinite,
              end.y.isFinite,
              end.z.isFinite
        else {
            return nil
        }


        // =========================================================
        // DISTANCE FROM PLANE
        // =========================================================

        let startDistance =
            start.z - planeZ

        let endDistance =
            end.z - planeZ


        // =========================================================
        // EPSILON
        // =========================================================

        let epsilon: Float =
            0.000001


        // =========================================================
        // PHOTON STARTED ON THE PLANE
        // =========================================================

        if abs(startDistance) <= epsilon {

            let hit =
                start

            guard abs(hit.x) <= planeHalfExtent,
                  abs(hit.y) <= planeHalfExtent
            else {
                return nil
            }

            var result =
                hit

            result.z =
                planeZ

            return result
        }


        // =========================================================
        // PHOTON DID NOT CROSS THE PLANE
        // =========================================================

        if startDistance * endDistance > 0.0 {
            return nil
        }


        // =========================================================
        // LINE-PLANE INTERSECTION
        //
        // Photon path:
        //
        //     P(t) = start + t(end - start)
        //
        // Solve:
        //
        //     P.z = planeZ
        //
        // =========================================================

        let denominator =
            end.z - start.z

        guard abs(denominator) > epsilon
        else {
            return nil
        }


        // =========================================================
        // INTERSECTION PARAMETER
        // =========================================================

        let t =
            (planeZ - start.z) /
            denominator

        guard t.isFinite,
              t >= 0.0,
              t <= 1.0
        else {
            return nil
        }


        // =========================================================
        // CALCULATE INTERSECTION
        // =========================================================

        let intersection =
            start +
            (end - start) * t


        // =========================================================
        // VALIDATE INTERSECTION
        // =========================================================

        guard intersection.x.isFinite,
              intersection.y.isFinite,
              intersection.z.isFinite
        else {
            return nil
        }


        // =========================================================
        // CHECK PROJECTION PLANE BOUNDS
        //
        // The hit must actually land on the visible plane.
        // =========================================================

        guard abs(intersection.x) <=
                planeHalfExtent,
              abs(intersection.y) <=
                planeHalfExtent
        else {
            return nil
        }


        // =========================================================
        // FORCE EXACT Z POSITION
        //
        // Eliminates floating-point drift.
        // =========================================================

        var hit =
            intersection

        hit.z =
            planeZ

        return hit
    }
    func tracePhoton(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        field: QRTLField,
        parameters: LensingParameters
    ) -> PhotonTraceResult {

        // =========================================================
        // INITIALIZE PHOTON
        // =========================================================

        var position = origin

        var photonDirection =
            simd_normalize(direction)

        guard photonDirection.x.isFinite,
              photonDirection.y.isFinite,
              photonDirection.z.isFinite
        else {
            return PhotonTraceResult(
                origin: origin,
                direction: direction,
                positions: [origin],
                finalPosition: origin,
                finalDirection: .zero,
                hitProjection: false,
                projectionPosition: nil,
                totalDeflection: 0.0,
                maximumQRTLInfluence: 0.0,
                maximumMagneticField: 0.0,
                maximumMagneticPhotonInfluence: 0.0,
                traveledDistance: 0.0,
                stepCount: 0,
                terminated: true
            )
        }

        var positions: [SIMD3<Float>] = []

        positions.reserveCapacity(
            parameters.maximumPhotonSteps + 1
        )

        positions.append(position)

        var totalDeflection: Float = 0.0

        var maximumMagneticInfluence: Float = 0.0

        var hitProjection = false

        var projectionPosition: SIMD3<Float>? = nil

        var terminated = false


        // =========================================================
        // PHOTON PROPAGATION
        // =========================================================

        for _ in 0..<parameters.maximumPhotonSteps {

            // -----------------------------------------------------
            // CURRENT STATE
            // -----------------------------------------------------

            let previousPosition =
                position

            let previousDirection =
                photonDirection


            // =====================================================
            // SAMPLE COMPLETE QRTL FIELD
            // =====================================================

            let sample =
                field.sample(
                    at: position
                )

            let totalIndex =
                sample.totalIndex

            guard totalIndex.isFinite,
                  totalIndex > 0.000001
            else {
                terminated = true
                break
            }


            // =====================================================
            // MAGNETIC / EM INFLUENCE
            //
            // Diagnostic only.
            //
            // The actual bending is produced by the gradient of
            // the total optical index.
            // =====================================================

            let magneticInfluence =
                field.electromagneticInfluence(
                    at: position
                )

            let magneticMagnitude =
                simd_length(
                    magneticInfluence
                )

            if magneticMagnitude.isFinite {

                maximumMagneticInfluence =
                    max(
                        maximumMagneticInfluence,
                        magneticMagnitude
                    )
            }


            // =====================================================
            // TOTAL INDEX GRADIENT
            // =====================================================

            let gradient =
                field.indexGradient(
                    at: position
                )

            guard gradient.x.isFinite,
                  gradient.y.isFinite,
                  gradient.z.isFinite
            else {
                terminated = true
                break
            }


            // =====================================================
            // TRANSVERSE GRADIENT
            //
            // Only the component perpendicular to the photon
            // direction changes the trajectory.
            // =====================================================

            let longitudinal =
                simd_dot(
                    gradient,
                    photonDirection
                )

            let transverseGradient =
                gradient -
                photonDirection *
                longitudinal


            // =====================================================
            // OPTICAL INDEX BENDING
            // =====================================================

            let indexBending =
                transverseGradient /
                max(
                    totalIndex,
                    0.000001
                )

            guard indexBending.x.isFinite,
                  indexBending.y.isFinite,
                  indexBending.z.isFinite
            else {
                terminated = true
                break
            }


            // =====================================================
            // DEFLECTION STRENGTH
            // =====================================================

            let directionChange =
                indexBending *
                parameters.deflectionStrength


            // =====================================================
            // PHOTON STEP SIZE
            // =====================================================

            let step =
                parameters.photonStepSize

            guard step.isFinite,
                  step > 0.0
            else {
                terminated = true
                break
            }


            // =====================================================
            // UPDATE PHOTON DIRECTION
            // =====================================================

            var nextDirection =
                photonDirection +
                directionChange *
                step

            guard nextDirection.x.isFinite,
                  nextDirection.y.isFinite,
                  nextDirection.z.isFinite
            else {
                terminated = true
                break
            }

            let directionLength =
                simd_length(
                    nextDirection
                )

            guard directionLength.isFinite,
                  directionLength > 0.000001
            else {
                terminated = true
                break
            }

            nextDirection =
                nextDirection /
                directionLength


            // =====================================================
            // CALCULATE NEXT POSITION
            // =====================================================

            let nextPosition =
                position +
                nextDirection *
                step

            guard nextPosition.x.isFinite,
                  nextPosition.y.isFinite,
                  nextPosition.z.isFinite
            else {
                terminated = true
                break
            }


            // =====================================================
            // PROJECTION PLANE INTERSECTION
            //
            // FIRST VALID INTERSECTION WINS.
            //
            // Once the photon reaches the projection plane,
            // terminate this photon immediately.
            // =====================================================

            if let intersection =
                projectionPlaneIntersection(
                    from: previousPosition,
                    to: nextPosition,
                    parameters: parameters
                ) {

                position =
                    intersection

                positions.append(
                    intersection
                )

                projectionPosition =
                    intersection

                hitProjection =
                    true

                terminated =
                    true

                // -------------------------------------------------
                // CRITICAL:
                // Do not continue this photon after projection.
                // -------------------------------------------------

                break
            }


            // =====================================================
            // UPDATE PHOTON STATE
            // =====================================================

            photonDirection =
                nextDirection

            position =
                nextPosition


            // =====================================================
            // RECORD PHOTON PATH
            // =====================================================

            positions.append(
                position
            )


            // =====================================================
            // ACCUMULATE DEFLECTION ANGLE
            // =====================================================

            let dotProduct =
                simd_dot(
                    previousDirection,
                    photonDirection
                )

            let clampedDot =
                max(
                    -1.0,
                    min(
                        1.0,
                        dotProduct
                    )
                )

            let angle =
                acos(
                    clampedDot
                )

            if angle.isFinite {

                totalDeflection +=
                    angle
            }


            // =====================================================
            // STOP OUTSIDE LENSING VOLUME
            // =====================================================

            let distanceFromOrigin =
                simd_length(
                    position
                )

            if distanceFromOrigin.isFinite,
               distanceFromOrigin >
                    parameters.maximumPropagationRadius {

                terminated =
                    true

                break
            }
        }


        // =========================================================
        // RETURN PHOTON TRACE
        // =========================================================

        return PhotonTraceResult(
            origin: origin,
            direction: direction,
            positions: [origin],
            finalPosition: origin,
            finalDirection: .zero,
            hitProjection: false,
            projectionPosition: nil,
            totalDeflection: 0.0,
            maximumQRTLInfluence: 0.0,
            maximumMagneticField: 0.0,
            maximumMagneticPhotonInfluence: 0.0,
            traveledDistance: 0.0,
            stepCount: 0,
            terminated: true
        )
    }
    func applyProjection(
        _ projection: LensingProjectionResult
    ) {

        // ----------------------------------------------------
        // Clear the image accumulator
        // ----------------------------------------------------

        accumulator.reset()

        // ----------------------------------------------------
        // Add every valid photon-plane intersection
        // ----------------------------------------------------

        for hit in projection.validHits {

            accumulator.addHit(
                y: Double(hit.coordinates.x),
                z: Double(hit.coordinates.y),
                weight: 1.5
            )
        }

        // ----------------------------------------------------
        // Replace the empty front plane with the projection
        // ----------------------------------------------------

        addFrontProjectionPlane(
            empty: false
        )
    }

    private func physicalToScene(
        _ position:
            SIMD3<Double>
    ) -> SCNVector3 {

        let scale =
            PhysicalConstants.solarRadius

        return SCNVector3(
            Float(
                position.x /
                scale
            ),

            Float(
                position.y /
                scale
            ),

            Float(
                position.z /
                scale
            )
        )
    }

    // ========================================================
    // CAMERA / LIGHTING
    // ========================================================

    private func setupCameraLights() {

        let cameraNode =
            SCNNode()

        let camera =
            SCNCamera()

        camera.zNear =
            0.01

        camera.zFar =
            100.0

        camera.fieldOfView =
            55

        cameraNode.camera =
            camera

        cameraNode.position =
            SCNVector3(
                60,
                6,
                0
            )

        cameraNode.look(
            at:
                SCNVector3(
                    0,
                    0,
                    0
                )
        )

        scene.rootNode.addChildNode(
            cameraNode
        )

        let keyNode =
            SCNNode()

        let keyLight =
            SCNLight()

        keyLight.type =
            .omni

        keyLight.intensity =
            1800

        keyLight.attenuationStartDistance =
            5

        keyLight.attenuationEndDistance =
            40

        keyNode.light =
            keyLight

        keyNode.position =
            SCNVector3(
                4,
                8,
                8
            )

        scene.rootNode.addChildNode(
            keyNode
        )

        let ambientNode =
            SCNNode()

        let ambient =
            SCNLight()

        ambient.type =
            .ambient

        ambient.intensity =
            300

        ambientNode.light =
            ambient

        scene.rootNode.addChildNode(
            ambientNode
        )
    }

    // ========================================================
    // AXES
    // ========================================================

    private func addAxes() {

        let length:
            Float =
            8.0

        let definitions:
            [
                (
                    SCNVector3,
                    UIColor
                )
            ] = [

                (
                    SCNVector3(
                        length,
                        0,
                        0
                    ),
                    .systemRed
                ),

                (
                    SCNVector3(
                        0,
                        length,
                        0
                    ),
                    .systemGreen
                ),

                (
                    SCNVector3(
                        0,
                        0,
                        length
                    ),
                    .systemBlue
                )
            ]

        for (
            vector,
            color
        ) in definitions {

            let axisLength =
                sqrt(
                    vector.x *
                    vector.x +
                    vector.y *
                    vector.y +
                    vector.z *
                    vector.z
                )

            let cylinder =
                SCNCylinder(
                    radius:
                        0.015,

                    height:
                        CGFloat(
                            axisLength
                        )
                )

            let material =
                SCNMaterial()

            material.diffuse.contents =
                color

            material.emission.contents =
                color

            material.lightingModel =
                .constant

            cylinder.materials =
                [material]

            let node =
                SCNNode(
                    geometry:
                        cylinder
                )

            node.position =
                SCNVector3(
                    vector.x / 2,
                    vector.y / 2,
                    vector.z / 2
                )

            if abs(vector.x) > 0 {

                node.eulerAngles.z =
                    .pi / 2
            }

            if abs(vector.z) > 0 {

                node.eulerAngles.x =
                    .pi / 2
            }

            scene.rootNode.addChildNode(
                node
            )
        }
    }

    // ========================================================
    // CLEAR
    // ========================================================

    func clearDynamic() {
        pathNodes.forEach { $0.removeFromParentNode() }
        pathNodes.removeAll()

        photonPathNodes.forEach { $0.removeFromParentNode() }
        photonPathNodes.removeAll()

        sourceGalaxyNodes.forEach { $0.removeFromParentNode() }
        sourceGalaxyNodes.removeAll()

        massNode?.removeFromParentNode()
        massNode = nil

        globularClusterNode?.removeFromParentNode()
        globularClusterNode = nil

        bottomPlaneNode?.removeFromParentNode()
        bottomPlaneNode = nil

        // Keep the front plane node variable clean
        frontPlaneNode?.removeFromParentNode()
        frontPlaneNode = nil

        // Remove debug marker if present
        scene.rootNode.childNode(withName: "FrontPlaneMarker", recursively: false)?
            .removeFromParentNode()

        accumulator.reset()
    }

    // ========================================================
    // SOURCE GALAXY
    // ========================================================

    func addSourceGalaxy(
        radius: Double = 0.75,
        nStars: Int = 220
    ) {
        // Remove any previous galaxy
        sourceGalaxyNodes.forEach {
            $0.removeFromParentNode()
        }

        sourceGalaxyNodes.removeAll()

        // Create stars
        for _ in 0..<nStars {

            // Random radial distance
            let r =
                radius *
                pow(
                    Double.random(in: 0.0...1.0),
                    0.7
                )

            // Random angular position
            let theta =
                Double.random(
                    in: 0.0...(2.0 * Double.pi)
                )

            // Spiral-arm modulation
            let arm =
                0.12 *
                sin(
                    2.5 * theta
                )

            // Galaxy Y coordinate
            let y =
                (
                    r +
                    arm * radius
                ) *
                cos(theta)

            // Galaxy Z coordinate
            let z =
                (
                    r +
                    arm * radius
                ) *
                sin(theta)

            // Create star
            let star =
                SCNSphere(
                    radius:
                        CGFloat(
                            Double.random(
                                in: 0.015...0.035
                            )
                        )
                )

            // Star appearance
            let material =
                SCNMaterial()

            material.diffuse.contents =
                UIColor.yellow

            material.emission.contents =
                UIColor.yellow

            material.lightingModel =
                .constant

            star.materials =
                [material]

            // Create node
            let node =
                SCNNode(
                    geometry: star
                )

            // Place galaxy at the source plane
            node.position =
                SCNVector3(
                    sourceX,
                    Float(y),
                    Float(z)
                )

            // Add to SceneKit
            scene.rootNode.addChildNode(
                node
            )

            sourceGalaxyNodes.append(
                node
            )
        }
    }
    func addGlobularCluster(
        radius: Double = 5.0,
        nStars: Int = 3000
    ) {

        // =========================================================
        // CLEAR PREVIOUS CLUSTER
        // =========================================================

        globularClusterNode?.removeFromParentNode()


        // =========================================================
        // CREATE CLUSTER NODE
        // =========================================================

        let clusterNode =
            SCNNode()

        globularClusterNode =
            clusterNode


        // =========================================================
        // CREATE STARS THROUGHOUT SPHERICAL VOLUME
        // =========================================================

        for _ in 0..<nStars {

            // -----------------------------------------------------
            // RANDOM DIRECTION
            // -----------------------------------------------------

            let theta =
                Double.random(
                    in: 0.0...(2.0 * Double.pi)
                )

            let zDirection =
                Double.random(
                    in: -1.0...1.0
                )

            let radialXY =
                sqrt(
                    max(
                        0.0,
                        1.0 -
                        zDirection * zDirection
                    )
                )


            // -----------------------------------------------------
            // UNIFORM VOLUME DISTRIBUTION
            // -----------------------------------------------------

            let radialFraction =
                pow(
                    Double.random(
                        in: 0.0...1.0
                    ),
                    1.0 / 3.0
                )

            let r =
                radius *
                radialFraction


            // -----------------------------------------------------
            // SPHERICAL → CARTESIAN
            // -----------------------------------------------------

            let x =
                r *
                radialXY *
                cos(theta)

            let y =
                r *
                radialXY *
                sin(theta)

            let z =
                r *
                zDirection


            let position =
                SIMD3<Float>(
                    Float(x),
                    Float(y),
                    Float(z)
                )


            // -----------------------------------------------------
            // DISTANCE FROM CENTER
            // -----------------------------------------------------

            let distanceFromCenter =
                r


            // -----------------------------------------------------
            // CORE DENSITY
            // -----------------------------------------------------

            let normalizedRadius =
                radius > 0.0
                ? distanceFromCenter / radius
                : 0.0

            let coreFactor =
                max(
                    0.0,
                    1.0 -
                    normalizedRadius
                )


            // -----------------------------------------------------
            // STAR SIZE
            // -----------------------------------------------------

            let starRadius =
                Float(
                    0.009 +
                    Double.random(
                        in: 0.0...0.012
                    ) +
                    coreFactor * 0.008
                )


            // -----------------------------------------------------
            // CREATE STAR GEOMETRY
            // -----------------------------------------------------

            let starGeometry =
                SCNSphere(
                    radius:
                        CGFloat(
                            starRadius
                        )
                )


            let material =
                SCNMaterial()

            material.diffuse.contents =
                UIColor.white

            material.emission.contents =
                UIColor.white

            material.lightingModel =
                .constant

            starGeometry.firstMaterial =
                material


            // -----------------------------------------------------
            // CREATE STAR NODE
            // -----------------------------------------------------

            let starNode =
                SCNNode(
                    geometry:
                        starGeometry
                )

            starNode.position =
                SCNVector3(
                    position.x,
                    position.y,
                    position.z
                )


            clusterNode.addChildNode(
                starNode
            )
        }


        // =========================================================
        // ADD CLUSTER TO SCENE
        // =========================================================

        scene.rootNode.addChildNode(
            clusterNode
        )
    }

    // ========================================================
    // FRONT PROJECTION PLANE
    // ========================================================

    // Constants on LensingSceneController:
    // let frontPlaneX: Float = 8
    // let bottomY: Float = -4
    // let planeHalfExtent: Float = 6
    // let heatmapHalfExtent: Float = 7

    func addFrontProjectionPlane(empty: Bool) {
        frontPlaneNode?.removeFromParentNode()

        let size = CGFloat(planeHalfExtent * 2)
        let plane = SCNPlane(width: size, height: size)
        let mat = SCNMaterial()
        mat.isDoubleSided = true
        mat.lightingModel = .constant

        if empty {
            mat.diffuse.contents = UIColor.cyan.withAlphaComponent(0.4)
            mat.emission.contents = UIColor.cyan.withAlphaComponent(0.25)
        } else {
            let img = accumulator.makeImage()
            mat.diffuse.contents = img
            mat.emission.contents = img
        }
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(frontPlaneX, 0, 0)
        node.eulerAngles.y = .pi / 2
        node.name = "FrontProjectionPlane"
        scene.rootNode.addChildNode(node)
        frontPlaneNode = node
    }

    func updateBottomHeatmap(field: QRTLField) {
        bottomPlaneNode?.removeFromParentNode()

        let image = QRTLHeatmapGenerator.makeHeatmapImage(
            field: field,
            size: 128,
            halfExtent: Double(heatmapHalfExtent)   // scene units only
        )

        let size = CGFloat(heatmapHalfExtent * 2)
        let plane = SCNPlane(width: size, height: size)
        let mat = SCNMaterial()
        mat.isDoubleSided = true
        mat.lightingModel = .constant
        mat.diffuse.contents = image
        mat.emission.contents = image
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(frontPlaneX * 0.5, bottomY, 0)
        node.eulerAngles.x = -.pi / 2
        node.name = "HeatmapPlane"
        scene.rootNode.addChildNode(node)
        bottomPlaneNode = node
    }
    private func makeSolidImage(color: UIColor) -> UIImage {
        let res = resolution
        UIGraphicsBeginImageContextWithOptions(CGSize(width: res, height: res), false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return UIImage() }
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: res, height: res))
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }

    // ========================================================
    // BOTTOM PLACEHOLDER
    // ========================================================

    func addBottomPlaceholder() {

        bottomPlaneNode?.removeFromParentNode()

        let size =
            heatmapHalfExtent *
            2.0

        let plane =
            SCNPlane(
                width:
                    CGFloat(size),

                height:
                    CGFloat(size)
            )

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor(
                white:
                    0.07,

                alpha:
                    0.9
            )

        material.emission.contents =
            UIColor(
                white:
                    0.02,

                alpha:
                    0.4
            )

        material.isDoubleSided =
            true

        plane.materials =
            [material]

        let node =
            SCNNode(
                geometry:
                    plane
            )

        node.position =
            SCNVector3(
                0,
                bottomY,
                0
            )

        node.eulerAngles.x =
            -.pi / 2

        scene.rootNode.addChildNode(
            node
        )

        bottomPlaneNode =
            node
    }

  
    // ========================================================
    // LENS MASS
    // ========================================================

    func addCluster(
        radius: Double,
        nStars: Int = 3000
    ) {

        // =========================================================
        // REMOVE PREVIOUS CLUSTER
        // =========================================================

        globularClusterNode?.removeFromParentNode()

        let clusterNode =
            SCNNode()

        globularClusterNode =
            clusterNode


        // =========================================================
        // CREATE STARS THROUGHOUT SPHERICAL VOLUME
        // =========================================================

        for _ in 0..<nStars {

            // -----------------------------------------------------
            // UNIFORM RANDOM DIRECTION
            // -----------------------------------------------------

            let theta =
                Double.random(
                    in: 0.0...(2.0 * Double.pi)
                )

            let phi =
                acos(
                    Double.random(
                        in: -1.0...1.0
                    )
                )


            // -----------------------------------------------------
            // UNIFORM VOLUME DISTRIBUTION
            //
            // Cube-root distribution prevents stars from being
            // concentrated toward the center.
            // -----------------------------------------------------

            let radialFraction =
                pow(
                    Double.random(
                        in: 0.0...1.0
                    ),
                    1.0 / 3.0
                )

            let r =
                radius *
                radialFraction


            // -----------------------------------------------------
            // SPHERICAL → CARTESIAN
            // -----------------------------------------------------

            let sinPhi =
                sin(phi)

            let x =
                r *
                sinPhi *
                cos(theta)

            let y =
                r *
                sinPhi *
                sin(theta)

            let z =
                r *
                cos(phi)


            // -----------------------------------------------------
            // STAR SIZE
            // -----------------------------------------------------

            let starRadius =
                0.006 +
                Double.random(
                    in: 0.0...0.010
                )


            // -----------------------------------------------------
            // STAR GEOMETRY
            // -----------------------------------------------------

            let star =
                SCNSphere(
                    radius:
                        CGFloat(
                            starRadius
                        )
                )


            let material =
                SCNMaterial()

            material.diffuse.contents =
                UIColor.white

            material.emission.contents =
                UIColor.white

            material.lightingModel =
                .constant

            star.firstMaterial =
                material


            // -----------------------------------------------------
            // STAR NODE
            // -----------------------------------------------------

            let starNode =
                SCNNode(
                    geometry:
                        star
                )

            starNode.position =
                SCNVector3(
                    x,
                    y,
                    z
                )


            clusterNode.addChildNode(
                starNode
            )
        }


        // =========================================================
        // ADD CLUSTER TO SCENE
        // =========================================================

        scene.rootNode.addChildNode(
            clusterNode
        )
    }

    // ========================================================
    // CYLINDER BETWEEN TWO SCENE POINTS
    //
    // This replaces the invalid SCNGeometryElement.lineWidth
    // approach.
    // ========================================================

    private func makeTubeSegment(
        from:
            SCNVector3,

        to:
            SCNVector3,

        radius:
            CGFloat,

        color:
            UIColor
    ) -> SCNNode {

        let start =
            SIMD3<Float>(
                from.x,
                from.y,
                from.z
            )

        let end =
            SIMD3<Float>(
                to.x,
                to.y,
                to.z
            )

        let delta =
            end -
            start

        let length =
            simd_length(
                delta
            )

        guard length >
                1.0e-6
        else {
            return SCNNode()
        }

        let cylinder =
            SCNCylinder(
                radius:
                    radius,

                height:
                    CGFloat(
                        length
                    )
            )

        let material =
            SCNMaterial()

        material.diffuse.contents =
            color

        material.emission.contents =
            color

        material.lightingModel =
            .constant

        cylinder.materials =
            [material]

        let node =
            SCNNode(
                geometry:
                    cylinder
            )

        node.position =
            SCNVector3(
                (
                    from.x +
                    to.x
                ) * 0.5,

                (
                    from.y +
                    to.y
                ) * 0.5,

                (
                    from.z +
                    to.z
                ) * 0.5
            )

        // SCNCylinder's local Y axis is its length axis.
        let direction =
            simd_normalize(
                delta
            )

        let up =
            SIMD3<Float>(
                0,
                1,
                0
            )

        let dot =
            simd_dot(
                up,
                direction
            )

        if dot > 0.9999 {

            node.simdOrientation =
                simd_quatf(
                    angle:
                        0,

                    axis:
                        SIMD3<Float>(
                            1,
                            0,
                            0
                        )
                )

        } else if dot < -0.9999 {

            node.simdOrientation =
                simd_quatf(
                    angle:
                        .pi,

                    axis:
                        SIMD3<Float>(
                            1,
                            0,
                            0
                        )
                )

        } else {

            let axis =
                simd_normalize(
                    simd_cross(
                        up,
                        direction
                    )
                )

            let angle =
                acos(
                    clamped(
                        Double(dot),
                        minimum:
                            -1,
                        maximum:
                            1
                    )
                )

            node.simdOrientation =
                simd_quatf(
                    angle:
                        Float(angle),

                    axis:
                        axis
                )
        }

        return node
    }

    // ========================================================
    // SMOOTH PHOTON PATH
    //
    // Catmull-Rom -> dense points -> cylindrical segments.
    // ========================================================

    @discardableResult
    func addSplinePhotonPath(
        controlPoints:
            [SIMD3<Double>],

        color:
            UIColor = .cyan,

        radius:
            CGFloat = 0.018,

        pointsPerSegment:
            Int = 6
    ) -> SCNNode? {

        guard controlPoints.count >= 2
        else {
            return nil
        }

        let physicalPoints =
            CatmullRomSpline.interpolate(
                points:
                    controlPoints,

                pointsPerSegment:
                    pointsPerSegment
            )

        guard physicalPoints.count >= 2
        else {
            return nil
        }

        let root =
            SCNNode()

        root.name =
            "PhotonSpline"

        let scenePoints =
            physicalPoints.map {
                physicalToScene($0)
            }

        for i in 0..<(scenePoints.count - 1) {

            let segment =
                makeTubeSegment(
                    from:
                        scenePoints[i],

                    to:
                        scenePoints[i + 1],

                    radius:
                        radius,

                    color:
                        color
                )

            root.addChildNode(
                segment
            )
        }

        scene.rootNode.addChildNode(
            root
        )

        photonPathNodes.append(
            root
        )

        return root
    }
    func renderPhotonPath(
        _ path: [SIMD3<Float>]
    ) {

        // ---------------------------------------------------------
        // VALIDATE PATH
        // ---------------------------------------------------------

        guard path.count >= 2 else {
            return
        }


        // ---------------------------------------------------------
        // CONVERT PHOTON PATH TO SCNVECTOR3
        // ---------------------------------------------------------

        let points =
            path.map {
                SCNVector3(
                    x: $0.x,
                    y: $0.y,
                    z: $0.z
                )
            }


        // ---------------------------------------------------------
        // CREATE SOURCE DATA
        // ---------------------------------------------------------

        let source =
            SCNGeometrySource(
                vertices:
                    points
            )


        // ---------------------------------------------------------
        // CREATE LINE INDICES
        // ---------------------------------------------------------

        var indices:
            [Int32] = []

        indices.reserveCapacity(
            (points.count - 1) * 2
        )


        for index in 0..<(points.count - 1) {

            indices.append(
                Int32(index)
            )

            indices.append(
                Int32(index + 1)
            )
        }


        // ---------------------------------------------------------
        // CREATE GEOMETRY ELEMENT
        // ---------------------------------------------------------

        let element =
            SCNGeometryElement(
                indices:
                    indices,

                primitiveType:
                    .line
            )


        // ---------------------------------------------------------
        // CREATE GEOMETRY
        // ---------------------------------------------------------

        let geometry =
            SCNGeometry(
                sources:
                    [source],

                elements:
                    [element]
            )


        // ---------------------------------------------------------
        // MATERIAL
        // ---------------------------------------------------------

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor.white.withAlphaComponent(0.1)

        material.emission.contents =
            UIColor.white.withAlphaComponent(0.1)

        material.lightingModel =
            .constant

        material.isDoubleSided =
            true

        geometry.firstMaterial =
            material


        // ---------------------------------------------------------
        // CREATE NODE
        // ---------------------------------------------------------

        let node =
            SCNNode(
                geometry:
                    geometry
            )


        // ---------------------------------------------------------
        // ADD TO PHOTON PATH COLLECTION
        // ---------------------------------------------------------

        photonPathNodes.append(
            node
        )


        // ---------------------------------------------------------
        // ADD TO SCENE
        // ---------------------------------------------------------

        scene.rootNode.addChildNode(
            node
        )
    }
    

    func addPhotonPath(
        _ points:
            [SIMD3<Double>]
    ) {

        guard points.count > 1
        else {
            return
        }

        let controlPoints =
            points

        addSplinePhotonPath(
            controlPoints:
                controlPoints,

            color:
                .cyan,

            radius:
                0.008,

            pointsPerSegment:
                2
        )
    }
}

