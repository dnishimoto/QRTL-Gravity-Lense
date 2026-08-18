/*
 The key change is to stop making the photon follow the QRTL radial field vector. Instead, the QRTL field should behave as a central lensing potential whose transverse influence accumulates along the photon path.
 */
import SwiftUI
import SceneKit
import simd
import Combine
import UIKit

// ============================================================
// MAIN CONTENT VIEW
// ============================================================

struct ContentView: View {
    
    @State private var massSolar: Double = 1_000_000
    @State private var radiusSolar: Double = 35
    
    @State private var alphaQ: Double = 5e-6
    @State private var etaQ: Double = 3.0
    @State private var gammaQ: Double = 1.0
    
    @State private var electromagneticCoupling: Double = 2e-11
    @State private var photonEMCoupling: Double = 5e-21
    
    @State private var chiQ: Double = 1.0
    @State private var interactionRate: Double = 0.0
    
    @State private var result: QRTLExperimentResult?
    
    @State private var isRunning: Bool = false
    
    @State private var statusMessage: String =
    "Ready — source galaxy → QRTL lens → observation plane"
    
    @State private var showControls: Bool = false
    @State private var showPhotonPaths: Bool = true
    
    @StateObject private var scene =
    LensingSceneController()
    
    // ========================================================
    // BODY
    // ========================================================
    
    var body: some View {
        
        ZStack {
            
            LensingSceneView(
                controller: scene
            )
            .ignoresSafeArea()
            
            VStack {
                
                Spacer()
                
                Toggle(
                    isOn: $showPhotonPaths
                ) {
                    
                    Label(
                        "Smooth Photon Paths",
                        systemImage: "wave.3.forward"
                    )
                    .labelStyle(
                        .titleAndIcon
                    )
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
                .foregroundColor(.white)
                .background(
                    .ultraThinMaterial,
                    in: Capsule()
                )
                .tint(.pink)
                .frame(maxWidth: 250)
                
                HStack {
                    
                    Spacer()
                    
                    Button {
                        
                        showControls = true
                        
                    } label: {
                        
                        Image(
                            systemName:
                                "slider.horizontal.3"
                        )
                        .font(
                            .title2.weight(
                                .semibold
                            )
                        )
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(
                            .ultraThinMaterial,
                            in: Circle()
                        )
                    }
                    .padding(
                        [
                            .trailing,
                            .bottom
                        ],
                        28
                    )
                }
            }
        }
        
        // ====================================================
        // CONTROLS SHEET
        // ====================================================
        
        .sheet(
            isPresented: $showControls
        ) {
            
            ControlsSheet(
                
                massSolar:
                    $massSolar,
                
                radiusSolar:
                    $radiusSolar,
                
                alphaQ:
                    $alphaQ,
                
                etaQ:
                    $etaQ,
                
                gammaQ:
                    $gammaQ,
                
                electromagneticCoupling:
                    $electromagneticCoupling,
                
                photonEMCoupling:
                    $photonEMCoupling,
                
                chiQ:
                    $chiQ,
                
                interactionRate:
                    $interactionRate,
                
                result:
                    $result,
                
                isRunning:
                    $isRunning,
                
                statusMessage:
                    $statusMessage,
                
                onRun:
                    runFullPipeline,
                
                onReset:
                    reset
            )
            .presentationDetents(
                [
                    .medium,
                    .large
                ]
            )
            .presentationDragIndicator(
                .visible
            )
        }
        
        // ====================================================
        // INITIAL PIPELINE
        // ====================================================
        
        .onAppear {
            
            runFullPipeline()
        }
    }
    
    // ========================================================
    // RESET
    // ========================================================
    
    private func reset() {
        
        guard !isRunning else {
            return
        }
        
        alphaQ = 0.0
        etaQ = 0.0
        gammaQ = 1.0
        
        electromagneticCoupling = 0.0
        photonEMCoupling = 0.0
        
        chiQ = 1.0
        interactionRate = 0.0
        
        result = nil
        
        statusMessage =
        "Reset to pure GR"
        
        scene.clearDynamic()
        
        scene.addGlobularCluster(
            radius:
                radiusSolar *
            PhysicalConstants.solarRadius
        )
        
        scene.addSourceGalaxy()
        
        scene.addFrontProjectionPlane(
            empty: true
        )
        
        scene.addBottomPlaceholder()
    }
    
    // ========================================================
    // FULL QRTL LENSING PIPELINE
    // ========================================================
    
    private func runFullPipeline() {
        
        guard !isRunning else {
            return
        }
        
        isRunning = true
        result = nil
        
        statusMessage =
        "Starting QRTL lensing pipeline…"
        
        // =========================================================
        // CAPTURE VALUES BEFORE BACKGROUND THREAD
        // =========================================================
        
        let mass =
        massSolar *
        PhysicalConstants.solarMass
        
        let radius =
        radiusSolar *
        PhysicalConstants.solarRadius
        
        let showPaths =
        showPhotonPaths
        
        // =========================================================
        // QRTL PARAMETERS
        // =========================================================
        
        var params =
        QRTLParameters()
        
        params.alphaQ =
        alphaQ
        
        params.etaQ =
        etaQ
        
        params.gammaQ =
        gammaQ
        
        params.chiQ =
        chiQ
        
        params.interactionRate =
        interactionRate
        
        params.electromagneticCoupling =
        electromagneticCoupling
        
        params.photonEMCoupling =
        photonEMCoupling
        
        // =========================================================
        // CLEAR DYNAMIC SCENE
        // =========================================================
        
        scene.clearDynamic()
        
        // =========================================================
        // BACKGROUND PHYSICS
        // =========================================================
        
        DispatchQueue.global(
            qos: .userInitiated
        ).async {
            
            autoreleasepool {
                
                // =====================================================
                // CREATE EXPERIMENT
                // =====================================================
                
                let experiment =
                QRTLExperiment(
                    mass:
                        mass,
                    
                    radius:
                        radius,
                    
                    parameters:
                        params
                )
                
                // =====================================================
                // STAGE 1
                // QRTL FIELD
                // =====================================================
                
                DispatchQueue.main.async {
                    
                    self.statusMessage =
                    "Stage 1/4 — calculating QRTL field…"
                }
                
                let outcome =
                experiment.run(
                    impactParameter:
                        0.15 *
                    PhysicalConstants.solarRadius,
                    
                    startDistance:
                        6.0 *
                    PhysicalConstants.solarRadius,
                    
                    endDistance:
                        6.0 *
                    PhysicalConstants.solarRadius,
                    
                    stepSize:
                        0.15 *
                    PhysicalConstants.solarRadius
                )
                
                // =====================================================
                // STAGE 2
                // TRACE SOURCE GALAXY PHOTONS
                // =====================================================
                
                DispatchQueue.main.async {
                    
                    self.statusMessage =
                    "Stage 2/4 — tracing galaxy photons…"
                }
                
                // =====================================================
                // LENSING PARAMETERS
                // =====================================================
                
                var lensingParameters =
                LensingParameters()
                
                // -----------------------------------------------------
                // PHOTON STEP
                // -----------------------------------------------------
                
                lensingParameters.stepSize =
                0.04
                
                lensingParameters.maxSteps =
                1500
                
                lensingParameters.maxRadius =
                60.0
                
                lensingParameters.deflectionStrength =
                0.01
                
                // -----------------------------------------------------
                // PROJECTION
                //
                // Photons travel +X.
                //
                // Therefore the projection plane is:
                //
                //              X = 10
                //
                // Y = horizontal
                // Z = vertical
                // -----------------------------------------------------
                
                lensingParameters.projectionDistance =
                10.0
                
                lensingParameters.projectionPlaneHalfExtent =
                12.0
                
                // -----------------------------------------------------
                // FIELD COUPLINGS
                // -----------------------------------------------------
                
                lensingParameters.magneticPhotonCoupling =
                1.0
                
                lensingParameters.magneticBendingStrength =
                1.0
                
                lensingParameters.qrtlFieldCoupling =
                1.0
                
                lensingParameters.currentCoupling =
                1.0
                
                lensingParameters.electromagneticCoupling =
                1.0
                
                // =====================================================
                // CREATE PHOTON FIELD
                // =====================================================
                
                let field =
                QRTLField(
                    massModel:
                        GaussianMassModel(
                            totalMass:
                                mass,
                            
                            characteristicRadius:
                                max(
                                    radius,
                                    0.0001
                                )
                        ),
                    
                    parameters:
                        params
                )
                
                // =====================================================
                // GET SOURCE GALAXY
                // =====================================================
                
                let sourceStars =
                self.scene.sourceGalaxyStars
                
                // =====================================================
                // PROJECTION HITS
                // =====================================================
                
                var hits:
                [LensingProjectionHit] = []
                
                hits.reserveCapacity(
                    sourceStars.count
                )
                
                // =====================================================
                // PHOTON PATHS
                //
                // One array of positions for every source photon.
                //
                // This is the critical data that was previously
                // generated by tracePhoton() but never rendered.
                // =====================================================
                
                var photonPaths:
                [[SIMD3<Float>]] = []
                
                if showPaths {
                    
                    photonPaths.reserveCapacity(
                        sourceStars.count
                    )
                }
                
                // =====================================================
                // TRACE EVERY SOURCE STAR
                // =====================================================
                
                for star in sourceStars {
                    
                    // -------------------------------------------------
                    // SOURCE POSITION
                    //
                    // Galaxy coordinates are Y-Z.
                    //
                    // X is photon travel direction.
                    // -------------------------------------------------
                    
                    let origin =
                    SIMD3<Float>(
                        -6.5,
                         star.position.y,
                         star.position.z
                    )
                    
                    // -------------------------------------------------
                    // INITIAL PHOTON DIRECTION
                    //
                    // Photon travels +X.
                    //
                    // This is intentional.
                    //
                    // X = propagation
                    // Y = horizontal lensing displacement
                    // Z = vertical lensing displacement
                    // -------------------------------------------------
                    
                    let direction =
                    SIMD3<Float>(
                        1.0,
                        0.0,
                        0.0
                    )
                    
                    // -------------------------------------------------
                    // TRACE PHOTON
                    // -------------------------------------------------
                    
                    let trace =
                    tracePhoton(
                        origin:
                            origin,
                        
                        direction:
                            direction,
                        
                        field:
                            field,
                        
                        parameters:
                            lensingParameters
                    )
                    
                    // =================================================
                    // STORE COMPLETE PHOTON PATH
                    // =================================================
                    
                    if showPaths {
                        
                        let path =
                        trace.positions
                        
                        if path.count >= 2 {
                            
                            photonPaths.append(
                                path
                            )
                        }
                    }
                    
                    // =================================================
                    // DIAGNOSTIC
                    // =================================================
                    
                    print(
                        "PHOTON:",
                        "star =",
                        star.id,
                        "steps =",
                        trace.stepCount,
                        "points =",
                        trace.positions.count,
                        "hit =",
                        trace.hitProjection,
                        "origin =",
                        trace.origin,
                        "final =",
                        trace.finalPosition,
                        "projection =",
                        trace.projectionPosition as Any,
                        "distance =",
                        trace.traveledDistance,
                        "QRTL =",
                        trace.maximumQRTLInfluence,
                        "magnetic =",
                        trace.maximumMagneticField,
                        "magneticPhoton =",
                        trace.maximumMagneticPhotonInfluence
                    )
                    
                    // =================================================
                    // PROJECTION HIT
                    // =================================================
                    
                    guard trace.hitProjection,
                          let projectionPoint =
                            trace.projectionPosition
                    else {
                        continue
                    }
                    
                    // -------------------------------------------------
                    // PROJECT Y-Z COORDINATES
                    // -------------------------------------------------
                    
                    let projectionCoordinates =
                    SIMD2<Float>(
                        projectionPoint.y,
                        projectionPoint.z
                    )
                    
                    // -------------------------------------------------
                    // SOURCE Y-Z COORDINATES
                    // -------------------------------------------------
                    
                    let sourceCoordinates =
                    SIMD2<Float>(
                        star.position.y,
                        star.position.z
                    )
                    
                    // -------------------------------------------------
                    // CREATE HIT
                    // -------------------------------------------------
                    
                    let hit =
                    LensingProjectionHit(
                        point:
                            projectionPoint,
                        
                        coordinates:
                            projectionCoordinates,
                        
                        sourceCoordinates:
                            sourceCoordinates,
                        
                        direction:
                            trace.finalDirection,
                        
                        traveledDistance:
                            trace.traveledDistance,
                        
                        interactionCount:
                            trace.stepCount,
                        
                        maximumMagneticField:
                            trace.maximumMagneticField,
                        
                        maximumQRTLInfluence:
                            trace.maximumQRTLInfluence,
                        
                        maximumMagneticPhotonInfluence:
                            trace.maximumMagneticPhotonInfluence,
                        
                        sourceID:
                            star.id
                    )
                    
                    hits.append(
                        hit
                    )
                }
                
                // =====================================================
                // TRACE SUMMARY
                // =====================================================
                
                print(
                    "PHOTON PATHS:",
                    photonPaths.count
                )
                
                print(
                    "PROJECTION HITS:",
                    hits.count
                )
                
                // =====================================================
                // CALCULATE PROJECTION
                // =====================================================
                
                let projection =
                LensingProjectionResult.calculate(
                    from:
                        hits
                )
                
                print(
                    "PROJECTION:",
                    "total hits =",
                    hits.count,
                    "valid hits =",
                    projection.validHits.count
                )
                
                // =====================================================
                // STAGE 3
                // =====================================================
                
                DispatchQueue.main.async {
                    
                    self.statusMessage =
                    "Stage 3/4 — preparing projection scene…"
                }
                
                // =====================================================
                // STAGE 4
                // =====================================================
                
                DispatchQueue.main.async {
                    
                    self.statusMessage =
                    "Stage 4/4 — rendering projection…"
                    
                    // =================================================
                    // SOURCE GALAXY
                    // =================================================
                    
                    self.scene.addSourceGalaxy(
                        radius:
                            0.75,
                        
                        nStars:
                            220
                    )
                    
                    // =================================================
                    // GLOBULAR CLUSTER / LENS
                    // =================================================
                    
                    self.scene.addGlobularCluster(
                        radius:
                            3.0
                    )
                    
                    // =================================================
                    // QRTL HEATMAP
                    // =================================================
                    
                    self.scene.updateBottomHeatmap(
                        field:
                            experiment.field
                    )
                    
                    // =================================================
                    // PROJECTION PLANE
                    //
                    // Plane is perpendicular to X.
                    //
                    // X = 10
                    // Y = horizontal
                    // Z = vertical
                    // =================================================
                    
                    self.scene.addProjectionPlane(
                        halfExtent:
                            Float(
                                lensingParameters
                                    .projectionPlaneHalfExtent
                            ),
                        
                        x:
                            lensingParameters
                            .projectionDistance
                    )
                    
                    // =================================================
                    // PROJECTED GALAXIES
                    // =================================================
                    
                    self.scene.applyProjection(
                        projection
                    )
                    
                    // =================================================
                    // PHOTON PATHS
                    //
                    // THIS WAS PREVIOUSLY EMPTY.
                    //
                    // tracePhoton() generated:
                    //
                    //     trace.positions
                    //
                    // We now send all of those paths to SceneKit.
                    // =================================================
                    
                    if showPaths {
                        
                        print(
                            "RENDERING PHOTON PATHS:",
                            photonPaths.count
                        )
                        
                        for (i, path) in photonPaths.enumerated() {
                            self.scene.addPhotonSpline(points: path, index: i)
                        }
                        
                    } else {
                        
                        self.scene.clearPhotonPaths()
                    }
                    
                    // =================================================
                    // RESULT
                    // =================================================
                    
                    self.result =
                    outcome
                    
                    // =================================================
                    // STATUS
                    // =================================================
                    
                    self.statusMessage =
                    "Projection complete — " +
                    "\(projection.validHits.count) photon hits, " +
                    "\(photonPaths.count) photon paths"
                    
                    self.isRunning =
                    false
                }
            }
        }
    }
    
    // ========================================================
    // MAKE PROJECTION HIT
    // ========================================================
    
    func makeHit(
        from trace:
        PhotonTraceResult,
        sourceID:
        Int,
        sourceCoordinates:
        SIMD2<Float>
    ) -> LensingProjectionHit? {
        
        guard
            let point =
                trace.projectionPoint,
            
                let coordinates =
                trace.projectionCoordinates
        else {
            return nil
        }
        
        
        return LensingProjectionHit(
            
            point:
                point,
            
            coordinates:
                coordinates,
            
            sourceCoordinates:
                sourceCoordinates,
            
            direction:
                trace.finalDirection,
            
            traveledDistance:
                trace.traveledDistance,
            
            interactionCount:
                trace.stepCount,
            
            maximumMagneticField:
                trace.maximumMagneticField,
            
            maximumQRTLInfluence:
                trace.maximumQRTLInfluence,
            
            maximumMagneticPhotonInfluence:
                trace.maximumMagneticPhotonInfluence,
            
            sourceID:
                sourceID
        )
    }
    
    // ========================================================
    // PROJECTION PLANE INTERSECTION
    //
    // X = constant
    // Y = horizontal
    // Z = vertical
    // ========================================================
    
    private func projectionPlaneIntersection(
        from:
        SIMD3<Float>,
        to:
        SIMD3<Float>,
        parameters:
        LensingParameters
    ) -> SIMD3<Float>? {
        
        let projectionX =
        parameters.projectionX
        
        let halfExtent =
        parameters.projectionPlaneHalfExtent
        
        guard projectionX.isFinite,
              halfExtent.isFinite,
              halfExtent > 0.0
        else {
            return nil
        }
        
        let x0 =
        from.x
        
        let x1 =
        to.x
        
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
        (projectionX - x0) / dx
        
        guard t.isFinite,
              t >= 0.0,
              t <= 1.0
        else {
            return nil
        }
        
        let intersection =
        from +
        (to - from) * t
        
        guard intersection.x.isFinite,
              intersection.y.isFinite,
              intersection.z.isFinite
        else {
            return nil
        }
        
        guard abs(intersection.y)
                <= halfExtent,
              abs(intersection.z)
                <= halfExtent
        else {
            return nil
        }
        
        return intersection
    }
    private func renderPhotonPaths(
        _ traces: [[SIMD3<Float>]]
    ) {
        
        scene.clearPhotonPaths()
        
        for (i, points) in traces.enumerated() {
            
            guard points.count >= 2 else {
                continue
            }
            
            scene.addPhotonSpline(
                points: points,
                index: i
            )
        }
    }
    // =============================================================
    // TRACE PHOTON THROUGH THE QRTL FIELD
    //
    // Photon propagation:
    //
    //     QRTL field
    //          ↓
    //     total optical index
    //          ↓
    //     index gradient ∇n
    //          ↓
    //     transverse gradient
    //          ↓
    //     QRTL lensing acceleration
    //          ↓
    //     photon direction
    //          ↓
    //     photon position
    //          ↓
    //     projection plane
    //
    // The photon is NOT treated as a Newtonian particle.
    // The path bends because the optical field changes spatially.
    // =============================================================
    
    func tracePhoton(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        field: QRTLField,
        parameters: LensingParameters
    ) -> PhotonTraceResult {
        
        // =========================================================
        // INITIALIZE PHOTON
        // =========================================================
        
        var position =
        origin
        
        var photonDirection =
        simd_normalize(direction)
        
        guard photonDirection.x.isFinite,
              photonDirection.y.isFinite,
              photonDirection.z.isFinite
        else {
            
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
        
        // =========================================================
        // PATH
        // =========================================================
        
        var positions:
        [SIMD3<Float>] = []
        
        positions.reserveCapacity(
            parameters.maximumPhotonSteps + 1
        )
        
        positions.append(
            position
        )
        
        // =========================================================
        // DIAGNOSTICS
        // =========================================================
        
        var maximumQRTLInfluence:
        Float = 0.0
        
        var maximumMagneticField:
        Float = 0.0
        
        var maximumMagneticPhotonInfluence:
        Float = 0.0
        
        var traveledDistance:
        Float = 0.0
        
        var stepCount:
        Int = 0
        
        var projectionPosition:
        SIMD3<Float>? = nil
        
        // =========================================================
        // PHOTON PROPAGATION
        // =========================================================
        
        for _ in 0..<parameters.maximumPhotonSteps {
            
            stepCount += 1
            
            let previousPosition =
            position
            
            let previousDirection =
            photonDirection
            
            // =====================================================
            // SAMPLE FIELD
            // =====================================================
            
            let sample =
            field.sample(
                at:
                    position
            )
            
            let totalIndex =
            sample.totalIndex
            
            guard totalIndex.isFinite,
                  totalIndex > 0.000001
            else {
                break
            }
            
            // =====================================================
            // QRTL DIAGNOSTIC
            // =====================================================
            
            let qrtlInfluence =
            field.influence(
                at:
                    position
            )
            
            let qrtlMagnitude =
            simd_length(
                qrtlInfluence
            )
            
            if qrtlMagnitude.isFinite {
                
                maximumQRTLInfluence =
                max(
                    maximumQRTLInfluence,
                    qrtlMagnitude
                )
            }
            
            // =====================================================
            // ELECTROMAGNETIC FIELD
            // =====================================================
            
            let electromagneticInfluence =
            field.electromagneticInfluence(
                at:
                    position
            )
            
            let magneticPhotonMagnitude =
            simd_length(
                electromagneticInfluence
            )
            
            if magneticPhotonMagnitude.isFinite {
                
                maximumMagneticPhotonInfluence =
                max(
                    maximumMagneticPhotonInfluence,
                    magneticPhotonMagnitude
                )
            }
            
            // =====================================================
            // MAGNETIC FIELD DIAGNOSTIC
            // =====================================================
            
            
            
            let electromagneticField =
            field.electromagneticField(
                at: position
            )
            
            let magneticFieldMagnitude =
            simd_length(
                electromagneticField
            )
            
            if magneticFieldMagnitude.isFinite {
                
                maximumMagneticField =
                max(
                    maximumMagneticField,
                    magneticFieldMagnitude
                )
            }
            
            // =====================================================
            // TOTAL INDEX GRADIENT
            // =====================================================
            
            let gradient =
            field.indexGradient(
                at:
                    position
            )
            
            guard gradient.x.isFinite,
                  gradient.y.isFinite,
                  gradient.z.isFinite
            else {
                break
            }
            
            // =====================================================
            // REMOVE LONGITUDINAL COMPONENT
            //
            // Only the transverse gradient bends the photon.
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
            // OPTICAL BENDING
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
                break
            }
            
            // =====================================================
            // STEP
            // =====================================================
            
            let step =
            parameters.photonStepSize
            
            guard step.isFinite,
                  step > 0.0
            else {
                break
            }
            
            // =====================================================
            // CHANGE DIRECTION
            // =====================================================
            
            let directionChange =
            indexBending *
            parameters.deflectionStrength
            
            var nextDirection =
            photonDirection +
            directionChange *
            step
            
            let directionLength =
            simd_length(
                nextDirection
            )
            
            guard directionLength.isFinite,
                  directionLength > 0.000001
            else {
                break
            }
            
            nextDirection =
            simd_normalize(
                nextDirection
            )
            
            // =====================================================
            // ADVANCE
            // =====================================================
            
            let nextPosition =
            position +
            nextDirection *
            step
            
            guard nextPosition.x.isFinite,
                  nextPosition.y.isFinite,
                  nextPosition.z.isFinite
            else {
                break
            }
            
            // =====================================================
            // CHECK PROJECTION PLANE
            //
            // IMPORTANT:
            // The plane is X = projectionDistance.
            // =====================================================
            
            if let intersection =
                projectionPlaneIntersection(
                    from:
                        previousPosition,
                    
                    to:
                        nextPosition,
                    
                    parameters:
                        parameters
                ) {
                
                position =
                intersection
                
                positions.append(
                    intersection
                )
                
                projectionPosition =
                intersection
                
                traveledDistance +=
                simd_distance(
                    previousPosition,
                    intersection
                )
                
                // -------------------------------------------------
                // PHOTON HAS REACHED TARGET
                // -------------------------------------------------
                
                return PhotonTraceResult(
                    
                    positions:
                        positions,
                    
                    origin:
                        origin,
                    
                    finalPosition:
                        intersection,
                    
                    finalDirection:
                        nextDirection,
                    
                    hitProjection:
                        true,
                    
                    projectionPosition:
                        projectionPosition,
                    
                    stepCount:
                        stepCount,
                    
                    traveledDistance:
                        traveledDistance,
                    
                    maximumQRTLInfluence:
                        maximumQRTLInfluence,
                    
                    maximumMagneticField:
                        maximumMagneticField,
                    
                    maximumMagneticPhotonInfluence:
                        maximumMagneticPhotonInfluence
                )
            }
            
            // =====================================================
            // COMMIT STATE
            // =====================================================
            
            photonDirection =
            nextDirection
            
            position =
            nextPosition
            
            traveledDistance +=
            step
            
            positions.append(
                position
            )
            
            // =====================================================
            // STOP OUTSIDE LENSING VOLUME
            // =====================================================
            
            let distanceFromCenter =
            simd_length(
                position
            )
            
            if distanceFromCenter.isFinite,
               distanceFromCenter >
                parameters.maximumPropagationRadius {
                
                break
            }
        }
        
        // =========================================================
        // PHOTON DID NOT HIT PROJECTION PLANE
        // =========================================================
        
        return PhotonTraceResult(
            
            positions:
                positions,
            
            origin:
                origin,
            
            finalPosition:
                position,
            
            finalDirection:
                photonDirection,
            
            hitProjection:
                false,
            
            projectionPosition:
                nil,
            
            stepCount:
                stepCount,
            
            traveledDistance:
                traveledDistance,
            
            maximumQRTLInfluence:
                maximumQRTLInfluence,
            
            maximumMagneticField:
                maximumMagneticField,
            
            maximumMagneticPhotonInfluence:
                maximumMagneticPhotonInfluence
        )
    }
}

