/*
 The key change is to stop making the photon follow the QRTL radial field vector. Instead, the QRTL field should behave as a central lensing potential whose transverse influence accumulates along the photon path.
 */
/*
 The key change is to stop making the photon follow the QRTL radial field vector. Instead, the QRTL field should behave as a central lensing potential whose transverse influence accumulates along the photon path.
 */
import SwiftUI
import SceneKit
import simd
import Combine
import UIKit


struct ContentView:
    View {

    
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


   
    @State private var result:
        QRTLExperimentResult?


    @State private var isRunning:
        Bool =
        false


    @State private var statusMessage:
        String =
        "Ready — source galaxy → QRTL lens → observation plane"


  

    @State private var showControls:
            Bool =
            false

        @State private var showPhotonPaths:
            Bool =
            true



    @StateObject private var scene =
        LensingSceneController()


    var globularClusterPositions: [SIMD3<Float>] = []
    
    var body:
        some View {

        ZStack {

            LensingSceneView(
                controller:
                    scene
            )
            .ignoresSafeArea()

            VStack {

                Spacer()

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
        // INITIAL SETUP
        //
        // Build the persistent scene furniture ONCE here.
        // clearDynamic() (called inside runFullPipeline()) no
        // longer removes the cluster/galaxy/bottom plane — see
        // the earlier clearDynamic fix — so runFullPipeline()
        // no longer needs to rebuild them on every call, and this
        // no longer races against clearDynamic() wiping them out.
        // ====================================================

        .onAppear {

            scene.addGlobularCluster(
                radius: 4.0
            )

            scene.addSourceGalaxy()

            scene.addBottomPlaceholder()

            runFullPipeline()
        }

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


    // ========================================================
    // RESET
    // ========================================================

    private func reset() {

        guard !isRunning
        else {
            return
        }

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
        // CLEAR PER-RUN OUTPUTS, THEN EXPLICITLY REBUILD
        // FURNITURE
        //
        // addGlobularCluster / addSourceGalaxy / addFrontProjectionPlane /
        // addBottomPlaceholder each remove their own previous node
        // before adding a new one, so calling them again here is
        // safe and idempotent — this deliberately gives Reset a
        // "fresh start" look, distinct from a normal pipeline run
        // which now leaves the cluster/galaxy alone.
        // ----------------------------------------------------

        scene.clearDynamic()

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
        // CLEAR PER-RUN PIPELINE OUTPUTS
        // ========================================================

        scene.clearDynamic()

        // ========================================================
        // CAPTURE SOURCE GALAXY
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

        lensingParameters.photonStepSize =
            0.04

        lensingParameters.maximumPhotonSteps =
            1500

        lensingParameters.maximumPropagationRadius =
            60.0

        lensingParameters.deflectionStrength =
            0.35

        lensingParameters.qrtlLensingStrength =
            0.40

        lensingParameters.qrtlFieldCoupling =
            8.0

        lensingParameters.maximumPhotonBend =
            0.12

        lensingParameters.projectionDistance =
            10.0

        lensingParameters.projectionPlaneHalfExtent =
            18.0

        lensingParameters.magneticPhotonCoupling =
            1.0

        lensingParameters.magneticBendingStrength =
            1.0

        lensingParameters.currentCoupling =
            1.0

        lensingParameters.electromagneticCoupling =
            1.0

        // ========================================================
        // BACKGROUND PHYSICS
        // ========================================================

        let physicsWorkItem =
            DispatchWorkItem {

                autoreleasepool {

                    // =================================================
                    // STAGE 1 — QRTL EXPERIMENT
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
                    let clusterDensitySource =
                        GlobularClusterDensityMap(
                            positions:
                                globularClusterPositions,
                            radius:
                                Float(radius),
                            totalMass:
                                Float(mass),
                            cellSize:
                                0.20
                        )

                    let field =
                        QRTLField(
                            densitySource:
                                clusterDensitySource,
                            parameters:
                                params
                        )
                    // =================================================
                    // STAGE 2 — SOURCE GALAXY PHOTONS
                    // =================================================

                    DispatchQueue.main.async {

                        self.statusMessage =
                            "Stage 2/4 — tracing galaxy photons…"
                    }

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

                    let projection =
                        LensingProjectionResult.calculate(
                            from:
                                photonBatch.hits
                        )

                    // =================================================
                    // STAGE 3 — PREPARE PROJECTION
                    // =================================================

                    DispatchQueue.main.async {

                        self.statusMessage =
                            "Stage 3/4 — preparing projection scene…"
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
                    // STAGE 4 — RENDER
                    // =================================================

                    DispatchQueue.main.async {

                        self.statusMessage =
                            "Stage 4/4 — rendering QRTL gravity surface…"

                        // ------------------------------------------------
                        // RENDER NORMAL PIPELINE OUTPUT
                        // ------------------------------------------------

                        self.scene.renderPipelineOutput(
                            output,
                            showPhotonPaths:
                                showPaths
                        )

                        // ------------------------------------------------
                        // INSTALL COMPLETE QRTL GRAVITY SURFACE
                        //
                        // QRTLGravitySurfaceEntity owns:
                        //
                        //   • curved gravity surface
                        //   • photon A paths
                        //   • photon B paths
                        //   • galaxy A projection
                        //   • galaxy B projection
                        // ------------------------------------------------

                        self.scene.installQRTLGravitySurface(
                            field:
                                field
                        )

                        // ------------------------------------------------
                        // OPTIONAL EXISTING SPACETIME SURFACE
                        //
                        // Keep this only if you still want the older
                        // deformed heatmap surface in addition to the
                        // QRTLGravitySurfaceEntity.
                        // ------------------------------------------------

                        self.scene.addDeformedSpacetimeSurface(
                            field:
                                field,

                            heatmap:
                                heatmapImage
                        )

                        // ------------------------------------------------
                        // RESULTS
                        // ------------------------------------------------

                        self.result =
                            outcome

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
        // EXECUTE BACKGROUND WORK
        // ========================================================

        DispatchQueue.global(
            qos:
                .userInitiated
        ).async(
            execute:
                physicsWorkItem
        )
    }
}
