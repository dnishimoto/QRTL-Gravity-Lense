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

struct ContentView:
    View {

    // ========================================================
    // USER PARAMETERS
    // ========================================================

    @State private var massSolar:
        Double =
        1_000_000

    @State private var radiusSolar:
        Double =
        35

    @State private var alphaQ:
        Double =
        5e-6

    @State private var etaQ:
        Double =
        3.0

    @State private var gammaQ:
        Double =
        1.0

    @State private var electromagneticCoupling:
        Double =
        2e-11

    @State private var photonEMCoupling:
        Double =
        5e-21

    @State private var chiQ:
        Double =
        1.0

    @State private var interactionRate:
        Double =
        0.0


    // ========================================================
    // RESULTS
    // ========================================================

    @State private var result:
        QRTLExperimentResult?


    @State private var isRunning:
        Bool =
        false


    @State private var statusMessage:
        String =
        "Ready — source galaxy → QRTL lens → observation plane"


    // ========================================================
    // UI STATE
    // ========================================================

    @State private var showControls:
        Bool =
        false

    @State private var showPhotonPaths:
        Bool =
        true


    // ========================================================
    // SCENEKIT CONTROLLER
    // ========================================================

    @StateObject private var scene =
        LensingSceneController()


    // ========================================================
    // BODY
    // ========================================================

    var body:
        some View {

        ZStack {

            // ------------------------------------------------
            // SCENE
            // ------------------------------------------------

            LensingSceneView(
                controller:
                    scene
            )
            .ignoresSafeArea()


            // ------------------------------------------------
            // CONTROLS
            // ------------------------------------------------

            VStack {

                Spacer()


                // ------------------------------------------------
                // PHOTON PATH TOGGLE
                // ------------------------------------------------

                Toggle(
                    isOn:
                        $showPhotonPaths
                ) {

                    Label(
                        "Smooth Photon Paths",
                        systemImage:
                            "wave.3.forward"
                    )
                    .labelStyle(
                        .titleAndIcon
                    )
                }
                .padding(
                    .horizontal
                )
                .padding(
                    .bottom,
                    16
                )
                .foregroundColor(
                    .white
                )
                .background(
                    .ultraThinMaterial,
                    in:
                        Capsule()
                )
                .tint(
                    .pink
                )
                .frame(
                    maxWidth:
                        250
                )


                // ------------------------------------------------
                // CONTROL BUTTON
                // ------------------------------------------------

                HStack {

                    Spacer()

                    Button {

                        showControls =
                            true

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
                        .foregroundStyle(
                            .white
                        )
                        .padding(
                            16
                        )
                        .background(
                            .ultraThinMaterial,
                            in:
                                Circle()
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

        guard !isRunning
        else {
            return
        }


        // ----------------------------------------------------
        // RESET PARAMETERS
        // ----------------------------------------------------

        alphaQ =
            0.0

        etaQ =
            0.0

        gammaQ =
            1.0

        electromagneticCoupling =
            0.0

        photonEMCoupling =
            0.0

        chiQ =
            1.0

        interactionRate =
            0.0


        result =
            nil


        statusMessage =
            "Reset to pure GR"


        // ----------------------------------------------------
        // CLEAR SCENE
        // ----------------------------------------------------

        scene.clearDynamic()


        // ----------------------------------------------------
        // REBUILD BASIC SCENE
        // ----------------------------------------------------

        scene.addGlobularCluster(
            radius:
                radiusSolar *
                PhysicalConstants.solarRadius
        )


        scene.addSourceGalaxy()


        scene.addFrontProjectionPlane(
            empty:
                true
        )


        scene.addBottomPlaceholder()
    }


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

        let radius =
            radiusSolar *
            PhysicalConstants.solarRadius

        let showPaths =
            showPhotonPaths


        // ========================================================
        // CAPTURE SOURCE GALAXY
        //
        // Must happen before background processing.
        // ========================================================

        let sourceStars =
            scene.sourceGalaxyStars


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

        // --------------------------------------------------------
        // PHOTON PROPAGATION
        // --------------------------------------------------------

        lensingParameters.photonStepSize =
            0.04

        lensingParameters.maximumPhotonSteps =
            1500

        lensingParameters.maximumPropagationRadius =
            60.0

        lensingParameters.deflectionStrength =
            0.01


        // --------------------------------------------------------
        // PROJECTION
        // --------------------------------------------------------

        lensingParameters.projectionDistance =
            10.0

        lensingParameters.projectionPlaneHalfExtent =
            12.0


        // --------------------------------------------------------
        // FIELD COUPLINGS
        // --------------------------------------------------------

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


        // ========================================================
        // CLEAR OLD SCENE
        //
        // SceneKit work remains on the main thread.
        // ========================================================

        scene.clearDynamic()


        // ========================================================
        // BACKGROUND PHYSICS
        // ========================================================

        let physicsWorkItem =
            DispatchWorkItem {

                autoreleasepool {

                    // =================================================
                    // STAGE 1
                    // QRTL EXPERIMENT
                    // =================================================

                    DispatchQueue.main.async {

                        self.statusMessage =
                            "Stage 1/4 — calculating QRTL field…"
                    }


                    let experiment =
                        QRTLExperiment(

                            mass:
                                mass,

                            radius:
                                radius,

                            parameters:
                                params
                        )


                    // =================================================
                    // RUN QRTL EXPERIMENT
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
                    // CREATE QRTL FIELD
                    // =================================================

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


                    // =================================================
                    // STAGE 2
                    // SOURCE GALAXY PHOTONS
                    // =================================================

                    DispatchQueue.main.async {

                        self.statusMessage =
                            "Stage 2/4 — tracing galaxy photons…"
                    }


                    // =================================================
                    // CONTROLLER PHOTON PIPELINE
                    //
                    // ContentView does NOT trace photons.
                    //
                    // Controller:
                    //
                    // source stars
                    //      ↓
                    // traceSourceGalaxy()
                    //      ↓
                    // tracePhoton()
                    //      ↓
                    // PhotonTraceBatch
                    // =================================================

                    let photonBatch =
                        self.scene.traceSourceGalaxy(

                            stars:
                                sourceStars,

                            field:
                                field,

                            parameters:
                                lensingParameters,

                            showPaths:
                                showPaths
                        )


                    // =================================================
                    // CALCULATE PROJECTION
                    // =================================================

                    let projection =
                        LensingProjectionResult.calculate(

                            from:
                                photonBatch.hits
                        )


                    // =================================================
                    // STAGE 3
                    // =================================================

                    DispatchQueue.main.async {

                        self.statusMessage =
                            "Stage 3/4 — preparing projection scene…"
                    }


                    // =================================================
                    // BUILD COMPLETE PIPELINE OUTPUT
                    // =================================================

                    let output =
                        LensingPipelineOutput(

                            // ------------------------------------------------
                            // QRTL EXPERIMENT
                            // ------------------------------------------------

                            experimentResult:
                                outcome,

                            // ------------------------------------------------
                            // QRTL FIELD
                            // ------------------------------------------------

                            field:
                                field,

                            // ------------------------------------------------
                            // COMPLETE PHOTON TRACES
                            // ------------------------------------------------

                            photonTraces:
                                photonBatch.traces,

                            // ------------------------------------------------
                            // PHOTON PATHS
                            // ------------------------------------------------

                            photonPaths:
                                photonBatch.paths,

                            // ------------------------------------------------
                            // PROJECTION HITS
                            // ------------------------------------------------

                            photonHits:
                                photonBatch.hits,

                            // ------------------------------------------------
                            // FINAL PROJECTION
                            // ------------------------------------------------

                            projection:
                                projection,

                            // ------------------------------------------------
                            // DIAGNOSTICS
                            // ------------------------------------------------

                            tracedPhotonCount:
                                photonBatch.traces.count,

                            successfulProjectionHits:
                                photonBatch.hits.count
                        )


                    // =================================================
                    // STAGE 4
                    // RENDER
                    // =================================================

                    DispatchQueue.main.async {

                        self.statusMessage =
                            "Stage 4/4 — rendering projection…"


                        // =================================================
                        // SINGLE PHYSICS → SCENEKIT CONNECTION
                        // =================================================

                        self.scene.renderPipelineOutput(

                            output,

                            showPhotonPaths:
                                showPaths
                        )


                        // =================================================
                        // SAVE RESULT
                        // =================================================

                        self.result =
                            outcome


                        // =================================================
                        // FINAL STATUS
                        // =================================================

                        self.statusMessage =
                            "Projection complete — " +
                            "\(output.successfulProjectionHits) photon hits, " +
                            "\(output.photonPaths.count) photon paths"


                        // =================================================
                        // UNLOCK
                        // =================================================

                        self.isRunning =
                            false
                    }
                }
            }


        // ========================================================
        // EXECUTE BACKGROUND WORK
        // ========================================================

        DispatchQueue.global(
            qos:
                .userInitiated
        )
        .async(
            execute:
                physicsWorkItem
        )
    }
}
