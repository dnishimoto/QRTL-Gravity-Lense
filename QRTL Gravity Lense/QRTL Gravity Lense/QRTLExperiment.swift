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
// QRTL FIELD
//      ↓
// GRAVITATIONAL / QRTL FIELD
//      ↓
// QRTL PHOTON TRACER
//      ↓
// PHOTONTRACE RESULT
//      ↓
// DEFLECTION COMPARISON WITH GR
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

        let clusterMassKg: Double

        if mass.isFinite && mass > 0.0 {
            clusterMassKg = mass
        } else {
            clusterMassKg =
                Self.defaultClusterMassKg
        }

        // ====================================================
        // CLUSTER RADIUS
        // ====================================================

        let clusterRadiusMeters =
            Float(
                max(
                    radius,
                    1.0e-6
                )
            )

        // ====================================================
        // STAR DISTRIBUTION
        // ====================================================

        let starCount = 3000

        var positions:
            [SIMD3<Float>] = []

        positions.reserveCapacity(
            starCount
        )

        // ====================================================
        // SPHERICAL STAR DISTRIBUTION
        // ====================================================

        for _ in 0..<starCount {

            let theta =
                Float.random(
                    in:
                        0.0...(2.0 * Float.pi)
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

            // Uniform volume distribution.
            let radialFraction =
                pow(
                    randomUnit,
                    1.0 / 3.0
                )

            let r =
                clusterRadiusMeters *
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
        // CELLULAR-AUTOMATA DENSITY SOURCE
        // ====================================================

        let densitySource =
            GlobularClusterDensityMap(
                positions:
                    positions,
                radiusMeters:
                    clusterRadiusMeters,
                totalMass:
                    Float(
                        clusterMassKg
                    ),
                cellSizeMeters:
                    0.20
            )

        // ====================================================
        // QRTL FIELD
        // ====================================================

        self.field =
            QRTLField(
                densitySource:
                    densitySource,
                parameters:
                    parameters,
                physicalRadiusMeters:
                    radius
            )
    }

    func run(
        impactParameter: Double,
        startDistance: Double,
        endDistance: Double,
        stepSize: Double
    ) -> QRTLExperimentResult {

        // ========================================================
        // SAFE INPUTS
        // ========================================================

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

        // ========================================================
        // PHOTON ORIGIN
        // ========================================================
        //
        // Photon travels in +X.
        //
        // Impact parameter is Y.
        //
        // ========================================================

        let origin =
            SIMD3<Double>(
                -safeStartDistance,
                safeImpactParameter,
                0.0
            )

        let direction =
            SIMD3<Double>(
                1.0,
                0.0,
                0.0
            )

        // ========================================================
        // TOTAL TRAVEL DISTANCE
        // ========================================================

        let totalDistance =
            safeStartDistance +
            safeEndDistance

        // ========================================================
        // INTEGRATION STEPS
        // ========================================================

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

        // ========================================================
        // CURRENT LENSING PARAMETERS
        // ========================================================
        //
        // This matches the CURRENT LensingParameters definition.
        //
        // No maxRadius
        // No stepSize
        // No maxSteps
        // No projectionX
        // No projectionDistance
        // No targetPlaneZ
        //
        // ========================================================

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
                    1.0,

                maximumPhotonBend:
                    0.35,

                qrtlFieldCoupling:
                    1.0,

                qrtlPhotonCoupling:
                    0.25,

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

        // ========================================================
        // PHOTON TRACER
        // ========================================================

        let tracer =
            QRTLPhotonTracer(
                field:
                    field
            )

        let trace =
            tracer.tracePhoton(
                origin:
                    SIMD3<Float>(
                        Float(origin.x),
                        Float(origin.y),
                        Float(origin.z)
                    ),

                direction:
                    SIMD3<Float>(
                        Float(direction.x),
                        Float(direction.y),
                        Float(direction.z)
                    ),

                parameters:
                    lensingParameters
            )

        // ========================================================
        // VALIDATE TRACE
        // ========================================================

        guard
            trace.positions.count >= 2
        else {
            return zeroResult()
        }

        // ========================================================
        // PHOTON POSITIONS
        // ========================================================

        let positions =
            trace.positions

        // ========================================================
        // INCOMING DIRECTION
        // ========================================================

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

        // ========================================================
        // OUTGOING DIRECTION
        // ========================================================

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

        // ========================================================
        // DEFLECTION ANGLE
        // ========================================================

        let incomingFloat =
            SIMD3<Float>(
                incoming.x,
                incoming.y,
                incoming.z
            )

        let outgoingFloat =
            SIMD3<Float>(
                outgoing.x,
                outgoing.y,
                outgoing.z
            )

        let dotProduct =
            simd_dot(
                incomingFloat,
                outgoingFloat
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

        // ========================================================
        // EINSTEIN WEAK-FIELD REFERENCE
        // ========================================================
        //
        // alpha_GR = 4GM / (bc²)
        //
        // ========================================================

        let physicalMassKg =
            Double(
                field
                    .densitySource
                    .totalMass
            )

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
            physicalMassKg /
            denominator

        guard
            grAngle.isFinite
        else {
            return zeroResult()
        }

        // ========================================================
        // DIFFERENCE FROM GENERAL RELATIVITY
        // ========================================================

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

        // ========================================================
        // ARCSECONDS
        // ========================================================

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

        // ========================================================
        // RESULT
        // ========================================================

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

        QRTLExperimentResult(

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
