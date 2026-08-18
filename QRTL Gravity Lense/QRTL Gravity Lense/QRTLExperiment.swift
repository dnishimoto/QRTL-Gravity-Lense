//
//  File.swift
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

    let field:
        QRTLField

    let tracer:
        QRTLPhotonTracer

    init(
        mass:
            Double,

        radius:
            Double,

        parameters:
            QRTLParameters
    ) {

        let model =
            GaussianMassModel(
                totalMass:
                    mass,

                characteristicRadius:
                    radius
            )

        self.field =
            QRTLField(
                massModel:
                    model,

                parameters:
                    parameters
            )

        self.tracer =
            QRTLPhotonTracer(
                field:
                    self.field
            )
    }

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
                0
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
                        1,
                        0,
                        0
                    ),

                totalDistance:
                    totalDistance,

                stepSize:
                    stepSize
            )

        guard path.count >= 3 else {

            return QRTLExperimentResult(
                qrtlDeflection:
                    0,

                grDeflection:
                    0,

                differencePercent:
                    0,

                qrtlDeflectionArcseconds:
                    0,

                grDeflectionArcseconds:
                    0
            )
        }

        let incoming =
            simd_normalize(
                path[1] -
                path[0]
            )

        let outgoing =
            simd_normalize(
                path[path.count - 1] -
                path[path.count - 2]
            )

        let cosine =
            clamped(
                simd_dot(
                    incoming,
                    outgoing
                ),

                minimum:
                    -1,

                maximum:
                    1
            )

        let qrtlAngle =
            acos(
                cosine
            )

        // --------------------------------------------------------
        // Standard weak-field GR point-mass deflection.
        //
        // alpha = 4GM / bc²
        // --------------------------------------------------------

        let grAngle =
            4.0 *
            PhysicalConstants.G *
            field.massModel.totalMass /
            (
                impactParameter *
                PhysicalConstants.c *
                PhysicalConstants.c
            )

        let difference =
            grAngle > 0
            ? 100.0 *
                (
                    qrtlAngle -
                    grAngle
                ) /
                grAngle
            : 0

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

