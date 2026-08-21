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
    // PHYSICAL SCALE
    // ========================================================

    /// Physical radius represented by normalized SceneKit
    /// coordinate magnitude 1.0.
    ///
    /// This MUST use the same radius used to construct
    /// GlobularClusterDensitySource.
    let physicalRadiusMeters: Double

    // ========================================================
    // PHYSICAL CONSTANTS
    // ========================================================

    private let solarMassKg: Float =
        1.98847e30

    private var clusterMassKg: Float {
        1.0e6 * solarMassKg
    }

    private var gravitationalConstant: Float {
        Float(PhysicalConstants.G)
    }

    private let speedOfLight: Double =
        299_792_458.0

    private var speedOfLightSquared: Float {

        let c = Float(speedOfLight)

        return max(
            c * c,
            Float(1.0)
        )
    }

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init(
        densitySource: GlobularClusterDensitySource,
        parameters: QRTLParameters,
        physicalRadiusMeters: Double
    ) {

        self.densitySource =
            densitySource

        self.parameters =
            parameters

        self.physicalRadiusMeters =
            physicalRadiusMeters

        self.referenceDensity =
            max(
                densitySource.maximumDensity,
                1.0e-30
            )
    }
     // ============================================================
    // NORMALIZED → PHYSICAL POSITION
    //
    // normalizedPosition:
    //     0 = center
    //     1 = physical cluster radius
    //
    // IMPORTANT:
    // There must be ONLY ONE function with this name.
    // ============================================================

    private func physicalPosition(
        from normalizedPosition: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radius: Float = max(
            Float(physicalRadiusMeters),
            1.0
        )

        return SIMD3<Float>(
            normalizedPosition.x * radius,
            normalizedPosition.y * radius,
            normalizedPosition.z * radius
        )
    }

    // ============================================================
    // PHYSICAL MASS DENSITY
    // ============================================================

    func massDensity(
        at normalizedPosition: SIMD3<Float>
    ) -> Float {

        let position = physicalPosition(
            from: normalizedPosition
        )

        let density = densitySource.density(
            at: position
        )

        guard density.isFinite else {
            return 0.0
        }

        return max(density, 0.0)
    }

    // ============================================================
    // NORMALIZED MASS DENSITY
    // ============================================================

    func normalizedDensity(
        at normalizedPosition: SIMD3<Float>
    ) -> Float {

        let density = massDensity(
            at: normalizedPosition
        )

        let reference = max(
            referenceDensity,
            Float(1.0e-30)
        )

        let value = density / reference

        guard value.isFinite else {
            return 0.0
        }

        return min(
            max(value, 0.0),
            1.0
        )
    }
    // ============================================================
    // QRTL SOURCE
    // ============================================================

    func qrtlSource(
        at normalizedPosition: SIMD3<Float>
    ) -> Float {

        let density = normalizedDensity(
            at: normalizedPosition
        )

        let source =
            Float(parameters.alphaQ) * density

        guard source.isFinite else {
            return 0.0
        }

        return max(source, 0.0)
    }

    // ============================================================
    // BOLGARINO FLUX
    // ============================================================

    func bolgarinoFlux(
        at normalizedPosition: SIMD3<Float>
    ) -> SIMD3<Float> {

        let r =
            simd_length(
                normalizedPosition
            )

        guard r > 1.0e-6 else {
            return .zero
        }

        let direction =
            normalizedPosition / r

        let source =
            qrtlSource(
                at: normalizedPosition
            )

        let velocity =
            max(
                Float(parameters.qrtlVelocity),
                1.0e-6
            )

        return direction *
            source *
            velocity
    }
    // ============================================================
    // QRTL CURRENT DENSITY
    // ============================================================

    func qrtlEnergyDensity(
        at normalizedPosition: SIMD3<Float>
    ) -> Float {

        let source =
            qrtlSource(
                at: normalizedPosition
            )

        let velocity =
            max(
                Float(parameters.qrtlVelocity),
                1.0e-6
            )

        let current =
            qrtlCurrent(
                at: normalizedPosition
            )

        let kineticEnergy =
            Float(0.5) *
            source *
            velocity *
            velocity

        let electromagneticEnergy =
            Float(0.5) *
            max(
                Float(parameters.electromagneticCoupling),
                0.0
            ) *
            current *
            current

        let energy =
            kineticEnergy +
            electromagneticEnergy

        guard energy.isFinite else {
            return 0.0
        }

        return max(
            energy,
            0.0
        )
    }

    // ============================================================
    // QRTL CURRENT
    // ============================================================

    func qrtlCurrent(
        at normalizedPosition: SIMD3<Float>
    ) -> Float {

        simd_length(
            qrtlCurrentDensity(
                at: normalizedPosition
            )
        )
    }

    func gravitationalPotential(
        at normalizedPosition: SIMD3<Float>,
        effectiveEnergyDensity: Float? = nil
    ) -> Float {

        let physical = physicalPosition(
            from: normalizedPosition
        )

        let r = max(
            simd_length(physical),
            Float(1.0)
        )

        let energyDensity =
            effectiveEnergyDensity ??
            qrtlEnergyDensity(
                at: normalizedPosition
            )

        let c2 = max(
            speedOfLightSquared,
            Float(1.0)
        )

        let massEquivalent =
            energyDensity / c2

        let potential =
            -gravitationalConstant *
            massEquivalent /
            r

        guard potential.isFinite else {
            return 0.0
        }

        return potential
    }
    // ============================================================
    // INDEX GRADIENT
    // ============================================================

    func indexGradient(
        at normalizedPosition: SIMD3<Float>
    ) -> SIMD3<Float> {

        let radius =
            max(
                simd_length(
                    normalizedPosition
                ),
                1.0e-4
            )

        let h =
            max(
                radius * 0.0025,
                1.0e-4
            )

        var gradient =
            SIMD3<Float>.zero

        for axis in 0..<3 {

            var plus =
                normalizedPosition

            var minus =
                normalizedPosition

            plus[axis] += h
            minus[axis] -= h

            let phiPlus =
                gravitationalPotential(
                    at: plus
                )

            let phiMinus =
                gravitationalPotential(
                    at: minus
                )

            gradient[axis] =
                (
                    phiPlus -
                    phiMinus
                ) /
                (
                    2.0 * h
                )
        }

        return gradient
    }

    
 
   
    // ============================================================
    // QRTL LENSING ACCELERATION
    // ============================================================

    func qrtlLensingAcceleration(
        at normalizedPosition: SIMD3<Float>,
        direction: SIMD3<Float>
    ) -> SIMD3<Float> {

        let gradient =
            indexGradient(
                at: normalizedPosition
            )

        let transverse =
            gradient -
            simd_dot(
                gradient,
                direction
            ) *
            direction

        return -transverse *
            Float(parameters.chiQ)
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
    func qrtlCurrentDensity(
        at position: SIMD3<Float>
    ) -> SIMD3<Float> {

        let flux =
            bolgarinoFlux(
                at: position
            )

        let velocity =
            max(
                Float(parameters.qrtlVelocity),
                1.0
            )

        return flux / velocity
    }
    func diagnoseQRTLField(
        at position: SIMD3<Float>
    ) {

        print("================================================")
        print("QRTL FIELD PIPELINE DIAGNOSTIC")
        print("================================================")

        let density =
            massDensity(at: position)

        let normalized =
            normalizedDensity(at: position)

        let influence =
            influence(at: position)

        let source =
            qrtlSource(at: position)

        let flux =
            bolgarinoFlux(at: position)

        let currentDensity =
            qrtlCurrentDensity(at: position)

        let current =
            qrtlCurrent(at: position)

        let energy =
            qrtlEnergyDensity(at: position)

        let potential =
            gravitationalPotential(at: position)

        let gradient =
            indexGradient(at: position)

        let acceleration =
            qrtlLensingAcceleration(
                at: position,
                direction: SIMD3<Float>(0, 0, 1)
            )

        print("Position:", position)
        print("Mass density:", density)
        print("Normalized density:", normalized)
        print("QRTL influence:", influence)
        print("QRTL source:", source)
        print("Bolgarino flux:", flux)
        print("QRTL current density:", currentDensity)
        print("QRTL current:", current)
        print("QRTL energy density:", energy)
        print("Gravitational potential:", potential)
        print("Index gradient:", gradient)
        print("QRTL lensing acceleration:", acceleration)
    }
  
    func inverseSpacetimeMetric(
        at position: SIMD3<Float>
    ) -> simd_double4x4 {

        let metric =
            spacetimeMetric(
                at: position
            )

        return simd_inverse(metric)
    }
 


    // ============================================================
    // MARK: - SPACETIME METRIC gμν
    // ============================================================
    //
    // Coordinates:
    //
    //     x⁰ = ct
    //     x¹ = x
    //     x² = y
    //     x³ = z
    //
    // Weak-field isotropic metric:
    //
    //     g₀₀ = -(1 + 2Φ/c²)
    //     gᵢᵢ =  (1 - 2Φ/c²)
    //
    // Signature:
    //
    //     (-,+,+,+)
    //
    // The metric describes the local spacetime geometry generated
    // by the QRTL gravitational potential.
    //
    // The photon should ultimately respond to this geometry through
    // the Christoffel symbols and the null-geodesic equation.
    //
    // ============================================================

    func spacetimeMetric(
        at position: SIMD3<Float>
    ) -> simd_double4x4 {

        // --------------------------------------------------------
        // GRAVITATIONAL POTENTIAL
        // --------------------------------------------------------

        let potential =
            Double(
                gravitationalPotential(
                    at: position
                )
            )

        // --------------------------------------------------------
        // SPEED OF LIGHT
        // --------------------------------------------------------

        let c =
            PhysicalConstants.c

        let cSquared =
            c * c

        // --------------------------------------------------------
        // WEAK-FIELD METRIC FACTOR
        // --------------------------------------------------------
        //
        //     2Φ/c²
        //
        // This is dimensionless.
        //
        // --------------------------------------------------------

        let twoPhiOverC2 =
            2.0 *
            potential /
            cSquared

        // --------------------------------------------------------
        // TEMPORAL COMPONENT
        // --------------------------------------------------------
        //
        //     g₀₀ = -(1 + 2Φ/c²)
        //
        // --------------------------------------------------------

        let g00 =
            -(1.0 + twoPhiOverC2)

        // --------------------------------------------------------
        // SPATIAL COMPONENTS
        // --------------------------------------------------------
        //
        //     gxx = gyy = gzz
        //
        // --------------------------------------------------------

        let spatialScale =
            1.0 - twoPhiOverC2

        // --------------------------------------------------------
        // COLUMN 0
        //
        // g₀₀
        // g₁₀
        // g₂₀
        // g₃₀
        // --------------------------------------------------------

        let column0 =
            SIMD4<Double>(
                g00,
                0.0,
                0.0,
                0.0
            )

        // --------------------------------------------------------
        // COLUMN 1
        //
        // g₀₁
        // g₁₁
        // g₂₁
        // g₃₁
        // --------------------------------------------------------

        let column1 =
            SIMD4<Double>(
                0.0,
                spatialScale,
                0.0,
                0.0
            )

        // --------------------------------------------------------
        // COLUMN 2
        //
        // g₀₂
        // g₁₂
        // g₂₂
        // g₃₂
        // --------------------------------------------------------

        let column2 =
            SIMD4<Double>(
                0.0,
                0.0,
                spatialScale,
                0.0
            )

        // --------------------------------------------------------
        // COLUMN 3
        //
        // g₀₃
        // g₁₃
        // g₂₃
        // g₃₃
        // --------------------------------------------------------

        let column3 =
            SIMD4<Double>(
                0.0,
                0.0,
                0.0,
                spatialScale
            )

        // --------------------------------------------------------
        // BUILD METRIC
        //
        // simd_double4x4 is column-major.
        // --------------------------------------------------------

        return simd_double4x4(
            columns: (
                column0,
                column1,
                column2,
                column3
            )
        )
    }

    // ============================================================
    // MARK: - METRIC DERIVATIVE ∂gμν / ∂xᵃ
    // ============================================================
    //
    // coordinate:
    //
    //     0 = ct
    //     1 = x
    //     2 = y
    //     3 = z
    //
    // The current QRTL cluster is static, so:
    //
    //     ∂gμν / ∂(ct) = 0
    //
    // Spatial derivatives are calculated using a centered finite
    // difference:
    //
    //     ∂g/∂xᵃ ≈ [g(x+h) - g(x-h)] / (2h)
    //
    // ============================================================

    func metricDerivative(
        at position: SIMD3<Float>,
        coordinate: Int
    ) -> simd_double4x4 {

        // --------------------------------------------------------
        // FINITE-DIFFERENCE STEP
        // --------------------------------------------------------

        let radius =
            simd_length(position)

        let h =
            max(
                1.0,
                Double(radius) * 1.0e-5
            )

        // --------------------------------------------------------
        // TIME COORDINATE
        // --------------------------------------------------------
        //
        // Static gravitational field:
        //
        //     ∂gμν / ∂(ct) = 0
        //
        // --------------------------------------------------------

        guard coordinate >= 1 && coordinate <= 3 else {

            let zero0 =
                SIMD4<Double>(
                    0.0,
                    0.0,
                    0.0,
                    0.0
                )

            let zero1 =
                SIMD4<Double>(
                    0.0,
                    0.0,
                    0.0,
                    0.0
                )

            let zero2 =
                SIMD4<Double>(
                    0.0,
                    0.0,
                    0.0,
                    0.0
                )

            let zero3 =
                SIMD4<Double>(
                    0.0,
                    0.0,
                    0.0,
                    0.0
                )

            return simd_double4x4(
                columns: (
                    zero0,
                    zero1,
                    zero2,
                    zero3
                )
            )
        }

        // --------------------------------------------------------
        // OFFSET POSITIONS
        // --------------------------------------------------------

        var plus =
            position

        var minus =
            position

        switch coordinate {

        case 1:
            plus.x += Float(h)
            minus.x -= Float(h)

        case 2:
            plus.y += Float(h)
            minus.y -= Float(h)

        case 3:
            plus.z += Float(h)
            minus.z -= Float(h)

        default:
            break
        }

        // --------------------------------------------------------
        // METRIC AT x + h
        // --------------------------------------------------------

        let gPlus =
            spacetimeMetric(
                at: plus
            )

        // --------------------------------------------------------
        // METRIC AT x - h
        // --------------------------------------------------------

        let gMinus =
            spacetimeMetric(
                at: minus
            )

        // --------------------------------------------------------
        // CENTRAL FINITE DIFFERENCE
        // --------------------------------------------------------
        //
        //     ∂g/∂xᵃ =
        //
        //     [g(x+h) - g(x-h)] / (2h)
        //
        // --------------------------------------------------------

        let denominator =
            2.0 * h

        let derivativeColumn0 =
            SIMD4<Double>(
                (gPlus.columns.0.x - gMinus.columns.0.x) / denominator,
                (gPlus.columns.0.y - gMinus.columns.0.y) / denominator,
                (gPlus.columns.0.z - gMinus.columns.0.z) / denominator,
                (gPlus.columns.0.w - gMinus.columns.0.w) / denominator
            )

        let derivativeColumn1 =
            SIMD4<Double>(
                (gPlus.columns.1.x - gMinus.columns.1.x) / denominator,
                (gPlus.columns.1.y - gMinus.columns.1.y) / denominator,
                (gPlus.columns.1.z - gMinus.columns.1.z) / denominator,
                (gPlus.columns.1.w - gMinus.columns.1.w) / denominator
            )

        let derivativeColumn2 =
            SIMD4<Double>(
                (gPlus.columns.2.x - gMinus.columns.2.x) / denominator,
                (gPlus.columns.2.y - gMinus.columns.2.y) / denominator,
                (gPlus.columns.2.z - gMinus.columns.2.z) / denominator,
                (gPlus.columns.2.w - gMinus.columns.2.w) / denominator
            )

        let derivativeColumn3 =
            SIMD4<Double>(
                (gPlus.columns.3.x - gMinus.columns.3.x) / denominator,
                (gPlus.columns.3.y - gMinus.columns.3.y) / denominator,
                (gPlus.columns.3.z - gMinus.columns.3.z) / denominator,
                (gPlus.columns.3.w - gMinus.columns.3.w) / denominator
            )

        return simd_double4x4(
            columns: (
                derivativeColumn0,
                derivativeColumn1,
                derivativeColumn2,
                derivativeColumn3
            )
        )
 

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
    // NORMALIZED DENSITY
    // ========================================================

   

 

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

