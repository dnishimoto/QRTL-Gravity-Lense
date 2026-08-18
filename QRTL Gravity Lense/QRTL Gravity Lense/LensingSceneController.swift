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
    
    private var projectionPlaneNode: SCNNode?
    
    private let photonPathRoot =
        SCNNode()
   

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
    
    private var sourceGalaxyNode:
        SCNNode?

    var sourceGalaxyStars:
        [SourceGalaxyStar] = []
    

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init(resolution: Int = 128) {
        self.resolution = resolution
        self.values = Array(
            repeating: 0.0,
            count: resolution * resolution
        )

        self.accumulator = ProjectionAccumulator(
            resolution: resolution,
            halfExtent: Double(planeHalfExtent)
        )

        setupCameraLights()
        addAxes()
        addBottomPlaceholder()
        addFrontProjectionPlane(empty: true)
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
        // Photons travel primarily along +X.
        //
        // Therefore:
        //
        //     X = projectionDistance
        //
        // Y and Z become the 2D projection coordinates.
        // =========================================================

        let planeX =
            parameters.projectionDistance

        let planeHalfExtent =
            parameters.projectionPlaneHalfExtent

        // =========================================================
        // VALIDATE PARAMETERS
        // =========================================================

        guard planeX.isFinite,
              planeHalfExtent.isFinite,
              planeHalfExtent > 0.0
        else {
            return nil
        }

        // =========================================================
        // VALIDATE POSITIONS
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
        // DISTANCE FROM X PLANE
        // =========================================================

        let startDistance =
            start.x - planeX

        let endDistance =
            end.x - planeX

        let epsilon:
            Float = 0.000001

        // =========================================================
        // STARTED ON PLANE
        // =========================================================

        if abs(startDistance) <= epsilon {

            guard abs(start.y) <= planeHalfExtent,
                  abs(start.z) <= planeHalfExtent
            else {
                return nil
            }

            var hit =
                start

            hit.x =
                planeX

            return hit
        }

        // =========================================================
        // DID NOT CROSS PLANE
        // =========================================================

        if startDistance * endDistance > 0.0 {
            return nil
        }

        // =========================================================
        // LINE-PLANE INTERSECTION
        //
        // P(t) = start + t(end - start)
        //
        // Solve:
        //
        //     P.x = planeX
        // =========================================================

        let denominator =
            end.x - start.x

        guard abs(denominator) > epsilon
        else {
            return nil
        }

        let t =
            (planeX - start.x) /
            denominator

        guard t.isFinite,
              t >= 0.0,
              t <= 1.0
        else {
            return nil
        }

        // =========================================================
        // INTERSECTION
        // =========================================================

        let intersection =
            start +
            (end - start) * t

        // =========================================================
        // VALIDATE
        // =========================================================

        guard intersection.x.isFinite,
              intersection.y.isFinite,
              intersection.z.isFinite
        else {
            return nil
        }

        // =========================================================
        // CHECK Y/Z IMAGE BOUNDS
        // =========================================================

        guard abs(intersection.y) <= planeHalfExtent,
              abs(intersection.z) <= planeHalfExtent
        else {
            return nil
        }

        // =========================================================
        // FORCE EXACT X
        // =========================================================

        var hit =
            intersection

        hit.x =
            planeX

        return hit
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

    func addSourceGalaxy(
        radius: Double = 0.75,
        nStars: Int = 220
    ) {

        // =========================================================
        // CLEAR PREVIOUS GALAXY
        // =========================================================

        sourceGalaxyNode?.removeFromParentNode()

        sourceGalaxyStars.removeAll(
            keepingCapacity: true
        )

        let galaxyNode =
            SCNNode()

        sourceGalaxyNode =
            galaxyNode


        // =========================================================
        // SOURCE GALAXY DISTANCE
        //
        // Photons travel in +X.
        //
        // Therefore the source galaxy starts at negative X
        // and travels toward the globular cluster at X = 0.
        // =========================================================

        let sourceX:
            Float = -6.5


        // =========================================================
        // GENERATE SOURCE GALAXY
        //
        // Galaxy lies primarily in the Y-Z plane.
        //
        // X = photon travel direction
        // Y = galaxy vertical/radial coordinate
        // Z = galaxy depth/radial coordinate
        // =========================================================

        for starID in 0..<nStars {

            // ---------------------------------------------------------
            // RANDOM ANGLE
            // ---------------------------------------------------------

            let theta = Double.random(
                in: 0.0...(2.0 * Double.pi)
            )

            // ---------------------------------------------------------
            // GALAXY RADIAL DISTRIBUTION
            //
            // sqrt() produces a broad disk distribution.
            // ---------------------------------------------------------

            let radialFraction =
                sqrt(
                    Double.random(
                        in:
                            0.0...1.0
                    )
                )


            let r =
                radius *
                radialFraction


            // ---------------------------------------------------------
            // Y / Z GALAXY POSITION
            // ---------------------------------------------------------

            let y =
                r *
                cos(theta)

            let z =
                r *
                sin(theta)


            // ---------------------------------------------------------
            // SMALL GALAXY THICKNESS ALONG X
            //
            // Keep the galaxy slightly three-dimensional.
            // ---------------------------------------------------------

            let xOffset =
                Double.random(
                    in:
                        -0.03...0.03
                )


            let position =
                SIMD3<Float>(
                    sourceX +
                        Float(xOffset),

                    Float(y),

                    Float(z)
                )


            // ---------------------------------------------------------
            // BRIGHTNESS
            // ---------------------------------------------------------

            let brightness =
                Float.random(
                    in:
                        0.5...1.0
                )


            // =========================================================
            // STORE SOURCE STAR
            //
            // IMPORTANT:
            // This is the position that runFullPipeline() will use
            // as the photon origin.
            // =========================================================

            sourceGalaxyStars.append(
                SourceGalaxyStar(
                    id:
                        starID,

                    position:
                        position,

                    brightness:
                        brightness
                )
            )


            // =========================================================
            // CREATE VISUAL STAR
            // =========================================================

            let starRadius =
                Float(
                    0.008 +
                    Double.random(
                        in:
                            0.0...0.012
                    )
                )


            let geometry =
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

            geometry.firstMaterial =
                material


            let starNode =
                SCNNode(
                    geometry:
                        geometry
                )


            starNode.position =
                SCNVector3(
                    position.x,
                    position.y,
                    position.z
                )


            galaxyNode.addChildNode(
                starNode
            )
        }


        // =========================================================
        // ADD GALAXY TO SCENE
        // =========================================================

        scene.rootNode.addChildNode(
            galaxyNode
        )
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
    
    func addProjectionPlane(
        halfExtent: Float,
        x: Float
    ) {

        // Remove previous plane
        projectionPlaneNode?.removeFromParentNode()

        let size =
            CGFloat(halfExtent * 2.0)

        let geometry =
            SCNPlane(
                width: size,
                height: size
            )

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor(
                white: 0.25,
                alpha: 0.35
            )

        material.emission.contents =
            UIColor(
                white: 0.15,
                alpha: 0.35
            )

        material.lightingModel =
            .constant

        material.isDoubleSided =
            true

        geometry.firstMaterial =
            material

        let node =
            SCNNode(
                geometry:
                    geometry
            )

        // Photons travel along +X.
        // Rotate SCNPlane so it occupies Y-Z.
        node.eulerAngles.y =
            Float.pi / 2.0

        node.position =
            SCNVector3(
                x,
                0,
                0
            )

        projectionPlaneNode =
            node

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
    // ============================================================
    // CLEAR PHOTON SPLINES
    // ============================================================

    func clearPhotonPaths() {

        photonPathRoot.childNodes.forEach {
            $0.removeFromParentNode()
        }

        print(
            "PHOTON SPLINES: cleared"
        )
    }
    // ============================================================
    // ADD ONE PHOTON SPLINE
    // ============================================================

    func addPhotonSpline(
        points: [SIMD3<Float>],
        index: Int
    ) {

        guard points.count >= 2 else {
            return
        }

        // --------------------------------------------------------
        // FILTER INVALID POINTS
        // --------------------------------------------------------

        let validPoints =
            points.filter {

                $0.x.isFinite &&
                $0.y.isFinite &&
                $0.z.isFinite
            }

        guard validPoints.count >= 2 else {
            return
        }

        // --------------------------------------------------------
        // CREATE PATH NODE
        // --------------------------------------------------------

        let pathNode =
            SCNNode()

        pathNode.name =
            "PhotonPath_\(index)"

        // --------------------------------------------------------
        // CREATE SEGMENTS
        //
        // Each pair of adjacent photon positions becomes one
        // short cylinder.
        //
        // This gives us a continuous visible spline-like path.
        // --------------------------------------------------------

        for i in 0..<(validPoints.count - 1) {

            let p0 =
                validPoints[i]

            let p1 =
                validPoints[i + 1]

            let start =
                SCNVector3(
                    p0.x,
                    p0.y,
                    p0.z
                )

            let end =
                SCNVector3(
                    p1.x,
                    p1.y,
                    p1.z
                )

            let segment =
                makePhotonSegment(
                    from:
                        start,

                    to:
                        end
                )

            pathNode.addChildNode(
                segment
            )
        }

        // --------------------------------------------------------
        // ADD COMPLETE PATH TO PHOTON ROOT
        // --------------------------------------------------------

        photonPathRoot.addChildNode(
            pathNode
        )
    }
    // ============================================================
    // PHOTON SEGMENT
    //
    // Creates one visible cylindrical segment between two photon
    // positions.
    //
    // SceneKit cylinders are aligned along their local Y axis,
    // so the cylinder is rotated to point from `from` to `to`.
    //
    // ============================================================

    private func makePhotonSegment(
        from: SCNVector3,
        to: SCNVector3
    ) -> SCNNode {

        // --------------------------------------------------------
        // CONVERT TO SIMD
        // --------------------------------------------------------

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

        // --------------------------------------------------------
        // DIRECTION
        // --------------------------------------------------------

        let delta =
            end - start

        let length =
            simd_length(delta)

        // --------------------------------------------------------
        // PROTECT AGAINST ZERO-LENGTH SEGMENTS
        // --------------------------------------------------------

        guard length > 0.000001,
              length.isFinite
        else {
            return SCNNode()
        }

        let direction =
            simd_normalize(delta)

        // --------------------------------------------------------
        // CYLINDER
        //
        // Small radius keeps the photon path thin while still
        // making it visible in SceneKit.
        // --------------------------------------------------------

        let cylinder =
            SCNCylinder(
                radius: 0.012,
                height: CGFloat(length)
            )

        // --------------------------------------------------------
        // MATERIAL
        // --------------------------------------------------------

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor.cyan

        material.emission.contents =
            UIColor.cyan

        material.lightingModel =
            .constant

        material.isDoubleSided =
            true

        cylinder.firstMaterial =
            material

        // --------------------------------------------------------
        // NODE
        // --------------------------------------------------------

        let node =
            SCNNode(
                geometry:
                    cylinder
            )

        // --------------------------------------------------------
        // POSITION
        //
        // Put the cylinder halfway between the two photon
        // positions.
        // --------------------------------------------------------

        node.position =
            SCNVector3(
                (from.x + to.x) * 0.5,
                (from.y + to.y) * 0.5,
                (from.z + to.z) * 0.5
            )

        // --------------------------------------------------------
        // ROTATE CYLINDER
        //
        // SCNCylinder points along local +Y.
        //
        // We need local +Y to point in `direction`.
        // --------------------------------------------------------

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

            // Already pointing along +Y.

            node.simdOrientation =
                simd_quatf(
                    angle: 0,
                    axis:
                        SIMD3<Float>(
                            1,
                            0,
                            0
                        )
                )

        } else if dot < -0.9999 {

            // Pointing along -Y.

            node.simdOrientation =
                simd_quatf(
                    angle: .pi,
                    axis:
                        SIMD3<Float>(
                            1,
                            0,
                            0
                        )
                )

        } else {

            // ----------------------------------------------------
            // GENERAL ROTATION
            // ----------------------------------------------------

            let rotationAxis =
                simd_normalize(
                    simd_cross(
                        up,
                        direction
                    )
                )

            let clampedDot =
                max(
                    -1.0,
                    min(
                        1.0,
                        Double(dot)
                    )
                )

            let angle =
                acos(
                    clampedDot
                )

            node.simdOrientation =
                simd_quatf(
                    angle:
                        Float(angle),

                    axis:
                        rotationAxis
                )
        }

        return node
    }
}

