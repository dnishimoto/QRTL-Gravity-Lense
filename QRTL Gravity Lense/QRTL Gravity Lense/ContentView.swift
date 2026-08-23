//
//  ContentView.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/18/26.
//

import SwiftUI
import SceneKit
import simd
import Combine
import UIKit

struct ContentView: View {

    // ============================================================
    // MARK: - CONTINUOUS PHOTON SIMULATION PROGRESS
    // ============================================================

    @State
    private var photonSimulationProgress =
        PhotonSimulationProgress(
            total: 0,
            completed: 0,
            active: 0,
            projectionHits: 0
        )

    // ============================================================
    // MARK: - SIMPLE GRAVITY POTENTIAL DEBUG
    // ============================================================

    @State
    private var showPotentialDebug: Bool = true

    @State
    private var potentialCenter: Double = 0.0

    @State
    private var potentialQuarter: Double = 0.0

    @State
    private var potentialHalf: Double = 0.0

    @State
    private var potentialEdge: Double = 0.0

    @State
    private var potentialCenterLevel: String = "UNKNOWN"

    @State
    private var potentialQuarterLevel: String = "UNKNOWN"

    @State
    private var potentialHalfLevel: String = "UNKNOWN"

    @State
    private var potentialEdgeLevel: String = "UNKNOWN"

    @State
    private var potentialStatus: String =
        "Waiting for QRTL field"

    @State
    private var potentialExplanation: String =
        "The QRTL gravitational potential has not been sampled yet."

    // ============================================================
    // MARK: - PHYSICAL CLUSTER PARAMETERS
    // ============================================================

    @State
    private var massSolar: Double = 1_000_000.0

    @State
    private var radiusSolar: Double = 35.0

    // ============================================================
    // MARK: - QRTL PARAMETERS
    // ============================================================

    @State
    private var alphaQ: Double = 5e-6

    @State
    private var etaQ: Double = 3.0

    @State
    private var gammaQ: Double = 1.0

    @State
    private var electromagneticCoupling: Double = 2e-11

    @State
    private var photonEMCoupling: Double = 5e-21

    @State
    private var chiQ: Double = 1.0

    @State
    private var interactionRate: Double = 0.0

    // ============================================================
    // MARK: - UI STATE
    // ============================================================

    @State
    private var result: QRTLExperimentResult?

    @State
    private var isRunning: Bool = false

    @State
    private var statusMessage: String =
        "Ready — source galaxy → QRTL lens → observation plane"

    @State
    private var showControls: Bool = false

    @State
    private var showPhotonPaths: Bool = false

    // ============================================================
    // MARK: - LIVE COMPUTATION OVERLAY
    // ============================================================

    @State
    private var computationStage: String =
        "Idle"

    @State
    private var computationDetail: String =
        "Ready to begin QRTL lensing computation."

    @State
    private var photonsCreated: Int = 0

    @State
    private var photonsTraced: Int = 0

    @State
    private var photonPathPoints: Int = 0

    @State
    private var projectionHits: Int = 0

    @State
    private var computationElapsed: Double = 0.0

    @State
    private var computationProgress: Double = 0.0

    @State
    private var maximumQRTLInfluence: Float = 0.0

    @State
    private var showComputationOverlay: Bool = true

    // ============================================================
    // MARK: - CONTINUOUS PHOTON EMITTER
    // ============================================================

    @State
    private var continuousPhotonEmissionStarted: Bool = false

    // ============================================================
    // MARK: - GRAVITY METRICS OVERLAY
    // ============================================================

    @State
    private var showGravityMetrics: Bool = false

    @State
    private var gravityRequestedMassSolar: Double = 0.0

    @State
    private var gravityFieldMassKg: Double = 0.0

    @State
    private var gravityRelativeMassError: Double = 0.0

    @State
    private var gravityStarCount: Int = 0

    @State
    private var gravityPerStarMassSolar: Double = 0.0

    @State
    private var gravityPerStarMassKg: Double = 0.0

    @State
    private var gravityClusterRadiusMeters: Double = 0.0

    // ============================================================
    // MARK: - SCENE CONTROLLER
    // ============================================================

    @StateObject
    private var scene =
        LensingSceneController()

    // ============================================================
    // MARK: - BODY
    // ============================================================

    var body: some View {

        ZStack {

            // ====================================================
            // SCENE
            // ====================================================

            LensingSceneView(
                controller: scene
            )
            .ignoresSafeArea()

            // ====================================================
            // COMPUTATION OVERLAY
            // ====================================================

            if showComputationOverlay {
                computationOverlay
            }

            // ====================================================
            // GRAVITY METRICS
            // ====================================================

            if showGravityMetrics {
                gravityMetricsOverlay
            }

            // ====================================================
            // BOTTOM CONTROLS
            // ====================================================

            VStack {

                Spacer()

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
                        [.trailing, .bottom],
                        28
                    )
                }
            }
        }

        // ========================================================
        // MARK: - CONTROL SHEET
        // ========================================================

        .sheet(
            isPresented:
                $showControls
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
                [.medium, .large]
            )
            .presentationDragIndicator(
                .visible
            )
        }

        // ========================================================
        // MARK: - INITIAL SCENE
        // ========================================================

        .onAppear {
            runFullPipeline()
        }

        // ========================================================
        // MARK: - PHOTON PATH VISIBILITY
        //
        // Photon paths are intentionally disabled.
        //
        // The continuous emitter is now the only photon system.
        // ========================================================

        .onChange(
            of: showPhotonPaths
        ) { _, visible in

            guard
                let output =
                    scene.lastPipelineOutput
            else {
                return
            }

            if visible {

                scene.displayPhotonPaths(
                    output.photonPaths
                )

            } else {

                scene.clearPhotonPaths()
            }
        }
    }

    // ============================================================
    // MARK: - COMPUTATION OVERLAY
    // ============================================================

    private var computationOverlay: some View {

        VStack(
            alignment: .leading,
            spacing: 10
        ) {

            HStack {

                Image(
                    systemName:
                        isRunning
                        ? "gearshape.2.fill"
                        : "checkmark.circle.fill"
                )

                Text(
                    isRunning
                    ? "QRTL PHYSICS COMPUTATION"
                    : "QRTL COMPUTATION COMPLETE"
                )
                .font(.headline)

                Spacer()
            }

            Divider()

            Text(
                computationStage
            )
            .font(.subheadline)
            .fontWeight(.semibold)

            Text(
                computationDetail
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            ProgressView(
                value:
                    computationProgress
            )

            HStack {

                Text("Progress")

                Spacer()

                Text(
                    "\(Int(computationProgress * 100))%"
                )
            }
            .font(.caption)

            Divider()

            // ====================================================
            // PHOTON PROCESSING
            // ====================================================

            computationRow(
                "Photons created",
                "\(photonsCreated)"
            )

            computationRow(
                "Photons traced",
                "\(photonsTraced)"
            )

            computationRow(
                "Projection hits",
                "\(projectionHits)"
            )

            computationRow(
                "Path points",
                "\(photonPathPoints)"
            )

            computationRow(
                "Max QRTL influence",
                String(
                    format:
                        "%.5g",
                    maximumQRTLInfluence
                )
            )

            computationRow(
                "Elapsed",
                String(
                    format:
                        "%.1f s",
                    computationElapsed
                )
            )

            Divider()

            // ====================================================
            // QRTL GRAVITY POTENTIAL
            // ====================================================

            HStack {

                Image(
                    systemName:
                        "arrow.down.circle.fill"
                )

                Text(
                    "QRTL GRAVITY POTENTIAL"
                )
                .font(.subheadline)
                .fontWeight(.bold)

                Spacer()
            }

            Text(
                potentialStatus
            )
            .font(.caption)
            .fontWeight(.bold)

            Text(
                potentialExplanation
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(
                horizontal: false,
                vertical: true
            )

            potentialLevelRow(
                "Center",
                level:
                    potentialCenterLevel,
                value:
                    potentialCenter
            )

            potentialLevelRow(
                "25% radius",
                level:
                    potentialQuarterLevel,
                value:
                    potentialQuarter
            )

            potentialLevelRow(
                "50% radius",
                level:
                    potentialHalfLevel,
                value:
                    potentialHalf
            )

            potentialLevelRow(
                "Edge",
                level:
                    potentialEdgeLevel,
                value:
                    potentialEdge
            )

            Text(
                "Expected gravity-well pattern:"
            )
            .font(.caption2)
            .fontWeight(.semibold)

            Text(
                "HIGH at center → " +
                "MEDIUM farther out → " +
                "LOW at edge"
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

            Text(
                "If all four values are the same, " +
                "the physical potential is flat and " +
                "the spacetime surface cannot form a bowl."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)
            .fixedSize(
                horizontal: false,
                vertical: true
            )
        }
        .padding(16)
        .frame(
            maxWidth: 360
        )
        .background(
            .ultraThinMaterial,
            in:
                RoundedRectangle(
                    cornerRadius: 18
                )
        )
        .foregroundStyle(.white)
        .padding(.top, 55)
        .padding(.horizontal, 16)
        .frame(
            maxHeight: .infinity,
            alignment: .top
        )
    }

    // ============================================================
    // MARK: - POTENTIAL LEVEL ROW
    // ============================================================

    private func potentialLevelRow(
        _ name: String,
        level: String,
        value: Double
    ) -> some View {

        HStack {

            Text(name)

            Spacer()

            Text(level)
                .fontWeight(.bold)

            Text(
                String(
                    format:
                        "%.2e",
                    value
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .font(.caption)
    }

    // ============================================================
    // MARK: - GRAVITY METRICS OVERLAY
    // ============================================================

    private var gravityMetricsOverlay: some View {

        VStack(
            alignment: .leading,
            spacing: 8
        ) {

            HStack {

                Image(
                    systemName:
                        "atom"
                )

                Text(
                    "GRAVITY METRICS"
                )
                .font(.headline)

                Spacer()

                Button {

                    showGravityMetrics =
                        false

                } label: {

                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            Divider()

            computationRow(
                "Requested mass",
                String(
                    format:
                        "%.4g M☉",
                    gravityRequestedMassSolar
                )
            )

            computationRow(
                "Field mass",
                String(
                    format:
                        "%.4e kg",
                    gravityFieldMassKg
                )
            )

            computationRow(
                "Mass error",
                String(
                    format:
                        "%.4g %%",
                    gravityRelativeMassError * 100.0
                )
            )

            Divider()

            computationRow(
                "Star count",
                "\(gravityStarCount)"
            )

            computationRow(
                "Mass per star",
                String(
                    format:
                        "%.4g M☉",
                    gravityPerStarMassSolar
                )
            )

            computationRow(
                "Mass per star (kg)",
                String(
                    format:
                        "%.4e kg",
                    gravityPerStarMassKg
                )
            )

            Divider()

            computationRow(
                "Cluster radius",
                String(
                    format:
                        "%.4e m",
                    gravityClusterRadiusMeters
                )
            )

            Divider()

            Text(
                "CONTINUOUS PHOTON EMITTER"
            )
            .font(.caption)
            .fontWeight(.bold)

            computationRow(
                "Emitter",
                continuousPhotonEmissionStarted
                ? "RUNNING"
                : "STOPPED"
            )

            computationRow(
                "Projection hits",
                "\(scene.projectionHitCount)"
            )
        }
        .padding(16)
        .frame(
            maxWidth: 320
        )
        .background(
            .ultraThinMaterial,
            in:
                RoundedRectangle(
                    cornerRadius: 18
                )
        )
        .foregroundStyle(.white)
        .padding(.bottom, 24)
        .padding(.horizontal, 16)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .bottomTrailing
        )
    }

    // ============================================================
    // MARK: - COMPUTATION ROW
    // ============================================================

    private func computationRow(
        _ title: String,
        _ value: String
    ) -> some View {

        HStack {

            Text(title)
                .foregroundStyle(
                    .secondary
                )

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
        .font(.caption)
    }

    // ============================================================
    // MARK: - RESET
    // ============================================================

    private func reset() {

        guard !isRunning else {
            return
        }

        // ========================================================
        // STOP CONTINUOUS EMITTER
        // ========================================================

        scene.stopContinuousPhotonSimulation()

        continuousPhotonEmissionStarted =
            false

        // ========================================================
        // RESET QRTL PARAMETERS
        // ========================================================

        alphaQ = 0.0
        etaQ = 0.0
        gammaQ = 1.0
        electromagneticCoupling = 0.0
        photonEMCoupling = 0.0
        chiQ = 1.0
        interactionRate = 0.0

        result = nil

        // ========================================================
        // RESET COMPUTATION
        // ========================================================

        computationStage =
            "Idle"

        computationDetail =
            "Reset to QRTL gravity-only mode."

        photonsCreated = 0
        photonsTraced = 0
        photonPathPoints = 0
        projectionHits = 0

        computationElapsed = 0.0
        computationProgress = 0.0
        maximumQRTLInfluence = 0.0

        statusMessage =
            "Reset to QRTL gravity-only mode"

        // ========================================================
        // RESET GRAVITY METRICS
        // ========================================================

        showGravityMetrics = false

        gravityRequestedMassSolar = 0.0
        gravityFieldMassKg = 0.0
        gravityRelativeMassError = 0.0
        gravityStarCount = 0
        gravityPerStarMassSolar = 0.0
        gravityPerStarMassKg = 0.0
        gravityClusterRadiusMeters = 0.0

        // ========================================================
        // RESET POTENTIAL
        // ========================================================

        potentialCenter = 0.0
        potentialQuarter = 0.0
        potentialHalf = 0.0
        potentialEdge = 0.0

        potentialCenterLevel =
            "UNKNOWN"

        potentialQuarterLevel =
            "UNKNOWN"

        potentialHalfLevel =
            "UNKNOWN"

        potentialEdgeLevel =
            "UNKNOWN"

        potentialStatus =
            "Waiting for QRTL field"

        potentialExplanation =
            "The QRTL gravitational potential has not been sampled yet."

        // ========================================================
        // CLEAR SCENE
        // ========================================================

        scene.clearDynamic()

        // ========================================================
        // REBUILD STATIC VISUAL SOURCE
        // ========================================================

        scene.addGlobularCluster(
            radius: 4.0
        )

        scene.addSourceGalaxy()
    }

    // ============================================================
    // MARK: - FULL PHYSICS PIPELINE
    // ============================================================

    private func runFullPipeline() {

        guard !isRunning else {
            return
        }

        // ========================================================
        // STOP PREVIOUS EMITTER
        // ========================================================

        scene.stopContinuousPhotonSimulation()

        continuousPhotonEmissionStarted =
            false

        // ========================================================
        // RESET PIPELINE STATE
        // ========================================================

        isRunning = true

        result = nil

        showGravityMetrics = false

        photonsCreated = 0
        photonsTraced = 0
        photonPathPoints = 0
        projectionHits = 0

        computationProgress = 0.0
        computationElapsed = 0.0
        maximumQRTLInfluence = 0.0

        computationStage =
            "Initializing QRTL lens"

        computationDetail =
            "Creating the physical stellar mass distribution."

        statusMessage =
            "Starting QRTL lensing pipeline…"

        showComputationOverlay =
            true

        let computationStart =
            CFAbsoluteTimeGetCurrent()

        // ========================================================
        // PHYSICAL PARAMETERS
        // ========================================================

        let mass =
            massSolar *
            PhysicalConstants.solarMass

        let radiusMeters =
            radiusSolar *
            PhysicalConstants.solarRadius

        // ========================================================
        // QRTL PARAMETERS
        // ========================================================

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

        // ========================================================
        // LENSING PARAMETERS
        // ========================================================

        var lensingParameters =
            LensingParameters()

        lensingParameters.qrtlLensingStrength =
            1.0

        lensingParameters.qrtlFieldCoupling =
            1.0

        lensingParameters.maximumPhotonBend =
            0.35

        lensingParameters.electromagneticCoupling =
            Float(
                electromagneticCoupling
            )

        lensingParameters.magneticPhotonCoupling =
            1.0

        lensingParameters.magneticBendingStrength =
            1.0

        lensingParameters.currentCoupling =
            1.0

        lensingParameters.interactionRate =
            Float(
                interactionRate
            )

        lensingParameters.qrtlPhotonCoupling =
            0.25

        // ========================================================
        // PHYSICS WORK ITEM
        // ========================================================

        let physicsWorkItem =
            DispatchWorkItem {

                autoreleasepool {

                    // ====================================================
                    // STAGE 1A — PHYSICAL SOURCE
                    // ====================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 1 / 5 — physical source"

                        self.computationDetail =
                            """
                            Creating the \(Int(self.massSolar)) solar-mass
                            globular cluster and generating its
                            stellar positions.
                            """

                        self.computationProgress =
                            0.03

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 1/5 — creating physical stellar source…"
                    }

                    // ====================================================
                    // STAR POSITIONS
                    // ====================================================

                    let starPositions =
                        self.scene.generateGlobularClusterStarPositions(
                            starCount:
                                1000,
                            radiusMeters:
                                Float(radiusMeters)
                        )

                    let perStarMassKg =
                        starPositions.isEmpty
                        ? 0.0
                        :
                        mass /
                        Double(
                            starPositions.count
                        )

                    _ = perStarMassKg

                    // ====================================================
                    // STATIC VISUAL SOURCE
                    //
                    // IMPORTANT:
                    //
                    // This is NOT a photon system.
                    // It only creates the visible cluster/lens.
                    // ====================================================

                    DispatchQueue.main.async {

                        self.scene.addGlobularCluster(
                            radius: 4.0
                        )

                        self.scene.addSourceGalaxy()
                    }

                    // ====================================================
                    // STAGE 1B — QRTL FIELD
                    // ====================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 1 / 5 — QRTL spacetime field"

                        self.computationDetail =
                            """
                            Building the authoritative QRTL field from
                            the requested cluster mass and radius.
                            """

                        self.computationProgress =
                            0.08

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 1/5 — creating QRTL spacetime field…"
                    }

                    // ====================================================
                    // CREATE AUTHORITATIVE FIELD
                    // ====================================================

                    let experiment =
                        QRTLExperiment(
                            mass:
                                mass,
                            radius:
                                radiusMeters,
                            parameters:
                                params
                        )

                    let field =
                        experiment.field

                    // ====================================================
                    // POTENTIAL OVERLAY
                    // ====================================================

                    self.updatePotentialOverlay(
                        field:
                            field,
                        radiusMeters:
                            radiusMeters
                    )

                    // ====================================================
                    // STAGE 1C — UNIFIED SPACETIME
                    // ====================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 1 / 5 — QRTL spacetime geometry"

                        self.computationDetail =
                            """
                            Converting the authoritative QRTL gravitational
                            potential into the QRTL spacetime metric.
                            """

                        self.computationProgress =
                            0.12

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 1/5 — evaluating QRTL spacetime geometry…"
                    }

                    // ====================================================
                    // CENTER METRIC SAMPLE
                    // ====================================================

                    let centerPosition =
                        SIMD3<Float>(
                            0.0,
                            0.0,
                            0.0
                        )

                    let centerSpacetime =
                        field.evaluateQRTLUnifiedSpacetime(
                            at:
                                centerPosition
                        )

                    #if DEBUG

                    print(
                        """
                        ====================================================
                        QRTL UNIFIED SPACETIME
                        ====================================================
                        Position:
                        \(centerSpacetime.position)

                        QRTL gravitational potential:
                        \(centerSpacetime.potential)

                        Metric:
                        g00 =
                        \(centerSpacetime.metric.g00)

                        g11 =
                        \(centerSpacetime.metric.g11)

                        g22 =
                        \(centerSpacetime.metric.g22)

                        g33 =
                        \(centerSpacetime.metric.g33)

                        Metric deformation:
                        \(centerSpacetime.metricDeformation)
                        ====================================================
                        """
                    )

                    #endif

                    // ====================================================
                    // MASS VALIDATION
                    // ====================================================

                    let requestedMass =
                        mass

                    let actualMass =
                        Double(
                            field.densitySource.totalMass
                        )

                    let relativeMassError =
                        requestedMass > 0.0
                        ?
                        abs(
                            actualMass -
                            requestedMass
                        )
                        /
                        requestedMass
                        :
                        0.0

                    let starCount =
                        field.densitySource.starCount

                    let actualPerStarMass =
                        Double(
                            field.densitySource.perStarMassKg
                        )

                    // ====================================================
                    // GRAVITY METRICS
                    // ====================================================

                    DispatchQueue.main.async {

                        self.gravityRequestedMassSolar =
                            self.massSolar

                        self.gravityFieldMassKg =
                            actualMass

                        self.gravityRelativeMassError =
                            relativeMassError

                        self.gravityStarCount =
                            starCount

                        self.gravityPerStarMassKg =
                            actualPerStarMass

                        self.gravityPerStarMassSolar =
                            actualPerStarMass /
                            PhysicalConstants.solarMass

                        self.gravityClusterRadiusMeters =
                            radiusMeters
                    }

                    // ====================================================
                    // GRAVITATIONAL VALIDATION
                    // ====================================================

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

                    // ====================================================
                    // STAGE 2
                    //
                    // IMPORTANT:
                    //
                    // THERE IS NO INITIAL PHOTON TRACE.
                    //
                    // The continuous emitter is the sole photon
                    // producer.
                    // ====================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 2 / 5 — preparing continuous photons"

                        self.computationDetail =
                            """
                            The authoritative QRTL field is complete.
                            Preparing the source galaxy and projection
                            system for continuous photon emission.
                            """

                        self.computationProgress =
                            0.20

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 2/5 — preparing continuous photon emitter…"
                    }

                    // ====================================================
                    // EMPTY PHOTON OUTPUT
                    //
                    // This allows the existing scene pipeline to retain
                    // its projection-plane infrastructure without
                    // creating a second photon animation.
                    // ====================================================

                    let emptyProjection =
                        LensingProjectionResult.calculate(
                            from:
                                []
                        )

                    let output =
                        LensingPipelineOutput(
                            experimentResult:
                                outcome,

                            field:
                                field,

                            photonTraces:
                                [],

                            photonPaths:
                                [],

                            photonHits:
                                [],

                            projection:
                                emptyProjection,

                            tracedPhotonCount:
                                0,

                            successfulProjectionHits:
                                0
                        )

                    // ====================================================
                    // HEATMAP
                    // ====================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 3 / 5 — QRTL density heatmap"

                        self.computationDetail =
                            """
                            Sampling the QRTL radial gravity field
                            for spacetime visualization.
                            """

                        self.computationProgress =
                            0.55

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 3/5 — generating QRTL field visualization…"
                    }

                    let heatmapImage =
                        QRTLHeatmapGenerator.makeHeatmapImage(
                            field:
                                field,

                            size:
                                128,

                            halfExtent:
                                Double(
                                    self.scene.heatmapHalfExtent
                                )
                        )

                    // ====================================================
                    // STORE OUTPUT AND BUILD SCENE
                    // ====================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 4 / 5 — spacetime visualization"

                        self.computationDetail =
                            """
                            Rendering the QRTL gravity surface, deformed
                            spacetime, source galaxy, and projection
                            system.
                            """

                        self.computationProgress =
                            0.70

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        // =================================================
                        // RENDER EMPTY PIPELINE OUTPUT
                        //
                        // This preserves the existing projection-plane
                        // setup without displaying photon paths.
                        // =================================================

                        self.scene.renderPipelineOutput(
                            output,
                            showPhotonPaths:
                                false
                        )

                        // =================================================
                        // GRAVITY SURFACE
                        // =================================================

                        self.scene.installQRTLGravitySurface(
                            field:
                                field
                        )

                        // =================================================
                        // DEFORMED SPACETIME
                        // =================================================

                        self.scene.addDeformedSpacetimeSurface(
                            field:
                                field,

                            heatmap:
                                heatmapImage
                        )

                        // =================================================
                        // SOURCE GALAXY
                        //
                        // Add after the surfaces so the source galaxy
                        // remains visible.
                        // =================================================

                        self.scene.addSourceGalaxy()

                        // =================================================
                        // STORE AUTHORITATIVE PIPELINE OUTPUT
                        // =================================================

                        self.scene.lastPipelineOutput =
                            output

                        self.result =
                            outcome
                    }

                    // ====================================================
                    // STAGE 5 — CONTINUOUS PHOTON EMITTER
                    // ====================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 5 / 5 — continuous photon emission"

                        self.computationDetail =
                            """
                            The QRTL field, gravity surface, source galaxy,
                            and projection plane are ready.

                            Starting the continuous photon emitter.

                            No initial photon-path animation is created.
                            """

                        self.computationProgress =
                            0.90

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 5/5 — starting continuous photon emission…"

                        // =================================================
                        // THE ONLY PHOTON SYSTEM
                        // =================================================

                        self.scene.startContinuousPhotonSimulation(

                            field:
                                field,

                            parameters:
                                lensingParameters,

                            progress: { progress in

                                DispatchQueue.main.async {

                                    self.photonSimulationProgress =
                                        progress

                                    self.photonsCreated =
                                        progress.total

                                    self.photonsTraced =
                                        progress.completed

                                    self.projectionHits =
                                        progress.projectionHits

                                    self.photonPathPoints =
                                        0

                                    self.maximumQRTLInfluence =
                                        0.0

                                    self.computationProgress =
                                        0.90

                                    self.computationStage =
                                        "Stage 5 / 5 — continuous photon emission"

                                    self.computationDetail =
                                        """
                                        Continuous photon emitter active.

                                        \(progress.completed)
                                        photons processed.

                                        \(progress.projectionHits)
                                        projection-plane hits.
                                        """
                                }
                            }
                        )

                        // =================================================
                        // EMITTER ACTIVE
                        // =================================================

                        self.continuousPhotonEmissionStarted =
                            true

                        self.computationProgress =
                            1.0

                        self.computationStage =
                            "COMPLETE"

                        self.computationDetail =
                            """
                            QRTL unified spacetime lensing simulation
                            is running.

                            The source galaxy is visible behind the
                            QRTL gravitational lens.

                            Continuous photons are being emitted through
                            the authoritative QRTL field and accumulated
                            on the projection plane.

                            No separate initial photon-path animation
                            is running.
                            """

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Continuous photon emission active — QRTL lens running"

                        self.isRunning =
                            false

                        self.showComputationOverlay =
                            false

                        self.showGravityMetrics =
                            true
                    }
                }
            }

        // ========================================================
        // EXECUTE OFF MAIN THREAD
        // ========================================================

        DispatchQueue.global(
            qos: .userInitiated
        )
        .async(
            execute:
                physicsWorkItem
        )
    }

    // ============================================================
    // MARK: - QRTL POTENTIAL SAMPLING
    // ============================================================

    private func updatePotentialOverlay(
        field: QRTLField,
        radiusMeters: Double
    ) {

        let centerPosition =
            SIMD3<Float>(
                0.0,
                0.0,
                0.0
            )

        let quarterPosition =
            SIMD3<Float>(
                Float(
                    radiusMeters * 0.25
                ),
                0.0,
                0.0
            )

        let halfPosition =
            SIMD3<Float>(
                Float(
                    radiusMeters * 0.50
                ),
                0.0,
                0.0
            )

        let edgePosition =
            SIMD3<Float>(
                Float(
                    radiusMeters * 0.95
                ),
                0.0,
                0.0
            )

        let centerPotential =
            Double(
                field.gravitationalPotential(
                    at:
                        centerPosition
                )
            )

        let quarterPotential =
            Double(
                field.gravitationalPotential(
                    at:
                        quarterPosition
                )
            )

        let halfPotential =
            Double(
                field.gravitationalPotential(
                    at:
                        halfPosition
                )
            )

        let edgePotential =
            Double(
                field.gravitationalPotential(
                    at:
                        edgePosition
                )
            )

        DispatchQueue.main.async {

            self.potentialCenter =
                centerPotential

            self.potentialQuarter =
                quarterPotential

            self.potentialHalf =
                halfPotential

            self.potentialEdge =
                edgePotential

            let maximumMagnitude =
                max(
                    abs(centerPotential),
                    abs(quarterPotential),
                    abs(halfPotential),
                    abs(edgePotential),
                    1e-30
                )

            self.potentialCenterLevel =
                self.potentialLevel(
                    centerPotential,
                    reference:
                        maximumMagnitude
                )

            self.potentialQuarterLevel =
                self.potentialLevel(
                    quarterPotential,
                    reference:
                        maximumMagnitude
                )

            self.potentialHalfLevel =
                self.potentialLevel(
                    halfPotential,
                    reference:
                        maximumMagnitude
                )

            self.potentialEdgeLevel =
                self.potentialLevel(
                    edgePotential,
                    reference:
                        maximumMagnitude
                )

            let centerMagnitude =
                abs(centerPotential)

            let quarterMagnitude =
                abs(quarterPotential)

            let halfMagnitude =
                abs(halfPotential)

            let edgeMagnitude =
                abs(edgePotential)

            let isFlat =
                centerMagnitude < 1e-30 ||
                (
                    abs(
                        centerMagnitude -
                        edgeMagnitude
                    )
                    /
                    max(
                        centerMagnitude,
                        1e-30
                    )
                    < 0.01
                )

            let formsWell =
                centerMagnitude >
                quarterMagnitude &&
                quarterMagnitude >
                halfMagnitude &&
                halfMagnitude >
                edgeMagnitude

            if isFlat {

                self.potentialStatus =
                    "LOW / FLAT GRAVITY POTENTIAL"

                self.potentialExplanation =
                    """
                    The QRTL potential changes very little from the
                    center to the edge. A strong bowl-shaped spacetime
                    deformation is therefore not expected.
                    """

            } else if formsWell {

                self.potentialStatus =
                    "HIGH CENTER → LOW EDGE"

                self.potentialExplanation =
                    """
                    The QRTL gravitational potential is strongest near
                    the cluster center and decreases outward. This is
                    the expected profile for a bowl-shaped gravity well.
                    """

            } else {

                self.potentialStatus =
                    "POTENTIAL PROFILE DETECTED"

                self.potentialExplanation =
                    """
                    The QRTL field has a measurable potential, but the
                    radial profile is not strictly decreasing from the
                    center to the edge.
                    """
            }
        }
    }

    // ============================================================
    // MARK: - POTENTIAL LEVEL CLASSIFICATION
    // ============================================================

    private func potentialLevel(
        _ potential: Double,
        reference: Double
    ) -> String {

        let magnitude =
            abs(potential)

        let referenceMagnitude =
            abs(reference)

        guard referenceMagnitude > 1e-30 else {
            return "LOW"
        }

        let fraction =
            magnitude /
            referenceMagnitude

        if fraction >= 0.66 {
            return "HIGH"
        }

        if fraction >= 0.33 {
            return "MEDIUM"
        }

        return "LOW"
    }
}
