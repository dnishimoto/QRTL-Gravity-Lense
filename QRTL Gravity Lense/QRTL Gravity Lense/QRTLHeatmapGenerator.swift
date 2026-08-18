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

    // ============================================================
    // MAKE QRTL LENSING HEATMAP
    //
    // The heatmap now visualizes the same QRTL lensing-strength
    // calculation used by photon tracing.
    //
    // IMPORTANT:
    // The heatmap is a visual diagnostic of the lensing field.
    // It is NOT a separate gravitational-density calculation.
    // ============================================================

    static func makeHeatmapImage(
        field: QRTLField,
        size: Int = 256,
        halfExtent: Double
    ) -> UIImage {

        let resolution =
            max(
                size,
                64
            )

        var samples =
            Array(
                repeating:
                    Array(
                        repeating: 0.0,
                        count: resolution
                    ),
                count: resolution
            )

        var maximum =
            0.0

        // --------------------------------------------------------
        // HEATMAP SAMPLING
        // --------------------------------------------------------

        for j in 0..<resolution {

            for i in 0..<resolution {

                let x =
                    -halfExtent +
                    (Double(i) + 0.5) *
                    (2.0 * halfExtent /
                     Double(resolution))
                
                let y =
                    -halfExtent +
                    (Double(i) + 0.5) *
                    (2.0 * halfExtent /
                     Double(resolution))


                let z =
                    -halfExtent +
                    (Double(j) + 0.5) *
                    (2.0 * halfExtent /
                     Double(resolution))

                
                let position =
                    SIMD3<Float>(
                        0.0,
                        Float(y),
                        Float(z)
                    )

                let photonDirection =
                    SIMD3<Float>(
                        1.0,
                        0.0,
                        0.0
                    )

                let lensingStrength =
                    Double(
                        field.qrtlLensingStrength(
                            at: position,
                            direction: photonDirection
                        )
                    )
                
                let safeValue =
                    lensingStrength.isFinite
                    ? max(lensingStrength, 0.0)
                    : 0.0

                samples[j][i] =
                    safeValue

                maximum =
                    max(
                        maximum,
                        safeValue
                    )
            }
        }

        // --------------------------------------------------------
        // PROTECT AGAINST EMPTY / ZERO FIELD
        // --------------------------------------------------------

        guard maximum.isFinite,
              maximum > 0.0
        else {

            return makeEmptyHeatmap(
                resolution:
                    resolution
            )
        }

        // --------------------------------------------------------
        // CREATE IMAGE
        // --------------------------------------------------------

        UIGraphicsBeginImageContextWithOptions(
            CGSize(
                width:
                    resolution,
                height:
                    resolution
            ),
            true,
            1.0
        )

        guard let context =
                UIGraphicsGetCurrentContext()
        else {
            UIGraphicsEndImageContext()
            return UIImage()
        }

        // --------------------------------------------------------
        // DRAW FIELD
        // --------------------------------------------------------

        for j in 0..<resolution {

            for i in 0..<resolution {

                let raw =
                    samples[j][i]

                var normalized =
                    raw /
                    maximum

                guard normalized.isFinite
                else {
                    normalized = 0.0
                    continue
                }

                normalized =
                    min(
                        max(
                            normalized,
                            0.0
                        ),
                        1.0
                    )

                // ------------------------------------------------
                // LOGARITHMIC CONTRAST
                //
                // QRTL lensing strength can have a very large
                // dynamic range. Linear normalization tends to
                // make almost the entire plane look black.
                //
                // Log compression reveals the surrounding field.
                // ------------------------------------------------

                let contrast =
                    log10(
                        1.0 +
                        99.0 *
                        normalized
                    ) /
                    log10(
                        100.0
                    )

                let t =
                    min(
                        max(
                            contrast,
                            0.0
                        ),
                        1.0
                    )

                let color =
                    colorForHeatmapValue(
                        t
                    )

                context.setFillColor(
                    color.cgColor
                )

                context.fill(
                    CGRect(
                        x:
                            i,
                        y:
                            resolution -
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

        let image =
            UIGraphicsGetImageFromCurrentImageContext()
            ?? UIImage()

        UIGraphicsEndImageContext()

        return image
    }


    // ============================================================
    // HEATMAP COLOR
    // ============================================================

    private static func colorForHeatmapValue(
        _ value: Double
    ) -> UIColor {

        let t =
            min(
                max(
                    value,
                    0.0
                ),
                1.0
            )

        // --------------------------------------------------------
        // VERY WEAK FIELD
        // --------------------------------------------------------

        if t < 0.20 {

            let local =
                t / 0.20

            return UIColor(
                red:
                    0.0,
                green:
                    0.0,
                blue:
                    CGFloat(
                        0.08 +
                        0.45 * local
                    ),
                alpha:
                    1.0
            )
        }

        // --------------------------------------------------------
        // WEAK → MODERATE
        // --------------------------------------------------------

        if t < 0.40 {

            let local =
                (t - 0.20) /
                0.20

            return UIColor(
                red:
                    0.0,
                green:
                    CGFloat(
                        0.15 +
                        0.55 * local
                    ),
                blue:
                    CGFloat(
                        0.55 +
                        0.35 * local
                    ),
                alpha:
                    1.0
            )
        }

        // --------------------------------------------------------
        // MODERATE → STRONG
        // --------------------------------------------------------

        if t < 0.60 {

            let local =
                (t - 0.40) /
                0.20

            return UIColor(
                red:
                    CGFloat(
                        0.05 +
                        0.75 * local
                    ),
                green:
                    CGFloat(
                        0.70 +
                        0.30 * local
                    ),
                blue:
                    CGFloat(
                        0.90 -
                        0.70 * local
                    ),
                alpha:
                    1.0
            )
        }

        // --------------------------------------------------------
        // STRONG → VERY STRONG
        // --------------------------------------------------------

        if t < 0.80 {

            let local =
                (t - 0.60) /
                0.20

            return UIColor(
                red:
                    0.80 +
                    0.20 * CGFloat(local),
                green:
                    1.0 -
                    0.35 * CGFloat(local),
                blue:
                    0.20 -
                    0.20 * CGFloat(local),
                alpha:
                    1.0
            )
        }

        // --------------------------------------------------------
        // EXTREME LENSING
        // --------------------------------------------------------

        let local =
            (t - 0.80) /
            0.20

        return UIColor(
            red:
                1.0,
            green:
                0.65 -
                0.65 * CGFloat(local),
            blue:
                0.0,
            alpha:
                1.0
        )
    }


    // ============================================================
    // EMPTY HEATMAP
    // ============================================================

    private static func makeEmptyHeatmap(
        resolution: Int
    ) -> UIImage {

        UIGraphicsBeginImageContextWithOptions(
            CGSize(
                width:
                    resolution,
                height:
                    resolution
            ),
            true,
            1.0
        )

        guard let context =
                UIGraphicsGetCurrentContext()
        else {
            UIGraphicsEndImageContext()
            return UIImage()
        }

        context.setFillColor(
            UIColor(
                red: 0.0,
                green: 0.0,
                blue: 0.05,
                alpha: 1.0
            ).cgColor
        )

        context.fill(
            CGRect(
                x: 0,
                y: 0,
                width: resolution,
                height: resolution
            )
        )

        let image =
            UIGraphicsGetImageFromCurrentImageContext()
            ?? UIImage()

        UIGraphicsEndImageContext()

        return image
    }
}
