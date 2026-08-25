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
// COORDINATE CONVENTION:
//
//     X = photon propagation direction
//     Y = transverse coordinate / impact parameter
//     Z = transverse coordinate
//
// UNIT CONTRACT:
//
//     run(...) accepts SI distances in metres:
//
//         impactParameter = metres
//         startDistance   = metres
//         endDistance     = metres
//         stepSize        = metres
//
//     QRTLPhotonTracer integrates normalized coordinates:
//
//         q¹ = X / Rcluster
//         q² = Y / Rcluster
//         q³ = Z / Rcluster
//
//     The GR reference continues to use the original physical
//     impact parameter in metres.
//
// ============================================================

final class QRTLExperiment {

    // ========================================================
    // DETERMINISTIC RANDOM NUMBER GENERATOR (SplitMix64)
    // ========================================================

    struct SeededGenerator: RandomNumberGenerator {

        private var state: UInt64

        init(seed: UInt64) {
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

    let starPositionSeed: UInt64?

    // ========================================================
    // STAR POSITIONS
    // ========================================================

    let starPositions: [SIMD3<Float>]

    // ========================================================
    // INITIALIZATION
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

        let positions: [SIMD3<Float>]

        if let externalStarPositions,
           !externalStarPositions.isEmpty {

            positions =
                externalStarPositions

            self.starCount =
                externalStarPositions.count

            self.starPositionSeed =
                nil

        } else {

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

                let plummerScale: Float =
                    0.30

                let safeRandomUnit =
                    max(
                        randomUnit,
                        1.0e-6
                    )

                let denominator =
                    pow(
                        safeRandomUnit,
                        Float(-2.0 / 3.0)
                    ) - 1.0

                let radialFraction: Float

                if denominator.isFinite,
                   denominator > 0.0 {

                    let plummerScaleRadius =
                        clusterRadiusFloat *
                        plummerScale

                    let candidateRadius =
                        plummerScaleRadius /
                        sqrt(denominator)

                    radialFraction =
                        min(
                            candidateRadius,
                            clusterRadiusFloat
                        ) /
                        clusterRadiusFloat

                } else {

                    radialFraction =
                        0.0
                }

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
    //
    // INPUT UNIT CONTRACT:
    //
    // impactParameter = metres
    // startDistance   = metres
    // endDistance     = metres
    // stepSize        = metres
    //
    // The GR formula uses physical SI values directly.
    //
    // QRTLPhotonTracer receives values normalized by:
    //
    //     q = physicalDistanceMeters / clusterRadiusMeters
    //
    // ========================================================

    func run(
        impactParameter: Double,
        startDistance: Double,
        endDistance: Double,
        stepSize: Double
    ) -> QRTLExperimentResult {

        // ====================================================
        // SAFE PHYSICAL INPUTS — METRES
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
        // PHYSICAL INPUTS — METRES
        //
        // Keep these values separate from q-space values.
        // They are used by the GR reference equation.
        // ====================================================

        let impactParameterMeters =
            safeImpactParameter

        let startDistanceMeters =
            safeStartDistance

        let endDistanceMeters =
            safeEndDistance

        let stepSizeMeters =
            safeStepSize

        guard clusterRadiusMeters.isFinite,
              clusterRadiusMeters > 0.0
        else {
            return zeroResult()
        }

        // ====================================================
        // NORMALIZED PHOTON-TRACER COORDINATES
        //
        // QRTLPhotonTracer integrates:
        //
        //     q¹ = X / Rcluster
        //     q² = Y / Rcluster
        //     q³ = Z / Rcluster
        //
        // These values are dimensionless.
        // ====================================================

        let normalizedImpactParameter =
            impactParameterMeters /
            clusterRadiusMeters

        let normalizedStartDistance =
            startDistanceMeters /
            clusterRadiusMeters

        let normalizedEndDistance =
            endDistanceMeters /
            clusterRadiusMeters

        let normalizedStepSize =
            stepSizeMeters /
            clusterRadiusMeters

        guard normalizedImpactParameter.isFinite,
              normalizedStartDistance.isFinite,
              normalizedEndDistance.isFinite,
              normalizedStepSize.isFinite,
              normalizedImpactParameter >= 0.0,
              normalizedStartDistance > 0.0,
              normalizedEndDistance > 0.0,
              normalizedStepSize > 0.0
        else {
            return zeroResult()
        }

        // ====================================================
        // PHOTON ORIGIN — NORMALIZED q COORDINATES
        //
        // X = propagation direction
        // Y = normalized impact parameter
        // Z = transverse coordinate
        //
        // The photon begins at -X and travels toward +X.
        // ====================================================

        let origin =
            SIMD3<Float>(
                Float(-normalizedStartDistance),
                Float(normalizedImpactParameter),
                0.0
            )

        let direction =
            SIMD3<Float>(
                1.0,
                0.0,
                0.0
            )

        // ====================================================
        // NORMALIZED TRACE EXTENT
        // ====================================================

        let totalNormalizedDistance =
            normalizedStartDistance +
            normalizedEndDistance

        let calculatedMaxSteps =
            max(
                Int(
                    ceil(
                        totalNormalizedDistance /
                        normalizedStepSize
                    )
                ),
                1
            )

        // ====================================================
        // CURRENT LENSING PARAMETERS
        //
        // All propagation values passed to QRTLPhotonTracer are
        // normalized q-space quantities.
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
                            totalNormalizedDistance,
                            0.001
                        )
                    ),

                photonStepSize:
                    Float(
                        normalizedStepSize
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
                        normalizedEndDistance
                    ),

                interactionRate:
                    0.0
            )

        // ====================================================
        // QRTL EXPERIMENT DEBUG
        // ====================================================

        print(
            """
            ============================================================
            QRTL EXPERIMENT
            ============================================================
            clusterMassKg              = \(String(format: "%.6e", clusterMassKg))
            clusterRadiusMeters        = \(String(format: "%.6e", clusterRadiusMeters))
            starCount                  = \(starPositions.count)
            impactParameterMeters      = \(String(format: "%.6e", impactParameterMeters))
            startDistanceMeters        = \(String(format: "%.6e", startDistanceMeters))
            endDistanceMeters          = \(String(format: "%.6e", endDistanceMeters))
            stepSizeMeters             = \(String(format: "%.6e", stepSizeMeters))
            normalizedImpactParameter  = \(String(format: "%.6e", normalizedImpactParameter))
            normalizedStartDistance    = \(String(format: "%.6e", normalizedStartDistance))
            normalizedEndDistance      = \(String(format: "%.6e", normalizedEndDistance))
            normalizedStepSize         = \(String(format: "%.6e", normalizedStepSize))
            ============================================================
            """
        )

        // ====================================================
        // PHOTON TRACER
        //
        // 1.0 means one visual scene unit corresponds to one
        // normalized cluster radius.
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

                sceneToPhysicalScale:
                    1.0
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
        //
        // alpha_GR = 4GM / (b c²)
        //
        // b is explicitly the physical SI impact parameter.
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
            impactParameterMeters *
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
