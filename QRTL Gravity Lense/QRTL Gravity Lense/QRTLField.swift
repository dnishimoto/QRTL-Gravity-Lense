//
//  QRTLField.swift
//  QRTL Gravity Lense
//
//  Cellular-Automata Driven QRTL Field
//
//  GRAVITY MODEL:
//
//  Cellular Automata Density
//          ↓
//  Physical Mass Density
//          ↓
//  Total Mass = 10^6 Solar Masses
//          ↓
//  Enclosed Mass
//          ↓
//  QRTL Energy Density
//          ↓
//  Effective QRTL Mass Density
//          ↓
//  QRTL Gravitational Potential
//          ↓
//  Spacetime / Optical Index
//          ↓
//  Photon Transverse Deflection
//
//  QRTL / EM fields remain available as additional fields.
//

import Foundation
import simd

// ============================================================
// QRTL FIELD
// ============================================================

final class QRTLField {

    // ========================================================
    // PHYSICAL INPUT
    // ========================================================

    let densitySource: GlobularClusterDensityMap
    let parameters: QRTLParameters
    let referenceDensity: Float

    // ========================================================
    // CONSTANTS
    // ========================================================

    private let gravitationalConstant: Double =
        6.67430e-11

    private let speedOfLight: Double =
        299_792_458.0

    private var speedOfLightSquared: Double {
        speedOfLight * speedOfLight
    }

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init(
        densitySource: GlobularClusterDensityMap,
        parameters: QRTLParameters
    ) {

        self.densitySource =
            densitySource

        self.parameters =
            parameters

        self.referenceDensity =
            Float(
                densitySource.centerDensity
            )
    }

    // ========================================================
    // PHYSICAL MASS DENSITY
    // ========================================================

    func massDensity(
        at position: SIMD3<Float>
    ) -> Float {

        densitySource.density(
            at: position
        )
    }

    func physicalMassDensity(
        at position: SIMD3<Float>
    ) -> Double {

        let density =
            densitySource.physicalMassDensity(
                at: position
            )

        guard density.isFinite,
              density >= 0.0
        else {
            return 0.0
        }

        return density
    }

    func normalizedDensity(
        at position: SIMD3<Float>
    ) -> Float {

        densitySource.normalizedDensity(
            at: position
        )
    }

    // ========================================================
    // PHYSICAL CLUSTER RADIUS
    // ========================================================

    private var clusterRadiusMeters: Double {

        let radius =
            Double(
                densitySource.fieldRadiusMeters
            )

        guard radius.isFinite,
              radius > 0.0
        else {
            return 1.0
        }

        return radius
    }

    // ========================================================
    // PHYSICAL TOTAL MASS
    // ========================================================
    //
    // This is the authoritative physical mass represented by
    // GlobularClusterDensityMap.
    //
    // QRTL gravity does NOT use this directly as its potential.
    // It is used for diagnostics and physical comparison.
    //
    // ========================================================

    private var physicalTotalMassKg: Double {

        let mass =
            Double(
                densitySource.totalMass
            )

        guard mass.isFinite,
              mass >= 0.0
        else {
            return 0.0
        }

        return mass
    }
    // ============================================================
    // SPACETIME CURVATURE HEIGHT
    // ============================================================
    //
    // QRTL GRAVITY → QRTL GRAVITATIONAL POTENTIAL
    //              → WEAK-FIELD CURVATURE
    //              → VISUAL SPACETIME SURFACE HEIGHT
    //
    // This function uses ONLY the QRTL gravitational field.
    //
    // It does NOT use:
    //
    //     physicalGravitationalPotential()
    //     physicalGravitationalAcceleration()
    //
    // The physical gravitational field remains available for
    // comparison and diagnostics.
    //
    // ============================================================

    func spacetimeCurvatureHeight(
        at position: SIMD3<Float>
    ) -> Float {

        // --------------------------------------------------------
        // 1. QRTL GRAVITATIONAL POTENTIAL
        // --------------------------------------------------------
        //
        // This is the authoritative QRTL gravity quantity.
        //
        //     Phi_QRTL < 0
        //
        // Stronger QRTL gravity produces a larger magnitude
        // of negative potential.
        //
        // --------------------------------------------------------

        let qrtlPotential =
            qrtlGravitationalPotential(
                at: position
            )

        guard qrtlPotential.isFinite else {
            return 0.0
        }

        // --------------------------------------------------------
        // 2. QRTL WEAK-FIELD CURVATURE
        // --------------------------------------------------------
        //
        //     h_QRTL = -2 Phi_QRTL / c²
        //
        // This is dimensionless.
        //
        // --------------------------------------------------------

        let qrtlCurvature =
            -2.0 *
            qrtlPotential /
            speedOfLightSquared

        guard qrtlCurvature.isFinite else {
            return 0.0
        }

        // --------------------------------------------------------
        // 3. CONVERT QRTL CURVATURE TO SURFACE HEIGHT
        // --------------------------------------------------------
        //
        // The conversion to SceneKit coordinates is a visualization
        // scale. It does not alter the QRTL gravitational field.
        //
        // --------------------------------------------------------

        let spacetimeHeightScale =
            1.0e6

        let height =
            qrtlCurvature *
            spacetimeHeightScale

        guard height.isFinite else {
            return 0.0
        }

        return Float(height)
    }
    // ============================================================
    // QRTL GRAVITY INFLUENCE
    //
    // Scalar visualization/diagnostic measure of the local QRTL
    // gravitational field.
    //
    // This is NOT a second gravitational-potential calculation.
    //
    // It is derived directly from the current QRTL gravitational
    // potential and normalized by c².
    //
    // Larger values indicate stronger local QRTL gravitational
    // influence.
    //
    // ============================================================

    func influence(
        at position: SIMD3<Float>
    ) -> Double {

        let potential =
            qrtlGravitationalPotential(
                at: position
            )

        guard potential.isFinite else {
            return 0.0
        }

        let cSquared =
            speedOfLightSquared

        guard cSquared.isFinite,
              cSquared > 0.0
        else {
            return 0.0
        }

        let influence =
            abs(potential) /
            cSquared

        guard influence.isFinite,
              influence >= 0.0
        else {
            return 0.0
        }

        return influence
    }
    // ========================================================
    // PHYSICAL GRAVITATIONAL POTENTIAL
    //
    // Reference field supplied by GlobularClusterDensityMap.
    //
    // ========================================================

    func physicalGravitationalPotential(
        at position: SIMD3<Float>
    ) -> Double {

        let potential =
            densitySource.gravitationalPotential(
                at: position
            )

        guard potential.isFinite
        else {
            return 0.0
        }

        return potential
    }

    // ========================================================
    // PHYSICAL GRAVITATIONAL ACCELERATION
    //
    // Reference field supplied by GlobularClusterDensityMap.
    //
    // ========================================================

    func physicalGravitationalAcceleration(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        densitySource.gravitationalAcceleration(
            at: position
        )
    }

    // ========================================================
    // QRTL SOURCE
    //
    // S_Q = alpha_Q * rho
    //
    // ========================================================

    func qrtlSource(
        at position: SIMD3<Float>
    ) -> Double {

        let rho =
            physicalMassDensity(
                at: position
            )

        guard rho.isFinite,
              rho >= 0.0
        else {
            return 0.0
        }

        let alpha =
            max(
                parameters.alphaQ,
                0.0
            )

        let source =
            alpha * rho

        guard source.isFinite,
              source >= 0.0
        else {
            return 0.0
        }

        return source
    }
    // ============================================================
    // GRAVITATIONAL POTENTIAL
    //
    // Public compatibility interface used by the gravity-surface
    // renderer and other visualization components.
    //
    // The authoritative QRTL gravity calculation remains:
    //
    //     qrtlGravitationalPotential(at:)
    //
    // This wrapper intentionally does not create a second gravity
    // calculation.
    // ============================================================

    func gravitationalPotential(
        at position: SIMD3<Float>
    ) -> Double {

        return qrtlGravitationalPotential(
            at: position
        )
    }
    // ========================================================
    // BOLGARINO RADIAL FLUX
    //
    // J_Q = S_Q * v_Q
    //
    // ========================================================

    func bolgarinoFlux(
        at position: SIMD3<Float>
    ) -> Double {

        let source =
            qrtlSource(
                at: position
            )

        let velocity =
            max(
                parameters.qrtlVelocity,
                0.0
            )

        let flux =
            source * velocity

        guard flux.isFinite,
              flux >= 0.0
        else {
            return 0.0
        }

        return flux
    }

    // ========================================================
    // QRTL CURRENT DENSITY
    //
    // ========================================================

    func qrtlCurrentDensity(
        at position: SIMD3<Float>
    ) -> Double {

        let flux =
            bolgarinoFlux(
                at: position
            )

        let interaction =
            max(
                parameters.interactionRate,
                0.0
            )

        let currentDensity =
            flux * interaction

        guard currentDensity.isFinite,
              currentDensity >= 0.0
        else {
            return 0.0
        }

        return currentDensity
    }

    // ========================================================
    // QRTL CURRENT
    //
    // ========================================================

    func qrtlCurrent(
        at position: SIMD3<Float>
    ) -> Double {

        qrtlCurrentDensity(
            at: position
        )
    }

    // ========================================================
    // ELECTROMAGNETIC INFLUENCE
    // ========================================================

    func electromagneticInfluence(
        at position: SIMD3<Float>
    ) -> Double {

        let current =
            qrtlCurrent(
                at: position
            )

        let coupling =
            max(
                parameters.electromagneticCoupling,
                0.0
            )

        let influence =
            current * coupling

        guard influence.isFinite,
              influence >= 0.0
        else {
            return 0.0
        }

        return influence
    }

    // ========================================================
    // MAGNETIC FIELD
    // ========================================================

    func magneticField(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let x =
            Double(position.x)

        let y =
            Double(position.y)

        let z =
            Double(position.z)

        let rSquared =
            x * x +
            y * y +
            z * z

        guard rSquared.isFinite
        else {
            return .zero
        }

        let r =
            sqrt(rSquared)

        guard r > 0.0,
              r.isFinite
        else {
            return .zero
        }

        let current =
            qrtlCurrent(
                at: position
            )

        guard current.isFinite,
              current >= 0.0
        else {
            return .zero
        }

        let mu0 =
            4.0 *
            Double.pi *
            1.0e-7

        let magnitude =
            mu0 *
            current /
            (
                4.0 *
                Double.pi *
                r * r
            )

        guard magnitude.isFinite,
              magnitude >= 0.0
        else {
            return .zero
        }

        // ----------------------------------------------------
        // Tangential magnetic-field direction
        // ----------------------------------------------------

        let radial =
            SIMD3<Double>(
                x,
                y,
                z
            )

        let axis =
            SIMD3<Double>(
                0.0,
                1.0,
                0.0
            )

        var tangential =
            simd_cross(
                axis,
                radial
            )

        let tangentialLength =
            simd_length(
                tangential
            )

        guard tangentialLength.isFinite,
              tangentialLength > 0.0
        else {
            return .zero
        }

        tangential /=
            tangentialLength

        return SIMD3<Float>(
            Float(
                tangential.x *
                magnitude
            ),
            Float(
                tangential.y *
                magnitude
            ),
            Float(
                tangential.z *
                magnitude
            )
        )
    }

    // ========================================================
    // MAGNETIC ENERGY DENSITY
    //
    // u_B = B² / (2 * mu_0)
    //
    // ========================================================

    func magneticEnergyDensity(
        at position: SIMD3<Float>
    ) -> Double {

        let B =
            magneticField(
                at: position
            )

        let magnitudeSquared =
            Double(B.x) * Double(B.x) +
            Double(B.y) * Double(B.y) +
            Double(B.z) * Double(B.z)

        guard magnitudeSquared.isFinite,
              magnitudeSquared >= 0.0
        else {
            return 0.0
        }

        let mu0 =
            4.0 *
            Double.pi *
            1.0e-7

        let energy =
            magnitudeSquared /
            (
                2.0 *
                mu0
            )

        guard energy.isFinite,
              energy >= 0.0
        else {
            return 0.0
        }

        return energy
    }

    // ========================================================
    // QRTL ENERGY DENSITY
    //
    // This is the independent QRTL energy field.
    //
    // u_Q =
    //
    //     S_Q * v_Q² * eta_Q
    //
    //     +
    //
    //     electromagneticInfluence * chi_Q
    //
    //     +
    //
    //     magnetic energy density
    //
    // ========================================================

    func qrtlEnergyDensity(
        at position: SIMD3<Float>
    ) -> Double {

        let source =
            qrtlSource(
                at: position
            )

        let velocity =
            max(
                parameters.qrtlVelocity,
                0.0
            )

        let eta =
            max(
                parameters.etaQ,
                0.0
            )

        let chi =
            max(
                parameters.chiQ,
                0.0
            )

        let kineticFactor =
            velocity *
            velocity

        let electromagnetic =
            electromagneticInfluence(
                at: position
            )

        let magnetic =
            magneticEnergyDensity(
                at: position
            )

        let energy =
            (
                source *
                kineticFactor *
                eta
            )
            +
            (
                electromagnetic *
                chi
            )
            +
            magnetic

        guard energy.isFinite,
              energy >= 0.0
        else {
            return 0.0
        }

        return energy
    }

    // ========================================================
    // EFFECTIVE QRTL MASS DENSITY
    //
    // rho_Q = u_Q / c²
    //
    // ========================================================

    func qrtlEffectiveMassDensity(
        at position: SIMD3<Float>
    ) -> Double {

        let energy =
            qrtlEnergyDensity(
                at: position
            )

        let density =
            energy /
            speedOfLightSquared

        guard density.isFinite,
              density >= 0.0
        else {
            return 0.0
        }

        return density
    }

    // ========================================================
    // QRTL GRAVITY INDEX
    //
    // Global calibration factor:
    //
    // qrtlGravityIndex =
    //
    //     average physical density
    //     -------------------------
    //     average QRTL effective density
    //
    // ========================================================

    lazy var qrtlGravityIndex: Double = {

        let radialFractions: [Double] = [
            0.0,
            0.125,
            0.25,
            0.375,
            0.50,
            0.625,
            0.75,
            0.875,
            1.0
        ]

        let angularDirections: [SIMD3<Double>] = [

            SIMD3<Double>(
                1.0,
                0.0,
                0.0
            ),

            SIMD3<Double>(
                -1.0,
                0.0,
                0.0
            ),

            SIMD3<Double>(
                0.0,
                1.0,
                0.0
            ),

            SIMD3<Double>(
                0.0,
                -1.0,
                0.0
            ),

            SIMD3<Double>(
                0.0,
                0.0,
                1.0
            ),

            SIMD3<Double>(
                0.0,
                0.0,
                -1.0
            ),

            simd_normalize(
                SIMD3<Double>(
                    1.0,
                    1.0,
                    1.0
                )
            ),

            simd_normalize(
                SIMD3<Double>(
                    -1.0,
                    1.0,
                    1.0
                )
            )
        ]

        var physicalDensitySum =
            0.0

        var qrtlDensitySum =
            0.0

        var sampleCount =
            0.0

        for fraction in radialFractions {

            let radius =
                clusterRadiusMeters *
                fraction

            for direction in angularDirections {

                let p =
                    SIMD3<Float>(
                        Float(
                            direction.x *
                            radius
                        ),
                        Float(
                            direction.y *
                            radius
                        ),
                        Float(
                            direction.z *
                            radius
                        )
                    )

                let physical =
                    physicalMassDensity(
                        at: p
                    )

                let qrtl =
                    qrtlEffectiveMassDensity(
                        at: p
                    )

                guard physical.isFinite,
                      qrtl.isFinite,
                      physical >= 0.0,
                      qrtl >= 0.0
                else {
                    continue
                }

                physicalDensitySum +=
                    physical

                qrtlDensitySum +=
                    qrtl

                sampleCount +=
                    1.0
            }
        }

        guard sampleCount > 0.0,
              physicalDensitySum.isFinite,
              qrtlDensitySum.isFinite,
              qrtlDensitySum > 0.0
        else {
            return 0.0
        }

        let averagePhysicalDensity =
            physicalDensitySum /
            sampleCount

        let averageQRTLMassDensity =
            qrtlDensitySum /
            sampleCount

        guard averagePhysicalDensity.isFinite,
              averagePhysicalDensity >= 0.0,
              averageQRTLMassDensity.isFinite,
              averageQRTLMassDensity > 0.0
        else {
            return 0.0
        }

        let index =
            averagePhysicalDensity /
            averageQRTLMassDensity

        guard index.isFinite,
              index >= 0.0
        else {
            return 0.0
        }

        return index
    }()

    // ========================================================
    // TOTAL CALIBRATED QRTL EFFECTIVE MASS
    //
    // M_Q =
    //
    // integral rho_Q(r) dV
    //
    // with global QRTL gravity calibration applied.
    //
    // ========================================================

    func qrtlTotalEffectiveMassKg() -> Double {

        let clusterRadius =
            clusterRadiusMeters

        let cSquared =
            speedOfLightSquared

        guard clusterRadius > 0.0,
              cSquared.isFinite,
              cSquared > 0.0
        else {
            return 0.0
        }

        let gravityIndex =
            qrtlGravityIndex

        guard gravityIndex.isFinite,
              gravityIndex >= 0.0
        else {
            return 0.0
        }

        let sampleCount =
            128

        let dr =
            clusterRadius /
            Double(sampleCount)

        guard dr.isFinite,
              dr > 0.0
        else {
            return 0.0
        }

        var totalMass =
            0.0

        for index in 0..<sampleCount {

            let r0 =
                Double(index) *
                dr

            let r1 =
                Double(index + 1) *
                dr

            let shellRadius =
                0.5 *
                (r0 + r1)

            let position =
                SIMD3<Float>(
                    Float(shellRadius),
                    0.0,
                    0.0
                )

            let energyDensity =
                qrtlEnergyDensity(
                    at: position
                )

            guard energyDensity.isFinite,
                  energyDensity >= 0.0
            else {
                continue
            }

            let massDensity =
                (
                    energyDensity /
                    cSquared
                ) *
                gravityIndex

            guard massDensity.isFinite,
                  massDensity >= 0.0
            else {
                continue
            }

            let shellVolume =
                (
                    4.0 *
                    Double.pi /
                    3.0
                ) *
                (
                    pow(r1, 3.0) -
                    pow(r0, 3.0)
                )

            guard shellVolume.isFinite,
                  shellVolume > 0.0
            else {
                continue
            }

            totalMass +=
                massDensity *
                shellVolume
        }

        guard totalMass.isFinite,
              totalMass >= 0.0
        else {
            return 0.0
        }

        return totalMass
    }

    // ========================================================
    // QRTL GRAVITATIONAL POTENTIAL
    //
    // Physical interpretation:
    //
    //     rho_Q = u_Q / c²
    //
    //     rho_calibrated =
    //         rho_Q * qrtlGravityIndex
    //
    //     Phi_Q =
    //         -G * integral(rho_calibrated / distance) dV
    //
    // For a spherical distribution:
    //
    //     Phi(r) =
    //
    //         -G M(<r) / r
    //
    //         -
    //
    //         G integral_r^R
    //         [dM(r') / r']
    //
    // ========================================================

    func qrtlGravitationalPotential(
        at position: SIMD3<Float>
    ) -> Double {

        let radius =
            Double(
                simd_length(position)
            )

        guard radius.isFinite,
              radius >= 0.0
        else {
            return 0.0
        }

        let G =
            gravitationalConstant

        let clusterRadius =
            clusterRadiusMeters

        let gravityIndex =
            qrtlGravityIndex

        guard G.isFinite,
              G > 0.0,
              clusterRadius.isFinite,
              clusterRadius > 0.0,
              gravityIndex.isFinite,
              gravityIndex >= 0.0
        else {
            return 0.0
        }

        let sampleCount =
            128

        let dr =
            clusterRadius /
            Double(sampleCount)

        guard dr.isFinite,
              dr > 0.0
        else {
            return 0.0
        }

        // ----------------------------------------------------
        // Outside the cluster
        //
        // Phi = -GM/r
        // ----------------------------------------------------

        if radius >= clusterRadius {

            let totalMass =
                qrtlTotalEffectiveMassKg()

            guard totalMass.isFinite,
                  totalMass >= 0.0
            else {
                return 0.0
            }

            let safeRadius =
                max(
                    radius,
                    1.0e-12
                )

            let potential =
                -G *
                totalMass /
                safeRadius

            return potential.isFinite
                ? potential
                : 0.0
        }

        // ----------------------------------------------------
        // Inside the cluster
        // ----------------------------------------------------

        let integrationRadius =
            min(
                radius,
                clusterRadius
            )

        var enclosedMass =
            0.0

        if integrationRadius > 0.0 {

            let numberOfSamples =
                max(
                    1,
                    min(
                        sampleCount,
                        Int(
                            ceil(
                                integrationRadius /
                                dr
                            )
                        )
                    )
                )

            for index in 0..<numberOfSamples {

                let r0 =
                    Double(index) *
                    dr

                let r1 =
                    min(
                        Double(index + 1) *
                        dr,
                        integrationRadius
                    )

                guard r1 > r0
                else {
                    continue
                }

                let shellRadius =
                    0.5 *
                    (r0 + r1)

                let samplePosition =
                    SIMD3<Float>(
                        Float(shellRadius),
                        0.0,
                        0.0
                    )

                let energyDensity =
                    qrtlEnergyDensity(
                        at: samplePosition
                    )

                guard energyDensity.isFinite,
                      energyDensity >= 0.0
                else {
                    continue
                }

                let rawMassDensity =
                    energyDensity /
                    speedOfLightSquared

                guard rawMassDensity.isFinite,
                      rawMassDensity >= 0.0
                else {
                    continue
                }

                let calibratedMassDensity =
                    rawMassDensity *
                    gravityIndex

                guard calibratedMassDensity.isFinite,
                      calibratedMassDensity >= 0.0
                else {
                    continue
                }

                let shellVolume =
                    (
                        4.0 *
                        Double.pi /
                        3.0
                    ) *
                    (
                        pow(r1, 3.0) -
                        pow(r0, 3.0)
                    )

                guard shellVolume.isFinite,
                      shellVolume > 0.0
                else {
                    continue
                }

                enclosedMass +=
                    calibratedMassDensity *
                    shellVolume
            }
        }

        // ----------------------------------------------------
        // Exterior shell contribution
        //
        // For shells outside r:
        //
        //     dPhi = -G dM / r_shell
        //
        // ----------------------------------------------------

        var exteriorPotentialIntegral =
            0.0

        for index in 0..<sampleCount {

            let r0 =
                Double(index) *
                dr

            let r1 =
                Double(index + 1) *
                dr

            guard r1 > radius
            else {
                continue
            }

            let shellRadius =
                0.5 *
                (r0 + r1)

            let samplePosition =
                SIMD3<Float>(
                    Float(shellRadius),
                    0.0,
                    0.0
                )

            let energyDensity =
                qrtlEnergyDensity(
                    at: samplePosition
                )

            guard energyDensity.isFinite,
                  energyDensity >= 0.0
            else {
                continue
            }

            let rawMassDensity =
                energyDensity /
                speedOfLightSquared

            guard rawMassDensity.isFinite,
                  rawMassDensity >= 0.0
            else {
                continue
            }

            let calibratedMassDensity =
                rawMassDensity *
                gravityIndex

            guard calibratedMassDensity.isFinite,
                  calibratedMassDensity >= 0.0
            else {
                continue
            }

            let shellVolume =
                (
                    4.0 *
                    Double.pi /
                    3.0
                ) *
                (
                    pow(r1, 3.0) -
                    pow(r0, 3.0)
                )

            guard shellVolume.isFinite,
                  shellVolume > 0.0
            else {
                continue
            }

            let shellMass =
                calibratedMassDensity *
                shellVolume

            guard shellMass.isFinite,
                  shellMass >= 0.0
            else {
                continue
            }

            exteriorPotentialIntegral +=
                shellMass /
                max(
                    shellRadius,
                    1.0e-12
                )
        }

        // ----------------------------------------------------
        // Enclosed mass contribution
        // ----------------------------------------------------

        let safeRadius =
            max(
                radius,
                1.0e-12
            )

        let enclosedPotential =
            enclosedMass > 0.0
            ? -G *
              enclosedMass /
              safeRadius
            : 0.0

        // ----------------------------------------------------
        // Exterior shell contribution
        // ----------------------------------------------------

        let exteriorPotential =
            -G *
            exteriorPotentialIntegral

        // ----------------------------------------------------
        // Total QRTL potential
        // ----------------------------------------------------

        let potential =
            enclosedPotential +
            exteriorPotential

        guard potential.isFinite
        else {
            return 0.0
        }

        return potential
    }

    // ========================================================
    // QRTL GRAVITATIONAL ACCELERATION
    //
    // The acceleration is derived numerically from the QRTL
    // gravitational potential:
    //
    //     g = -grad(Phi_Q)
    //
    // This keeps the acceleration and potential mathematically
    // consistent.
    // ========================================================

    func qrtlGravitationalAcceleration(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radius =
            Double(
                simd_length(position)
            )

        guard radius.isFinite
        else {
            return .zero
        }

        let h =
            max(
                radius * 1.0e-3,
                1.0
            )

        let step =
            Float(h)

        guard step.isFinite,
              step > 0.0
        else {
            return .zero
        }

        let dx =
            SIMD3<Float>(
                step,
                0.0,
                0.0
            )

        let dy =
            SIMD3<Float>(
                0.0,
                step,
                0.0
            )

        let dz =
            SIMD3<Float>(
                0.0,
                0.0,
                step
            )

        let potentialXPlus =
            qrtlGravitationalPotential(
                at:
                    position + dx
            )

        let potentialXMinus =
            qrtlGravitationalPotential(
                at:
                    position - dx
            )

        let potentialYPlus =
            qrtlGravitationalPotential(
                at:
                    position + dy
            )

        let potentialYMinus =
            qrtlGravitationalPotential(
                at:
                    position - dy
            )

        let potentialZPlus =
            qrtlGravitationalPotential(
                at:
                    position + dz
            )

        let potentialZMinus =
            qrtlGravitationalPotential(
                at:
                    position - dz
            )

        guard potentialXPlus.isFinite,
              potentialXMinus.isFinite,
              potentialYPlus.isFinite,
              potentialYMinus.isFinite,
              potentialZPlus.isFinite,
              potentialZMinus.isFinite
        else {
            return .zero
        }

        let denominator =
            2.0 *
            Double(step)

        guard denominator.isFinite,
              denominator > 0.0
        else {
            return .zero
        }

        let dPhiDx =
            (
                potentialXPlus -
                potentialXMinus
            ) /
            denominator

        let dPhiDy =
            (
                potentialYPlus -
                potentialYMinus
            ) /
            denominator

        let dPhiDz =
            (
                potentialZPlus -
                potentialZMinus
            ) /
            denominator

        let acceleration =
            SIMD3<Float>(
                Float(-dPhiDx),
                Float(-dPhiDy),
                Float(-dPhiDz)
            )

        guard acceleration.x.isFinite,
              acceleration.y.isFinite,
              acceleration.z.isFinite
        else {
            return .zero
        }

        return acceleration
    }

    // ========================================================
    // TRANSVERSE QRTL GRAVITY
    //
    // Only the component perpendicular to the photon direction
    // changes the direction of propagation.
    // ========================================================

    func qrtlTransverseGravity(
        at position: SIMD3<Float>,
        photonDirection: SIMD3<Float>
    ) -> SIMD3<Float> {

        let gravity =
            qrtlGravitationalAcceleration(
                at: position
            )

        let directionLength =
            simd_length(
                photonDirection
            )

        guard directionLength.isFinite,
              directionLength > 0.0
        else {
            return .zero
        }

        let direction =
            photonDirection /
            directionLength

        let parallel =
            simd_dot(
                gravity,
                direction
            )

        return gravity -
            direction *
            parallel
    }

    // ========================================================
    // EINSTEIN-STYLE PHOTON CURVATURE
    //
    // kappa =
    //
    //     -2 g_perpendicular / c²
    //
    // ========================================================

    func qrtlPhotonCurvature(
        at position: SIMD3<Float>,
        direction: SIMD3<Float>
    ) -> SIMD3<Float> {

        let transverseGravity =
            qrtlTransverseGravity(
                at: position,
                photonDirection: direction
            )

        let magnitude =
            simd_length(
                transverseGravity
            )

        guard magnitude.isFinite,
              magnitude > 0.0
        else {
            return .zero
        }

        let curvatureMagnitude =
            -2.0 *
            Double(magnitude) /
            speedOfLightSquared

        guard curvatureMagnitude.isFinite
        else {
            return .zero
        }

        let curvatureDirection =
            transverseGravity /
            magnitude

        let curvature =
            curvatureDirection *
            Float(
                curvatureMagnitude
            )

        guard curvature.x.isFinite,
              curvature.y.isFinite,
              curvature.z.isFinite
        else {
            return .zero
        }

        return curvature
    }

    // ========================================================
    // GRAVITATIONAL OPTICAL INDEX
    //
    // n_G = 1 - 2 Phi / c²
    //
    // Since Phi is negative, n_G > 1 near the mass.
    //
    // ========================================================

    func gravitationalIndex(
        at position: SIMD3<Float>
    ) -> Double {

        let potential =
            qrtlGravitationalPotential(
                at: position
            )

        guard potential.isFinite
        else {
            return 1.0
        }

        let normalized =
            -2.0 *
            potential /
            speedOfLightSquared

        let index =
            1.0 +
            normalized

        guard index.isFinite,
              index > 0.0
        else {
            return 1.0
        }

        return index
    }

    // ========================================================
    // ELECTROMAGNETIC OPTICAL CONTRIBUTION
    // ========================================================

    func electromagneticOpticalContribution(
        at position: SIMD3<Float>
    ) -> Double {

        let influence =
            electromagneticInfluence(
                at: position
            )

        let coupling =
            max(
                parameters.photonEMCoupling,
                0.0
            )

        let contribution =
            coupling *
            influence

        guard contribution.isFinite,
              contribution >= 0.0
        else {
            return 0.0
        }

        return contribution
    }

    // ========================================================
    // TOTAL OPTICAL INDEX
    //
    // n_total =
    //
    //     n_G * (1 + n_EM)
    //
    // ========================================================

    func totalIndex(
        at position: SIMD3<Float>
    ) -> Double {

        let gravitational =
            gravitationalIndex(
                at: position
            )

        let electromagnetic =
            electromagneticOpticalContribution(
                at: position
            )

        let index =
            gravitational *
            (
                1.0 +
                electromagnetic
            )

        guard index.isFinite,
              index > 0.0
        else {
            return 1.0
        }

        return index
    }

    // ========================================================
    // INDEX GRADIENT
    //
    // Numerical gradient of the total optical index.
    // ========================================================

    func indexGradient(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radius =
            max(
                simd_length(position),
                1.0
            )

        let h =
            Float(
                max(
                    radius * 1.0e-3,
                    1.0
                )
            )

        let dx =
            SIMD3<Float>(
                h,
                0.0,
                0.0
            )

        let dy =
            SIMD3<Float>(
                0.0,
                h,
                0.0
            )

        let dz =
            SIMD3<Float>(
                0.0,
                0.0,
                h
            )

        let xGradient =
            (
                totalIndex(
                    at:
                        position + dx
                )
                -
                totalIndex(
                    at:
                        position - dx
                )
            )
            /
            Double(
                2.0 * h
            )

        let yGradient =
            (
                totalIndex(
                    at:
                        position + dy
                )
                -
                totalIndex(
                    at:
                        position - dy
                )
            )
            /
            Double(
                2.0 * h
            )

        let zGradient =
            (
                totalIndex(
                    at:
                        position + dz
                )
                -
                totalIndex(
                    at:
                        position - dz
                )
            )
            /
            Double(
                2.0 * h
            )

        guard xGradient.isFinite,
              yGradient.isFinite,
              zGradient.isFinite
        else {
            return .zero
        }

        return SIMD3<Float>(
            Float(xGradient),
            Float(yGradient),
            Float(zGradient)
        )
    }

    // ========================================================
    // QRTL LENSING ACCELERATION
    //
    // Combines:
    //
    // 1. Einstein-style gravitational curvature
    // 2. Transverse optical-index gradient
    //
    // ========================================================

    func qrtlLensingAcceleration(
        at position: SIMD3<Float>,
        direction: SIMD3<Float>
    ) -> SIMD3<Float> {

        let gravitationalCurvature =
            qrtlPhotonCurvature(
                at: position,
                direction: direction
            )

        let gradient =
            indexGradient(
                at: position
            )

        let directionLength =
            simd_length(
                direction
            )

        guard directionLength.isFinite,
              directionLength > 0.0
        else {
            return gravitationalCurvature
        }

        let normalizedDirection =
            direction /
            directionLength

        let gradientParallel =
            simd_dot(
                gradient,
                normalizedDirection
            )

        let transverseGradient =
            gradient -
            normalizedDirection *
            gradientParallel

        let electromagneticScale =
            Float(
                max(
                    parameters.photonEMCoupling,
                    0.0
                )
            )

        let opticalCurvature =
            -transverseGradient *
            electromagneticScale

        let result =
            gravitationalCurvature +
            opticalCurvature

        guard result.x.isFinite,
              result.y.isFinite,
              result.z.isFinite
        else {
            return .zero
        }

        return result
    }

    // ========================================================
    // COMPLETE FIELD SAMPLE
    // ========================================================

    struct Sample {

        let position:
            SIMD3<Float>

        let massDensity:
            Double

        let normalizedDensity:
            Double

        let qrtlSource:
            Double

        let bolgarinoFlux:
            Double

        let qrtlCurrent:
            Double

        let electromagneticInfluence:
            Double

        let magneticEnergyDensity:
            Double

        let qrtlEnergyDensity:
            Double

        let qrtlEffectiveMassDensity:
            Double

        let physicalPotential:
            Double

        let qrtlPotential:
            Double

        let physicalAcceleration:
            SIMD3<Float>

        let qrtlAcceleration:
            SIMD3<Float>

        let qrtlGravityIndex:
            Double

        let gravitationalIndex:
            Double

        let totalIndex:
            Double
    }

    // ========================================================
    // SAMPLE
    // ========================================================

    func sample(
        at position: SIMD3<Float>
    ) -> Sample {

        let physicalDensity =
            physicalMassDensity(
                at: position
            )

        let normalized =
            Double(
                normalizedDensity(
                    at: position
                )
            )

        let source =
            qrtlSource(
                at: position
            )

        let flux =
            bolgarinoFlux(
                at: position
            )

        let current =
            qrtlCurrent(
                at: position
            )

        let electromagnetic =
            electromagneticInfluence(
                at: position
            )

        let magneticEnergy =
            magneticEnergyDensity(
                at: position
            )

        let qrtlEnergy =
            qrtlEnergyDensity(
                at: position
            )

        let qrtlMass =
            qrtlEffectiveMassDensity(
                at: position
            )

        let physicalPotential =
            physicalGravitationalPotential(
                at: position
            )

        let qrtlPotential =
            qrtlGravitationalPotential(
                at: position
            )

        let physicalAcceleration =
            physicalGravitationalAcceleration(
                at: position
            )

        let qrtlAcceleration =
            qrtlGravitationalAcceleration(
                at: position
            )

        let gravityIndex =
            gravitationalIndex(
                at: position
            )

        let opticalIndex =
            totalIndex(
                at: position
            )

        return Sample(

            position:
                position,

            massDensity:
                physicalDensity,

            normalizedDensity:
                normalized,

            qrtlSource:
                source,

            bolgarinoFlux:
                flux,

            qrtlCurrent:
                current,

            electromagneticInfluence:
                electromagnetic,

            magneticEnergyDensity:
                magneticEnergy,

            qrtlEnergyDensity:
                qrtlEnergy,

            qrtlEffectiveMassDensity:
                qrtlMass,

            physicalPotential:
                physicalPotential,

            qrtlPotential:
                qrtlPotential,

            physicalAcceleration:
                physicalAcceleration,

            qrtlAcceleration:
                qrtlAcceleration,

            qrtlGravityIndex:
                qrtlGravityIndex,

            gravitationalIndex:
                gravityIndex,

            totalIndex:
                opticalIndex
        )
    }

    // ========================================================
    // DIAGNOSTIC
    // ========================================================

    func diagnoseQRTLField(
        at position: SIMD3<Float>
    ) {

        let s =
            sample(
                at: position
            )

        print(
            """
            ============================================================
            QRTL FIELD DIAGNOSTIC
            ============================================================

            Position:
                \(position)

            Physical total mass:
                \(physicalTotalMassKg)

            Physical mass density:
                \(s.massDensity)

            Normalized density:
                \(s.normalizedDensity)

            QRTL source:
                \(s.qrtlSource)

            Bolgarino flux:
                \(s.bolgarinoFlux)

            QRTL current:
                \(s.qrtlCurrent)

            Electromagnetic influence:
                \(s.electromagneticInfluence)

            Magnetic energy density:
                \(s.magneticEnergyDensity)

            QRTL energy density:
                \(s.qrtlEnergyDensity)

            QRTL effective mass density:
                \(s.qrtlEffectiveMassDensity)

            QRTL total effective mass:
                \(qrtlTotalEffectiveMassKg())

            Physical gravitational potential:
                \(s.physicalPotential)

            QRTL gravitational potential:
                \(s.qrtlPotential)

            Physical gravitational acceleration:
                \(s.physicalAcceleration)

            QRTL gravitational acceleration:
                \(s.qrtlAcceleration)

            QRTL gravity index:
                \(s.qrtlGravityIndex)

            Gravitational optical index:
                \(s.gravitationalIndex)

            Total optical index:
                \(s.totalIndex)

            ============================================================
            """
        )
    }
}
