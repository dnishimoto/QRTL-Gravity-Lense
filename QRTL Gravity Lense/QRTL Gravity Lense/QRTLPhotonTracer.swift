
//
//  QRTLPhotonTracer.swift
//  QRTL Gravity Lense
//
//  QRTL gravitational photon tracer
//
//  IMPORTANT:
//
//  The trajectory generated here is the authoritative photon path
//  used by the visualization.
//
//  There is NO independent straight-line photon path.
//
//  Current pipeline:
//
//  Source Galaxy
//       ↓
//  Photon Origin
//       ↓
//  QRTL physical-space query
//       ↓
//  QRTL gravitational lensing response
//       ↓
//  Transverse gravitational response
//       ↓
//  Photon direction update
//       ↓
//  Photon position update
//       ↓
//  Projection-plane intersection at X = projectionX
//       ↓
//  PhotonTraceResult.positions
//       ↓
//  Continuous photon emitter
//

import Foundation
import simd

final class QRTLPhotonTracer {

    // ============================================================
    // MARK: - FIELD
    // ============================================================

    let field: QRTLField

    init(field: QRTLField) {
        self.field = field
    }

    // ============================================================
    // MARK: - TRANSVERSE COMPONENT
    // ============================================================

    private func transverseComponent(
        _ vector: SIMD3<Float>,
        relativeTo direction: SIMD3<Float>
    ) -> SIMD3<Float> {

        let length = simd_length(direction)

        guard
            length.isFinite,
            length > 1.0e-12
        else {
            return .zero
        }

        let d = direction / length

        let parallel = simd_dot(vector, d)

        let result =
            vector - d * parallel

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
    // MARK: - PROJECTION PLANE INTERSECTION
    // ============================================================
    //
    // Current ContentView geometry:
    //
    // Photon propagation = +X
    //
    // Projection plane:
    //
    //      X = parameters.projectionX
    //
    // Image coordinates:
    //
    //      horizontal = Y
    //      vertical   = Z
    //
    // Normalized coordinates:
    //
    //      Y / projectionPlaneHalfExtent
    //      Z / projectionPlaneHalfExtent
    //
    // ============================================================

    private func projectionIntersection(
        previousPosition: SIMD3<Float>,
        currentPosition: SIMD3<Float>,
        parameters: LensingParameters
    ) -> (
        point: SIMD3<Float>,
        coordinates: SIMD2<Float>
    )? {

        let targetX =
            Float(parameters.projectionX)

        let previousX =
            previousPosition.x

        let currentX =
            currentPosition.x

        let dx =
            currentX - previousX

        guard
            targetX.isFinite,
            previousX.isFinite,
            currentX.isFinite,
            dx.isFinite,
            abs(dx) > 1.0e-8
        else {
            return nil
        }

        // The photon must cross the projection plane while
        // propagating forward in +X.

        guard
            currentX >= previousX,
            targetX >= previousX,
            targetX <= currentX
        else {
            return nil
        }

        let t =
            (targetX - previousX) / dx

        guard
            t.isFinite,
            t >= 0.0,
            t <= 1.0
        else {
            return nil
        }

        let point =
            previousPosition
            +
            (currentPosition - previousPosition) * t

        let halfExtent =
            Float(parameters.projectionPlaneHalfExtent)

        guard
            halfExtent.isFinite,
            halfExtent > 0.0
        else {
            return nil
        }

        let coordinates =
            SIMD2<Float>(
                point.y / halfExtent,
                point.z / halfExtent
            )

        guard
            point.x.isFinite,
            point.y.isFinite,
            point.z.isFinite,
            coordinates.x.isFinite,
            coordinates.y.isFinite,
            abs(coordinates.x) <= 1.0,
            abs(coordinates.y) <= 1.0
        else {
            return nil
        }

        return (
            point: point,
            coordinates: coordinates
        )
    }

    // ============================================================
    // MARK: - TRACE PHOTON
    // ============================================================

    func tracePhoton(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        parameters: LensingParameters
    ) -> PhotonTraceResult {

        // ========================================================
        // INITIAL POSITION
        // ========================================================

        var position =
            origin

        // ========================================================
        // INITIAL DIRECTION
        // ========================================================

        let initialLength =
            simd_length(direction)

        guard
            direction.x.isFinite,
            direction.y.isFinite,
            direction.z.isFinite,
            initialLength.isFinite,
            initialLength > 1.0e-12
        else {

            return PhotonTraceResult(
                origin: origin,
                direction: .zero,
                positions: [origin],
                finalPosition: origin,
                finalDirection: .zero,
                hitProjection: false,
                projectionPoint: nil,
                projectionCoordinates: nil,
                stepCount: 0,
                traveledDistance: 0.0,
                maximumQRTLInfluence: 0.0,
                maximumMagneticField: 0.0,
                maximumMagneticPhotonInfluence: 0.0,
                sourceCoordinates: nil,
                interactionCount: 0
            )
        }

        var rayDirection =
            direction / initialLength

        guard
            rayDirection.x.isFinite,
            rayDirection.y.isFinite,
            rayDirection.z.isFinite
        else {

            return PhotonTraceResult(
                origin: origin,
                direction: .zero,
                positions: [origin],
                finalPosition: origin,
                finalDirection: .zero,
                hitProjection: false,
                projectionPoint: nil,
                projectionCoordinates: nil,
                stepCount: 0,
                traveledDistance: 0.0,
                maximumQRTLInfluence: 0.0,
                maximumMagneticField: 0.0,
                maximumMagneticPhotonInfluence: 0.0,
                sourceCoordinates: nil,
                interactionCount: 0
            )
        }

        // ========================================================
        // AUTHORITATIVE PHOTON PATH
        // ========================================================

        var positions =
            [SIMD3<Float>]()

        positions.reserveCapacity(
            parameters.maxSteps + 1
        )

        positions.append(position)

        // ========================================================
        // DIAGNOSTICS
        // ========================================================

        var stepCount =
            0

        var traveledDistance:
            Float = 0.0

        var interactionCount =
            0

        var maximumQRTLInfluence:
            Float = 0.0

        // Electromagnetic photon bending is intentionally disabled.
        //
        // The gravitational path is generated exclusively from
        // field.qrtlLensingAcceleration(...).

        let maximumMagneticField:
            Float = 0.0

        let maximumMagneticPhotonInfluence:
            Float = 0.0

        // ========================================================
        // PROJECTION STATE
        // ========================================================

        var hitProjection =
            false

        var projectionPoint:
            SIMD3<Float>? = nil

        var projectionCoordinates:
            SIMD2<Float>? = nil

        // ========================================================
        // CURRENT LENSING PARAMETERS
        // ========================================================

        let stepSize =
            Float(parameters.stepSize)

        let maximumRadius =
            Float(parameters.maxRadius)

        let lensingStrength =
            Float(parameters.qrtlLensingStrength)

        let projectionX =
            Float(parameters.projectionX)

        let projectionHalfExtent =
            Float(parameters.projectionPlaneHalfExtent)

        guard
            stepSize.isFinite,
            stepSize > 0.0,
            maximumRadius.isFinite,
            maximumRadius > 0.0,
            lensingStrength.isFinite,
            projectionX.isFinite,
            projectionHalfExtent.isFinite,
            projectionHalfExtent > 0.0,
            parameters.maxSteps > 0
        else {

            return PhotonTraceResult(
                origin: origin,
                direction: rayDirection,
                positions: positions,
                finalPosition: position,
                finalDirection: rayDirection,
                hitProjection: false,
                projectionPoint: nil,
                projectionCoordinates: nil,
                stepCount: 0,
                traveledDistance: 0.0,
                maximumQRTLInfluence: 0.0,
                maximumMagneticField: 0.0,
                maximumMagneticPhotonInfluence: 0.0,
                sourceCoordinates: nil,
                interactionCount: 0
            )
        }

        // ========================================================
        // PHOTON PROPAGATION
        // ========================================================

        for step in 0..<parameters.maxSteps {

            stepCount =
                step + 1

            let previousPosition =
                position

            // ====================================================
            // QRTL FIELD QUERY
            // ====================================================
            //
            // ContentView supplies photon positions in the same
            // physical coordinate system used by QRTLField.
            //
            // No additional scene-to-physical conversion is
            // performed here.
            //
            // This is important because the current QRTL field
            // operates on physical-space coordinates.
            // ====================================================

            guard
                position.x.isFinite,
                position.y.isFinite,
                position.z.isFinite
            else {
                break
            }

            let qrtlResponse =
                field.qrtlLensingAcceleration(
                    at: position,
                    direction: rayDirection
                )

            guard
                qrtlResponse.x.isFinite,
                qrtlResponse.y.isFinite,
                qrtlResponse.z.isFinite
            else {
                break
            }

            // ====================================================
            // REMOVE LONGITUDINAL COMPONENT
            // ====================================================

            let qrtlTransverse =
                transverseComponent(
                    qrtlResponse,
                    relativeTo: rayDirection
                )

            let qrtlMagnitude =
                simd_length(qrtlTransverse)

            guard
                qrtlMagnitude.isFinite
            else {
                break
            }

            maximumQRTLInfluence =
                max(
                    maximumQRTLInfluence,
                    qrtlMagnitude
                )

            if qrtlMagnitude > 0.0 {
                interactionCount += 1
            }

            // ====================================================
            // APPLY QRTL GRAVITATIONAL DEFLECTION
            // ====================================================
            //
            // Current QRTL photon equation:
            //
            // D(next) =
            //
            // normalize(
            //     D(current)
            //     +
            //     QRTL_transverse
            //     × qrtlLensingStrength
            //     × stepSize
            // )
            //
            // The response and integration coordinates are now
            // in the same coordinate system as QRTLField.
            // ====================================================

            let deflection =
                qrtlTransverse
                *
                lensingStrength
                *
                stepSize

            guard
                deflection.x.isFinite,
                deflection.y.isFinite,
                deflection.z.isFinite
            else {
                break
            }

            rayDirection +=
                deflection

            let directionLength =
                simd_length(rayDirection)

            guard
                directionLength.isFinite,
                directionLength > 1.0e-12
            else {
                break
            }

            rayDirection =
                rayDirection / directionLength

            // ====================================================
            // ADVANCE PHOTON
            // ====================================================

            position +=
                rayDirection * stepSize

            traveledDistance +=
                stepSize

            guard
                position.x.isFinite,
                position.y.isFinite,
                position.z.isFinite
            else {
                break
            }

            // ====================================================
            // STORE ACTUAL CURVED POSITION
            // ====================================================
            //
            // This is the authoritative trajectory.
            //
            // ContentView / SceneKit must render these positions.
            // ====================================================

            positions.append(position)

            // ====================================================
            // PROJECTION PLANE
            // ====================================================

            if !hitProjection {

                if let hit =
                    projectionIntersection(
                        previousPosition:
                            previousPosition,
                        currentPosition:
                            position,
                        parameters:
                            parameters
                    ) {

                    hitProjection =
                        true

                    projectionPoint =
                        hit.point

                    projectionCoordinates =
                        hit.coordinates
                }
            }

            // ====================================================
            // PROPAGATION LIMIT
            // ====================================================

            let radius =
                simd_length(position)

            guard
                radius.isFinite
            else {
                break
            }

            if radius >= maximumRadius {
                break
            }

            // ====================================================
            // STOP AFTER PROJECTION
            // ====================================================
            //
            // Once the photon reaches the projection plane,
            // its image coordinate has been determined.
            //
            // There is no need to continue tracing it beyond
            // the image plane.
            // ====================================================

            if hitProjection {
                break
            }
        }

        // ========================================================
        // FINAL RESULT
        // ========================================================

        return PhotonTraceResult(
            origin:
                origin,

            direction:
                rayDirection,

            positions:
                positions,

            finalPosition:
                position,

            finalDirection:
                rayDirection,

            hitProjection:
                hitProjection,

            projectionPoint:
                projectionPoint,

            projectionCoordinates:
                projectionCoordinates,

            stepCount:
                stepCount,

            traveledDistance:
                traveledDistance,

            maximumQRTLInfluence:
                maximumQRTLInfluence,

            maximumMagneticField:
                maximumMagneticField,

            maximumMagneticPhotonInfluence:
                maximumMagneticPhotonInfluence,

            sourceCoordinates:
                nil,

            interactionCount:
                interactionCount
        )
    }
}

