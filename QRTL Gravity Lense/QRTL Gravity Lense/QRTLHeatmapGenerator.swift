//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/17/26.
//

import Foundation
import SwiftUI
import simd


final class QRTLHeatmapGenerator {

    // =========================================================
    // MAKE HEATMAP
    // =========================================================

    static func makeHeatmapImage(
        field:
            QRTLField,

        size:
            Int = 128,

        halfExtent:
            Double
    ) -> UIImage {

        // -----------------------------------------------------
        // CREATE IMAGE CONTEXT
        // -----------------------------------------------------

        UIGraphicsBeginImageContextWithOptions(
            CGSize(
                width:
                    size,

                height:
                    size
            ),

            true,

            1.0
        )


        guard let context =
            UIGraphicsGetCurrentContext()
        else {

            return UIImage()
        }


        // =====================================================
        // SAMPLE FIELD
        // =====================================================

        var maxValue:
            Double = 1.0e-30


        var samples =
            [[Double]](
                repeating:
                    [Double](
                        repeating:
                            0.0,

                        count:
                            size
                    ),

                count:
                    size
            )


        // =====================================================
        // SAMPLE X-Z PLANE
        //
        // Y = 0
        //
        // This produces a top-down slice through the center
        // of the globular cluster.
        // =====================================================

        for j in 0..<size {

            for i in 0..<size {

                let x =
                    -halfExtent +
                    (
                        Double(i) +
                        0.5
                    ) *
                    (
                        2.0 *
                        halfExtent /
                        Double(size)
                    )


                let z =
                    -halfExtent +
                    (
                        Double(j) +
                        0.5
                    ) *
                    (
                        2.0 *
                        halfExtent /
                        Double(size)
                    )


                let position =
                    SIMD3<Float>(
                        Float(x),
                        0.0,
                        Float(z)
                    )


                // =================================================
                // LOCAL DENSITY
                // =================================================

                let density =
                    Double(
                        field.normalizedDensity(
                            at:
                                position
                        )
                    )


                // =================================================
                // LOCAL QRTL INFLUENCE
                // =================================================

                let qrtlVector =
                    field.influence(
                        at:
                            position
                    )


                let qrtlMagnitude =
                    Double(
                        simd_length(
                            qrtlVector
                        )
                    )


                // =================================================
                // LOCAL EM INFLUENCE
                // =================================================

                let electromagneticVector =
                    field.electromagneticInfluence(
                        at:
                            position
                    )


                let electromagneticMagnitude =
                    Double(
                        simd_length(
                            electromagneticVector
                        )
                    )


                // =================================================
                // COMBINED HEATMAP VALUE
                //
                // Density is included so that the heatmap
                // directly follows the same cluster density
                // experienced by the photon.
                // =================================================

                let value =
                    density *
                    (
                        1.0 +
                        qrtlMagnitude +
                        electromagneticMagnitude
                    )


                samples[j][i] =
                    value


                maxValue =
                    max(
                        maxValue,
                        value
                    )
            }
        }


        // =====================================================
        // RENDER HEATMAP
        // =====================================================

        for j in 0..<size {

            for i in 0..<size {

                let normalized =
                    samples[j][i] /
                    maxValue


                let t =
                    CGFloat(
                        min(
                            max(
                                normalized,
                                0.0
                            ),
                            1.0
                        )
                    )


                // =================================================
                // HEATMAP COLOR
                //
                // 0.00 → blue
                // 0.25 → cyan
                // 0.50 → green
                // 0.75 → yellow
                // 1.00 → white
                // =================================================

                let color:
                    UIColor


                if t < 0.25 {

                    color =
                        UIColor(
                            red:
                                0.0,

                            green:
                                0.0,

                            blue:
                                t * 4.0,

                            alpha:
                                1.0
                        )


                } else if t < 0.5 {

                    color =
                        UIColor(
                            red:
                                0.0,

                            green:
                                (t - 0.25) * 4.0,

                            blue:
                                1.0,

                            alpha:
                                1.0
                        )


                } else if t < 0.75 {

                    color =
                        UIColor(
                            red:
                                (t - 0.5) * 4.0,

                            green:
                                1.0,

                            blue:
                                1.0 -
                                (t - 0.5) * 4.0,

                            alpha:
                                1.0
                        )


                } else {

                    color =
                        UIColor(
                            red:
                                1.0,

                            green:
                                1.0,

                            blue:
                                max(
                                    0.0,

                                    1.0 -
                                    (t - 0.75) * 4.0
                                ),

                            alpha:
                                1.0
                        )
                }


                // =================================================
                // DRAW PIXEL
                // =================================================

                context.setFillColor(
                    color.cgColor
                )


                context.fill(
                    CGRect(
                        x:
                            i,

                        y:
                            size -
                            1 -
                            j,

                        width:
                            1,

                        height:
                            1
                    )
                )
            }
        }


        // =====================================================
        // CREATE IMAGE
        // =====================================================

        let image =
            UIGraphicsGetImageFromCurrentImageContext()
            ?? UIImage()


        UIGraphicsEndImageContext()


        return image
    }
}

