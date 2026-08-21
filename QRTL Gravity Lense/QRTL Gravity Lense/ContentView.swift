
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

        // ============================================================
        // RESET / LOCK PIPELINE
        // ============================================================

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

        showComputationOverlay = true

        let computationStart =
            CFAbsoluteTimeGetCurrent()

        // ============================================================
        // CREATE / RESET VISUAL SOURCE GEOMETRY
        // ============================================================

        scene.addGlobularCluster(
            radius: 4.0
        )

        scene.addSourceGalaxy()

        // ============================================================
        // CAPTURE SWIFTUI VALUES
        // ============================================================

        let mass =
            massSolar *
            PhysicalConstants.solarMass

        let radiusMeters =
            radiusSolar *
            PhysicalConstants.solarRadius

        let showPaths =
            showPhotonPaths

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
            Float(
                electromagneticCoupling
            )

        lensingParameters.magneticPhotonCoupling =
            1.0

        lensingParameters.magneticBendingStrength =
            1.0

        lensingParameters.projectionPlaneHalfExtent =
            18.0

        lensingParameters.currentCoupling =
            1.0

        lensingParameters.interactionRate =
            Float(
                interactionRate
            )

        lensingParameters.qrtlPhotonCoupling =
            0.25

        // ============================================================
        // PHYSICS WORK ITEM
        // ============================================================

        let physicsWorkItem =
            DispatchWorkItem {

                autoreleasepool {

                    // ========================================================
                    // STAGE 1 — CREATE QRTL FIELD
                    // ========================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 1 / 4 — QRTL spacetime field"

                        self.computationDetail =
                            """
                            Creating the 10⁶ solar-mass central lens,
                            populating its density source, and validating
                            the QRTL field.
                            """

                        self.computationProgress =
                            0.05

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 1/4 — creating QRTL spacetime field…"
                    }

                    // ========================================================
                    // CREATE AUTHORITATIVE QRTL FIELD
                    // ========================================================

                    let experiment =
                        QRTLExperiment(
                            mass: mass,
                            radius: radiusMeters,
                            parameters: params
                        )

                    let field =
                        experiment.field

                    // ========================================================
                    // CRITICAL FIELD VALIDATION
                    //
                    // This MUST happen before rendering.
                    // If these values are zero, the problem is upstream
                    // of SceneKit.
                    // ========================================================

                    print("")
                    print("============================================================")
                    print("QRTL FIELD CREATED")
                    print("============================================================")
                    print("Requested mass:")
                    print(mass)
                    print("Requested radius:")
                    print(radiusMeters)
                    print("Density source:")
                    print(field.densitySource)
                    print("Total density-source mass:")
                    print(field.densitySource.totalMass)
                    print("Star count:")
                    print(field.densitySource.starCount)
                    print("Per-star mass:")
                    print(field.densitySource.perStarMassKg)
                    print("============================================================")
                    print("")

                    // ========================================================
                    // VALIDATE DENSITY SOURCE DIRECTLY
                    // ========================================================

                    let testPositions: [SIMD3<Float>] = [

                        SIMD3<Float>(
                            0.0,
                            0.0,
                            0.0
                        ),

                        SIMD3<Float>(
                            0.1,
                            0.0,
                            0.0
                        ),

                        SIMD3<Float>(
                            0.5,
                            0.0,
                            0.0
                        ),

                        SIMD3<Float>(
                            1.0,
                            0.0,
                            0.0
                        ),

                        SIMD3<Float>(
                            5.0,
                            0.0,
                            0.0
                        )
                    ]

                    for position in testPositions {

                        let density =
                            field.densitySource.density(
                                at: position
                            )

                        let fieldDensity =
                            field.massDensity(
                                at: position
                            )

                        print(
                            """
                            QRTL DENSITY CHECK
                            position: \(position)
                            densitySource.density: \(density)
                            field.massDensity: \(fieldDensity)
                            """
                        )
                    }

                    // ========================================================
                    // FULL QRTL DIAGNOSTIC
                    // ========================================================

                    field.diagnoseQRTLField(
                        at: SIMD3<Float>(
                            0.0,
                            0.0,
                            0.0
                        )
                    )

                    field.diagnoseQRTLField(
                        at: SIMD3<Float>(
                            0.1,
                            0.0,
                            0.0
                        )
                    )

                    field.diagnoseQRTLField(
                        at: SIMD3<Float>(
                            0.5,
                            0.0,
                            0.0
                        )
                    )

                    field.diagnoseQRTLField(
                        at: SIMD3<Float>(
                            1.0,
                            0.0,
                            0.0
                        )
                    )

                    field.diagnoseQRTLField(
                        at: SIMD3<Float>(
                            5.0,
                            0.0,
                            0.0
                        )
                    )

                    // ========================================================
                    // FIELD VALIDATION
                    // ========================================================

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

                    let perStarMassKg =
                        Double(
                            field.densitySource.perStarMassKg
                        )

                    print(
                        """
                        ============================================================
                        QRTL MASS VALIDATION
                        ============================================================
                        Requested mass:
                            \(requestedMass) kg

                        Requested solar masses:
                            \(massSolar)

                        Field mass:
                            \(actualMass) kg

                        Relative mass error:
                            \(relativeMassError)

                        Star count:
                            \(starCount)

                        Per-star mass:
                            \(perStarMassKg) kg

                        Physical radius:
                            \(radiusMeters) m
                        ============================================================
                        """
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

                        self.computationDetail =
                            """
                            QRTL field created and validated.
                            Density source contains \(starCount) stars.
                            Field mass = \(actualMass) kg.
                            """

                        self.computationProgress =
                            0.15
                    }

                    // ========================================================
                    // GRAVITATIONAL VALIDATION
                    // ========================================================

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

                    // ========================================================
                    // STAGE 2 — PHOTON TRACING
                    //
                    // IMPORTANT:
                    // Photons use the QRTLField directly.
                    // They do NOT require the SceneKit gravity surface.
                    // ========================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 2 / 4 — tracing photons"

                        self.computationDetail =
                            """
                            Tracing source-galaxy photons through the
                            validated QRTL gravitational field.
                            """

                        self.computationProgress =
                            0.20

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 2/4 — tracing galaxy photons through QRTL gravity and EM field…"
                    }

                    // ========================================================
                    // TRACE SOURCE GALAXY
                    // ========================================================

                    let photonBatch =
                        self.scene.traceSourceGalaxy(
                            field:
                                field,

                            parameters:
                                lensingParameters,

                            progress: {
                                progress in

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
                                        Double(
                                            progress.completed
                                        )
                                        /
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

                                        Calculating gravitational spacetime
                                        curvature, QRTL transverse influence,
                                        photon deflection, and curved path.
                                        """

                                    self.computationElapsed =
                                        CFAbsoluteTimeGetCurrent()
                                        - computationStart
                                }
                            }
                        )

                    // ========================================================
                    // PHOTON RESULTS
                    // ========================================================

                    let pathPointCount =
                        photonBatch.paths.reduce(
                            0
                        ) {
                            $0 + $1.count
                        }

                    DispatchQueue.main.async {

                        self.photonsCreated =
                            photonBatch.traces.count

                        self.photonsTraced =
                            photonBatch.traces.count

                        self.photonPathPoints =
                            pathPointCount

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

                    // ========================================================
                    // STAGE 3 — PROJECTION
                    // ========================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 3 / 4 — projection plane"

                        self.computationDetail =
                            """
                            Mapping the final positions of curved photon
                            trajectories onto the target observation plane.
                            """

                        self.computationProgress =
                            0.80

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 3/4 — preparing two-galaxy projection…"
                    }

                    // ========================================================
                    // CALCULATE PROJECTION
                    // ========================================================

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

                            \(photonBatch.hits.count)
                            photon intersections mapped
                            onto the observation plane.
                            """

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart
                    }

                    // ========================================================
                    // CREATE PIPELINE OUTPUT
                    // ========================================================

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

                    // ========================================================
                    // HEATMAP
                    // ========================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 3 / 4 — QRTL density heatmap"

                        self.computationDetail =
                            """
                            Sampling QRTL mass density across
                            the central lensing surface.
                            """

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

                    // ========================================================
                    // STAGE 4 — SCENEKIT RENDERING
                    //
                    // ALL SCENEKIT OPERATIONS ARE HERE.
                    //
                    // This is the ONLY place where the gravity surface
                    // should be installed.
                    // ========================================================

                    DispatchQueue.main.async {

                        self.computationStage =
                            "Stage 4 / 4 — rendering"

                        self.computationDetail =
                            """
                            Rendering the validated QRTL gravity surface,
                            curved photon paths, spacetime surface,
                            heatmap, and photon projection.
                            """

                        self.computationProgress =
                            0.94

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Stage 4/4 — rendering QRTL gravity surface and photon projection…"

                        // ====================================================
                        // 1. RENDER PHOTON / PROJECTION OUTPUT
                        // ====================================================

                        self.scene.renderPipelineOutput(
                            output,
                            showPhotonPaths:
                                showPaths
                        )

                        // ====================================================
                        // 2. INSTALL QRTL GRAVITY SURFACE
                        //
                        // IMPORTANT:
                        // This call has been removed from the background
                        // physics queue and exists ONLY here.
                        // ====================================================

                        self.scene.installQRTLGravitySurface(
                            field:
                                field
                        )

                        // ====================================================
                        // 3. DEFORMED SPACETIME SURFACE
                        // ====================================================

                        self.scene.addDeformedSpacetimeSurface(
                            field:
                                field,

                            heatmap:
                                heatmapImage
                        )

                        // ====================================================
                        // 4. STORE OUTPUT
                        // ====================================================

                        self.scene.lastPipelineOutput =
                            output

                        self.result =
                            outcome

                        // ====================================================
                        // 5. FINAL COUNTERS
                        // ====================================================

                        self.photonsCreated =
                            photonBatch.traces.count

                        self.photonsTraced =
                            photonBatch.traces.count

                        self.projectionHits =
                            photonBatch.hits.count

                        self.photonPathPoints =
                            pathPointCount

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

                            \(photonBatch.traces.count)
                            photons traced.

                            \(photonBatch.paths.count)
                            photon paths generated.

                            \(photonBatch.hits.count)
                            photons reached the projection plane.
                            """

                        self.computationElapsed =
                            CFAbsoluteTimeGetCurrent()
                            - computationStart

                        self.statusMessage =
                            "Projection complete — " +
                            "\(photonBatch.hits.count) photon hits, " +
                            "\(photonBatch.paths.count) photon paths"

                        self.isRunning =
                            false

                        self.showComputationOverlay =
                            false
                    }
                }
            }

        // ============================================================
        // EXECUTE PHYSICS OFF MAIN THREAD
        // ============================================================

        DispatchQueue.global(
            qos: .userInitiated
        )
        .async(
            execute:
                physicsWorkItem
        )
    }
}
