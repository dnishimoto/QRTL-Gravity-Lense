//
//  QRTLField.swift
//  QRTL Gravity Lense
//
//  Cellular-Automata Driven QRTL Field
//

import Foundation
import simd

// ============================================================
// CELLULAR-AUTOMATA DENSITY SOURCE
// ============================================================
//
// The cellular automata becomes the spatial mass distribution
// of the globular cluster.
//
// density(at:) must return MASS / VOLUME for the cell containing
// the requested scene position.
//




// ============================================================
// QRTL FIELD
// ============================================================

final class QRTLField {

    // ========================================================
    // PRIMARY DATA SOURCES
    // ========================================================

    let densitySource:
        GlobularClusterDensitySource

    let parameters:
        QRTLParameters

    let referenceDensity:
        Float


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
    // FIELD SAMPLE
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
    // LOCAL FIELD VECTOR
    // ========================================================

    func vector(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let distance =
            simd_length(position)

        guard
            distance.isFinite,
            distance > 1.0e-6
        else {
            return .zero
        }

        let radialDirection =
            simd_normalize(
                -position
            )

        let strength =
            self.strength(
                at: position
            )

        return radialDirection *
            strength
    }


    // ========================================================
    // LOCAL FIELD STRENGTH
    // ========================================================

    func strength(
        at position: SIMD3<Float>
    ) -> Float {

        let distance =
            simd_length(position)

        guard
            distance.isFinite,
            distance > 1.0e-6
        else {
            return 0.0
        }

        let density =
            normalizedDensity(
                at: position
            )

        guard density.isFinite else {
            return 0.0
        }

        return min(
            max(
                density,
                0.0
            ),
            1.0
        )
    }


    // ========================================================
    // CELLULAR-AUTOMATA MASS DENSITY
    // ========================================================
    //
    // THIS IS THE IMPORTANT CHANGE.
    //
    // QRTLField no longer obtains density from a Gaussian model.
    //
    // It directly samples the cellular-automata globular
    // cluster.
    //
    // rho(x,y,z) = cellular automata mass / cell volume
    //

    func massDensity(
        at position: SIMD3<Float>
    ) -> Float {

        let density =
            densitySource.density(
                at: position
            )

        guard density.isFinite else {
            return 0.0
        }

        return max(
            density,
            0.0
        )
    }


    // ========================================================
    // NORMALIZED CELLULAR-AUTOMATA DENSITY
    // ========================================================

    func normalizedDensity(
        at position: SIMD3<Float>
    ) -> Float {

        let density =
            massDensity(
                at: position
            )

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
    // QRTL / GRAVITY-LIKE INFLUENCE
    // ========================================================

    func influence(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radius =
            simd_length(position)

        guard
            radius.isFinite,
            radius > 0.000001
        else {
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
            Float(parameters.alphaQ) *
            density *
            distanceFalloff

        guard strength.isFinite else {
            return .zero
        }

        return inwardDirection *
            strength
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
            Float(parameters.alphaQ) *
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
    // BOLGARINO RADIAL FLOW
    // ========================================================

    func bolgarinoFlux(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radius =
            simd_length(position)

        guard
            radius.isFinite,
            radius > 0.000001
        else {
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

        guard
            currentDensity.x.isFinite,
            currentDensity.y.isFinite,
            currentDensity.z.isFinite
        else {
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
            simd_length(position)

        guard
            radius.isFinite,
            radius > 0.000001
        else {
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

        guard
            current.isFinite,
            current > 0.0
        else {
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

        if simd_length_squared(tangent)
            < 0.000001 {

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
            simd_length(tangent)

        guard
            tangentLength > 0.000001
        else {
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

        let field =
            magneticField(
                at: position
            )

        let magnitude =
            simd_length(field)

        guard magnitude.isFinite else {
            return 0.0
        }

        return magnitude
    }


    // ========================================================
    // ELECTROMAGNETIC FIELD
    // ========================================================

    func electromagneticField(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        return magneticField(
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

        let influence =
            magnetic *
            coupling

        guard
            influence.x.isFinite,
            influence.y.isFinite,
            influence.z.isFinite
        else {
            return .zero
        }

        return influence
    }


    // ========================================================
    // ELECTROMAGNETIC INFLUENCE MAGNITUDE
    // ========================================================

    func electromagneticInfluenceMagnitude(
        at position: SIMD3<Float>
    ) -> Float {

        let influence =
            electromagneticInfluence(
                at: position
            )

        let magnitude =
            simd_length(influence)

        guard magnitude.isFinite else {
            return 0.0
        }

        return magnitude
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
            simd_length_squared(field)

        guard bSquared.isFinite else {
            return 0.0
        }

        let mu0 =
            Float(
                PhysicalConstants.mu0
            )

        guard mu0 > 0.0 else {
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
            simd_length(flux)

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
    // GRAVITATIONAL POTENTIAL
    // ========================================================
    //
    // The potential is now based on the cellular-automata
    // mass density sampled through massDensity(at:).
    //
    // Phi = -G M(r) / r
    //

    func gravitationalPotential(
        at position: SIMD3<Float>,
        effectiveEnergyDensity: Float
    ) -> Float {

        let radius =
            simd_length(position)

        guard
            radius.isFinite,
            radius > 0.000001
        else {
            return 0.0
        }

        let G =
            Float(
                PhysicalConstants.G
            )

        let c =
            Float(
                PhysicalConstants.c
            )

        // ----------------------------------------------------
        // CELLULAR-AUTOMATA MASS DENSITY
        // ----------------------------------------------------

        let localDensity =
            massDensity(
                at: position
            )

        guard
            localDensity.isFinite,
            localDensity >= 0.0
        else {
            return 0.0
        }

        // ----------------------------------------------------
        // QRTL ENERGY -> EFFECTIVE MASS DENSITY
        // ----------------------------------------------------

        let safeEnergyDensity =
            effectiveEnergyDensity.isFinite
            ? max(
                effectiveEnergyDensity,
                0.0
            )
            : 0.0

        let effectiveMassDensity =
            safeEnergyDensity /
            max(
                c * c,
                1.0
            )

        // ----------------------------------------------------
        // TOTAL EFFECTIVE DENSITY
        // ----------------------------------------------------

        let totalDensity =
            localDensity +
            effectiveMassDensity

        guard
            totalDensity.isFinite,
            totalDensity >= 0.0
        else {
            return 0.0
        }

        // ----------------------------------------------------
        // LOCAL ENCLOSED-MASS APPROXIMATION
        // ----------------------------------------------------

        let volume =
            (4.0 / 3.0) *
            Float.pi *
            radius *
            radius *
            radius

        let enclosedMass =
            totalDensity *
            volume

        guard
            enclosedMass.isFinite,
            enclosedMass >= 0.0
        else {
            return 0.0
        }

        // ----------------------------------------------------
        // GRAVITATIONAL POTENTIAL
        // ----------------------------------------------------

        let potential =
            -G *
            enclosedMass /
            radius

        guard potential.isFinite else {
            return 0.0
        }

        return potential
    }


    // ========================================================
    // ELECTROMAGNETIC OPTICAL CONTRIBUTION
    // ========================================================

    func electromagneticOpticalContribution(
        at position: SIMD3<Float>
    ) -> Float {

        let energy =
            magneticEnergyDensity(
                at: position
            )

        guard energy.isFinite else {
            return 0.0
        }

        return energy
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
                at: position,
                effectiveEnergyDensity:
                    effectiveEnergy
            )

        let cSquared =
            Float(
                PhysicalConstants.c *
                PhysicalConstants.c
            )

        let gamma =
            Float(
                parameters.gammaQ
            )

        let gravitationalIndex =
            1.0 -
            (1.0 + gamma) *
            potential /
            cSquared

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
    // TOTAL INDEX GRADIENT
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
            max(
                radius * 0.001,
                0.0001
            )

        let xOffset =
            SIMD3<Float>(
                h,
                0.0,
                0.0
            )

        let yOffset =
            SIMD3<Float>(
                0.0,
                h,
                0.0
            )

        let zOffset =
            SIMD3<Float>(
                0.0,
                0.0,
                h
            )

        let xPlus =
            sample(
                at: position + xOffset
            ).totalIndex

        let xMinus =
            sample(
                at: position - xOffset
            ).totalIndex

        let yPlus =
            sample(
                at: position + yOffset
            ).totalIndex

        let yMinus =
            sample(
                at: position - yOffset
            ).totalIndex

        let zPlus =
            sample(
                at: position + zOffset
            ).totalIndex

        let zMinus =
            sample(
                at: position - zOffset
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

        guard
            gradient.x.isFinite,
            gradient.y.isFinite,
            gradient.z.isFinite
        else {
            return .zero
        }

        return gradient
    }


    // ========================================================
    // QRTL LENSING ACCELERATION
    // ========================================================

    func qrtlLensingAcceleration(
        at position: SIMD3<Float>,
        direction photonDirection: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radius =
            simd_length(position)

        guard
            radius.isFinite,
            radius > 0.000001
        else {
            return .zero
        }

        let directionLength =
            simd_length(
                photonDirection
            )

        guard
            directionLength.isFinite,
            directionLength > 0.000001
        else {
            return .zero
        }

        let direction =
            photonDirection /
            directionLength

        let radialDirection =
            position /
            radius

        let longitudinal =
            simd_dot(
                radialDirection,
                direction
            )

        let transverseRadial =
            radialDirection -
            direction *
            longitudinal

        let transverseLength =
            simd_length(
                transverseRadial
            )

        guard
            transverseLength.isFinite,
            transverseLength > 0.000001
        else {
            return .zero
        }

        let inwardLensingDirection =
            -transverseRadial /
            transverseLength

        let impactParameter =
            radius *
            sqrt(
                max(
                    1.0 -
                    longitudinal *
                    longitudinal,
                    0.0
                )
            )

        let safeImpactParameter =
            max(
                impactParameter,
                0.05
            )

        // ----------------------------------------------------
        // CELLULAR-AUTOMATA DENSITY
        // ----------------------------------------------------

        let density =
            normalizedDensity(
                at: position
            )

        let source =
            qrtlSource(
                at: position
            )

        let qrtlFlux =
            bolgarinoFlux(
                at: position
            )

        let qrtlFluxStrength =
            simd_length(
                qrtlFlux
            )

        let magnetic =
            magneticField(
                at: position
            )

        let magneticStrength =
            simd_length(
                magnetic
            )

        let sourceTerm =
            min(
                max(
                    source,
                    0.0
                ),
                1.0
            )

        let fluxTerm =
            min(
                max(
                    qrtlFluxStrength,
                    0.0
                ),
                1.0
            )

        let magneticTerm =
            min(
                max(
                    magneticStrength,
                    0.0
                ),
                1.0
            )

        let fieldStrength =
            0.50 * density +
            0.30 * sourceTerm +
            0.15 * fluxTerm +
            0.05 * magneticTerm

        guard
            fieldStrength.isFinite,
            fieldStrength > 0.000001
        else {
            return .zero
        }

        let impactFalloff =
            1.0 /
            safeImpactParameter

        let normalizedRadius =
            radius /
            12.0

        let radialEnvelope =
            exp(
                -0.5 *
                pow(
                    normalizedRadius,
                    2.0
                )
            )

        let gamma =
            max(
                Float(parameters.gammaQ),
                0.0
            )

        let lensingMagnitude =
            gamma *
            fieldStrength *
            impactFalloff *
            radialEnvelope

        guard
            lensingMagnitude.isFinite,
            lensingMagnitude > 0.000001
        else {
            return .zero
        }

        let acceleration =
            inwardLensingDirection *
            lensingMagnitude

        guard
            acceleration.x.isFinite,
            acceleration.y.isFinite,
            acceleration.z.isFinite
        else {
            return .zero
        }

        return acceleration
    }


    // ========================================================
    // CURVILINEAR PHOTON DIRECTION
    // ========================================================

    func qrtlCurvilinearDirection(
        at position: SIMD3<Float>,
        direction photonDirection: SIMD3<Float>,
        stepSize: Float
    ) -> SIMD3<Float> {

        let directionLength =
            simd_length(
                photonDirection
            )

        guard
            directionLength.isFinite,
            directionLength > 0.000001,
            stepSize.isFinite,
            stepSize > 0.0
        else {
            return photonDirection
        }

        let direction =
            photonDirection /
            directionLength

        let acceleration =
            qrtlLensingAcceleration(
                at: position,
                direction: direction
            )

        let deflected =
            direction +
            acceleration *
            stepSize

        let length =
            simd_length(deflected)

        guard
            length.isFinite,
            length > 0.000001
        else {
            return direction
        }

        return deflected /
            length
    }


    // ========================================================
    // QRTL LENSING STRENGTH
    // ========================================================

    func qrtlLensingStrength(
        at position: SIMD3<Float>,
        direction photonDirection: SIMD3<Float>
    ) -> Float {

        let acceleration =
            qrtlLensingAcceleration(
                at: position,
                direction: photonDirection
            )

        let strength =
            simd_length(
                acceleration
            )

        guard strength.isFinite else {
            return 0.0
        }

        return strength
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

        guard
            directionLength.isFinite,
            directionLength > 0.000001
        else {
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

        let impactParameter =
            simd_length(
                closestPoint
            )

        guard impactParameter.isFinite else {
            return 0.0
        }

        return impactParameter
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
            simd_length(flux)

        guard
            length.isFinite,
            length > 0.000001
        else {
            return .zero
        }

        return flux /
            length
    }


    // ========================================================
    // QRTL PHOTON BEND DIRECTION
    // ========================================================

    func qrtlPhotonBendDirection(
        at position: SIMD3<Float>,
        direction photonDirection: SIMD3<Float>
    ) -> SIMD3<Float> {

        let acceleration =
            qrtlLensingAcceleration(
                at: position,
                direction: photonDirection
            )

        let length =
            simd_length(
                acceleration
            )

        guard
            length.isFinite,
            length > 0.000001
        else {
            return .zero
        }

        return acceleration /
            length
    }
    func spacetimeCurvatureHeight(
        atXZ point: SIMD2<Float>
    ) -> Float {

        // ---------------------------------------------------------
        // Convert XZ surface coordinate into a 3D QRTL field point.
        //
        // The surface is being viewed in the X-Z plane, so Y is
        // initially the uncurved spacetime height.
        // ---------------------------------------------------------

        let fieldPosition = SIMD3<Float>(
            point.x,
            0.0,
            point.y
        )

        // ---------------------------------------------------------
        // Sample the QRTL field.
        // ---------------------------------------------------------

        let sample = self.sample(
            at: fieldPosition
        )

        // ---------------------------------------------------------
        // Gravitational potential.
        //
        // The potential is negative near the mass concentration.
        // We take its magnitude because the SceneKit surface needs
        // a positive visual displacement downward into the bowl.
        // ---------------------------------------------------------

        let potentialMagnitude =
            abs(sample.gravitationalPotential)

        guard
            potentialMagnitude.isFinite,
            potentialMagnitude > 0.0
        else {
            return 0.0
        }

        // ---------------------------------------------------------
        // Convert the physical potential into a visual height.
        //
        // curvatureScale controls how deep the bowl appears.
        // This is a visualization scale, not a physical constant.
        // ---------------------------------------------------------

        let curvatureScale: Float = 2.5

        let height =
            -Float(potentialMagnitude) *
            Float(curvatureScale)
        
        guard height.isFinite else {
            return 0.0
        }

        return height
    }
}
