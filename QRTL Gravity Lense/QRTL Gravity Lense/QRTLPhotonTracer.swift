//
//  QRTLPhotonTracer.swift
//  QRTL Gravity Lense
//
//  Canonical photon propagation through the QRTL gravitational
//  surface and electromagnetic optical field.
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
    // MARK: - FLOAT CONVERSION
    // ============================================================

    private func float3(
        _ value: SIMD3<Double>
    ) -> SIMD3<Float> {

        SIMD3<Float>(
            Float(value.x),
            Float(value.y),
            Float(value.z)
        )
    }

    // ============================================================
    // MARK: - TRANSVERSE COMPONENT
    // ============================================================

    private func transverseComponent(
        _ vector: SIMD3<Double>,
        relativeTo direction: SIMD3<Double>
    ) -> SIMD3<Double> {

        let length = simd_length(direction)

        guard
            length.isFinite,
            length > 1.0e-12
        else {
            return .zero
        }

        let d = direction / length

        let parallel =
            simd_dot(vector, d)

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
                0.0,
                0.0
            )

        let dy =
            SIMD3<Double>(
                0.0,
                h,
                0.0
            )

        let dz =
            SIMD3<Double>(
                0.0,
                0.0,
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
    // MARK: - ELECTROMAGNETIC REFRACTION
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
    // MARK: - PROJECTION PLANE INTERSECTION
    // ============================================================

    private func projectionIntersection(
        previousPosition: SIMD3<Float>,
        currentPosition: SIMD3<Float>,
        parameters: LensingParameters
    ) -> (
        point: SIMD3<Float>,
        coordinates: SIMD2<Float>
    )? {

        // ========================================================
        // OBSERVATION PLANE
        // ========================================================
        //
        // Photons propagate primarily along +X.
        //
        // Therefore the projection plane is:
        //
        //     X = targetPlaneX
        //
        // The remaining Y/Z coordinates become the projection
        // coordinates.
        //
        // ========================================================

        let targetX =
            Float(parameters.targetPlaneX)

        let previousX =
            previousPosition.x

        let currentX =
            currentPosition.x

        let dx =
            currentX - previousX

        guard
            dx.isFinite,
            abs(dx) > 1.0e-8
        else {
            return nil
        }

        // ========================================================
        // SEGMENT / PLANE INTERSECTION
        // ========================================================

        let t =
            (targetX - previousX) / dx

        guard
            t >= 0.0,
            t <= 1.0,
            t.isFinite
        else {
            return nil
        }

        // ========================================================
        // INTERSECTION POINT
        // ========================================================

        let point =
            previousPosition +
            (
                currentPosition -
                previousPosition
            ) * t

        // ========================================================
        // PROJECTION COORDINATES
        // ========================================================
        //
        // X = depth / observation-plane position
        // Y = horizontal image coordinate
        // Z = vertical image coordinate
        //
        // ========================================================

        let halfExtent =
            Float(
                parameters.projectionPlaneHalfExtent
            )

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

        // ========================================================
        // VALIDATION
        // ========================================================

        guard
            point.x.isFinite,
            point.y.isFinite,
            point.z.isFinite,
            coordinates.x.isFinite,
            coordinates.y.isFinite
        else {
            return nil
        }

        // ========================================================
        // PROJECTION BOUNDS
        // ========================================================

        guard
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
    // MARK: - CANONICAL PHOTON TRACE
    // ============================================================

    func tracePhoton(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        parameters: LensingParameters
    ) -> PhotonTraceResult {

        var position =
            origin

        var rayDirection =
            simd_normalize(direction)

        var positions:
            [SIMD3<Float>] = []

        positions.reserveCapacity(
            parameters.maximumPhotonSteps + 1
        )

        positions.append(
            position
        )

        var stepCount = 0

        var traveledDistance:
            Float = 0.0

        var interactionCount = 0

        var maximumQRTLInfluence:
            Float = 0.0

        var maximumMagneticField:
            Float = 0.0

        var maximumMagneticPhotonInfluence:
            Float = 0.0

        var hitProjection = false

        var projectionPoint:
            SIMD3<Float>? = nil

        var projectionCoordinates:
            SIMD2<Float>? = nil

        let stepSize =
            Float(
                parameters.photonStepSize
            )

        let maximumRadius =
            Float(
                parameters.maximumPropagationRadius
            )

        // ========================================================
        // PHOTON PROPAGATION
        // ========================================================

        for step
        in 0..<parameters.maximumPhotonSteps {

            stepCount = step + 1

            let currentPosition =
                position

         
        
            // ====================================================
            // QRTL GRAVITATIONAL BENDING
            // ====================================================

            let qrtlAcceleration =
                field.qrtlLensingAcceleration(
                    at: currentPosition,
                    direction: rayDirection
                )

            let qrtlAccelerationFloat =
                SIMD3<Float>(
                    Float(qrtlAcceleration.x),
                    Float(qrtlAcceleration.y),
                    Float(qrtlAcceleration.z)
                )

            let qrtlTransverse =
                qrtlAccelerationFloat
                -
                rayDirection
                *
                simd_dot(
                    qrtlAccelerationFloat,
                    rayDirection
                )

            // ====================================================
            // ELECTROMAGNETIC REFRACTION
            // ====================================================

            let positionDouble =
                SIMD3<Double>(
                    Double(currentPosition.x),
                    Double(currentPosition.y),
                    Double(currentPosition.z)
                )

            let directionDouble =
                SIMD3<Double>(
                    Double(rayDirection.x),
                    Double(rayDirection.y),
                    Double(rayDirection.z)
                )

            let emForce =
                electromagneticForce(
                    at: positionDouble,
                    direction: directionDouble
                )

            let emForceFloat =
                float3(
                    emForce
                )

            maximumMagneticPhotonInfluence =
                max(
                    maximumMagneticPhotonInfluence,
                    simd_length(emForceFloat)
                )

            // ====================================================
            // MAGNETIC FIELD DIAGNOSTIC
            // ====================================================

            let magneticInfluence =
                field.electromagneticInfluence(
                    at: currentPosition
                )

            let magneticMagnitude =
                simd_length(
                    magneticInfluence
                )

            maximumMagneticField =
                max(
                    maximumMagneticField,
                    magneticMagnitude
                )

            // ====================================================
            // COMBINED PHOTON BENDING
            // ====================================================

            let combinedBending =
                qrtlTransverse
                +
                emForceFloat

            let bendingMagnitude =
                simd_length(
                    combinedBending
                )

            if bendingMagnitude > 0.0 {
                interactionCount += 1
            }

            // ====================================================
            // UPDATE PHOTON DIRECTION
            // ====================================================

            rayDirection +=
                combinedBending
                *
                Float(
                    parameters.deflectionStrength
                )
                *
                stepSize

            let directionLength =
                simd_length(
                    rayDirection
                )

            guard
                directionLength.isFinite,
                directionLength > 1.0e-12
            else {
                break
            }

            rayDirection =
                simd_normalize(
                    rayDirection
                )

            // ====================================================
            // ADVANCE PHOTON
            // ====================================================

            let previousPosition =
                position

            position +=
                rayDirection
                *
                stepSize

            traveledDistance +=
                stepSize

            positions.append(
                position
            )

            // ====================================================
            // PROJECTION PLANE
            // ====================================================

            if
                !hitProjection,
                let hit =
                    projectionIntersection(
                        previousPosition:
                            previousPosition,
                        currentPosition:
                            position,
                        parameters:
                            parameters
                    )
            {
                hitProjection = true

                projectionPoint =
                    hit.point

                projectionCoordinates =
                    hit.coordinates
            }

            // ====================================================
            // PROPAGATION LIMIT
            // ====================================================

            if
                simd_length(position)
                >
                maximumRadius
            {
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
                simd_normalize(
                    direction
                ),

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
