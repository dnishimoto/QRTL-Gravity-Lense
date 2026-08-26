//
//  DataStructures.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/18/26.
//

import Foundation
import simd
import SceneKit
import SwiftUI
struct MetersPerSceneUnit {
    /// The number of physical meters per SceneKit scene unit.
    ///
    /// THIS IS THE SINGLE AUTHORITATIVE SCENE↔PHYSICAL CONVERSION.
    /// Every place in the project that needs to turn a SceneKit
    /// coordinate into a physical (meters) coordinate — or back —
    /// should go through this struct rather than computing its own
    /// ratio inline. That was the actual bug behind the
    /// "6.2 m radius" debug output: SceneKit coordinates were being
    /// treated as meters directly in some code paths, with no
    /// conversion applied at all.
    ///
    /// `value` is NOT a fixed guess. It is derived once, at scene
    /// build time, from the two quantities that actually define the
    /// mapping:
    ///
    ///     value = physical cluster radius (meters)
    ///             / surface grid extent (scene units)
    ///
    /// Call `configure(clusterRadiusMeters:extentSceneUnits:)` as
    /// soon as both of those are known (QRTLGravitySurfaceEntity
    /// does this in its initializer) before reading `value` or
    /// calling the conversion helpers below.
    private(set) static var value: Double = 1.0

    private(set) static var isConfigured: Bool = false

    /// Establishes the single authoritative scene↔physical mapping
    /// from the actual runtime cluster radius and the actual scene
    /// extent the surface is drawn at — not a hardcoded placeholder.
    static func configure(
        clusterRadiusMeters: Double,
        extentSceneUnits: Double
    ) {
        guard clusterRadiusMeters.isFinite,
              clusterRadiusMeters > 0.0,
              extentSceneUnits.isFinite,
              extentSceneUnits > 0.0
        else {
            return
        }

        value = clusterRadiusMeters / extentSceneUnits
        isConfigured = true
    }

    /// Convert SceneKit units (Float) to physical meters (Double).
    static func sceneUnitsToMeters(_ sceneUnits: Float) -> Double {
        return Double(sceneUnits) * value
    }

    /// Convert physical meters (Double) to SceneKit units (Float).
    static func metersToSceneUnits(_ meters: Double) -> Float {
        return Float(meters / value)
    }
}
struct QRTLGravitySurfaceSample {
    let positionMeters: SIMD3<Float>
    let massDensity: Double
    let normalizedDensity: Double
    let qrtlInfluence: Double
    let gravitationalPotential: Double
    let normalizedPotential: Double
}
struct PhotonSimulationProgress {

    /// Total number of photons emitted during the simulation.
    var total: Int

    /// Number of photons that have completed propagation.
    var completed: Int

    /// Number of photons currently propagating through the QRTL field.
    var active: Int

    /// Number of photons that reached the projection plane.
    var projectionHits: Int

    init(
        total: Int = 0,
        completed: Int = 0,
        active: Int = 0,
        projectionHits: Int = 0
    ) {
        self.total = total
        self.completed = completed
        self.active = active
        self.projectionHits = projectionHits
    }
}

// ============================================================
// CONTINUOUS PHOTON
// ============================================================

// ============================================================
// CONTINUOUS PHOTON
// ============================================================
//
// Represents one photon continuously emitted from the source
// galaxy and propagated through the QRTL field toward the
// projection plane.
//
// This is the runtime state for the continuous photon emitter.
// ============================================================

struct ContinuousPhoton {

    // ========================================================
    // PROPAGATION STATE
    // ========================================================

    /// Current physical position of the photon.
    var position: SIMD3<Float>

    /// Current normalized propagation direction.
    var direction: SIMD3<Float>

    /// Total physical distance traveled by the photon.
    var traveledDistance: Float

    /// Number of integration steps completed.
    var stepCount: Int

    /// Complete photon trajectory.
    var path: [SIMD3<Float>]

    // ========================================================
    // QRTL INTERACTION
    // ========================================================

    /// Maximum QRTL field influence encountered by this photon.
    var maximumQRTLInfluence: Float

    // ========================================================
    // LIFETIME / PROJECTION STATE
    // ========================================================

    /// True while the photon is still propagating.
    var alive: Bool

    /// True when the photon reaches the projection plane.
    var hitProjectionPlane: Bool

    /// Physical position where the photon struck the
    /// projection plane.
    var projectionPosition: SIMD3<Float>?

    // ========================================================
    // SCENEKIT REPRESENTATION
    // ========================================================

    /// SceneKit node used to visualize this photon.
    ///
    /// The node is optional because photons can exist in the
    /// simulation before their visual representation is created.
    var node: SCNNode?
}
// ============================================================
// ADVANCE CONTINUOUS PHOTON
// ============================================================

private func advanceContinuousPhoton(
    photon: inout ContinuousPhoton,
    field: QRTLField,
    parameters: LensingParameters,
    deltaTime: Float
) -> Bool {

    guard photon.alive else {
        return false
    }

    let stepDistance =
        parameters.photonStepSize

    let position =
        photon.position

    let direction =
        simd_normalize(photon.direction)

    // --------------------------------------------------------
    // Maximum propagation distance
    // --------------------------------------------------------

    if photon.traveledDistance >=
        parameters.maximumPropagationRadius {

        photon.alive = false
        return false
    }

    // --------------------------------------------------------
    // QRTL lensing acceleration
    // --------------------------------------------------------

    let acceleration =
        field.qrtlLensingAcceleration(
            at: position,
            direction: direction
        )

    let influence =
        simd_length(acceleration)

    photon.maximumQRTLInfluence =
        max(
            photon.maximumQRTLInfluence,
            influence
        )

    // --------------------------------------------------------
    // QRTL bending
    // --------------------------------------------------------

    var bend =
        acceleration *
        parameters.qrtlLensingStrength

    let bendMagnitude =
        simd_length(bend)

    if bendMagnitude >
        parameters.maximumPhotonBend {

        if bendMagnitude > 0 {

            bend =
                simd_normalize(bend) *
                parameters.maximumPhotonBend
        }
    }

    // --------------------------------------------------------
    // Direction update
    // --------------------------------------------------------

    var newDirection =
        direction +
        bend * deltaTime

    let directionMagnitude =
        simd_length(newDirection)

    if directionMagnitude > 0 {

        newDirection =
            simd_normalize(newDirection)

    } else {

        newDirection =
            direction
    }

    // --------------------------------------------------------
    // Position update
    // --------------------------------------------------------

    let newPosition =
        position +
        newDirection *
        stepDistance

    // --------------------------------------------------------
    // Store path
    // --------------------------------------------------------

    photon.path.append(
        newPosition
    )

    // --------------------------------------------------------
    // Projection-plane crossing
    // --------------------------------------------------------

    let crossedProjectionPlane =
        position.x <
        parameters.targetPlaneX &&
        newPosition.x >=
        parameters.targetPlaneX

    // --------------------------------------------------------
    // Update photon
    // --------------------------------------------------------

    photon.position =
        newPosition

    photon.direction =
        newDirection

    photon.traveledDistance +=
        stepDistance

    // --------------------------------------------------------
    // Photon reached projection plane
    // --------------------------------------------------------

    if crossedProjectionPlane {

        photon.alive = false

        return false
    }

    // --------------------------------------------------------
    // Maximum propagation distance
    // --------------------------------------------------------

    if photon.traveledDistance >=
        parameters.maximumPropagationRadius {

        photon.alive = false

        return false
    }

    return true
}

struct QRTLUnifiedSpacetimeSample {

    let position: SIMD3<Float>

    let potential: Float

    let metric: QRTLSpacetimeMetric

    let inverseMetric: QRTLSpacetimeMetric

    let metricDeformation: Float
}

struct QRTLSpacetimeMetric {

    // ============================================================
    // COORDINATE INDEX
    //
    // 0 = time
    // 1 = x
    // 2 = y
    // 3 = z
    // ============================================================

    var g00: Float
    var g11: Float
    var g22: Float
    var g33: Float

    // ============================================================
    // MINKOWSKI / FLAT SPACETIME
    //
    // No gravitational potential:
    //
    // ds² =
    // -c²dt² + dx² + dy² + dz²
    //
    // Therefore:
    //
    // g00 = -1
    // g11 =  1
    // g22 =  1
    // g33 =  1
    // ============================================================

    static let minkowski =
        QRTLSpacetimeMetric(

            g00:
                -1.0,

            g11:
                1.0,

            g22:
                1.0,

            g33:
                1.0
        )
}

var gravitySurfaceDiagnostics =
    GravitySurfaceDiagnostics()

struct PhotonTraceProgress {

    let total: Int
    let completed: Int
    let pathPoints: Int
    let maximumQRTLInfluence: Float
}
struct PhotonPipelineVerification {

    let photonsCreated: Int
    let photonsTraced: Int
    let photonsReachedProjectionPlane: Int
    let photonsWithCurvedPaths: Int

    let totalPathPoints: Int
    let maximumDeflection: Float
    let maximumQRTLInfluence: Float

    var creationVerified: Bool {
        photonsCreated > 0
    }

    var tracingVerified: Bool {
        photonsTraced > 0
    }

    var curvatureVerified: Bool {
        photonsWithCurvedPaths > 0 &&
        maximumDeflection > 0
    }

    var projectionVerified: Bool {
        photonsReachedProjectionPlane > 0
    }

    var complete: Bool {
        creationVerified &&
        tracingVerified &&
        curvatureVerified &&
        projectionVerified
    }
}
// ============================================================
// PHOTON TRACE BATCH
//
// Contains the complete photon-tracing oLensingProjectionHitutput for one
// source galaxy.
//
// Physics:
//     Source Galaxy
//          ↓
//     Photon origins
//          ↓
//     tracePhoton()
//          ↓
//     Photon paths
//          ↓
//     Projection hits
//          ↓
//     LensingProjectionResult
// ============================================================

struct PhotonTraceBatch {

    // =========================================================
    // COMPLETE TRACE RESULTS
    // =========================================================

    let traces:
        [PhotonTraceResult]

    // =========================================================
    // PHOTON PATHS
    // =========================================================

    let paths:
        [[SIMD3<Float>]]

    // =========================================================
    // SUCCESSFUL PROJECTION HITS
    // =========================================================

    let hits:
        [LensingProjectionHit]

    // =========================================================
    // CONVENIENCE COUNTS
    // =========================================================

    var photonCount:
        Int {
        traces.count
    }

    var pathCount:
        Int {
        paths.count
    }

    var hitCount:
        Int {
        hits.count
    }

    var hasHits:
        Bool {
        !hits.isEmpty
    }
}




struct SourceGalaxyStar:
    Identifiable {

    // ========================================================
    // UNIQUE STAR ID
    // ========================================================

    let id:
        Int

    // ========================================================
    // 3D POSITION
    // ========================================================

    let position:
        SIMD3<Float>

    // ========================================================
    // VISUAL BRIGHTNESS
    // ========================================================

    let brightness:
        Float

    // ========================================================
    // INITIALIZER
    // ========================================================

    init(
        id:
            Int,

        position:
            SIMD3<Float>,

        brightness:
            Float =
            1.0
    ) {

        self.id =
            id

        self.position =
            position

        self.brightness =
            brightness
    }
}

// ============================================================
// CELLULAR-AUTOMATA DENSITY SOURCE
// ============================================================
//
// density()
//      = dimensionless cellular-automata spatial distribution
//
// integratedDensity
//      = integral of CA density over physical volume
//
// fieldRadiusMeters
//      = physical radius represented by the cluster
//
// The physical normalization is:
//
// rhoPhysical(r)
//      = rhoCA(r) * Mcluster / integratedDensity
//
// Therefore:
//
// ∫ rhoPhysical dV = Mcluster
//
// ============================================================

import Foundation
import simd
struct GlobularClusterStar {
    let position: SIMD3<Float>
    let massKg: Double
}
struct SpatialGravitySample {

    let position: SIMD3<Float>

    let energyDensity: Float

    let effectiveMassDensity: Float

    let potential: Float
}

struct RadialGravitySample {

    let radius: Double

    /// QRTL energy density at this radius.
    let energyDensity: Double

    /// Effective mass density derived from QRTL energy density.
    let effectiveMassDensity: Double

    /// Enclosed effective mass at this radius.
    let enclosedMass: Double

    /// QRTL gravitational potential at this radius.
    let potential: Double
}
struct ControlsSheet:
    View {

    @Binding var massSolar:
        Double

    @Binding var radiusSolar:
        Double

    @Binding var alphaQ:
        Double

    @Binding var etaQ:
        Double

    @Binding var gammaQ:
        Double

    @Binding var electromagneticCoupling:
        Double

    @Binding var photonEMCoupling:
        Double

    @Binding var chiQ:
        Double

    @Binding var interactionRate:
        Double

    @Binding var result:
        QRTLExperimentResult?

    @Binding var isRunning:
        Bool

    @Binding var statusMessage:
        String

    var onRun:
        () -> Void

    var onReset:
        () -> Void

    var body:
        some View {

        NavigationStack {

            Form {

                Section(
                    "Lens Mass"
                ) {

                    HStack {

                        Text(
                            "Mass (M☉)"
                        )

                        Spacer()

                        TextField(
                            "",
                            value:
                                $massSolar,

                            format:
                                .number
                        )
                        .keyboardType(
                            .decimalPad
                        )
                        .multilineTextAlignment(
                            .trailing
                        )
                        .frame(
                            width:
                                120
                        )
                    }

                    HStack {

                        Text(
                            "Radius (R☉)"
                        )

                        Spacer()

                        TextField(
                            "",
                            value:
                                $radiusSolar,

                            format:
                                .number
                        )
                        .keyboardType(
                            .decimalPad
                        )
                        .multilineTextAlignment(
                            .trailing
                        )
                        .frame(
                            width:
                                120
                        )
                    }
                }

                Section(
                    "QRTL / Bolgarino"
                ) {

                    slider(
                        "α_Q",
                        value:
                            $alphaQ,

                        range:
                            0...3e-5
                    )

                    slider(
                        "η_Q",
                        value:
                            $etaQ,

                        range:
                            0...20
                    )

                    slider(
                        "γ_Q",
                        value:
                            $gammaQ,

                        range:
                            0.5...1.5
                    )

                    slider(
                        "χ_Q",
                        value:
                            $chiQ,

                        range:
                            0.1...10
                    )

                    slider(
                        "Γ_Q",
                        value:
                            $interactionRate,

                        range:
                            0...3e-6
                    )
                }

                Section(
                    "EM Coupling"
                ) {

                    slider(
                        "g_QE",
                        value:
                            $electromagneticCoupling,

                        range:
                            0...1e-9
                    )

                    slider(
                        "κ_EM",
                        value:
                            $photonEMCoupling,

                        range:
                            0...1e-19
                    )
                }

                Section {

                    Button(
                        action:
                            onRun
                    ) {

                        Label(
                            isRunning
                            ? "Running…"
                            : "Run Full Projection Pipeline",

                            systemImage:
                                "play.fill"
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                    }
                    .disabled(
                        isRunning
                    )
                    .buttonStyle(
                        .borderedProminent
                    )

                    Button(
                        "Reset to pure GR",
                        action:
                            onReset
                    )
                    .disabled(
                        isRunning
                    )
                }

                if let result {

                    Section(
                        "Deflection"
                    ) {

                        Text(
                            "QRTL: " +
                            String(
                                format:
                                    "%.4e",
                                result.qrtlDeflectionArcseconds
                            ) +
                            " arcsec"
                        )

                        Text(
                            "GR:   " +
                            String(
                                format:
                                    "%.4e",
                                result.grDeflectionArcseconds
                            ) +
                            " arcsec"
                        )

                        Text(
                            "Δ:    " +
                            String(
                                format:
                                    "%.2f",
                                result.differencePercent
                            ) +
                            " %"
                        )
                    }
                }

                Section(
                    "Status"
                ) {

                    Text(
                        statusMessage
                    )
                    .font(
                        .footnote
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            .navigationTitle(
                "QRTL Lensing"
            )

            .navigationBarTitleDisplayMode(
                .inline
            )
        }
    }

    private func slider(
        _ title:
            String,

        value:
            Binding<Double>,

        range:
            ClosedRange<Double>
    ) -> some View {

        VStack(
            alignment:
                .leading
        ) {

            HStack {

                Text(
                    title
                )

                Spacer()

                Text(
                    String(
                        format:
                            "%.3e",
                        value.wrappedValue
                    )
                )
                .font(
                    .caption.monospaced()
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Slider(
                value:
                    value,

                in:
                    range
            )
        }
    }
}




struct LensingProjectionResult {

    // =========================================================
    // ALL PROJECTION HITS
    // =========================================================

    /// Every photon that produced a projection-plane hit.
    let hits: [LensingProjectionHit]


    // =========================================================
    // VALID PROJECTION HITS
    // =========================================================

    /// Hits that passed the projection-plane validity checks.
    let validHits: [LensingProjectionHit]


    // =========================================================
    // PROJECTED CENTER
    // =========================================================

    let projectedCenter: SIMD3<Float>


    // =========================================================
    // PROJECTION BOUNDS
    // =========================================================

    let minimum: SIMD3<Float>

    let maximum: SIMD3<Float>


    // =========================================================
    // PROJECTION DIMENSIONS
    // =========================================================

    let width: Float

    let height: Float

    let depth: Float


    // =========================================================
    // VALIDITY
    // =========================================================

    var isValid: Bool {

        !validHits.isEmpty
    }


    // =========================================================
    // INITIALIZER
    // =========================================================

    init(
        hits: [LensingProjectionHit],
        validHits: [LensingProjectionHit],
        projectedCenter: SIMD3<Float>,
        minimum: SIMD3<Float>,
        maximum: SIMD3<Float>,
        width: Float,
        height: Float,
        depth: Float
    ) {

        self.hits =
            hits

        self.validHits =
            validHits

        self.projectedCenter =
            projectedCenter

        self.minimum =
            minimum

        self.maximum =
            maximum

        self.width =
            width

        self.height =
            height

        self.depth =
            depth
    }


    // =========================================================
    // CALCULATE PROJECTION RESULT
    // =========================================================

    static func calculate(
        from hits: [LensingProjectionHit]
    ) -> LensingProjectionResult {

        // -----------------------------------------------------
        // NO HITS
        // -----------------------------------------------------

        guard !hits.isEmpty else {

            let zero =
                SIMD3<Float>(
                    0,
                    0,
                    0
                )

            return LensingProjectionResult(
                hits: [],
                validHits: [],
                projectedCenter: zero,
                minimum: zero,
                maximum: zero,
                width: 0,
                height: 0,
                depth: 0
            )
        }


        // -----------------------------------------------------
        // FILTER FINITE HITS
        // -----------------------------------------------------

        let validHits =
            hits.filter { hit in

                let p =
                    hit.point

                return
                    p.x.isFinite &&
                    p.y.isFinite &&
                    p.z.isFinite
            }


        // -----------------------------------------------------
        // NO VALID HITS
        // -----------------------------------------------------

        guard !validHits.isEmpty else {

            let zero =
                SIMD3<Float>(
                    0,
                    0,
                    0
                )

            return LensingProjectionResult(
                hits: hits,
                validHits: [],
                projectedCenter: zero,
                minimum: zero,
                maximum: zero,
                width: 0,
                height: 0,
                depth: 0
            )
        }


        // -----------------------------------------------------
        // INITIAL BOUNDS
        // -----------------------------------------------------

        var minimum =
            validHits[0].point

        var maximum =
            validHits[0].point


        // -----------------------------------------------------
        // CALCULATE 3D BOUNDS
        // -----------------------------------------------------

        for hit in validHits {

            let point =
                hit.point


            minimum.x =
                min(
                    minimum.x,
                    point.x
                )

            minimum.y =
                min(
                    minimum.y,
                    point.y
                )

            minimum.z =
                min(
                    minimum.z,
                    point.z
                )


            maximum.x =
                max(
                    maximum.x,
                    point.x
                )

            maximum.y =
                max(
                    maximum.y,
                    point.y
                )

            maximum.z =
                max(
                    maximum.z,
                    point.z
                )
        }


        // -----------------------------------------------------
        // DIMENSIONS
        // -----------------------------------------------------

        let width =
            max(
                maximum.x - minimum.x,
                0.0001
            )

        let height =
            max(
                maximum.y - minimum.y,
                0.0001
            )

        let depth =
            max(
                maximum.z - minimum.z,
                0.0001
            )


        // -----------------------------------------------------
        // PROJECTED CENTER
        // -----------------------------------------------------

        let projectedCenter =
            (
                minimum
                + maximum
            )
            * 0.5


        // -----------------------------------------------------
        // RETURN RESULT
        // -----------------------------------------------------

        return LensingProjectionResult(

            hits:
                hits,

            validHits:
                validHits,

            projectedCenter:
                projectedCenter,

            minimum:
                minimum,

            maximum:
                maximum,

            width:
                width,

            height:
                height,

            depth:
                depth
        )
    }
}

// ============================================================
// PHYSICAL CONSTANTS
// ============================================================

enum PhysicalConstants {

    // ============================================================
    // MARK: - FUNDAMENTAL PHYSICAL CONSTANTS
    // ============================================================

    /// Newtonian gravitational constant (m³ kg⁻¹ s⁻²)
    static let G: Double =
        6.67430e-11

    /// Speed of light in vacuum (m/s)
    static let speedOfLight: Double =
        299_792_458.0

    /// Alias retained for newer metric calculations.
    static let c: Double =
        speedOfLight

    /// Vacuum permittivity (F/m)
    static let epsilon0: Double =
        8.8541878128e-12

    /// Vacuum permeability (H/m)
    static let mu0: Double =
        1.25663706212e-6

    // ============================================================
    // MARK: - ASTRONOMICAL CONSTANTS
    // ============================================================

    /// Solar mass (kg)
    static let solarMass: Double =
        1.98847e30

    /// Solar radius (m)
    static let solarRadius: Double =
        6.957e8

    // ============================================================
    // MARK: - DERIVED RELATIVISTIC CONSTANTS
    // ============================================================

    /// Speed of light squared (m²/s²)
    static let cSquared: Double =
        speedOfLight * speedOfLight

    /// Schwarzschild radius of one solar mass (m)
    ///
    /// rₛ = 2GM☉ / c²
    static let solarSchwarzschildRadius: Double =
        2.0 *
        G *
        solarMass /
        cSquared

    // ============================================================
    // MARK: - ANGULAR CONVERSION
    // ============================================================

    /// Radians → arcseconds
    static let radiansToArcseconds: Double =
        206_264.80624709636
}
// ============================================================
// NUMERICAL UTILITIES
// ============================================================

@inline(__always)
func clamped(
    _ value: Double,
    minimum: Double,
    maximum: Double
) -> Double {

    min(
        max(value, minimum),
        maximum
    )
}

@inline(__always)
func transverseComponent(
    _ vector: SIMD3<Double>,
    relativeTo direction: SIMD3<Double>
) -> SIMD3<Double> {

    vector -
    direction *
    simd_dot(vector, direction)
}

// ============================================================
// EXPERIMENT RESULT
// ============================================================

struct QRTLExperimentResult {

    let qrtlDeflection:
        Double

    let grDeflection:
        Double

    let differencePercent:
        Double

    let qrtlDeflectionArcseconds:
        Double

    let grDeflectionArcseconds:
        Double
}
struct Field {
    func massDensity(at positionMeters: SIMD3<Float>) -> Float {
        // Implementation here
        return 0
    }

    func physicalMassDensity(at positionMeters: SIMD3<Float>) -> Float {
        // Implementation here
        return 0
    }

    func normalizedDensity(at positionMeters: SIMD3<Float>) -> Float {
        // Implementation here
        return 0
    }

    func influence(at positionMeters: SIMD3<Float>) -> Float {
        // Implementation here
        return 0
    }

    func gravitationalPotential(at positionMeters: SIMD3<Float>) -> Float {
        // Implementation here
        return 0
    }
}

struct Diagnostics {
    var field: Field

    func diagnosticSample(scenePosition: SIMD3<Float>) -> Float {
        // SceneKit units → physical meters
        let positionMeters = scenePosition * Float(MetersPerSceneUnit.value)
        print("Diagnostic Sample - Scene position: \(scenePosition), Meters: \(positionMeters)")

        let radiusMeters = 1.0 * Float(MetersPerSceneUnit.value)
        print("Sample radius in meters: \(radiusMeters)")

        return field.massDensity(at: positionMeters)
    }

    func anotherDiagnostic(scenePosition: SIMD3<Float>) -> Float {
        // SceneKit units → physical meters
        let positionMeters = scenePosition * Float(MetersPerSceneUnit.value)
        return field.normalizedDensity(at: positionMeters)
    }
}

struct SurfaceDebug {
    var field: Field

    func debugPoint(scenePosition: SIMD3<Float>) -> Float {
        // SceneKit units → physical meters
        let positionMeters = scenePosition * Float(MetersPerSceneUnit.value)
        return field.gravitationalPotential(at: positionMeters)
    }
}

struct Grid {
    var field: Field

    func sampleField(atScenePosition scenePosition: SIMD3<Float>) -> Float {
        // SceneKit units → physical meters
        let positionMeters = scenePosition * Float(MetersPerSceneUnit.value)
        return field.influence(at: positionMeters)
    }
}

