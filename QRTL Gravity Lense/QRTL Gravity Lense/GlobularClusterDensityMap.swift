//
//  GlobularClusterDensityMap.swift
//  QRTL Gravity Lense
//
//  Continuous spherical mass model for the globular cluster.
//
//  IMPORTANT:
//  The star positions are retained for visualization/source photons,
//  but gravitational density is NOT calculated by looking up a
//  microscopic spatial cell.
//
//  The gravitational field uses a continuous Plummer profile:
//
//      rho(r) = (3 M / 4 pi a^3) (1 + r^2/a^2)^(-5/2)
//
//      M(r) = M r^3 / (r^2 + a^2)^(3/2)
//
//      Phi(r) = -G M / sqrt(r^2 + a^2)
//
//  This guarantees a nonzero, continuous interior field.
//

import Foundation
import simd

// ============================================================
// GLOBULAR CLUSTER DENSITY MAP
// ============================================================

final class GlobularClusterDensityMap:
    GlobularClusterDensitySource {

    // ========================================================
    // CONSTANTS
    // ========================================================

    let gravitationalConstant: Double =
        6.67430e-11

    // ========================================================
    // CLUSTER PARAMETERS
    // ========================================================

    let clusterMassKg: Double

    let clusterRadiusMeters: Float

    let starCount: Int

    // ========================================================
    // PLUMMER SCALE
    //
    // This controls the concentration of the continuous
    // spherical mass distribution.
    //
    // A smaller value produces a denser center.
    // ========================================================

    let plummerScaleMeters: Double

    // ========================================================
    // STAR POSITIONS
    //
    // Retained for rendering and photon-source generation.
    // They are NOT used as a discrete density lookup.
    // ========================================================

    let starPositions: [SIMD3<Float>]

    // ========================================================
    // LEGACY CELL SIZE
    //
    // Kept only for source compatibility with code that may
    // still reference this property.
    //
    // It is NO LONGER used to calculate gravitational density.
    // ========================================================

    let cellSizeMeters: Float = 1.0e9



    var totalMass: Float {

        let value =
            Float(clusterMassKg)

        guard
            value.isFinite,
            value >= 0.0
        else {
            return 0.0
        }

        return value
    }

    // ============================================================
    // MAXIMUM DENSITY
    // ============================================================
    //
    // Plummer central density:
    //
    // rho(0) = 3M / (4πa³)
    //
    // ============================================================

    var maximumDensity: Float {

        let a =
            max(
                plummerScaleMeters,
                1.0
            )

        let mass =
            clusterMassKg

        guard
            mass.isFinite,
            mass > 0.0
        else {
            return 0.0
        }

        let value =
            3.0 * mass /
            (
                4.0 *
                Double.pi *
                a *
                a *
                a
            )

        guard
            value.isFinite,
            value >= 0.0
        else {
            return 0.0
        }

        return Float(value)
    }

    // ============================================================
    // INTEGRATED DENSITY
    // ============================================================
    //
    // ∫ρ dV = total cluster mass
    //
    // ============================================================

    var integratedDensity: Float {

        return totalMass
    }

    // ============================================================
    // FIELD RADIUS
    // ============================================================

    var fieldRadiusMeters: Float {

        let value =
            clusterRadiusMeters

        guard
            value.isFinite,
            value > 0.0
        else {
            return 0.0
        }

        return value
    }

    // ============================================================
    // MASS PER SOURCE STAR
    // ============================================================
    //
    // Each rendered/source star represents:
    //
    //     total cluster mass / number of stars
    //
    // This does NOT replace the continuous Plummer field.
    // ============================================================

    var perStarMassKg: Float {

        guard
            starCount > 0,
            clusterMassKg.isFinite,
            clusterMassKg > 0.0
        else {
            return 0.0
        }

        let value =
            clusterMassKg /
            Double(starCount)

        guard
            value.isFinite,
            value >= 0.0
        else {
            return 0.0
        }

        return Float(value)
    }

    init(
        clusterMassKg: Double,
        clusterRadiusMeters: Float,
        starPositions: [SIMD3<Float>],
        plummerScaleFraction: Double = 0.30
    ) {

        self.clusterMassKg =
            max(
                clusterMassKg,
                0.0
            )

        self.clusterRadiusMeters =
            max(
                clusterRadiusMeters,
                1.0
            )

        self.starPositions =
            starPositions

        self.starCount =
            starPositions.count

        let safeFraction =
            min(
                max(
                    plummerScaleFraction,
                    0.01
                ),
                1.0
            )

        self.plummerScaleMeters =
            max(
                Double(clusterRadiusMeters) *
                safeFraction,
                1.0
            )
    }

    // ============================================================
    // CONVENIENCE INITIALIZER
    // ============================================================
    //
    // Useful when the cluster has a radius and star count but
    // positions are generated elsewhere.
    //
    // ============================================================

    convenience init(
        clusterMassKg: Double,
        clusterRadiusMeters: Float,
        starCount: Int
    ) {

        self.init(
            clusterMassKg:
                clusterMassKg,

            clusterRadiusMeters:
                clusterRadiusMeters,

            starPositions:
                Array(
                    repeating:
                        SIMD3<Float>.zero,
                    count:
                        max(
                            starCount,
                            0
                        )
                )
        )
    }

    // ============================================================
    // RADIUS
    // ============================================================

    func radius(
        at position: SIMD3<Float>
    ) -> Double {

        let x =
            Double(position.x)

        let y =
            Double(position.y)

        let z =
            Double(position.z)

        let radiusSquared =
            x * x +
            y * y +
            z * z

        guard radiusSquared.isFinite,
              radiusSquared >= 0.0
        else {
            return 0.0
        }

        return sqrt(
            radiusSquared
        )
    }

    // ============================================================
    // NORMALIZED RADIUS
    // ============================================================

    func normalizedRadius(
        at position: SIMD3<Float>
    ) -> Double {

        let r =
            radius(
                at:
                    position
            )

        let clusterRadius =
            Double(
                clusterRadiusMeters
            )

        guard clusterRadius > 0.0 else {
            return 0.0
        }

        return r /
            clusterRadius
    }

    // ============================================================
    // CONTINUOUS MASS DENSITY
    //
    // Plummer density:
    //
    // rho(r) =
    //
    // 3M
    // ───────────────
    // 4 pi a^3
    //
    // ×
    //
    // (1 + r²/a²)^(-5/2)
    //
    // This is evaluated continuously at every point.
    // ============================================================

    func density(
        at position: SIMD3<Float>
    ) -> Float {

        let r =
            radius(
                at:
                    position
            )

        let clusterRadius =
            Double(
                clusterRadiusMeters
            )

        guard r <= clusterRadius else {
            return 0.0
        }

        let mass =
            clusterMassKg

        guard mass > 0.0,
              mass.isFinite
        else {
            return 0.0
        }

        let a =
            max(
                plummerScaleMeters,
                1.0
            )

        let aSquared =
            a * a

        let rSquared =
            r * r

        let denominator =
            pow(
                1.0 +
                rSquared /
                aSquared,
                2.5
            )

        guard denominator.isFinite,
              denominator > 0.0
        else {
            return 0.0
        }

        let normalization =
            3.0 *
            mass /
            (
                4.0 *
                Double.pi *
                a *
                a *
                a
            )

        let density =
            normalization /
            denominator

        guard density.isFinite,
              density >= 0.0
        else {
            return 0.0
        }

        return Float(
            density
        )
    }

    // ============================================================
    // PHYSICAL MASS DENSITY
    //
    // This intentionally does NOT perform a cell lookup.
    // ============================================================

    func physicalMassDensity(
        at position: SIMD3<Float>
    ) -> Double {

        let value =
            Double(
                density(
                    at:
                        position
                )
            )

        guard value.isFinite,
              value >= 0.0
        else {
            return 0.0
        }

        return value
    }

    // ============================================================
    // CENTER DENSITY
    // ============================================================

    var centerDensity: Double {

        return physicalMassDensity(
            at:
                .zero
        )
    }

    // ============================================================
    // NORMALIZED DENSITY
    //
    // 0 ... 1 relative to center density.
    // ============================================================

    func normalizedDensity(
        at position: SIMD3<Float>
    ) -> Float {

        let current =
            physicalMassDensity(
                at:
                    position
            )

        let center =
            centerDensity

        guard center > 0.0,
              center.isFinite,
              current.isFinite
        else {
            return 0.0
        }

        let normalized =
            current /
            center

        guard normalized.isFinite else {
            return 0.0
        }

        return Float(
            min(
                max(
                    normalized,
                    0.0
                ),
                1.0
            )
        )
    }

    // ============================================================
    // ENCLOSED MASS
    //
    // Plummer enclosed mass:
    //
    // M(r) =
    //
    // M r³
    // ───────────────
    // (r² + a²)^(3/2)
    //
    // This is continuous everywhere.
    // ============================================================

    func enclosedMass(
        at position: SIMD3<Float>
    ) -> Double {

        let r =
            radius(
                at:
                    position
            )

        guard r > 0.0 else {
            return 0.0
        }

        let clusterRadius =
            Double(
                clusterRadiusMeters
            )

        if r >= clusterRadius {
            return clusterMassKg
        }

        let a =
            max(
                plummerScaleMeters,
                1.0
            )

        let rSquared =
            r * r

        let aSquared =
            a * a

        let denominator =
            pow(
                rSquared +
                aSquared,
                1.5
            )

        guard denominator.isFinite,
              denominator > 0.0
        else {
            return 0.0
        }

        let mass =
            clusterMassKg *
            r *
            r *
            r /
            denominator

        guard mass.isFinite,
              mass >= 0.0
        else {
            return 0.0
        }

        return min(
            mass,
            clusterMassKg
        )
    }

    // ============================================================
    // ENCLOSED MASS FRACTION
    // ============================================================

    func enclosedMassFraction(
        at position: SIMD3<Float>
    ) -> Double {

        guard clusterMassKg > 0.0 else {
            return 0.0
        }

        let mass =
            enclosedMass(
                at:
                    position
            )

        let fraction =
            mass /
            clusterMassKg

        guard fraction.isFinite else {
            return 0.0
        }

        return min(
            max(
                fraction,
                0.0
            ),
            1.0
        )
    }

    // ============================================================
    // GRAVITATIONAL POTENTIAL
    //
    // Plummer potential:
    //
    // Phi(r) =
    //
    //       -GM
    // ─────────────────
    // sqrt(r² + a²)
    //
    // Unlike the previous sparse-grid implementation, the
    // interior potential is NEVER zero merely because there
    // isn't a star in a local cell.
    // ============================================================

    func gravitationalPotential(
        at position: SIMD3<Float>
    ) -> Double {

        let r =
            radius(
                at:
                    position
            )

        let mass =
            clusterMassKg

        guard mass > 0.0,
              mass.isFinite
        else {
            return 0.0
        }

        let a =
            max(
                plummerScaleMeters,
                1.0
            )

        let denominator =
            sqrt(
                r * r +
                a * a
            )

        guard denominator.isFinite,
              denominator > 0.0
        else {
            return 0.0
        }

        let potential = -gravitationalConstant *
            mass /
            denominator

        guard potential.isFinite else {
            return 0.0
        }

        return potential
    }

    // ============================================================
    // GRAVITATIONAL ACCELERATION
    //
    // a(r) =
    //
    // -GM r
    // ─────────────────────────
    // (r² + a²)^(3/2)
    //
    // This is continuous and finite at the center.
    // ============================================================

    func gravitationalAcceleration(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let rSquared =
            Double(
                position.x
            ) *
            Double(
                position.x
            ) +
            Double(
                position.y
            ) *
            Double(
                position.y
            ) +
            Double(
                position.z
            ) *
            Double(
                position.z
            )

        guard rSquared.isFinite else {
            return .zero
        }

        let a =
            max(
                plummerScaleMeters,
                1.0
            )

        let denominator =
            pow(
                rSquared +
                a * a,
                1.5
            )

        guard denominator.isFinite,
              denominator > 0.0
        else {
            return .zero
        }

        let scale =
            -gravitationalConstant *
            clusterMassKg /
            denominator

        guard scale.isFinite else {
            return .zero
        }

        return SIMD3<Float>(
            Float(
                scale *
                Double(position.x)
            ),
            Float(
                scale *
                Double(position.y)
            ),
            Float(
                scale *
                Double(position.z)
            )
        )
    }

    // ============================================================
    // POTENTIAL GRADIENT
    //
    // ∇Phi = -acceleration
    // ============================================================

    func potentialGradient(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        return -gravitationalAcceleration(
                at:
                    position
            )
    }

    // ============================================================
    // STAR POSITION ACCESS
    // ============================================================

    func starPosition(
        at index: Int
    ) -> SIMD3<Float>? {

        guard starPositions.indices.contains(
            index
        )
        else {
            return nil
        }

        return starPositions[index]
    }

    // ============================================================
    // STAR COUNT
    // ============================================================

    var numberOfStars: Int {

        return starPositions.count
    }

    // ============================================================
    // DIAGNOSTIC SAMPLE
    // ============================================================

    struct DensitySample {

        let position: SIMD3<Float>

        let radiusMeters: Double

        let normalizedRadius: Double

        let density: Double

        let normalizedDensity: Double

        let enclosedMassKg: Double

        let enclosedMassFraction: Double

        let gravitationalPotential: Double

        let gravitationalAcceleration:
            SIMD3<Float>
    }

    // ============================================================
    // SAMPLE
    // ============================================================

    func sample(
        at position: SIMD3<Float>
    ) -> DensitySample {

        let r =
            radius(
                at:
                    position
            )

        let normalizedR =
            normalizedRadius(
                at:
                    position
            )

        let densityValue =
            physicalMassDensity(
                at:
                    position
            )

        let normalizedDensityValue =
            Double(
                normalizedDensity(
                    at:
                        position
                )
            )

        let enclosedMassValue =
            enclosedMass(
                at:
                    position
            )

        let enclosedFraction =
            enclosedMassFraction(
                at:
                    position
            )

        let potential =
            gravitationalPotential(
                at:
                    position
            )

        let acceleration =
            gravitationalAcceleration(
                at:
                    position
            )

        return DensitySample(

            position:
                position,

            radiusMeters:
                r,

            normalizedRadius:
                normalizedR,

            density:
                densityValue,

            normalizedDensity:
                normalizedDensityValue,

            enclosedMassKg:
                enclosedMassValue,

            enclosedMassFraction:
                enclosedFraction,

            gravitationalPotential:
                potential,

            gravitationalAcceleration:
                acceleration
        )
    }

    // ============================================================
    // VERIFY THE CONTINUOUS FIELD
    //
    // Useful for diagnostics/debugging.
    // ============================================================

    func diagnosticSamples()
        -> [DensitySample] {

        let radius =
            clusterRadiusMeters

        let fractions:
            [Float] =
            [
                0.0,
                0.25,
                0.50,
                0.75,
                0.90,
                0.99,
                1.00,
                1.25
            ]

        return fractions.map {

            let r =
                radius *
                $0

            let position =
                SIMD3<Float>(
                    r,
                    0.0,
                    0.0
                )

            return sample(
                at:
                    position
            )
        }
    }
}
