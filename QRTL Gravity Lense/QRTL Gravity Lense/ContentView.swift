/*
 The key change is to stop making the photon follow the QRTL radial field vector. Instead, the QRTL field should behave as a central lensing potential whose transverse influence accumulates along the photon path.
 */
/*
 The key change is to stop making the photon follow the QRTL radial field vector. Instead, the QRTL field should behave as a central lensing potential whose transverse influence accumulates along the photon path.
 */

/*
The key change is to stop making the photon follow the QRTL radial field vector. Instead, the QRTL field should behave as a central lensing potential whose transverse influence accumulates along the photon path.
*/
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
    // MARK: - LIVE COMPUTATION OVERLAY
    // ============================================================

    @State private var computationStage: String =
        "Idle"

    @State private var computationDetail: String =
        "Ready to begin QRTL lensing computation."

    @State private var photonsCreated: Int = 0

    @State private var photonsTraced: Int = 0

    @State private var photonPathPoints: Int = 0

    @State private var projectionHits: Int = 0

    @State private var computationElapsed: Double = 0.0

    @State private var computationProgress: Double = 0.0

    @State private var maximumQRTLInfluence: Float = 0.0


    @State private var showComputationOverlay: Bool = true

    // ============================================================
    // MARK: - GRAVITY METRICS OVERLAY
    // ============================================================
    //
    // Populated once the QRTLField exists (Stage 1 of
    // runFullPipeline), so you can confirm the cluster mass —
    // and the per-star mass sourcing the gravity surface — are
    // what you expect, independent of the transient computation
    // overlay above.
    // ============================================================

    @State private var showGravityMetrics: Bool = true

    @State private var gravityRequestedMassSolar: Double = 0.0

    @State private var gravityFieldMassKg: Double = 0.0

    @State private var gravityRelativeMassError: Double = 0.0

    @State private var gravityStarCount: Int = 0

    @State private var gravityPerStarMassSolar: Double = 0.0

    @State private var gravityPerStarMassKg: Double = 0.0

    @State private var gravityClusterRadiusMeters: Double = 0.0
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
            // GRAVITY METRICS OVERLAY
            // ====================================================

            if showGravityMetrics {

                gravityMetricsOverlay
            }

            // ====================================================
            // BOTTOM CONTROLS
            // ====================================================

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

            if visible { scene.displayPhotonPaths( output.photonPaths ) } else { scene.clearPhotonPaths() }
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
                    format: "%.5g",
                    maximumQRTLInfluence
                )
            )

            computationRow(
                "Elapsed",
                String(
                    format: "%.1f s",
                    computationElapsed
                )
            )
        }
        .padding(16)
        .frame(
            maxWidth: 360
        )
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(
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
    // MARK: - GRAVITY METRICS OVERLAY
    // ============================================================
    //
    // Shows the actual mass driving the cluster, so you can
    // confirm it against what you dialed in: requested vs. field
    // mass, the relative error between them, star count, and the
    // per-star mass (10^6 M☉ / star count) that sources every
    // occupied cell of the gravity surface.
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
                    gravityRelativeMassError *
                    100.0
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
        }
        .padding(16)
        .frame(
            maxWidth: 320
        )
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(
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

        alphaQ = 0.0
        etaQ = 0.0
        gammaQ = 1.0

        electromagneticCoupling = 0.0
        photonEMCoupling = 0.0

        chiQ = 1.0
        interactionRate = 0.0

        result = nil

        // --------------------------------------------------------
        // RESET COMPUTATION OVERLAY
        // --------------------------------------------------------

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

        // --------------------------------------------------------
        // RESET GRAVITY METRICS OVERLAY
        // --------------------------------------------------------

        gravityRequestedMassSolar = 0.0
        gravityFieldMassKg = 0.0
        gravityRelativeMassError = 0.0
        gravityStarCount = 0
        gravityPerStarMassSolar = 0.0
        gravityPerStarMassKg = 0.0
        gravityClusterRadiusMeters = 0.0

        // --------------------------------------------------------
        // CLEAR SCENE
        // --------------------------------------------------------

        scene.clearDynamic()

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
        // LOCK PIPELINE
        // ========================================================

        isRunning = true

        result = nil

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
            "Preparing the 10⁶ solar-mass central lens."

        statusMessage =
            "Starting QRTL lensing pipeline…"

        let computationStart =
            CFAbsoluteTimeGetCurrent()

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
        // QRTL PHYSICAL PARAMETERS
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
        // PHOTON LENSING PARAMETERS
        // ========================================================

        var lensingParameters =
            LensingParameters()

        // --------------------------------------------------------
        // QRTL CENTRAL LENSING POTENTIAL
        // --------------------------------------------------------

        lensingParameters.qrtlLensingStrength =
            1.0

        lensingParameters.qrtlFieldCoupling =
            1.0

        lensingParameters.maximumPhotonBend =
            0.35

        // --------------------------------------------------------
        // ELECTROMAGNETIC PHOTON INTERACTION
        // --------------------------------------------------------

        lensingParameters.electromagneticCoupling =
            Float(
                electromagneticCoupling
            )

        lensingParameters.magneticPhotonCoupling =
            1.0

        lensingParameters.magneticBendingStrength =
            1.0

        // --------------------------------------------------------
        // PROJECTION PLANE
        // --------------------------------------------------------

        lensingParameters.projectionPlaneHalfExtent =
            18.0

        // --------------------------------------------------------
        // OPTIONAL INTERACTION PARAMETERS
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
        // PHYSICS WORK ITEM
        // ========================================================

        let physicsWorkItem =
            DispatchWorkItem {

                autoreleasepool {

                    // ====================================================
                    // STAGE 1 — QRTL FIELD
                    // ====================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 1 / 4 — QRTL spacetime field"

                        self.computationDetail =
                            "Creating the 10⁶ solar-mass central lens and calculating its gravitational potential."

                        self.computationProgress =
                            0.05

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 1/4 — calculating QRTL spacetime field…"
                    }

                    // ====================================================
                    // AUTHORITATIVE QRTL EXPERIMENT
                    // ====================================================

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

                    // ====================================================
                    // FIELD CREATED
                    // ====================================================

                    DispatchQueue.main.async {

                        self.computationDetail =
                            "QRTL field created. Validating total mass and radial density."

                        self.computationProgress =
                            0.15

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart
                    }

                    // ====================================================
                    // MASS CONSERVATION CHECK
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

                    // ====================================================
                    // GRAVITY METRICS OVERLAY UPDATE
                    // ====================================================

                    let starCount =
                        field.densitySource.starCount

                    let perStarMassKg =
                        Double(
                            field.densitySource.perStarMassKg
                        )

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
                            perStarMassKg

                        self.gravityPerStarMassSolar =
                            perStarMassKg /
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
                    // STAGE 2 — PHOTON TRACING
                    // ====================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 2 / 4 — tracing photons"

                        self.computationDetail =
                            "Tracing source-galaxy photons through the central QRTL lens. Each photon accumulates transverse curvature along its path."

                        self.computationProgress =
                            0.20

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 2/4 — tracing galaxy photons through QRTL gravity and EM field…"
                    }

                    // ====================================================
                    // TRACE SOURCE GALAXY
                    //
                    // This assumes traceSourceGalaxy has a progress
                    // callback. The callback should be invoked by the
                    // controller after each photon is completed.
                    // ====================================================
                    let photonBatch =
                        self.scene.traceSourceGalaxy(
                            field: field,
                            parameters: lensingParameters,
                            progress: { progress in

                                DispatchQueue.main.async {

                                    self.photonsCreated =
                                        progress.total

                                    self.photonsTraced =
                                        progress.completed

                                    self.photonPathPoints =
                                        progress.pathPoints

                                    self.maximumQRTLInfluence =
                                        progress.maximumQRTLInfluence

                                    let photonFraction =
                                        Double(progress.completed) /
                                        Double(
                                            max(
                                                progress.total,
                                                1
                                            )
                                        )

                                    self.computationProgress =
                                        0.20 +
                                        (
                                            photonFraction *
                                            0.55
                                        )

                                    self.computationStage =
                                        "Stage 2 / 4 — tracing photons"

                                    self.computationDetail =
                                        """
                                        Photon \(progress.completed) of \(progress.total)

                                        Calculating gravitational spacetime curvature,
                                        QRTL transverse influence, photon deflection,
                                        and accumulated curved path.
                                        """

                                    self.computationElapsed =
                                        CFAbsoluteTimeGetCurrent()
                                        - computationStart
                                }
                            }
                        )
                    
                    // UPDATE PHOTON COUNT
                    // ====================================================

                    DispatchQueue.main.async {

                        self.photonsCreated =
                            photonBatch.traces.count

                        self.photonsTraced =
                            photonBatch.traces.count

                        self.photonPathPoints =
                            photonBatch.paths.reduce(
                                0
                            ) {
                                $0 + $1.count
                            }

                        self.projectionHits =
                            photonBatch.hits.count

                        self.computationProgress =
                            0.76

                        self.computationDetail =
                            """
                            Photon tracing complete.

                            \(photonBatch.traces.count) photons traced.
                            \(photonBatch.paths.count) curved photon paths generated.
                            \(photonBatch.hits.count) photons reached the projection plane.
                            """

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart
                    }

                    // ====================================================
                    // STAGE 3 — PROJECTION
                    // ====================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 3 / 4 — projection plane"

                        self.computationDetail =
                            "Mapping the final positions of curved photon trajectories onto the target observation plane."

                        self.computationProgress =
                            0.80

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 3/4 — preparing two-galaxy projection…"
                    }

                    // ====================================================
                    // CALCULATE PROJECTION
                    // ====================================================

                    let projection =
                        LensingProjectionResult.calculate(
                            from:
                                photonBatch.hits
                        )

                    DispatchQueue.main.async {

                        self.projectionHits =
                            photonBatch.hits.count

                        self.computationProgress =
                            0.84

                        self.computationDetail =
                            """
                            Projection calculated.

                            \(photonBatch.hits.count) photon intersections
                            mapped onto the observation plane.
                            """

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart
                    }

                    // ====================================================
                    // PREPARE OUTPUT
                    // ====================================================

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

                    // ====================================================
                    // HEATMAP
                    // ====================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 3 / 4 — QRTL density heatmap"

                        self.computationDetail =
                            "Sampling QRTL mass density across the central lensing surface."

                        self.computationProgress =
                            0.86

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart
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

                    DispatchQueue.main.async {

                        self.computationProgress =
                            0.90

                        self.computationDetail =
                            "QRTL mass-density heatmap generated."
                    }

                    // ====================================================
                    // STAGE 4 — RENDERING
                    // ====================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 4 / 4 — rendering"

                        self.computationDetail =
                            """
                            Rendering the QRTL gravity surface,
                            curved photon paths, spacetime surface,
                            heatmap, and projection plane.
                            """

                        self.computationProgress =
                            0.94

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 4/4 — rendering QRTL gravity surface and photon projection…"

                        // ====================================================
                        // PHOTON / PROJECTION OUTPUT
                        // ====================================================

                        self.scene.renderPipelineOutput(
                            output,
                            showPhotonPaths:
                                showPaths
                        )

                        // ====================================================
                        // QRTL GRAVITY SURFACE
                        // ====================================================

                        self.scene.installQRTLGravitySurface(
                            field:
                                field
                        )

                        // ====================================================
                        // DEFORMED SPACETIME SURFACE
                        // ====================================================

                        self.scene.addDeformedSpacetimeSurface(
                            field:
                                field,

                            heatmap:
                                heatmapImage
                        )

                        // ====================================================
                        // STORE PIPELINE OUTPUT
                        // ====================================================

                        self.scene.lastPipelineOutput =
                            output

                        self.result =
                            outcome

                        // ====================================================
                        // FINAL COUNTERS
                        // ====================================================

                        self.photonsCreated =
                            photonBatch.traces.count

                        self.photonsTraced =
                            photonBatch.traces.count

                        self.projectionHits =
                            photonBatch.hits.count

                        self.photonPathPoints =
                            photonBatch.paths.reduce(
                                0
                            ) {
                                $0 + $1.count
                            }

                        // ====================================================
                        // COMPLETE
                        // ====================================================

                        self.computationProgress =
                            1.0

                        self.computationStage =
                            "COMPLETE"

                        self.computationDetail =
                            """
                            QRTL lensing simulation completed.

                            \(photonBatch.traces.count) photons traced.
                            \(photonBatch.paths.count) photon paths generated.
                            \(photonBatch.hits.count) photons reached the projection plane.
                            """

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Projection complete — " +
                            "\(photonBatch.hits.count) photon hits, " +
                            "\(photonBatch.paths.count) photon paths"
                   
                     
                        self.computationDetail = """
                        QRTL lensing simulation completed.
                        \(photonBatch.traces.count) photons traced.
                        \(photonBatch.paths.count) photon paths generated.
                        \(photonBatch.hits.count) photons reached the projection plane.
                        """

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Projection complete — " +
                            "\(photonBatch.hits.count) photon hits, " +
                            "\(photonBatch.paths.count) photon paths"

                        self.isRunning = false

                        // REMOVE COMPUTATION OVERLAY
                        self.showComputationOverlay = false
                    }
                }
            }

        // ========================================================
        // EXECUTE PHYSICS OFF MAIN THREAD
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
