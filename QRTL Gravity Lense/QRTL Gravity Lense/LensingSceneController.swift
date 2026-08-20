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

    @Published var lastPipelineOutput:
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

    private(set) var qrtlGravitySurface:
            QRTLGravitySurfaceEntity?

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
    
    private let gravitationalConstant: Double =
        6.67430e-11

    private let speedOfLight: Double =
        299_792_458.0

    private let globularClusterMassKilograms: Double =
        2.0e36

    private let globularClusterScaleRadiusMeters: Double =
        3.085677581e16

    // SceneKit distance represented by one visual scene unit.
    // Choose the scale that matches your model. This is one parsec
    // per scene unit as a reasonable initial physical mapping.
    private let metersPerSceneUnit: Double =
        3.085677581e16

    // 1.0 = literal GR weak-field bend.
    // Use a larger value only for a visible educational visualization.
    private let einsteinDisplayGain: Double =
        1.0
  

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
    func installQRTLGravitySurface(
        field: QRTLField
    ) {

        qrtlGravitySurface?.removeFromParentNode()
        qrtlGravitySurface = nil

        let entity =
            QRTLGravitySurfaceEntity(
                field: field,
                gridSize: 64,
                extent: 18.0,
                numberOfStars: 220,
                photonSteps: 500,
                curvatureScale: 1.0
            )

        qrtlGravitySurface =
            entity

        scene.rootNode.addChildNode(
            entity
        )
    }
    func verifyPhotonPipeline(
        photonResults: [PhotonTraceResult],
        photonsCreated: Int
    ) -> PhotonPipelineVerification {

        var photonsTraced = 0
        var photonsReachedProjectionPlane = 0
        var photonsWithCurvedPaths = 0
        var totalPathPoints = 0

        var maximumDeflection: Float = 0.0
        var maximumQRTLInfluence: Float = 0.0

        for result in photonResults {

            photonsTraced += 1

            totalPathPoints += result.positions.count

            maximumQRTLInfluence = max(
                maximumQRTLInfluence,
                result.maximumQRTLInfluence
            )

            // ----------------------------------------------------
            // Determine total photon deflection from the path.
            //
            // Compare the initial direction of the photon with
            // its final direction after QRTL/gravitational bending.
            // ----------------------------------------------------

            if result.positions.count >= 2 {

                let start =
                    result.positions[1] -
                    result.positions[0]

                let initialDirection =
                    simd_normalize(start)

                let finalDirection =
                    simd_normalize(result.finalDirection)

                if simd_length(initialDirection) > 0.0 &&
                   simd_length(finalDirection) > 0.0 {

                    let dotValue =
                        simd_dot(
                            initialDirection,
                            finalDirection
                        )

                    let clampedDot =
                        max(
                            -1.0,
                            min(1.0, dotValue)
                        )

                    let deflection =
                        acos(clampedDot)

                    maximumDeflection =
                        max(
                            maximumDeflection,
                            deflection
                        )

                    if deflection > 0.000001 {
                        photonsWithCurvedPaths += 1
                    }
                }
            }

            // ----------------------------------------------------
            // Projection-plane verification.
            //
            // hitProjection is the authoritative result from
            // the photon tracer that the photon reached the
            // target projection plane.
            // ----------------------------------------------------

            if result.hitProjection {
                photonsReachedProjectionPlane += 1
            }
        }

        return PhotonPipelineVerification(
            photonsCreated:
                photonsCreated,

            photonsTraced:
                photonsTraced,

            photonsReachedProjectionPlane:
                photonsReachedProjectionPlane,

            photonsWithCurvedPaths:
                photonsWithCurvedPaths,

            totalPathPoints:
                totalPathPoints,

            maximumDeflection:
                maximumDeflection,

            maximumQRTLInfluence:
                maximumQRTLInfluence
        )
    }
    // ============================================================
    // EINSTEIN LENS MASS PROFILE
    // ============================================================

    private func plummerEnclosedMass(
        radiusMeters: Double
    ) -> Double {
        let radius = max(
            radiusMeters,
            0.0
        )

        let a =
            max(
                globularClusterScaleRadiusMeters,
                1.0
            )

        let denominator =
            pow(
                radius * radius +
                a * a,
                1.5
            )

        guard denominator.isFinite,
              denominator > 0.0
        else {
            return 0.0
        }

        let enclosedMass =
            globularClusterMassKilograms *
            radius *
            radius *
            radius /
            denominator

        guard enclosedMass.isFinite,
              enclosedMass >= 0.0
        else {
            return 0.0
        }

        return enclosedMass
    }

    // ============================================================
    // EINSTEIN DEFLECTION ANGLE
    // ============================================================
    //
    // Returns the physical weak-field GR deflection angle in radians:
    //
    // α = 4 G M(<b) / (c² b)
    //
    // For a perfectly centered ray, symmetry means there is no unique
    // transverse direction, so return zero rather than divide by zero.
    //

    private func einsteinDeflectionAngle(
        impactParameterMeters: Double
    ) -> Double {
        let b =
            max(
                impactParameterMeters,
                0.0
            )

        guard b.isFinite,
              b > 1.0
        else {
            return 0.0
        }

        let enclosedMass =
            plummerEnclosedMass(
                radiusMeters: b
            )

        let numerator =
            4.0 *
            gravitationalConstant *
            enclosedMass

        let denominator =
            speedOfLight *
            speedOfLight *
            b

        guard numerator.isFinite,
              denominator.isFinite,
              denominator > 0.0
        else {
            return 0.0
        }

        let angle =
            numerator /
            denominator

        guard angle.isFinite,
              angle >= 0.0
        else {
            return 0.0
        }

        return angle
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

        let stride = max(
            1,
            rawPath.count / maxControlPoints
        )

        var controlPoints: [SIMD3<Float>] =
            rawPath.enumerated().compactMap { index, point in
                index % stride == 0 ? point : nil
            }

        if controlPoints.last != rawPath.last {
            controlPoints.append(
                rawPath[
                    rawPath.count - 1
                ]
            )
        }

        guard controlPoints.count >= 2 else {
            return rawPath
        }

        let lastControlPointIndex =
            controlPoints.count - 1

        let riding: [SIMD3<Double>] =
            controlPoints.enumerated().map {
                index,
                point in

                let isEndpoint =
                    index == 0 ||
                    index == lastControlPointIndex

                let surfaceY: Float

                if isEndpoint {
                    // Preserve actual source and detector endpoints.
                    surfaceY = 0.0
                } else {
                    surfaceY =
                        field.spacetimeCurvatureHeight(
                            atXZ: SIMD2<Float>(
                                point.x,
                                point.z
                            )
                        )
                }

                let displayedY =
                    point.y +
                    surfaceY *
                    curvatureRideStrength

                return SIMD3<Double>(
                    Double(point.x),
                    Double(displayedY),
                    Double(point.z)
                )
            }

        let smoothed =
            CatmullRomSpline.interpolate(
                points: riding,
                pointsPerSegment: pointsPerSegment
            )

        var result = smoothed.map {
            SIMD3<Float>(
                Float($0.x),
                Float($0.y),
                Float($0.z)
            )
        }

        // Catmull–Rom interpolation may slightly shift end points.
        // Restore the exact raw source-star and projection-hit positions.
        if !result.isEmpty {
            result[0] = rawPath[0]

            result[
                result.count - 1
            ] =
                rawPath[
                    rawPath.count - 1
                ]
        }

        return result
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

        // =========================================================
        // REMOVE PREVIOUS SURFACE
        // =========================================================

        bottomPlaneNode?.removeFromParentNode()

        // =========================================================
        // GRID RESOLUTION
        // =========================================================

        let n =
            resolution > 4
            ? min(resolution, 96)
            : 48

        let extent =
            heatmapHalfExtent

        var positions:
            [SCNVector3] = []

        var colors:
            [SIMD4<Float>] = []

        var texcoords:
            [CGPoint] = []

        var indices:
            [Int32] = []

        positions.reserveCapacity(n * n)
        colors.reserveCapacity(n * n)
        texcoords.reserveCapacity(n * n)

        let start =
            -extent

        let step =
            (2.0 * extent) /
            Float(n - 1)

        // =========================================================
        // FIND MAXIMUM FIELD INTENSITY
        //
        // This gives us a common normalization for the entire
        // surface so the color represents relative gravity
        // intensity across the complete 360-degree field.
        // =========================================================

        var maximumIntensity:
            Float = 0.000001

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

                let density =
                    field.normalizedDensity(
                        at: position
                    )

                let qrtlSource =
                    field.qrtlSource(
                        at: position
                    )

                let flow =
                    field.bolgarinoFlux(
                        at: position
                    )

                let flowMagnitude =
                    simd_length(flow)

                let magnetic =
                    field.magneticField(
                        at: position
                    )

                let magneticMagnitude =
                    simd_length(magnetic)

                // -------------------------------------------------
                // Combined QRTL gravity intensity
                // -------------------------------------------------

                let densityTerm =
                    min(
                        max(
                            density,
                            0.0
                        ),
                        1.0
                    )

                let sourceTerm =
                    min(
                        max(
                            qrtlSource,
                            0.0
                        ),
                        1.0
                    )

                let flowTerm =
                    flowMagnitude.isFinite
                    ? min(
                        max(
                            flowMagnitude /
                            (flowMagnitude + 1.0),
                            0.0
                        ),
                        1.0
                    )
                    : 0.0

                let magneticTerm =
                    magneticMagnitude.isFinite
                    ? min(
                        max(
                            magneticMagnitude /
                            (magneticMagnitude + 1.0),
                            0.0
                        ),
                        1.0
                    )
                    : 0.0

                let intensity =
                    0.55 * densityTerm +
                    0.25 * sourceTerm +
                    0.15 * flowTerm +
                    0.05 * magneticTerm

                if intensity.isFinite {

                    maximumIntensity =
                        max(
                            maximumIntensity,
                            intensity
                        )
                }
            }
        }

        // =========================================================
        // BUILD THE 3D CURVATURE SURFACE
        // =========================================================

        for j in 0..<n {

            for i in 0..<n {

                let x =
                    start +
                    Float(i) * step

                let z =
                    start +
                    Float(j) * step

                let base =
                    SIMD3<Float>(
                        x,
                        0.0,
                        z
                    )

                // -------------------------------------------------
                // CELLULAR-AUTOMATA MASS DENSITY
                // -------------------------------------------------

                let density =
                    field.normalizedDensity(
                        at: base
                    )

                // -------------------------------------------------
                // QRTL SOURCE
                // -------------------------------------------------

                let source =
                    field.qrtlSource(
                        at: base
                    )

                // -------------------------------------------------
                // BOLGARINO FLOW
                // -------------------------------------------------

                let flow =
                    field.bolgarinoFlux(
                        at: base
                    )

                let flowMagnitude =
                    simd_length(flow)

                let flowTerm =
                    flowMagnitude.isFinite
                    ? min(
                        max(
                            flowMagnitude /
                            (flowMagnitude + 1.0),
                            0.0
                        ),
                        1.0
                    )
                    : 0.0

                // -------------------------------------------------
                // MAGNETIC FIELD
                // -------------------------------------------------

                let magnetic =
                    field.magneticField(
                        at: base
                    )

                let magneticMagnitude =
                    simd_length(magnetic)

                let magneticTerm =
                    magneticMagnitude.isFinite
                    ? min(
                        max(
                            magneticMagnitude /
                            (magneticMagnitude + 1.0),
                            0.0
                        ),
                        1.0
                    )
                    : 0.0

                // -------------------------------------------------
                // COMBINED GRAVITY INTENSITY
                // -------------------------------------------------

                let densityTerm =
                    min(
                        max(
                            density,
                            0.0
                        ),
                        1.0
                    )

                let sourceTerm =
                    min(
                        max(
                            source,
                            0.0
                        ),
                        1.0
                    )

                let intensity =
                    0.55 * densityTerm +
                    0.25 * sourceTerm +
                    0.15 * flowTerm +
                    0.05 * magneticTerm

                // -------------------------------------------------
                // NORMALIZED INTENSITY
                // -------------------------------------------------

                let normalizedIntensity =
                    min(
                        max(
                            intensity /
                            maximumIntensity,
                            0.0
                        ),
                        1.0
                    )

                // -------------------------------------------------
                // QRTL SPACETIME CURVATURE
                //
                // This is the actual vertical deformation.
                //
                // The field determines the shape.
                // The color independently shows its intensity.
                // -------------------------------------------------

                let surfaceY =
                    field.spacetimeCurvatureHeight(
                        atXZ:
                            SIMD2<Float>(
                                base.x,
                                base.z
                            )
                    )

                // -------------------------------------------------
                // OPTIONAL INTENSITY MODULATION
                //
                // Keeps the visual surface tied to the same
                // density field without changing the actual
                // QRTL curvature calculation.
                // -------------------------------------------------

                let y =
                    surfaceY

                positions.append(
                    SCNVector3(
                        x,
                        y,
                        z
                    )
                )

                // -------------------------------------------------
                // GRAVITY COLOR
                //
                // 0.0 = weak field
                // 1.0 = strongest field
                //
                // Color progression:
                //
                // dark blue
                //     ↓
                // cyan
                //     ↓
                // green
                //     ↓
                // yellow
                //     ↓
                // red
                //
                // -------------------------------------------------

                let color =
                    gravityIntensityColor(
                        normalizedIntensity
                    )

                colors.append(color)

                // -------------------------------------------------
                // TEXTURE COORDINATES
                // -------------------------------------------------

                texcoords.append(
                    CGPoint(
                        x:
                            CGFloat(
                                Float(i) /
                                Float(n - 1)
                            ),
                        y:
                            CGFloat(
                                Float(j) /
                                Float(n - 1)
                            )
                    )
                )
            }
        }

        // =========================================================
        // TRIANGLE INDICES
        // =========================================================

        for j in 0..<(n - 1) {

            for i in 0..<(n - 1) {

                let idx =
                    Int32(
                        j * n + i
                    )

                indices.append(
                    contentsOf: [
                        idx,
                        idx + 1,
                        idx + Int32(n),

                        idx + 1,
                        idx + 1 + Int32(n),
                        idx + Int32(n)
                    ]
                )
            }
        }

        // =========================================================
        // GEOMETRY SOURCES
        // =========================================================

        let posSource =
            SCNGeometrySource(
                vertices:
                    positions
            )

        let colorData: Data = colors.withUnsafeBytes { buffer in
            Data(buffer)
        }

        let colorSource =
            SCNGeometrySource(
                data: colorData,
                semantic: .color,
                vectorCount: colors.count,
                usesFloatComponents: true,
                componentsPerVector: 4,
                bytesPerComponent: MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride: MemoryLayout<SIMD4<Float>>.stride
            )

        let uvSource =
            SCNGeometrySource(
                textureCoordinates:
                    texcoords
            )

        let element =
            SCNGeometryElement(
                indices:
                    indices,
                primitiveType:
                    .triangles
            )

        // =========================================================
        // CREATE GEOMETRY
        // =========================================================

        let geometry =
            SCNGeometry(
                sources: [
                    posSource,
                    colorSource,
                    uvSource
                ],
                elements: [
                    element
                ]
            )

        // =========================================================
        // MATERIAL
        // =========================================================

        let material =
            SCNMaterial()

        material.isDoubleSided =
            true

        material.lightingModel =
            .constant

        // ---------------------------------------------------------
        // If a heatmap is supplied, use it as the surface texture.
        // Otherwise use the vertex gravity colors.
        // ---------------------------------------------------------

        if let heatmap {

            material.diffuse.contents =
                heatmap

            material.emission.contents =
                heatmap

            material.lightingModel =
                .constant

        } else {

            material.diffuse.contents =
                UIColor.white

            material.shaderModifiers = [
                .surface: """
                _surface.diffuse = vec4(_geometry.color.rgb, 1.0);
                _surface.emission = vec4(_geometry.color.rgb, 1.0);
                """
            ]
            material.emission.contents =
                UIColor.white

            material.lightingModel =
                .constant
        }

        geometry.materials =
            [material]

        // =========================================================
        // CREATE SCENE NODE
        // =========================================================

        let node =
            SCNNode(
                geometry:
                    geometry
            )

        node.position =
            SCNVector3(
                frontPlaneX * 0.5,
                bottomY,
                0.0
            )

        node.name =
            "DeformedSpacetimeSurface"

        scene.rootNode.addChildNode(
            node
        )

        bottomPlaneNode =
            node
    }

    // =============================================================
    // GRAVITY INTENSITY COLOR
    // =============================================================

    private func gravityIntensityColor(
        _ value: Float
    ) -> SIMD4<Float> {

        let t =
            min(
                max(
                    value,
                    0.0
                ),
                1.0
            )

        // ---------------------------------------------------------
        // BLUE → CYAN → GREEN → YELLOW → RED
        // ---------------------------------------------------------

        if t < 0.25 {

            let u =
                t / 0.25

            return SIMD4<Float>(
                0.0,
                u,
                1.0,
                1.0
            )

        } else if t < 0.50 {

            let u =
                (t - 0.25) / 0.25

            return SIMD4<Float>(
                0.0,
                1.0,
                1.0 - u,
                1.0
            )

        } else if t < 0.75 {

            let u =
                (t - 0.50) / 0.25

            return SIMD4<Float>(
                u,
                1.0,
                0.0,
                1.0
            )

        } else {

            let u =
                (t - 0.75) / 0.25

            return SIMD4<Float>(
                1.0,
                1.0 - u,
                0.0,
                1.0
            )
        }
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

    // ============================================================
    // TRACE SOURCE GALAXY
    // ============================================================

    func traceSourceGalaxy(
        field: QRTLField,
        parameters: LensingParameters,
        progress: ((PhotonTraceProgress) -> Void)? = nil
    ) -> PhotonTraceBatch {

        let tracer =
            QRTLPhotonTracer(
                field: field
            )

        var traces:
            [PhotonTraceResult] = []

        var paths:
            [[SIMD3<Float>]] = []

        var hits:
            [LensingProjectionHit] = []

        traces.reserveCapacity(
            sourceGalaxyStars.count
        )

        paths.reserveCapacity(
            sourceGalaxyStars.count
        )

        hits.reserveCapacity(
            sourceGalaxyStars.count
        )

        // ============================================================
        // PROGRESS ACCUMULATION
        // ============================================================

        var totalPathPoints = 0

        var maximumQRTLInfluence:
            Float = 0.0

        let totalPhotons =
            sourceGalaxyStars.count

        // ============================================================
        // TRACE EVERY SOURCE GALAXY STAR
        // ============================================================

        for (sourceID, star)
            in sourceGalaxyStars.enumerated() {

            // --------------------------------------------------------
            // PHOTON ORIGIN
            // --------------------------------------------------------

            let origin =
                SIMD3<Float>(
                    star.position.x,
                    star.position.y,
                    star.position.z
                )

            // --------------------------------------------------------
            // INITIAL PHOTON DIRECTION
            //
            // Photons travel from the source galaxy toward
            // the QRTL lens along +X.
            // --------------------------------------------------------

            let direction =
                SIMD3<Float>(
                    1.0,
                    0.0,
                    0.0
                )

            // --------------------------------------------------------
            // TRACE PHOTON THROUGH QRTL FIELD
            // --------------------------------------------------------

            let trace =
                tracer.tracePhoton(
                    origin: origin,
                    direction: direction,
                    parameters: parameters
                )

            // --------------------------------------------------------
            // STORE TRACE
            // --------------------------------------------------------

            traces.append(
                trace
            )

            // --------------------------------------------------------
            // STORE COMPLETE PHOTON PATH
            // --------------------------------------------------------

            paths.append(
                trace.positions
            )

            totalPathPoints +=
                trace.positions.count

            // --------------------------------------------------------
            // TRACK MAXIMUM QRTL INFLUENCE
            // --------------------------------------------------------

            maximumQRTLInfluence =
                max(
                    maximumQRTLInfluence,
                    trace.maximumQRTLInfluence
                )

            // --------------------------------------------------------
            // CHECK PROJECTION PLANE
            // --------------------------------------------------------

            if let hit =
                makeProjectionHit(
                    from: trace,
                    sourceID: sourceID,
                    parameters: parameters
                ) {

                hits.append(
                    hit
                )
            }

            // ========================================================
            // REPORT LIVE PROGRESS
            // ========================================================

            progress?(
                PhotonTraceProgress(
                    total:
                        totalPhotons,

                    completed:
                        sourceID + 1,

                    pathPoints:
                        totalPathPoints,

                    maximumQRTLInfluence:
                        maximumQRTLInfluence
                )
            )
        }

        // ============================================================
        // RETURN COMPLETE PHOTON TRACE BATCH
        // ============================================================

        return PhotonTraceBatch(
            traces:
                traces,

            paths:
                paths,

            hits:
                hits
        )
    }
    private func makeProjectionHit(
        from trace: PhotonTraceResult,
        sourceID: Int,
        parameters: LensingParameters
    ) -> LensingProjectionHit? {

        // ============================================================
        // REQUIRE A VALID PROJECTION HIT
        // ============================================================

        guard trace.hitProjection,
              let point = trace.projectionPoint
        else {
            return nil
        }

        // ============================================================
        // CONVERT 2D PROJECTION COORDINATES → 3D
        //
        // SIMD2:
        //
        //     (Y, Z)
        //
        // becomes:
        //
        //     (X, Y, Z)
        //
        // where X is the configured projection plane.
        // ============================================================

        let coordinates3D: SIMD3<Float>?

        if let coordinates2D = trace.projectionCoordinates {

            coordinates3D = SIMD3<Float>(
                parameters.targetPlaneX,
                coordinates2D.x,
                coordinates2D.y
            )

        } else {

            coordinates3D = nil
        }

        // ============================================================
        // CREATE PROJECTION HIT
        // ============================================================

        return LensingProjectionHit(
            point: point,
            coordinates: coordinates3D,
            sourceCoordinates: trace.sourceCoordinates,
            direction: trace.finalDirection,
            traveledDistance: trace.traveledDistance,
            interactionCount: trace.interactionCount,
            maximumMagneticField:
                trace.maximumMagneticField,
            maximumQRTLInfluence:
                trace.maximumQRTLInfluence,
            maximumMagneticPhotonInfluence:
                trace.maximumMagneticPhotonInfluence,
            sourceID: sourceID
        )
    }
    private func makeRandomPhotonDirection(
        for star: SourceGalaxyStar
    ) -> SIMD3<Float> {

        let forward =
            SIMD3<Float>(
                1.0,
                0.0,
                0.0
            )

        let angle =
            Float.random(
                in: 0.0...(2.0 * .pi)
            )

        let spread =
            Float.random(
                in: 0.12...0.28
            )

        let transverse =
            SIMD3<Float>(
                0.0,
                cos(angle),
                sin(angle)
            )

        return simd_normalize(
            forward +
            transverse * spread
        )
    }
    private func projectionPlaneIntersection(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        parameters: LensingParameters
    ) -> SIMD3<Float>? {

        // ============================================================
        // PROJECTION PLANE
        // ============================================================
        //
        // The canonical projection plane is:
        //
        //     X = parameters.targetPlaneX
        //
        // Y/Z define the position on that plane.
        // ============================================================

        let planeX = parameters.targetPlaneX
        let halfExtent = parameters.projectionPlaneHalfExtent

        guard planeX.isFinite,
              halfExtent.isFinite,
              halfExtent > 0.0
        else {
            return nil
        }

        // ============================================================
        // VALIDATE SEGMENT ENDPOINTS
        // ============================================================

        guard start.x.isFinite,
              start.y.isFinite,
              start.z.isFinite,
              end.x.isFinite,
              end.y.isFinite,
              end.z.isFinite
        else {
            return nil
        }

        // ============================================================
        // X-DIRECTION OF PHOTON SEGMENT
        // ============================================================

        let dx = end.x - start.x

        guard dx.isFinite,
              abs(dx) > 0.000001
        else {
            return nil
        }

        // ============================================================
        // LINEAR INTERSECTION WITH X = planeX
        //
        // start + t(end - start)
        //
        // Solve:
        //
        //     start.x + t(end.x - start.x) = planeX
        // ============================================================

        let t =
            (planeX - start.x) / dx

        guard t.isFinite,
              t >= 0.0,
              t <= 1.0
        else {
            return nil
        }

        // ============================================================
        // CALCULATE INTERSECTION
        // ============================================================

        let intersection =
            start +
            (end - start) * t

        guard intersection.x.isFinite,
              intersection.y.isFinite,
              intersection.z.isFinite
        else {
            return nil
        }

        // ============================================================
        // PROJECTION PLANE BOUNDS
        //
        // The projection plane is bounded in Y/Z.
        // ============================================================

        guard abs(intersection.y) <= halfExtent,
              abs(intersection.z) <= halfExtent
        else {
            return nil
        }

        // ============================================================
        // FORCE EXACT PLANE X
        //
        // Prevent floating-point interpolation from leaving the
        // intersection microscopically off the projection plane.
        // ============================================================

        var result = intersection

        result.x = planeX

        return result
    }
    // ============================================================
    // DISPLAY PROJECTION HIT MARKERS (FIX #3 applied here)
    // ============================================================

    private func displayProjectionHits(
        _ hits: [LensingProjectionHit],
        planeHalfExtent: Float
    ) {
        projectionHitsNode?
            .removeFromParentNode()

        let hitsNode = SCNNode()
        hitsNode.name = "ProjectionHits"

        guard let projectionNode else {
            scene.rootNode.addChildNode(
                hitsNode
            )

            projectionHitsNode = hitsNode
            return
        }

        for hit in hits {
            let point = hit.point

            guard point.x.isFinite,
                  point.y.isFinite,
                  point.z.isFinite
            else {
                continue
            }

            let sphere = SCNSphere(
                radius: 0.035
            )

            sphere.firstMaterial =
                hitMarkerMaterial

            let marker = SCNNode(
                geometry: sphere
            )

            let worldPosition = SCNVector3(
                point.x,
                point.y,
                point.z
            )

            // hit.point is world space, but the marker becomes
            // a child of projectionNode, so it must use local space.
            marker.position =
                projectionNode.convertPosition(
                    worldPosition,
                    from: scene.rootNode
                )

            hitsNode.addChildNode(
                marker
            )
        }

        projectionNode.addChildNode(
            hitsNode
        )

        projectionHitsNode = hitsNode
    }
    // ============================================================
    // RENDER PROJECTION
    // ============================================================

    private func renderProjection(
        _ projection: LensingProjectionResult,
        projectionDistance: Float,
        projectionPlaneHalfExtent: Float
    ) {
        projectionNode?.removeFromParentNode()
        projectionNode = nil

        let plane = SCNPlane(
            width: CGFloat(
                projectionPlaneHalfExtent * 2.0
            ),
            height: CGFloat(
                projectionPlaneHalfExtent * 2.0
            )
        )

        let material = SCNMaterial()

        material.diffuse.contents =
            UIColor(
                white: 0.05,
                alpha: 0.90
            )

        material.emission.contents =
            UIColor(
                white: 0.05,
                alpha: 0.90
            )

        material.isDoubleSided = true
        material.lightingModel = .constant

        plane.firstMaterial = material

        let node = SCNNode(
            geometry: plane
        )

        node.name = "LensingProjectionPlane"

        // Photon integration and projectionPlaneIntersection()
        // use the plane x = projectionDistance.
        node.position = SCNVector3(
            projectionDistance,
            0.0,
            0.0
        )

        // SCNPlane starts in local X–Y. Rotate it to local Y–Z,
        // producing a plane with normal along the X optical axis.
        node.eulerAngles.y = .pi / 2.0

        scene.rootNode.addChildNode(
            node
        )

        projectionNode = node

        displayProjectionHits(
            projection.hits,
            planeHalfExtent: projectionPlaneHalfExtent
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

        // ============================================================
        // INITIAL STATE
        // ============================================================

        var position = origin

        let initialDirectionLength = simd_length(direction)

        guard
            initialDirectionLength.isFinite,
            initialDirectionLength > 1.0e-12
        else {
            return PhotonTraceResult(
                origin: origin,
                direction: .zero,
                positions: [origin],
                finalPosition: origin,
                finalDirection: .zero,
                hitProjection: false,
                projectionPoint: nil,
                projectionCoordinates: nil,
                stepCount: 0,
                traveledDistance: 0.0,
                maximumQRTLInfluence: 0.0,
                maximumMagneticField: 0.0,
                maximumMagneticPhotonInfluence: 0.0,
                sourceCoordinates: nil,
                interactionCount: 0
            )
        }

        var rayDirection =
            simd_normalize(direction)

        // ============================================================
        // PATH
        // ============================================================

        var positions: [SIMD3<Float>] = []

        positions.reserveCapacity(
            parameters.maximumPhotonSteps + 1
        )

        positions.append(position)

        // ============================================================
        // DIAGNOSTICS
        // ============================================================

        var stepCount = 0

        var traveledDistance: Float = 0.0

        var interactionCount = 0

        var maximumQRTLInfluence: Float = 0.0

        var maximumMagneticField: Float = 0.0

        var maximumMagneticPhotonInfluence: Float = 0.0

        // ============================================================
        // PROJECTION
        // ============================================================

        var hitProjection = false

        var projectionPoint: SIMD3<Float>? = nil

        var projectionCoordinates: SIMD2<Float>? = nil

        // ============================================================
        // STEP PARAMETERS
        // ============================================================

       let stepSize =
            Float(parameters.photonStepSize)
         
        

        let maximumRadius = max(
            Float(parameters.maximumPropagationRadius),
            stepSize
        )

        let maximumSteps =
            max(
                parameters.maximumPhotonSteps,
                1
            )

        // ============================================================
        // COUPLINGS
        // ============================================================

        let deflectionStrength = max(
            Float(parameters.deflectionStrength),
            0.0
        )

        // ============================================================
        // PHOTON PROPAGATION
        // ============================================================

        for step in 0..<maximumSteps {

            stepCount = step + 1

            // ========================================================
            // CURRENT POSITION
            // ========================================================

            let currentPosition = position


            // ========================================================
            // 4. QRTL LENSING ACCELERATION
            // ========================================================

            let acceleration =
                field.qrtlLensingAcceleration(
                    at: currentPosition,
                    direction: rayDirection
                )

            guard
                acceleration.x.isFinite,
                acceleration.y.isFinite,
                acceleration.z.isFinite
            else {
                break
            }

            // ========================================================
            // 5. TRANSVERSE QRTL ACCELERATION
            //
            // Remove the component parallel to the photon direction.
            // Only the transverse component bends the trajectory.
            // ========================================================

            let parallelComponent =
                simd_dot(
                    acceleration,
                    rayDirection
                )

            let transverseAcceleration =
                acceleration -
                rayDirection * parallelComponent

            guard
                transverseAcceleration.x.isFinite,
                transverseAcceleration.y.isFinite,
                transverseAcceleration.z.isFinite
            else {
                break
            }

            // ========================================================
            // 6. UPDATE PHOTON DIRECTION
            // ========================================================

            rayDirection +=
                transverseAcceleration *
                deflectionStrength *
                stepSize

            let directionLength =
                simd_length(rayDirection)

            guard
                directionLength.isFinite,
                directionLength > 1.0e-12
            else {
                break
            }

            rayDirection =
                simd_normalize(
                    rayDirection
                )

            // ========================================================
            // 7. INTERACTION COUNT
            // ========================================================

            let interactionMagnitude =
                simd_length(
                    transverseAcceleration
                )

            if interactionMagnitude.isFinite,
               interactionMagnitude > 1.0e-12 {

                interactionCount += 1
            }

            // ========================================================
            // 8. ADVANCE PHOTON
            // ========================================================

            let previousPosition =
                position

            position +=
                rayDirection *
                stepSize

            guard
                position.x.isFinite,
                position.y.isFinite,
                position.z.isFinite
            else {
                break
            }

            let actualStepDistance =
                simd_length(
                    position -
                    previousPosition
                )

            if actualStepDistance.isFinite {

                traveledDistance +=
                    actualStepDistance
            }

            positions.append(
                position
            )

            // ========================================================
            // 9. PROJECTION PLANE
            // ========================================================

            if !hitProjection {

                if let hit =
                    projectionIntersection(
                        previousPosition:
                            previousPosition,
                        currentPosition:
                            position,
                        parameters:
                            parameters
                    )
                {

                    hitProjection = true

                    projectionPoint =
                        hit.point

                    projectionCoordinates =
                        hit.coordinates
                }
            }

            // ========================================================
            // 10. PROPAGATION LIMIT
            // ========================================================

            if simd_length(position) >= maximumRadius {

                break
            }
        }

        // ============================================================
        // FINAL RESULT
        // ============================================================

        return PhotonTraceResult(

            origin:
                origin,

            direction:
                simd_normalize(direction),

            positions:
                positions,

            finalPosition:
                position,

            finalDirection:
                rayDirection,

            hitProjection:
                hitProjection,

            projectionPoint:
                projectionPoint,

            projectionCoordinates:
                projectionCoordinates,

            stepCount:
                stepCount,

            traveledDistance:
                traveledDistance,

            maximumQRTLInfluence:
                maximumQRTLInfluence,

            maximumMagneticField:
                maximumMagneticField,

            maximumMagneticPhotonInfluence:
                maximumMagneticPhotonInfluence,

            sourceCoordinates:
                nil,

            interactionCount:
                interactionCount
        )
    }
 
    private func projectionIntersection(
        previousPosition: SIMD3<Float>,
        currentPosition: SIMD3<Float>,
        parameters: LensingParameters
    ) -> (
        point: SIMD3<Float>,
        coordinates: SIMD2<Float>
    )? {

        // ============================================================
        // PROJECTION PLANE
        // ============================================================
        //
        // The projection plane is perpendicular to the X axis:
        //
        //     X = parameters.targetPlaneX
        //
        // The returned 2D projection coordinates are:
        //
        //     (Y, Z)
        // ============================================================

        let projectionX =
            parameters.targetPlaneX

        let halfExtent =
            parameters.projectionPlaneHalfExtent

        // ============================================================
        // VALIDATE PARAMETERS
        // ============================================================

        guard projectionX.isFinite,
              halfExtent.isFinite,
              halfExtent > 0.0
        else {
            return nil
        }

        // ============================================================
        // VALIDATE PHOTON POSITIONS
        // ============================================================

        guard previousPosition.x.isFinite,
              previousPosition.y.isFinite,
              previousPosition.z.isFinite,
              currentPosition.x.isFinite,
              currentPosition.y.isFinite,
              currentPosition.z.isFinite
        else {
            return nil
        }

        // ============================================================
        // X-AXIS SEGMENT
        // ============================================================

        let x0 =
            previousPosition.x

        let x1 =
            currentPosition.x

        let denominator =
            x1 - x0

        guard denominator.isFinite,
              abs(denominator) > 1.0e-8
        else {
            return nil
        }

        // ============================================================
        // LINEAR INTERSECTION
        //
        // previous + t(current - previous)
        //
        // Solve:
        //
        // previous.x +
        //     t(current.x - previous.x)
        //     =
        // projectionX
        // ============================================================

        let t =
            (projectionX - x0) /
            denominator

        guard t.isFinite,
              t >= 0.0,
              t <= 1.0
        else {
            return nil
        }

        // ============================================================
        // INTERSECTION POINT
        // ============================================================

        var point =
            previousPosition +
            (currentPosition - previousPosition) * t

        guard point.x.isFinite,
              point.y.isFinite,
              point.z.isFinite
        else {
            return nil
        }

        // ============================================================
        // FORCE EXACT PROJECTION X
        //
        // Removes small floating-point error from the interpolation.
        // ============================================================

        point.x =
            projectionX

        // ============================================================
        // PROJECTION-PLANE BOUNDS
        //
        // Y/Z define the 2D coordinates on the observation plane.
        // ============================================================

        guard abs(point.y) <= halfExtent,
              abs(point.z) <= halfExtent
        else {
            return nil
        }

        // ============================================================
        // 2D PROJECTION COORDINATES
        //
        // SIMD2:
        //
        //     x = world Y
        //     y = world Z
        // ============================================================

        let coordinates =
            SIMD2<Float>(
                point.y,
                point.z
            )

        return (
            point: point,
            coordinates: coordinates
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

}
