

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
    //
    // Removes the component of the gravitational response
    // parallel to photon propagation.
    //
    // Only the transverse component changes photon direction.
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
    // MARK: - PROJECTION PLANE INTERSECTION
    //
    // Photons propagate primarily along +X.
    //
    // Projection plane:
    //
    //     X = targetPlaneX
    //
    // Projection coordinates:
    //
    //     horizontal = Y
    //     vertical   = Z
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

        // --------------------------------------------------------
        // Segment / plane intersection
        // --------------------------------------------------------

        let t =
            (targetX - previousX) / dx

        guard
            t.isFinite,
            t >= 0.0,
            t <= 1.0
        else {
            return nil
        }

        // --------------------------------------------------------
        // Intersection point
        // --------------------------------------------------------

        let point =
            previousPosition
            +
            (
                currentPosition
                -
                previousPosition
            )
            * t

        // --------------------------------------------------------
        // Projection scale
        // --------------------------------------------------------

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

        // --------------------------------------------------------
        // Y/Z become image coordinates
        // --------------------------------------------------------

        let coordinates =
            SIMD2<Float>(
                point.y / halfExtent,
                point.z / halfExtent
            )

        // --------------------------------------------------------
        // Validation
        // --------------------------------------------------------

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
    //
    // Pipeline:
    //
    // Photon origin
    //      ↓
    // Normalize direction
    //      ↓
    // Sample QRTL gravitational field
    //      ↓
    // Remove longitudinal component
    //      ↓
    // Apply gravitational deflection
    //      ↓
    // Normalize direction
    //      ↓
    // Advance photon
    //      ↓
    // Check projection plane
    //      ↓
    // Repeat
    // ============================================================

    func tracePhoton(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        parameters: LensingParameters,
        sceneToPhysicalScale: Float = 1.0
    ) -> PhotonTraceResult {

        // --------------------------------------------------------
        // SCENE-SPACE vs. PHYSICAL-SPACE
        //
        // origin/direction/position/stepSize all live in the
        // caller's SCENE coordinates (e.g. a visualization's
        // -extent...+extent range). QRTLField's gravity table,
        // however, is built over the cluster's REAL physical
        // radius in meters (field.clusterRadiusMeters), which can
        // be many orders of magnitude larger than any reasonable
        // scene extent.
        //
        // Without a conversion, every scene-space query position
        // — from a "far away" source galaxy to the point of
        // closest approach — lands inside the very first, tiny
        // sliver of the physical table, so the field always reads
        // as if the photon were sitting at the exact center: no
        // "before curvature starts" is representable, and a
        // source galaxy can never be meaningfully positioned
        // outside the cluster's influence.
        //
        // sceneToPhysicalScale converts a scene-space position to
        // the equivalent physical position (in meters) ONLY for
        // querying the field — the photon's actual integration
        // (position, direction, step size) stays entirely in
        // scene-space, so nothing about rendering, step size, or
        // the projection plane needs to change. Default 1.0
        // preserves prior behavior for any caller already passing
        // literal physical positions.
        // --------------------------------------------------------

        let sceneToPhysical =
            sceneToPhysicalScale.isFinite &&
            sceneToPhysicalScale > 0.0
            ? sceneToPhysicalScale
            : 1.0

        var position =
            origin

        // --------------------------------------------------------
        // Initial photon direction
        // --------------------------------------------------------

        var rayDirection =
            simd_normalize(direction)

        guard
            rayDirection.x.isFinite,
            rayDirection.y.isFinite,
            rayDirection.z.isFinite,
            simd_length(rayDirection) > 1.0e-12
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

        // --------------------------------------------------------
        // Photon path
        // --------------------------------------------------------

        var positions:
            [SIMD3<Float>] = []

        positions.reserveCapacity(
            parameters.maximumPhotonSteps + 1
        )

        positions.append(position)

        // --------------------------------------------------------
        // Diagnostics
        // --------------------------------------------------------

        var stepCount =
            0

        var traveledDistance:
            Float = 0.0

        var interactionCount =
            0

        var maximumQRTLInfluence:
            Float = 0.0

        // --------------------------------------------------------
        // These fields remain zero because electromagnetic
        // photon bending has been removed from this tracer.
        //
        // They are retained only for compatibility with the
        // existing PhotonTraceResult structure.
        // --------------------------------------------------------

        let maximumMagneticField:
            Float = 0.0

        let maximumMagneticPhotonInfluence:
            Float = 0.0

        // --------------------------------------------------------
        // Projection state
        // --------------------------------------------------------

        var hitProjection =
            false

        var projectionPoint:
            SIMD3<Float>? = nil

        var projectionCoordinates:
            SIMD2<Float>? = nil

        // --------------------------------------------------------
        // Propagation parameters
        // --------------------------------------------------------

        let stepSize =
            Float(
                parameters.photonStepSize
            )

        let maximumRadius =
            Float(
                parameters.maximumPropagationRadius
            )

        guard
            stepSize.isFinite,
            stepSize > 0.0,
            maximumRadius.isFinite,
            maximumRadius > 0.0
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

        for step
        in 0..<parameters.maximumPhotonSteps {

            stepCount =
                step + 1

            let currentPosition =
                position

            // ====================================================
            // CONVERT TO PHYSICAL SPACE FOR THE FIELD QUERY ONLY
            // ====================================================

            let physicalQueryPosition =
                currentPosition *
                sceneToPhysical

            // ====================================================
            // QRTL GRAVITATIONAL LENSING
            // ====================================================

            let qrtlResponse =
                field.qrtlLensingAcceleration(
                    at: physicalQueryPosition,
                    direction: rayDirection
                )

            // ----------------------------------------------------
            // Keep only the component perpendicular to the
            // direction of photon travel.
            // ----------------------------------------------------

            let qrtlTransverse =
                transverseComponent(
                    qrtlResponse,
                    relativeTo: rayDirection
                )

            // ----------------------------------------------------
            // Diagnostic magnitude
            // ----------------------------------------------------

            let qrtlMagnitude =
                simd_length(
                    qrtlTransverse
                )

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
            // UPDATE PHOTON DIRECTION
            //
            // dD/ds ≈ QRTL transverse response
            //
            // D_new =
            // normalize(
            //     D + response * deflectionStrength * ds
            // )
            // ====================================================

            rayDirection +=
                qrtlTransverse
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

                hitProjection =
                    true

                projectionPoint =
                    hit.point

                projectionCoordinates =
                    hit.coordinates
            }

            // ====================================================
            // PROPAGATION LIMIT
            // ====================================================

            let radius =
                simd_length(
                    position
                )

            guard radius.isFinite else {
                break
            }

            if radius > maximumRadius {
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




