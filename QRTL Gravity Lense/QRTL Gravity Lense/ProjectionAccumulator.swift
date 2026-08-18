//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/18/26.
//

import Foundation
import SwiftUI

final class ProjectionAccumulator {

    let resolution:
        Int

    let halfExtent:
        Double

    private var buffer:
        [[Float]]

    init(
        resolution:
            Int = 128,

        halfExtent:
            Double
    ) {

        self.resolution =
            resolution

        self.halfExtent =
            halfExtent

        self.buffer =
            [[Float]](
                repeating:
                    [Float](
                        repeating:
                            0,

                        count:
                            resolution
                    ),

                count:
                    resolution
            )
    }

    func reset() {

        for j in 0..<resolution {

            for i in 0..<resolution {

                buffer[j][i] =
                    0
            }
        }
    }

    func addHit(
        y:
            Double,

        z:
            Double,

        weight:
            Float = 1.0
    ) {

        let u =
            (
                y +
                halfExtent
            ) /
            (
                2.0 *
                halfExtent
            )

        let v =
            (
                z +
                halfExtent
            ) /
            (
                2.0 *
                halfExtent
            )

        guard u >= 0,
              u <= 1,
              v >= 0,
              v <= 1
        else {
            return
        }

        let i =
            Int(
                u *
                Double(
                    resolution - 1
                )
            )

        let j =
            Int(
                v *
                Double(
                    resolution - 1
                )
            )

        guard i >= 0,
              i < resolution,
              j >= 0,
              j < resolution
        else {
            return
        }

        buffer[j][i] +=
            weight
    }

    func makeImage() -> UIImage {

        var maxValue:
            Float =
            1.0e-6

        for row in buffer {

            for value in row {

                maxValue =
                    max(
                        maxValue,
                        value
                    )
            }
        }

        UIGraphicsBeginImageContextWithOptions(
            CGSize(
                width:
                    resolution,

                height:
                    resolution
            ),

            false,

            1
        )

        guard let context =
            UIGraphicsGetCurrentContext()
        else {
            return UIImage()
        }

        for j in 0..<resolution {

            for i in 0..<resolution {

                let t =
                    CGFloat(
                        buffer[j][i] /
                        maxValue
                    )

                let alpha =
                    min(
                        1.0,
                        t * 1.8
                    )

                let color =
                    UIColor(
                        red:
                            1,

                        green:
                            0.95,

                        blue:
                            0.7,

                        alpha:
                            alpha
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
}


