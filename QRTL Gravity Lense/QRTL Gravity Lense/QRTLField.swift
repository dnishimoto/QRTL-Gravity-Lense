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

    let densitySource: GlobularClusterDensitySource
    let parameters: QRTLParameters
    let referenceDensity: Float

    // ========================================================
    // PHYSICAL CONSTANTS
    // ========================================================

    private let solarMassKg: Float = 1.98847e30

    private var clusterMassKg: Float {
        1.0e6 * solarMassKg
    }

    private var gravitationalConstant: Float {
        Float(PhysicalConstants.G)
    }

    private var speedOfLight: Float {
        Float(PhysicalConstants.c)
    }

    private var speedOfLightSquared: Float {
        let c = speedOfLight
        return max(c * c, 1.0)
    }

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init(
        densitySource: GlobularClusterDensitySource,
        parameters: QRTLParameters
    ) {
        self.densitySource = densitySource
        self.parameters = parameters

        self.referenceDensity = max(
            densitySource.maximumDensity,
            0.000001
        )
    }

    // ========================================================
    // GRAVITY MEASUREMENT (per-star mass)
    // ========================================================
    //
    // Pass-through to the density source's per-star mass
    // measurement: 10^6 solar masses / star count. This is the
    // figure that actually sources the gravity surface.
    // ========================================================

    var perStarMassKg: Float {
        densitySource.perStarMassKg
    }

    var starCount: Int {
        densitySource.starCount
    }

    var gravityMeasurementReport: String {
        "Globular Cluster Gravity Measurement\n" +
        "  Total mass:     \(clusterMassKg / solarMassKg) M☉  (\(clusterMassKg) kg)\n" +
        "  Star count:     \(starCount)\n" +
        "  Mass per star:  \(perStarMassKg / solarMassKg) M☉  (\(perStarMassKg) kg)"
    }
    // ============================================================
    // EINSTEIN SPACETIME CURVATURE HEIGHT
    // ============================================================
    //
    // Visualization of the Einstein gravitational potential.
    //
    // This is NOT used as the photon force.
    // It only converts the gravitational potential into a
    // SceneKit-compatible bowl/well height.
    //
    // Negative Y = deeper gravitational well.
    //
    // ------------------------------------------------------------
    // UNIT FIX — SCENE UNITS ARE NOT METERS
    // ------------------------------------------------------------
    //
    // The gravity surface / heatmap sample this function using
    // SceneKit coordinates (roughly -20...20), while
    // gravitationalPotential() expects real meters — the cluster's
    // physical radius is on the order of 10^10 m. Feeding scene
    // coordinates straight in as meters put every visible sample
    // deep inside the compactness clamp (compactness >> 1
    // everywhere), so the bowl rendered as one flat, maximally
    // deep plateau with no visible z-depth variation.
    //
    // visualClusterRadiusSceneUnits declares what scene-unit
    // radius should visually represent the cluster's real edge
    // (densitySource.fieldRadiusMeters). Points are rescaled into
    // real meters before evaluating the potential, so the bowl
    // now shows a smooth gradient from a clamped core out to a
    // shallow rim, matching the cluster's real 1/r falloff.
    //
    // Only this visual helper is rescaled — gravitationalPotential,
    // enclosedMass, and photon propagation elsewhere in this class
    // continue to operate in real meters, unchanged.
    // ------------------------------------------------------------

    var visualClusterRadiusSceneUnits: Float = 18.0

    private var sceneUnitsToMeters: Float {

        let radius = max(
            densitySource.fieldRadiusMeters,
            1.0e-6
        )

        let sceneRadius = max(
            visualClusterRadiusSceneUnits,
            1.0e-6
        )

        let scale = radius / sceneRadius

        guard scale.isFinite else {
            return 1.0
        }

        return scale
    }

    func spacetimeCurvatureHeight(
        atXZ point: SIMD2<Float>
    ) -> Float {

        let scale =
            sceneUnitsToMeters

        let position =
            SIMD3<Float>(
                point.x * scale,
                0.0,
                point.y * scale
            )

        let phi =
            gravitationalPotential(
                at: position
            )

        let clusterRadius =
            max(
                densitySource.fieldRadiusMeters,
                1.0
            )

        let edgePosition =
            SIMD3<Float>(
                clusterRadius,
                0.0,
                0.0
            )

        let phiEdge =
            gravitationalPotential(
                at: edgePosition
            )

        let phiDepth =
            phiEdge - phi

        guard
            phiDepth.isFinite,
            phiDepth >= 0.0
        else {
            return 0.0
        }

        // --------------------------------------------------------
        // VISUAL REFERENCE DEPTH
        // --------------------------------------------------------

        let referenceDepth =
            max(
                abs(phiEdge),
                1.0
            )

        let normalized =
            min(
                max(
                    phiDepth /
                    referenceDepth,
                    0.0
                ),
                1.0
            )

        // --------------------------------------------------------
        // NONLINEAR VISUAL RESPONSE
        // --------------------------------------------------------

        let shaped =
            pow(
                normalized,
                0.35
            )

        // --------------------------------------------------------
        // SCENE DEPTH
        // --------------------------------------------------------

        let visualScale: Float = 6.0

        return -shaped * visualScale
    }
    // ========================================================
    // MASS NORMALIZATION
    // ========================================================

    private var massNormalization: Float {

        let integral = max(
            densitySource.integratedDensity,
            0.000001
        )

        let normalization =
            clusterMassKg / integral

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

        return max(
            rawDensity * massNormalization,
            0.0
        )
    }

    // ========================================================
    // MASS DENSITY
    // ========================================================

    func massDensity(
        at position: SIMD3<Float>
    ) -> Float {

        physicalMassDensity(
            at: position
        )
    }

    // ========================================================
    // NORMALIZED DENSITY
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
            density / referenceDensity

        guard normalized.isFinite else {
            return 0.0
        }

        return min(
            max(normalized, 0.0),
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

        return max(source, 0.0)
    }

    // ========================================================
    // QRTL INFLUENCE
    // ========================================================

    func influence(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radiusSquared =
            simd_length_squared(position)

        guard radiusSquared.isFinite,
              radiusSquared > 0.000001
        else {
            return .zero
        }

        let radius =
            sqrt(radiusSquared)

        let direction =
            -position / radius

        let density =
            normalizedDensity(
                at: position
            )

        let falloff =
            1.0 /
            max(radiusSquared, 0.01)

        let strength =
            Float(parameters.alphaQ) *
            density *
            falloff

        guard strength.isFinite else {
            return .zero
        }

        return direction * strength
    }

    // ========================================================
    // BOLGARINO RADIAL FLOW
    // ========================================================

    func bolgarinoFlux(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radiusSquared =
            simd_length_squared(position)

        guard radiusSquared.isFinite,
              radiusSquared > 0.000001
        else {
            return .zero
        }

        let radius =
            sqrt(radiusSquared)

        let radialDirection =
            position / radius

        let source =
            qrtlSource(
                at: position
            )

        let falloff =
            1.0 /
            max(radiusSquared, 0.01)

        let magnitude =
            source * falloff

        guard magnitude.isFinite else {
            return .zero
        }

        return radialDirection * magnitude
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

        return flux * coupling
    }

    // ========================================================
    // QRTL CURRENT
    // ========================================================

    func qrtlCurrent(
        at position: SIMD3<Float>
    ) -> Float {

        simd_length(
            qrtlCurrentDensity(
                at: position
            )
        )
    }

    // ========================================================
    // MAGNETIC FIELD
    // ========================================================

    func magneticField(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radiusSquared =
            simd_length_squared(position)

        guard radiusSquared.isFinite,
              radiusSquared > 0.000001
        else {
            return .zero
        }

        let radius =
            sqrt(radiusSquared)

        let currentDensity =
            qrtlCurrentDensity(
                at: position
            )

        let current =
            simd_length(
                currentDensity
            )

        guard current.isFinite,
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

        if simd_length_squared(tangent) < 0.000001 {

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

        tangent /= tangentLength

        let coupling =
            Float(
                parameters.electromagneticCoupling
            )

        let fieldStrength =
            coupling *
            current /
            max(radius, 0.01)

        guard fieldStrength.isFinite else {
            return .zero
        }

        return tangent * fieldStrength
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

        // Photon EM influence has been disabled.
        return .zero
    }

    // ========================================================
    // ELECTROMAGNETIC INFLUENCE MAGNITUDE
    // ========================================================

    func electromagneticInfluenceMagnitude(
        at position: SIMD3<Float>
    ) -> Float {

        0.0
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

        guard bSquared.isFinite,
              mu0 > 0.0
        else {
            return 0.0
        }

        return max(
            bSquared /
            (2.0 * mu0),
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
    // EFFECTIVE ENERGY DENSITY
    // ========================================================

    func effectiveEnergyDensity(
        at position: SIMD3<Float>
    ) -> Float {

        qrtlEnergyDensity(
            at: position
        )
        +
        magneticEnergyDensity(
            at: position
        )
    }

    // ========================================================
    // ELECTROMAGNETIC OPTICAL CONTRIBUTION
    // ========================================================

    func electromagneticOpticalContribution(
        at position: SIMD3<Float>
    ) -> Float {

        0.0
    }

    // ========================================================
    // FAST ENCLOSED MASS
    // ========================================================
    //
    // IMPORTANT:
    //
    // Outside a spherical globular cluster:
    //
    //     M(<r) = Mtotal
    //
    // Therefore no radial integration is necessary.
    //
    // ========================================================

    func enclosedMass(
        within radius: Float,
        radialSamples: Int = 32
    ) -> Float {

        guard radius.isFinite,
              radius > 0.0
        else {
            return 0.0
        }

        let clusterRadius =
            max(
                densitySource.fieldRadiusMeters,
                0.000001
            )

        // ----------------------------------------------------
        // MOST PHOTON STEPS WILL BE OUTSIDE THE CLUSTER.
        // ----------------------------------------------------

        if radius >= clusterRadius {
            return clusterMassKg
        }

        // ----------------------------------------------------
        // Interior mass calculation.
        //
        // This is used only while the photon is physically
        // inside the cluster.
        // ----------------------------------------------------

        let sampleCount =
            max(
                min(radialSamples, 32),
                8
            )

        let integrationRadius =
            min(
                radius,
                clusterRadius
            )

        let dr =
            integrationRadius /
            Float(sampleCount)

        guard dr.isFinite,
              dr > 0.0
        else {
            return 0.0
        }

        var mass: Float = 0.0

        for index in 0..<sampleCount {

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

        return min(
            max(mass, 0.0),
            clusterMassKg
        )
    }

    // ========================================================
    // GRAVITATIONAL POTENTIAL
    // ========================================================

    // ========================================================
    // EINSTEIN GRAVITATIONAL POTENTIAL
    // ========================================================
    //
    // For a spherical extended mass distribution:
    //
    //     Phi(r) = -G [ M(r)/r
    //                + 4*pi * integral_r^R rho(s) * s ds ]
    //
    // The second term is essential.
    //
    // Exterior spherical shells exert zero net force inside
    // the shell, but they DO contribute gravitational potential.
    //
    // Therefore the potential reaches its deepest finite value
    // at the center of the globular cluster instead of incorrectly
    // approaching zero there.
    //
    // Outside the cluster:
    //
    //     Phi(r) = -G Mtotal / r
    //
    // ========================================================

    func gravitationalPotential(
        at position: SIMD3<Float>
    ) -> Float {

        let radiusSquared =
            simd_length_squared(position)

        guard
            radiusSquared.isFinite
        else {
            return 0.0
        }

        let radius =
            sqrt(max(radiusSquared, 0.0))

        let clusterRadius =
            max(
                densitySource.fieldRadiusMeters,
                0.000001
            )

        // ----------------------------------------------------
        // OUTSIDE THE CLUSTER
        // ----------------------------------------------------
        //
        // Once outside a spherical distribution, the entire
        // cluster behaves gravitationally like a point mass.
        //
        // Phi = -GM/r
        //
        // ----------------------------------------------------

        if radius >= clusterRadius {

            guard radius > 0.000001 else {
                return 0.0
            }

            let potential =
                -gravitationalConstant *
                clusterMassKg /
                radius

            guard potential.isFinite else {
                return 0.0
            }

            return potential
        }

        // ----------------------------------------------------
        // INSIDE THE CLUSTER
        // ----------------------------------------------------
        //
        // Phi(r) =
        //
        // -G [
        //       M(<r)/r
        //       +
        //       4*pi * integral_r^R rho(s)s ds
        //     ]
        //
        // ----------------------------------------------------

        let sampleCount = 128

        let dr =
            clusterRadius /
            Float(sampleCount)

        guard
            dr.isFinite,
            dr > 0.0
        else {
            return 0.0
        }

        // ----------------------------------------------------
        // ENCLOSED MASS
        // ----------------------------------------------------

        let enclosed =
            enclosedMass(
                within: radius,
                radialSamples: 64
            )

        // ----------------------------------------------------
        // INTERIOR SHELL POTENTIAL
        // ----------------------------------------------------
        //
        // Integrate:
        //
        //     4*pi*rho(r)*r dr
        //
        // from current radius to cluster radius.
        //
        // ----------------------------------------------------

        var exteriorShellPotentialTerm: Float = 0.0

        if radius < clusterRadius {

            let startIndex =
                max(
                    Int(
                        floor(
                            radius / dr
                        )
                    ),
                    0
                )

            if startIndex < sampleCount {

                for index in startIndex..<sampleCount {

                    let r =
                        (Float(index) + 0.5) *
                        dr

                    guard
                        r > radius,
                        r <= clusterRadius
                    else {
                        continue
                    }

                    let density =
                        physicalMassDensity(
                            at: SIMD3<Float>(
                                r,
                                0.0,
                                0.0
                            )
                        )

                    guard
                        density.isFinite,
                        density >= 0.0
                    else {
                        continue
                    }

                    exteriorShellPotentialTerm +=
                        density *
                        r *
                        dr
                }
            }
        }

        let shellFactor =
            4.0 *
            Float.pi

        let enclosedPotentialTerm =
            enclosed /
            max(radius, 0.000001)

        let totalPotentialTerm =
            enclosedPotentialTerm +
            shellFactor *
            exteriorShellPotentialTerm

        let potential =
            -gravitationalConstant *
            totalPotentialTerm

        guard potential.isFinite else {
            return 0.0
        }

        return potential
    }

    // ========================================================
    // FAST GRAVITATIONAL GRADIENT
    // ========================================================
    //
    // For a spherical mass distribution:
    //
    //     Phi = -GM/r
    //
    // therefore:
    //
    //     grad(Phi) = GM/r^3 * position
    //
    // This replaces SIX gravitationalPotential() calls.
    //
    // ========================================================

    func gravitationalPotentialGradient(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radiusSquared =
            simd_length_squared(position)

        guard radiusSquared.isFinite,
              radiusSquared > 0.000001
        else {
            return .zero
        }

        let radius =
            sqrt(radiusSquared)

        // ----------------------------------------------------
        // OUTSIDE CLUSTER
        // ----------------------------------------------------

        if radius >= densitySource.fieldRadiusMeters {

            let inverseRadius =
                1.0 / radius

            let inverseRadiusCubed =
                inverseRadius *
                inverseRadius *
                inverseRadius

            let coefficient =
                gravitationalConstant *
                clusterMassKg *
                inverseRadiusCubed

            let gradient =
                position *
                coefficient

            guard gradient.x.isFinite,
                  gradient.y.isFinite,
                  gradient.z.isFinite
            else {
                return .zero
            }

            return gradient
        }

        // ----------------------------------------------------
        // INSIDE CLUSTER
        // ----------------------------------------------------

        let enclosed =
            enclosedMass(
                within: radius,
                radialSamples: 16
            )

        let coefficient =
            gravitationalConstant *
            enclosed /
            max(
                radiusSquared * radius,
                0.000001
            )

        let gradient =
            position *
            coefficient

        guard gradient.x.isFinite,
              gradient.y.isFinite,
              gradient.z.isFinite
        else {
            return .zero
        }

        return gradient
    }

    // ========================================================
    // EINSTEIN PHOTON BENDING
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
              directionLength > 0.000001
        else {
            return .zero
        }

        let direction =
            photonDirection /
            directionLength

        // ----------------------------------------------------
        // ONE FAST FIELD EVALUATION
        // ----------------------------------------------------

        let gradient =
            gravitationalPotentialGradient(
                at: position
            )

        // ----------------------------------------------------
        // REMOVE LONGITUDINAL COMPONENT
        // ----------------------------------------------------

        let longitudinal =
            direction *
            simd_dot(
                gradient,
                direction
            )

        let transverseGradient =
            gradient -
            longitudinal

        // ----------------------------------------------------
        // EINSTEIN WEAK-FIELD BENDING
        // ----------------------------------------------------

        let bending =
            -2.0 *
            transverseGradient /
            speedOfLightSquared

        guard bending.x.isFinite,
              bending.y.isFinite,
              bending.z.isFinite
        else {
            return .zero
        }

        return bending
    }

    // ========================================================
    // CURVILINEAR PHOTON DIRECTION
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
              stepSize > 0.0
        else {
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
            bending * stepSize

        let newLength =
            simd_length(
                newDirection
            )

        guard newLength.isFinite,
              newLength > 0.000001
        else {
            return direction
        }

        return newDirection / newLength
    }

    // ========================================================
    // GRAVITATIONAL OPTICAL INDEX
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
    // TOTAL INDEX GRADIENT
    // ========================================================
    //
    // EM photon influence has been removed.
    //
    // This method is retained for compatibility.
    //
    // ========================================================

    func indexGradient(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let gradient =
            gravitationalPotentialGradient(
                at: position
            )

        let result =
            -2.0 *
            gradient /
            speedOfLightSquared

        guard result.x.isFinite,
              result.y.isFinite,
              result.z.isFinite
        else {
            return .zero
        }

        return result
    }

    // ========================================================
    // COMPATIBILITY WRAPPER
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
    // IMPACT PARAMETER
    // ========================================================

    func qrtlImpactParameter(
        at position: SIMD3<Float>,
        direction photonDirection: SIMD3<Float>
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
    // OUTWARD FIELD
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
            simd_length(acceleration)

        guard length > 0.000001 else {
            return .zero
        }

        return acceleration / length
    }
}

