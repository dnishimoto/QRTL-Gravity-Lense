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

    private let accumulator: ProjectionAccumulator

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

    // ========================================================
    // PHYSICAL -> SCENE
    // ========================================================

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
                10,
                6,
                15
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
            UIColor.white.withAlphaComponent(0.2)

        material.emission.contents =
            UIColor.white.withAlphaComponent(0.2)

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
    func applyProjection(_ projection: LensingProjectionResult) {

        accumulator.reset()

        for hit in projection.validHits {
            // hit.coordinates are already in the plane’s local Y/Z
            accumulator.addHit(
                y: Double(hit.coordinates.x),
                z: Double(hit.coordinates.y),
                weight: 1.5
            )
        }

        // This is the line that finally puts the yellow image on the plane
        addFrontProjectionPlane(empty: false)
    }
    // ========================================================
    // LEGACY RAW PATH
    //
    // Kept for debugging.
    //
    // IMPORTANT:
    // There is intentionally NO lineWidth property here.
    // SCNGeometryElement has no lineWidth member.
    // ========================================================

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

