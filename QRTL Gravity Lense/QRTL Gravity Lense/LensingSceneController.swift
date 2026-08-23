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
import simd

final class LensingSceneController:
    ObservableObject {
    @State
    private var lensingParameters = LensingParameters()
     private var photonEmitterNode: SCNNode?
     private var projectionNode: SCNNode?
    @Published var qrtlField: QRTLField?
    private var photonTraceResults: [PhotonTraceResult] = []
    
    private var sceneToPhysicalScale: Float = 1.0
    
    private var sourceGalaxyPositions: [SIMD3<Float>] = []
    
    private var totalPhotonCount: Int = 0
    private var photonNodes: [SCNNode] = []
    private var continuousPhotonField: QRTLField?
    private var continuousPhotonParameters: LensingParameters?
    private var continuousPhotonSimulationRunning: Bool = false
    private var photonSimulationDisplayLink: CADisplayLink?
    private var lastPhotonSimulationTime: CFTimeInterval = 0.0
    private var photonEmissionAccumulator: Double = 0.0
    private var activePhotons: [ContinuousPhoton] = []
    
    private var activePhotonCount: Int = 0

    private var completedPhotonCount: Int = 0

    var projectionHitCount: Int = 0

    var continuousPhotonEmissionIndex: Int = 0

    var sceneSourceGalaxyPositions: [SIMD3<Float>] = []
    
    private var photonSimulationProgress =
        PhotonSimulationProgress(
            total: 0,
            completed: 0,
            active: 0,
            projectionHits: 0
        )


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
      
      
    }
    func setQRTLField(
        _ field: QRTLField
    ) {
        qrtlField = field
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
                curvatureScale: 1.0
            )

        qrtlGravitySurface =
            entity

        scene.rootNode.addChildNode(
            entity
        )
    }
    
    // ============================================================
    // MARK: - STOP CONTINUOUS PHOTON SIMULATION
    // ============================================================

    func stopContinuousPhotonSimulation() {

        // --------------------------------------------------------
        // Stop the display-link driven simulation loop.
        // --------------------------------------------------------

        photonSimulationDisplayLink?.invalidate()
        photonSimulationDisplayLink = nil

        // --------------------------------------------------------
        // Mark the continuous emitter as stopped.
        // --------------------------------------------------------

        continuousPhotonSimulationRunning = false

        // --------------------------------------------------------
        // Reset the emission clock/accumulator.
        //
        // This prevents the next simulation from inheriting
        // elapsed time from the previous run.
        // --------------------------------------------------------

        lastPhotonSimulationTime = 0.0
        photonEmissionAccumulator = 0.0

        // --------------------------------------------------------
        // Remove all photons that are still traveling.
        //
        // IMPORTANT:
        //
        // This stops the continuous stream immediately. It does
        // not modify the authoritative QRTLField.
        // --------------------------------------------------------

        activePhotons.removeAll()

        // --------------------------------------------------------
        // Reset the continuous-emission bookkeeping.
        // --------------------------------------------------------

        activePhotonCount = 0

        // --------------------------------------------------------
        // Keep completed/projection counters intact unless your
        // design specifically wants STOP to represent a complete
        // reset.
        //
        // Therefore we do NOT reset:
        //
        // completedPhotonCount
        // projectionHitCount
        //
        // Those represent what happened during the simulation.
        // --------------------------------------------------------

        // --------------------------------------------------------
        // Optional status update on the main thread.
        // --------------------------------------------------------

        DispatchQueue.main.async { [weak self] in

            guard let self else {
                return
            }

       
        }
    }
    // ============================================================
    // MARK: - PHOTON SIMULATION DISPLAY LINK TICK
    // ============================================================

    @objc
    private func photonSimulationDisplayLinkTick(
        _ displayLink: CADisplayLink
    ) {

        // ============================================================
        // SIMULATION RUNNING?
        // ============================================================

        guard continuousPhotonSimulationRunning else {
            return
        }

        // ============================================================
        // CURRENT DISPLAY-LINK TIME
        // ============================================================

        let currentTime =
            displayLink.timestamp

        // ============================================================
        // FIRST FRAME
        // ============================================================

        if lastPhotonSimulationTime == 0.0 {

            lastPhotonSimulationTime =
                currentTime

            return
        }

        // ============================================================
        // ELAPSED TIME
        // ============================================================

        let deltaTime =
            currentTime -
            lastPhotonSimulationTime

        lastPhotonSimulationTime =
            currentTime

        // ============================================================
        // CLAMP FRAME TIME
        // ============================================================

        let clampedDeltaTime =
            min(
                max(
                    deltaTime,
                    0.0
                ),
                1.0 / 20.0
            )

        // ============================================================
        // UPDATE CONTINUOUS PHOTON FIELD
        // ============================================================

        updateContinuousPhotonSimulation(
            deltaTime:
                clampedDeltaTime
        )
    }
    // ============================================================
    // MARK: - UPDATE CONTINUOUS PHOTON SIMULATION
    // ============================================================

    private func updateContinuousPhotonSimulation(
        deltaTime: CFTimeInterval
    ) {

        // ============================================================
        // SIMULATION RUNNING?
        // ============================================================

        guard continuousPhotonSimulationRunning else {
            return
        }

        // ============================================================
        // QRTL FIELD
        // ============================================================

        guard let field =
            continuousPhotonField
        else {
            return
        }

        // ============================================================
        // LENSING PARAMETERS
        // ============================================================

        guard let parameters =
            continuousPhotonParameters
        else {
            return
        }

        // ============================================================
        // 1. CONTINUOUS PHOTON EMISSION
        // ============================================================

        let emissionRate =
            max(
                parameters.photonEmissionRate,
                0.0
            )

        photonEmissionAccumulator +=
            Double(emissionRate) *
            deltaTime

        let photonsToEmit =
            Int(
                floor(
                    photonEmissionAccumulator
                )
            )

        if photonsToEmit > 0 {

            photonEmissionAccumulator -=
                Double(photonsToEmit)

            for _ in 0..<photonsToEmit {

                emitContinuousPhoton(
                    field:
                        field,
                    parameters:
                        parameters
                )
            }
        }

        // ============================================================
        // 2. NO ACTIVE PHOTONS
        // ============================================================

        guard !activePhotons.isEmpty else {

            activePhotonCount =
                0

            updateContinuousPhotonCounters()

            updateContinuousPhotonNodes()

            return
        }

        // ============================================================
        // 3. NEXT ACTIVE PHOTON ARRAY
        // ============================================================

        var photonsThatRemain:
            [ContinuousPhoton] = []

        photonsThatRemain.reserveCapacity(
            activePhotons.count
        )

        // ============================================================
        // 4. FRAME COMPLETION COUNTERS
        // ============================================================

        var completedThisFrame =
            0

        // ============================================================
        // 5. ADVANCE ACTIVE PHOTONS
        // ============================================================

        for var photon in activePhotons {

            // --------------------------------------------------------
            // Advance the photon through the physical QRTL field.
            // --------------------------------------------------------

            let photonContinues =
                advanceContinuousPhoton(
                    &photon,
                    field:
                        field,
                    parameters:
                        parameters,
                    deltaTime:
                        Float(deltaTime)
                )

            // --------------------------------------------------------
            // Photon reached the projection plane.
            // --------------------------------------------------------

            if photon.hitProjectionPlane {

                completedThisFrame += 1

                projectionHitCount += 1

                continue
            }

            // --------------------------------------------------------
            // Photon has reached a termination condition.
            // --------------------------------------------------------

            if !photonContinues ||
                !photon.alive {

                completedThisFrame += 1

                continue
            }

            // --------------------------------------------------------
            // Photon is still traveling through the QRTL field.
            // --------------------------------------------------------

            photonsThatRemain.append(
                photon
            )
        }

        // ============================================================
        // 6. REPLACE ACTIVE PHOTON ARRAY
        // ============================================================

        activePhotons =
            photonsThatRemain

        // ============================================================
        // 7. UPDATE COMPLETED PHOTON COUNT
        // ============================================================

        completedPhotonCount +=
            completedThisFrame

        // ============================================================
        // 8. UPDATE ACTIVE PHOTON COUNT
        // ============================================================

        activePhotonCount =
            activePhotons.count

        // ============================================================
        // 9. UPDATE PHOTON SIMULATION PROGRESS
        // ============================================================

        updateContinuousPhotonCounters()

        // ============================================================
        // 10. UPDATE SCENE NODES
        // ============================================================

        updateContinuousPhotonNodes()
    }
    // ============================================================
    // ADVANCE CONTINUOUS PHOTON
    // ============================================================

    private func advanceContinuousPhoton(
        _ photon: inout ContinuousPhoton,
        field: QRTLField,
        parameters: LensingParameters,
        deltaTime: Float
    ) -> Bool {

        // --------------------------------------------------------
        // PROPAGATION DISTANCE
        // --------------------------------------------------------

        let stepDistance =
            parameters.photonStepSize

        // --------------------------------------------------------
        // CURRENT PHOTON STATE
        // --------------------------------------------------------

        let position = photon.position
        let direction = simd_normalize(photon.direction)

        // --------------------------------------------------------
        // STOP CONDITIONS
        // --------------------------------------------------------

        let traveledDistance =
            photon.traveledDistance

        if traveledDistance >=
            parameters.maximumPropagationRadius {

            return false
        }

        if photon.stepCount >=
            parameters.maximumPhotonSteps {

            return false
        }

        // --------------------------------------------------------
        // PROJECTION PLANE
        //
        // The photon travels primarily in +X.
        // Detect crossing of the projection plane rather than
        // requiring the photon to land exactly on targetPlaneX.
        // --------------------------------------------------------

        let targetX =
            parameters.targetPlaneX

        let previousX =
            position.x

        // --------------------------------------------------------
        // QRTL LENSING ACCELERATION
        // --------------------------------------------------------

        let acceleration =
            field.qrtlLensingAcceleration(
                at: position,
                direction: direction
            )

        // --------------------------------------------------------
        // LIMIT THE BENDING CONTRIBUTION
        // --------------------------------------------------------

        let accelerationMagnitude =
            simd_length(acceleration)

        var bend =
            acceleration * parameters.qrtlLensingStrength

        if accelerationMagnitude > 0 {

            let maximumBend =
                parameters.maximumPhotonBend

            let bendMagnitude =
                simd_length(bend)

            if bendMagnitude > maximumBend {

                bend =
                    simd_normalize(bend) *
                    maximumBend
            }
        }

        // --------------------------------------------------------
        // UPDATE DIRECTION
        // --------------------------------------------------------

        var newDirection =
            direction + bend * deltaTime

        let newDirectionMagnitude =
            simd_length(newDirection)

        if newDirectionMagnitude > 0 {

            newDirection =
                simd_normalize(newDirection)

        } else {

            newDirection =
                direction
        }

        // --------------------------------------------------------
        // ADVANCE PHOTON
        // --------------------------------------------------------

        let newPosition =
            position +
            newDirection * stepDistance

        // --------------------------------------------------------
        // CHECK PROJECTION-PLANE CROSSING
        // --------------------------------------------------------

        let crossedProjectionPlane =
            previousX < targetX &&
            newPosition.x >= targetX

        if crossedProjectionPlane {

            // ----------------------------------------------------
            // Interpolate the exact projection-plane intersection.
            // ----------------------------------------------------

            let dx =
                newPosition.x - previousX

            var fraction: Float = 1.0

            if abs(dx) > 0.000001 {

                fraction =
                    (targetX - previousX) / dx
            }

            fraction =
                max(
                    0.0,
                    min(
                        fraction,
                        1.0
                    )
                )

            let projectionPosition =
                position +
                (newPosition - position) * fraction

            // ----------------------------------------------------
            // Store projection result.
            // ----------------------------------------------------

            photon.position =
                projectionPosition

            photon.direction =
                newDirection

            photon.traveledDistance +=
                stepDistance * fraction

            photon.stepCount += 1

            photon.hitProjectionPlane = true

            photon.projectionPosition =
                projectionPosition

            return false
        }

        // --------------------------------------------------------
        // STORE UPDATED PHOTON STATE
        // --------------------------------------------------------

        photon.position =
            newPosition

        photon.direction =
            newDirection

        photon.traveledDistance +=
            stepDistance

        photon.stepCount += 1

        photon.hitProjectionPlane = false

        // --------------------------------------------------------
        // CONTINUE PROPAGATION
        // --------------------------------------------------------

        return true
    }
    // ============================================================
    // UPDATE CONTINUOUS PHOTON NODES
    // ============================================================

    private func updateContinuousPhotonNodes() {

        // --------------------------------------------------------
        // Keep a node for every active photon.
        // --------------------------------------------------------

        for photon in activePhotons {

            guard let node = photon.node else {
                continue
            }

            // ----------------------------------------------------
            // Photon position
            // ----------------------------------------------------

            node.position = SCNVector3(
                photon.position.x,
                photon.position.y,
                photon.position.z
            )

            // ----------------------------------------------------
            // Make sure the photon is visible.
            // ----------------------------------------------------

            node.isHidden = false
        }

        // --------------------------------------------------------
        // Remove nodes belonging to photons that are no longer
        // active.
        //
        // This prevents completed photons from remaining visually
        // frozen in the SceneKit scene.
        // --------------------------------------------------------

        // ============================================================
        // SYNCHRONIZE PHOTON NODES WITH ACTIVE PHOTONS
        // ============================================================

        while photonNodes.count > activePhotons.count {

            let node = photonNodes.removeLast()

            node.removeFromParentNode()
        }

        // ------------------------------------------------------------
        // Create missing SceneKit nodes.
        // ------------------------------------------------------------

        while photonNodes.count < activePhotons.count {

            let node = SCNNode()

            let geometry = SCNSphere(
                radius: 0.015
            )

            node.geometry = geometry

            scene.rootNode.addChildNode(node)

            photonNodes.append(node)
        }
    }
    // ============================================================
    // UPDATE CONTINUOUS PHOTON COUNTERS
    // ============================================================

    private func updateContinuousPhotonCounters() {

        let activeCount = activePhotons.count

        photonSimulationProgress.active = activeCount
    }
    // ============================================================
    // MARK: - EMIT CONTINUOUS PHOTON
    // ============================================================

    private func emitContinuousPhoton(
        field: QRTLField,
        parameters: LensingParameters
    ) {

        // --------------------------------------------------------
        // Source galaxy must exist before photons can be emitted.
        // --------------------------------------------------------

        guard !sceneSourceGalaxyPositions.isEmpty else {
            return
        }

        // --------------------------------------------------------
        // Select the next source-galaxy star.
        //
        // This keeps emission distributed across the source galaxy
        // rather than creating every photon at one point.
        // --------------------------------------------------------

        let sourceIndex =
            continuousPhotonEmissionIndex %
            sceneSourceGalaxyPositions.count

        continuousPhotonEmissionIndex += 1

        let sourcePosition =
            sceneSourceGalaxyPositions[sourceIndex]

        // --------------------------------------------------------
        // Photon travels toward the QRTL lens / projection plane.
        //
        // Your source galaxy is positioned behind the lens, so
        // calculate the initial direction from the source position
        // toward the lens center.
        // --------------------------------------------------------

        let target =
            SIMD3<Float>(
                0.0,
                0.0,
                0.0
            )

        let directionVector =
            target -
            sourcePosition

        let directionLength =
            simd_length(directionVector)

        guard directionLength > 1e-6 else {
            return
        }

        let initialDirection =
            simd_normalize(directionVector)

        // --------------------------------------------------------
        // Create one continuous photon.
        // --------------------------------------------------------

        let photon = ContinuousPhoton(

            position:
                sourcePosition,

            direction:
                initialDirection,

            traveledDistance:
                0.0,
            stepCount:
                0,

            path:
                [sourcePosition],

        
            maximumQRTLInfluence:
                0.0,

            alive:
                true,

            hitProjectionPlane:
                false,

            projectionPosition:
                nil
        )
        // --------------------------------------------------------
        // Add photon to the live simulation.
        //
        // The photon will now be advanced by
        // updateContinuousPhotonSimulation().
        // --------------------------------------------------------

        activePhotons.append(
            photon
        )

        // --------------------------------------------------------
        // Update bookkeeping.
        // --------------------------------------------------------

        activePhotonCount =
            activePhotons.count

        totalPhotonCount += 1
    }
    private func startPhotonSimulationDisplayLink() {

        // Prevent multiple display links from being created.
        photonSimulationDisplayLink?.invalidate()
        photonSimulationDisplayLink = nil

        // Reset timing for the new simulation.
        lastPhotonSimulationTime = 0.0

        // Reset emission accumulator so the first frame starts clean.
        photonEmissionAccumulator = 0.0

        // Create the display-link callback.
        let displayLink = CADisplayLink(
            target: self,
            selector: #selector(
                photonSimulationDisplayLinkTick(_:)
            )
        )

        // Run continuously with the screen refresh.
        displayLink.add(
            to: .main,
            forMode: .common
        )

        photonSimulationDisplayLink = displayLink
    }
  
    // ============================================================
    // GENERATE GLOBULAR CLUSTER STAR POSITIONS
    // ============================================================
    //
    // Generates the physical 3D positions of the stars that make
    // up the globular cluster.
    //
    // These positions are used by:
    //   1. GlobularClusterDensityMap
    //   2. QRTLField
    //   3. Gravity-surface generation
    //   4. Source-photon generation
    //
    // The distribution is spherical and centrally concentrated.
    //
    // IMPORTANT:
    // These are REAL 3D positions. They are not a 2D visual-only
    // distribution and they are not all placed at the origin.
    // ============================================================

    func generateGlobularClusterStarPositions(
        starCount: Int,
        radiusMeters: Float
    ) -> [SIMD3<Float>] {

        guard starCount > 0 else {
            return []
        }

        guard radiusMeters.isFinite,
              radiusMeters > 0.0 else {
            return []
        }

        var positions:
            [SIMD3<Float>] = []

        positions.reserveCapacity(
            starCount
        )

        // ========================================================
        // RANDOM NUMBER GENERATOR
        // ========================================================

        var generator =
            SystemRandomNumberGenerator()

        // ========================================================
        // HELPER — UNIFORM RANDOM NUMBER
        // ========================================================

        func randomUnit() -> Float {

            return Float.random(
                in: 0.0...1.0,
                using: &generator
            )
        }

        // ========================================================
        // GENERATE SPHERICAL DIRECTION
        // ========================================================
        //
        // Uses an isotropic distribution over the sphere.
        //
        // z = cos(theta)
        //
        // phi = azimuth
        // ========================================================

        func randomDirection()
            -> SIMD3<Float> {

            let z =
                randomUnit() * 2.0 - 1.0

            let phi =
                randomUnit()
                * 2.0
                * Float.pi

            let radial =
                sqrt(
                    max(
                        0.0,
                        1.0 - z * z
                    )
                )

            return SIMD3<Float>(
                radial * cos(phi),
                radial * sin(phi),
                z
            )
        }

        // ========================================================
        // PLUMMER-LIKE RADIAL DISTRIBUTION
        // ========================================================
        //
        // We want substantially more stars toward the center.
        //
        // The inverse cumulative distribution for a Plummer model
        // can be written:
        //
        //     r = a / sqrt(u^(-2/3) - 1)
        //
        // where:
        //
        //     u = uniform random number
        //
        // The generated distribution is then truncated at the
        // requested cluster radius.
        //
        // ========================================================

        let scale =
            radiusMeters * 0.30

        // ========================================================
        // GENERATE STARS
        // ========================================================

        while positions.count < starCount {

            let u =
                max(
                    randomUnit(),
                    1.0e-6
                )

            let denominator =
                pow(
                    u,
                    -2.0 / 3.0
                ) - 1.0

            guard denominator > 0.0,
                  denominator.isFinite else {
                continue
            }

            let radius =
                scale /
                sqrt(
                    denominator
                )

            let maximumRadius =
                Float(radiusMeters)

            guard radius.isFinite,
                  radius >= 0.0,
                  radius <= maximumRadius
            else {
                continue
            }

            let direction =
                randomDirection()

            let position =
                direction *
                Float(radius)

            guard position.x.isFinite,
                  position.y.isFinite,
                  position.z.isFinite else {
                continue
            }

            positions.append(
                position
            )
        }

        return positions
    }

    // ============================================================
    // MARK: - CONTINUOUS PHOTON SIMULATION
    // ============================================================
    //
    // This is the single entry point for the photon pipeline.
    //
    // The controller owns:
    //     1. QRTL photon tracing
    //     2. authoritative PhotonTraceResult storage
    //     3. continuous trajectory visualization
    //     4. projection accumulation
    //
    // There is no second independent photon path generator.
    //
    // ============================================================

    func startContinuousPhotonSimulation(
        field: QRTLField,
        parameters: LensingParameters,
        progress: @escaping (PhotonSimulationProgress) -> Void
    ) {

        // ========================================================
        // STOP ANY PREVIOUS SIMULATION
        // ========================================================

        stopContinuousPhotonSimulation()

        // ========================================================
        // STORE AUTHORITATIVE FIELD
        // ========================================================

        self.qrtlField = field

        // ========================================================
        // CREATE THE AUTHORITATIVE PHOTON TRACER
        // ========================================================

        let tracer =
            QRTLPhotonTracer(
                field: field
            )

        // ========================================================
        // GET SOURCE-GALAXY POSITIONS
        // ========================================================

        let sources =
            sourceGalaxyPositions

        // ========================================================
        // INITIAL PROGRESS
        // ========================================================

        progress(
            PhotonSimulationProgress(
                total:
                    sources.count,

                completed:
                    0,

                active:
                    0,

                projectionHits:
                    0
            )
        )

        // ========================================================
        // TRACE PHOTONS
        // ========================================================

        var traces =
            [PhotonTraceResult]()

        traces.reserveCapacity(
            sources.count
        )

        let initialDirection =
            SIMD3<Float>(
                1.0,
                0.0,
                0.0
            )

        for sourcePosition in sources {

            let trace =
                tracer.tracePhoton(
                    origin:
                        sourcePosition,

                    direction:
                        initialDirection,

                    parameters:
                        parameters,

                      )

            // ====================================================
            // RETAIN ONLY VALID TRAJECTORIES
            // ====================================================

            guard
                trace.positions.count > 1
            else {
                continue
            }

            traces.append(
                trace
            )

            // ====================================================
            // UPDATE PROGRESS
            // ====================================================

            progress(
                PhotonSimulationProgress(
                    total:
                        sources.count,

                    completed:
                        traces.count,

                    active:
                        max(
                            0,
                            sources.count -
                            traces.count
                        ),

                    projectionHits:
                        traces.reduce(
                            into: 0
                        ) {
                            count,
                            trace in

                            if trace.hitProjection {
                                count += 1
                            }
                        }
                )
            )
        }

        // ========================================================
        // STORE AUTHORITATIVE TRACES
        // ========================================================
        //
        // These exact traces are now consumed by both:
        //
        //     photon visualization
        //
        // and
        //
        //     projection
        //
        // No second tracing pass is performed.
        // ========================================================

        photonTraceResults =
            traces

        // ========================================================
        // REMOVE PREVIOUS TRAJECTORY VISUALIZATION
        // ========================================================

        photonEmitterNode?
            .removeFromParentNode()

        photonEmitterNode =
            nil

        // ========================================================
        // CREATE VISUALIZATION FROM STORED TRAJECTORIES
        // ========================================================

        let emitter =
            createContinuousPhotonEmitter(
                traces:
                    traces
            )

        photonEmitterNode =
            emitter

        scene.rootNode.addChildNode(
            emitter
        )

        // ========================================================
        // CREATE PROJECTION FROM THE SAME TRAJECTORIES
        // ========================================================

        projectionNode?
            .removeFromParentNode()

        projectionNode =
            nil

        let projection =
            createProjectionFromPhotonTraces(
                traces
            )

        projectionNode =
            projection

        scene.rootNode.addChildNode(
            projection
        )

        // ========================================================
        // FINAL PROGRESS
        // ========================================================

        let projectionHitCount =
            traces.reduce(
                into: 0
            ) {
                count,
                trace in

                if trace.hitProjection {
                    count += 1
                }
            }

        progress(
            PhotonSimulationProgress(
                total:
                    sources.count,

                completed:
                    traces.count,

                active:
                    0,

                projectionHits:
                    projectionHitCount
            )
        )
    }
    // ============================================================
    // MARK: - PROJECTIVE MAP FROM AUTHORITATIVE PHOTON TRACES
    // ============================================================
    //
    // IMPORTANT:
    //
    // This function does NOT trace photons.
    //
    // The authoritative photon trajectories already exist in:
    //
    //     photonTraceResults
    //
    // Each trace contains the actual QRTL-calculated trajectory.
    //
    // This function examines the final trajectory position and
    // projects it onto the observation plane.
    //
    // Pipeline:
    //
    // QRTLPhotonTracer
    //        ↓
    // PhotonTraceResult
    //        ↓
    // createProjectionFromPhotonTraces(...)
    //        ↓
    // observation-plane positions
    //        ↓
    // projective visualization
    //
    // ============================================================

    private func createProjectionFromPhotonTraces(
        _ traces: [PhotonTraceResult]
    ) -> SCNNode {

        let projectionNode = SCNNode()

        // ========================================================
        // REMOVE OLD PROJECTION CONTENT
        // ========================================================

        projectionNode.childNodes.forEach {
            $0.removeFromParentNode()
        }

        // ========================================================
        // PROJECTION PARAMETERS
        // ========================================================
        //
        // The photon travels primarily along +X.
        //
        // Therefore:
        //
        //     X = depth / propagation direction
        //     Y = vertical projection coordinate
        //     Z = horizontal projection coordinate
        //
        // The observation plane is perpendicular to the X axis.
        // ========================================================

        let targetX: Float =
            Float(
                lensingParameters.targetPlaneX
            )

        // ========================================================
        // CREATE PROJECTED PHOTON POINTS
        // ========================================================

        for trace in traces {

            let positions = trace.positions

            guard positions.count > 1 else {
                continue
            }

            // ====================================================
            // FIND INTERSECTION WITH OBSERVATION PLANE
            // ====================================================
            //
            // We search the trajectory for the first segment that
            // crosses targetX.
            // ====================================================

            var projectionPosition:
                SIMD3<Float>? = nil

            for index in 1..<positions.count {

                let previous =
                    positions[index - 1]

                let current =
                    positions[index]

                let previousX =
                    previous.x

                let currentX =
                    current.x

                // =================================================
                // DIRECT HIT
                // =================================================

                if abs(
                    currentX - targetX
                ) < 1e-6 {

                    projectionPosition =
                        current

                    break
                }

                // =================================================
                // SEGMENT CROSSES TARGET PLANE
                // =================================================

                let crossesPlane =
                    (
                        previousX <= targetX &&
                        currentX >= targetX
                    )
                    ||
                    (
                        previousX >= targetX &&
                        currentX <= targetX
                    )

                guard crossesPlane else {
                    continue
                }

                let denominator =
                    currentX - previousX

                guard abs(denominator) > 1e-12 else {
                    continue
                }

                let fraction =
                    (
                        targetX -
                        previousX
                    ) /
                    denominator

                projectionPosition =
                    previous +
                    (
                        current -
                        previous
                    ) *
                    fraction

                break
            }

            // ====================================================
            // NO OBSERVATION-PLANE INTERSECTION
            // ====================================================

            guard let hit =
                projectionPosition
            else {
                continue
            }

            // ====================================================
            // CREATE PROJECTED PHOTON
            // ====================================================

            let photon = SCNNode()

            let geometry =
                SCNSphere(
                    radius: 0.035
                )

            let material =
                SCNMaterial()

            material.diffuse.contents =
                UIColor.white

            material.emission.contents =
                UIColor.white

            material.emission.intensity =
                1.0

            geometry.materials = [
                material
            ]

            photon.geometry =
                geometry

            // ====================================================
            // POSITION ON OBSERVATION PLANE
            // ====================================================

            photon.position =
                SCNVector3(
                    hit.x,
                    hit.y,
                    hit.z
                )

            projectionNode.addChildNode(
                photon
            )
        }

        // ========================================================
        // CREATE OBSERVATION PLANE
        // ========================================================
        //
        // The plane itself is intentionally subtle.
        //
        // The actual projected photons are the important output.
        // ========================================================

        let planeSize: CGFloat =
            8.0

        let planeGeometry =
            SCNPlane(
                width: planeSize,
                height: planeSize
            )

        let planeMaterial =
            SCNMaterial()

        planeMaterial.diffuse.contents =
            UIColor.clear

        planeMaterial.emission.contents =
            UIColor.clear

        planeMaterial.isDoubleSided =
            true

        planeMaterial.transparency =
            0.0

        planeGeometry.materials = [
            planeMaterial
        ]

        let observationPlane =
            SCNNode(
                geometry:
                    planeGeometry
            )

        // ========================================================
        // SCNPlane DEFAULT ORIENTATION
        // ========================================================
        //
        // SCNPlane lies in the XY plane.
        //
        // Rotate it so its normal is aligned with the X axis.
        // ========================================================

        observationPlane.eulerAngles =
            SCNVector3(
                0.0,
                Float.pi / 2.0,
                0.0
            )

        observationPlane.position =
            SCNVector3(
                targetX,
                0.0,
                0.0
            )

        projectionNode.addChildNode(
            observationPlane
        )

        return projectionNode
    }
    // ============================================================
    // MARK: - CONTINUOUS PHOTON EMITTER
    // ============================================================
    //
    // IMPORTANT:
    //
    // This function does NOT calculate photon physics.
    //
    // QRTLPhotonTracer has already calculated each trajectory.
    //
    // This function only converts those stored trajectories into
    // SceneKit animations.
    //
    // Pipeline:
    //
    // sourceGalaxyPositions
    //        ↓
    // QRTLPhotonTracer.tracePhoton(...)
    //        ↓
    // PhotonTraceResult.positions
    //        ↓
    // photonTraceResults
    //        ↓
    // createContinuousPhotonEmitter(...)
    //        ↓
    // SceneKit visualization
    //
    // There is NO second photon integration here.
    // ============================================================

    private func createContinuousPhotonEmitter(
        traces: [PhotonTraceResult]
    ) -> SCNNode {

        let emitterNode = SCNNode()

        // ========================================================
        // EACH TRACE REPRESENTS ONE PHOTON
        // ========================================================

        for trace in traces {

            let positions = trace.positions

            guard positions.count > 1 else {
                continue
            }

            // ====================================================
            // CREATE VISUAL PHOTON NODE
            // ====================================================

            let photonNode = SCNNode()

            // ====================================================
            // CONVERT STORED TRAJECTORY INTO KEYFRAMES
            // ====================================================
            //
            // Every position here came directly from
            // QRTLPhotonTracer.
            //
            // Therefore the animation follows the actual
            // calculated QRTL trajectory rather than a new
            // straight-line path.
            // ====================================================

            var keyTimes = [NSNumber]()
            var values = [NSValue]()

            let count = positions.count

            keyTimes.reserveCapacity(count)
            values.reserveCapacity(count)

            for index in 0..<count {

                let fraction =
                    Float(index) /
                    Float(max(1, count - 1))

                keyTimes.append(
                    NSNumber(
                        value: fraction
                    )
                )

                let position = positions[index]

                values.append(
                    NSValue(
                        scnVector3: SCNVector3(
                            position.x,
                            position.y,
                            position.z
                        )
                    )
                )
            }

            // ====================================================
            // CREATE STORED-TRAJECTORY ANIMATION
            // ====================================================

            let animation = CAKeyframeAnimation(
                keyPath: "position"
            )

            animation.values = values
            animation.keyTimes = keyTimes

            // ====================================================
            // TRAJECTORY TIMING
            // ====================================================
            //
            // count points contain count - 1 integration segments.
            //
            // Each segment corresponds approximately to the
            // configured photon step size.
            // ====================================================

            let segmentCount =
                max(
                    1,
                    count - 1
                )

            animation.duration =
                Double(segmentCount) *
                Double(
                    lensingParameters.photonStepSize
                )

            animation.repeatCount = .infinity

            animation.calculationMode = .linear

            // ====================================================
            // INITIAL POSITION
            // ====================================================

            if let first = positions.first {

                photonNode.position =
                    SCNVector3(
                        first.x,
                        first.y,
                        first.z
                    )
            }

            // ====================================================
            // PHOTON GEOMETRY
            // ====================================================

            let geometry = SCNSphere(
                radius: 0.025
            )

            let material = SCNMaterial()

            material.diffuse.contents =
                UIColor.white

            material.emission.contents =
                UIColor.white

            material.emission.intensity =
                1.0

            geometry.materials = [
                material
            ]

            photonNode.geometry =
                geometry

            // ====================================================
            // START STORED QRTL TRAJECTORY
            // ====================================================

            photonNode.addAnimation(
                animation,
                forKey:
                    "QRTLPhotonTrajectory"
            )

            // ====================================================
            // ADD PHOTON TO EMITTER
            // ====================================================

            emitterNode.addChildNode(
                photonNode
            )
        }

        // ========================================================
        // RETURN COMPLETE PHOTON VISUALIZATION
        // ========================================================

        return emitterNode
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

    func addDeformedSpacetimeSurface(
        field: QRTLField,
        heatmap: UIImage? = nil
    ) {
        // =========================================================
        // REMOVE PREVIOUS SURFACE
        // =========================================================

        bottomPlaneNode?.removeFromParentNode()

        // =========================================================
        // VISUALIZATION GRID
        //
        // Keep the physics/radial lookup resolution independent
        // from the SceneKit surface resolution.
        //
        // 64 x 64 = 4,096 vertices
        // 63 x 63 x 2 = 7,938 triangles
        // =========================================================

        let n: Int =
            resolution > 4
            ? min(resolution, 64)
            : 32

        guard n >= 2 else {
            return
        }

        let extent = heatmapHalfExtent
        let vertexCount = n * n
        let cellCount = (n - 1) * (n - 1)

        let start = -extent
        let step =
            (2.0 * extent) /
            Float(n - 1)

        // =========================================================
        // GEOMETRY STORAGE
        // =========================================================

        var positions = [SCNVector3]()
        var colors = [SIMD4<Float>]()
        var texcoords = [CGPoint]()
        var indices = [Int32]()

        positions.reserveCapacity(vertexCount)
        colors.reserveCapacity(vertexCount)
        texcoords.reserveCapacity(vertexCount)
        indices.reserveCapacity(cellCount * 6)

        // =========================================================
        // COLOR INTENSITY CACHE
        // =========================================================

        var intensityCache = [Float](
            repeating: 0.0,
            count: vertexCount
        )

        // =========================================================
        // PASS 1
        //
        // Calculate visualization intensity once per vertex
        // using the precomputed radial lookup tables.
        //
        // This pass does NOT calculate gravitational curvature.
        // =========================================================

        var maximumIntensity: Float = 0.000001

        for j in 0..<n {

            let z =
                start +
                Float(j) * step

            let rowOffset =
                j * n

            for i in 0..<n {

                let x =
                    start +
                    Float(i) * step

                let position =
                    SIMD3<Float>(
                        x,
                        0.0,
                        z
                    )

                // -------------------------------------------------
                // RADIAL DISTANCE (shared by all lookups)
                // -------------------------------------------------

                let radiusSquared =
                    x * x +
                    z * z

                let radius =
                    Double(
                        sqrt(
                            max(
                                0.0,
                                radiusSquared
                            )
                        )
                    )

                // -------------------------------------------------
                // DENSITY  (radial table)
                // -------------------------------------------------

                let density =
                    field.interpolateRadialNormalizedDensity(
                        radius: radius
                    )

                let densityTerm =
                    density.isFinite
                    ? max(
                        0.0,
                        min(
                            Float(density),
                            1.0
                        )
                    )
                    : 0.0

                // -------------------------------------------------
                // QRTL SOURCE  (radial table)
                // -------------------------------------------------

                let qrtlSource =
                    field.interpolateRadialSource(
                        radius: radius
                    )

                let sourceValue =
                    Float(qrtlSource)

                let sourceTerm =
                    sourceValue.isFinite
                    ? max(
                        0.0,
                        min(
                            sourceValue,
                            1.0
                        )
                    )
                    : 0.0

                // -------------------------------------------------
                // BOLGARINO FLOW  (radial table)
                // -------------------------------------------------

                let flow =
                    field.interpolateRadialFlux(
                        radius: radius
                    )

                let flowMagnitude =
                    flow.isFinite
                    ? abs(
                        Float(flow)
                    )
                    : 0.0

                let flowTerm =
                    flowMagnitude /
                    (flowMagnitude + 1.0)

                // -------------------------------------------------
                // MAGNETIC FIELD  (radial magnitude + geometric direction)
                // -------------------------------------------------

                let magnetic =
                    field.interpolateRadialMagneticField(
                        at: position
                    )

                let magneticSquared =
                    dot(
                        magnetic,
                        magnetic
                    )

                let magneticMagnitude =
                    magneticSquared.isFinite
                    ? sqrt(
                        max(
                            0.0,
                            magneticSquared
                        )
                    )
                    : 0.0

                let magneticTerm =
                    magneticMagnitude /
                    (magneticMagnitude + 1.0)

                // -------------------------------------------------
                // VISUALIZATION INTENSITY
                // -------------------------------------------------

                let intensity =
                    (0.55 * densityTerm) +
                    (0.25 * sourceTerm) +
                    (0.15 * flowTerm) +
                    (0.05 * magneticTerm)

                let safeIntensity =
                    intensity.isFinite
                    ? intensity
                    : 0.0

                let index =
                    rowOffset + i

                intensityCache[index] =
                    safeIntensity

                if safeIntensity > maximumIntensity {
                    maximumIntensity =
                        safeIntensity
                }
            }
        }

        // =========================================================
        // GRAVITY → SURFACE HEIGHT
        //
        // h = (-2 Phi / c²) × scale
        //
        // Precompute the constant multiplier once.
        // =========================================================

        let speedOfLightSquared =
            299_792_458.0 *
            299_792_458.0

        let spacetimeHeightScale =
            1.0e6

        let curvatureScale =
            -2.0 *
            spacetimeHeightScale /
            speedOfLightSquared

        // =========================================================
        // PASS 2
        //
        // BUILD SURFACE VERTICES
        //
        // Gravity path:
        //
        // x,z
        //  ↓
        // radius
        //  ↓
        // radialGravityTable
        //  ↓
        // interpolateRadialPotential()
        //  ↓
        // weak-field curvature
        //  ↓
        // SceneKit Y
        //
        // NO radial integration occurs here.
        // =========================================================

        for j in 0..<n {

            let z =
                start +
                Float(j) * step

            let v =
                CGFloat(j) /
                CGFloat(n - 1)

            let rowOffset =
                j * n

            for i in 0..<n {

                let x =
                    start +
                    Float(i) * step

                let u =
                    CGFloat(i) /
                    CGFloat(n - 1)

                // -------------------------------------------------
                // RADIAL DISTANCE
                // -------------------------------------------------

                let radiusSquared =
                    x * x +
                    z * z

                let radius =
                    sqrt(
                        max(
                            0.0,
                            radiusSquared
                        )
                    )

                // -------------------------------------------------
                // RADIAL POTENTIAL LOOKUP
                // -------------------------------------------------

                let potential =
                    field.interpolateRadialPotential(
                        radius: Double(radius)
                    )

                // -------------------------------------------------
                // POTENTIAL → CURVATURE HEIGHT
                // -------------------------------------------------

                let curvatureHeight =
                    potential.isFinite
                    ? potential * curvatureScale
                    : 0.0

                let y =
                    curvatureHeight.isFinite
                    ? Float(curvatureHeight)
                    : 0.0

                // -------------------------------------------------
                // POSITION
                // -------------------------------------------------

                positions.append(
                    SCNVector3(
                        x,
                        y,
                        z
                    )
                )

                // -------------------------------------------------
                // COLOR
                // -------------------------------------------------

                let index =
                    rowOffset + i

                let intensity =
                    intensityCache[index]

                let normalizedIntensity =
                    maximumIntensity > 0.0
                    ? max(
                        0.0,
                        min(
                            intensity /
                            maximumIntensity,
                            1.0
                        )
                    )
                    : 0.0

                colors.append(
                    gravityIntensityColor(
                        normalizedIntensity
                    )
                )

                // -------------------------------------------------
                // UV
                // -------------------------------------------------

                texcoords.append(
                    CGPoint(
                        x: u,
                        y: v
                    )
                )
            }
        }

        // =========================================================
        // TRIANGLE INDICES
        // =========================================================

        for j in 0..<(n - 1) {

            let row =
                j * n

            let nextRow =
                row + n

            for i in 0..<(n - 1) {

                let base =
                    Int32(row + i)

                let right =
                    base + 1

                let bottom =
                    Int32(nextRow + i)

                let bottomRight =
                    bottom + 1

                indices.append(base)
                indices.append(right)
                indices.append(bottom)

                indices.append(right)
                indices.append(bottomRight)
                indices.append(bottom)
            }
        }

        // =========================================================
        // POSITION SOURCE
        // =========================================================

        let positionSource =
            SCNGeometrySource(
                vertices: positions
            )

        // =========================================================
        // COLOR SOURCE
        // =========================================================

        let colorData =
            colors.withUnsafeBytes { buffer in
                Data(buffer)
            }

        let colorSource =
            SCNGeometrySource(
                data: colorData,
                semantic: .color,
                vectorCount: colors.count,
                usesFloatComponents: true,
                componentsPerVector: 4,
                bytesPerComponent:
                    MemoryLayout<Float>.size,
                dataOffset: 0,
                dataStride:
                    MemoryLayout<SIMD4<Float>>.stride
            )

        // =========================================================
        // UV SOURCE
        // =========================================================

        let uvSource =
            SCNGeometrySource(
                textureCoordinates: texcoords
            )

        // =========================================================
        // ELEMENT
        // =========================================================

        let element =
            SCNGeometryElement(
                indices: indices,
                primitiveType: .triangles
            )

        // =========================================================
        // GEOMETRY
        // =========================================================

        let geometry =
            SCNGeometry(
                sources: [
                    positionSource,
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

        material.isDoubleSided = true
        material.lightingModel = .constant

        if let heatmap {

            material.diffuse.contents =
                heatmap

            material.emission.contents =
                heatmap

        } else {

            material.diffuse.contents =
                UIColor.white

            material.emission.contents =
                UIColor.white

            material.shaderModifiers = [
                .surface: """
                _surface.diffuse =
                    vec4(_geometry.color.rgb, 1.0);

                _surface.emission =
                    vec4(_geometry.color.rgb, 1.0);
                """
            ]
        }

        geometry.materials = [
            material
        ]

        // =========================================================
        // CREATE NODE
        // =========================================================

        let node =
            SCNNode(
                geometry: geometry
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
        _ output: LensingPipelineOutput,
        showPhotonPaths: Bool,
        projectionDistance: Float = 10.0,
        projectionPlaneHalfExtent: Float = 12.0
    ) {

        // ========================================================
        // STORE COMPLETE PIPELINE OUTPUT
        // ========================================================

        lastPipelineOutput = output

        // ========================================================
        // CLEAR OLD PHOTON PATHS
        // ========================================================
        //
        // Removes paths from any previous pipeline run.
        //
        // ========================================================

        clearPhotonPaths()

        // ========================================================
        // DISPLAY QRTL PHOTON PATHS
        // ========================================================
        //
        // The photon trajectories have already been calculated by:
        //
        //     QRTLField
        //         ↓
        //     QRTLPhotonTracer
        //         ↓
        //     tracePhoton()
        //         ↓
        //     traceSourceGalaxy()
        //         ↓
        //     photonBatch.paths
        //         ↓
        //     output.photonPaths
        //
        // This function ONLY renders those positions.
        //
        // It does NOT:
        //
        //     - calculate gravity
        //     - calculate EM bending
        //     - calculate index gradients
        //     - calculate geodesics
        //     - modify photon positions
        //     - generate another photon path
        //
        // ========================================================

        if showPhotonPaths {
            displayPhotonPaths(
                output.photonPaths
            )
        }

        // ========================================================
        // RENDER PROJECTION
        // ========================================================
        //
        // Use the supplied rendering parameters rather than
        // hard-coded values.
        //
        // ========================================================

        renderProjection(
            output.projection,
            projectionDistance:
                projectionDistance,
            projectionPlaneHalfExtent:
                projectionPlaneHalfExtent
        )

        // ========================================================
        // DISPLAY PROJECTION HITS
        // ========================================================
        //
        // The projection hit's `point` is its SceneKit position.
        //
        // ========================================================

        displayProjectionHits(
            output.projection.hits,
            planeHalfExtent:
                projectionPlaneHalfExtent
        )

        // ========================================================
        // POSITION PROJECTION PLANE
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

    // ============================================================
    // MARK: - EXISTING SOURCE GALAXY POSITION GENERATOR
    // ============================================================
    //
    // Generates the source-galaxy star positions used by the
    // authoritative photon pipeline.
    //
    // Coordinate convention:
    //
    //     X = photon propagation direction
    //     Y/Z = source-galaxy image plane
    //
    // The returned positions are SceneKit coordinates.
    //
    // IMPORTANT:
    // - This function does NOT create photons.
    // - This function does NOT trace photons.
    // - This function does NOT apply gravitational lensing.
    // - The QRTLPhotonTracer applies the QRTL field later.
    // ============================================================

    private func generateYourExistingSourceGalaxyPositions(
        starCount: Int = 220
    ) -> [SIMD3<Float>] {

        guard starCount > 0 else {
            return []
        }

        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(starCount)

        // --------------------------------------------------------
        // SOURCE GALAXY LOCATION
        // --------------------------------------------------------
        //
        // X is the photon travel direction.
        // The source galaxy is therefore placed behind the lens.
        //
        let sourceX: Float = -8.0

        // --------------------------------------------------------
        // GALAXY DIMENSIONS
        // --------------------------------------------------------

        let majorRadius: Float = 2.8
        let minorRadius: Float = 1.15

        // --------------------------------------------------------
        // DETERMINISTIC DISTRIBUTION
        // --------------------------------------------------------
        //
        // Using the golden angle avoids random clustering while
        // producing a visually natural spiral distribution.
        //
        let goldenAngle =
            Float.pi * (3.0 - sqrt(5.0))

        // --------------------------------------------------------
        // CENTRAL BULGE
        // --------------------------------------------------------
        //
        // A fraction of the stars are concentrated toward the
        // center of the galaxy.
        //
        let bulgeFraction = 0.20
        let bulgeCount = Int(
            Float(starCount) * Float(bulgeFraction)
        )

        if bulgeCount > 0 {

            for i in 0..<bulgeCount {

                let t =
                    Float(i) /
                    Float(max(bulgeCount - 1, 1))

                let radius =
                    0.20 +
                    0.75 * sqrt(t)

                let angle =
                    Float(i) * goldenAngle

                let y =
                    radius *
                    0.55 *
                    cos(angle)

                let z =
                    radius *
                    0.55 *
                    sin(angle)

                positions.append(
                    SIMD3<Float>(
                        sourceX,
                        y,
                        z
                    )
                )
            }
        }

        // --------------------------------------------------------
        // SPIRAL DISK
        // --------------------------------------------------------

        let diskCount =
            starCount - bulgeCount

        if diskCount > 0 {

            for i in 0..<diskCount {

                let t =
                    Float(i) /
                    Float(max(diskCount - 1, 1))

                // Concentrate more stars toward the inner disk.
                let radialFraction =
                    pow(t, 0.72)

                let radius =
                    majorRadius *
                    radialFraction

                // Two-arm spiral structure.
                let spiralTurns: Float = 2.15

                let baseAngle =
                    Float(i) *
                    goldenAngle

                let spiralAngle =
                    baseAngle +
                    radialFraction *
                    spiralTurns *
                    2.0 *
                    Float.pi

                // Elliptical disk.
                let y =
                    radius *
                    cos(spiralAngle)

                let z =
                    minorRadius *
                    radialFraction *
                    sin(spiralAngle)

                // Small vertical thickness.
                //
                // Deterministic pseudo-thickness rather than random
                // values so repeated pipeline runs produce the same
                // source galaxy.
                let thicknessPhase =
                    Float(i) * 1.6180339887

                let verticalOffset =
                    0.08 *
                    sin(thicknessPhase)

                positions.append(
                    SIMD3<Float>(
                        sourceX,
                        y,
                        z + verticalOffset
                    )
                )
            }
        }

        return positions
    }
    func addSourceGalaxy() {

        // ========================================================
        // CLEAR PREVIOUS SOURCE GALAXY
        // ========================================================

        sourceGalaxyPositions.removeAll(
            keepingCapacity: true
        )

        // Remove your existing source-galaxy visual node here
        // using the node/property already present in your
        // LensingSceneController.
        //
        // Example only if your existing controller has this node:
        //
        // sourceGalaxyNode?.removeFromParentNode()
        // sourceGalaxyNode = SCNNode()
        //
        // DO NOT add a new node property if your current
        // implementation already has one.

        // ========================================================
        // GENERATE SOURCE GALAXY POSITIONS
        // ========================================================
        //
        // IMPORTANT:
        //
        // Replace `generatedPositions` below with the exact
        // position-generation code already used by your current
        // addSourceGalaxy().
        //
        // The critical requirement is that the positions used
        // to render the visible stars are ALSO stored in
        // sourceGalaxyPositions.
        // ========================================================

        let generatedPositions: [SIMD3<Float>] =
            generateYourExistingSourceGalaxyPositions()

        // ========================================================
        // STORE + RENDER THE SAME POSITIONS
        // ========================================================

        for position in generatedPositions {

            // ----------------------------------------------------
            // AUTHORITATIVE PHOTON ORIGIN
            // ----------------------------------------------------

            sourceGalaxyPositions.append(
                position
            )

            // ----------------------------------------------------
            // EXISTING VISUAL STAR CREATION
            // ----------------------------------------------------
            //
            // Use your existing star geometry/material here.
            // The visual star MUST use the exact same `position`.
            //

            let starNode =
                SCNNode()

            starNode.position =
                SCNVector3(
                    position.x,
                    position.y,
                    position.z
                )

            // Your existing star geometry goes here.
            //
            // starNode.geometry = ...

            scene.rootNode.addChildNode(
                starNode
            )
        }
    }

    // ============================================================
    // MARK: - GENERATE SOURCE GALAXY POSITIONS
    // ============================================================
    //
    // Creates the physical source-star positions used by the
    // authoritative photon pipeline.
    //
    // IMPORTANT:
    //
    // These positions are stored in sourceGalaxyPositions.
    //
    // Later:
    //
    // sourceGalaxyPositions
    //        ↓
    // QRTLPhotonTracer
    //        ↓
    // PhotonTraceResult
    //        ↓
    // continuous photon emitter
    //        ↓
    // projection
    //
    // No photon is created here.
    // This function ONLY creates source positions.
    // ============================================================

    private func generateSourceGalaxyPositions(
        starCount: Int = 220,
        radius: Float = 2.5
    ) -> [SIMD3<Float>] {

        guard starCount > 0 else {
            return []
        }

        var positions = [SIMD3<Float>]()

        positions.reserveCapacity(starCount)

        // ========================================================
        // SOURCE GALAXY PLANE
        // ========================================================
        //
        // Photons travel primarily in +X.
        //
        // Therefore the source galaxy is distributed in the Y-Z
        // plane.
        //
        // X = source depth
        // Y = vertical galaxy coordinate
        // Z = horizontal galaxy coordinate
        //
        // The small negative X offset places the source galaxy
        // behind the gravitational lens relative to the photon
        // propagation direction.
        // ========================================================

        let sourceX: Float = -8.0

        // ========================================================
        // DETERMINISTIC DISTRIBUTION
        // ========================================================
        //
        // Use a golden-angle spiral rather than random positions.
        //
        // This makes the source galaxy reproducible every time
        // the simulation runs.
        // ========================================================

        let goldenAngle =
            Float.pi *
            (3.0 - sqrt(5.0))

        for index in 0..<starCount {

            let fraction =
                Float(index) /
                Float(max(1, starCount - 1))

            // ====================================================
            // RADIAL DISTRIBUTION
            // ====================================================
            //
            // sqrt(fraction) gives approximately uniform area
            // density while still allowing a concentrated center
            // when combined with the falloff below.
            // ====================================================

            let radialFraction =
                sqrt(fraction)

            let radialDistance =
                radius *
                radialFraction

            let angle =
                Float(index) *
                goldenAngle

            // ====================================================
            // SPIRAL / GALAXY STRUCTURE
            // ====================================================

            let armWave =
                sin(
                    angle * 2.5
                )

            let armOffset =
                0.18 *
                armWave

            let effectiveRadius =
                radialDistance *
                (
                    1.0 +
                    armOffset
                )

            // ====================================================
            // Y-Z GALAXY PLANE
            // ====================================================

            let y =
                cos(angle) *
                effectiveRadius

            let z =
                sin(angle) *
                effectiveRadius

            // ====================================================
            // CENTRAL CONCENTRATION
            // ====================================================

            let centerWeight =
                1.0 -
                0.25 *
                radialFraction

            let finalY =
                y *
                centerWeight

            let finalZ =
                z *
                centerWeight

            positions.append(
                SIMD3<Float>(
                    sourceX,
                    finalY,
                    finalZ
                )
            )
        }

        return positions
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
 

    func displayPhotonPaths(
        _ paths: [[SIMD3<Float>]]
    ) {

        // ------------------------------------------------------------
        // Remove previously rendered photon paths.
        // ------------------------------------------------------------

        clearPhotonPaths()

        // ------------------------------------------------------------
        // Render only photon trajectories already calculated by
        // QRTLField / QRTLPhotonTracer.
        // ------------------------------------------------------------

        for path in paths {

            guard path.count >= 2 else {
                continue
            }

            // --------------------------------------------------------
            // Convert traced QRTL photon positions to SceneKit
            // vertices.
            // --------------------------------------------------------

            let points =
                path.map {
                    SCNVector3(
                        $0.x,
                        $0.y,
                        $0.z
                    )
                }

            let vertexSource =
                SCNGeometrySource(
                    vertices: points
                )

            // --------------------------------------------------------
            // Connect consecutive photon positions.
            // --------------------------------------------------------

            var indices =
                [Int32]()

            indices.reserveCapacity(
                (path.count - 1) * 2
            )

            for index in 0..<(path.count - 1) {

                indices.append(
                    Int32(index)
                )

                indices.append(
                    Int32(index + 1)
                )
            }

            let element =
                SCNGeometryElement(
                    indices: indices,
                    primitiveType: .line
                )

            // --------------------------------------------------------
            // Create SceneKit geometry.
            // --------------------------------------------------------

            let geometry =
                SCNGeometry(
                    sources: [
                        vertexSource
                    ],
                    elements: [
                        element
                    ]
                )

            // --------------------------------------------------------
            // Photon-path material.
            // --------------------------------------------------------

            let material =
                SCNMaterial()

            material.diffuse.contents =
                UIColor.white

            material.emission.contents =
                UIColor.white

            material.isDoubleSided =
                true

            material.lightingModel =
                .constant

            geometry.materials =
                [material]

            // --------------------------------------------------------
            // SceneKit node.
            // --------------------------------------------------------

            let node =
                SCNNode(
                    geometry: geometry
                )

            node.name =
                "QRTLPhotonPath"

            scene.rootNode.addChildNode(
                node
            )

            photonPathNodes.append(
                node
            )
        }
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
