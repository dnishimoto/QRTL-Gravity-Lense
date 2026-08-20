//
//  File.swift
//  QRTL Gravity Lense
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
// EXPERIMENT
// ============================================================

final class QRTLExperiment {

    let field: QRTLField
    let tracer: QRTLPhotonTracer

    init(
        mass: Double,
        radius: Double,
        parameters: QRTLParameters
    ) {

        // ========================================================
        // CREATE STAR POSITIONS
        //
        // This creates the same type of spherical distribution
        // used by the globular-cluster renderer.
        // ========================================================

        let starCount = 3000

        var positions:
            [SIMD3<Float>] = []

        positions.reserveCapacity(starCount)

        let clusterRadius =
            Float(
                max(
                    radius,
                    0.0001
                )
            )

        for _ in 0..<starCount {

            let theta =
                Float.random(
                    in: 0.0...(2.0 * Float.pi)
                )

            let zDirection =
                Float.random(
                    in: -1.0...1.0
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

            // Uniform volume distribution.
            let radialFraction =
                pow(
                    Float.random(
                        in: 0.0...1.0
                    ),
                    1.0 / 3.0
                )

            let r =
                clusterRadius *
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

        // ========================================================
        // CREATE CELLULAR DENSITY MAP
        //
        // The star positions become the mass-density source
        // sampled by QRTLField.
        // ========================================================

        let densitySource =
            GlobularClusterDensityMap(
                positions:
                    positions,
                radius:
                    clusterRadius,
                totalMass:
                    Float(
                        max(
                            mass,
                            0.0
                        )
                    ),
                cellSize:
                    0.20
            )

        // ========================================================
        // CREATE QRTL FIELD
        // ========================================================

        self.field =
            QRTLField(
                densitySource:
                    densitySource,
                parameters:
                    parameters
            )

        // ========================================================
        // CREATE PHOTON TRACER
        // ========================================================

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

        let start =
            SIMD3<Double>(
                -startDistance,
                impactParameter,
                0.0
            )

        let totalDistance =
            startDistance +
            endDistance

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
                    stepSize
            )

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

        let incoming =
            simd_normalize(
                path[1] -
                path[0]
            )

        // ========================================================
        // OUTGOING PHOTON DIRECTION
        // ========================================================

        let outgoing =
            simd_normalize(
                path[path.count - 1] -
                path[path.count - 2]
            )

        // ========================================================
        // ANGLE BETWEEN INCOMING AND OUTGOING
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
        // STANDARD WEAK-FIELD GR DEFLECTION
        //
        // alpha = 4GM / bc²
        // ========================================================
        let mass =
            Double(field.densitySource.totalMass)

        let G =
            Double(PhysicalConstants.G)

        let c =
            Double(PhysicalConstants.c)

        let safeImpactParameter =
            max(
                impactParameter,
                1.0e-12
            )

        let grAngle =
            4.0 *
            G *
            mass /
            (
                safeImpactParameter *
                c *
                c
            )
        // ========================================================
        // DIFFERENCE
        // ========================================================

        let difference =
            grAngle > 0.0
            ? 100.0 *
                (
                    qrtlAngle -
                    grAngle
                ) /
                grAngle
            : 0.0

        // ========================================================
        // RESULT
        // ========================================================

        return QRTLExperimentResult(

            qrtlDeflection:
                qrtlAngle,

            grDeflection:
                grAngle,

            differencePercent:
                difference,

            qrtlDeflectionArcseconds:
                qrtlAngle *
                PhysicalConstants.radiansToArcseconds,

            grDeflectionArcseconds:
                grAngle *
                PhysicalConstants.radiansToArcseconds
        )
    }
}
