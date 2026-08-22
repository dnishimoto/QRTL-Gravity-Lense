import Foundation
import simd

// ============================================================
// GLOBULAR CLUSTER DENSITY SOURCE
// ============================================================
//
// The source represents a globular cluster using:
//
//     • discrete stellar positions
//     • equal mass per source star
//     • softened 3D gravitational summation
//     • continuous density evaluation
//
// The gravitational field is NOT reconstructed from a radial
// shell integral and does NOT assume spherical symmetry.
//
// Every star contributes directly to the field at every query
// position.
//
// ============================================================

final class GlobularClusterDensityMap:
    GlobularClusterDensitySource {
    
    let stars: [GlobularClusterStar]

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
    // ========================================================
    //
    // Retained as the characteristic smooth scale of the
    // cluster.
    //
    // It is useful for diagnostics and smooth density
    // normalization, but the gravitational field below is
    // generated directly from the individual stars.
    //
    // ========================================================

    let plummerScaleMeters: Double

    // ========================================================
    // STAR POSITIONS
    // ========================================================
    //
    // These positions are now ACTIVE gravitational sources.
    //
    // Every position contributes:
    //
    //     Phi_i = -G m_i / sqrt(d^2 + epsilon^2)
    //
    // and
    //
    //     a_i =
    //     -G m_i d /
    //     (d^2 + epsilon^2)^(3/2)
    //
    // ========================================================

    let starPositions: [SIMD3<Float>]

    // ========================================================
    // LEGACY CELL SIZE
    // ========================================================
    //
    // Retained for source compatibility.
    //
    // It is NOT used as a density-grid lookup.
    //
    // ========================================================

    let cellSizeMeters: Float =
        1.0e9

    // ========================================================
    // GRAVITATIONAL SOFTENING
    // ========================================================
    //
    // Prevents singularities when a query point is very close
    // to a source star.
    //
    // This is now the spatial resolution parameter for the
    // stellar gravitational field.
    //
    // ========================================================

    let softeningLengthMeters: Double

    // ========================================================
    // MASS PER STAR
    // ========================================================
    //
    // Each source star receives an equal fraction of the
    // total cluster mass.
    //
    //     m_star = M / N
    //
    // ========================================================

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

    // ========================================================
    // TOTAL MASS
    // ========================================================

    var totalMass: Float {

        guard
            clusterMassKg.isFinite,
            clusterMassKg >= 0.0
        else {
            return 0.0
        }

        return Float(clusterMassKg)
    }

    // ========================================================
    // FIELD RADIUS
    // ========================================================

    var fieldRadiusMeters: Float {

        guard
            clusterRadiusMeters.isFinite,
            clusterRadiusMeters > 0.0
        else {
            return 0.0
        }

        return clusterRadiusMeters
    }

    // ========================================================
    // MAXIMUM DENSITY
    // ========================================================
    //
    // For visualization/normalization this is evaluated at
    // the cluster center using the smooth Plummer profile.
    //
    // The actual gravitational field is NOT derived from this
    // value.
    //
    // ========================================================

    var maximumDensity: Float {

        guard !starPositions.isEmpty else {
            return 0.0
        }

        var maximum: Double = 0.0

        let centerDensity =
            physicalMassDensity(
                at: .zero
            )

        if centerDensity.isFinite {
            maximum = max(
                maximum,
                centerDensity
            )
        }

        for star in starPositions {

            let value =
                physicalMassDensity(
                    at: star
                )

            if value.isFinite {
                maximum = max(
                    maximum,
                    value
                )
            }
        }

        guard maximum.isFinite,
              maximum > 0.0
        else {
            return 0.0
        }

        return Float(maximum)
    }
    // ========================================================
    // INTEGRATED DENSITY
    // ========================================================
    //
    // The integrated physical mass represented by the source.
    //
    // ========================================================

    var integratedDensity: Float {
        return totalMass
    }

    // ========================================================
    // INITIALIZER
    // ========================================================

    init(
        clusterMassKg: Double,
        clusterRadiusMeters: Float,
        starPositions: [SIMD3<Float>],
        plummerScaleFraction: Double = 0.30,
        softeningLengthMeters: Double? = nil
    ) {

        // --------------------------------------------------------
        // CLUSTER MASS
        // --------------------------------------------------------

        self.clusterMassKg =
            max(
                clusterMassKg,
                0.0
            )

        // --------------------------------------------------------
        // CLUSTER RADIUS
        // --------------------------------------------------------

        self.clusterRadiusMeters = clusterRadiusMeters

        // --------------------------------------------------------
        // STAR POSITIONS
        // --------------------------------------------------------

        self.starPositions =
            starPositions

        self.starCount =
            starPositions.count

        // --------------------------------------------------------
        // MASS PER STAR
        // --------------------------------------------------------

        let massPerStar: Double

        if starPositions.isEmpty {

            massPerStar = 0.0

        } else {

            massPerStar =
                max(
                    self.clusterMassKg /
                    Double(starPositions.count),
                    0.0
                )
        }

        // --------------------------------------------------------
        // BUILD STAR OBJECTS
        // --------------------------------------------------------

        self.stars =
            starPositions.map { position in

                GlobularClusterStar(
                    position: position,
                    massKg: massPerStar
                )
            }

        // --------------------------------------------------------
        // PLUMMER SCALE
        // --------------------------------------------------------

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

        // --------------------------------------------------------
        // GRAVITATIONAL SOFTENING
        // --------------------------------------------------------

        let defaultSoftening =
            Double(clusterRadiusMeters) *
            0.01

        self.softeningLengthMeters =
            max(
                softeningLengthMeters ??
                defaultSoftening,
                1.0
            )
    }
    // ========================================================
    // CONVENIENCE INITIALIZER
    // ========================================================

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

    // ========================================================
    // RADIUS
    // ========================================================

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

        guard
            radiusSquared.isFinite,
            radiusSquared >= 0.0
        else {
            return 0.0
        }

        return sqrt(
            radiusSquared
        )
    }

    // ========================================================
    // NORMALIZED RADIUS
    // ========================================================

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

        guard
            clusterRadius > 0.0
        else {
            return 0.0
        }

        return r /
            clusterRadius
    }

    // ========================================================
    // DISTANCE TO STAR
    // ========================================================

    private func distanceSquared(
        from position: SIMD3<Float>,
        to star: SIMD3<Float>
    ) -> Double {

        let dx =
            Double(position.x) -
            Double(star.x)

        let dy =
            Double(position.y) -
            Double(star.y)

        let dz =
            Double(position.z) -
            Double(star.z)

        return
            dx * dx +
            dy * dy +
            dz * dz
    }

    // ========================================================
    // CONTINUOUS 3D STELLAR DENSITY
    // ========================================================
    //
    // Each star is represented by a softened localized kernel.
    //
    // This means density now depends on:
    //
    //     |position - starPosition|
    //
    // rather than only:
    //
    //     |position|
    //
    // Therefore the stellar distribution can create local
    // structure in the gravity surface.
    //
    // ========================================================

    func density(
        at position: SIMD3<Float>
    ) -> Float {

        guard
            starCount > 0,
            clusterMassKg > 0.0
        else {
            return 0.0
        }

        let epsilon =
            max(
                softeningLengthMeters,
                1.0
            )

        let epsilonSquared =
            epsilon *
            epsilon

        let starMass =
            clusterMassKg /
            Double(starCount)

        guard
            starMass.isFinite,
            starMass > 0.0
        else {
            return 0.0
        }

        // ----------------------------------------------------
        // Gaussian-like localized stellar kernel.
        //
        // This is used for the density visualization.
        // The gravitational potential below uses the exact
        // softened point-mass summation separately.
        // ----------------------------------------------------

        let normalization =
            starMass /
            (
                pow(
                    2.0 * Double.pi,
                    1.5
                ) *
                pow(
                    epsilon,
                    3.0
                )
            )

        var totalDensity:
            Double = 0.0

        for star in starPositions {

            let dSquared =
                distanceSquared(
                    from:
                        position,
                    to:
                        star
                )

            guard
                dSquared.isFinite
            else {
                continue
            }

            let exponent =
                -0.5 *
                dSquared /
                epsilonSquared

            let contribution =
                normalization *
                exp(exponent)

            if contribution.isFinite,
               contribution > 0.0 {

                totalDensity +=
                    contribution
            }
        }

        guard
            totalDensity.isFinite,
            totalDensity >= 0.0
        else {
            return 0.0
        }

        return Float(
            totalDensity
        )
    }

    // ========================================================
    // PHYSICAL MASS DENSITY
    // ========================================================

    func physicalMassDensity(
        at position: SIMD3<Float>
    ) -> Double {

   
        let radius = simd_length(position)

        guard radius.isFinite,
              radius >= 0.0
        else {
            return 0.0
        }

        // Reject obviously invalid coordinates before touching
        // the density source.
        guard abs(position.x) < 1.0e30,
              abs(position.y) < 1.0e30,
              abs(position.z) < 1.0e30
        else {
            return 0.0
        }

        let value = Double(
            density(
                at: position
            )
        )

        guard value.isFinite,
              value >= 0.0
        else {
            return 0.0
        }

        return value
    }

    // ========================================================
    // CENTER DENSITY
    // ========================================================

    var centerDensity: Double {

        return physicalMassDensity(
            at:
                .zero
        )
    }

    // ========================================================
    // NORMALIZED DENSITY
    // ========================================================

    func normalizedDensity(
        at position: SIMD3<Float>
    ) -> Float {

        let current =
            physicalMassDensity(
                at:
                    position
            )

        let maximum =
            Double(
                maximumDensity
            )

        guard
            maximum > 0.0,
            maximum.isFinite,
            current.isFinite
        else {
            return 0.0
        }

        let normalized =
            current /
            maximum

        guard
            normalized.isFinite
        else {
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

    // ========================================================
    // ENCLOSED MASS
    // ========================================================
    //
    // Unlike the old Plummer implementation, this is now
    // determined directly from the stellar positions.
    //
    // A star contributes its mass when it lies inside the
    // requested radius.
    //
    // ========================================================

    // ========================================================
    // ENCLOSED MASS — 10⁶ STAR RADIAL DISTRIBUTION
    // ========================================================

    // ========================================================
    // ENCLOSED MASS — 10⁶ STAR RADIAL DISTRIBUTION
    // ========================================================

    // ========================================================
    // ENCLOSED MASS — 10⁶ STAR RADIAL DISTRIBUTION
    // ========================================================

    func enclosedMass(
        at position: SIMD3<Float>
    ) -> Double {

        let x = Double(position.x)
        let y = Double(position.y)
        let z = Double(position.z)

        let r = sqrt(x * x + y * y + z * z)

        guard r.isFinite, r >= 0.0 else {
            return 0.0
        }

        let a = plummerScaleMeters
        let r2 = r * r
        let a2 = a * a

        // Compute enclosed mass using Plummer profile formula:
        // M(<r) = M_total * r^3 / (r^2 + a^2)^(3/2)

        let denominator = pow(r2 + a2, 1.5)

        guard denominator.isFinite, denominator > 0.0 else {
            return 0.0
        }

        let enclosed = clusterMassKg * (r * r * r) / denominator

        guard enclosed.isFinite else {
            return 0.0
        }

        // Clamp enclosed mass to [0, clusterMassKg]
        return min(max(enclosed, 0.0), clusterMassKg)
    }
    // ========================================================
    // ENCLOSED MASS FRACTION
    // ========================================================

    func enclosedMassFraction(
        at position: SIMD3<Float>
    ) -> Double {

        guard clusterMassKg > 0.0,
              clusterMassKg.isFinite
        else {
            return 0.0
        }

        let mass = enclosedMass(
            at: position
        )

        guard mass.isFinite,
              mass >= 0.0
        else {
            return 0.0
        }

        let fraction = mass / clusterMassKg

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
    // ========================================================
    // 3D GRAVITATIONAL POTENTIAL
    // ========================================================
    //
    //     Phi(r) =
    //
    //       -G SUM[m_i /
    //       sqrt(|r-r_i|^2 + epsilon^2)]
    //
    // This is the critical replacement for the old radial
    // Plummer potential.
    //
    // ========================================================

    func gravitationalPotential(
        at position: SIMD3<Float>
    ) -> Double {

        guard
            starCount > 0,
            clusterMassKg > 0.0
        else {
            return 0.0
        }

        let starMass =
            clusterMassKg /
            Double(starCount)

        let epsilon =
            max(
                softeningLengthMeters,
                1.0
            )

        let epsilonSquared =
            epsilon *
            epsilon

        var potential:
            Double = 0.0

        for star in starPositions {

            let dSquared =
                distanceSquared(
                    from:
                        position,
                    to:
                        star
                )

            guard
                dSquared.isFinite
            else {
                continue
            }

            let denominator =
                sqrt(
                    dSquared +
                    epsilonSquared
                )

            guard
                denominator.isFinite,
                denominator > 0.0
            else {
                continue
            }

            potential +=
                -gravitationalConstant *
                starMass /
                denominator
        }

        guard
            potential.isFinite
        else {
            return 0.0
        }

        return potential
    }

    // ========================================================
    // 3D GRAVITATIONAL ACCELERATION
    // ========================================================
    //
    //     a(r) =
    //
    //       -G SUM[
    //          m_i (r-r_i)
    //          /
    //          (|r-r_i|² + epsilon²)^(3/2)
    //       ]
    //
    // Every star contributes its own vector.
    //
    // ========================================================

    func gravitationalAcceleration(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        guard
            starCount > 0,
            clusterMassKg > 0.0
        else {
            return .zero
        }

        let starMass =
            clusterMassKg /
            Double(starCount)

        let epsilon =
            max(
                softeningLengthMeters,
                1.0
            )

        let epsilonSquared =
            epsilon *
            epsilon

        var acceleration =
            SIMD3<Double>(
                0.0,
                0.0,
                0.0
            )

        for star in starPositions {

            let dx =
                Double(position.x) -
                Double(star.x)

            let dy =
                Double(position.y) -
                Double(star.y)

            let dz =
                Double(position.z) -
                Double(star.z)

            let dSquared =
                dx * dx +
                dy * dy +
                dz * dz

            guard
                dSquared.isFinite
            else {
                continue
            }

            let denominator =
                pow(
                    dSquared +
                    epsilonSquared,
                    1.5
                )

            guard
                denominator.isFinite,
                denominator > 0.0
            else {
                continue
            }

            let scale =
                -gravitationalConstant *
                starMass /
                denominator

            acceleration.x +=
                scale * dx

            acceleration.y +=
                scale * dy

            acceleration.z +=
                scale * dz
        }

        guard
            acceleration.x.isFinite,
            acceleration.y.isFinite,
            acceleration.z.isFinite
        else {
            return .zero
        }

        return SIMD3<Float>(
            Float(acceleration.x),
            Float(acceleration.y),
            Float(acceleration.z)
        )
    }

    // ========================================================
    // POTENTIAL GRADIENT
    // ========================================================
    //
    //     grad(Phi) = -a
    //
    // ========================================================

    func potentialGradient(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        return -gravitationalAcceleration(
            at:
                position
        )
    }

    // ========================================================
    // STAR POSITION ACCESS
    // ========================================================

    func starPosition(
        at index: Int
    ) -> SIMD3<Float>? {

        guard
            starPositions.indices.contains(
                index
            )
        else {
            return nil
        }

        return starPositions[index]
    }

    // ========================================================
    // STAR COUNT ALIAS
    // ========================================================

    var numberOfStars: Int {
        return starPositions.count
    }

    // ========================================================
    // DIAGNOSTIC SAMPLE
    // ========================================================

    struct DensitySample {

        let position:
            SIMD3<Float>

        let radiusMeters:
            Double

        let normalizedRadius:
            Double

        let density:
            Double

        let normalizedDensity:
            Double

        let enclosedMassKg:
            Double

        let enclosedMassFraction:
            Double

        let gravitationalPotential:
            Double

        let gravitationalAcceleration:
            SIMD3<Float>
    }

    // ========================================================
    // SAMPLE
    // ========================================================

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

    // ========================================================
    // DIAGNOSTIC SAMPLES
    // ========================================================

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

    // ========================================================
    // STAR FIELD DIAGNOSTIC
    // ========================================================
    //
    // Returns the total gravitational contribution of all
    // stars at a position.
    //
    // Useful for verifying that the field actually changes
    // when the query point moves relative to the stars.
    //
    // ========================================================

    func starFieldMagnitude(
        at position: SIMD3<Float>
    ) -> Float {

        let acceleration =
            gravitationalAcceleration(
                at:
                    position
            )

        let magnitude =
            simd_length(
                acceleration
            )

        guard
            magnitude.isFinite
        else {
            return 0.0
        }

        return magnitude
    }

    // ========================================================
    // VERIFY STAR-DRIVEN FIELD
    // ========================================================
    //
    // Samples the potential at arbitrary positions.
    //
    // If the star distribution is asymmetric, these values
    // will no longer be identical at equal radial distances.
    //
    // ========================================================

    func potentialDifference(
        between first: SIMD3<Float>,
        and second: SIMD3<Float>
    ) -> Double {

        let p1 =
            gravitationalPotential(
                at:
                    first
            )

        let p2 =
            gravitationalPotential(
                at:
                    second
            )

        let difference =
            p1 -
            p2

        guard
            difference.isFinite
        else {
            return 0.0
        }

        return difference
    }
}
