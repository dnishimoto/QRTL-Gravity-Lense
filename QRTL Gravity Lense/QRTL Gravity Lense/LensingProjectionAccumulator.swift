//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/16/26.
//

import Foundation
import SwiftUI


import Foundation
import simd

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
        resolution: Int = 64,
        halfExtent: Float = 12.0
    ) {

        self.resolution = max(resolution, 2)
        self.halfExtent = max(
            halfExtent.isFinite ? halfExtent : 12.0,
            0.000001
        )

        self.values = Array(
            repeating: 0.0,
            count: self.resolution * self.resolution
        )
    }
    // ============================================================
    // LEGACY COMPATIBILITY — ADD HIT
    // ============================================================

    func addHit(
        _ hit: LensingProjectionHit,
        strength: Float = 1.0
    ) {
        accumulate(
            hit,
            strength: strength
        )
    }
    // =========================================================
    // CLEAR
    // =========================================================

    func clear() {
        reset()
    }

    // =========================================================
    // RESET
    // =========================================================

    func reset() {

        values = Array(
            repeating: 0.0,
            count: resolution * resolution
        )
    }

    // =========================================================
    // ACCUMULATE SINGLE HIT
    // =========================================================

    func accumulate(
        _ hit: LensingProjectionHit,
        strength: Float = 1.0
    ) {

        // =========================================================
        // SAFE STRENGTH
        // =========================================================

        let safeStrength = max(
            strength.isFinite
                ? strength
                : 0.0,
            0.0
        )

        guard safeStrength > 0.0 else {
            return
        }

        // =========================================================
        // PROJECTION COORDINATES
        //
        // LensingProjectionHit.coordinates is now:
        //
        //     SIMD3<Float>?
        //
        // The projection plane uses X/Y.
        // Z is retained for the physical 3D projection position.
        // =========================================================

        guard let coordinates =
            hit.coordinates
        else {
            return
        }

        // =========================================================
        // FINITE CHECK
        // =========================================================

        guard
            coordinates.x.isFinite,
            coordinates.y.isFinite
        else {
            return
        }

        // =========================================================
        // NORMALIZE
        //
        // Physical projection coordinates:
        //
        //     -halfExtent ... 0 ... +halfExtent
        //
        // Image coordinates:
        //
        //      0.0 ... 0.5 ... 1.0
        // =========================================================

        guard halfExtent > 0.0,
              halfExtent.isFinite
        else {
            return
        }

        let normalizedX =
            (
                coordinates.x / halfExtent
                + 1.0
            ) * 0.5

        let normalizedY =
            (
                coordinates.y / halfExtent
                + 1.0
            ) * 0.5

        // =========================================================
        // VALIDATE NORMALIZED COORDINATES
        // =========================================================

        guard
            normalizedX.isFinite,
            normalizedY.isFinite
        else {
            return
        }

        // =========================================================
        // OUTSIDE PROJECTION PLANE
        // =========================================================

        guard
            normalizedX >= 0.0,
            normalizedX <= 1.0,
            normalizedY >= 0.0,
            normalizedY <= 1.0
        else {
            return
        }

        // =========================================================
        // CONVERT TO PIXELS
        // =========================================================

        let maxPixel =
            Float(resolution - 1)

        let fx =
            normalizedX * maxPixel

        let fy =
            normalizedY * maxPixel

        let x =
            Int(fx.rounded())

        let y =
            Int(fy.rounded())

        // =========================================================
        // PIXEL SAFETY
        // =========================================================

        guard
            x >= 0,
            x < resolution,
            y >= 0,
            y < resolution
        else {
            return
        }

        // =========================================================
        // FLATTEN 2D IMAGE INDEX
        // =========================================================

        let index =
            y * resolution + x

        // =========================================================
        // ACCUMULATE PHOTON STRENGTH
        // =========================================================

        values[index] += safeStrength
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

        // -----------------------------------------------------
        // INTERACTION WEIGHT
        // -----------------------------------------------------

        let interactionWeight =
            1.0 +
            Float(
                max(
                    hit.interactionCount,
                    0
                )
            ) * 0.01

        // -----------------------------------------------------
        // FIELD WEIGHT
        // -----------------------------------------------------

        let fieldWeight =
            1.0 +
            qrtl +
            magnetic +
            magneticPhoton

        // -----------------------------------------------------
        // FINAL WEIGHT
        // -----------------------------------------------------

        let safeBaseStrength =
            max(
                baseStrength.isFinite
                    ? baseStrength
                    : 0.0,
                0.0
            )

        let strength =
            safeBaseStrength *
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
        values.reduce(0.0, +)
    }

    // =========================================================
    // VALUE AT PIXEL
    // =========================================================

    func value(
        x: Int,
        y: Int
    ) -> Float {

        guard
            x >= 0,
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

        guard
            maximum.isFinite,
            maximum > 0.0
        else {
            return 0.0
        }

        return value(
            x: x,
            y: y
        ) / maximum
    }

    // =========================================================
    // NORMALIZED ARRAY
    // =========================================================

    func normalizedValues() -> [Float] {

        let maximum =
            maximumValue

        guard
            maximum.isFinite,
            maximum > 0.0
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

