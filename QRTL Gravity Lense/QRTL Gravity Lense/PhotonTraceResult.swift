//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/18/26.
//

import Foundation
import simd

// =============================================================
// PHOTON TRACE RESULT
// =============================================================
//
// Stores the complete result of one stepwise photon trace.
//
// The photon carries:
//   • its complete path
//   • final position
//   • final direction
//   • projection-plane hit state
//   • total accumulated deflection
//
// Diagnostics record the strongest field influence encountered
// anywhere along the photon path.
//
// =============================================================

// =============================================================
// PHOTON TRACE RESULT
// =============================================================

struct PhotonTraceResult {

    // =========================================================
    // PHOTON INITIAL STATE
    // =========================================================

    let origin: SIMD3<Float>
    let direction: SIMD3<Float>

    // =========================================================
    // PHOTON PATH
    // =========================================================

    let positions: [SIMD3<Float>]

    // Compatibility alias used by rendering code.
    var path: [SIMD3<Float>] {
        positions
    }

    // =========================================================
    // FINAL PHOTON STATE
    // =========================================================

    let finalPosition: SIMD3<Float>
    let finalDirection: SIMD3<Float>

    // =========================================================
    // PROJECTION
    // =========================================================

    let hitProjection: Bool
    let projectionPosition: SIMD3<Float>?

    // =========================================================
    // DIAGNOSTICS
    // =========================================================

    let totalDeflection: Float

    let maximumQRTLInfluence: Float

    let maximumMagneticField: Float

    let maximumMagneticPhotonInfluence: Float

    // =========================================================
    // PROPAGATION
    // =========================================================

    let traveledDistance: Float

    let stepCount: Int

    let terminated: Bool
}
