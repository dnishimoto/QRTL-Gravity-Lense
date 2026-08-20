//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/20/26.
//

import Foundation


struct LensingProjectionHit {

    let point:
        SIMD3<Float>

    let coordinates:
        SIMD3<Float>?

    let sourceCoordinates:
        SIMD3<Float>?

    let direction:
        SIMD3<Float>

    let traveledDistance:
        Float

    let interactionCount:
        Int

    let maximumMagneticField:
        Float

    let maximumQRTLInfluence:
        Float

    let maximumMagneticPhotonInfluence:
        Float

    let sourceID:
        Int

    init(
        point:
            SIMD3<Float>,

        coordinates:
            SIMD3<Float>?,

        sourceCoordinates:
            SIMD3<Float>?,

        direction:
            SIMD3<Float>,

        traveledDistance:
            Float,

        interactionCount:
            Int,

        maximumMagneticField:
            Float,

        maximumQRTLInfluence:
            Float,

        maximumMagneticPhotonInfluence:
            Float,

        sourceID:
            Int
    ) {

        self.point =
            point

        self.coordinates =
            coordinates

        self.sourceCoordinates =
            sourceCoordinates

        self.direction =
            direction

        self.traveledDistance =
            traveledDistance

        self.interactionCount =
            interactionCount

        self.maximumMagneticField =
            maximumMagneticField

        self.maximumQRTLInfluence =
            maximumQRTLInfluence

        self.maximumMagneticPhotonInfluence =
            maximumMagneticPhotonInfluence

        self.sourceID =
            sourceID
    }
}
