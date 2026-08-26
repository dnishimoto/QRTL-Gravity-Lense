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


    private func updatePotentialOverlay(
        field: QRTLField,
        radiusMeters: Double
    ) {

        // ========================================================
        // SAMPLE POSITIONS
        // ========================================================

        let centerPosition =
            SIMD3<Float>(
                0.0,
                0.0,
                0.0
            )

        let quarterPosition =
            SIMD3<Float>(
                Float(radiusMeters * 0.25),
                0.0,
                0.0
            )

        let halfPosition =
            SIMD3<Float>(
                Float(radiusMeters * 0.50),
                0.0,
                0.0
            )

        let edgePosition =
            SIMD3<Float>(
                Float(radiusMeters * 0.95),
                0.0,
                0.0
            )

        // ========================================================
        // SAMPLE AUTHORITATIVE QRTL GRAVITATIONAL POTENTIAL
        // ========================================================

        let centerPotential =
            Double(
                field.gravitationalPotential(
                    at: centerPosition
                )
            )

        let quarterPotential =
            Double(
                field.gravitationalPotential(
                    at: quarterPosition
                )
            )

        let halfPotential =
            Double(
                field.gravitationalPotential(
                    at: halfPosition
                )
            )

        let edgePotential =
            Double(
                field.gravitationalPotential(
                    at: edgePosition
                )
            )

        // ========================================================
        // UPDATE SWIFTUI STATE ON MAIN THREAD
        // ========================================================

        DispatchQueue.main.async {

            self.potentialCenter =
                centerPotential

            self.potentialQuarter =
                quarterPotential

            self.potentialHalf =
                halfPotential

            self.potentialEdge =
                edgePotential

            // ====================================================
            // FIND REFERENCE MAGNITUDE
            // ====================================================

            let maximumMagnitude =
                max(
                    abs(centerPotential),
                    abs(quarterPotential),
                    abs(halfPotential),
                    abs(edgePotential),
                    1e-30
                )

            // ====================================================
            // CLASSIFY POTENTIAL LEVELS
            // ====================================================

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

            // ====================================================
            // POTENTIAL MAGNITUDES
            // ====================================================

            let centerMagnitude =
                abs(centerPotential)

            let quarterMagnitude =
                abs(quarterPotential)

            let halfMagnitude =
                abs(halfPotential)

            let edgeMagnitude =
                abs(edgePotential)

            // ====================================================
            // DETERMINE WHETHER POTENTIAL IS FLAT
            // ====================================================

            let isFlat =
                centerMagnitude < 1e-30
                ||
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

            // ====================================================
            // DETERMINE WHETHER POTENTIAL FORMS EXPECTED WELL
            // ====================================================

            let formsWell =
                centerMagnitude >
                quarterMagnitude
                &&
                quarterMagnitude >
                halfMagnitude
                &&
                halfMagnitude >
                edgeMagnitude

            // ====================================================
            // UPDATE STATUS
            // ====================================================

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


    // ================================================================
    // MARK: - FULL QRTL PHYSICS PIPELINE
    // ================================================================
    //
    // AUTHORITATIVE PIPELINE
    //
    // 1. Physical stellar mass
    // 2. Physical cluster radius
    // 3. QRTL parameters
    // 4. Lensing parameters
    // 5. Physical stellar positions
    // 6. Authoritative QRTL field
    // 7. QRTL gravitational potential
    // 8. Unified QRTL spacetime metric
    // 9. Gravity validation
    // 10. QRTL heatmap
    // 11. Static spacetime visualization
    // 12. Source galaxy
    // 13. Photon tracing through QRTL field
    // 14. Projection-plane intersections
    // 15. Projection map
    // 16. Continuous photon visualization
    //
    // IMPORTANT:
    //
    // ContentView constructs the physics.
    // LensingSceneController owns the scene and photon tracing.
    //
    // There must be only ONE photon-tracing pass.
    // ================================================================

    // ================================================================
    // MARK: - FULL QRTL PHYSICS PIPELINE
    // ================================================================
    //
    // AUTHORITATIVE PIPELINE
    //
    // 1. Physical stellar mass
    // 2. Physical cluster radius
    // 3. QRTL parameters
    // 4. Lensing parameters
    // 5. Physical stellar positions
    // 6. Authoritative QRTL field
    // 7. QRTL gravitational potential
    // 8. Unified QRTL spacetime metric
    // 9. Gravity validation
    // 10. QRTL heatmap — SAMPLED IN PHYSICAL METERS
    // 11. Static spacetime visualization
    // 12. Source galaxy
    // 13. Photon tracing through QRTL field
    // 14. Projection-plane intersections
    // 15. Projection map
    // 16. Continuous photon visualization
    //
    // IMPORTANT:
    //
    // ContentView constructs the physics.
    //
    // LensingSceneController owns the SceneKit scene,
    // gravity-surface installation, and photon tracing.
    //
    // QRTLHeatmapGenerator operates in PHYSICAL METERS.
    //
    // SceneKit visualization operates in SCENE UNITS.
    //
    // These coordinate systems must not be mixed.
    //
    // There is only ONE authoritative photon-tracing pass.
    // ================================================================

    private func runFullPipeline() {

        // ============================================================
        // PREVENT DUPLICATE PIPELINE EXECUTION
        // ============================================================

        guard !isRunning else {
            return
        }

        // ============================================================
        // STOP PREVIOUS CONTINUOUS SIMULATION
        // ============================================================

        scene.stopContinuousPhotonSimulation()

        continuousPhotonEmissionStarted = false

        // ============================================================
        // RESET PIPELINE STATE
        // ============================================================

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

        photonSimulationProgress =
            PhotonSimulationProgress(
                total: 0,
                completed: 0,
                active: 0,
                projectionHits: 0
            )

        computationStage =
            "Initializing QRTL lens"

        computationDetail =
            "Creating the physical stellar mass distribution."

        statusMessage =
            "Starting QRTL lensing pipeline…"

        showComputationOverlay = true

        let computationStart =
            CFAbsoluteTimeGetCurrent()

        // ============================================================
        // PHYSICAL PARAMETERS
        // ============================================================

        let mass =
            massSolar * PhysicalConstants.solarMass

        let radiusMeters =
            radiusSolar * PhysicalConstants.solarRadius

        // ============================================================
        // QRTL PARAMETERS
        // ============================================================

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

        // ============================================================
        // LENSING PARAMETERS
        // ============================================================

        var lensingParameters =
            LensingParameters()

        lensingParameters.qrtlLensingStrength =
            1.0

        lensingParameters.qrtlFieldCoupling =
            1.0

        lensingParameters.maximumPhotonBend =
            0.35

        lensingParameters.electromagneticCoupling =
            Float(electromagneticCoupling)

        lensingParameters.magneticPhotonCoupling =
            1.0

        lensingParameters.magneticBendingStrength =
            1.0

        lensingParameters.currentCoupling =
            1.0

        lensingParameters.interactionRate =
            Float(interactionRate)

        lensingParameters.qrtlPhotonCoupling =
            0.25

        // ============================================================
        // CAPTURE VALUES FOR BACKGROUND WORK
        // ============================================================

        let massSolarCaptured =
            massSolar

        let radiusMetersCaptured =
            radiusMeters

        // ============================================================
        // IMPORTANT:
        //
        // DO NOT capture scene.heatmapHalfExtent here.
        //
        // That is a SceneKit-space visualization quantity.
        //
        // The heatmap must be sampled over the physical QRTL
        // cluster radius in METERS.
        // ============================================================

        let physicsWorkItem =
            DispatchWorkItem {

                autoreleasepool {

                    // =================================================
                    // STAGE 1 — PHYSICAL SOURCE / QRTL FIELD
                    // =================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 1 / 5 — physical source"

                        self.computationDetail =
                            """
                            Creating the \(Int(massSolarCaptured)) \
                            solar-mass globular cluster and QRTL field.
                            """

                        self.computationProgress =
                            0.08

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            -
                            computationStart

                        self.statusMessage =
                            "Stage 1/5 — creating QRTL spacetime field…"
                    }

                    // =================================================
                    // CREATE AUTHORITATIVE QRTL EXPERIMENT
                    // =================================================

                    let experiment =
                        QRTLExperiment(
                            mass: mass,
                            radius: radiusMetersCaptured,
                            parameters: params
                        )

                    // =================================================
                    // AUTHORITATIVE QRTL FIELD
                    // =================================================

                    let field =
                        experiment.field

                    // =================================================
                    // SAMPLE POTENTIAL FOR UI VALIDATION
                    // =================================================

                    self.updatePotentialOverlay(
                        field: field,
                        radiusMeters: radiusMetersCaptured
                    )

                    // =================================================
                    // MASS VALIDATION
                    // =================================================

                    let requestedMass =
                        mass

                    let actualMass =
                        Double(
                            field.densitySource.totalMass
                        )

                    let relativeMassError =
                        requestedMass > 0.0
                        ? abs(
                            actualMass
                            -
                            requestedMass
                        )
                        /
                        requestedMass
                        : 0.0

                    let starCount =
                        field.densitySource.starCount

                    let actualPerStarMass =
                        Double(
                            field.densitySource.perStarMassKg
                        )

                    // =================================================
                    // VALIDATE FIELD / GRAVITY PIPELINE
                    // =================================================

                    let outcome =
                        experiment.run(
                            impactParameter:
                                0.15
                                *
                                PhysicalConstants.solarRadius,

                            startDistance:
                                6.0
                                *
                                PhysicalConstants.solarRadius,

                            endDistance:
                                6.0
                                *
                                PhysicalConstants.solarRadius,

                            stepSize:
                                0.15
                                *
                                PhysicalConstants.solarRadius
                        )

                    // =================================================
                    // UPDATE GRAVITY METRICS
                    // =================================================

                    DispatchQueue.main.async {

                        self.gravityRequestedMassSolar =
                            massSolarCaptured

                        self.gravityFieldMassKg =
                            actualMass

                        self.gravityRelativeMassError =
                            relativeMassError

                        self.gravityStarCount =
                            starCount

                        self.gravityPerStarMassKg =
                            actualPerStarMass

                        self.gravityPerStarMassSolar =
                            actualPerStarMass
                            /
                            PhysicalConstants.solarMass

                        self.gravityClusterRadiusMeters =
                            radiusMetersCaptured
                    }

                    // =================================================
                    // STAGE 2 — AUTHORITATIVE FIELD VALIDATION
                    // =================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 2 / 5 — QRTL field validation"

                        self.computationDetail =
                            """
                            Validating the physical QRTL mass distribution \
                            and gravitational potential before visualization.
                            """

                        self.computationProgress =
                            0.30

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            -
                            computationStart

                        self.statusMessage =
                            "Stage 2/5 — validating QRTL field…"
                    }

                    // =================================================
                    // STAGE 3 — QRTL HEATMAP
                    // =================================================
                    //
                    // CRITICAL UNIT BOUNDARY
                    //
                    // QRTLHeatmapGenerator expects PHYSICAL METERS.
                    //
                    // radiusMetersCaptured is the actual physical
                    // cluster radius.
                    //
                    // DO NOT use:
                    //
                    //     scene.heatmapHalfExtent
                    //
                    // because that value belongs to SceneKit space.
                    //
                    // The heatmap must cover:
                    //
                    //     -radiusMeters ... +radiusMeters
                    //
                    // in the physical QRTL coordinate system.
                    // =================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 3 / 5 — QRTL density heatmap"

                        self.computationDetail =
                            """
                            Sampling the authoritative QRTL field across \
                            the physical cluster radius.
                            """

                        self.computationProgress =
                            0.55

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            -
                            computationStart

                        self.statusMessage =
                            "Stage 3/5 — generating QRTL field visualization…"
                    }

                    // =================================================
                    // PHYSICAL HEATMAP EXTENT
                    // =================================================

                    let heatmapHalfExtentMeters =
                        radiusMetersCaptured

                    // =================================================
                    // GENERATE HEATMAP
                    // =================================================
                    //
                    // This call stays entirely in physical coordinates.
                    //
                    // field:
                    //     authoritative QRTL field
                    //
                    // size:
                    //     image resolution
                    //
                    // halfExtent:
                    //     physical meters
                    // =================================================

                    let heatmapImage =
                        QRTLHeatmapGenerator.makeHeatmapImage(
                            field: field,
                            size: 128,
                            halfExtent:
                                heatmapHalfExtentMeters
                        )

                    // =================================================
                    // STAGE 4 / 5 — SCENE + PHOTON GEODESICS
                    // =================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 4–5 / 5 — scene + photon geodesics"

                        self.computationDetail =
                            """
                            Installing the physical QRTL gravity surface, \
                            source galaxy, heatmap, then executing one \
                            authoritative photon-tracing pass.
                            """

                        self.computationProgress =
                            0.75

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            -
                            computationStart

                        self.statusMessage =
                            "Stage 4–5/5 — tracing photons through QRTL field…"

                        // =================================================
                        // FIELD OWNERSHIP
                        // =================================================

                        self.scene.qrtlField =
                            field

                        // =================================================
                        // STATIC VISUAL SOURCE
                        // =================================================

                        self.scene.addGlobularCluster(
                            radius: 4.0
                        )

                        self.scene.addSourceGalaxy()

                        // =================================================
                        // AUTHORITATIVE QRTL GRAVITY SURFACE
                        // =================================================

                        self.scene.installQRTLGravitySurface(
                            field: field
                        )

                        // =================================================
                        // HEATMAP-TEXTURED SPACETIME SURFACE
                        // =================================================
                        //
                        // heatmapImage was generated using physical
                        // meters. The scene controller now handles the
                        // conversion into its SceneKit visualization.
                        // =================================================

                        self.scene.addDeformedSpacetimeSurface(
                            field: field,
                            heatmap: heatmapImage
                        )

                        // =================================================
                        // ONE AUTHORITATIVE PHOTON PASS
                        // =================================================
                        //
                        // SourceGalaxy → QRTLPhotonTracer
                        //
                        // No second static photon pass.
                        // =================================================

                        let batch =
                            self.scene.runAuthoritativePhotonPass(
                                field: field,
                                parameters: lensingParameters
                            ) { progress in

                                self.photonsTraced =
                                    progress.completed

                                self.photonPathPoints =
                                    progress.pathPoints

                                self.maximumQRTLInfluence =
                                    progress.maximumQRTLInfluence

                                self.computationProgress =
                                    0.75
                                    +
                                    0.20
                                    *
                                    Double(progress.completed)
                                    /
                                    max(
                                        Double(progress.total),
                                        1.0
                                    )

                                self.computationElapsed =
                                    CFAbsoluteTimeGetCurrent()
                                    -
                                    computationStart
                            }

                        // =================================================
                        // FINAL PHOTON RESULTS
                        // =================================================

                        self.photonsCreated =
                            batch.traces.count

                        self.photonsTraced =
                            batch.traces.count

                        self.projectionHits =
                            batch.hits.count

                        self.photonPathPoints =
                            batch.paths.reduce(0) {
                                $0 + $1.count
                            }

                        self.maximumQRTLInfluence =
                            batch.traces
                                .map(
                                    \.maximumQRTLInfluence
                                )
                                .max()
                            ?? 0.0

                        // =================================================
                        // STORE EXPERIMENT RESULT
                        // =================================================

                        self.result =
                            outcome

                        // =================================================
                        // CONTINUOUS PHOTON EMISSION
                        // =================================================
                        //
                        // Uses the SAME field and SAME lensing parameters.
                        //
                        // This is visualization only and does not replace
                        // the authoritative photon pass above.
                        // =================================================

                        self.scene.beginContinuousEmission(
                            field: field,
                            parameters: lensingParameters
                        )

                        self.continuousPhotonEmissionStarted =
                            true

                        // =================================================
                        // COMPLETE
                        // =================================================

                        self.computationProgress =
                            1.0

                        self.computationStage =
                            "COMPLETE"

                        self.computationDetail =
                            """
                            QRTL field, heatmap, spacetime surface, \
                            source galaxy, and photon geodesics are active.
                            """

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            -
                            computationStart

                        self.statusMessage =
                            """
                            QRTL lensing complete — \
                            \(batch.hits.count) projection hits
                            """

                        self.isRunning =
                            false

                        self.showComputationOverlay =
                            false

                        self.showGravityMetrics =
                            true
                    }
                }
            }

        // ============================================================
        // EXECUTE PHYSICS OFF MAIN THREAD
        // ============================================================

        DispatchQueue.global(
            qos: .userInitiated
        ).async(
            execute: physicsWorkItem
        )
    }




}
