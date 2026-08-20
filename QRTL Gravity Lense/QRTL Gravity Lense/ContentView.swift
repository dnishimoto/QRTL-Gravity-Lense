/*
 The key change is to stop making the photon follow the QRTL radial field vector. Instead, the QRTL field should behave as a central lensing potential whose transverse influence accumulates along the photon path.
 */
/*
 The key change is to stop making the photon follow the QRTL radial field vector. Instead, the QRTL field should behave as a central lensing potential whose transverse influence accumulates along the photon path.
 */
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
    // MARK: - PHYSICAL CLUSTER PARAMETERS
    // ============================================================

    @State private var massSolar: Double = 1_000_000.0
    @State private var radiusSolar: Double = 35.0

    // ============================================================
    // MARK: - QRTL PARAMETERS
    // ============================================================

    @State private var alphaQ: Double = 5e-6
    @State private var etaQ: Double = 3.0
    @State private var gammaQ: Double = 1.0
    @State private var electromagneticCoupling: Double = 2e-11
    @State private var photonEMCoupling: Double = 5e-21
    @State private var chiQ: Double = 1.0
    @State private var interactionRate: Double = 0.0

    // ============================================================
    // MARK: - UI STATE
    // ============================================================

    @State private var result: QRTLExperimentResult?

    @State private var isRunning: Bool = false

    @State private var statusMessage: String =
        "Ready — source galaxy → QRTL lens → observation plane"

    @State private var showControls: Bool = false

    @State private var showPhotonPaths: Bool = true

    // ============================================================
    // MARK: - SCENE CONTROLLER
    // ============================================================

    @StateObject private var scene =
        LensingSceneController()

    // ============================================================
    // MARK: - BODY
    // ============================================================

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

            scene.addGlobularCluster(
                radius: 4.0
            )

            scene.addSourceGalaxy()

            scene.addBottomPlaceholder()

            runFullPipeline()
        }

        // ========================================================
        // MARK: - PHOTON PATH VISIBILITY
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
                    output.photonPaths,
                    field: output.field
                )

            } else {

                scene.clearPhotonPaths()
            }
        }
    }

    // ============================================================
    // MARK: - RESET
    // ============================================================

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
            "Reset to QRTL gravity-only mode"

        // ========================================================
        // CLEAR SCENE
        // ========================================================

        scene.clearDynamic()

        scene.addGlobularCluster(
            radius: 4.0
        )

        scene.addSourceGalaxy()

        scene.addFrontProjectionPlane(
            empty: true
        )

        scene.addBottomPlaceholder()
    }

    // ============================================================
    // MARK: - FULL PHYSICS PIPELINE
    // ============================================================

    private func runFullPipeline() {

        guard !isRunning else {
            return
        }

        // ========================================================
        // LOCK PIPELINE
        // ========================================================

        isRunning = true
        result = nil

        statusMessage =
            "Starting QRTL lensing pipeline…"

        // ========================================================
        // CAPTURE SWIFTUI VALUES
        // ========================================================

        let mass =
            massSolar *
            PhysicalConstants.solarMass

        let radiusMeters =
            radiusSolar *
            PhysicalConstants.solarRadius

        let showPaths =
            showPhotonPaths

        let radius =
            radiusMeters

        // ========================================================
        // MARK: - QRTL PHYSICAL PARAMETERS
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
        // MARK: - PHOTON LENSING PARAMETERS
        // ========================================================

        var lensingParameters =
            LensingParameters()

    
   
        // --------------------------------------------------------
        // QRTL gravitational bending
        // --------------------------------------------------------

        lensingParameters.qrtlLensingStrength =
            1.0

        lensingParameters.qrtlFieldCoupling =
            1.0

        lensingParameters.maximumPhotonBend =
            0.35

        // --------------------------------------------------------
        // Electromagnetic photon interaction
        // --------------------------------------------------------

        lensingParameters.electromagneticCoupling =
            Float(
                electromagneticCoupling
            )

        lensingParameters.magneticPhotonCoupling =
            1.0

        lensingParameters.magneticBendingStrength =
            1.0


        lensingParameters.projectionPlaneHalfExtent =
            18.0

        // --------------------------------------------------------
        // Optional interaction parameters
        // --------------------------------------------------------

        lensingParameters.currentCoupling =
            1.0

        lensingParameters.interactionRate =
            Float(
                interactionRate
            )

        lensingParameters.qrtlPhotonCoupling =
            0.25

        // ========================================================
        // PHYSICS WORK
        // ========================================================

        let physicsWorkItem =
            DispatchWorkItem {

                autoreleasepool {

                    // =================================================
                    // STAGE 1
                    // =================================================

                    DispatchQueue.main.async {

                        self.statusMessage =
                            "Stage 1/4 — calculating QRTL spacetime field…"
                    }

                    // =================================================
                    // AUTHORITATIVE QRTL EXPERIMENT
                    // =================================================

                    let experiment =
                        QRTLExperiment(
                            mass:
                                mass,

                            radius:
                                radius,

                            parameters:
                                params
                        )

                    let field =
                        experiment.field

                    // =================================================
                    // MASS CONSERVATION CHECK
                    // =================================================

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

                    print(
                        """
                        ================================================
                        QRTL MASS VALIDATION
                        ================================================

                        Requested mass:
                            \(requestedMass) kg

                        Requested solar masses:
                            \(massSolar)

                        Field mass:
                            \(actualMass) kg

                        Relative mass error:
                            \(relativeMassError)

                        Physical radius:
                            \(radiusMeters) m

                        ================================================
                        """
                    )

                    // =================================================
                    // GRAVITATIONAL VALIDATION
                    // =================================================

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

                    // =================================================
                    // STAGE 2
                    // SOURCE GALAXY PHOTONS
                    // =================================================

                    DispatchQueue.main.async {

                        self.statusMessage =
                            "Stage 2/4 — tracing galaxy photons through QRTL gravity and EM field…"
                    }

                    // =================================================
                    // TRACE EVERY SOURCE GALAXY STAR
                    // =================================================

                    let photonBatch =
                        self.scene.traceSourceGalaxy(
                            field:
                                field,

                            parameters:
                                lensingParameters
                        )

                    // =================================================
                    // PROJECTION
                    // =================================================

                    let projection =
                        LensingProjectionResult.calculate(
                            from:
                                photonBatch.hits
                        )

                    // =================================================
                    // STAGE 3
                    // PREPARE OUTPUT
                    // =================================================

                    DispatchQueue.main.async {

                        self.statusMessage =
                            "Stage 3/4 — preparing two-galaxy projection…"
                    }

                    let output =
                        LensingPipelineOutput(

                            experimentResult:
                                outcome,

                            field:
                                field,

                            photonTraces:
                                photonBatch.traces,

                            photonPaths:
                                photonBatch.paths,

                            photonHits:
                                photonBatch.hits,

                            projection:
                                projection,

                            tracedPhotonCount:
                                photonBatch.traces.count,

                            successfulProjectionHits:
                                photonBatch.hits.count
                        )

                    // =================================================
                    // HEATMAP
                    // =================================================

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

                    // =================================================
                    // STAGE 4
                    // RENDER EVERYTHING
                    // =================================================

                    DispatchQueue.main.async {

                        self.statusMessage =
                            "Stage 4/4 — rendering QRTL gravity surface and photon projection…"

                        // ------------------------------------------------
                        // PHOTON / PROJECTION OUTPUT
                        // ------------------------------------------------

                        self.scene.renderPipelineOutput(
                            output,
                            showPhotonPaths:
                                showPaths
                        )

                        // ------------------------------------------------
                        // QRTL GRAVITY SURFACE
                        // ------------------------------------------------

                        self.scene.installQRTLGravitySurface(
                            field:
                                field
                        )

                        // ------------------------------------------------
                        // DEFORMED SPACETIME SURFACE
                        // ------------------------------------------------

                        self.scene.addDeformedSpacetimeSurface(
                            field:
                                field,

                            heatmap:
                                heatmapImage
                        )

                        // ------------------------------------------------
                        // STORE PIPELINE OUTPUT
                        // ------------------------------------------------

                        self.scene.lastPipelineOutput =
                            output

                        self.result =
                            outcome

                        // ------------------------------------------------
                        // FINAL STATUS
                        // ------------------------------------------------

                        self.statusMessage =
                            "Projection complete — " +
                            "\(photonBatch.hits.count) photon hits, " +
                            "\(photonBatch.paths.count) photon paths"

                        self.isRunning =
                            false
                    }
                }
            }

        // ========================================================
        // EXECUTE
        // ========================================================

        DispatchQueue.global(
            qos: .userInitiated
        )
        .async(
            execute:
                physicsWorkItem
        )
    }
}
