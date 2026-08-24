//
//  QRTLExperiment.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/18/26.
//

import Foundation
import simd

// ============================================================
// QRTL EXPERIMENT
// ============================================================
//
// Authoritative physics experiment.
//
// COORDINATE CONVENTION (authoritative — matches
// QRTLGravitySurfaceEntity exactly):
//
//     X = photon propagation direction
//     Y = transverse coordinate
//     Z = transverse coordinate
//
// The stellar distribution generated below is a UNIFORM SPHERE —
// symmetric under rotation about any axis — so it carries no
// axis-specific assumption of its own and cannot conflict with
// this convention. Any code that later samples the field along a
// specific axis (e.g. QRTLField.buildRadialGravityTable, which
// samples along physical X) relies on that same spherical
// symmetry, not on any particular axis being "special."
//
// Physical pipeline:
//
// BARYONIC MASS
//      ↓
// GLOBULAR CLUSTER STAR POSITIONS
//      ↓
// GLOBULAR CLUSTER DENSITY MAP
//      ↓
// PHYSICAL MASS DENSITY
//      ↓
// STELLAR GRAVITATIONAL POTENTIAL
//      ↓
// STELLAR GRAVITATIONAL ACCELERATION
//      ↓
// QRTL FIELD
//      ↓
// QRTL ENERGY DENSITY
//      ↓
// QRTL GRAVITY INDEX
//      ↓
// QRTL GRAVITATIONAL POTENTIAL
//      ↓
// QRTL GRAVITATIONAL ACCELERATION
//      ↓
// TRANSVERSE GRAVITY
//      ↓
// EINSTEIN-STYLE PHOTON CURVATURE
//      ↓
// PHOTON TRACER
//      ↓
// PHOTON TRACE RESULT
//      ↓
// MEASURED QRTL PHOTON DEFLECTION
//      ↓
// GENERAL RELATIVITY REFERENCE
//      ↓
// QRTL / GR COMPARISON
//
// ============================================================

final class QRTLExperiment {

    // ========================================================
    // DETERMINISTIC RANDOM NUMBER GENERATOR (SplitMix64)
    // ========================================================
    //
    // Swift's `Float.random(in:)` with no generator argument uses
    // SystemRandomNumberGenerator, which is intentionally
    // non-deterministic — a different stellar distribution (and
    // therefore a different lens) every run. That makes QRTL-vs-GR
    // comparisons impossible to reproduce.
    //
    // SeededGenerator is a small, fast, deterministic generator:
    // the SAME seed always produces the SAME sequence of star
    // positions, so an experiment can be re-run — or compared
    // against a GR reference run — with an identical lens.
    // ========================================================

    struct SeededGenerator: RandomNumberGenerator {

        private var state: UInt64

        init(seed: UInt64) {

            // Avoid a zero state, which would produce a degenerate
            // (all-zero) sequence from SplitMix64.
            self.state =
                seed == 0
                ? 0x9E3779B97F4A7C15
                : seed
        }

        mutating func next() -> UInt64 {

            state = state &+ 0x9E3779B97F4A7C15

            var z = state

            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB

            return z ^ (z >> 31)
        }
    }

    // ========================================================
    // FIELD
    // ========================================================

    let field: QRTLField

    // ========================================================
    // PARAMETERS
    // ========================================================

    let parameters: QRTLParameters

    // ========================================================
    // PHYSICAL CONSTANTS
    // ========================================================

    private static let solarMassKg: Double =
        1.98847e30

    private static let defaultClusterMassKg: Double =
        1.0e6 * solarMassKg

    // ========================================================
    // CLUSTER CONFIGURATION
    // ========================================================

    private let clusterMassKg: Double

    private let clusterRadiusMeters: Double

    private let starCount: Int

    // ========================================================
    // REPRODUCIBILITY
    // ========================================================
    //
    // The seed actually used to generate starPositions (when no
    // external distribution was supplied). Exposed so a caller can
    // read back exactly what produced this experiment's lens, log
    // it alongside results, and reuse it later.
    //
    // nil when an externally supplied star distribution was used
    // instead — the seed is meaningless in that case.
    // ========================================================

    let starPositionSeed: UInt64?

    // ========================================================
    // STAR POSITIONS
    // ========================================================

    //
    // These positions are retained so the experiment and
    // density map use the SAME physical stellar distribution.
    //
    let starPositions: [SIMD3<Float>]

    // ========================================================
    // INITIALIZATION
    // ========================================================
    //
    // For repeatable experiments (e.g. QRTL vs. GR comparisons
    // that must use the same lens), either:
    //
    //   • pass `starPositions:` with an externally supplied
    //     distribution — nothing is generated, and
    //     starPositionSeed is nil, OR
    //   • rely on the default deterministic `seed:` (or pass your
    //     own) — the same seed always reproduces the same
    //     distribution.
    //
    // The old behavior — a fresh, unseeded, unreproducible
    // distribution every call — is no longer the default.
    // ========================================================

    init(
        mass: Double,
        radius: Double,
        parameters: QRTLParameters,
        starPositions externalStarPositions: [SIMD3<Float>]? = nil,
        seed: UInt64 = 42
    ) {

        self.parameters = parameters

        // ====================================================
        // TOTAL CLUSTER MASS
        // ====================================================

        let resolvedClusterMassKg: Double

        if mass.isFinite && mass > 0.0 {

            resolvedClusterMassKg = mass

        } else {

            resolvedClusterMassKg =
                Self.defaultClusterMassKg
        }

        self.clusterMassKg =
            resolvedClusterMassKg

        // ====================================================
        // CLUSTER RADIUS
        // ====================================================

        let resolvedRadius: Double =
            radius.isFinite && radius > 0.0
            ? radius
            : 1.0e-6

        self.clusterRadiusMeters =
            resolvedRadius

        let clusterRadiusFloat =
            Float(resolvedRadius)

        // ====================================================
        // STAR DISTRIBUTION
        // ====================================================
        //
        // Generate the physical 3D stellar distribution.
        //
        // The same positions are passed directly into
        // GlobularClusterDensityMap.
        //
        // Therefore:
        //
        //     stars
        //       ↓
        //     density map
        //       ↓
        //     QRTLField
        //
        // all describe the same lens.
        //
        // ====================================================

        let positions: [SIMD3<Float>]

        if let externalStarPositions,
           !externalStarPositions.isEmpty {

            // ------------------------------------------------
            // EXTERNALLY SUPPLIED DISTRIBUTION
            //
            // No generation, no randomness at all — the caller
            // is fully in control of the lens (e.g. reusing an
            // exact distribution from a prior experiment).
            // ------------------------------------------------

            positions =
                externalStarPositions

            self.starCount =
                externalStarPositions.count

            self.starPositionSeed =
                nil

        } else {

            // ------------------------------------------------
            // DETERMINISTIC GENERATION
            //
            // Same seed → same sequence → same stellar
            // distribution → same lens, every time.
            // ------------------------------------------------

            let resolvedStarCount = 1000

            self.starCount =
                resolvedStarCount

            self.starPositionSeed =
                seed

            var rng =
                SeededGenerator(
                    seed: seed
                )

            var generated:
                [SIMD3<Float>] = []

            generated.reserveCapacity(
                resolvedStarCount
            )

            for _ in 0..<resolvedStarCount {

                let theta =
                    Float.random(
                        in: 0.0...(2.0 * Float.pi),
                        using: &rng
                    )

                let zDirection =
                    Float.random(
                        in: -1.0...1.0,
                        using: &rng
                    )

                let radialXY =
                    sqrt(
                        max(
                            0.0,
                            1.0 -
                            zDirection *
                            zDirection
                        )
                    )

                let randomUnit =
                    Float.random(
                        in: 0.0...1.0,
                        using: &rng
                    )

                // Uniform spherical-volume distribution.
                let radialFraction =
                    pow(
                        randomUnit,
                        Float(1.0 / 3.0)
                    )

                let r =
                    clusterRadiusFloat *
                    radialFraction

                let x =
                    r *
                    radialXY *
                    cos(theta)

                let y =
                    r *
                    radialXY *
                    sin(theta)

                let z =
                    r *
                    zDirection

                generated.append(
                    SIMD3<Float>(
                        x,
                        y,
                        z
                    )
                )
            }

            positions =
                generated
        }

        self.starPositions =
            positions

        // ====================================================
        // GLOBULAR CLUSTER DENSITY MAP
        // ====================================================
        //
        // This is the physical source of the lens.
        //
        // It contains:
        //
        // • total cluster mass
        // • cluster radius
        // • 3,000 stars
        // • per-star mass
        // • actual 3D star positions
        // • physical mass density
        // • stellar gravitational potential
        // • stellar gravitational acceleration
        //
        // ====================================================

        let densityMap =
            GlobularClusterDensityMap(
                clusterMassKg:
                    resolvedClusterMassKg,

                clusterRadiusMeters:
                    clusterRadiusFloat,

                starPositions:
                    positions,

                plummerScaleFraction:
                    0.30
            )

        // ====================================================
        // AUTHORITATIVE QRTL FIELD
        // ====================================================
        //
        // IMPORTANT:
        //
        // Current QRTLField owns the QRTL gravity model.
        //
        // The field receives the actual 3D stellar mass model.
        //
        // It then calculates:
        //
        // physical density
        //       ↓
        // QRTL source
        //       ↓
        // Bolgarino flux
        //       ↓
        // QRTL current
        //       ↓
        // QRTL energy density
        //       ↓
        // QRTL gravity index
        //       ↓
        // QRTL gravitational acceleration
        //       ↓
        // photon curvature
        //
        // ====================================================

        self.field =
            QRTLField(
                densitySource:
                    densityMap,

                parameters:
                    parameters
            )
    }

    // ========================================================
    // RUN EXPERIMENT
    // ========================================================

    func run(
        impactParameter: Double,
        startDistance: Double,
        endDistance: Double,
        stepSize: Double
    ) -> QRTLExperimentResult {

        // ====================================================
        // SAFE INPUTS
        // ====================================================

        let safeImpactParameter =
            max(
                abs(impactParameter),
                1.0e-9
            )

        let safeStartDistance =
            max(
                startDistance,
                1.0e-9
            )

        let safeEndDistance =
            max(
                endDistance,
                1.0e-9
            )

        let safeStepSize =
            max(
                stepSize,
                1.0e-9
            )

        // ====================================================
        // PHOTON ORIGIN
        // ====================================================
        //
        // Physical coordinates:
        //
        //     X = photon propagation direction
        //     Y = impact parameter
        //     Z = transverse direction
        //
        // Photon starts at -X and travels toward +X.
        //
        // ====================================================

        let origin =
            SIMD3<Float>(
                Float(-safeStartDistance),
                Float(safeImpactParameter),
                0.0
            )

        let direction =
            SIMD3<Float>(
                1.0,
                0.0,
                0.0
            )

        // ====================================================
        // TOTAL TRAVEL DISTANCE
        // ====================================================

        let totalDistance =
            safeStartDistance +
            safeEndDistance

        // ====================================================
        // INTEGRATION STEPS
        // ====================================================

        let calculatedMaxSteps =
            max(
                Int(
                    ceil(
                        totalDistance /
                        safeStepSize
                    )
                ),
                1
            )

        // ====================================================
        // CURRENT LENSING PARAMETERS
        // ====================================================
        //
        // The photon tracer queries the current QRTLField.
        //
        // In particular, QRTLField supplies:
        //
        //     qrtlGravitationalAcceleration(at:)
        //
        //     qrtlTransverseGravity(
        //         at:photonDirection:
        //     )
        //
        //     qrtlPhotonCurvature(
        //         at:direction:
        //     )
        //
        //     qrtlLensingAcceleration(
        //         at:direction:
        //     )
        //
        // The QRTL gravity index is therefore part of the
        // actual photon-curvature calculation.
        //
        // Electromagnetic photon bending remains disabled
        // here so the gravitational QRTL prediction can be
        // compared independently with GR.
        //
        // ====================================================

        let lensingParameters =
            LensingParameters(
                maximumPhotonSteps:
                    calculatedMaxSteps,

                   deflectionStrength:
                    1.0,
                   projectionPlaneHalfExtent:
                       18.0,
                      maximumPropagationRadius:
                    Float(
                        max(
                            totalDistance,
                            0.001
                        )
                    ),

                photonStepSize:
                    Float(
                        safeStepSize
                    ),


         
            
                qrtlLensingStrength:
                    Float(
                        parameters.chiQ
                    ),

                maximumPhotonBend:
                    0.35,

                qrtlFieldCoupling:
                    1.0,

                qrtlPhotonCoupling:
                    1.0,

                electromagneticCoupling:
                    0.0,

                magneticPhotonCoupling:
                    0.0,

                magneticBendingStrength:
                    0.0,

                currentCoupling:
                    0.0,

                targetPlaneX:
                    Float(
                        safeEndDistance
                    ),

           

                interactionRate:
                    0.0
            )

        // ====================================================
        // QRTL GRAVITY INDEX DIAGNOSTIC
        // ====================================================
        //
        // The QRTLField now contains a global calibration
        // relationship between the physical stellar mass
        // density and the QRTL effective energy density.
        //
        // This is NOT a GR value.
        //
        // It is a QRTL calibration quantity used to put the
        // QRTL gravitational prediction onto the physical
        // mass scale.
        //
        // ====================================================

      
        print("")
        print("============================================================")
        print("QRTL EXPERIMENT")
        print("============================================================")
        print("Cluster mass:")
        print(clusterMassKg)
        print("Cluster radius:")
        print(clusterRadiusMeters)
        print("Star count:")
        print(starPositions.count)
        print("Per-star mass:")
        print("QRTL gravity index:")
           print("============================================================")
        print("")

        // ====================================================
        // PHOTON TRACER
        // ====================================================

        let tracer =
            QRTLPhotonTracer(
                field:
                    field
            )

        let trace =
            tracer.tracePhoton(
                origin:
                    origin,

                direction:
                    direction,

                parameters:
                    lensingParameters,
                
                sceneToPhysicalScale: 1.0
            )

        // ====================================================
        // VALIDATE TRACE
        // ====================================================

        guard
            trace.positions.count >= 2
        else {

            return zeroResult()
        }

        // ====================================================
        // PHOTON POSITIONS
        // ====================================================

        let positions =
            trace.positions

        // ====================================================
        // INCOMING DIRECTION
        // ====================================================

        let incomingVector =
            positions[1] -
            positions[0]

        let incomingLength =
            simd_length(
                incomingVector
            )

        guard
            incomingLength.isFinite,
            incomingLength > 0.000001
        else {

            return zeroResult()
        }

        let incoming =
            incomingVector /
            incomingLength

        // ====================================================
        // OUTGOING DIRECTION
        // ====================================================

        var outgoing =
            trace.finalDirection

        let outgoingLength =
            simd_length(
                outgoing
            )

        if
            !outgoingLength.isFinite ||
            outgoingLength <= 0.000001
        {

            let finalIndex =
                positions.count - 1

            let outgoingVector =
                positions[finalIndex] -
                positions[finalIndex - 1]

            let fallbackLength =
                simd_length(
                    outgoingVector
                )

            guard
                fallbackLength.isFinite,
                fallbackLength > 0.000001
            else {

                return zeroResult()
            }

            outgoing =
                outgoingVector /
                fallbackLength

        } else {

            outgoing /=
                outgoingLength
        }

        // ====================================================
        // DEFLECTION ANGLE
        // ====================================================
        //
        // This is the measured deflection produced by the
        // QRTLField-driven photon integration.
        //
        // ====================================================

        let dotProduct =
            simd_dot(
                incoming,
                outgoing
            )

        let cosine =
            min(
                max(
                    dotProduct,
                    -1.0
                ),
                1.0
            )

        let qrtlAngleFloat =
            acos(
                cosine
            )

        guard
            qrtlAngleFloat.isFinite
        else {

            return zeroResult()
        }

        let qrtlAngle =
            Double(
                qrtlAngleFloat
            )

        guard
            qrtlAngle.isFinite
        else {

            return zeroResult()
        }

        // ====================================================
        // GENERAL RELATIVITY REFERENCE
        // ====================================================
        //
        // Weak-field point-mass reference:
        //
        //     alpha_GR = 4GM / (b c²)
        //
        // This is intentionally independent of the QRTL
        // calculation.
        //
        // QRTL predicts its own deflection.
        //
        // GR supplies the reference prediction.
        //
        // ====================================================

        let G =
            Double(
                PhysicalConstants.G
            )

        let c =
            Double(
                PhysicalConstants.c
            )

        let cSquared =
            c * c

        let denominator =
            safeImpactParameter *
            cSquared

        guard
            denominator.isFinite,
            denominator > 0.0
        else {

            return zeroResult()
        }

        let grAngle =
            4.0 *
            G *
            clusterMassKg /
            denominator

        guard
            grAngle.isFinite
        else {

            return zeroResult()
        }

        // ====================================================
        // DIFFERENCE FROM GENERAL RELATIVITY
        // ====================================================

        let differencePercent: Double

        if grAngle > 0.0 {

            differencePercent =
                100.0 *
                (
                    qrtlAngle -
                    grAngle
                ) /
                grAngle

        } else {

            differencePercent =
                0.0
        }

        // ====================================================
        // ARCSECONDS
        // ====================================================

        let radiansToArcseconds =
            Double(
                PhysicalConstants
                    .radiansToArcseconds
            )

        let qrtlArcseconds =
            qrtlAngle *
            radiansToArcseconds

        let grArcseconds =
            grAngle *
            radiansToArcseconds

        // ====================================================
        // FINAL RESULT
        // ====================================================

        return QRTLExperimentResult(

            qrtlDeflection:
                qrtlAngle,

            grDeflection:
                grAngle,

            differencePercent:
                differencePercent,

            qrtlDeflectionArcseconds:
                qrtlArcseconds,

            grDeflectionArcseconds:
                grArcseconds
        )
    }

    // ========================================================
    // ZERO RESULT
    // ========================================================

    private func zeroResult()
        -> QRTLExperimentResult {

        return QRTLExperimentResult(

            qrtlDeflection:
                0.0,

            grDeflection:
                0.0,

            differencePercent:
                0.0,

            qrtlDeflectionArcseconds:
                0.0,

            grDeflectionArcseconds:
                0.0
        )
    }
}

