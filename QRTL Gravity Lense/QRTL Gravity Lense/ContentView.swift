/*
 Baryonic Mass Distribution — The pipeline begins with the baryonic mass of the globular cluster or galaxy. The mass is distributed throughout the modeled volume rather than treated as a single point.
 Mass Density — The baryonic mass is converted into a spatial mass-density field. Each location therefore has a local density representing how much baryonic matter is concentrated there.
 QRTL Source — The local baryonic mass density generates the QRTL source strength. Higher mass density produces a stronger QRTL source.
 Bolgarino Flow — The QRTL source produces the radial Bolgarino or QRTL flow through the surrounding space. The flow carries the QRTL influence outward from the dense regions.
 QRTL Flux — The Bolgarino flow is converted into a local QRTL flux. This describes the amount and direction of QRTL flow passing through each region.
 QRTL Current — The QRTL flux generates the QRTL current. Current is therefore no longer an independent electromagnetic input; it is a downstream consequence of the QRTL source and Bolgarino flow.
 QRTL Current Density — The current is distributed spatially through the modeled volume, producing a local current density with both magnitude and direction.
 QRTL Magnetic Field — The QRTL current generates the associated electromagnetic or magnetic field. The field direction and strength are determined by the calculated current distribution rather than by an arbitrarily assigned magnetic direction.
 Electromagnetic Energy Density — The magnetic field is converted into electromagnetic energy density. Regions containing stronger QRTL-generated magnetic fields therefore contain greater electromagnetic energy.
 QRTL Energy Density — The QRTL flow also produces its corresponding QRTL energy density. This represents the energy associated with the QRTL field itself.
 Combined Effective Energy — The QRTL energy and QRTL-generated electromagnetic energy are combined into an effective energy distribution.
 Effective Gravitational Source — The combined energy distribution contributes to the effective gravitational source used by the lensing calculation.
 QRTL Gravitational Potential — The effective gravitational source produces the QRTL gravitational potential throughout the lensing volume.
 Gravitational Optical Index — The QRTL gravitational potential is converted into the gravitational contribution to the effective optical index experienced by photons.
 Electromagnetic Optical Contribution — The QRTL-generated electromagnetic field contributes its own optical effect to photon propagation.
 Total Optical Index — The gravitational and electromagnetic contributions are combined into one total optical index. The photon therefore responds to the combined QRTL gravitational and electromagnetic environment rather than to two independent bending calculations.
 Photon Enters the QRTL Field — A photon is launched from the source galaxy toward the destination observation plane with an initial position and direction.
 Local Field Sampling — At every photon step, the code samples the QRTL field at the photon's current position.
 Local Optical Index — The total optical index at the photon's position is determined from the local gravitational and electromagnetic contributions.
 Optical-Index Gradient — The spatial change of the total optical index around the photon is calculated.
 Transverse Gradient — The portion of the optical-index gradient perpendicular to the photon's direction is isolated. This is the portion responsible for changing the photon's trajectory.
 Photon Direction Change — The transverse influence changes the photon's direction by a small amount.
 Photon Position Advance — The photon moves forward using its newly calculated direction.
 Stepwise Field Interaction — Steps 18 through 23 are repeated continuously as the photon travels through the QRTL field. The photon therefore accumulates many small changes in direction instead of receiving one artificial bending event.
 Curved Photon Trajectory — The accumulated direction changes create the complete curved photon path through the globular-cluster field.
 Dense-Center Influence — When the photon passes closer to the denser central portion of the cluster, it encounters stronger QRTL source strength, stronger flow, stronger current, stronger electromagnetic field, and consequently a stronger change in its trajectory.
 Deflection Measurement — Once the photon reaches the destination region, the difference between its original direction and final direction is measured.
 QRTL Deflection Angle — The measured trajectory change becomes the predicted QRTL lensing deflection.
 GR Baseline — A separate general-relativity calculation determines the corresponding gravitational deflection expected from the same baryonic mass distribution.
 QRTL–GR Comparison — The QRTL prediction is compared with the GR prediction.
 Observation Comparison — The predicted QRTL deflection can then be compared with an observed gravitational-lensing deflection.
 Photon Collection — Many photons are traced from different portions of the source galaxy through the QRTL field.
 Trajectory Distribution — Their final positions are collected at the destination observation plane.
 Projection Mapping — The final photon positions are mapped onto the observation plane.
 Surface Brightness Formation — Photons arriving at similar locations accumulate, producing regions of higher projected brightness.
 Lensing Distortion — The original geometry of the source galaxy is distorted according to the accumulated photon deflections.
 Multiple Image Formation — If the QRTL field produces the appropriate spatial mapping, photons originating from different portions or directions of the source can arrive at separated regions of the observation plane.
 Projected Galaxy Structures — Those concentrated photon-arrival regions appear as projected galaxy-like structures on the observation plane.
 Spline Construction — The calculated photon positions are then passed to the visualization system to construct smooth representations of the trajectories.
 Catmull-Rom Photon Paths — The stored photon positions are interpolated into smooth Catmull-Rom spline paths so the rendered trajectories visually follow the calculated photon motion.
 Photon-Path Rendering — The spline paths are rendered as visible tubes or curves between the source region and the destination observation plane.
 Final Projection — The observation plane displays the accumulated result of the photon trajectories.
 QRTL Prediction — The final prediction is therefore not simply that mass bends light. It is that baryonic mass creates a QRTL source, the QRTL source produces Bolgarino flow, the flow produces current, the current produces an electromagnetic field, the resulting QRTL and electromagnetic energies modify the effective optical environment, and photons propagating through that environment acquire measurable deflections.
 Observable Result — The ultimate observable is the spatial distribution of photons on the projection plane and the resulting lensing pattern.
 Theory Test — The resulting QRTL lensing pattern and measured deflection can finally be compared against GR and astronomical observations.

 In one continuous sequence:

 Baryonic mass → mass density → QRTL source → Bolgarino flow → QRTL flux → QRTL current → current density → QRTL magnetic field → electromagnetic energy → QRTL energy → effective energy → effective gravitational source → QRTL potential → gravitational optical index → electromagnetic optical contribution → total optical index → photon propagation → optical-index gradient → transverse field influence → direction change → curved photon path → deflection → photon collection → projection plane → lensing pattern → comparison with GR and observation.
 
 
 The QRTL gravitational lensing pipeline begins with a single source galaxy positioned behind the globular cluster. The source galaxy represents the original astronomical object whose light is being observed. Thousands of photons are distributed across the source galaxy, with each photon beginning at a slightly different position. The photons initially travel toward the globular cluster, so the collection of photons carries the spatial structure of the original galaxy toward the lensing region.

 The globular cluster provides the central lensing environment. Its baryonic mass is distributed throughout the volume of the cluster, creating a density distribution that is strongest toward the dense central region and progressively weaker toward the outside. Within the QRTL model, this baryonic density establishes the QRTL source field. The source field produces the proposed QRTL or Bolgarino flow throughout the surrounding volume. The QRTL flow represents the spatially varying field through which the photons must travel. The stronger portions of the field are associated with the denser and more influential regions of the cluster.

 The QRTL flow is then associated with a QRTL energy distribution. That energy contributes to the effective gravitational environment surrounding and filling the globular cluster. The resulting gravitational influence is not treated as a single force applied to the photon at one particular point. Instead, the photon encounters a continuously changing gravitational environment as it moves through space. This creates the spatial variation that allows the photon trajectory to bend progressively rather than simply receiving one predetermined deflection angle.

 The QRTL model also contains an electromagnetic branch. The local QRTL environment produces an electromagnetic influence that varies throughout the cluster. Therefore, a photon traveling through the outer portion of the cluster experiences one electromagnetic environment, while a photon traveling closer to the dense center encounters another. The electromagnetic influence contributes an additional component to the photon's local directional change. In the current implementation, the electromagnetic influence is sampled at the photon's actual position, so the electromagnetic contribution changes as the photon moves through the lens.

 The gravitational and electromagnetic influences are combined into the total optical environment experienced by the photon. The photon therefore does not travel through empty space with one fixed propagation condition. At every location, the QRTL gravitational contribution and electromagnetic contribution determine the local optical index. As the photon moves from one location to another, that index changes. The change in the index creates a gradient, and the portion of that gradient that is transverse to the photon's current direction produces the local bending of the trajectory.

 The photon is therefore bent incrementally rather than being rotated by a single large amount. The system evaluates the local field, determines the local directional influence, changes the photon's direction, advances the photon a small distance, and then repeats the calculation. The new position becomes the starting point for the next calculation. This creates a continuous sequence of small directional changes that produces the curved photon path. The implementation records these successive positions as the photon's path.

 This stepwise process is particularly important near the dense center of the globular cluster. Photons that pass close to the center encounter stronger spatial changes in the QRTL and electromagnetic fields and therefore experience greater cumulative bending. Photons that pass farther from the center encounter weaker field changes and experience less bending. Consequently, photons that began close together in the source galaxy can finish their journey in significantly different locations after passing through the lens.

 An analogy is a broad river flowing toward a large island. Before reaching the island, the water forms one continuous flow. When it encounters the island, different portions of the water are redirected around different sides of the island. Water passing close to the island is redirected more strongly, while water farther away is affected less. The individual water paths therefore separate and curve around the obstacle. Far downstream, the original single stream can appear as multiple concentrated streams even though all of the water originated from the same source. In this analogy, the source galaxy is the original river, the QRTL and electromagnetic fields are the island and its influence on the flow, the photons are the individual streams of water, and the projection plane is the downstream region where the redirected flow becomes visible.

 The analogy becomes even more useful because the QRTL lens is not represented as a simple solid object with one uniform influence. It is a three-dimensional field that fills the lensing volume. Every photon therefore follows its own route through that field. A photon passing above the center experiences one sequence of field conditions. A photon passing below the center experiences another. A photon passing directly through a dense central region experiences a much stronger sequence of influences. The resulting photon paths can therefore spread, converge, and curve in different ways as they travel through the cluster.

 When the photons emerge from the opposite side of the globular cluster, they have no longer retained their original straight-line spatial arrangement. The source galaxy's original photon distribution has been transformed by the accumulated bending. Each photon now carries a new position and a new direction determined by everything it encountered along its path. The photon trajectories therefore contain the information needed to reconstruct the lensed appearance of the original galaxy.

 The projection plane receives these photons and records where each trajectory intersects the plane. Each intersection represents the apparent location of a photon from the original source after its journey through the QRTL lens. The system accumulates these intersections rather than simply drawing a second galaxy by hand. The uploaded pipeline converts successful photon trajectories into projection hits containing the intersection point, projected coordinates, original source coordinates, final direction, traveled distance, and field diagnostics.

 The apparent second galaxy therefore emerges from the redistribution of the photons. A particular region of the source galaxy may send photons that are redirected toward one region of the projection plane. Another region of the same source galaxy may send photons toward another region. If the lensing field causes the photon distribution to separate into two dominant concentrations, the projection plane will contain two galaxy-like concentrations even though there was only one physical source galaxy.

 This is the central idea behind the two-galaxy projection. The program does not need to create a second physical galaxy. It creates a single source galaxy, traces its photons through the QRTL and electromagnetic fields, and allows the resulting photon trajectories to determine where the light appears on the projection plane. The second apparent galaxy is therefore an emergent consequence of the photon trajectories and their final intersection distribution.

 The visual photon splines are especially useful because they make this transformation visible. They should begin at the source galaxy, travel toward the globular cluster, progressively curve as the QRTL and electromagnetic influences change, pass around or through the dense central region, and continue toward the projection plane. When enough paths are rendered together, the viewer can visually follow the transformation from one source galaxy into the separated photon distributions that eventually form the projected images. The current pipeline explicitly renders the traced photon paths after the projection calculation.

 The final projection is therefore best understood as a **photon-density transformation**. The source galaxy establishes the original photon distribution. The QRTL gravitational field and electromagnetic field transform the trajectories of those photons. The transformed trajectories establish a new distribution of photon arrival positions. The projection plane converts that arrival distribution into an observable image. If the transformed distribution contains two dominant concentrations, the result is a two-galaxy projection originating from one source galaxy.

 In complete words, the pipeline is: **one source galaxy emits many photons, the photons enter the spatially varying QRTL lensing environment, the baryonic density establishes the QRTL source, the QRTL source establishes the proposed QRTL flow, the QRTL flow establishes the QRTL energy and gravitational influence, the QRTL environment also produces the modeled electromagnetic influence, the gravitational and electromagnetic influences combine to determine the local optical environment, the changing optical environment bends each photon incrementally, photons passing through different regions of the globular cluster experience different amounts of cumulative bending, the initially unified photon distribution becomes spatially redistributed, the curved photon trajectories reach the projection plane at different locations, those locations are accumulated, and the resulting concentrations of photon arrivals form the apparent projected images of the original source galaxy. When the field produces two dominant concentrations of arrivals, the single source galaxy appears as two galaxies on the projection plane.**

 One important qualification is that the uploaded material treats the photon-tracing and projection mechanism as the implemented computational part, while the fundamental QRTL derivations connecting the QRTL source to its flow, the flow to QRTL energy density, and the flow to the electromagnetic field are explicitly identified as relationships that still need to be derived from the QRTL assumptions.

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

        alphaQ =
            0

        etaQ =
            0

        gammaQ =
            1

        electromagneticCoupling =
            0

        photonEMCoupling =
            0

        chiQ =
            1

        interactionRate =
            0

        result =
            nil

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
            empty:
                true
        )

        scene.addBottomPlaceholder()
    }

    private func runFullPipeline() {

        // =========================================================
        // PREVENT SIMULTANEOUS PIPELINES
        // =========================================================

        guard !isRunning else {
            return
        }

        isRunning =
            true

        result =
            nil

        statusMessage =
            "Starting QRTL lensing pipeline…"


        // =========================================================
        // CAPTURE ALL SWIFTUI VALUES BEFORE BACKGROUND THREAD
        // =========================================================

        let mass =
            massSolar *
            PhysicalConstants.solarMass

        let showPaths =
            showPhotonPaths

        let sourceGalaxyRadius:
            Float = 0.75

        let photonCount =
            1200

        let clusterSceneRadius:
            Double = 3.0

        // ---------------------------------------------------------
        // Capture the projection plane position once.
        // ---------------------------------------------------------

        let frontX =
            scene.frontPlaneX


        // =========================================================
        // BUILD QRTL PARAMETERS
        // =========================================================

        var params =
            QRTLParameters()

        params.alphaQ =
            max(
                alphaQ,
                1e-2
            )

        params.etaQ =
            etaQ

        params.gammaQ =
            gammaQ

        params.chiQ =
            chiQ

        params.interactionRate =
            interactionRate

        params.electromagneticCoupling =
            max(
                electromagneticCoupling,
                1e-2
            )

        params.photonEMCoupling =
            max(
                photonEMCoupling,
                1e-2
            )


        // =========================================================
        // CLEAR OLD DYNAMIC SCENE CONTENT
        // =========================================================

        scene.clearDynamic()


        // =========================================================
        // BACKGROUND COMPUTATION
        // =========================================================

        DispatchQueue.global(
            qos: .userInitiated
        ).async {

            autoreleasepool {

                // =================================================
                // STAGE 1
                // =================================================

                DispatchQueue.main.async {

                    self.statusMessage =
                        "Stage 1/4 — QRTL field (scene units)…"
                }


                // =================================================
                // MASS MODEL
                // =================================================

                let massModel =
                    GaussianMassModel(
                        totalMass:
                            mass,

                        characteristicRadius:
                            clusterSceneRadius
                    )


                // =================================================
                // QRTL FIELD
                // =================================================

                let field =
                    QRTLField(
                        massModel:
                            massModel,

                        parameters:
                            params
                    )


                // =================================================
                // QRTL EXPERIMENT / BASELINE
                // =================================================

                let experiment =
                    QRTLExperiment(
                        mass:
                            mass,

                        radius:
                            clusterSceneRadius,

                        parameters:
                            params
                    )


                let outcome =
                    experiment.run(
                        impactParameter:
                            0.5,

                        startDistance:
                            8.0,

                        endDistance:
                            8.0,

                        stepSize:
                            0.05
                    )


                // =================================================
                // STAGE 2
                // =================================================

                DispatchQueue.main.async {

                    self.statusMessage =
                        "Stage 2/4 — tracing photons…"
                }


                // =================================================
                // LENSING PARAMETERS
                // =================================================

                var lensingParameters =
                    LensingParameters()


                // -------------------------------------------------
                // Photon integration
                // -------------------------------------------------

                lensingParameters.stepSize =
                    0.04

                lensingParameters.maxSteps =
                    1500

                lensingParameters.deflectionStrength =
                    0.2


                // -------------------------------------------------
                // QRTL FIELD COUPLING
                // -------------------------------------------------

                lensingParameters.qrtlFieldCoupling =
                    5.0

                lensingParameters.electromagneticCoupling =
                    5.0


                // -------------------------------------------------
                // Magnetic diagnostics
                // -------------------------------------------------

                lensingParameters.magneticPhotonCoupling =
                    1.0

                lensingParameters.magneticBendingStrength =
                    1.0


                // -------------------------------------------------
                // PROJECTION PLANE
                // -------------------------------------------------

                lensingParameters.projectionDistance =
                    frontX

                lensingParameters.projectionPlaneHalfExtent =
                    6.0


                // =================================================
                // PROJECTION STORAGE
                // =================================================

                var hits:
                    [LensingProjectionHit] = []

                hits.reserveCapacity(
                    photonCount
                )


                // =================================================
                // PHOTON TRACE STORAGE
                // =================================================

                var traces:
                    [PhotonTraceResult] = []

                if showPaths {

                    traces.reserveCapacity(
                        photonCount
                    )
                }


                // =================================================
                // TRACE PHOTONS
                // =================================================

                for _ in 0..<photonCount {

                    // -------------------------------------------------
                    // SOURCE GALAXY DISTRIBUTION
                    // -------------------------------------------------

                    let theta =
                        Float.random(
                            in:
                                0...(2 * .pi)
                        )

                    let rf =
                        sqrt(
                            Float.random(
                                in:
                                    0...1
                            )
                        )

                    let r =
                        sourceGalaxyRadius *
                        rf

                    let sy =
                        r *
                        cos(theta)

                    let sz =
                        r *
                        sin(theta)


                    // -------------------------------------------------
                    // SOURCE POSITION
                    //
                    // X = photon propagation axis
                    // Y = vertical source coordinate
                    // Z = depth/source coordinate
                    // -------------------------------------------------

                    let origin =
                        SIMD3<Float>(
                            -6.5,
                            sy,
                            sz
                        )


                    // -------------------------------------------------
                    // INITIAL PHOTON DIRECTION
                    // -------------------------------------------------

                    let direction =
                        SIMD3<Float>(
                            1.0,
                            0.0,
                            0.0
                        )


                    // -------------------------------------------------
                    // TRACE
                    // -------------------------------------------------

                    let trace =
                        self.tracePhoton(
                            origin:
                                origin,

                            direction:
                                direction,

                            field:
                                field,

                            parameters:
                                lensingParameters
                        )


                    // -------------------------------------------------
                    // STORE TRACE ONLY WHEN REQUESTED
                    // -------------------------------------------------

                    if showPaths {

                        traces.append(
                            trace
                        )
                    }


                    // -------------------------------------------------
                    // IMPORTANT:
                    //
                    // ONLY photons that actually hit the projection
                    // plane may create projection hits.
                    // -------------------------------------------------

                    guard trace.hitProjection else {
                        continue
                    }


                    // -------------------------------------------------
                    // CREATE EXACTLY ONE HIT
                    // -------------------------------------------------

                    if let hit =
                        self.makeHit(
                            from:
                                trace,

                            sourceID:
                                0,

                            sourceCoordinates:
                                SIMD2(
                                    sy,
                                    sz
                                )
                        ) {

                        hits.append(
                            hit
                        )
                    }
                }


                // =================================================
                // STAGE 3
                // =================================================

                DispatchQueue.main.async {

                    self.statusMessage =
                        "Stage 3/4 — calculating projection…"
                }


                // =================================================
                // CALCULATE PROJECTION
                // =================================================

                let projection =
                    LensingProjectionResult.calculate(
                        from:
                            hits
                    )


                // =================================================
                // STAGE 4
                // =================================================

                DispatchQueue.main.async {

                    self.statusMessage =
                        "Stage 4/4 — rendering…"


                    // =================================================
                    // SOURCE GALAXY
                    // =================================================

                    self.scene.addSourceGalaxy(
                        radius:
                            Double(
                                sourceGalaxyRadius
                            ),

                        nStars:
                            220
                    )


                    // =================================================
                    // GLOBULAR CLUSTER
                    // =================================================

                    self.scene.addGlobularCluster(
                        radius:
                            clusterSceneRadius,

                        nStars:
                            2500
                    )


                    // =================================================
                    // FIELD HEATMAP
                    // =================================================

                    self.scene.updateBottomHeatmap(
                        field:
                            field
                    )


                    // =================================================
                    // APPLY PROJECTION
                    // =================================================

                    self.scene.applyProjection(
                        projection
                    )


                    // =================================================
                    // RENDER PHOTON PATHS
                    // =================================================

                    if showPaths {

                        for trace in traces {

                            guard trace.hitProjection else {
                                continue
                            }

                            self.scene.renderPhotonPath(
                                trace.path
                            )
                        }
                    }


                    // =================================================
                    // FINAL RESULT
                    // =================================================

                    self.result =
                        outcome

                    self.statusMessage =
                        "Done — \(projection.validHits.count) hits"

                    self.isRunning =
                        false
                }
            }
        }
    }
    
    private func makeHit(
        from trace: PhotonTraceResult,
        sourceID: Int,
        sourceCoordinates: SIMD2<Float>
    ) -> LensingProjectionHit? {

        guard trace.hitProjection,
              let point = trace.projectionPosition
        else {
            return nil
        }

        guard point.x.isFinite,
              point.y.isFinite,
              point.z.isFinite
        else {
            return nil
        }


        // =========================================================
        // PROJECTION PLANE IS X CONSTANT
        //
        // Photon travels along X.
        //
        // Therefore the image coordinates are:
        //
        // horizontal = Y
        // vertical   = Z
        // =========================================================

        let coordinates =
            SIMD2<Float>(
                point.y,
                point.z
            )


        guard coordinates.x.isFinite,
              coordinates.y.isFinite
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
 
    
    private func projectionPlaneIntersection(
        from: SIMD3<Float>,
        to: SIMD3<Float>,
        parameters: LensingParameters
    ) -> SIMD3<Float>? {

        // =========================================================
        // PROJECTION PLANE
        //
        // Plane is perpendicular to the X axis:
        //
        //     x = projectionDistance
        //
        // The photon segment is tested from `from` -> `to`.
        // =========================================================

        let projectionDistance =
            parameters.projectionDistance

        let halfExtent =
            parameters.projectionPlaneHalfExtent

        guard projectionDistance.isFinite,
              halfExtent.isFinite,
              halfExtent > 0.0
        else {
            return nil
        }

        // =========================================================
        // SEGMENT X VALUES
        // =========================================================

        let x0 = from.x
        let x1 = to.x

        guard x0.isFinite,
              x1.isFinite
        else {
            return nil
        }

        // =========================================================
        // DETERMINE WHETHER SEGMENT CROSSES X PLANE
        // =========================================================

        let dx =
            x1 - x0

        guard dx.isFinite,
              abs(dx) > 0.000001
        else {
            return nil
        }

        // =========================================================
        // INTERSECTION PARAMETER
        //
        // from + t(to - from)
        //
        // Solve:
        //
        // x = projectionDistance
        // =========================================================

        let t =
            (projectionDistance - x0) / dx

        guard t.isFinite,
              t >= 0.0,
              t <= 1.0
        else {
            return nil
        }

        // =========================================================
        // CALCULATE INTERSECTION
        // =========================================================

        let intersection =
            from +
            (to - from) * t

        guard intersection.x.isFinite,
              intersection.y.isFinite,
              intersection.z.isFinite
        else {
            return nil
        }

        // =========================================================
        // PROJECTION PLANE BOUNDS
        //
        // The plane is an X-oriented plane, so the visible
        // coordinates are Y and Z.
        // =========================================================

        guard abs(intersection.y) <= halfExtent,
              abs(intersection.z) <= halfExtent
        else {
            return nil
        }

        return intersection
    }
    
    func tracePhoton(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        field: QRTLField,
        parameters: LensingParameters
    ) -> PhotonTraceResult {

        // =========================================================
        // INITIALIZE PHOTON
        // =========================================================

        var position = origin

        var photonDirection =
            simd_normalize(direction)

        guard photonDirection.x.isFinite,
              photonDirection.y.isFinite,
              photonDirection.z.isFinite
        else {
            return PhotonTraceResult(
                origin: origin,
                direction: direction,
                positions: [origin],
                finalPosition: origin,
                finalDirection: .zero,
                hitProjection: false,
                projectionPosition: nil,
                totalDeflection: 0.0,
                maximumQRTLInfluence: 0.0,
                maximumMagneticField: 0.0,
                maximumMagneticPhotonInfluence: 0.0,
                traveledDistance: 0.0,
                stepCount: 0,
                terminated: true
            )
        }

        // =========================================================
        // PATH STORAGE
        // =========================================================

        var positions: [SIMD3<Float>] = []

        positions.reserveCapacity(
            parameters.maximumPhotonSteps + 1
        )

        positions.append(position)

        // =========================================================
        // DIAGNOSTICS
        // =========================================================

        var totalDeflection: Float = 0.0

        var maximumQRTLInfluence: Float = 0.0

        var maximumMagneticField: Float = 0.0

        var maximumMagneticPhotonInfluence: Float = 0.0

        var traveledDistance: Float = 0.0

        // =========================================================
        // PROJECTION STATE
        // =========================================================

        var hitProjection = false

        var projectionPosition:
            SIMD3<Float>? = nil

        var terminated = false

        // =========================================================
        // PHOTON PROPAGATION
        // =========================================================

        for _ in 0..<parameters.maximumPhotonSteps {

            // -----------------------------------------------------
            // CURRENT STATE
            // -----------------------------------------------------

            let previousPosition =
                position

            let previousDirection =
                photonDirection

            // =====================================================
            // SAMPLE COMPLETE QRTL FIELD
            // =====================================================

            let sample =
                field.sample(
                    at: position
                )

            let totalIndex =
                sample.totalIndex

            guard totalIndex.isFinite,
                  totalIndex > 0.000001
            else {
                terminated = true
                break
            }

            // =====================================================
            // QRTL INFLUENCE
            // =====================================================

            let qrtlInfluenceVector =
                field.influence(
                    at: position
                )

            let qrtlInfluence =
                simd_length(
                    qrtlInfluenceVector
                )

            if qrtlInfluence.isFinite {

                maximumQRTLInfluence =
                    max(
                        maximumQRTLInfluence,
                        qrtlInfluence
                    )
            }

            // =====================================================
            // ELECTROMAGNETIC INFLUENCE
            // =====================================================

            let magneticInfluence =
                field.electromagneticInfluence(
                    at: position
                )

            let magneticMagnitude =
                simd_length(
                    magneticInfluence
                )

            if magneticMagnitude.isFinite {

                maximumMagneticField =
                    max(
                        maximumMagneticField,
                        magneticMagnitude
                    )

                maximumMagneticPhotonInfluence =
                    max(
                        maximumMagneticPhotonInfluence,
                        magneticMagnitude
                    )
            }

            // =====================================================
            // TOTAL INDEX GRADIENT
            // =====================================================

            let gradient =
                field.indexGradient(
                    at: position
                )

            guard gradient.x.isFinite,
                  gradient.y.isFinite,
                  gradient.z.isFinite
            else {
                terminated = true
                break
            }

            // =====================================================
            // TRANSVERSE GRADIENT
            //
            // Only the component perpendicular to the photon
            // direction changes the trajectory.
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
            // OPTICAL INDEX BENDING
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
                terminated = true
                break
            }

            // =====================================================
            // DEFLECTION STRENGTH
            // =====================================================

            let directionChange =
                indexBending *
                parameters.deflectionStrength

            // =====================================================
            // PHOTON STEP SIZE
            // =====================================================

            let step =
                parameters.photonStepSize

            guard step.isFinite,
                  step > 0.0
            else {
                terminated = true
                break
            }

            // =====================================================
            // UPDATE PHOTON DIRECTION
            // =====================================================

            var nextDirection =
                photonDirection +
                directionChange *
                step

            guard nextDirection.x.isFinite,
                  nextDirection.y.isFinite,
                  nextDirection.z.isFinite
            else {
                terminated = true
                break
            }

            let directionLength =
                simd_length(
                    nextDirection
                )

            guard directionLength.isFinite,
                  directionLength > 0.000001
            else {
                terminated = true
                break
            }

            nextDirection =
                nextDirection /
                directionLength

            // =====================================================
            // CALCULATE NEXT POSITION
            // =====================================================

            let nextPosition =
                position +
                nextDirection *
                step

            guard nextPosition.x.isFinite,
                  nextPosition.y.isFinite,
                  nextPosition.z.isFinite
            else {
                terminated = true
                break
            }

            // =====================================================
            // PROJECTION PLANE INTERSECTION
            //
            // The photon may cross the projection plane between
            // previousPosition and nextPosition.
            // =====================================================

            if let intersection =
                projectionPlaneIntersection(
                    from: previousPosition,
                    to: nextPosition,
                    parameters: parameters
                ) {

                // -------------------------------------------------
                // ADD ONLY THE ACTUAL DISTANCE TO THE PLANE
                // -------------------------------------------------

                let segment =
                    intersection -
                    previousPosition

                let intersectionDistance =
                    simd_length(
                        segment
                    )

                if intersectionDistance.isFinite {

                    traveledDistance +=
                        intersectionDistance
                }

                // -------------------------------------------------
                // FINAL PHOTON STATE
                // -------------------------------------------------

                position =
                    intersection

                photonDirection =
                    nextDirection

                // -------------------------------------------------
                // RECORD FINAL INTERSECTION
                // -------------------------------------------------

                positions.append(
                    intersection
                )

                projectionPosition =
                    intersection

                hitProjection =
                    true

                terminated =
                    true

                break
            }

            // =====================================================
            // UPDATE PHOTON STATE
            // =====================================================

            photonDirection =
                nextDirection

            position =
                nextPosition

            traveledDistance +=
                step

            // =====================================================
            // RECORD PHOTON PATH
            // =====================================================

            positions.append(
                position
            )

            // =====================================================
            // ACCUMULATE DEFLECTION ANGLE
            // =====================================================

            let dotProduct =
                simd_dot(
                    previousDirection,
                    photonDirection
                )

            let clampedDot =
                max(
                    -1.0,
                    min(
                        1.0,
                        dotProduct
                    )
                )

            let angle =
                acos(
                    clampedDot
                )

            if angle.isFinite {

                totalDeflection +=
                    angle
            }

            // =====================================================
            // STOP OUTSIDE LENSING VOLUME
            // =====================================================

            let distanceFromOrigin =
                simd_length(
                    position
                )

            if distanceFromOrigin.isFinite,
               distanceFromOrigin >
                    parameters.maximumPropagationRadius {

                terminated =
                    true

                break
            }
        }

        // =========================================================
        // RETURN THE ACTUAL CALCULATED PHOTON TRACE
        // =========================================================

        return PhotonTraceResult(
            origin:
                origin,

            direction:
                direction,

            positions:
                positions,

            finalPosition:
                position,

            finalDirection:
                photonDirection,

            hitProjection:
                hitProjection,

            projectionPosition:
                projectionPosition,

            totalDeflection:
                totalDeflection,

            maximumQRTLInfluence:
                maximumQRTLInfluence,

            maximumMagneticField:
                maximumMagneticField,

            maximumMagneticPhotonInfluence:
                maximumMagneticPhotonInfluence,

            traveledDistance:
                traveledDistance,

            stepCount:
                max(
                    positions.count - 1,
                    0
                ),

            terminated:
                terminated
        )
    }
    
}

