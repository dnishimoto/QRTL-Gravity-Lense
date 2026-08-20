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
// The globular-cluster cellular density map supplies the
// spatial mass distribution.
//
// QRTLField does NOT create a Gaussian mass distribution.
//
// ============================================================

protocol GlobularClusterDensitySource {

    func density(
        at position: SIMD3<Float>
    ) -> Float

    var totalMass: Float { get }

    var maximumDensity: Float { get }
}

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
    // MASS DENSITY
    // ========================================================
    //
    // THIS IS THE CELLULAR-AUTOMATA MASS DISTRIBUTION.
    //
    // QRTLField asks GlobularClusterDensityMap for the density
    // at every requested 3D position.
    //
    // ========================================================

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
            -position / radius

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
            position / radius

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
            source * falloff

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
            flux * coupling

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
            position / radius

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

        guard tangentLength > 0.000001 else {
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
            simd_length_squared(field)

        let mu0 =
            Float(
                PhysicalConstants.mu0
            )

        guard
            bSquared.isFinite,
            mu0 > 0.0
        else {
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
    // The local CA density contributes to the effective
    // gravitational field.
    //
    // ========================================================

    func gravitationalPotential(
        at position: SIMD3<Float>,
        effectiveEnergyDensity:
            Float
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
        // CELLULAR-AUTOMATA DENSITY
        // ----------------------------------------------------

        let localDensity =
            massDensity(
                at: position
            )

        guard localDensity.isFinite else {
            return 0.0
        }

        // ----------------------------------------------------
        // QRTL ENERGY -> EFFECTIVE MASS
        // ----------------------------------------------------

        let safeEnergy =
            effectiveEnergyDensity.isFinite
            ? max(
                effectiveEnergyDensity,
                0.0
            )
            : 0.0

        let effectiveMassDensity =
            safeEnergy /
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
        // LOCAL VOLUME
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

        guard enclosedMass.isFinite else {
            return 0.0
        }

        // ----------------------------------------------------
        // POTENTIAL
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

        magneticEnergyDensity(
            at: position
        )
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
    // 360-DEGREE SPACETIME CURVATURE
    // ========================================================
    //
    // IMPORTANT:
    //
    // The surface coordinate is X/Z.
    //
    //     X = horizontal
    //     Z = depth
    //
    // Radius is calculated from BOTH:
    //
    //     r = sqrt(x² + z²)
    //
    // Therefore curvature exists in every direction.
    //
    // ========================================================

    func spacetimeCurvatureHeight(
        atXZ point: SIMD2<Float>
    ) -> Float {

        let fieldPosition =
            SIMD3<Float>(
                point.x,
                0.0,
                point.y
            )

        // ----------------------------------------------------
        // TRUE RADIAL DISTANCE
        // ----------------------------------------------------

        let radius =
            simd_length(point)

        guard radius.isFinite else {
            return 0.0
        }

        // ----------------------------------------------------
        // CELLULAR-AUTOMATA DENSITY
        // ----------------------------------------------------

        let density =
            normalizedDensity(
                at: fieldPosition
            )

        guard density.isFinite else {
            return 0.0
        }

        // ----------------------------------------------------
        // COMPLETE QRTL SAMPLE
        // ----------------------------------------------------

        let fieldSample =
            sample(
                at: fieldPosition
            )

        // ----------------------------------------------------
        // GRAVITATIONAL POTENTIAL
        // ----------------------------------------------------

        let potentialMagnitude =
            abs(
                fieldSample.gravitationalPotential
            )

        // ----------------------------------------------------
        // RADIAL BOWL ENVELOPE
        // ----------------------------------------------------
        //
        // Larger radius -> flatter surface.
        //
        // This is rotationally symmetric around Y.
        //
        // ----------------------------------------------------

        let normalizedRadius =
            radius / 12.0

        let radialEnvelope =
            exp(
                -0.5 *
                normalizedRadius *
                normalizedRadius
            )

        // ----------------------------------------------------
        // DENSITY TERM
        // ----------------------------------------------------

        let densityTerm =
            min(
                max(
                    density,
                    0.0
                ),
                1.0
            )

        // ----------------------------------------------------
        // POTENTIAL TERM
        // ----------------------------------------------------

        let c =
            Float(
                PhysicalConstants.c
            )

        let potentialScale =
            max(
                c * c,
                1.0
            )

        let potentialTerm =
            min(
                max(
                    potentialMagnitude /
                    potentialScale,
                    0.0
                ),
                1.0
            )

        // ----------------------------------------------------
        // COMBINED CURVATURE
        // ----------------------------------------------------

        let curvatureStrength =
            0.70 * densityTerm +
            0.30 * potentialTerm

        // ----------------------------------------------------
        // FINAL BOWL HEIGHT
        // ----------------------------------------------------
        //
        // Negative Y means downward.
        //
        // Center:
        //      deepest
        //
        // Outside:
        //      approaches zero
        //
        // ----------------------------------------------------

        let curvatureScale:
            Float = 5.0

        let height =
            -curvatureStrength *
            radialEnvelope *
            curvatureScale

        guard height.isFinite else {
            return 0.0
        }

        return height
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
                at:
                    position + xOffset
            ).totalIndex

        let xMinus =
            sample(
                at:
                    position - xOffset
            ).totalIndex

        let yPlus =
            sample(
                at:
                    position + yOffset
            ).totalIndex

        let yMinus =
            sample(
                at:
                    position - yOffset
            ).totalIndex

        let zPlus =
            sample(
                at:
                    position + zOffset
            ).totalIndex

        let zMinus =
            sample(
                at:
                    position - zOffset
            ).totalIndex

        let twoH =
            2.0 * h

        let gradient =
            SIMD3<Float>(
                (xPlus - xMinus) / twoH,
                (yPlus - yMinus) / twoH,
                (zPlus - zMinus) / twoH
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
        direction photonDirection:
            SIMD3<Float>
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

        guard directionLength > 0.000001 else {
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

        guard transverseLength > 0.000001 else {
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

        let flux =
            bolgarinoFlux(
                at: position
            )

        let fluxStrength =
            simd_length(flux)

        let magnetic =
            magneticField(
                at: position
            )

        let magneticStrength =
            simd_length(magnetic)

        let densityTerm =
            min(
                max(
                    density,
                    0.0
                ),
                1.0
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
                    fluxStrength,
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

        // ----------------------------------------------------
        // COMBINED FIELD STRENGTH
        // ----------------------------------------------------

        let fieldStrength =
            0.50 * densityTerm +
            0.30 * sourceTerm +
            0.15 * fluxTerm +
            0.05 * magneticTerm

        guard fieldStrength > 0.000001 else {
            return .zero
        }

        // ----------------------------------------------------
        // IMPACT PARAMETER FALLoff
        // ----------------------------------------------------

        let impactFalloff =
            1.0 /
            safeImpactParameter

        // ----------------------------------------------------
        // RADIAL ENVELOPE
        // ----------------------------------------------------

        let normalizedRadius =
            radius / 12.0

        let radialEnvelope =
            exp(
                -0.5 *
                normalizedRadius *
                normalizedRadius
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

        guard lensingMagnitude.isFinite else {
            return .zero
        }

        return inwardLensingDirection *
            lensingMagnitude
    }

    // ========================================================
    // CURVILINEAR PHOTON DIRECTION
    // ========================================================

    func qrtlCurvilinearDirection(
        at position: SIMD3<Float>,
        direction photonDirection:
            SIMD3<Float>,
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

        guard length > 0.000001 else {
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
        direction photonDirection:
            SIMD3<Float>
    ) -> Float {

        simd_length(
            qrtlLensingAcceleration(
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
        direction photonDirection:
            SIMD3<Float>
    ) -> Float {

        let directionLength =
            simd_length(
                photonDirection
            )

        guard directionLength > 0.000001 else {
            return simd_length(position)
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
            simd_length(flux)

        guard length > 0.000001 else {
            return .zero
        }

        return flux / length
    }

    // ========================================================
    // QRTL PHOTON BEND DIRECTION
    // ========================================================

    func qrtlPhotonBendDirection(
        at position: SIMD3<Float>,
        direction photonDirection:
            SIMD3<Float>
    ) -> SIMD3<Float> {

        let acceleration =
            qrtlLensingAcceleration(
                at: position,
                direction: photonDirection
            )

        let length =
            simd_length(acceleration)

        guard length > 0.000001 else {
            return .zero
        }

        return acceleration / length
    }
}
