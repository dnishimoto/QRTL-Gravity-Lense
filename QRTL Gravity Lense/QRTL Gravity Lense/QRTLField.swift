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
//  Einstein Weak-Field Potential
//          ↓
//  Spacetime Metric
//          ↓
//  Photon Transverse Deflection
//
//  QRTL / EM fields remain available as additional fields,
//  but Einstein gravity is the primary photon-lensing field.
//

import Foundation
import simd



// ============================================================
// QRTL FIELD
// ============================================================

final class QRTLField {

    // ========================================================
    // PRIMARY DATA
    // ========================================================

    let densitySource:
        GlobularClusterDensitySource

    let parameters:
        QRTLParameters

    let referenceDensity:
        Float

    // ========================================================
    // PHYSICAL CONSTANTS
    // ========================================================

    private let solarMassKg:
        Float = 1.98847e30

    /// Globular cluster total mass:
    ///
    ///     10^6 solar masses
    ///
    private var clusterMassKg:
        Float {

        1.0e6 *
        solarMassKg
    }

    private var gravitationalConstant:
        Float {

        Float(
            PhysicalConstants.G
        )
    }

    private var speedOfLight:
        Float {

        Float(
            PhysicalConstants.c
        )
    }

    private var speedOfLightSquared:
        Float {

        let c =
            speedOfLight

        return max(
            c * c,
            1.0
        )
    }

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init(
        densitySource:
            GlobularClusterDensitySource,
        parameters:
            QRTLParameters
    ) {

        self.densitySource =
            densitySource

        self.parameters =
            parameters

        self.referenceDensity =
            max(
                densitySource.maximumDensity,
                0.000001
            )
    }

    // ========================================================
    // MASS NORMALIZATION
    // ========================================================
    //
    // Converts the cellular-automata density into physical
    // kg / m^3.
    //
    // rhoPhysical =
    //
    //     rhoCA *
    //     Mcluster /
    //     integral(rhoCA dV)
    //
    // Therefore:
    //
    // integral(rhoPhysical dV)
    //     = 10^6 solar masses
    //
    // ========================================================

    private var massNormalization:
        Float {

        let integral =
            max(
                densitySource.integratedDensity,
                0.000001
            )

        let normalization =
            clusterMassKg /
            integral

        guard normalization.isFinite else {
            return 0.0
        }

        return normalization
    }

    // ========================================================
    // PHYSICAL MASS DENSITY
    // ========================================================

    func physicalMassDensity(
        at position: SIMD3<Float>
    ) -> Float {

        let rawDensity =
            densitySource.density(
                at: position
            )

        guard rawDensity.isFinite else {
            return 0.0
        }

        let positiveDensity =
            max(
                rawDensity,
                0.0
            )

        let density =
            positiveDensity *
            massNormalization

        guard density.isFinite else {
            return 0.0
        }

        return max(
            density,
            0.0
        )
    }

    // ========================================================
    // MASS DENSITY
    // ========================================================
    //
    // This is now PHYSICAL mass density.
    //
    // Units:
    //
    //     kg / m^3
    //
    // ========================================================

    func massDensity(
        at position: SIMD3<Float>
    ) -> Float {

        physicalMassDensity(
            at: position
        )
    }

    // ========================================================
    // NORMALIZED CELLULAR-AUTOMATA DENSITY
    // ========================================================

    func normalizedDensity(
        at position: SIMD3<Float>
    ) -> Float {

        let density =
            densitySource.density(
                at: position
            )

        guard density.isFinite else {
            return 0.0
        }

        let normalized =
            density /
            referenceDensity

        guard normalized.isFinite else {
            return 0.0
        }

        return min(
            max(
                normalized,
                0.0
            ),
            1.0
        )
    }

    // ========================================================
    // QRTL SOURCE
    // ========================================================

    func qrtlSource(
        at position: SIMD3<Float>
    ) -> Float {

        let density =
            normalizedDensity(
                at: position
            )

        let source =
            Float(
                parameters.alphaQ
            ) *
            density

        guard source.isFinite else {
            return 0.0
        }

        return max(
            source,
            0.0
        )
    }

    // ========================================================
    // QRTL / GRAVITY-LIKE INFLUENCE
    // ========================================================

    func influence(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radius =
            simd_length(
                position
            )

        guard radius.isFinite,
              radius > 0.000001 else {
            return .zero
        }

        let inwardDirection =
            -position /
            radius

        let density =
            normalizedDensity(
                at: position
            )

        let distanceFalloff =
            1.0 /
            max(
                radius * radius,
                0.01
            )

        let strength =
            Float(
                parameters.alphaQ
            ) *
            density *
            distanceFalloff

        guard strength.isFinite else {
            return .zero
        }

        return inwardDirection *
            strength
    }

    // ========================================================
    // BOLGARINO RADIAL FLOW
    // ========================================================

    func bolgarinoFlux(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radius =
            simd_length(
                position
            )

        guard radius.isFinite,
              radius > 0.000001 else {
            return .zero
        }

        let radialDirection =
            position /
            radius

        let source =
            qrtlSource(
                at: position
            )

        let falloff =
            1.0 /
            max(
                radius * radius,
                0.01
            )

        let fluxMagnitude =
            source *
            falloff

        guard fluxMagnitude.isFinite else {
            return .zero
        }

        return radialDirection *
            fluxMagnitude
    }

    // ========================================================
    // QRTL CURRENT DENSITY
    // ========================================================

    func qrtlCurrentDensity(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let flux =
            bolgarinoFlux(
                at: position
            )

        let coupling =
            Float(
                parameters.electromagneticCoupling
            )

        let currentDensity =
            flux *
            coupling

        guard currentDensity.x.isFinite,
              currentDensity.y.isFinite,
              currentDensity.z.isFinite else {
            return .zero
        }

        return currentDensity
    }

    // ========================================================
    // QRTL CURRENT
    // ========================================================

    func qrtlCurrent(
        at position: SIMD3<Float>
    ) -> Float {

        let currentDensity =
            qrtlCurrentDensity(
                at: position
            )

        let current =
            simd_length(
                currentDensity
            )

        guard current.isFinite else {
            return 0.0
        }

        return current
    }

    // ========================================================
    // MAGNETIC FIELD
    // ========================================================

    func magneticField(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radius =
            simd_length(
                position
            )

        guard radius.isFinite,
              radius > 0.000001 else {
            return .zero
        }

        let currentDensity =
            qrtlCurrentDensity(
                at: position
            )

        let current =
            simd_length(
                currentDensity
            )

        guard current.isFinite,
              current > 0.0 else {
            return .zero
        }

        let radial =
            position /
            radius

        let referenceAxis =
            SIMD3<Float>(
                0.0,
                1.0,
                0.0
            )

        var tangent =
            simd_cross(
                referenceAxis,
                radial
            )

        if simd_length_squared(
            tangent
        ) < 0.000001 {

            tangent =
                simd_cross(
                    SIMD3<Float>(
                        1.0,
                        0.0,
                        0.0
                    ),
                    radial
                )
        }

        let tangentLength =
            simd_length(
                tangent
            )

        guard tangentLength >
                0.000001 else {
            return .zero
        }

        tangent /=
            tangentLength

        let coupling =
            Float(
                parameters.electromagneticCoupling
            )

        let fieldStrength =
            coupling *
            current /
            max(
                radius,
                0.01
            )

        guard fieldStrength.isFinite else {
            return .zero
        }

        return tangent *
            fieldStrength
    }

    // ========================================================
    // MAGNETIC FIELD MAGNITUDE
    // ========================================================

    func magneticFieldMagnitude(
        at position: SIMD3<Float>
    ) -> Float {

        simd_length(
            magneticField(
                at: position
            )
        )
    }

    // ========================================================
    // ELECTROMAGNETIC FIELD
    // ========================================================

    func electromagneticField(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        magneticField(
            at: position
        )
    }

    // ========================================================
    // ELECTROMAGNETIC INFLUENCE
    // ========================================================

    func electromagneticInfluence(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let magnetic =
            magneticField(
                at: position
            )

        let coupling =
            Float(
                parameters.photonEMCoupling
            )

        return magnetic *
            coupling
    }

    // ========================================================
    // ELECTROMAGNETIC INFLUENCE MAGNITUDE
    // ========================================================

    func electromagneticInfluenceMagnitude(
        at position: SIMD3<Float>
    ) -> Float {

        simd_length(
            electromagneticInfluence(
                at: position
            )
        )
    }

    // ========================================================
    // MAGNETIC ENERGY DENSITY
    // ========================================================

    func magneticEnergyDensity(
        at position: SIMD3<Float>
    ) -> Float {

        let field =
            magneticField(
                at: position
            )

        let bSquared =
            simd_length_squared(
                field
            )

        let mu0 =
            Float(
                PhysicalConstants.mu0
            )

        guard bSquared.isFinite,
              mu0 > 0.0 else {
            return 0.0
        }

        let energy =
            bSquared /
            (2.0 * mu0)

        guard energy.isFinite else {
            return 0.0
        }

        return max(
            energy,
            0.0
        )
    }

    // ========================================================
    // QRTL ENERGY DENSITY
    // ========================================================

    func qrtlEnergyDensity(
        at position: SIMD3<Float>
    ) -> Float {

        let source =
            qrtlSource(
                at: position
            )

        let flux =
            bolgarinoFlux(
                at: position
            )

        let fluxMagnitude =
            simd_length(
                flux
            )

        let energy =
            source *
            fluxMagnitude

        guard energy.isFinite else {
            return 0.0
        }

        return max(
            energy,
            0.0
        )
    }

    // ========================================================
    // EFFECTIVE QRTL + EM ENERGY DENSITY
    // ========================================================

    func effectiveEnergyDensity(
        at position: SIMD3<Float>
    ) -> Float {

        let qrtlEnergy =
            qrtlEnergyDensity(
                at: position
            )

        let electromagneticEnergy =
            magneticEnergyDensity(
                at: position
            )

        let totalEnergy =
            qrtlEnergy +
            electromagneticEnergy

        guard totalEnergy.isFinite else {
            return 0.0
        }

        return max(
            totalEnergy,
            0.0
        )
    }

    // ========================================================
    // ELECTROMAGNETIC OPTICAL CONTRIBUTION
    // ========================================================

    func electromagneticOpticalContribution(
        at position: SIMD3<Float>
    ) -> Float {

        magneticEnergyDensity(
            at: position
        )
    }

    // ========================================================
    // ENCLOSED PHYSICAL MASS
    // ========================================================
    //
    // For a spherical globular cluster:
    //
    // M(<r) =
    //
    //     integral_0^r
    //     4 pi r'^2 rho(r') dr'
    //
    // ========================================================

    func enclosedMass(
        within radius: Float,
        radialSamples: Int = 128
    ) -> Float {

        guard radius.isFinite,
              radius > 0.0 else {
            return 0.0
        }

        let clusterRadius =
            max(
                densitySource.fieldRadiusMeters,
                0.000001
            )

        let integrationRadius =
            min(
                radius,
                clusterRadius
            )

        let sampleCount =
            max(
                radialSamples,
                32
            )

        let dr =
            integrationRadius /
            Float(sampleCount)

        guard dr.isFinite,
              dr > 0.0 else {
            return 0.0
        }

        var mass:
            Float = 0.0

        for index in
            0..<sampleCount {

            let r =
                (Float(index) + 0.5) *
                dr

            let position =
                SIMD3<Float>(
                    r,
                    0.0,
                    0.0
                )

            let density =
                physicalMassDensity(
                    at: position
                )

            let shellVolume =
                4.0 *
                Float.pi *
                r *
                r *
                dr

            mass +=
                density *
                shellVolume
        }

        guard mass.isFinite else {
            return 0.0
        }

        // Outside the cluster, all 10^6 solar masses
        // contribute to the exterior spherical field.

        if radius >= clusterRadius {

            return clusterMassKg
        }

        return min(
            max(
                mass,
                0.0
            ),
            clusterMassKg
        )
    }

    // ========================================================
    // EINSTEIN WEAK-FIELD GRAVITATIONAL POTENTIAL
    // ========================================================
    //
    // Phi(r) =
    //
    //     -G M(<r) / r
    //
    // ========================================================

    func gravitationalPotential(
        at position: SIMD3<Float>
    ) -> Float {

        let radius =
            simd_length(
                position
            )

        guard radius.isFinite,
              radius > 0.000001 else {
            return 0.0
        }

        let enclosed =
            enclosedMass(
                within: radius
            )

        let potential =
            -gravitationalConstant *
            enclosed /
            radius

        guard potential.isFinite else {
            return 0.0
        }

        return potential
    }

    // ========================================================
    // EINSTEIN TIME METRIC
    // ========================================================
    //
    // Weak-field metric:
    //
    //     g00 =
    //         -(1 + 2 Phi / c^2)
    //
    // We return the positive magnitude.
    //
    // ========================================================

    func gravitationalMetricTime(
        at position: SIMD3<Float>
    ) -> Float {

        let phi =
            gravitationalPotential(
                at: position
            )

        let metric =
            1.0 +
            2.0 *
            phi /
            speedOfLightSquared

        guard metric.isFinite else {
            return 1.0
        }

        return max(
            metric,
            0.000001
        )
    }

    // ========================================================
    // EINSTEIN SPATIAL METRIC
    // ========================================================
    //
    // Weak-field spatial metric:
    //
    //     gij =
    //         (1 - 2 Phi / c^2) delta_ij
    //
    // ========================================================

    func spatialMetricFactor(
        at position: SIMD3<Float>
    ) -> Float {

        let phi =
            gravitationalPotential(
                at: position
            )

        let metric =
            1.0 -
            2.0 *
            phi /
            speedOfLightSquared

        guard metric.isFinite else {
            return 1.0
        }

        return max(
            metric,
            0.000001
        )
    }

    // ========================================================
    // EINSTEIN SPACETIME CURVATURE HEIGHT
    // ========================================================
    //
    // This is a VISUALIZATION of the Einstein gravitational
    // potential.
    //
    // It is NOT a separate force field.
    //
    // Negative Y = deeper gravitational well.
    //
    // ========================================================

    func spacetimeCurvatureHeight(
        atXZ point: SIMD2<Float>
    ) -> Float {

        let position =
            SIMD3<Float>(
                point.x,
                0.0,
                point.y
            )

        let phi =
            gravitationalPotential(
                at: position
            )

        let compactness =
            -2.0 *
            phi /
            speedOfLightSquared

        guard compactness.isFinite else {
            return 0.0
        }

        let normalized =
            min(
                max(
                    compactness,
                    0.0
                ),
                1.0
            )

        // SceneKit visualization scale.
        //
        // This does NOT alter the physical gravitational field.

        let visualScale:
            Float = 5.0

        return -normalized *
            visualScale
    }

    // ========================================================
    // EINSTEIN POTENTIAL GRADIENT
    // ========================================================

    func gravitationalPotentialGradient(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radius =
            max(
                simd_length(
                    position
                ),
                1.0
            )

        let h =
            max(
                radius * 0.001,
                0.0001
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

        let phiXPlus =
            gravitationalPotential(
                at: position + dx
            )

        let phiXMinus =
            gravitationalPotential(
                at: position - dx
            )

        let phiYPlus =
            gravitationalPotential(
                at: position + dy
            )

        let phiYMinus =
            gravitationalPotential(
                at: position - dy
            )

        let phiZPlus =
            gravitationalPotential(
                at: position + dz
            )

        let phiZMinus =
            gravitationalPotential(
                at: position - dz
            )

        let twoH =
            2.0 * h

        let gradient =
            SIMD3<Float>(
                (phiXPlus - phiXMinus) /
                    twoH,

                (phiYPlus - phiYMinus) /
                    twoH,

                (phiZPlus - phiZMinus) /
                    twoH
            )

        guard gradient.x.isFinite,
              gradient.y.isFinite,
              gradient.z.isFinite else {
            return .zero
        }

        return gradient
    }

    // ========================================================
    // EINSTEIN PHOTON BENDING
    // ========================================================
    //
    // Weak-field null-geodesic approximation:
    //
    // d k / d l =
    //
    //     -2 / c^2 *
    //
    //     [ grad(Phi)
    //       -
    //       k (k dot grad(Phi)) ]
    //
    // The longitudinal component is removed because only
    // the transverse gravitational gradient changes the
    // photon direction.
    //
    // ========================================================

    func einsteinPhotonBendingAcceleration(
        at position: SIMD3<Float>,
        direction photonDirection: SIMD3<Float>
    ) -> SIMD3<Float> {

        let directionLength =
            simd_length(
                photonDirection
            )

        guard directionLength.isFinite,
              directionLength > 0.000001 else {
            return .zero
        }

        let direction =
            photonDirection /
            directionLength

        let potentialGradient =
            gravitationalPotentialGradient(
                at: position
            )

        // Remove longitudinal component.

        let longitudinal =
            direction *
            simd_dot(
                potentialGradient,
                direction
            )

        let transverseGradient =
            potentialGradient -
            longitudinal

        let bending =
            -2.0 *
            transverseGradient /
            speedOfLightSquared

        guard bending.x.isFinite,
              bending.y.isFinite,
              bending.z.isFinite else {
            return .zero
        }

        return bending
    }

    // ========================================================
    // CURVILINEAR EINSTEIN PHOTON DIRECTION
    // ========================================================

    func einsteinCurvilinearDirection(
        at position: SIMD3<Float>,
        direction photonDirection: SIMD3<Float>,
        stepSize: Float
    ) -> SIMD3<Float> {

        let directionLength =
            simd_length(
                photonDirection
            )

        guard directionLength.isFinite,
              directionLength > 0.000001,
              stepSize.isFinite,
              stepSize > 0.0 else {

            return photonDirection
        }

        let direction =
            photonDirection /
            directionLength

        let bending =
            einsteinPhotonBendingAcceleration(
                at: position,
                direction: direction
            )

        let newDirection =
            direction +
            bending *
            stepSize

        let newLength =
            simd_length(
                newDirection
            )

        guard newLength.isFinite,
              newLength > 0.000001 else {
            return direction
        }

        return newDirection /
            newLength
    }

    // ========================================================
    // TOTAL INDEX
    // ========================================================
    //
    // The gravitational part is now derived from the Einstein
    // potential rather than an arbitrary density bowl.
    //
    // EM remains an optional optical contribution.
    //
    // ========================================================

    func gravitationalOpticalIndex(
        at position: SIMD3<Float>
    ) -> Float {

        let phi =
            gravitationalPotential(
                at: position
            )

        let index =
            1.0 -
            2.0 *
            phi /
            speedOfLightSquared

        guard index.isFinite else {
            return 1.0
        }

        return max(
            index,
            1.0
        )
    }

    // ========================================================
    // COMPLETE FIELD SAMPLE
    // ========================================================

    struct Sample {

        let massDensity:
            Float

        let normalizedDensity:
            Float

        let qrtlSource:
            Float

        let bolgarinoFlux:
            SIMD3<Float>

        let qrtlCurrentDensity:
            SIMD3<Float>

        let qrtlCurrent:
            Float

        let magneticField:
            SIMD3<Float>

        let magneticEnergyDensity:
            Float

        let qrtlEnergyDensity:
            Float

        let effectiveEnergyDensity:
            Float

        let gravitationalPotential:
            Float

        let gravitationalIndex:
            Float

        let electromagneticIndex:
            Float

        let totalIndex:
            Float
    }

    // ========================================================
    // COMPLETE FIELD SAMPLE
    // ========================================================

    func sample(
        at position: SIMD3<Float>
    ) -> Sample {

        let density =
            massDensity(
                at: position
            )

        let normalized =
            normalizedDensity(
                at: position
            )

        let source =
            qrtlSource(
                at: position
            )

        let flux =
            bolgarinoFlux(
                at: position
            )

        let currentDensity =
            qrtlCurrentDensity(
                at: position
            )

        let current =
            simd_length(
                currentDensity
            )

        let magnetic =
            magneticField(
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

        let effectiveEnergy =
            qrtlEnergy +
            magneticEnergy

        let potential =
            gravitationalPotential(
                at: position
            )

        // ----------------------------------------------------
        // Einstein weak-field optical index.
        //
        // n_g ≈ 1 - 2 Phi / c²
        //
        // Since Phi < 0:
        //
        // n_g > 1
        //
        // ----------------------------------------------------

        let gravitationalIndex =
            gravitationalOpticalIndex(
                at: position
            )

        // ----------------------------------------------------
        // EM optical contribution.
        //
        // Kept compatible with your existing QRTL model.
        //
        // ----------------------------------------------------

        let photonCoupling =
            Float(
                parameters.photonEMCoupling
            )

        let electromagneticContribution =
            electromagneticOpticalContribution(
                at: position
            )

        let electromagneticIndex =
            1.0 +
            photonCoupling *
            electromagneticContribution

        guard electromagneticIndex.isFinite else {

            return Sample(
                massDensity:
                    density,

                normalizedDensity:
                    normalized,

                qrtlSource:
                    source,

                bolgarinoFlux:
                    flux,

                qrtlCurrentDensity:
                    currentDensity,

                qrtlCurrent:
                    current,

                magneticField:
                    magnetic,

                magneticEnergyDensity:
                    magneticEnergy,

                qrtlEnergyDensity:
                    qrtlEnergy,

                effectiveEnergyDensity:
                    effectiveEnergy,

                gravitationalPotential:
                    potential,

                gravitationalIndex:
                    gravitationalIndex,

                electromagneticIndex:
                    1.0,

                totalIndex:
                    gravitationalIndex
            )
        }

        let totalIndex =
            gravitationalIndex *
            electromagneticIndex

        return Sample(
            massDensity:
                density,

            normalizedDensity:
                normalized,

            qrtlSource:
                source,

            bolgarinoFlux:
                flux,

            qrtlCurrentDensity:
                currentDensity,

            qrtlCurrent:
                current,

            magneticField:
                magnetic,

            magneticEnergyDensity:
                magneticEnergy,

            qrtlEnergyDensity:
                qrtlEnergy,

            effectiveEnergyDensity:
                effectiveEnergy,

            gravitationalPotential:
                potential,

            gravitationalIndex:
                gravitationalIndex,

            electromagneticIndex:
                electromagneticIndex,

            totalIndex:
                totalIndex
        )
    }

    // ========================================================
    // TOTAL OPTICAL INDEX GRADIENT
    // ========================================================
    //
    // This remains available for diagnostics / EM optical
    // effects.
    //
    // PRIMARY gravitational photon bending should use:
    //
    //     einsteinPhotonBendingAcceleration()
    //
    // ========================================================

    func indexGradient(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radius =
            max(
                simd_length(
                    position
                ),
                1.0
            )

        let h =
            max(
                radius * 0.001,
                0.0001
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

        let xPlus =
            sample(
                at: position + dx
            ).totalIndex

        let xMinus =
            sample(
                at: position - dx
            ).totalIndex

        let yPlus =
            sample(
                at: position + dy
            ).totalIndex

        let yMinus =
            sample(
                at: position - dy
            ).totalIndex

        let zPlus =
            sample(
                at: position + dz
            ).totalIndex

        let zMinus =
            sample(
                at: position - dz
            ).totalIndex

        let twoH =
            2.0 * h

        let gradient =
            SIMD3<Float>(
                (xPlus - xMinus) /
                    twoH,

                (yPlus - yMinus) /
                    twoH,

                (zPlus - zMinus) /
                    twoH
            )

        guard gradient.x.isFinite,
              gradient.y.isFinite,
              gradient.z.isFinite else {
            return .zero
        }

        return gradient
    }

    // ========================================================
    // COMPATIBILITY WRAPPER
    // ========================================================
    //
    // Existing tracer code can continue calling:
    //
    //     qrtlLensingAcceleration()
    //
    // but the implementation now uses Einstein gravity.
    //
    // ========================================================

    func qrtlLensingAcceleration(
        at position: SIMD3<Float>,
        direction photonDirection: SIMD3<Float>
    ) -> SIMD3<Float> {

        einsteinPhotonBendingAcceleration(
            at: position,
            direction: photonDirection
        )
    }

    // ========================================================
    // COMPATIBILITY WRAPPER
    // ========================================================

    func qrtlCurvilinearDirection(
        at position: SIMD3<Float>,
        direction photonDirection: SIMD3<Float>,
        stepSize: Float
    ) -> SIMD3<Float> {

        einsteinCurvilinearDirection(
            at: position,
            direction: photonDirection,
            stepSize: stepSize
        )
    }

    // ========================================================
    // QRTL LENSING STRENGTH
    // ========================================================

    func qrtlLensingStrength(
        at position: SIMD3<Float>,
        direction photonDirection: SIMD3<Float>
    ) -> Float {

        simd_length(
            einsteinPhotonBendingAcceleration(
                at: position,
                direction: photonDirection
            )
        )
    }

    // ========================================================
    // QRTL IMPACT PARAMETER
    // ========================================================

    func qrtlImpactParameter(
        at position: SIMD3<Float>,
        direction photonDirection: SIMD3<Float>
    ) -> Float {

        let directionLength =
            simd_length(
                photonDirection
            )

        guard directionLength >
                0.000001 else {

            return simd_length(
                position
            )
        }

        let direction =
            photonDirection /
            directionLength

        let longitudinal =
            simd_dot(
                position,
                direction
            )

        let closestPoint =
            position -
            direction *
            longitudinal

        return simd_length(
            closestPoint
        )
    }

    // ========================================================
    // QRTL OUTWARD FIELD
    // ========================================================

    func qrtlOutwardField(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let flux =
            bolgarinoFlux(
                at: position
            )

        let length =
            simd_length(
                flux
            )

        guard length >
                0.000001 else {
            return .zero
        }

        return flux /
            length
    }

    // ========================================================
    // PHOTON BEND DIRECTION
    // ========================================================

    func qrtlPhotonBendDirection(
        at position: SIMD3<Float>,
        direction photonDirection: SIMD3<Float>
    ) -> SIMD3<Float> {

        let acceleration =
            einsteinPhotonBendingAcceleration(
                at: position,
                direction: photonDirection
            )

        let length =
            simd_length(
                acceleration
            )

        guard length >
                0.000001 else {
            return .zero
        }

        return acceleration /
            length
    }
}
