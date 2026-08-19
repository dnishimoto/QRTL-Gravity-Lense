//
//  QRTLPhotonTracer.swift
//  QRTL Gravity Lense
//
//  Photon propagation through the QRTL gravitational surface.
//
//  Primary mechanism:
//      QRTLGravitySurface / QRTL gravitational field
//
//  Secondary mechanism:
//      electromagnetic optical refraction
//
//  The photon is propagated step-by-step through the field.
//  At every step the gravitational curvature perpendicular
//  to the current photon direction changes the direction.
//  The photon is then advanced along that new direction.
//

import Foundation
import SwiftUI
import simd

final class QRTLPhotonTracer {

    let field: QRTLField

    init(field: QRTLField) {
        self.field = field
    }

    // ============================================================
    // MARK: - QRTL GRAVITY ACCELERATION
    // ============================================================

    private func qrtlGravityAcceleration(
        at position: SIMD3<Double>,
        direction: SIMD3<Double>
    ) -> SIMD3<Double> {

        let p = SIMD3<Float>(
            Float(position.x),
            Float(position.y),
            Float(position.z)
        )

        let d = SIMD3<Float>(
            Float(direction.x),
            Float(direction.y),
            Float(direction.z)
        )

        let acceleration =
            field.qrtlLensingAcceleration(
                at: p,
                direction: d
            )

        let result = SIMD3<Double>(
            Double(acceleration.x),
            Double(acceleration.y),
            Double(acceleration.z)
        )

        guard
            result.x.isFinite,
            result.y.isFinite,
            result.z.isFinite
        else {
            return .zero
        }

        return result
    }

    // ============================================================
    // MARK: - QRTL GRAVITY SURFACE
    // ============================================================
    //
    // This represents the same scalar surface used by the
    // visualization:
    //
    //      surface =
    //          density contribution
    //          +
    //          Bolgarino-flow contribution
    //
    // The photon responds to the LOCAL GRADIENT of that surface.
    //
    // This is NOT treated as a second gravitational acceleration.
    // It is a geometric curvature correction.
    //
    // ============================================================

    private func qrtlGravitySurfaceValue(
        at p: SIMD3<Float>
    ) -> Float {

        let density =
            field.normalizedDensity(
                at: p
            )

        let flow =
            field.bolgarinoFlux(
                at: p
            )

        let flowMagnitude =
            simd_length(flow)

        guard
            density.isFinite,
            flowMagnitude.isFinite
        else {
            return 0.0
        }

        let normalizedFlow =
            flowMagnitude > 0.0
            ? min(
                flowMagnitude /
                (flowMagnitude + 1.0),
                1.0
            )
            : 0.0

        let value =
            0.65 * density
            +
            0.35 * Float(normalizedFlow)

        return value.isFinite
            ? value
            : 0.0
    }

    // ============================================================
    // MARK: - QRTL GRAVITY SURFACE GRADIENT
    // ============================================================

    private func qrtlGravitySurfaceGradient(
        at position: SIMD3<Double>
    ) -> SIMD3<Double> {

        let p = SIMD3<Float>(
            Float(position.x),
            Float(position.y),
            Float(position.z)
        )

        let radius =
            max(
                simd_length(p),
                0.001
            )

        let h =
            max(
                radius * 0.002,
                0.001
            )

        let dx =
            SIMD3<Float>(
                h,
                0,
                0
            )

        let dy =
            SIMD3<Float>(
                0,
                h,
                0
            )

        let dz =
            SIMD3<Float>(
                0,
                0,
                h
            )

        let gx =
            (
                qrtlGravitySurfaceValue(
                    at: p + dx
                )
                -
                qrtlGravitySurfaceValue(
                    at: p - dx
                )
            )
            /
            (2.0 * h)

        let gy =
            (
                qrtlGravitySurfaceValue(
                    at: p + dy
                )
                -
                qrtlGravitySurfaceValue(
                    at: p - dy
                )
            )
            /
            (2.0 * h)

        let gz =
            (
                qrtlGravitySurfaceValue(
                    at: p + dz
                )
                -
                qrtlGravitySurfaceValue(
                    at: p - dz
                )
            )
            /
            (2.0 * h)

        let gradient =
            SIMD3<Double>(
                Double(gx),
                Double(gy),
                Double(gz)
            )

        guard
            gradient.x.isFinite,
            gradient.y.isFinite,
            gradient.z.isFinite
        else {
            return .zero
        }

        return gradient
    }

    // ============================================================
    // MARK: - GRAVITY SURFACE CURVATURE
    // ============================================================
    //
    // Only the component perpendicular to the photon direction
    // changes the photon direction.
    //
    // ============================================================

    private func qrtlGravitySurfaceCurvature(
        at position: SIMD3<Double>,
        direction: SIMD3<Double>
    ) -> SIMD3<Double> {

        let gradient =
            qrtlGravitySurfaceGradient(
                at: position
            )

        return transverseComponent(
            gradient,
            relativeTo: direction
        )
    }

    // ============================================================
    // MARK: - ELECTROMAGNETIC INDEX
    // ============================================================

    private func electromagneticIndex(
        at position: SIMD3<Double>
    ) -> Double {

        let p = SIMD3<Float>(
            Float(position.x),
            Float(position.y),
            Float(position.z)
        )

        let density =
            Double(
                field.normalizedDensity(
                    at: p
                )
            )

        let magneticInfluence =
            field.electromagneticInfluence(
                at: p
            )

        let magneticMagnitude =
            Double(
                simd_length(
                    magneticInfluence
                )
            )

        guard
            density.isFinite,
            magneticMagnitude.isFinite
        else {
            return 1.0
        }

        let coupling =
            Double(
                field.parameters.photonEMCoupling
            )

        let index =
            1.0
            +
            coupling
            *
            magneticMagnitude
            *
            (0.2 + 0.8 * density)

        guard index.isFinite else {
            return 1.0
        }

        return max(
            index,
            1.0e-12
        )
    }

    // ============================================================
    // MARK: - ELECTROMAGNETIC INDEX GRADIENT
    // ============================================================

    private func electromagneticIndexGradient(
        at position: SIMD3<Double>
    ) -> SIMD3<Double> {

        let radius =
            simd_length(position)

        guard
            radius.isFinite,
            radius > 1.0e-6
        else {
            return .zero
        }

        let h =
            max(
                radius * 0.002,
                0.001
            )

        let dx =
            SIMD3<Double>(
                h,
                0,
                0
            )

        let dy =
            SIMD3<Double>(
                0,
                h,
                0
            )

        let dz =
            SIMD3<Double>(
                0,
                0,
                h
            )

        let gx =
            (
                electromagneticIndex(
                    at: position + dx
                )
                -
                electromagneticIndex(
                    at: position - dx
                )
            )
            /
            (2.0 * h)

        let gy =
            (
                electromagneticIndex(
                    at: position + dy
                )
                -
                electromagneticIndex(
                    at: position - dy
                )
            )
            /
            (2.0 * h)

        let gz =
            (
                electromagneticIndex(
                    at: position + dz
                )
                -
                electromagneticIndex(
                    at: position - dz
                )
            )
            /
            (2.0 * h)

        let gradient =
            SIMD3<Double>(
                gx,
                gy,
                gz
            )

        guard
            gradient.x.isFinite,
            gradient.y.isFinite,
            gradient.z.isFinite
        else {
            return .zero
        }

        return gradient
    }

    // ============================================================
    // MARK: - ELECTROMAGNETIC FORCE
    // ============================================================

    private func electromagneticForce(
        at position: SIMD3<Double>,
        direction: SIMD3<Double>
    ) -> SIMD3<Double> {

        let gradient =
            electromagneticIndexGradient(
                at: position
            )

        let index =
            electromagneticIndex(
                at: position
            )

        guard
            index.isFinite,
            index > 1.0e-12
        else {
            return .zero
        }

        let opticalForce =
            gradient / index

        return transverseComponent(
            opticalForce,
            relativeTo: direction
        )
    }

    // ============================================================
    // MARK: - PHOTON TRACE
    // ============================================================

    func trace(
        start: SIMD3<Double>,
        direction: SIMD3<Double>,
        totalDistance: Double,
        stepSize: Double
    ) -> [SIMD3<Double>] {

        var position =
            start

        var dir =
            simd_normalize(
                direction
            )

        guard
            dir.x.isFinite,
            dir.y.isFinite,
            dir.z.isFinite,
            simd_length(dir) > 1.0e-12
        else {
            return [start]
        }

        var path:
            [SIMD3<Double>] =
            [position]

        let effectiveStep =
            max(
                stepSize,
                Double(
                    field.parameters.minimumStep
                )
            )

        let requestedSteps =
            Int(
                ceil(
                    totalDistance /
                    effectiveStep
                )
            )

        let nSteps =
            min(
                max(
                    requestedSteps,
                    1
                ),
                field.parameters.maximumRaySteps
            )

        path.reserveCapacity(
            nSteps + 1
        )

        // ========================================================
        // COUPLINGS
        // ========================================================

        let gravityCoupling =
            max(
                Double(
                    field.parameters.qrtlFieldCoupling
                ),
                0.0
            )

        let surfaceCoupling =
            max(
                Double(
                    field.parameters.qrtlFieldCoupling
                ),
                0.0
            )

        let electromagneticCoupling =
            max(
                Double(
                    field.parameters.photonEMCoupling
                ),
                0.0
            )

        // ========================================================
        // PHOTON PROPAGATION
        // ========================================================

        for _ in 0..<nSteps {

            // ----------------------------------------------------
            // 1. QRTL GRAVITY
            //
            // This is the PRIMARY curvature mechanism.
            // ----------------------------------------------------

            let gravity =
                qrtlGravityAcceleration(
                    at: position,
                    direction: dir
                )

            // ----------------------------------------------------
            // 2. GRAVITY-SURFACE GEOMETRY
            //
            // This describes the local slope of the visualized
            // QRTL gravity surface.
            //
            // It is deliberately weaker than the primary
            // gravitational acceleration to avoid double-counting.
            // ----------------------------------------------------

            let surface =
                qrtlGravitySurfaceCurvature(
                    at: position,
                    direction: dir
                )

            // ----------------------------------------------------
            // 3. ELECTROMAGNETIC REFRACTION
            // ----------------------------------------------------

            let electromagnetic =
                electromagneticForce(
                    at: position,
                    direction: dir
                )

            // ----------------------------------------------------
            // 4. COMBINE FIELD CONTRIBUTIONS
            // ----------------------------------------------------

            let totalAcceleration =
                gravity
                *
                gravityCoupling

                +

                surface
                *
                surfaceCoupling
                *
                0.10

                +

                electromagnetic
                *
                electromagneticCoupling

            guard
                totalAcceleration.x.isFinite,
                totalAcceleration.y.isFinite,
                totalAcceleration.z.isFinite
            else {
                break
            }

            // ----------------------------------------------------
            // 5. ONLY TRANSVERSE COMPONENT BENDS PHOTON
            // ----------------------------------------------------

            let transverseAcceleration =
                transverseComponent(
                    totalAcceleration,
                    relativeTo: dir
                )

            // ----------------------------------------------------
            // 6. CURVE THE PHOTON DIRECTION
            //
            // d(direction)/ds = transverse curvature
            // ----------------------------------------------------

            var newDirection =
                dir
                +
                transverseAcceleration
                *
                effectiveStep

            let magnitude =
                simd_length(
                    newDirection
                )

            guard
                magnitude.isFinite,
                magnitude > 1.0e-20
            else {
                break
            }

            newDirection /=
                magnitude

            dir =
                newDirection

            // ----------------------------------------------------
            // 7. ADVANCE PHOTON
            // ----------------------------------------------------

            position +=
                dir
                *
                effectiveStep

            guard
                position.x.isFinite,
                position.y.isFinite,
                position.z.isFinite
            else {
                break
            }

            path.append(
                position
            )
        }

        return path
    }

    // ============================================================
    // MARK: - TRANSVERSE COMPONENT
    // ============================================================

    private func transverseComponent(
        _ vector: SIMD3<Double>,
        relativeTo direction: SIMD3<Double>
    ) -> SIMD3<Double> {

        let d =
            simd_normalize(
                direction
            )

        guard
            d.x.isFinite,
            d.y.isFinite,
            d.z.isFinite,
            simd_length(d) > 1.0e-12
        else {
            return .zero
        }

        let parallel =
            simd_dot(
                vector,
                d
            )

        return
            vector
            -
            d * parallel
    }
}
