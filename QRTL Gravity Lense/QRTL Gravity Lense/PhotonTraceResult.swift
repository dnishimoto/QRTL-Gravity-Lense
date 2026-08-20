//
//  PhotonTraceResult.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/18/26.
//

import Foundation
import simd

// ============================================================
// PHOTON TRACE RESULT
// ============================================================
//
// Stores the complete result of a QRTL photon integration.
//
// Coordinate convention:
//
//     X = photon propagation direction
//     Y = transverse lensing direction
//     Z = second transverse direction
//
// The tracer performs its numerical integration using
// SIMD3<Double>.  The result is converted to Float for the
// SceneKit / visualization pipeline.
//
// ============================================================

struct PhotonTraceResult {

    let origin: SIMD3<Float>
    let direction: SIMD3<Float>

    let positions: [SIMD3<Float>]

    let finalPosition: SIMD3<Float>
    let finalDirection: SIMD3<Float>

    let hitProjection: Bool

    let projectionPoint: SIMD3<Float>?
    let projectionCoordinates: SIMD2<Float>?

    let stepCount: Int
    let traveledDistance: Float

    let maximumQRTLInfluence: Float
    let maximumMagneticField: Float
    let maximumMagneticPhotonInfluence: Float

    let sourceCoordinates: SIMD3<Float>?
    let interactionCount: Int

    init(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        positions: [SIMD3<Float>],
        finalPosition: SIMD3<Float>,
        finalDirection: SIMD3<Float>,
        hitProjection: Bool,
        projectionPoint: SIMD3<Float>?,
        projectionCoordinates: SIMD2<Float>?,
        stepCount: Int,
        traveledDistance: Float,
        maximumQRTLInfluence: Float,
        maximumMagneticField: Float,
        maximumMagneticPhotonInfluence: Float,
        sourceCoordinates: SIMD3<Float>?,
        interactionCount: Int
    ) {
        self.origin = origin
        self.direction = direction
        self.positions = positions
        self.finalPosition = finalPosition
        self.finalDirection = finalDirection
        self.hitProjection = hitProjection
        self.projectionPoint = projectionPoint
        self.projectionCoordinates = projectionCoordinates
        self.stepCount = stepCount
        self.traveledDistance = traveledDistance
        self.maximumQRTLInfluence = maximumQRTLInfluence
        self.maximumMagneticField = maximumMagneticField
        self.maximumMagneticPhotonInfluence =
            maximumMagneticPhotonInfluence
        self.sourceCoordinates = sourceCoordinates
        self.interactionCount = interactionCount
    }
}
