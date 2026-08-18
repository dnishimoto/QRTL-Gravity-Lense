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

    let field: QRTLField

    init(field: QRTLField) {
        self.field = field
    }

    // n_G = 1 + γ · |influence| · (boosted by density)
    func gravitationalIndex(at position: SIMD3<Double>) -> Double {
        let p = SIMD3<Float>(Float(position.x), Float(position.y), Float(position.z))
        let density = Double(field.normalizedDensity(at: p))
        let mag = Double(simd_length(field.influence(at: p)))
        guard mag.isFinite else { return 1.0 }
        let index = 1.0 + field.parameters.gammaQ * mag * (0.25 + 0.75 * density)
        return max(index, 1e-12)
    }

    // n_EM = 1 + κ_EM · |EM| · density weight  → core bends more
    func electromagneticIndex(at position: SIMD3<Double>) -> Double {
        let p = SIMD3<Float>(Float(position.x), Float(position.y), Float(position.z))
        let density = Double(field.normalizedDensity(at: p))
        let mag = Double(simd_length(field.electromagneticInfluence(at: p)))
        guard mag.isFinite else { return 1.0 }
        let kappa = field.parameters.photonEMCoupling
        let index = 1.0 + kappa * mag * (0.2 + 0.8 * density)
        return max(index, 1e-12)
    }

    func totalIndex(at position: SIMD3<Double>) -> Double {
        let n = gravitationalIndex(at: position) * electromagneticIndex(at: position)
        return n.isFinite ? max(n, 1e-12) : 1.0
    }

    func totalIndexGradient(at position: SIMD3<Double>) -> SIMD3<Double> {
        let r = simd_length(position)
        guard r.isFinite, r > 1e-6 else { return .zero }

        let step = max(r * 0.002, 0.001)   // scene units — never solarRadius

        let dx = SIMD3(step, 0, 0)
        let dy = SIMD3(0, step, 0)
        let dz = SIMD3(0, 0, step)

        let g = SIMD3(
            (totalIndex(at: position + dx) - totalIndex(at: position - dx)) / (2 * step),
            (totalIndex(at: position + dy) - totalIndex(at: position - dy)) / (2 * step),
            (totalIndex(at: position + dz) - totalIndex(at: position - dz)) / (2 * step)
        )
        guard g.x.isFinite, g.y.isFinite, g.z.isFinite else { return .zero }
        return g
    }

    func trace(
        start: SIMD3<Double>,
        direction: SIMD3<Double>,
        totalDistance: Double,
        stepSize: Double
    ) -> [SIMD3<Double>] {

        var position = start
        var dir = simd_normalize(direction)
        var path: [SIMD3<Double>] = [position]

        let effectiveStep = max(stepSize, field.parameters.minimumStep)
        let nSteps = min(
            max(Int(ceil(totalDistance / effectiveStep)), 1),
            field.parameters.maximumRaySteps
        )
        path.reserveCapacity(nSteps + 1)

        for _ in 0..<nSteps {
            let n = totalIndex(at: position)
            let grad = totalIndexGradient(at: position)
            let transverse = transverseComponent(grad / n, relativeTo: dir)

            var newDir = dir + transverse * effectiveStep
            let mag = simd_length(newDir)
            guard mag.isFinite, mag > 1e-20 else { break }
            dir = newDir / mag

            position += dir * effectiveStep
            guard position.x.isFinite, position.y.isFinite, position.z.isFinite else { break }
            path.append(position)
        }
        return path
    }
}
