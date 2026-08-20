//
//  QRTLExperiment.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/18/26.
//

import Foundation
import simd
import SwiftUI

// ============================================================
// QRTL EXPERIMENT
// ============================================================
//
// Physical cluster:
//
//     M = 10^6 solar masses
//
//     M = 1.98847 × 10^36 kg
//
// The cellular-automata density map distributes this total
// mass through the cluster volume.
//
// QRTLField then calculates:
//
//     rho(x)
//          ↓
//     M_enclosed(r)
//          ↓
//     Phi(r) = -G M_enclosed(r) / r
//          ↓
//     ∇Phi
//          ↓
//     transverse photon bending
//
// ============================================================

final class QRTLExperiment {

    // ========================================================
    // FIELD
    // ========================================================

    let field: QRTLField

    let tracer: QRTLPhotonTracer

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

        // ====================================================
        // TOTAL PHYSICAL MASS
        // ====================================================

        let clusterMassKg: Double

        if mass.isFinite && mass > 0.0 {
            clusterMassKg = mass
        } else {
            clusterMassKg =
                Self.defaultClusterMassKg
        }

        // ====================================================
        // PHYSICAL CLUSTER RADIUS
        // ====================================================

        let clusterRadiusMeters =
            Float(
                max(
                    radius,
                    1.0e-6
                )
            )

        // ====================================================
        // STAR POSITIONS
        // ====================================================
        //
        // These positions define the cellular-automata
        // spatial distribution.
        //
        // They do NOT individually determine the total mass.
        //
        // The density map assigns the complete cluster mass
        // across this distribution.
        //
        // ====================================================

        let starCount = 3000

        var positions:
            [SIMD3<Float>] = []

        positions.reserveCapacity(
            starCount
        )

        // ====================================================
        // SPHERICAL DISTRIBUTION
        // ====================================================

        for _ in 0..<starCount {

            // ------------------------------------------------
            // Azimuth
            // ------------------------------------------------

            let theta =
                Float.random(
                    in:
                        0.0...(2.0 * Float.pi)
                )

            // ------------------------------------------------
            // Uniform cosine of polar angle
            // ------------------------------------------------

            let zDirection =
                Float.random(
                    in:
                        -1.0...1.0
                )

            // ------------------------------------------------
            // XY component
            // ------------------------------------------------

            let radialXY =
                sqrt(
                    max(
                        0.0,
                        1.0 -
                        zDirection *
                        zDirection
                    )
                )

            // ------------------------------------------------
            // Uniform volume distribution
            //
            // r = R * U^(1/3)
            // ------------------------------------------------

            let randomUnit =
                Float.random(
                    in:
                        0.0...1.0
                )

            let radialFraction =
                pow(
                    randomUnit,
                    1.0 / 3.0
                )

            let r =
                clusterRadiusMeters *
                radialFraction

            // ------------------------------------------------
            // Cartesian position
            // ------------------------------------------------

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
        // CREATE CELLULAR-AUTOMATA DENSITY SOURCE
        // ====================================================
        //
        // The entire density distribution is normalized to:
        //
        //     clusterMassKg
        //
        // Therefore the integrated physical mass is:
        //
        //     ∫ rho dV = 10^6 solar masses
        //
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
        // CREATE QRTL FIELD
        // ====================================================

        self.field =
            QRTLField(
                densitySource:
                    densitySource,

                parameters:
                    parameters
            )

        // ====================================================
        // CREATE PHOTON TRACER
        // ====================================================

        self.tracer =
            QRTLPhotonTracer(
                field:
                    self.field
            )
    }

    // ============================================================
    // RUN EXPERIMENT
    // ============================================================

    func run(
        impactParameter:
            Double,

        startDistance:
            Double,

        endDistance:
            Double,

        stepSize:
            Double
    ) -> QRTLExperimentResult {

        // ========================================================
        // SAFE INPUTS
        // ========================================================

        let safeImpactParameter =
            max(
                abs(
                    impactParameter
                ),
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
        // PHOTON START POSITION
        // ========================================================
        //
        // Photon travels in +X.
        //
        // Impact parameter is Y.
        //
        // ========================================================

        let start =
            SIMD3<Double>(
                -safeStartDistance,
                safeImpactParameter,
                0.0
            )

        let totalDistance =
            safeStartDistance +
            safeEndDistance

        // ========================================================
        // TRACE PHOTON THROUGH EINSTEIN/QRTL FIELD
        // ========================================================

        let path =
            tracer.trace(
                start:
                    start,

                direction:
                    SIMD3<Double>(
                        1.0,
                        0.0,
                        0.0
                    ),

                totalDistance:
                    totalDistance,

                stepSize:
                    safeStepSize
            )

        // ========================================================
        // VALIDATE PATH
        // ========================================================

        guard path.count >= 3 else {

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

        // ========================================================
        // INCOMING PHOTON DIRECTION
        // ========================================================

        let incomingVector =
            path[1] -
            path[0]

        let incomingLength =
            simd_length(
                incomingVector
            )

        guard incomingLength > 0.0 else {

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

        let incoming =
            incomingVector /
            incomingLength

        // ========================================================
        // OUTGOING PHOTON DIRECTION
        // ========================================================

        let outgoingVector =
            path[path.count - 1] -
            path[path.count - 2]

        let outgoingLength =
            simd_length(
                outgoingVector
            )

        guard outgoingLength > 0.0 else {

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

        let outgoing =
            outgoingVector /
            outgoingLength

        // ========================================================
        // ANGLE BETWEEN INCOMING AND OUTGOING RAYS
        // ========================================================

        let cosine =
            clamped(
                simd_dot(
                    incoming,
                    outgoing
                ),
                minimum:
                    -1.0,
                maximum:
                    1.0
            )

        let qrtlAngle =
            acos(
                cosine
            )

        // ========================================================
        // EINSTEIN WEAK-FIELD REFERENCE
        // ========================================================
        //
        // alpha_GR = 4GM / (b c²)
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

        let grAngle =
            4.0 *
            G *
            physicalMassKg /
            (
                safeImpactParameter *
                cSquared
            )

        // ========================================================
        // DIFFERENCE
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

            differencePercent = 0.0
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
}
