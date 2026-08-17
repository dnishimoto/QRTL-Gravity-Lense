//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/17/26.
//

import Foundation
import SwiftUI
import simd

final class QRTLPhotonTracer {

    // =========================================================
    // FIELD
    // =========================================================

    let field:
        QRTLField


    // =========================================================
    // INITIALIZER
    // =========================================================

    init(
        field:
            QRTLField
    ) {

        self.field =
            field
    }


    // =========================================================
    // GRAVITATIONAL INDEX
    //
    // Uses the magnitude of the local QRTL influence.
    //
    // The important property for this tracer is that the index
    // changes continuously as the photon moves through the
    // density field.
    // =========================================================

    func gravitationalIndex(
        at position:
            SIMD3<Double>
    ) -> Double {

        let p =
            SIMD3<Float>(
                Float(position.x),
                Float(position.y),
                Float(position.z)
            )


        let influence =
            field.influence(
                at:
                    p
            )


        let magnitude =
            Double(
                simd_length(
                    influence
                )
            )


        guard magnitude.isFinite else {
            return 1.0
        }


        let gamma =
            field.parameters.gammaQ


        let index =
            1.0 +
            gamma *
            magnitude


        return max(
            index,
            1.0e-12
        )
    }


    // =========================================================
    // ELECTROMAGNETIC INDEX
    //
    // Uses the local EM field magnitude.
    //
    // Because electromagneticInfluence() is density dependent,
    // this index automatically becomes:
    //
    // outside cluster  -> approximately 1
    // cluster edge     -> small effect
    // dense interior   -> strong effect
    // center            -> strongest effect
    // exiting cluster  -> decreases again
    // =========================================================

    func electromagneticIndex(
        at position:
            SIMD3<Double>
    ) -> Double {

        let p =
            SIMD3<Float>(
                Float(position.x),
                Float(position.y),
                Float(position.z)
            )


        let electromagneticField =
            field.electromagneticInfluence(
                at:
                    p
            )


        let magnitude =
            Double(
                simd_length(
                    electromagneticField
                )
            )


        guard magnitude.isFinite else {
            return 1.0
        }


        let coupling =
            field.parameters.photonEMCoupling


        let index =
            1.0 +
            coupling *
            magnitude


        return max(
            index,
            1.0e-12
        )
    }


    // =========================================================
    // TOTAL REFRACTIVE INDEX
    //
    // nTotal = nGravity × nEM
    // =========================================================

    func totalIndex(
        at position:
            SIMD3<Double>
    ) -> Double {

        let nG =
            gravitationalIndex(
                at:
                    position
            )


        let nEM =
            electromagneticIndex(
                at:
                    position
            )


        let value =
            nG *
            nEM


        guard value.isFinite else {
            return 1.0
        }


        return max(
            value,
            1.0e-12
        )
    }


    // =========================================================
    // TOTAL INDEX GRADIENT
    //
    // Central finite difference.
    //
    // The finite-difference step is deliberately small relative
    // to the local radius so the photon sees the changing density
    // as it passes through the globular cluster.
    // =========================================================

    func totalIndexGradient(
        at position:
            SIMD3<Double>
    ) -> SIMD3<Double> {

        let radius =
            simd_length(
                position
            )


        guard radius.isFinite,
              radius > 0.000001
        else {

            return .zero
        }


        // -----------------------------------------------------
        // IMPORTANT:
        //
        // Do NOT use 1.0e5 here.
        //
        // The previous:
        //
        // max(r * 0.002, 1.0e5)
        //
        // can create an enormous finite-difference distance.
        //
        // Use a small fraction of the local radius with a
        // reasonable minimum.
        // -----------------------------------------------------

        let step =
            max(
                radius * 0.002,
                0.001
            )


        let dx =
            SIMD3<Double>(
                step,
                0.0,
                0.0
            )


        let dy =
            SIMD3<Double>(
                0.0,
                step,
                0.0
            )


        let dz =
            SIMD3<Double>(
                0.0,
                0.0,
                step
            )


        let xp =
            totalIndex(
                at:
                    position + dx
            )


        let xm =
            totalIndex(
                at:
                    position - dx
            )


        let yp =
            totalIndex(
                at:
                    position + dy
            )


        let ym =
            totalIndex(
                at:
                    position - dy
            )


        let zp =
            totalIndex(
                at:
                    position + dz
            )


        let zm =
            totalIndex(
                at:
                    position - dz
            )


        let gradient =
            SIMD3<Double>(
                (xp - xm) /
                    (2.0 * step),

                (yp - ym) /
                    (2.0 * step),

                (zp - zm) /
                    (2.0 * step)
            )


        guard gradient.x.isFinite,
              gradient.y.isFinite,
              gradient.z.isFinite
        else {

            return .zero
        }


        return gradient
    }


    // =========================================================
    // TRACE
    //
    // Photon is advanced step-by-step through the field.
    //
    // Every step:
    //
    //     local density
    //          ↓
    //     QRTL influence
    //          ↓
    //     EM influence
    //          ↓
    //     total refractive index
    //          ↓
    //     index gradient
    //          ↓
    //     photon direction
    //          ↓
    //     next position
    // =========================================================

    func trace(
        start:
            SIMD3<Double>,

        direction:
            SIMD3<Double>,

        totalDistance:
            Double,

        stepSize:
            Double
    ) -> [SIMD3<Double>] {

        var position =
            start


        var directionVector =
            simd_normalize(
                direction
            )


        var path:
            [SIMD3<Double>] = [
                position
            ]


        // =====================================================
        // STEP SIZE
        // =====================================================

        let minimumStep =
            field.parameters.minimumStepSolarRadii *
            PhysicalConstants.solarRadius


        let effectiveStep =
            max(
                stepSize,
                minimumStep
            )


        // =====================================================
        // NUMBER OF STEPS
        // =====================================================

        let calculatedSteps =
            Int(
                ceil(
                    totalDistance /
                    effectiveStep
                )
            )


        let nSteps =
            min(
                max(
                    calculatedSteps,
                    1
                ),
                field.parameters.maximumRaySteps
            )


        path.reserveCapacity(
            nSteps + 1
        )


        // =====================================================
        // INTEGRATE PHOTON
        // =====================================================

        for _ in 0..<nSteps {

            // -------------------------------------------------
            // CURRENT REFRACTIVE INDEX
            // -------------------------------------------------

            let n =
                max(
                    totalIndex(
                        at:
                            position
                    ),
                    1.0e-12
                )


            // -------------------------------------------------
            // INDEX GRADIENT
            // -------------------------------------------------

            let gradient =
                totalIndexGradient(
                    at:
                        position
                )


            // -------------------------------------------------
            // NORMALIZED PROPAGATION GRADIENT
            // -------------------------------------------------

            let propagationGradient =
                gradient /
                n


            // -------------------------------------------------
            // ONLY THE COMPONENT PERPENDICULAR TO THE PHOTON
            // DIRECTION CAN BEND THE RAY.
            // -------------------------------------------------

            let transverse =
                transverseComponent(
                    propagationGradient,
                    relativeTo:
                        directionVector
                )


            // -------------------------------------------------
            // UPDATE DIRECTION
            // -------------------------------------------------

            var newDirection =
                directionVector +
                transverse *
                effectiveStep


            let magnitude =
                simd_length(
                    newDirection
                )


            guard magnitude.isFinite,
                  magnitude > 1.0e-20
            else {

                break
            }


            newDirection =
                simd_normalize(
                    newDirection
                )


            directionVector =
                newDirection


            // -------------------------------------------------
            // ADVANCE PHOTON
            // -------------------------------------------------

            position +=
                directionVector *
                effectiveStep


            // -------------------------------------------------
            // VALID POSITION
            // -------------------------------------------------

            guard position.x.isFinite,
                  position.y.isFinite,
                  position.z.isFinite
            else {

                break
            }


            // -------------------------------------------------
            // RECORD PHOTON
            // -------------------------------------------------

            path.append(
                position
            )
        }


        return path
    }
}
