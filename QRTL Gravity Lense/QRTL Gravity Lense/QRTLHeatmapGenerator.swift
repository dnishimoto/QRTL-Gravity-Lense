//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/17/26.
//

import Foundation
import SwiftUI
import simd


import UIKit
import simd

final class QRTLHeatmapGenerator {

    static func makeHeatmapImage(
        field: QRTLField,
        size: Int = 128,
        halfExtent: Double
    ) -> UIImage {

        let res = max(size, 32)
        var samples = Array(repeating: Array(repeating: 0.0, count: res), count: res)
        var maxValue = 1e-30

        for j in 0..<res {
            for i in 0..<res {
                let x = -halfExtent + (Double(i) + 0.5) * (2 * halfExtent / Double(res))
                let z = -halfExtent + (Double(j) + 0.5) * (2 * halfExtent / Double(res))
                let pos = SIMD3<Float>(Float(x), 0, Float(z))

                let density = Double(field.normalizedDensity(at: pos))
                let qrtl = Double(simd_length(field.influence(at: pos)))
                let em = Double(simd_length(field.electromagneticInfluence(at: pos)))

                let value = density * (1.0 + qrtl + em)
                samples[j][i] = value
                maxValue = max(maxValue, value)
            }
        }
        if maxValue < 1e-20 { maxValue = 1.0 }

        UIGraphicsBeginImageContextWithOptions(CGSize(width: res, height: res), true, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return UIImage() }

        for j in 0..<res {
            for i in 0..<res {
                var t = CGFloat(samples[j][i] / maxValue)
                t = min(max(t, 0), 1)
                t = max(t, 0.06)   // never pure black

                let color: UIColor
                if t < 0.25 {
                    color = UIColor(red: 0, green: 0, blue: t * 4, alpha: 1)
                } else if t < 0.5 {
                    color = UIColor(red: 0, green: (t - 0.25) * 4, blue: 1, alpha: 1)
                } else if t < 0.75 {
                    color = UIColor(red: (t - 0.5) * 4, green: 1, blue: 1 - (t - 0.5) * 4, alpha: 1)
                } else {
                    color = UIColor(red: 1, green: 1, blue: max(0, 1 - (t - 0.75) * 4), alpha: 1)
                }
                ctx.setFillColor(color.cgColor)
                ctx.fill(CGRect(x: i, y: res - 1 - j, width: 1, height: 1))
            }
        }

        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }
}
