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

    // ========================================================
    // CONFIGURATION
    // ========================================================

    let resolution: Int

    let halfExtent: Float


    // ========================================================
    // ACCUMULATED PROJECTION VALUES
    // ========================================================

    private(set) var values: [Float]


    // ========================================================
    // INITIALIZER
    // ========================================================

    init(
        resolution: Int = 256,
        halfExtent: Float = 12.0
    ) {

        self.resolution =
            max(
                resolution,
                2
            )

        self.halfExtent =
            max(
                halfExtent,
                0.000001
            )

        self.values =
            Array(
                repeating: 0.0,
                count:
                    self.resolution *
                    self.resolution
            )
    }


    // ========================================================
    // RESET
    // ========================================================

    func reset() {

        values =
            Array(
                repeating: 0.0,
                count:
                    resolution *
                    resolution
            )
    }


    func accumulate(
        _ hit: LensingProjectionHit,
        strength: Float = 1.0
    ) {

        // --------------------------------------------------------
        // CONVERT PROJECTION COORDINATES TO NORMALIZED SPACE
        // --------------------------------------------------------
        //
        // coordinates are expected to be centered around zero:
        //
        //      -halfExtent ... 0 ... +halfExtent
        //
        // Convert that range to:
        //
        //       0 ... 1
        //
        // --------------------------------------------------------

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


        // --------------------------------------------------------
        // REJECT HITS OUTSIDE THE PROJECTION PLANE
        // --------------------------------------------------------

        guard
            normalizedX >= 0.0,
            normalizedX <= 1.0,
            normalizedY >= 0.0,
            normalizedY <= 1.0
        else {
            return
        }


        // --------------------------------------------------------
        // CONVERT TO PIXEL COORDINATES
        // --------------------------------------------------------

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


        // --------------------------------------------------------
        // SAFETY CHECK
        // --------------------------------------------------------

        guard
            x >= 0,
            x < resolution,
            y >= 0,
            y < resolution
        else {
            return
        }


        // --------------------------------------------------------
        // FLATTEN 2D PIXEL COORDINATES
        // INTO THE 1D VALUE ARRAY
        // --------------------------------------------------------

        let index =
            y * resolution + x


        // --------------------------------------------------------
        // ACCUMULATE PHOTON CONTRIBUTION
        // --------------------------------------------------------

        values[index] +=
            max(
                strength,
                0.0
            )
    }


    // ============================================================
    // ACCUMULATE COMPLETE LENSING RESULT
    // ============================================================

    func accumulate(
        _ result: LensingProjectionResult,
        strength: Float = 1.0
    ) {

        // --------------------------------------------------------
        // `LensingProjectionResult` contains:
        //
        //     hits
        //
        // and exposes:
        //
        //     validHits
        //
        // It does NOT contain `projectionHits`.
        // --------------------------------------------------------

        for hit in result.validHits {

            accumulate(
                hit,
                strength: strength
            )
        }
    }


    // ========================================================
    // MAXIMUM VALUE
    // ========================================================

    var maximumValue: Float {

        values.max() ?? 0.0
    }


    // ========================================================
    // TOTAL ACCUMULATED VALUE
    // ========================================================

    var totalValue: Float {

        values.reduce(
            0.0,
            +
        )
    }


    // ========================================================
    // NORMALIZED VALUE
    // ========================================================

    func normalizedValue(
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
            y *
            resolution +
            x

        let maximum =
            maximumValue

        guard maximum > 0.0 else {
            return 0.0
        }

        return
            values[index] /
            maximum
    }


    // ========================================================
    // VALUE AT INDEX
    // ========================================================

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

        return values[
            y *
            resolution +
            x
        ]
    }


    // ========================================================
    // NORMALIZED VALUE ARRAY
    // ========================================================

    func normalizedValues() -> [Float] {

        let maximum =
            maximumValue

        guard maximum > 0.0 else {

            return Array(
                repeating: 0.0,
                count: values.count
            )
        }

        return values.map {
            $0 / maximum
        }
    }


    // ========================================================
    // ADDITIONAL PHOTON HIT WEIGHTING
    // ========================================================
    //
    // This version optionally weights a hit according to
    // its field interaction strength.
    //
    // ========================================================

    func accumulateWeighted(
        _ hit: LensingProjectionHit,
        baseStrength: Float = 1.0
    ) {

        let qrtl =
            max(
                hit.maximumQRTLInfluence,
                0.0
            )

        let magnetic =
            max(
                hit.maximumMagneticField,
                0.0
            )

        let magneticPhoton =
            max(
                hit.maximumMagneticPhotonInfluence,
                0.0
            )

        let interactionWeight =
            1.0 +
            Float(
                hit.interactionCount
            ) *
            0.01

        let fieldWeight =
            1.0 +
            qrtl +
            magnetic +
            magneticPhoton

        let strength =
            baseStrength *
            interactionWeight *
            fieldWeight

        accumulate(
            hit,
            strength:
                strength
        )
    }


    // ========================================================
    // CLEAR AND REBUILD
    // ========================================================

    func rebuild(
        from result: LensingProjectionResult,
        strength: Float = 1.0
    ) {

        reset()

        accumulate(
            result,
            strength:
                strength
        )
    }
}
// =============================================================
// LENSING PROJECTION HIT
// =============================================================

struct LensingProjectionHit {

    // =========================================================
    // 3D PROJECTION-PLANE INTERSECTION
    // =========================================================

    /// Exact 3D world-space position where the photon
    /// intersects the projection plane.
    let point: SIMD3<Float>


    // =========================================================
    // 2D PROJECTION COORDINATES
    // =========================================================

    /// Coordinates of the photon on the projection plane.
    ///
    /// x = plane horizontal coordinate
    /// y = plane vertical coordinate
    let coordinates: SIMD2<Float>


    // =========================================================
    // PHOTON DIRECTION
    // =========================================================

    /// Photon direction when it reaches the projection plane.
    let direction: SIMD3<Float>


    // =========================================================
    // PROPAGATION INFORMATION
    // =========================================================

    /// Total distance traveled by the photon.
    let traveledDistance: Float

    /// Number of field interactions encountered.
    let interactionCount: Int


    // =========================================================
    // FIELD INFORMATION
    // =========================================================

    /// Maximum magnetic-field magnitude encountered
    /// during the photon trace.
    let maximumMagneticField: Float

    /// Maximum QRTL-field influence encountered
    /// during the photon trace.
    let maximumQRTLInfluence: Float

    /// Maximum magnetic-photon influence encountered
    /// during the photon trace.
    let maximumMagneticPhotonInfluence: Float


    // =========================================================
    // SOURCE GALAXY
    // =========================================================

    /// Identifies which source galaxy emitted the photon.
    ///
    /// 0 = Source Galaxy A
    /// 1 = Source Galaxy B
    let sourceID: Int


    // =========================================================
    // INITIALIZER
    // =========================================================

    init(
        point: SIMD3<Float>,
        coordinates: SIMD2<Float>,
        direction: SIMD3<Float>,
        traveledDistance: Float,
        interactionCount: Int,
        maximumMagneticField: Float,
        maximumQRTLInfluence: Float,
        maximumMagneticPhotonInfluence: Float,
        sourceID: Int = 0
    ) {

        self.point =
            point

        self.coordinates =
            coordinates

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
