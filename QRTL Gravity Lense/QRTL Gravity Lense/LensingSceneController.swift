//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/17/26.
//

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

    @Published private(set) var isRunning:
        Bool = false

    @Published private(set) var pipelineStatus:
        String = "Ready"

    @Published private(set) var lastPipelineOutput:
        LensingPipelineOutput?

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
    let planeHalfExtent: Float = 10.0
    let heatmapHalfExtent: Float = 5.0

    private var projectionPlaneNode: SCNNode?

    private let photonPathRoot =
        SCNNode()


    // ========================================================
    // SHARED MATERIALS (FIX #3)
    //
    // Previously nearly every geometry-creation site allocated
    // a brand-new SCNMaterial() even when every instance of that
    // "kind" of object (a star, a photon path line, a projection
    // hit marker) used identical settings. Sharing one instance
    // per kind cuts allocation churn and lets SceneKit batch
    // more aggressively across nodes that reference the same
    // material.
    // ========================================================

    private lazy var starMaterial: SCNMaterial = {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.emission.contents = UIColor.white
        material.lightingModel = .constant
        return material
    }()

    private lazy var photonLineMaterial: SCNMaterial = {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.systemPink
        material.emission.contents = UIColor.systemPink
        material.lightingModel = .constant
        material.isDoubleSided = true
        return material
    }()

    private lazy var hitMarkerMaterial: SCNMaterial = {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.white
        material.emission.contents = UIColor.white
        material.lightingModel = .constant
        return material
    }()

    private lazy var ghostPathMaterial: SCNMaterial = {
        let material = SCNMaterial()
        let color = UIColor.white.withAlphaComponent(0.1)
        material.diffuse.contents = color
        material.emission.contents = color
        material.lightingModel = .constant
        material.isDoubleSided = true
        return material
    }()

    private lazy var legacyPhotonSegmentMaterial: SCNMaterial = {
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.cyan
        material.emission.contents = UIColor.cyan
        material.lightingModel = .constant
        material.isDoubleSided = true
        return material
    }()


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

    private var projectionHitsNode:
        SCNNode?

    private var photonPathsNode:
        SCNNode?


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
    // ============================================================
    // PHOTON PATH → GR SURFACE-RIDING SPLINE
    //
    // Converts a raw, per-physics-step polyline (from tracePhoton)
    // into a smooth spline whose height is pulled toward the same
    // spacetime-curvature surface used by addDeformedSpacetimeSurface.
    // The result: paths visibly dip along the curved sheet as they
    // pass near the mass, rather than only bending via the separate
    // qrtlLensingAcceleration force in isolation.
    //
    // Raw physics traces can be very dense (up to maximumPhotonSteps),
    // so control points are downsampled before spline fitting —
    // otherwise Catmull-Rom oversampling would multiply an already
    // near-continuous path into tens of thousands of vertices.
    // ============================================================

    private func photonSplinePoints(
        from rawPath: [SIMD3<Float>],
        field: QRTLField,
        maxControlPoints: Int = 60,
        pointsPerSegment: Int = 6,
        curvatureRideStrength: Float = 1.0
    ) -> [SIMD3<Float>] {

        guard rawPath.count >= 2 else {
            return rawPath
        }

        // -------------------------------------------------------
        // DOWNSAMPLE TO CONTROL POINTS
        // -------------------------------------------------------

        let stride = max(1, rawPath.count / maxControlPoints)

        var controlPoints: [SIMD3<Float>] = rawPath.enumerated()
            .compactMap { index, point in
                index % stride == 0 ? point : nil
            }

        if controlPoints.last != rawPath.last {
            controlPoints.append(rawPath[rawPath.count - 1])
        }

        guard controlPoints.count >= 2 else {
            return rawPath
        }

        // -------------------------------------------------------
        // RIDE THE SPACETIME CURVATURE SURFACE
        //
        // Superimpose the same curvature dip the floor mesh uses,
        // on top of the photon's own physics-computed y. Near the
        // mass, curvature is strongly negative, pulling the path
        // down toward the sheet; far away, curvature → 0 and the
        // path reverts to its original trajectory.
        // -------------------------------------------------------

        let riding: [SIMD3<Double>] = controlPoints.map { point in
            let surfaceY = field.spacetimeCurvatureHeight(atXZ: point)
            let blendedY = point.y + surfaceY * curvatureRideStrength
            return SIMD3<Double>(Double(point.x), Double(blendedY), Double(point.z))
        }

        // -------------------------------------------------------
        // SMOOTH WITH CATMULL-ROM SPLINE
        // -------------------------------------------------------

        let smoothed = CatmullRomSpline.interpolate(
            points: riding,
            pointsPerSegment: pointsPerSegment
        )

        return smoothed.map {
            SIMD3<Float>(Float($0.x), Float($0.y), Float($0.z))
        }
    }


    func displayPhotonPaths(
        _ paths: [[SIMD3<Float>]],
        field: QRTLField
    ) {

        clearPhotonPaths()

        let pathsNode = SCNNode()
        pathsNode.name = "PhotonPaths"

        for path in paths {

            let splinePath = photonSplinePoints(
                from: path,
                field: field
            )

            guard let lineNode = makeLineGeometryNode(
                from: splinePath,
                material: photonLineMaterial
            ) else {
                continue
            }

            pathsNode.addChildNode(lineNode)
        }

        scene.rootNode.addChildNode(pathsNode)
        photonPathsNode = pathsNode
    }
 

   
    // ========================================================
    // BOTTOM PLACEHOLDER
    //
    // Flat, undeformed plane used before any QRTLField exists
    // (initial .onAppear, and reset()). Once a pipeline run
    // completes, addDeformedSpacetimeSurface(field:heatmap:)
    // replaces this node with the real deformed mesh — see
    // runFullPipeline() Stage 4.
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
    // DEFORMED SPACETIME SURFACE
    //
    // Replaces the flat SCNPlane bottom placeholder with an
    // actual curved-sheet mesh, ported from
    // QRTLGravitySurfaceView.makeSurfaceGeometry(). Vertex height
    // (y) is driven by mass density + QRTL/Bolgarino flux, so the
    // surface visibly deforms under the globular cluster mass and
    // the QRTL field's own gravity-like force.
    // ========================================================

    func addDeformedSpacetimeSurface(
        field: QRTLField,
        heatmap: UIImage? = nil
    ) {

        bottomPlaneNode?.removeFromParentNode()

        let n = resolution > 4 ? min(resolution, 96) : 48   // grid density; capped for perf
        let extent = heatmapHalfExtent

        var positions: [SCNVector3] = []
        var texcoords: [CGPoint] = []
        var indices: [Int32] = []

        let start = -extent
        let step = (2 * extent) / Float(n - 1)

        for j in 0..<n {
            for i in 0..<n {
                let x = start + Float(i) * step
                let z = start + Float(j) * step
                let base = SIMD3<Float>(x, 0, z)

                // --- CORE LOGIC FOR SPACETIME CURVATURE (from QRTLGravitySurfaceView) ---
                let density = field.normalizedDensity(at: base)
                let flow = field.bolgarinoFlux(at: base)
                let flowMag = simd_length(flow)
                let flowNorm = flowMag.isFinite && flowMag > 0 ? min(flowMag / (flowMag + 1), 1.0) : 0.0
                let curvature = 0.65 * density + 0.35 * Float(flowNorm)
                let y = field.spacetimeCurvatureHeight(atXZ: base)
             
                positions.append(SCNVector3(x, y, z))
                texcoords.append(CGPoint(
                    x: CGFloat(Float(i) / Float(n - 1)),
                    y: CGFloat(Float(j) / Float(n - 1))
                ))
            }
        }

        for j in 0..<(n - 1) {
            for i in 0..<(n - 1) {
                let idx = Int32(j * n + i)
                indices.append(contentsOf: [
                    idx, idx + 1, idx + Int32(n),
                    idx + 1, idx + 1 + Int32(n), idx + Int32(n)
                ])
            }
        }

        let posSource = SCNGeometrySource(vertices: positions)
        let uvSource = SCNGeometrySource(textureCoordinates: texcoords)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: [posSource, uvSource], elements: [element])

        let material = SCNMaterial()
        material.isDoubleSided = true
        if let heatmap {
            material.diffuse.contents = heatmap
            material.emission.contents = heatmap
            material.lightingModel = .constant
        } else {
            material.diffuse.contents = UIColor(white: 0.07, alpha: 0.9)
            material.emission.contents = UIColor(white: 0.02, alpha: 0.4)
        }
        geometry.materials = [material]

        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(frontPlaneX * 0.5, bottomY, 0)
        node.name = "DeformedSpacetimeSurface"
        scene.rootNode.addChildNode(node)
        bottomPlaneNode = node
    }

  
    // ============================================================
    // POINT-CLOUD STAR FIELD HELPER (FIX #2)
    //
    // Previously addGlobularCluster / addCluster / addSourceGalaxy
    // each created one SCNSphere + one SCNMaterial + one SCNNode
    // PER STAR — up to 3,220 separate nodes rebuilt on every run,
    // each its own draw call.
    //
    // This builds the entire star field as a single SCNGeometry
    // using primitiveType .point, so an entire field of thousands
    // of stars becomes ONE node / ONE draw call.
    //
    // TRADE-OFF: individual per-star size variation (e.g. the
    // "brighter/larger near the core" effect in the original
    // addGlobularCluster) is lost — every point in a given cloud
    // renders at the same size. If that visual detail matters,
    // it can be reintroduced via a per-vertex SCNGeometrySource
    // with semantic .color to modulate brightness, but that adds
    // complexity that isn't justified unless you actually miss
    // the look.
    // ============================================================

    private func makeStarPointCloudNode(
        positions: [SIMD3<Float>],
        pointSize: CGFloat = 0.05,
        minimumScreenSpaceRadius: CGFloat = 1.0,
        maximumScreenSpaceRadius: CGFloat = 6.0
    ) -> SCNNode {

        guard !positions.isEmpty else {
            return SCNNode()
        }

        let vertices = positions.map {
            SCNVector3($0.x, $0.y, $0.z)
        }

        let source = SCNGeometrySource(vertices: vertices)

        let indices: [Int32] = Array(0..<Int32(vertices.count))

        let element = SCNGeometryElement(
            indices: indices,
            primitiveType: .point
        )

        element.pointSize = pointSize
        element.minimumPointScreenSpaceRadius = minimumScreenSpaceRadius
        element.maximumPointScreenSpaceRadius = maximumScreenSpaceRadius

        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial = starMaterial

        return SCNNode(geometry: geometry)
    }


    // ============================================================
    // SINGLE-GEOMETRY-PER-PATH LINE HELPER (FIX #1)
    //
    // Replaces the old approach of one SCNCylinder + one
    // SCNMaterial + one SCNNode PER SEGMENT of a photon path
    // (with up to ~1500 steps per photon, times up to 220 stars,
    // this was the single largest node-count contributor in the
    // whole file) with ONE SCNGeometry per path, using
    // primitiveType .line.
    //
    // TRADE-OFF: .line primitives have no controllable thickness
    // (they rasterize at a hairline width), unlike the cylinder
    // segments which had real 3D radius. This matches the
    // approach your own renderPhotonPath(_:) already used
    // elsewhere in this file — this fix generalizes that pattern
    // to displayPhotonPaths so it's used for the main pipeline
    // output, not just the unused "ghost path" overlay.
    // ============================================================

    private func makeLineGeometryNode(
        from path: [SIMD3<Float>],
        material: SCNMaterial
    ) -> SCNNode? {

        guard path.count >= 2 else {
            return nil
        }

        let validPoints = path.filter {
            $0.x.isFinite && $0.y.isFinite && $0.z.isFinite
        }

        guard validPoints.count >= 2 else {
            return nil
        }

        let vertices = validPoints.map {
            SCNVector3($0.x, $0.y, $0.z)
        }

        let source = SCNGeometrySource(vertices: vertices)

        var indices: [Int32] = []
        indices.reserveCapacity((vertices.count - 1) * 2)

        for i in 0..<(vertices.count - 1) {
            indices.append(Int32(i))
            indices.append(Int32(i + 1))
        }

        let element = SCNGeometryElement(
            indices: indices,
            primitiveType: .line
        )

        let geometry = SCNGeometry(sources: [source], elements: [element])
        geometry.firstMaterial = material

        return SCNNode(geometry: geometry)
    }


  
    // ============================================================
    // RENDER COMPLETE LENSING PIPELINE OUTPUT
    // ============================================================
    //
    // Physics/data flow:
    //
    // LensingPipelineOutput
    //        │
    //        ├── photonPaths
    //        │       ↓
    //        │   displayPhotonPaths()
    //        │
    //        ├── projection
    //        │       ↓
    //        │   renderProjection()
    //        │
    //        └── projection.hits
    //                ↓
    //            displayProjectionHits()
    //
    // ContentView generates the pipeline.
    // LensingSceneController renders the results.
    //
    // ============================================================

    func renderPipelineOutput(
        _ output:
            LensingPipelineOutput,

        showPhotonPaths:
            Bool,

        projectionDistance:
            Float = 10.0,

        projectionPlaneHalfExtent:
            Float = 12.0
    ) {

        // ========================================================
        // STORE COMPLETE PIPELINE OUTPUT
        // ========================================================

        lastPipelineOutput =
            output


        // ========================================================
        // CLEAR OLD PHOTON PATHS
        //
        // Prevents paths from previous pipeline runs from
        // remaining in the scene.
        // ========================================================

        clearPhotonPaths()


        // ========================================================
        // DISPLAY PHOTON PATHS
        //
        // These paths were generated by:
        //
        // traceSourceGalaxy()
        //        ↓
        // tracePhoton()
        //        ↓
        // photonBatch.paths
        //        ↓
        // output.photonPaths
        //
        // This function does NOT calculate photon trajectories.
        // It only displays the paths already calculated.
        // ========================================================


        if showPhotonPaths {

            displayPhotonPaths(
                output.photonPaths,
                field: output.field
            )
        }

        // ========================================================
        // RENDER PROJECTION
        //
        // This renders the projection structure/image.
        // ========================================================

        renderProjection(
            output.projection,
            projectionDistance: 10.0,
            projectionPlaneHalfExtent: 12.0
        )


        // ========================================================
        // DISPLAY PROJECTION HITS
        //
        // LensingProjectionHit contains:
        //
        //     point
        //     coordinates
        //     sourceCoordinates
        //     direction
        //     diagnostics
        //
        // The 3D SceneKit location is `point`.
        // ========================================================

        displayProjectionHits(

            output.projection.hits,

            planeHalfExtent:
                projectionPlaneHalfExtent
        )


        // ========================================================
        // POSITION PROJECTION PLANE
        //
        // projectionDistance belongs to the rendering configuration,
        // not LensingPipelineOutput.
        // ========================================================

        projectionNode?.position.z =
            projectionDistance
    }
    // ============================================================
    // TRACE SOURCE GALAXY
    //
    // Unchanged from before — this turn's fixes are scoped to
    // rendering (SceneKit node/material construction), not the
    // physics tracing pipeline.
    // ============================================================

    func traceSourceGalaxy(
        stars: [SourceGalaxyStar],
        field: QRTLField,
        parameters: LensingParameters,
        showPaths: Bool
    ) -> PhotonTraceBatch {

        var traces: [PhotonTraceResult] = []
        var paths: [[SIMD3<Float>]] = []
        var hits: [LensingProjectionHit] = []

        traces.reserveCapacity(stars.count * 2)
        hits.reserveCapacity(stars.count * 2)
        if showPaths {
            paths.reserveCapacity(stars.count * 2)
        }

        for star in stars {

            // -------------------------------------------------
            // Launch TWO photons (A & B) on opposite sides
            // of the lens so we get two distinct images
            // -------------------------------------------------
            let pair = makePhotonPairDirections(for: star)

            let launches: [(SIMD3<Float>, SIMD3<Float>)] = [
                (star.position, pair.left),   // Photon A
                (star.position, pair.right)   // Photon B
            ]

            for (origin, direction) in launches {

                let trace = tracePhoton(
                    origin: origin,
                    direction: direction,
                    field: field,
                    parameters: parameters
                )

                traces.append(trace)

                if showPaths, trace.positions.count >= 2 {
                    paths.append(trace.positions)
                }

                guard trace.hitProjection,
                      let projectionPoint = trace.projectionPosition
                else { continue }

                let hit = LensingProjectionHit(
                    point: projectionPoint,
                    coordinates: SIMD2<Float>(projectionPoint.y, projectionPoint.z),
                    sourceCoordinates: SIMD2<Float>(star.position.y, star.position.z),
                    direction: trace.finalDirection,
                    traveledDistance: trace.traveledDistance,
                    interactionCount: trace.stepCount,
                    maximumMagneticField: trace.maximumMagneticField,
                    maximumQRTLInfluence: trace.maximumQRTLInfluence,
                    maximumMagneticPhotonInfluence: trace.maximumMagneticPhotonInfluence,
                    sourceID: star.id
                )

                hits.append(hit)
            }
        }

        return PhotonTraceBatch(traces: traces, paths: paths, hits: hits)
    }
    private func projectionPlaneIntersection(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        parameters: LensingParameters
    ) -> SIMD3<Float>? {

        let planeX =
            parameters.projectionDistance

        let halfExtent =
            parameters.projectionPlaneHalfExtent

        guard planeX.isFinite,
              halfExtent.isFinite,
              halfExtent > 0.0
        else {
            return nil
        }

        let x0 =
            start.x

        let x1 =
            end.x

        guard x0.isFinite,
              x1.isFinite
        else {
            return nil
        }

        let dx =
            x1 - x0

        guard dx.isFinite,
              abs(dx) > 0.000001
        else {
            return nil
        }

        let t =
            (planeX - x0) / dx

        guard t.isFinite,
              t >= 0.0,
              t <= 1.0
        else {
            return nil
        }

        let intersection =
            start +
            (end - start) * t

        guard intersection.x.isFinite,
              intersection.y.isFinite,
              intersection.z.isFinite
        else {
            return nil
        }

        guard abs(intersection.y) <= halfExtent,
              abs(intersection.z) <= halfExtent
        else {
            return nil
        }

        var result =
            intersection

        result.x =
            planeX

        return result
    }
    // ============================================================
    // DISPLAY PROJECTION HIT MARKERS (FIX #3 applied here)
    // ============================================================

    private func displayProjectionHits(
        _ hits:
            [LensingProjectionHit],

        planeHalfExtent:
            Float
    ) {

        // ========================================================
        // REMOVE OLD HIT MARKERS
        // ========================================================

        projectionHitsNode?
            .removeFromParentNode()


        // ========================================================
        // CREATE HIT CONTAINER
        // ========================================================

        let hitsNode =
            SCNNode()

        hitsNode.name =
            "ProjectionHits"


        // ========================================================
        // CREATE VISUAL MARKER FOR EACH PHOTON HIT
        //
        // Individual SCNSphere per hit is kept — the count here
        // is bounded by star count (hundreds, not thousands), so
        // a point-cloud rewrite isn't worth the added complexity.
        // The fix here is only sharing hitMarkerMaterial instead
        // of allocating a new SCNMaterial per hit.
        // ========================================================

        for hit in hits {

            let position =
                hit.point

            let sphere =
                SCNSphere(
                    radius:
                        0.035
                )

            sphere.firstMaterial =
                hitMarkerMaterial

            let node =
                SCNNode(
                    geometry:
                        sphere
                )

            node.position =
                SCNVector3(
                    position.x,
                    position.y,
                    position.z
                )

            hitsNode.addChildNode(
                node
            )
        }


        // ========================================================
        // ADD HIT COLLECTION TO PROJECTION NODE
        // ========================================================

        projectionNode?
            .addChildNode(
                hitsNode
            )


        projectionHitsNode =
            hitsNode
    }
    // ============================================================
    // RENDER PROJECTION
    // ============================================================

    private func renderProjection(
        _ projection:
            LensingProjectionResult,

        projectionDistance:
            Float,

        projectionPlaneHalfExtent:
            Float
    ) {

        projectionNode?
            .removeFromParentNode()

        projectionNode =
            nil

        let plane =
            SCNPlane(

                width:
                    CGFloat(
                        projectionPlaneHalfExtent * 2.0
                    ),

                height:
                    CGFloat(
                        projectionPlaneHalfExtent * 2.0
                    )
            )

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor(
                white:
                    0.05,
                alpha:
                    0.90
            )

        material.emission.contents =
            UIColor(
                white:
                    0.05,
                alpha:
                    0.90
            )

        material.isDoubleSided =
            true

        material.lightingModel =
            .constant

        plane.firstMaterial =
            material

        let node =
            SCNNode()

        node.name =
            "LensingProjectionPlane"

        node.geometry =
            plane

        node.position =
            SCNVector3(
                0,
                0,
                projectionDistance
            )

        scene.rootNode.addChildNode(
            node
        )

        projectionNode =
            node

        displayProjectionHits(
            projection.hits,
            planeHalfExtent:
                projectionPlaneHalfExtent
        )
    }

    // ============================================================
    // TRACE PHOTON THROUGH QRTL + ELECTROMAGNETIC FIELD
    //
    // Unchanged — out of scope for this turn's fixes.
    // ============================================================

    func tracePhoton(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        field: QRTLField,
        parameters: LensingParameters
    ) -> PhotonTraceResult {

        var position = origin

        let initialLength = simd_length(direction)
        guard initialLength.isFinite, initialLength > 0.000001 else {
            return PhotonTraceResult(
                positions: [origin],
                origin: origin,
                finalPosition: origin,
                finalDirection: .zero,
                hitProjection: false,
                projectionPosition: nil,
                stepCount: 0,
                traveledDistance: 0.0,
                maximumQRTLInfluence: 0.0,
                maximumMagneticField: 0.0,
                maximumMagneticPhotonInfluence: 0.0
            )
        }

        var photonDirection = simd_normalize(direction)

        guard photonDirection.x.isFinite,
              photonDirection.y.isFinite,
              photonDirection.z.isFinite else {
            return PhotonTraceResult(
                positions: [origin],
                origin: origin,
                finalPosition: origin,
                finalDirection: .zero,
                hitProjection: false,
                projectionPosition: nil,
                stepCount: 0,
                traveledDistance: 0.0,
                maximumQRTLInfluence: 0.0,
                maximumMagneticField: 0.0,
                maximumMagneticPhotonInfluence: 0.0
            )
        }

        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(parameters.maximumPhotonSteps + 1)
        positions.append(position)

        var maximumQRTLInfluence: Float = 0.0
        var maximumMagneticField: Float = 0.0
        var maximumMagneticPhotonInfluence: Float = 0.0
        var traveledDistance: Float = 0.0
        var stepCount: Int = 0

        for _ in 0..<parameters.maximumPhotonSteps {

            stepCount += 1
            let previousPosition = position
            let previousDirection = photonDirection

            // -------------------------------------------------------
            // Diagnostics (unchanged)
            // -------------------------------------------------------
            let qrtlInfluence = field.influence(at: position)
            let qrtlMagnitude = simd_length(qrtlInfluence)
            if qrtlMagnitude.isFinite {
                maximumQRTLInfluence = max(maximumQRTLInfluence, qrtlMagnitude)
            }

            let electromagneticInfluence = field.electromagneticInfluence(at: position)
            let magneticPhotonMagnitude = simd_length(electromagneticInfluence)
            if magneticPhotonMagnitude.isFinite {
                maximumMagneticPhotonInfluence = max(maximumMagneticPhotonInfluence, magneticPhotonMagnitude)
            }

            let electromagneticField = field.electromagneticField(at: position)
            let magneticFieldMagnitude = simd_length(electromagneticField)
            if magneticFieldMagnitude.isFinite {
                maximumMagneticField = max(maximumMagneticField, magneticFieldMagnitude)
            }

            // -------------------------------------------------------
            // QRTL curvilinear flow – matches the heatmap
            //
            // Uses the same acceleration that qrtlLensingStrength
            // (and therefore the heatmap) is built from.
            // The kick is already transverse → photons flow around
            // the high-density core like streamlines around an island.
            // -------------------------------------------------------
            let acceleration = field.qrtlLensingAcceleration(
                at: position,
                direction: photonDirection
            )

            guard acceleration.x.isFinite,
                  acceleration.y.isFinite,
                  acceleration.z.isFinite else {
                break
            }

            let step = parameters.photonStepSize
            guard step.isFinite, step > 0.0 else { break }

            let kick = acceleration
                     * parameters.qrtlFieldCoupling
                     * parameters.deflectionStrength
                     * step

            var nextDirection = photonDirection + kick

            let nextLength = simd_length(nextDirection)
            guard nextLength.isFinite, nextLength > 0.000001 else { break }

            nextDirection = simd_normalize(nextDirection)

            // Soft limit on angular change per step
            let maxBend = parameters.maximumPhotonBend
            let cosAngle = simd_clamp(simd_dot(photonDirection, nextDirection), -1.0, 1.0)
            let bendAngle = acos(cosAngle)
            if bendAngle > maxBend {
                nextDirection = photonDirection   // reject violent flip
            }

            let nextPosition = position + nextDirection * step
            guard nextPosition.x.isFinite,
                  nextPosition.y.isFinite,
                  nextPosition.z.isFinite else {
                break
            }

            // -------------------------------------------------------
            // Projection-plane intersection test
            // -------------------------------------------------------
            if let intersection = projectionPlaneIntersection(
                from: previousPosition,
                to: nextPosition,
                parameters: parameters
            ) {
                position = intersection
                positions.append(intersection)
                traveledDistance += simd_distance(previousPosition, intersection)

                return PhotonTraceResult(
                    positions: positions,
                    origin: origin,
                    finalPosition: intersection,
                    finalDirection: nextDirection,
                    hitProjection: true,
                    projectionPosition: intersection,
                    stepCount: stepCount,
                    traveledDistance: traveledDistance,
                    maximumQRTLInfluence: maximumQRTLInfluence,
                    maximumMagneticField: maximumMagneticField,
                    maximumMagneticPhotonInfluence: maximumMagneticPhotonInfluence
                )
            }

            // -------------------------------------------------------
            // Advance
            // -------------------------------------------------------
            photonDirection = nextDirection
            position = nextPosition
            traveledDistance += step
            positions.append(position)

            let distanceFromCenter = simd_length(position)
            if distanceFromCenter.isFinite,
               distanceFromCenter > parameters.maximumPropagationRadius {
                break
            }
        }

        return PhotonTraceResult(
            positions: positions,
            origin: origin,
            finalPosition: position,
            finalDirection: photonDirection,
            hitProjection: false,
            projectionPosition: nil,
            stepCount: stepCount,
            traveledDistance: traveledDistance,
            maximumQRTLInfluence: maximumQRTLInfluence,
            maximumMagneticField: maximumMagneticField,
            maximumMagneticPhotonInfluence: maximumMagneticPhotonInfluence
        )
    }
 
    private func makePhotonPairDirections(
        for star: SourceGalaxyStar
    ) -> (left: SIMD3<Float>, right: SIMD3<Float>) {

        let forward = SIMD3<Float>(1, 0, 0)

        // Random but stable orientation for this star
        let angle = Float.random(in: -Float.pi ... Float.pi)
        let transverse = SIMD3<Float>(0, cos(angle), sin(angle))

        // Larger offset → clearer separation of the two images
        let offset = Float.random(in: 0.12 ... 0.28)

        let left  = simd_normalize(forward - transverse * offset)
        let right = simd_normalize(forward + transverse * offset)

        return (left, right)
    }
    func removePreviousProjection() {

        projectionNode?.removeFromParentNode()
        projectionNode = nil

        for node in projectionNodes {

            node.removeFromParentNode()
        }

        projectionNodes.removeAll(
            keepingCapacity: true
        )

        projectionAccumulator.reset()
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
    // CLEAR (per-run pipeline output only — see prior fix)
    // ========================================================

    func clearDynamic() {

        // ----------------------------------------------------
        // PHOTON PATHS (both representations)
        // ----------------------------------------------------

        clearPhotonPaths()

        pathNodes.forEach {
            $0.removeFromParentNode()
        }

        pathNodes.removeAll()


        // ----------------------------------------------------
        // PROJECTION PLANE + HIT MARKERS
        // ----------------------------------------------------

        projectionNode?
            .removeFromParentNode()

        projectionNode =
            nil

        projectionHitsNode?
            .removeFromParentNode()

        projectionHitsNode =
            nil

        projectionPlaneNode?
            .removeFromParentNode()

        projectionPlaneNode =
            nil

        projectionNodes.forEach {
            $0.removeFromParentNode()
        }

        projectionNodes.removeAll(
            keepingCapacity: true
        )


        // ----------------------------------------------------
        // ACCUMULATED PROJECTION DATA
        // ----------------------------------------------------

        accumulator.reset()

        projectionAccumulator.reset()


        // ----------------------------------------------------
        // LAST PIPELINE OUTPUT
        // ----------------------------------------------------

        lastPipelineOutput =
            nil

        // NOTE: globularClusterNode, sourceGalaxyNode,
        // sourceGalaxyStars, bottomPlaneNode, and frontPlaneNode
        // are deliberately NOT touched here — they're persistent
        // scene furniture, not per-run pipeline output. See the
        // "fix clearDynamic" discussion earlier in this thread.
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

        let sourceX:
            Float = -6.5

        var positions:
            [SIMD3<Float>] = []

        positions.reserveCapacity(
            nStars
        )

        // =========================================================
        // GENERATE SOURCE GALAXY POSITIONS + METADATA
        //
        // This part is unchanged CPU-only math — no SceneKit
        // objects are created per star anymore. The visual is
        // built once, after this loop, as a single point cloud.
        // =========================================================

        for starID in 0..<nStars {

            let theta = Double.random(
                in: 0.0...(2.0 * Double.pi)
            )

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

            let y =
                r *
                cos(theta)

            let z =
                r *
                sin(theta)

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

            let brightness =
                Float.random(
                    in:
                        0.5...1.0
                )

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

            positions.append(
                position
            )
        }


        // =========================================================
        // BUILD SINGLE POINT-CLOUD NODE (FIX #2)
        //
        // Replaces up to 220 individual SCNSphere/SCNMaterial/
        // SCNNode allocations with one draw call.
        // =========================================================

        let galaxyNode =
            makeStarPointCloudNode(
                positions: positions,
                pointSize: 0.03,
                minimumScreenSpaceRadius: 1.0,
                maximumScreenSpaceRadius: 4.0
            )

        sourceGalaxyNode =
            galaxyNode

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

        var positions:
            [SIMD3<Float>] = []

        positions.reserveCapacity(
            nStars
        )

        // =========================================================
        // GENERATE CLUSTER POSITIONS (unchanged math)
        // =========================================================

        for _ in 0..<nStars {

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

            positions.append(
                SIMD3<Float>(
                    Float(x),
                    Float(y),
                    Float(z)
                )
            )
        }

        // =========================================================
        // BUILD SINGLE POINT-CLOUD NODE (FIX #2)
        //
        // Replaces up to 3,000 individual node allocations. Note:
        // this drops the original per-star "brighter/larger near
        // core" size variation — see the comment on
        // makeStarPointCloudNode above.
        // =========================================================

        let clusterNode =
            makeStarPointCloudNode(
                positions: positions,
                pointSize: 0.04,
                minimumScreenSpaceRadius: 1.0,
                maximumScreenSpaceRadius: 5.0
            )

        globularClusterNode =
            clusterNode

        scene.rootNode.addChildNode(
            clusterNode
        )
    }

    // ========================================================
    // FRONT PROJECTION PLANE
    // ========================================================

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

    // ========================================================
    // CYLINDER BETWEEN TWO SCENE POINTS
    //
    // Legacy — used only by addSplinePhotonPath, which is not
    // called anywhere in the current pipeline (ContentView never
    // invokes addPhotonPath/addSplinePhotonPath). Left intact for
    // compatibility with any external call sites; out of scope
    // for this turn's fixes since it isn't in the hot path.
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
    // SMOOTH PHOTON PATH (legacy, not in current pipeline)
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

  
   
   
    // ============================================================
    // CLEAR PHOTON SPLINES
    //
    // FIXED: previously did not remove photonPathsNode from the
    // scene — displayPhotonPaths() overwrote the *reference* on
    // every run but the OLD node stayed parented in the scene
    // graph forever, since nothing ever called
    // photonPathsNode?.removeFromParentNode(). This was a real
    // leak: every pipeline run left the previous run's photon
    // paths behind, invisible to your Swift-side bookkeeping but
    // still present (and still being rendered/costing GPU time)
    // in the actual scene graph — compounding run after run.
    // ============================================================

    func clearPhotonPaths() {

        photonPathRoot.childNodes.forEach {
            $0.removeFromParentNode()
        }

        photonPathNodes.forEach {
            $0.removeFromParentNode()
        }

        photonPathNodes.removeAll(
            keepingCapacity: true
        )

        photonPathsNode?
            .removeFromParentNode()

        photonPathsNode =
            nil
    }


    // ============================================================
    // PHOTON SEGMENT (legacy — FIX #3 applied: shared material)
    // ============================================================

    private func makePhotonSegment(
        from: SCNVector3,
        to: SCNVector3
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
            end - start

        let length =
            simd_length(delta)

        guard length > 0.000001,
              length.isFinite
        else {
            return SCNNode()
        }

        let direction =
            simd_normalize(delta)

        let cylinder =
            SCNCylinder(
                radius: 0.012,
                height: CGFloat(length)
            )

        cylinder.firstMaterial =
            legacyPhotonSegmentMaterial

        let node =
            SCNNode(
                geometry:
                    cylinder
            )

        node.position =
            SCNVector3(
                (from.x + to.x) * 0.5,
                (from.y + to.y) * 0.5,
                (from.z + to.z) * 0.5
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
                    angle: 0,
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
                    angle: .pi,
                    axis:
                        SIMD3<Float>(
                            1,
                            0,
                            0
                        )
                )

        } else {

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
