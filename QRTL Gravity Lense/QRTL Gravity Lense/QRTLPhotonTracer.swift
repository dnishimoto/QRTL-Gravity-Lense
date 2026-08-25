//
//  QRTLPhotonTracer.swift
//  QRTL Gravity Lense
//
//  Photon propagation through the QRTL-derived spacetime metric.
//
//  ARCHITECTURE
//
//  QRTLField
//      ↓
//  QRTL gravitational potential Φ
//      ↓
//  dimensionless potential U = Φ / c²
//      ↓
//  weak-field spacetime metric gμν
//      ↓
//  ∂gμν / ∂xα
//      ↓
//  Christoffel symbols Γᵘαβ
//      ↓
//  null geodesic equation
//      ↓
//  photon trajectory
//
//  The renderer does NOT bend the photon.
//  The gravity surface does NOT bend the photon.
//  The photon tracer follows the calculated spacetime geometry.
//
//  Coordinate convention:
//
//      Scene X = photon propagation direction
//      Scene Y = transverse direction
//      Scene Z = transverse direction
//
//      Physical X = photon propagation direction
//      Physical Y = transverse direction
//      Physical Z = transverse direction
//
//  The fourth coordinate is:
//
//      q⁰ = ct / R
//
//  where R is the QRTL cluster radius.
//
//  Spatial coordinates are:
//
//      q¹ = X / R
//      q² = Y / R
//      q³ = Z / R
//
//  The metric is evaluated in the weak-field limit:
//
//      g₀₀ = -(1 + 2Φ/c²)
//
//      gᵢⱼ = (1 - 2Φ/c²) δᵢⱼ
//
//  with γ = 1.
//
//  This is a weak-field GR-style null-geodesic implementation.
//  QRTL supplies Φ; the renderer remains a consumer.
//

import Foundation
import simd

// ============================================================
// QRTL PHOTON TRACER
// ============================================================

final class QRTLPhotonTracer {

    static let sceneExtent: Float = 18.0
    // ============================================================
    // AUTHORITATIVE FIELD
    // ============================================================

    private let field: QRTLField

    // ============================================================
    // PHYSICAL CONSTANTS
    // ============================================================

    private let speedOfLight: Double = 299_792_458.0

    // GR PPN spatial-curvature parameter.
    //
    // General relativity:
    //
    //     γ = 1
    //
    // Keeping it explicit makes the GR/QRTL comparison easier.
    private let gamma: Double = 1.0

    // ============================================================
    // INITIALIZATION
    // ============================================================

    init(field: QRTLField) {
        self.field = field
    }

    // ============================================================
    // TRACE PHOTON
    // ============================================================

    func tracePhoton(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        parameters: LensingParameters,
        sceneToPhysicalScale: Float
    ) -> PhotonTraceResult {

        // ========================================================
        // SCALE
        // ========================================================

        let clusterRadius = Double(field.clusterRadiusMeters)

        guard clusterRadius.isFinite,
              clusterRadius > 0.0
        else {
            return emptyResult(
                origin: origin,
                direction: direction
            )
        }

        let sceneToPhysical = Double(sceneToPhysicalScale)

        guard sceneToPhysical.isFinite,
              sceneToPhysical > 0.0
        else {
            return emptyResult(
                origin: origin,
                direction: direction
            )
        }

        // ========================================================
        // INITIAL DIRECTION
        // ========================================================

        let initialDirection = simd_normalize(
            SIMD3<Double>(
                Double(direction.x),
                Double(direction.y),
                Double(direction.z)
            )
        )

        guard simd_length_squared(initialDirection) > 1.0e-20
        else {
            return emptyResult(
                origin: origin,
                direction: direction
            )
        }

        // ========================================================
        // INITIAL POSITION
        //
        // q = scene position / cluster radius scale
        //
        // q¹ = X / R
        // q² = Y / R
        // q³ = Z / R
        // ========================================================

        var position = SIMD3<Double>(
            Double(origin.x) / sceneToPhysical,
            Double(origin.y) / sceneToPhysical,
            Double(origin.z) / sceneToPhysical
        )

        // ========================================================
        // FOUR-POSITION
        //
        // q⁰ = ct / R
        // q¹ = X / R
        // q² = Y / R
        // q³ = Z / R
        // ========================================================

        var q = SIMD4<Double>(
            0.0,
            position.x,
            position.y,
            position.z
        )

        // ========================================================
        // INITIAL NULL TANGENT
        // ========================================================

        var k = SIMD4<Double>(
            1.0,
            initialDirection.x,
            initialDirection.y,
            initialDirection.z
        )

        // ========================================================
        // TRACE CONFIGURATION
        // ========================================================

        let maxSteps = max(
            parameters.maximumPhotonSteps,
            1
        )

        let stepSize = max(
            Double(parameters.stepSize),
            1.0e-6
        )

        // ========================================================
        // IMPORTANT UNIT FIX
        //
        // position is dimensionless:
        //
        //     position = scenePosition / sceneToPhysical
        //
        // Therefore parameters.maxRadius must NOT be compared
        // against position.
        //
        // The radius safety check below uses scenePosition instead.
        // ========================================================

        let maxRadius = max(
            Double(parameters.maxRadius),
            0.001
        )

        // ========================================================
        // PROJECTION BOUNDARY
        //
        // The flat circular visualization has an authoritative
        // scene extent of Self.sceneExtent.
        //
        // Do not allow targetPlaneZ to extend beyond that surface.
        //
        // NOTE:
        // targetPlaneZ is historically named Z, but in this
        // architecture Scene X is the photon propagation axis.
        // ========================================================

        let targetPlaneX = min(
            Double(parameters.targetPlaneZ),
            Double(Self.sceneExtent)
        )

        // ========================================================
        // PATH STORAGE
        // ========================================================

        var positions: [SIMD3<Float>] = []

        positions.reserveCapacity(
            maxSteps + 1
        )

        positions.append(
            SIMD3<Float>(
                origin.x,
                origin.y,
                origin.z
            )
        )

        // ========================================================
        // DIAGNOSTIC STATE
        // ========================================================

        var maximumQRTLInfluence: Float = 0.0
        var maximumMagneticField: Float = 0.0
        var maximumMagneticPhotonInfluence: Float = 0.0

        var hitProjection = false
        var projectionCoordinates: SIMD2<Float>? = nil

        var traveledDistance: Double = 0.0

        // ========================================================
        // GEODESIC INTEGRATION
        // ========================================================

        for _ in 0..<maxSteps {

            // ----------------------------------------------------
            // CURRENT SCENE POSITION
            //
            // Convert the dimensionless geodesic coordinates back
            // into SceneKit coordinates.
            // ----------------------------------------------------

            let scenePosition = SIMD3<Float>(
                Float(q.y * sceneToPhysical),
                Float(q.z * sceneToPhysical),
                Float(q.w * sceneToPhysical)
            )

            guard scenePosition.x.isFinite,
                  scenePosition.y.isFinite,
                  scenePosition.z.isFinite
            else {
                break
            }

            // ----------------------------------------------------
            // SCENE-SPACE RADIUS
            //
            // IMPORTANT:
            //
            // q / position are dimensionless.
            //
            // scenePosition is in SceneKit units.
            //
            // maxRadius is a scene-space safety boundary.
            // ----------------------------------------------------

            let sceneRadius = simd_length(scenePosition)

            guard sceneRadius.isFinite
            else {
                break
            }

            // ----------------------------------------------------
            // SAFETY TERMINATION
            // ----------------------------------------------------

            if Double(sceneRadius) > maxRadius {
                break
            }

            // ----------------------------------------------------
            // FIELD DIAGNOSTICS
            //
            // Observational only.
            //
            // These do NOT bend the photon.
            // ----------------------------------------------------

            updateDiagnostics(
                physicalPosition: SIMD3<Double>(
                    position.x,
                    position.y,
                    position.z
                ) * clusterRadius,
                maximumQRTLInfluence: &maximumQRTLInfluence,
                maximumMagneticField: &maximumMagneticField,
                maximumMagneticPhotonInfluence:
                    &maximumMagneticPhotonInfluence
            )

            // ----------------------------------------------------
            // FLAT CIRCULAR PROJECTION PLANE
            //
            // Scene X is the photon propagation direction.
            //
            // The projection plane is therefore:
            //
            //     X = targetPlaneX
            //
            // targetPlaneX is capped by Self.sceneExtent so the
            // photon cannot be projected beyond the circular
            // visualization.
            // ----------------------------------------------------

            if Double(scenePosition.x) >= targetPlaneX {

                hitProjection = true

                projectionCoordinates = SIMD2<Float>(
                    scenePosition.y,
                    scenePosition.z
                )

                break
            }

            // ----------------------------------------------------
            // RK4 GEODESIC STEP
            // ----------------------------------------------------

            let step = geodesicStep(
                q: q,
                k: k,
                step: stepSize,
                clusterRadius: clusterRadius
            )

            let stepQIsFinite = step.q.x.isFinite && step.q.y.isFinite && step.q.z.isFinite && step.q.w.isFinite
            let stepKIsFinite = step.k.x.isFinite && step.k.y.isFinite && step.k.z.isFinite && step.k.w.isFinite

            guard stepQIsFinite,
                  stepKIsFinite
            else {
                break
            }

            q = step.q
            k = step.k

            // ----------------------------------------------------
            // UPDATE DIMENSIONLESS SPATIAL POSITION
            //
            // This remains dimensionless.
            //
            // q¹ = X/R
            // q² = Y/R
            // q³ = Z/R
            // ----------------------------------------------------

            position = SIMD3<Double>(
                q.y,
                q.z,
                q.w
            )

            traveledDistance += stepSize

            // ----------------------------------------------------
            // STORE VISUAL SCENE POSITION
            // ----------------------------------------------------

            positions.append(
                SIMD3<Float>(
                    Float(q.y * sceneToPhysical),
                    Float(q.z * sceneToPhysical),
                    Float(q.w * sceneToPhysical)
                )
            )
        }

        // ========================================================
        // FINAL STATE
        // ========================================================

        let finalPosition: SIMD3<Float>

        if let last = positions.last {
            finalPosition = last
        } else {
            finalPosition = origin
        }

        let finalDirection = simd_normalize(
            SIMD3<Float>(
                Float(k.y),
                Float(k.z),
                Float(k.w)
            )
        )

        // projectionPoint: We do not have a computed 3D intersection point on the plane,
        // so per instructions we set this to nil for now.
        let projectionPoint: SIMD3<Float>? = nil

        return PhotonTraceResult(
            origin: origin,
            direction: direction,
            positions: positions,
            finalPosition: finalPosition,
            finalDirection: finalDirection,
            hitProjection: hitProjection,
            projectionPoint: projectionPoint,
            projectionCoordinates: projectionCoordinates,
            stepCount: positions.count,
            traveledDistance: Float(traveledDistance),
            maximumQRTLInfluence: maximumQRTLInfluence,
            maximumMagneticField: maximumMagneticField,
            maximumMagneticPhotonInfluence: maximumMagneticPhotonInfluence,
            sourceCoordinates: nil,
            interactionCount: 0
        )
    }

    // ============================================================
    // GEODESIC STEP
    // ============================================================

    private func geodesicStep(
        q: SIMD4<Double>,
        k: SIMD4<Double>,
        step: Double,
        clusterRadius: Double
    ) -> (
        q: SIMD4<Double>,
        k: SIMD4<Double>
    ) {

        // --------------------------------------------------------
        // RK4
        //
        // dqᵘ/dλ = kᵘ
        //
        // dkᵘ/dλ =
        //
        //     -Γᵘαβ kᵅ kᵝ
        // --------------------------------------------------------

        let a1 = derivative(
            q: q,
            k: k,
            clusterRadius: clusterRadius
        )

        let q2 = q + 0.5 * step * k
        let k2 = k + 0.5 * step * a1

        let a2 = derivative(
            q: q2,
            k: k2,
            clusterRadius: clusterRadius
        )

        let q3 = q + 0.5 * step * k2
        let k3 = k + 0.5 * step * a2

        let a3 = derivative(
            q: q3,
            k: k3,
            clusterRadius: clusterRadius
        )

        let q4 = q + step * k3
        let k4 = k + step * a3

        let a4 = derivative(
            q: q4,
            k: k4,
            clusterRadius: clusterRadius
        )

        let newQ =
            q +
            (step / 6.0) *
            (
                k +
                2.0 * k2 +
                2.0 * k3 +
                k4
            )

        let newK =
            k +
            (step / 6.0) *
            (
                a1 +
                2.0 * a2 +
                2.0 * a3 +
                a4
            )

        return (
            q: newQ,
            k: newK
        )
    }

    // ============================================================
    // GEODESIC DERIVATIVE
    // ============================================================

    private func derivative(
        q: SIMD4<Double>,
        k: SIMD4<Double>,
        clusterRadius: Double
    ) -> SIMD4<Double> {

        let christoffel =
            christoffelSymbols(
                q: q,
                clusterRadius: clusterRadius
            )

        var acceleration = SIMD4<Double>(
            repeating: 0.0
        )

        // --------------------------------------------------------
        // -Γᵘαβ kᵅ kᵝ
        // --------------------------------------------------------

        for mu in 0..<4 {

            var value = 0.0

            for alpha in 0..<4 {

                for beta in 0..<4 {

                    value +=
                        christoffel[mu][alpha][beta] *
                        k[alpha] *
                        k[beta]
                }
            }

            acceleration[mu] = -value
        }

        return acceleration
    }

    // ============================================================
    // CHRISTOFFEL SYMBOLS
    // ============================================================

    private func christoffelSymbols(
        q: SIMD4<Double>,
        clusterRadius: Double
    ) -> [[[Double]]] {

        let metric =
            spacetimeMetric(
                q: q,
                clusterRadius: clusterRadius
            )

        let inverseMetric =
            inverseMetric(
                metric
            )

        let derivatives =
            metricDerivatives(
                q: q,
                clusterRadius: clusterRadius
            )

        var gammaSymbols =
            Array(
                repeating:
                    Array(
                        repeating:
                            Array(
                                repeating: 0.0,
                                count: 4
                            ),
                        count: 4
                    ),
                count: 4
            )

        // --------------------------------------------------------
        // Γᵘαβ =
        //
        // 1/2 gᵘν
        //
        // [ ∂α gνβ
        // + ∂β gνα
        // - ∂ν gαβ ]
        // --------------------------------------------------------

        for mu in 0..<4 {

            for alpha in 0..<4 {

                for beta in 0..<4 {

                    var value = 0.0

                    for nu in 0..<4 {

                        let first =
                            derivatives[nu][beta][alpha]

                        let second =
                            derivatives[nu][alpha][beta]

                        let third =
                            derivatives[alpha][beta][nu]

                        value +=
                            inverseMetric[mu][nu] *
                            (
                                first +
                                second -
                                third
                            )
                    }

                    gammaSymbols[mu][alpha][beta] =
                        0.5 * value
                }
            }
        }

        return gammaSymbols
    }

    // ============================================================
    // SPACETIME METRIC
    // ============================================================

    private func spacetimeMetric(
        q: SIMD4<Double>,
        clusterRadius: Double
    ) -> [[Double]] {

        let potential =
            qrtlPotential(
                q: q,
                clusterRadius: clusterRadius
            )

        // --------------------------------------------------------
        // Dimensionless weak-field potential
        //
        // U = Φ / c²
        // --------------------------------------------------------

        let U =
            potential /
            (speedOfLight * speedOfLight)

        // --------------------------------------------------------
        // Weak-field isotropic metric
        //
        // g00 = -(1 + 2U)
        //
        // gij = (1 - 2γU)δij
        // --------------------------------------------------------

        let temporal =
            -(1.0 + 2.0 * U)

        let spatial =
            1.0 - 2.0 * gamma * U

        return [
            [
                temporal, 0.0, 0.0, 0.0
            ],
            [
                0.0, spatial, 0.0, 0.0
            ],
            [
                0.0, 0.0, spatial, 0.0
            ],
            [
                0.0, 0.0, 0.0, spatial
            ]
        ]
    }

    // ============================================================
    // METRIC DERIVATIVES
    // ============================================================

    private func metricDerivatives(
        q: SIMD4<Double>,
        clusterRadius: Double
    ) -> [[[Double]]] {

        var result =
            Array(
                repeating:
                    Array(
                        repeating:
                            Array(
                                repeating: 0.0,
                                count: 4
                            ),
                        count: 4
                    ),
                count: 4
            )

        // --------------------------------------------------------
        // Static gravitational field.
        //
        // Therefore:
        //
        // ∂gμν / ∂q⁰ = 0
        // --------------------------------------------------------

        for coordinate in 1...3 {

            let derivative =
                metricDerivative(
                    q: q,
                    coordinate: coordinate,
                    clusterRadius: clusterRadius
                )

            for mu in 0..<4 {

                for nu in 0..<4 {

                    result[mu][nu][coordinate] =
                        derivative[mu][nu]
                }
            }
        }

        return result
    }

    // ============================================================
    // SINGLE METRIC DERIVATIVE
    // ============================================================

    private func metricDerivative(
        q: SIMD4<Double>,
        coordinate: Int,
        clusterRadius: Double
    ) -> [[Double]] {

        // --------------------------------------------------------
        // Physical finite-difference spacing.
        //
        // This is intentionally tied to the cluster scale rather
        // than SceneKit scale.
        // --------------------------------------------------------

        let normalizedStep = 1.0e-5

        var plus = q
        var minus = q

        plus[coordinate] += normalizedStep
        minus[coordinate] -= normalizedStep

        let gPlus =
            spacetimeMetric(
                q: plus,
                clusterRadius: clusterRadius
            )

        let gMinus =
            spacetimeMetric(
                q: minus,
                clusterRadius: clusterRadius
            )

        let denominator =
            2.0 * normalizedStep

        var derivative =
            Array(
                repeating:
                    Array(
                        repeating: 0.0,
                        count: 4
                    ),
                count: 4
            )

        for mu in 0..<4 {

            for nu in 0..<4 {

                derivative[mu][nu] =
                    (
                        gPlus[mu][nu] -
                        gMinus[mu][nu]
                    ) /
                    denominator
            }
        }

        return derivative
    }

    // ============================================================
    // INVERSE METRIC
    //
    // The weak-field metric is diagonal, so no general matrix
    // inversion is necessary.
    // ============================================================

    private func inverseMetric(
        _ metric: [[Double]]
    ) -> [[Double]] {

        var inverse =
            Array(
                repeating:
                    Array(
                        repeating: 0.0,
                        count: 4
                    ),
                count: 4
            )

        for i in 0..<4 {

            let value = metric[i][i]

            if abs(value) > 1.0e-30 {
                inverse[i][i] = 1.0 / value
            }
        }

        return inverse
    }

    // ============================================================
    // QRTL POTENTIAL
    // ============================================================

    private func qrtlPotential(
        q: SIMD4<Double>,
        clusterRadius: Double
    ) -> Double {

        let x = q.y * clusterRadius
        let y = q.z * clusterRadius
        let z = q.w * clusterRadius

        let radius = sqrt(
            x * x +
            y * y +
            z * z
        )

        guard radius.isFinite
        else {
            return 0.0
        }

        return field.interpolateRadialPotential(
            radius: radius
        )
    }

    // ============================================================
    // DIAGNOSTICS
    // ============================================================

    private func updateDiagnostics(
        physicalPosition: SIMD3<Double>,
        maximumQRTLInfluence: inout Float,
        maximumMagneticField: inout Float,
        maximumMagneticPhotonInfluence:
            inout Float
    ) {

        let position = SIMD3<Float>(
            Float(physicalPosition.x),
            Float(physicalPosition.y),
            Float(physicalPosition.z)
        )

        // --------------------------------------------------------
        // These calls are diagnostic only.
        //
        // They do NOT enter the geodesic equation here.
        //
        // Gravity geometry is supplied by the QRTL potential.
        // --------------------------------------------------------

        let influence =
            field.influence(
                at: position
            )

        maximumQRTLInfluence =
            max(
                maximumQRTLInfluence,
                Float(influence)
            )

        let magneticField =
            field.magneticField(
                at: position
            )

        maximumMagneticField =
            max(
                maximumMagneticField,
                simd_length(magneticField)
            )

        let magneticInfluence =
            field.electromagneticInfluence(
                at: position
            )

        maximumMagneticPhotonInfluence =
            max(
                maximumMagneticPhotonInfluence,
                Float(magneticInfluence)
            )
    }

    // ============================================================
    // EMPTY RESULT
    // ============================================================

    private func emptyResult(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>
    ) -> PhotonTraceResult {

        return PhotonTraceResult(
            origin: origin,
            direction: direction,
            positions: [
                origin
            ],
            finalPosition: origin,
            finalDirection: SIMD3<Float>(
                1.0,
                0.0,
                0.0
            ),
            hitProjection: false,
            projectionPoint: nil,
            projectionCoordinates: nil,
            stepCount: 1,
            traveledDistance: 0.0,
            maximumQRTLInfluence: 0.0,
            maximumMagneticField: 0.0,
            maximumMagneticPhotonInfluence: 0.0,
            sourceCoordinates: nil,
            interactionCount: 0
        )
    }
}

