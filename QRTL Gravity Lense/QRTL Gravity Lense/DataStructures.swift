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

// ============================================================
// QRTL GRAVITY SURFACE DIAGNOSTICS
// ============================================================



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
    let effectiveMassDensity: Double
    let enclosedMass: Double
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
// CATMULL-ROM SPLINE
// ============================================================

enum CatmullRomSpline {

    static func interpolate(
        points: [SIMD3<Double>],
        pointsPerSegment: Int = 8
    ) -> [SIMD3<Double>] {

        guard points.count >= 2 else {
            return points
        }

        let segments =
            max(
                pointsPerSegment,
                1
            )

        if points.count == 2 {

            let p0 = points[0]
            let p1 = points[1]

            var result:
                [SIMD3<Double>] = []

            result.reserveCapacity(
                segments + 1
            )

            for step in 0...segments {

                let t =
                    Double(step) /
                    Double(segments)

                result.append(
                    p0 +
                    (p1 - p0) * t
                )
            }

            return result
        }

        var extended =
            points

        extended.insert(
            points[0] +
            (points[0] - points[1]),
            at: 0
        )

        extended.append(
            points[points.count - 1] +
            (
                points[points.count - 1] -
                points[points.count - 2]
            )
        )

        var result:
            [SIMD3<Double>] = []

        let segmentCount =
            extended.count - 3

        for i in 0..<segmentCount {

            let p0 = extended[i]
            let p1 = extended[i + 1]
            let p2 = extended[i + 2]
            let p3 = extended[i + 3]

            let startStep =
                i == 0 ? 0 : 1

            for step in startStep...segments {

                let t =
                    Double(step) /
                    Double(segments)

                let t2 =
                    t * t

                let t3 =
                    t2 * t

                let a =
                    -0.5 * t3 +
                    t2 -
                    0.5 * t

                let b =
                    1.5 * t3 -
                    2.5 * t2 +
                    1.0

                let c =
                    -1.5 * t3 +
                    2.0 * t2 +
                    0.5 * t

                let d =
                    0.5 * t3 -
                    0.5 * t2

                let point =
                    p0 * a +
                    p1 * b +
                    p2 * c +
                    p3 * d

                result.append(point)
            }
        }

        return result
    }
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

