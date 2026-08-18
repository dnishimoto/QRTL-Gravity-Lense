//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/18/26.
//

import Foundation
import simd
// ============================================================
// PHOTON TRACE RESULT
//
// Complete diagnostic/result state for one photon.
//
// This structure is shared by:
//     tracePhoton()
//     ContentView
//     makeHit()
//     projection rendering
// ============================================================

struct PhotonTraceResult {

    // =========================================================
    // COMPLETE PHOTON PATH
    // =========================================================

    let positions:
        [SIMD3<Float>]


    // =========================================================
    // STARTING STATE
    // =========================================================

    let origin:
        SIMD3<Float>


    // =========================================================
    // FINAL STATE
    // =========================================================

    let finalPosition:
        SIMD3<Float>

    let finalDirection:
        SIMD3<Float>


    // =========================================================
    // PROJECTION
    // =========================================================

    let hitProjection:
        Bool

    let projectionPosition:
        SIMD3<Float>?

    let projectionCoordinates:
        SIMD2<Float>?


    // =========================================================
    // INTEGRATION
    // =========================================================

    let stepCount:
        Int

    let traveledDistance:
        Float


    // =========================================================
    // QRTL DIAGNOSTICS
    // =========================================================

    let maximumQRTLInfluence:
        Float


    // =========================================================
    // MAGNETIC DIAGNOSTICS
    // =========================================================

    let maximumMagneticField:
        Float

    let maximumMagneticPhotonInfluence:
        Float


    // =========================================================
    // BACKWARD-COMPATIBLE ALIAS
    //
    // Existing code can continue using:
    //
    // trace.projectionPoint
    //
    // while the stored property remains:
    //
    // projectionPosition
    // =========================================================

    var projectionPoint:
        SIMD3<Float>? {

        return projectionPosition
    }


    // =========================================================
    // BACKWARD-COMPATIBLE ALIAS
    //
    // Existing code can continue using:
    //
    // trace.path
    // =========================================================

    var path:
        [SIMD3<Float>] {

        return positions
    }


    // =========================================================
    // BACKWARD-COMPATIBLE ALIAS
    //
    // Existing code can continue using:
    //
    // trace.reachedTarget
    // =========================================================

    var reachedTarget:
        Bool {

        return hitProjection
    }


    // =========================================================
    // INITIALIZER
    // =========================================================

    init(
        positions:
            [SIMD3<Float>],

        origin:
            SIMD3<Float>,

        finalPosition:
            SIMD3<Float>,

        finalDirection:
            SIMD3<Float>,

        hitProjection:
            Bool,

        projectionPosition:
            SIMD3<Float>?,

        projectionCoordinates:
            SIMD2<Float>? = nil,

        stepCount:
            Int,

        traveledDistance:
            Float,

        maximumQRTLInfluence:
            Float,

        maximumMagneticField:
            Float,

        maximumMagneticPhotonInfluence:
            Float
    ) {

        self.positions =
            positions

        self.origin =
            origin

        self.finalPosition =
            finalPosition

        self.finalDirection =
            finalDirection

        self.hitProjection =
            hitProjection

        self.projectionPosition =
            projectionPosition

        self.projectionCoordinates =
            projectionCoordinates

        self.stepCount =
            stepCount

        self.traveledDistance =
            traveledDistance

        self.maximumQRTLInfluence =
            maximumQRTLInfluence

        self.maximumMagneticField =
            maximumMagneticField

        self.maximumMagneticPhotonInfluence =
            maximumMagneticPhotonInfluence
    }
}
