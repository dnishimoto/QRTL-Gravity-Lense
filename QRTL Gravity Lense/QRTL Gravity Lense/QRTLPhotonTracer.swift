
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
        
        // --------------------------------------------------------
        // INITIALISATION (unchanged safety checks)
        // --------------------------------------------------------
        var position = origin
        
        let initialLength = simd_length(direction)
        guard direction.x.isFinite, direction.y.isFinite, direction.z.isFinite,
              initialLength.isFinite, initialLength > 1e-12 else {
            return emptyResult(origin: origin)
        }
        
        var rayDirection = direction / initialLength
        guard rayDirection.x.isFinite, rayDirection.y.isFinite, rayDirection.z.isFinite else {
            return emptyResult(origin: origin)
        }
        
        var positions = [SIMD3<Float>]()
        positions.reserveCapacity(parameters.maxSteps + 1)
        positions.append(position)
        
        var stepCount = 0
        var traveledDistance: Float = 0
        var interactionCount = 0
        var maximumQRTLInfluence: Float = 0
        
        // Electromagnetic bending intentionally disabled
        let maximumMagneticField: Float = 0
        let maximumMagneticPhotonInfluence: Float = 0
        
        var hitProjection = false
        var projectionPoint: SIMD3<Float>? = nil
        var projectionCoordinates: SIMD2<Float>? = nil
        
        let baseStepSize = Float(parameters.stepSize)
        let maximumRadius = Float(parameters.maxRadius)
        let lensingStrength = Float(parameters.qrtlLensingStrength)
        let projectionX = Float(parameters.projectionX)
        let projectionHalfExtent = Float(parameters.projectionPlaneHalfExtent)
        
        guard baseStepSize.isFinite, baseStepSize > 0,
              maximumRadius.isFinite, maximumRadius > 0,
              lensingStrength.isFinite,
              projectionX.isFinite,
              projectionHalfExtent.isFinite, projectionHalfExtent > 0,
              parameters.maxSteps > 0 else {
            return PhotonTraceResult(
                origin: origin, direction: rayDirection,
                positions: positions, finalPosition: position, finalDirection: rayDirection,
                hitProjection: false, projectionPoint: nil, projectionCoordinates: nil,
                stepCount: 0, traveledDistance: 0,
                maximumQRTLInfluence: 0, maximumMagneticField: 0,
                maximumMagneticPhotonInfluence: 0,
                sourceCoordinates: nil, interactionCount: 0
            )
        }
        
        // --------------------------------------------------------
        // MAIN PROPAGATION LOOP – second-order + adaptive
        // --------------------------------------------------------
        for step in 0..<parameters.maxSteps {
            
            stepCount = step + 1
            let previousPosition = position
            let previousDirection = rayDirection
            
            guard position.x.isFinite, position.y.isFinite, position.z.isFinite else { break }
            
            // ----------------------------------------------------
            // 1. Evaluate acceleration from the local potential
            //    (this is the actual gravity / curvature force)
            // ----------------------------------------------------
            let rawAccel = field.qrtlLensingAcceleration(at: position, direction: rayDirection)
            guard rawAccel.x.isFinite, rawAccel.y.isFinite, rawAccel.z.isFinite else { break }
            
            let accel1 = transverseComponent(rawAccel, relativeTo: rayDirection)
            let accelMag = simd_length(accel1)
            guard accelMag.isFinite else { break }
            
            maximumQRTLInfluence = max(maximumQRTLInfluence, accelMag)
            if accelMag > 0 { interactionCount += 1 }
            
            // Adaptive step: shrink when curvature is strong
            let adaptiveFactor = 1.0 + 8.0 * accelMag          // tune the 8.0 if needed
            let stepSize = baseStepSize / adaptiveFactor
            guard stepSize.isFinite, stepSize > 1e-8 else { break }
            
            // ----------------------------------------------------
            // 2. Predictor step
            // ----------------------------------------------------
            var dirPred = rayDirection + accel1 * (lensingStrength * stepSize)
            let predLen = simd_length(dirPred)
            guard predLen.isFinite, predLen > 1e-12 else { break }
            dirPred /= predLen
            
            let posPred = position + dirPred * stepSize
            
            // ----------------------------------------------------
            // 3. Corrector – re-evaluate potential at predicted point
            // ----------------------------------------------------
            let rawAccel2 = field.qrtlLensingAcceleration(at: posPred, direction: dirPred)
            guard rawAccel2.x.isFinite, rawAccel2.y.isFinite, rawAccel2.z.isFinite else { break }
            
            let accel2 = transverseComponent(rawAccel2, relativeTo: dirPred)
            
            // Average acceleration (Heun / improved Euler)
            let avgAccel = 0.5 * (accel1 + accel2)
            
            // ----------------------------------------------------
            // 4. Final direction & position update
            // ----------------------------------------------------
            rayDirection += avgAccel * (lensingStrength * stepSize)
            let dirLen = simd_length(rayDirection)
            guard dirLen.isFinite, dirLen > 1e-12 else { break }
            rayDirection /= dirLen
            
            position += rayDirection * stepSize
            traveledDistance += stepSize
            
            guard position.x.isFinite, position.y.isFinite, position.z.isFinite else { break }
            
            positions.append(position)
            
            // ----------------------------------------------------
            // 5. Projection-plane test
            // ----------------------------------------------------
            if !hitProjection {
                if let hit = projectionIntersection(
                    previousPosition: previousPosition,
                    currentPosition: position,
                    parameters: parameters
                ) {
                    hitProjection = true
                    projectionPoint = hit.point
                    projectionCoordinates = hit.coordinates
                }
            }
            
            // ----------------------------------------------------
            // 6. Termination conditions
            // ----------------------------------------------------
            let radius = simd_length(position)
            if !radius.isFinite || radius >= maximumRadius { break }
            if hitProjection { break }
        }
        
        // --------------------------------------------------------
        // RESULT
        // --------------------------------------------------------
        return PhotonTraceResult(
            origin: origin,
            direction: rayDirection,               // final direction after last update
            positions: positions,
            finalPosition: position,
            finalDirection: rayDirection,
            hitProjection: hitProjection,
            projectionPoint: projectionPoint,
            projectionCoordinates: projectionCoordinates,
            stepCount: stepCount,
            traveledDistance: traveledDistance,
            maximumQRTLInfluence: maximumQRTLInfluence,
            maximumMagneticField: maximumMagneticField,
            maximumMagneticPhotonInfluence: maximumMagneticPhotonInfluence,
            sourceCoordinates: nil,
            interactionCount: interactionCount
        )
    }
    
    // Helper that returns a “failed” result (keeps the rest of the class clean)
    private func emptyResult(origin: SIMD3<Float>) -> PhotonTraceResult {
        PhotonTraceResult(
            origin: origin, direction: .zero,
            positions: [origin], finalPosition: origin, finalDirection: .zero,
            hitProjection: false, projectionPoint: nil, projectionCoordinates: nil,
            stepCount: 0, traveledDistance: 0,
            maximumQRTLInfluence: 0, maximumMagneticField: 0,
            maximumMagneticPhotonInfluence: 0,
            sourceCoordinates: nil, interactionCount: 0
        )
    }
}

