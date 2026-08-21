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
// Pipeline:
//
// BARYONIC MASS
//      ↓
// GLOBULAR CLUSTER DENSITY
//      ↓
// CONTINUOUS MASS PROFILE
//      ↓
// QRTL FIELD
//      ↓
// GRAVITATIONAL POTENTIAL
//      ↓
// SPACETIME METRIC
//      ↓
// PHOTON TRACER
//      ↓
// PHOTON TRACE RESULT
//      ↓
// MEASURED PHOTON DEFLECTION
//      ↓
// GENERAL RELATIVITY REFERENCE
//      ↓
// QRTL / GR COMPARISON
//
// ============================================================

final class QRTLExperiment {

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
    private let starCount: Int = 3000

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init(
        mass: Double,
        radius: Double,
        parameters: QRTLParameters
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

        let resolvedRadius =
            max(
                radius,
                1.0e-6
            )

        self.clusterRadiusMeters =
            resolvedRadius

        let clusterRadiusFloat =
            Float(resolvedRadius)

        // ====================================================
        // STAR DISTRIBUTION
        // ====================================================
        //
        // Stars are retained for:
        //
        // • source galaxy visualization
        // • photon source generation
        // • projection rendering
        //
        // The continuous density source supplies the
        // gravitational field.
        //
        // ====================================================

        var positions: [SIMD3<Float>] = []

        positions.reserveCapacity(
            starCount
        )
        // ====================================================
        // SPHERICAL STAR DISTRIBUTION
        // ====================================================

        for _ in 0..<starCount {

            let thetaRange =
                ClosedRange<Float>(
                    uncheckedBounds:
                        (
                            lower: 0.0,
                            upper: 2.0 * Float.pi
                        )
                )

            let theta =
                Float.random(
                    in: thetaRange
                )

            let zDirection =
                Float.random(
                    in:
                        -1.0...1.0
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
                    in:
                        0.0...1.0
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

            positions.append(
                SIMD3<Float>(
                    x,
                    y,
                    z
                )
            )
        }
        // ====================================================
        // CONTINUOUS GLOBULAR CLUSTER DENSITY SOURCE
        // ====================================================
        //
        // The density source is continuous.
        //
        // The individual star positions are NOT used as a
        // sparse gravitational grid.
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
        // QRTL FIELD
        // ====================================================

        self.field =
            QRTLField(
                densitySource:
                    densityMap,
                parameters:
                    parameters,
                physicalRadiusMeters:
                    resolvedRadius
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
        // The experiment uses PHYSICAL METERS.
        //
        // Photon:
        //
        //     starts at -X
        //     travels toward +X
        //     has Y impact parameter
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
        // IMPORTANT:
        //
        // The QRTLField currently provides:
        //
        //     qrtlLensingAcceleration(...)
        //
        // and
        //
        //     einsteinPhotonBendingAcceleration(...)
        //
        // Electromagnetic photon bending is currently
        // disabled in QRTLField:
        //
        //     electromagneticInfluence = .zero
        //
        // Therefore EM photon coupling remains ZERO here.
        //
        // ====================================================

        let lensingParameters =
            LensingParameters(

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

                maximumPhotonSteps:
                    calculatedMaxSteps,

                deflectionStrength:
                    1.0,

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

                projectionPlaneHalfExtent:
                    18.0,

                interactionRate:
                    0.0
            )

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
                    lensingParameters
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
        // ====================================================
        //
        // Weak-field point-mass approximation:
        //
        //     alpha_GR = 4GM / (bc²)
        //
        // The impact parameter and cluster mass are both
        // physical quantities in this experiment.
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
        // RESULT
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
