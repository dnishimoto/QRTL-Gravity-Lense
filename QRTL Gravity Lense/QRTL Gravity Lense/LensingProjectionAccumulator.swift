//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/16/26.
//

import Foundation
import SwiftUI


// ============================================================
// QRTL LENSING PROJECTION ACCUMULATOR
// ============================================================

final class LensingProjectionAccumulator {

    // =========================================================
    // CONFIGURATION
    // =========================================================

    let resolution: Int
    let halfExtent: Float


    // =========================================================
    // ACCUMULATED PROJECTION VALUES
    // =========================================================

    private(set) var values: [Float]


    // =========================================================
    // INITIALIZER
    // =========================================================

    init(
        resolution: Int = 256,
        halfExtent: Float = 12.0
    ) {

        self.resolution =
            max(resolution, 2)

        self.halfExtent =
            max(halfExtent, 0.000001)

        self.values =
            Array(
                repeating: 0.0,
                count:
                    self.resolution *
                    self.resolution
            )
    }

    func clear() {
        reset()
    }
    // =========================================================
    // RESET
    // =========================================================

    func reset() {

        values =
            Array(
                repeating: 0.0,
                count:
                    resolution *
                    resolution
            )
    }


    // =========================================================
    // ACCUMULATE SINGLE HIT
    // =========================================================

    func accumulate(
        _ hit: LensingProjectionHit,
        strength: Float = 1.0
    ) {

        let safeStrength =
            max(
                strength.isFinite ? strength : 0.0,
                0.0
            )

        guard safeStrength > 0.0
        else {
            return
        }


        // -----------------------------------------------------
        // PROJECTION COORDINATES
        //
        // Coordinates are centered on zero:
        //
        // -halfExtent ... 0 ... +halfExtent
        // -----------------------------------------------------

        let normalizedX =
            (
                hit.coordinates.x /
                halfExtent
                + 1.0
            ) * 0.5

        let normalizedY =
            (
                hit.coordinates.y /
                halfExtent
                + 1.0
            ) * 0.5


        // -----------------------------------------------------
        // VALIDATE
        // -----------------------------------------------------

        guard normalizedX.isFinite,
              normalizedY.isFinite
        else {
            return
        }


        // -----------------------------------------------------
        // OUTSIDE PROJECTION PLANE
        // -----------------------------------------------------

        guard normalizedX >= 0.0,
              normalizedX <= 1.0,
              normalizedY >= 0.0,
              normalizedY <= 1.0
        else {
            return
        }


        // -----------------------------------------------------
        // CONVERT TO PIXELS
        // -----------------------------------------------------

        let fx =
            normalizedX *
            Float(resolution - 1)

        let fy =
            normalizedY *
            Float(resolution - 1)

        let x =
            Int(
                fx.rounded()
            )

        let y =
            Int(
                fy.rounded()
            )


        // -----------------------------------------------------
        // SAFETY CHECK
        // -----------------------------------------------------

        guard x >= 0,
              x < resolution,
              y >= 0,
              y < resolution
        else {
            return
        }


        // -----------------------------------------------------
        // FLATTEN 2D INDEX
        // -----------------------------------------------------

        let index =
            y * resolution + x


        // -----------------------------------------------------
        // ACCUMULATE
        // -----------------------------------------------------

        values[index] +=
            safeStrength
    }


    // =========================================================
    // ACCUMULATE COMPLETE RESULT
    // =========================================================

    func accumulate(
        _ result: LensingProjectionResult,
        strength: Float = 1.0
    ) {

        for hit in result.validHits {

            accumulate(
                hit,
                strength: strength
            )
        }
    }


    // =========================================================
    // ACCUMULATE WEIGHTED HIT
    // =========================================================

    func accumulateWeighted(
        _ hit: LensingProjectionHit,
        baseStrength: Float = 1.0
    ) {

        let qrtl =
            max(
                hit.maximumQRTLInfluence.isFinite
                    ? hit.maximumQRTLInfluence
                    : 0.0,
                0.0
            )

        let magnetic =
            max(
                hit.maximumMagneticField.isFinite
                    ? hit.maximumMagneticField
                    : 0.0,
                0.0
            )

        let magneticPhoton =
            max(
                hit.maximumMagneticPhotonInfluence.isFinite
                    ? hit.maximumMagneticPhotonInfluence
                    : 0.0,
                0.0
            )


        let interactionWeight =
            1.0 +
            Float(
                max(
                    hit.interactionCount,
                    0
                )
            ) *
            0.01


        let fieldWeight =
            1.0 +
            qrtl +
            magnetic +
            magneticPhoton


        let strength =
            max(
                baseStrength,
                0.0
            ) *
            interactionWeight *
            fieldWeight


        accumulate(
            hit,
            strength: strength
        )
    }


    // =========================================================
    // REBUILD
    // =========================================================

    func rebuild(
        from result: LensingProjectionResult,
        strength: Float = 1.0
    ) {

        reset()

        accumulate(
            result,
            strength: strength
        )
    }


    // =========================================================
    // MAXIMUM VALUE
    // =========================================================

    var maximumValue: Float {

        values.max() ?? 0.0
    }


    // =========================================================
    // TOTAL VALUE
    // =========================================================

    var totalValue: Float {

        values.reduce(
            0.0,
            +
        )
    }


    // =========================================================
    // VALUE AT PIXEL
    // =========================================================

    func value(
        x: Int,
        y: Int
    ) -> Float {

        guard x >= 0,
              x < resolution,
              y >= 0,
              y < resolution
        else {
            return 0.0
        }

        let index =
            y * resolution + x

        return values[index]
    }


    // =========================================================
    // NORMALIZED VALUE
    // =========================================================

    func normalizedValue(
        x: Int,
        y: Int
    ) -> Float {

        let maximum =
            maximumValue

        guard maximum > 0.0
        else {
            return 0.0
        }

        return
            value(
                x: x,
                y: y
            ) /
            maximum
    }


    // =========================================================
    // NORMALIZED ARRAY
    // =========================================================

    func normalizedValues() -> [Float] {

        let maximum =
            maximumValue

        guard maximum > 0.0
        else {
            return Array(
                repeating: 0.0,
                count: values.count
            )
        }

        return values.map {
            $0 / maximum
        }
    }
}


// =============================================================
// LENSING PROJECTION HIT
// =============================================================

struct LensingProjectionHit {

    // =========================================================
    // 3D PROJECTION POSITION
    // =========================================================

    let point:
        SIMD3<Float>


    // =========================================================
    // 2D PROJECTION COORDINATES
    //
    // These are the coordinates actually accumulated into
    // the projection image.
    // =========================================================

    let coordinates:
        SIMD2<Float>


    // =========================================================
    // ORIGINAL SOURCE COORDINATES
    // =========================================================

    let sourceCoordinates:
        SIMD2<Float>


    // =========================================================
    // FINAL PHOTON DIRECTION
    // =========================================================

    let direction:
        SIMD3<Float>


    // =========================================================
    // DIAGNOSTICS
    // =========================================================

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


    // =========================================================
    // SOURCE IDENTIFIER
    // =========================================================

    let sourceID:
        Int
}
