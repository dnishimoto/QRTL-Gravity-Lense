
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
    
    let spacetimeHeightScale: Float = 1.0e6
    
    var qrtlMetricCoupling: Float = 1.0
    
    private var spatialPotentialGrid: [Float] = []

    private var spatialEnergyDensityGrid: [Float] = []


    var radialGravityTable: [RadialGravitySample] = []
    let densitySource: GlobularClusterDensityMap
    let parameters: QRTLParameters
    let referenceDensity: Float
    
    // ========================================================
    // ADDITIONAL RADIAL LOOKUP TABLES (built once at init)
    // ========================================================
    
    private var radialNormalizedDensityTable: [Double] = []
    private var radialQRTLSourceTable: [Double] = []
    private var radialBolgarinoFluxTable: [Double] = []
    private var radialMagneticMagnitudeTable: [Double] = []
    
    // The density map is the SINGLE SOURCE OF TRUTH for both the
    // cluster's physical mass and radius — it's what the star
    // positions were actually generated within. QRTLField must not
    // independently re-derive these from `parameters`, because
    // nothing keeps parameters.clusterRadiusParsecs /
    // clusterMassSolarMasses in sync with whatever radius/mass the
    // caller actually built the star field with (ContentView never
    // sets either — they silently sit at their struct defaults,
    // e.g. 10 parsecs ≈ 3.09e17 m, while the real cluster may be
    // built at a completely different scale, e.g. 35 solar radii
    // ≈ 2.4e10 m). That ~7-order-of-magnitude mismatch was causing
    // the radial table to sample almost entirely outside where any
    // star actually is, zeroing the QRTL energy density — and
    // therefore the enclosed mass and potential — everywhere except
    // the exact center.
    private var clusterMassKg: Double {

        densitySource.clusterMassKg
    }

    var clusterRadiusMeters: Double {

        Double(
            densitySource.fieldRadiusMeters
        )
    }

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
    
    private var inverseSpeedOfLightSquared: Float {
        1.0 / Float(speedOfLight * speedOfLight)
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

      
        self.radialGravityTable =
            buildRadialGravityTable(
                densitySource: densitySource,
                parameters: parameters,
                sampleCount: 1024
            )
        
        // One-time build of all additional radial tables
        // (same radii as radialGravityTable).
        buildAdditionalRadialLookupTables()
    }
    func qrtlSpacetimeDeformation(
        at position: SIMD3<Float>
    ) -> Float {

        let metric =
            qrtlSpacetimeMetric(
                at: position
            )

        let spatialScale =
            (metric.g11 +
             metric.g22 +
             metric.g33) / 3.0

        return spatialScale - 1.0
    }
    private func metricDerivative(
        at position: SIMD3<Float>,
        row: Int,
        column: Int,
        coordinate: Int
    ) -> Float {

        qrtlMetricDerivative(
            at: position,
            metricRow: row,
            metricColumn: column,
            coordinate: coordinate
        )
    }
    func evaluateQRTLUnifiedSpacetime(
        at position: SIMD3<Float>
    ) -> QRTLUnifiedSpacetimeSample {

        let potential =
            gravitationalPotential(
                at: position
            )

        let metric =
            qrtlSpacetimeMetric(
                at: position
            )

        let inverseMetric =
            qrtlInverseMetric(
                at: position
            )

        let metricDeformation =
            (
                metric.g11 +
                metric.g22 +
                metric.g33
            ) / 3.0 - 1.0

        return QRTLUnifiedSpacetimeSample(
            position: position,
            potential: Float(potential),
            metric: metric,
            inverseMetric: inverseMetric,
            metricDeformation: metricDeformation
        )
    }
    func qrtlMetricPhotonAcceleration(
        at position: SIMD3<Float>,
        direction: SIMD3<Float>
    ) -> SIMD3<Float> {

        let normalizedDirection =
            simd_normalize(direction)

        let c2 = speedOfLight * speedOfLight

        var acceleration = SIMD3<Float>.zero

        for i in 1...3 {

            var value: Float = 0.0

            for j in 1...3 {

                let gamma =
                    qrtlChristoffelSymbol(
                        at: position,
                        upper: i,
                        lower1: j,
                        lower2: j
                    )

                let component: Float

                switch j {
                case 1:
                    component = normalizedDirection.x

                case 2:
                    component = normalizedDirection.y

                case 3:
                    component = normalizedDirection.z

                default:
                    component = 0.0
                }

                value +=
                    gamma *
                    component *
                    component
            }

            switch i {

            case 1:
                acceleration.x = Float(-c2) * value

            case 2:
                acceleration.y = Float(-c2) * value

            case 3:
                acceleration.z = Float(-c2) * value

            default:
                break
            }
        }

        return acceleration
    }
    func qrtlChristoffelSymbol(
        at position: SIMD3<Float>,
        upper: Int,
        lower1: Int,
        lower2: Int
    ) -> Float {

        let inverse =
            qrtlInverseMetric(at: position)

        var result: Float = 0.0

        for sigma in 0..<4 {

            let term1 =
                metricDerivative(
                    at: position,
                    row: sigma,
                    column: lower2,
                    coordinate: lower1
                )

            let term2 =
                metricDerivative(
                    at: position,
                    row: sigma,
                    column: lower1,
                    coordinate: lower2
                )

            let term3 =
                metricDerivative(
                    at: position,
                    row: lower1,
                    column: lower2,
                    coordinate: sigma
                )

            let inverseValue =
                metricValue(
                    inverse,
                    upper,
                    sigma
                )

            result +=
                0.5 *
                inverseValue *
                (term1 + term2 - term3)
        }

        return result
    }
    private func metricValue(
        _ metric: QRTLSpacetimeMetric,
        _ row: Int,
        _ column: Int
    ) -> Float {

        switch (row, column) {

        // ========================================================
        // TIME-TIME
        // ========================================================

        case (0, 0):
            return metric.g00

        // ========================================================
        // X-X
        // ========================================================

        case (1, 1):
            return metric.g11

        // ========================================================
        // Y-Y
        // ========================================================

        case (2, 2):
            return metric.g22

        // ========================================================
        // Z-Z
        // ========================================================

        case (3, 3):
            return metric.g33

        // ========================================================
        // OFF-DIAGONAL TERMS
        //
        // The current QRTL metric is diagonal.
        //
        // g01 = g02 = g03 = ...
        //      = g30 = g31 = g32 = 0
        // ========================================================

        default:
            return 0.0
        }
    }
    func qrtlInverseMetric(
        at position: SIMD3<Float>
    ) -> QRTLSpacetimeMetric {

        let metric =
            qrtlSpacetimeMetric(
                at: position
            )

        // ============================================================
        // INVERSE OF DIAGONAL METRIC
        //
        // For a diagonal metric:
        //
        // g^00 = 1 / g00
        // g^11 = 1 / g11
        // g^22 = 1 / g22
        // g^33 = 1 / g33
        //
        // All off-diagonal components are zero.
        // ============================================================

        return QRTLSpacetimeMetric(

            g00:
                1.0 / metric.g00,

            g11:
                1.0 / metric.g11,

            g22:
                1.0 / metric.g22,

            g33:
                1.0 / metric.g33
        )
    }
    func qrtlMetricDerivative(
        at position: SIMD3<Float>,
        metricRow: Int,
        metricColumn: Int,
        coordinate: Int
    ) -> Float {

        let h: Float = 0.001

        var plus = position
        var minus = position

        switch coordinate {

        case 1:
            plus.x += h
            minus.x -= h

        case 2:
            plus.y += h
            minus.y -= h

        case 3:
            plus.z += h
            minus.z -= h

        default:
            return 0.0
        }

        let forward = qrtlMetricComponent(
            at: plus,
            row: metricRow,
            column: metricColumn
        )

        let backward = qrtlMetricComponent(
            at: minus,
            row: metricRow,
            column: metricColumn
        )

        return (forward - backward) / (2.0 * h)
    }
    func qrtlMetricComponent(
        at position: SIMD3<Float>,
        row: Int,
        column: Int
    ) -> Float {

        let metric =
            qrtlSpacetimeMetric(
                at: position
            )

        switch (row, column) {

        // ========================================================
        // TIME-TIME
        // ========================================================

        case (0, 0):
            return metric.g00

        // ========================================================
        // X-X
        // ========================================================

        case (1, 1):
            return metric.g11

        // ========================================================
        // Y-Y
        // ========================================================

        case (2, 2):
            return metric.g22

        // ========================================================
        // Z-Z
        // ========================================================

        case (3, 3):
            return metric.g33

        // ========================================================
        // OFF-DIAGONAL COMPONENTS
        //
        // Current QRTL spacetime metric is diagonal.
        // Therefore:
        //
        // gμν = 0 when μ ≠ ν
        // ========================================================

        default:
            return 0.0
        }
    }
    func qrtlSpacetimeMetric(
        at position: SIMD3<Float>
    ) -> QRTLSpacetimeMetric {

        // ============================================================
        // QRTL GRAVITATIONAL POTENTIAL
        // ============================================================

        let potential =
            gravitationalPotential(
                at: position
            )

        // ============================================================
        // DIMENSIONLESS POTENTIAL / c²
        // ============================================================

        let phiOverC2 =
            qrtlMetricCoupling *
            Float(potential) *
            inverseSpeedOfLightSquared

        // ============================================================
        // TEMPORAL METRIC COMPONENT
        //
        // Weak-field form:
        //
        // g00 = -(1 + 2Φ/c²)
        // ============================================================

        let temporal =
            -(1.0 + 2.0 * phiOverC2)

        // ============================================================
        // SPATIAL METRIC COMPONENTS
        //
        // All three spatial directions must be valid.
        //
        // IMPORTANT:
        // g22 must NOT be zero.
        // ============================================================

        let spatial =
            1.0 -
            phiOverC2

        // ============================================================
        // QRTL SPACETIME METRIC
        // ============================================================

        return QRTLSpacetimeMetric(

            g00:
                temporal,

            g11:
                spatial,

            g22:
                spatial,

            g33:
                spatial
        )
    }
  
    // ========================================================
    // BUILD ADDITIONAL RADIAL LOOKUP TABLES (ONCE)
    // ========================================================
    
    private func buildAdditionalRadialLookupTables() {
        
        let count = radialGravityTable.count
        guard count >= 2 else {
            radialNormalizedDensityTable = []
            radialQRTLSourceTable = []
            radialBolgarinoFluxTable = []
            radialMagneticMagnitudeTable = []
            return
        }
        
        radialNormalizedDensityTable = [Double](repeating: 0.0, count: count)
        radialQRTLSourceTable = [Double](repeating: 0.0, count: count)
        radialBolgarinoFluxTable = [Double](repeating: 0.0, count: count)
        radialMagneticMagnitudeTable = [Double](repeating: 0.0, count: count)
        
        for i in 0..<count {
            
            let radius = radialGravityTable[i].radius
            
            let position = SIMD3<Float>(
                Float(radius),
                0.0,
                0.0
            )
            
            // Normalized density
            let norm = Double(densitySource.normalizedDensity(at: position))
            radialNormalizedDensityTable[i] =
                (norm.isFinite && norm >= 0.0) ? norm : 0.0
            
            // QRTL source (uses existing method)
            let source = qrtlSource(at: position)
            radialQRTLSourceTable[i] =
                (source.isFinite && source >= 0.0) ? source : 0.0
            
            // Bolgarino flux (uses existing method)
            let flux = bolgarinoFlux(at: position)
            radialBolgarinoFluxTable[i] =
                (flux.isFinite && flux >= 0.0) ? flux : 0.0
            
            // Magnetic magnitude (uses existing magneticField, keeps vector behaviour)
            let B = magneticField(at: position)
            let mag = Double(simd_length(B))
            radialMagneticMagnitudeTable[i] =
                (mag.isFinite && mag >= 0.0) ? mag : 0.0
        }
    }
    
    // ========================================================
    // FAST RADIAL INTERPOLATORS (for rendering / visualization)
    // ========================================================
    
    func interpolateRadialNormalizedDensity(radius: Double) -> Double {
        interpolateRadialScalarTable(
            radius: radius,
            values: radialNormalizedDensityTable
        )
    }
    
    func interpolateRadialSource(radius: Double) -> Double {
        interpolateRadialScalarTable(
            radius: radius,
            values: radialQRTLSourceTable
        )
    }
    
    func interpolateRadialFlux(radius: Double) -> Double {
        interpolateRadialScalarTable(
            radius: radius,
            values: radialBolgarinoFluxTable
        )
    }
    
    /// Returns a full magnetic-field vector.
    /// Magnitude comes from the radial table; direction is reconstructed
    /// exactly as in the original magneticField(at:) implementation.
    func interpolateRadialMagneticField(at position: SIMD3<Float>) -> SIMD3<Float> {
        
        let radius = Double(simd_length(position))
        guard radius.isFinite, radius > 0.0 else {
            return .zero
        }
        
        let magnitude = interpolateRadialScalarTable(
            radius: radius,
            values: radialMagneticMagnitudeTable
        )
        
        guard magnitude.isFinite, magnitude > 0.0 else {
            return .zero
        }
        
        // Reconstruct tangential direction (identical to original magneticField)
        let p = SIMD3<Double>(
            Double(position.x),
            Double(position.y),
            Double(position.z)
        )
        
        let axis = SIMD3<Double>(0.0, 1.0, 0.0)
        
        var tangential = simd_cross(axis, p)
        let tangentialLength = simd_length(tangential)
        
        guard tangentialLength.isFinite, tangentialLength > 0.0 else {
            return .zero
        }
        
        tangential /= tangentialLength
        
        return SIMD3<Float>(
            Float(tangential.x * magnitude),
            Float(tangential.y * magnitude),
            Float(tangential.z * magnitude)
        )
    }
    
    // Generic binary-search interpolator used by the new tables.
    // (Does not touch the existing interpolateRadialPotential.)
    private func interpolateRadialScalarTable(
        radius: Double,
        values: [Double]
    ) -> Double {
        
        guard !radialGravityTable.isEmpty,
              values.count == radialGravityTable.count,
              radius.isFinite
        else {
            return 0.0
        }
        
        if radius <= radialGravityTable[0].radius {
            return values[0]
        }
        
        let lastIndex = radialGravityTable.count - 1
        if radius >= radialGravityTable[lastIndex].radius {
            return values[lastIndex]
        }
        
        var lower = 0
        var upper = lastIndex
        
        while upper - lower > 1 {
            let middle = (lower + upper) >> 1
            if radialGravityTable[middle].radius <= radius {
                lower = middle
            } else {
                upper = middle
            }
        }
        
        let r0 = radialGravityTable[lower].radius
        let r1 = radialGravityTable[upper].radius
        let span = r1 - r0
        
        guard span.isFinite, span > 0.0 else {
            return values[lower]
        }
        
        let t = (radius - r0) / span
        guard t.isFinite else {
            return values[lower]
        }
        
        let value = values[lower] + (values[upper] - values[lower]) * t
        return value.isFinite ? value : values[lower]
    }
    
    // ========================================================
    // EXISTING METHODS (unchanged)
    // ========================================================

    func qrtlEnergyDensity(
        at position: SIMD3<Float>
    ) -> Float {

        let positions =
            densitySource.starPositions

        guard !positions.isEmpty else {
            return 0.0
        }

        let softening =
            Float(
                max(
                    densitySource.softeningLengthMeters,
                    1.0
                )
            )

        let softeningSquared =
            softening * softening

        var spatialWeight: Float = 0.0

        for starPosition in positions {

            let delta =
                position -
                starPosition

            let distanceSquared =
                simd_length_squared(delta)

            let softenedDistanceSquared =
                distanceSquared +
                softeningSquared

            let distance =
                sqrt(
                    softenedDistanceSquared
                )

            guard distance.isFinite,
                  distance > 0.0
            else {
                continue
            }

            spatialWeight +=
                1.0 / distance
        }

        guard spatialWeight.isFinite else {
            return 0.0
        }

        // Normalize the spatial contribution so that the
        // existing cluster-scale QRTL energy-density model
        // remains the amplitude source.
        let referenceEnergyDensity =
            qrtlEnergyDensityFromClusterDensity(
                at: position
            )

        guard referenceEnergyDensity.isFinite,
              referenceEnergyDensity > 0.0
        else {
            return 0.0
        }

        debugQRTLEnergyDensity(at: position)
 
        
        return referenceEnergyDensity *
               spatialWeight
    }
    // ============================================================
    // MARK: - QRTL ENERGY DENSITY DEBUG
    // ============================================================

    private func debugQRTLEnergyDensity(
        at position: SIMD3<Float>
    ) {

        let radius = Double(simd_length(position))

        let massDensityValue = massDensity(
            at: position
        )

        let sourceValue = qrtlSource(
            at: position
        )

        let fluxValue = bolgarinoFlux(
            at: position
        )

        let currentDensityValue = qrtlCurrentDensity(
            at: position
        )

        let currentValue = qrtlCurrent(
            at: position
        )

        let electromagneticValue =
            electromagneticInfluence(
                at: position
            )


#if DEBUG



    print("""
    QRTLField module
    ============================================================
    QRTL ENERGY DENSITY TRACE
    ============================================================
    
    position        = \(position)
    radius          = \(simd_length(position))
    
    qrtlSource      = \(qrtlSource(at: position))
    
    bolgarinoFlux   = \(bolgarinoFlux(at: position))
    
    currentDensity  = \(qrtlCurrentDensity(at: position))
    
    current         = \(qrtlCurrent(at: position))
    
    electromagneticInfluence =
        \(electromagneticInfluence(at: position))
    
    magneticEnergyDensity =
        \(magneticEnergyDensity(at: position))
    
    ============================================================
    """)

#endif
    }
    private func qrtlEnergyDensityFromClusterDensity(
        at position: SIMD3<Float>
    ) -> Float {

        let density =
            densitySource.density(
                at: position
            )

        guard density.isFinite,
              density > 0.0
        else {
            return 0.0
        }

        // QRTL source term.
        let source =
            parameters.alphaQ *
            Double(density)

        guard source.isFinite,
              source > 0.0
        else {
            return 0.0
        }

        // Bolgarino radial flux.
        let flux =
            bolgarinoFlux(
                at: position
            )

        guard flux.isFinite,
              flux > 0.0
        else {
            return 0.0
        }

        let energyDensity =
            source *
            flux

        guard energyDensity.isFinite else {
            return 0.0
        }

        return Float(
            max(
                energyDensity,
                0.0
            )
        )
    }
    func radialCurvatureHeight(
        at position: SIMD3<Float>
    ) -> Float {

        let radius = sqrt(
            position.x * position.x +
            position.z * position.z
        )

        let potential =
            interpolateRadialPotential(
                radius: Double(radius)
            )

        guard potential.isFinite else {
            return 0.0
        }

        return spacetimeCurvatureHeight(
            at : position
        )
    }


    // ============================================================
    // MARK: - SPATIAL GRID INDEX
    // ============================================================
    //
    // Flattened 3D:
    //
    // index = x
    //       + resolution * y
    //       + resolution² * z
    //
    // X changes fastest.
    // Y changes next.
    // Z changes slowest.
    //
    // Total grid size:
    //
    // resolution × resolution × resolution
    //
    // ============================================================

    private func spatialGridIndex(
        x: Int,
        z: Int,
        resolution: Int
    ) -> Int {

        return x + z * resolution
    }
    
    // ============================================================
    // MARK: - BUILD SPATIAL POTENTIAL FROM RADIAL GRAVITY TABLE
    // ============================================================
    //
    // VISUALIZATION ONLY
    //
    // IMPORTANT:
    //
    // This function does NOT solve the gravitational potential.
    //
    // The authoritative QRTL gravity calculation has already been
    // performed when radialGravityTable was constructed:
    //
    //     GlobularClusterDensityMap
    //                ↓
    //            QRTLField
    //                ↓
    //       radialGravityTable
    //
    // This function simply samples the existing radial potential
    // and places it into the 2-D X-Z visualization grid.
    //
    // Therefore there is:
    //
    //     NO 3-D grid
    //     NO cell-mass calculation
    //     NO pairwise gravity summation
    //     NO O(N²) potential solver
    //
    // ============================================================

    private func buildSpatialPotentialFromEnergyDensity(
        radius: Float,
        spacing: Float
    ) {

        // ============================================================
        // VISUALIZATION RESOLUTION
        // ============================================================
        //
        // This is a visualization resolution only.
        //
        // 128 × 128 = 16,384 samples.
        //
        // It is NOT a QRTL physics resolution.
        //
        // ============================================================

        let resolution = 128

        let totalSamples =
            resolution * resolution

        // ============================================================
        // VALIDATE RADIAL TABLE
        // ============================================================

        guard radialGravityTable.count >= 2 else {

            spatialPotentialGrid =
                [Float](
                    repeating: 0.0,
                    count: totalSamples
                )

            return
        }

        guard radius > 0.0 else {

            spatialPotentialGrid =
                [Float](
                    repeating: 0.0,
                    count: totalSamples
                )

            return
        }

        // ============================================================
        // ALLOCATE 2-D POTENTIAL GRID
        // ============================================================

        spatialPotentialGrid =
            [Float](
                repeating: 0.0,
                count: totalSamples
            )

        // ============================================================
        // SAMPLE RADIAL POTENTIAL
        // ============================================================
        //
        // The X-Z plane passes through the center of the cluster.
        //
        // Y = 0
        //
        // Because the QRTL gravity field is radial, every X-Z pixel
        // only needs its radial distance from the cluster center.
        //
        // ============================================================

        for zIndex in 0..<resolution {

            let z =
                -radius +
                Float(zIndex) * spacing

            for xIndex in 0..<resolution {

                let x =
                    -radius +
                    Float(xIndex) * spacing

                let index =
                    xIndex +
                    zIndex * resolution

                // ====================================================
                // RADIAL DISTANCE
                // ====================================================

                let radialDistance =
                    sqrt(
                        x * x +
                        z * z
                    )

                // ====================================================
                // OUTSIDE THE PHYSICAL CLUSTER
                // ====================================================

                if radialDistance >= radius {

                    spatialPotentialGrid[index] =
                        0.0

                    continue
                }

                // ====================================================
                // NORMALIZED RADIAL POSITION
                //
                // 0 → cluster center
                // 1 → cluster radius
                // ====================================================

                let normalizedRadius =
                    radialDistance / radius

                // ====================================================
                // RADIAL TABLE POSITION
                // ====================================================

                let tablePosition =
                    normalizedRadius *
                    Float(
                        radialGravityTable.count - 1
                    )

                let lowerIndex =
                    max(
                        0,
                        min(
                            Int(floor(tablePosition)),
                            radialGravityTable.count - 1
                        )
                    )

                let upperIndex =
                    min(
                        lowerIndex + 1,
                        radialGravityTable.count - 1
                    )

                let fraction =
                    tablePosition -
                    Float(lowerIndex)

                // ====================================================
                // READ AUTHORITATIVE RADIAL VALUES
                // ====================================================

                let lower =
                    radialGravityTable[lowerIndex]

                let upper =
                    radialGravityTable[upperIndex]

                // ====================================================
                // LINEAR INTERPOLATION
                // ====================================================

                let potential =
                    lower.potential +
                    (
                        upper.potential -
                        lower.potential
                    ) * Double(fraction)
                // ====================================================
                // STORE VISUAL POTENTIAL
                // ====================================================

                spatialPotentialGrid[index] =
                    potential.isFinite
                    ? Float(potential)
                    : 0.0
            }
        }
    }
    private func buildRadialGravityTable(
        densitySource: GlobularClusterDensityMap,
        parameters: QRTLParameters,
        sampleCount: Int
    ) -> [RadialGravitySample] {

        let count = max(sampleCount, 2)

        // ============================================================
        // PHYSICAL CLUSTER PARAMETERS
        // ============================================================

        let clusterRadiusMeters =
            Double(densitySource.fieldRadiusMeters)

        let declaredClusterMass =
            Double(densitySource.clusterMassKg)

        guard
            clusterRadiusMeters.isFinite,
            clusterRadiusMeters > 0.0,
            declaredClusterMass.isFinite,
            declaredClusterMass > 0.0
        else {
            return [
                RadialGravitySample(
                    radius: 0.0,
                    energyDensity: 0.0,
                    effectiveMassDensity: 0.0,
                    enclosedMass: 0.0,
                    potential: 0.0
                )
            ]
        }

        let dr =
            clusterRadiusMeters /
            Double(count - 1)

        // ============================================================
        // STEP 1
        //
        // Sample the RAW QRTL effective mass density.
        //
        // IMPORTANT:
        //
        // We do NOT assume that the raw QRTL density already integrates
        // to the declared cluster mass.
        //
        // We first construct the complete radial profile, determine its
        // integrated mass, and then normalize the profile.
        // ============================================================

        var radii =
            [Double](
                repeating: 0.0,
                count: count
            )

        var energyDensities =
            [Double](
                repeating: 0.0,
                count: count
            )

        var rawDensities =
            [Double](
                repeating: 0.0,
                count: count
            )

        let speedOfLight =
            299_792_458.0

        let cSquared =
            speedOfLight * speedOfLight

        for i in 0..<count {

            let radius =
                Double(i) * dr

            radii[i] =
                radius

            guard radius.isFinite else {
                continue
            }

            let position =
                SIMD3<Float>(
                    Float(radius),
                    0.0,
                    0.0
                )

            // --------------------------------------------------------
            // RAW QRTL ENERGY DENSITY
            // --------------------------------------------------------

            let rawEnergy =
                self.qrtlEnergyDensity(
                    at: position
                )

            let energyDensity =
                rawEnergy.isFinite &&
                rawEnergy > 0.0
                ? Double(rawEnergy)
                : 0.0

            energyDensities[i] =
                energyDensity

            // --------------------------------------------------------
            // RAW EFFECTIVE MASS DENSITY
            //
            // rho = u / c²
            // --------------------------------------------------------

            let rawMassDensity =
                energyDensity /
                cSquared

            rawDensities[i] =
                rawMassDensity.isFinite &&
                rawMassDensity > 0.0
                ? rawMassDensity
                : 0.0
        }

        // ============================================================
        // STEP 2
        //
        // Integrate the RAW density profile.
        //
        // M_raw(R) =
        //
        //     ∫ 4πr²ρ_raw(r) dr
        //
        // This tells us what mass the QRTL density profile actually
        // represents before normalization.
        // ============================================================

        let fourPi =
            4.0 * Double.pi

        var rawEnclosedMass =
            [Double](
                repeating: 0.0,
                count: count
            )

        if count > 1 {

            for i in 1..<count {

                let r0 =
                    radii[i - 1]

                let r1 =
                    radii[i]

                let rho0 =
                    rawDensities[i - 1]

                let rho1 =
                    rawDensities[i]

                let shell0 =
                    fourPi *
                    r0 *
                    r0 *
                    rho0

                let shell1 =
                    fourPi *
                    r1 *
                    r1 *
                    rho1

                let shellMass =
                    0.5 *
                    (shell0 + shell1) *
                    (r1 - r0)

                rawEnclosedMass[i] =
                    rawEnclosedMass[i - 1] +
                    max(
                        shellMass,
                        0.0
                    )
            }
        }

        // ============================================================
        // STEP 3
        //
        // DETERMINE MASS NORMALIZATION
        //
        // The raw QRTL density currently integrates to approximately:
        //
        //     1.3568e15 kg
        //
        // while the declared cluster contains:
        //
        //     1.98847e36 kg
        //
        // Therefore we normalize the density profile so that:
        //
        //     M_normalized(R) = declaredClusterMass
        //
        // IMPORTANT:
        //
        // This preserves the SHAPE of the QRTL density profile.
        // It changes only its overall mass scale.
        // ============================================================

        let rawTotalMass =
            rawEnclosedMass.last ?? 0.0

        guard
            rawTotalMass.isFinite,
            rawTotalMass > 0.0
        else {

            print("""
            ============================================================
            QRTL RADIAL FIELD ERROR
            ============================================================

            Raw QRTL density integrated to zero mass.

            rawTotalMass = \(rawTotalMass)
            declaredMass = \(declaredClusterMass)

            Cannot normalize radial density profile.

            ============================================================
            """)

            return [
                RadialGravitySample(
                    radius: 0.0,
                    energyDensity: 0.0,
                    effectiveMassDensity: 0.0,
                    enclosedMass: 0.0,
                    potential: 0.0
                )
            ]
        }

        let massNormalization =
            declaredClusterMass /
            rawTotalMass

        guard
            massNormalization.isFinite,
            massNormalization > 0.0
        else {
            return [
                RadialGravitySample(
                    radius: 0.0,
                    energyDensity: 0.0,
                    effectiveMassDensity: 0.0,
                    enclosedMass: 0.0,
                    potential: 0.0
                )
            ]
        }

        // ============================================================
        // STEP 4
        //
        // APPLY MASS NORMALIZATION TO THE RADIAL DENSITY.
        //
        // rho_normalized =
        //
        //     rho_raw * M_declared / M_raw
        //
        // ============================================================

        var densities =
            [Double](
                repeating: 0.0,
                count: count
            )

        var normalizedEnergyDensities =
            [Double](
                repeating: 0.0,
                count: count
            )

        for i in 0..<count {

            let normalizedDensity =
                rawDensities[i] *
                massNormalization

            densities[i] =
                normalizedDensity.isFinite &&
                normalizedDensity > 0.0
                ? normalizedDensity
                : 0.0

            // Since rho = u / c², convert the normalized density back
            // into the corresponding physical energy density.
            normalizedEnergyDensities[i] =
                densities[i] *
                cSquared
        }

        // ============================================================
        // STEP 5
        //
        // INTEGRATE THE NORMALIZED MASS DENSITY.
        //
        // M(r) = ∫ 4πr²ρ(r)dr
        // ============================================================

        var enclosedMass =
            [Double](
                repeating: 0.0,
                count: count
            )

        if count > 1 {

            for i in 1..<count {

                let r0 =
                    radii[i - 1]

                let r1 =
                    radii[i]

                let rho0 =
                    densities[i - 1]

                let rho1 =
                    densities[i]

                let shell0 =
                    fourPi *
                    r0 *
                    r0 *
                    rho0

                let shell1 =
                    fourPi *
                    r1 *
                    r1 *
                    rho1

                let shellMass =
                    0.5 *
                    (shell0 + shell1) *
                    (r1 - r0)

                enclosedMass[i] =
                    enclosedMass[i - 1] +
                    max(
                        shellMass,
                        0.0
                    )
            }
        }

        // ============================================================
        // STEP 6
        //
        // FORCE THE FINAL MASS TO THE DECLARED CLUSTER MASS ONLY
        // WITHIN NUMERICAL ROUNDING.
        //
        // This is a safety check, NOT a physics correction.
        //
        // The normalization above should already make these equal.
        // ============================================================

        let integratedMass =
            enclosedMass.last ?? 0.0

        let massRatio =
            integratedMass /
            declaredClusterMass

        // ============================================================
        // STEP 7
        //
        // EXTERIOR SHELL CONTRIBUTION
        //
        // Φ(r) =
        //
        // -G [
        //
        //      M(r)/r
        //
        //      +
        //
        //      ∫r^R 4πsρ(s)ds
        //
        // ]
        // ============================================================

        var exteriorShellIntegral =
            [Double](
                repeating: 0.0,
                count: count
            )

        if count > 1 {

            exteriorShellIntegral[count - 1] =
                0.0

            for i in stride(
                from: count - 2,
                through: 0,
                by: -1
            ) {

                let r0 =
                    radii[i]

                let r1 =
                    radii[i + 1]

                let rho0 =
                    densities[i]

                let rho1 =
                    densities[i + 1]

                let integrand0 =
                    fourPi *
                    r0 *
                    rho0

                let integrand1 =
                    fourPi *
                    r1 *
                    rho1

                let shellContribution =
                    0.5 *
                    (integrand0 + integrand1) *
                    (r1 - r0)

                exteriorShellIntegral[i] =
                    exteriorShellIntegral[i + 1] +
                    max(
                        shellContribution,
                        0.0
                    )
            }
        }

        // ============================================================
        // STEP 8
        //
        // BUILD POTENTIAL
        // ============================================================

        let gravitationalConstant =
            6.67430e-11

        var samples =
            [RadialGravitySample]()

        samples.reserveCapacity(
            count
        )

        for i in 0..<count {

            let radius =
                radii[i]

            let mass =
                enclosedMass[i]

            let exteriorContribution =
                exteriorShellIntegral[i]

            let enclosedContribution: Double

            if radius > 0.0 {

                enclosedContribution =
                    mass /
                    radius

            } else {

                enclosedContribution =
                    0.0
            }

            let potential =
                -gravitationalConstant *
                (
                    enclosedContribution +
                    exteriorContribution
                )

            samples.append(
                RadialGravitySample(
                    radius:
                        radius,

                    energyDensity:
                        normalizedEnergyDensities[i],

                    effectiveMassDensity:
                        densities[i],

                    enclosedMass:
                        mass,

                    potential:
                        potential.isFinite
                        ? potential
                        : 0.0
                )
            )
        }

        // ============================================================
        // STEP 9
        //
        // FINAL MASS CONSISTENCY CHECK
        // ============================================================

        let finalMass =
            samples.last?.enclosedMass ?? 0.0

        let finalMassRatio =
            finalMass /
            declaredClusterMass

        let directPotentialAtRadius =
            -gravitationalConstant *
            declaredClusterMass /
            clusterRadiusMeters

        let tablePotentialAtRadius =
            samples.last?.potential ?? 0.0

        let potentialRatio =
            directPotentialAtRadius != 0.0
            ? tablePotentialAtRadius /
              directPotentialAtRadius
            : 0.0

        #if DEBUG

        print("""
        ============================================================
        QRTL CLUSTER MASS NORMALIZATION
        ============================================================

        CLUSTER

            declaredMass =
                \(declaredClusterMass) kg

            clusterRadius =
                \(clusterRadiusMeters) m

        ------------------------------------------------------------

        RAW QRTL DENSITY

            rawIntegratedMass =
                \(rawTotalMass) kg

        ------------------------------------------------------------

        MASS NORMALIZATION

            normalizationFactor =
                \(massNormalization)

        ------------------------------------------------------------

        NORMALIZED RADIAL MASS

            integratedMass =
                \(integratedMass) kg

            massRatio =
                \(massRatio)

        ------------------------------------------------------------

        EXPECTED

            massRatio ≈ 1.0

        ------------------------------------------------------------

        EDGE POTENTIAL

            directPotential =
                \(directPotentialAtRadius) m²/s²

            tablePotential =
                \(tablePotentialAtRadius) m²/s²

            potentialRatio =
                \(potentialRatio)

        ------------------------------------------------------------

        EXPECTED

            potentialRatio ≈ 1.0

        ============================================================
        """)

        let debugIndices = [
            0,
            count / 4,
            count / 2,
            (count * 3) / 4,
            count - 1
        ]

        for index in debugIndices {

            print("""
            ------------------------------------------------------------
            Radius \(index)
            ------------------------------------------------------------

                normalizedRadius =
                    \(Double(index) / Double(count - 1))

                physicalRadiusMeters =
                    \(radii[index])

                rawEnergyDensity =
                    \(energyDensities[index])

                normalizedEnergyDensity =
                    \(normalizedEnergyDensities[index])

                rawEffectiveDensity =
                    \(rawDensities[index])

                normalizedEffectiveDensity =
                    \(densities[index])

                rawEnclosedMass =
                    \(rawEnclosedMass[index])

                normalizedEnclosedMass =
                    \(enclosedMass[index])

                massFraction =
                    \(enclosedMass[index] / declaredClusterMass)

                exteriorContribution =
                    \(exteriorShellIntegral[index])

                tablePotential =
                    \(samples[index].potential)

            """)
        }

        print("""
        ============================================================
        QRTL RADIAL FIELD DEBUG COMPLETE
        ============================================================
        """)

        #endif

        return samples
    }

    // ============================================================
    // RADIAL GRAVITY LOOKUP TABLE
    // ============================================================
    //
    // Precomputes the spherical QRTL gravitational field once.
    //
    // Each sample stores:
    //
    //   radius
    //   effective QRTL mass density
    //   enclosed effective mass
    //   QRTL gravitational potential
    //
    // Runtime photon tracing can then interpolate these values
    // instead of rebuilding the 256-shell integral every call.
    //
    // ============================================================

   
    func qrtlGravitationalPotential(
        at position: SIMD3<Float>
    ) -> Double {

        let radius = Double(simd_length(position))

        guard radius.isFinite else {
            return 0.0
        }

        return interpolateRadialPotential(
            radius: radius
        )
    }
    // ============================================================
    // INTERPOLATE RADIAL QRTL GRAVITATIONAL POTENTIAL
    // ============================================================
    //
    // Returns Phi(r) from the precomputed radialGravityTable.
    //
    // The table is assumed to be ordered by increasing radius.
    //
    // ============================================================

    func interpolateRadialPotential(
        radius: Double
    ) -> Double {

        let table = radialGravityTable

        guard !table.isEmpty,
              radius.isFinite else {
            return 0.0
        }

        let r = max(radius, 0.0)

        // ============================================================
        // BELOW TABLE RANGE
        // ============================================================
        //
        // IMPORTANT:
        // Do NOT clamp the gravitational potential to zero.
        //
        // A gravitational potential is normally negative:
        //
        //     Phi < 0
        //
        // The sign must be preserved because QRTLPhotonTracer
        // converts this physical potential into:
        //
        //     U = Phi / c²
        //
        // which then determines the spacetime metric.
        //
        // ============================================================

        if r <= table[0].radius {
            return table[0].potential.isFinite
                ? table[0].potential
                : 0.0
        }

        // ============================================================
        // ABOVE TABLE RANGE
        // ============================================================
        //
        // Preserve the signed physical potential.
        //
        // Do NOT use:
        //
        //     max(potential, 0.0)
        //
        // ============================================================

        if r >= table[table.count - 1].radius {
            return table[table.count - 1].potential.isFinite
                ? table[table.count - 1].potential
                : 0.0
        }

        // ============================================================
        // BINARY SEARCH
        // ============================================================

        var low = 0
        var high = table.count - 1

        while high - low > 1 {

            let middle = (low + high) / 2

            if table[middle].radius <= r {
                low = middle
            } else {
                high = middle
            }
        }

        let lower = table[low]
        let upper = table[high]

        // ============================================================
        // VALIDATE RADIAL INTERVAL
        // ============================================================

        let denominator =
            upper.radius - lower.radius

        guard denominator.isFinite,
              denominator > 0.0,
              lower.radius.isFinite,
              upper.radius.isFinite,
              lower.potential.isFinite,
              upper.potential.isFinite else {

            return lower.potential.isFinite
                ? lower.potential
                : 0.0
        }

        // ============================================================
        // LINEAR INTERPOLATION
        // ============================================================

        let t = min(
            max(
                (r - lower.radius) / denominator,
                0.0
            ),
            1.0
        )

        let potential =
            lower.potential +
            (upper.potential - lower.potential) * t

        // ============================================================
        // RETURN SIGNED PHYSICAL POTENTIAL
        // ============================================================

        guard potential.isFinite else {
            return 0.0
        }

        return potential
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

        let x = Double(position.x)
        let y = Double(position.y)
        let z = Double(position.z)

        let radius = sqrt(
            x * x +
            y * y +
            z * z
        )

        let density =
            densitySource.physicalMassDensity(
                at: position
            )

        guard density.isFinite,
              density >= 0.0
        else {

            print("""
            ============================================================
            QRTL MASS DENSITY DEBUG — INVALID
            ============================================================
            position          = \(position)
            radiusMeters      = \(radius)
            physicalDensity   = \(density)
            units              = kg/m³
            ============================================================
            """)

            return 0.0
        }

        print("""
        ============================================================
        QRTL MASS DENSITY DEBUG
        ============================================================
        position          = \(position)
        radiusMeters      = \(radius)
        physicalDensity   = \(density) kg/m³
        clusterMass       = \(clusterMassKg) kg
        clusterRadius     = \(clusterRadiusMeters) m
        ============================================================
        """)

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

        // ============================================================
        // AUTHORITATIVE QRTL POTENTIAL
        // ============================================================

        let potential =
            gravitationalPotential(
                at: position
            )

        // ============================================================
        // QRTL SPACETIME CURVATURE
        //
        // Weak-field relationship:
        //
        // curvature ∝ -2 Φ / c²
        //
        // The result is dimensionless.
        // ============================================================

        let curvature =
            -2.0 * Float (potential) * inverseSpeedOfLightSquared

        // ============================================================
        // VISUAL AMPLIFICATION
        //
        // The physical curvature can be extremely small.
        // Therefore convert the dimensionless curvature into
        // SceneKit display units.
        // ============================================================

        let height =
            curvature *
            spacetimeHeightScale

        // ============================================================
        // SAFETY
        // ============================================================

        guard height.isFinite else {
            return 0.0
        }

        return height
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

    // ============================================================
    // AUTHORITATIVE GRAVITATIONAL POTENTIAL
    // ============================================================
    //
    // Returns the physical gravitational potential:
    //
    //     Φ(r)  [m²/s²]
    //
    // Convention:
    //
    //     Φ < 0
    //
    // The potential is referenced to:
    //
    //     Φ(∞) = 0
    //
    // For a spherically symmetric mass distribution:
    //
    //     inside:
    //         Φ(r) = -G [ M(r)/r + ∫r∞ (1/r') dM(r') ]
    //
    //     outside:
    //         Φ(r) = -G Mtotal / r
    //
    // IMPORTANT:
    //
    // This function is the authoritative source of Φ for:
    //
    //     • QRTLPhotonTracer
    //     • QRTLGravitySurfaceEntity
    //     • QRTLHeatmapGenerator
    //     • radial gravity diagnostics
    //
    // The optional effectiveEnergyDensity parameter is retained for
    // API compatibility, but it must NOT replace the physical mass
    // model unless the caller explicitly supplies a physically
    // equivalent density.
    //
    // ============================================================

    func gravitationalPotential(
        at position: SIMD3<Float>,
        effectiveEnergyDensity: Double? = nil
    ) -> Double {

        let x = Double(position.x)
        let y = Double(position.y)
        let z = Double(position.z)

        guard
            x.isFinite,
            y.isFinite,
            z.isFinite
        else {
            print(
                "QRTL Φ DEBUG: INVALID POSITION",
                position
            )
            return 0.0
        }

        let radius = sqrt(
            x * x +
            y * y +
            z * z
        )

        guard radius.isFinite else {
            print(
                "QRTL Φ DEBUG: INVALID RADIUS"
            )
            return 0.0
        }

        let clusterRadius = Double(
            clusterRadiusMeters
        )

        guard
            clusterRadius.isFinite,
            clusterRadius > 0.0
        else {
            print(
                "QRTL Φ DEBUG: INVALID CLUSTER RADIUS =",
                clusterRadius
            )
            return 0.0
        }

        // ============================================================
        // CENTER
        // ============================================================

        if radius <= 0.0 {

            guard let firstSample =
                    radialGravityTable.first
            else {
                print(
                    "QRTL Φ DEBUG: RADIAL TABLE EMPTY"
                )
                return 0.0
            }

            let potential =
                Double(firstSample.potential)

            print(
                "QRTL Φ DEBUG CENTER:",
                "position =", position,
                "radiusMeters =", radius,
                "potential =", potential,
                "normalized? = NO",
                "units = m²/s²",
                "source = radialGravityTable.first.potential"
            )

            guard potential.isFinite else {
                return 0.0
            }

            return potential
        }

        // ============================================================
        // INTERIOR
        // ============================================================

        if radius < clusterRadius {

            let potential =
                interpolateRadialPotential(
                    radius: radius
                )

            print(
                "QRTL Φ DEBUG INTERIOR:",
                "position =", position,
                "radiusMeters =", radius,
                "clusterRadiusMeters =", clusterRadius,
                "normalizedRadius =", radius / clusterRadius,
                "potential =", potential,
                "absPotential =", abs(potential),
                "normalized? = NO",
                "units = m²/s²",
                "source = interpolateRadialPotential"
            )

            guard potential.isFinite else {
                return 0.0
            }

            return potential
        }

        // ============================================================
        // EXTERIOR
        // ============================================================

        guard
            clusterMassKg.isFinite,
            clusterMassKg > 0.0,
            gravitationalConstant.isFinite,
            gravitationalConstant > 0.0
        else {
            print(
                "QRTL Φ DEBUG: INVALID MASS OR G",
                "mass =", clusterMassKg,
                "G =", gravitationalConstant
            )
            return 0.0
        }

        let potential =
            -gravitationalConstant *
            clusterMassKg /
            radius

        print(
            "QRTL Φ DEBUG EXTERIOR:",
            "position =", position,
            "radiusMeters =", radius,
            "clusterRadiusMeters =", clusterRadius,
            "potential =", potential,
            "absPotential =", abs(potential),
            "normalized? = NO",
            "units = m²/s²",
            "source = -G*M/r"
        )

        guard potential.isFinite else {
            return 0.0
        }

        return potential
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

        // ------------------------------------------------------------
        // QRTL / BOLGARINO FLUX
        // ------------------------------------------------------------

        let flux = bolgarinoFlux(
            at: position
        )

        guard flux.isFinite,
              flux > 0.0
        else {
            return 0.0
        }

        // ------------------------------------------------------------
        // QRTL TRANSPORT VELOCITY
        // ------------------------------------------------------------

        let velocity = max(
            parameters.qrtlVelocity,
            0.0
        )

        guard velocity.isFinite,
              velocity > 0.0
        else {
            return 0.0
        }

        // ------------------------------------------------------------
        // CHARACTERISTIC QRTL INTERACTION LENGTH
        //
        // This must be a physical length in meters. Uses the same
        // authoritative clusterRadiusMeters (sourced from the
        // density map) as everywhere else — not an independent
        // parameters.clusterRadiusParsecs derivation, which is the
        // same stale/unsynced value already fixed above.
        // ------------------------------------------------------------

        let interactionLength =
            clusterRadiusMeters

        guard interactionLength.isFinite,
              interactionLength > 0.0
        else {
            return 0.0
        }

        // ------------------------------------------------------------
        // QRTL INTERACTION RATE
        //
        // ΓQ = vQ / LQ
        //
        // Units:
        //
        // (meters / second) / meter
        // = 1 / second
        // ------------------------------------------------------------

        let interactionRate =
            velocity /
            interactionLength

        guard interactionRate.isFinite,
              interactionRate > 0.0
        else {
            return 0.0
        }

        // ------------------------------------------------------------
        // QRTL COUPLING EFFICIENCY
        // ------------------------------------------------------------

        let coupling =
            max(
                parameters.etaQ,
                0.0
            )

        // ------------------------------------------------------------
        // QRTL CURRENT DENSITY
        //
        // JQ = ηQ × ΦQ × ΓQ
        //
        // therefore:
        //
        // JQ = ηQ × ΦQ × vQ / LQ
        // ------------------------------------------------------------

        let currentDensity =
            coupling *
            flux *
            interactionRate

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

        let p = SIMD3<Double>(
            Double(position.x),
            Double(position.y),
            Double(position.z)
        )

        let rSquared =
            simd_length_squared(p)

        guard rSquared.isFinite,
              rSquared > 0.0
        else {
            return .zero
        }

        let r =
            sqrt(rSquared)

        guard r.isFinite,
              r > 0.0
        else {
            return .zero
        }

        let currentDensity =
            qrtlCurrentDensity(
                at: position
            )

        guard currentDensity.isFinite,
              currentDensity >= 0.0
        else {
            return .zero
        }

        let mu0 =
            4.0 *
            Double.pi *
            1.0e-7

        /*
         QRTL magnetic coupling.

         The local current density generates
         a circulating magnetic field around
         the QRTL flow axis.
        */

        let magneticScale =
            max(
                parameters.electromagneticCoupling,
                0.0
            )

        let magnitude =
            mu0 *
            magneticScale *
            currentDensity *
            r

        guard magnitude.isFinite,
              magnitude >= 0.0
        else {
            return .zero
        }

        let axis =
            SIMD3<Double>(
                0.0,
                1.0,
                0.0
            )

        var tangential =
            simd_cross(
                axis,
                p
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
            Float(tangential.x * magnitude),
            Float(tangential.y * magnitude),
            Float(tangential.z * magnitude)
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

        let density = Double(energy) / speedOfLightSquared

        guard density.isFinite,
              density >= 0.0
        else {
            return 0.0
        }

        return density
    }

   
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

        guard clusterRadius.isFinite,
              clusterRadius > 0.0
        else {
            return 0.0
        }

        // --------------------------------------------------------
        // Radial integration resolution
        // --------------------------------------------------------

        let sampleCount =
            256

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

        // --------------------------------------------------------
        // Integrate QRTL effective mass density
        //
        // rho_Q(r) = u_Q(r) / c²
        //
        // IMPORTANT:
        // No qrtlGravityIndex is applied.
        // --------------------------------------------------------

        for index in 0..<sampleCount {

            let r0 =
                Double(index) *
                dr

            let r1 =
                Double(index + 1) *
                dr

            guard r1 > r0
            else {
                continue
            }

            let shellRadius =
                0.5 *
                (r0 + r1)

            let position =
                SIMD3<Float>(
                    Float(shellRadius),
                    0.0,
                    0.0
                )

            let massDensity =
                qrtlEffectiveMassDensity(
                    at: position
                )

            guard massDensity.isFinite,
                  massDensity >= 0.0
            else {
                continue
            }

            // ----------------------------------------------------
            // Spherical shell volume
            //
            // dV = 4π/3 (r₁³ - r₀³)
            // ----------------------------------------------------

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

            // ----------------------------------------------------
            // Shell mass
            //
            // dM = rho_Q dV
            // ----------------------------------------------------

            let shellMass =
                massDensity *
                shellVolume

            guard shellMass.isFinite,
                  shellMass >= 0.0
            else {
                continue
            }

            totalMass +=
                shellMass
        }

        guard totalMass.isFinite,
              totalMass >= 0.0
        else {
            return 0.0
        }

        return totalMass
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

        let directionLength =
            simd_length(
                direction
            )

        guard directionLength.isFinite,
              directionLength > 0.0
        else {
            return .zero
        }

        let cSquared =
            speedOfLightSquared

        guard cSquared.isFinite,
              cSquared > 0.0
        else {
            return .zero
        }

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

        // --------------------------------------------------------
        // QRTL photon curvature
        //
        // The photon responds only to the transverse component
        // of the QRTL gravitational acceleration.
        //
        // curvature magnitude:
        //
        //     -2 |g_transverse| / c²
        //
        // The factor of 2 provides the Einstein-style photon
        // curvature scaling.
        // --------------------------------------------------------

        let curvatureMagnitude =
            -2.0 *
            Double(magnitude) /
            cSquared

        guard curvatureMagnitude.isFinite
        else {
            return .zero
        }

        let curvatureDirection =
            transverseGravity /
            magnitude

        guard curvatureDirection.x.isFinite,
              curvatureDirection.y.isFinite,
              curvatureDirection.z.isFinite
        else {
            return .zero
        }

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

        let cSquared =
            speedOfLightSquared

        guard cSquared.isFinite,
              cSquared > 0.0
        else {
            return 1.0
        }

        // --------------------------------------------------------
        // Gravitational optical index
        //
        // n_G = 1 - 2Φ_Q / c²
        //
        // Since Φ_Q <= 0 for an attractive QRTL field,
        // n_G >= 1 in the gravitational well.
        // --------------------------------------------------------

        let normalized =
            -2.0 *
            potential /
            cSquared

        guard normalized.isFinite
        else {
            return 1.0
        }

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

        guard influence.isFinite,
              influence >= 0.0
        else {
            return 0.0
        }

        let coupling =
            max(
                parameters.photonEMCoupling,
                0.0
            )

        guard coupling.isFinite
        else {
            return 0.0
        }

        // --------------------------------------------------------
        // Electromagnetic optical contribution
        //
        // n_EM = coupling × electromagneticInfluence
        //
        // This is an optical contribution only.
        // It does not modify QRTL gravitational mass.
        // --------------------------------------------------------

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

        guard gravitational.isFinite,
              gravitational > 0.0,
              electromagnetic.isFinite
        else {
            return 1.0
        }

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

        // ========================================================
        // SPATIAL SCALE
        // ========================================================

        let radius =
            Double(
                simd_length(position)
            )

        guard radius.isFinite,
              radius >= 0.0
        else {
            return .zero
        }

        // Adaptive finite-difference step.
        //
        // The step scales with distance from the QRTL center,
        // while retaining a minimum numerical step.
        //

        let h =
            max(
                radius * 1.0e-3,
                1.0e-3
            )

        guard h.isFinite,
              h > 0.0
        else {
            return .zero
        }

        let step =
            Float(h)

        guard step.isFinite,
              step > 0.0
        else {
            return .zero
        }

        // ========================================================
        // FINITE-DIFFERENCE OFFSETS
        // ========================================================

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

        // ========================================================
        // TOTAL OPTICAL INDEX
        //
        // d n / d x
        // d n / d y
        // d n / d z
        //
        // Central finite difference:
        //
        // df/dx =
        //     [f(x+h) - f(x-h)] / 2h
        // ========================================================

        let indexXPlus =
            totalIndex(
                at:
                    position + dx
            )

        let indexXMinus =
            totalIndex(
                at:
                    position - dx
            )

        let indexYPlus =
            totalIndex(
                at:
                    position + dy
            )

        let indexYMinus =
            totalIndex(
                at:
                    position - dy
            )

        let indexZPlus =
            totalIndex(
                at:
                    position + dz
            )

        let indexZMinus =
            totalIndex(
                at:
                    position - dz
            )

        guard indexXPlus.isFinite,
              indexXMinus.isFinite,
              indexYPlus.isFinite,
              indexYMinus.isFinite,
              indexZPlus.isFinite,
              indexZMinus.isFinite
        else {
            return .zero
        }

        // ========================================================
        // CENTRAL DIFFERENCES
        // ========================================================

        let denominator =
            2.0 * h

        guard denominator.isFinite,
              denominator > 0.0
        else {
            return .zero
        }

        let xGradient =
            (
                indexXPlus -
                indexXMinus
            ) /
            denominator

        let yGradient =
            (
                indexYPlus -
                indexYMinus
            ) /
            denominator

        let zGradient =
            (
                indexZPlus -
                indexZMinus
            ) /
            denominator

        guard xGradient.isFinite,
              yGradient.isFinite,
              zGradient.isFinite
        else {
            return .zero
        }

        // ========================================================
        // RETURN GRADIENT
        // ========================================================

        let result =
            SIMD3<Float>(
                Float(xGradient),
                Float(yGradient),
                Float(zGradient)
            )

        guard result.x.isFinite,
              result.y.isFinite,
              result.z.isFinite
        else {
            return .zero
        }

        return result
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

        // ========================================================
        // QRTL GRAVITATIONAL CURVATURE
        //
        // Derived from the QRTL gravitational potential.
        //
        // No qrtlGravityIndex calibration is used.
        // ========================================================

        let gravitationalCurvature =
            qrtlPhotonCurvature(
                at: position,
                direction: direction
            )

        guard
            gravitationalCurvature.x.isFinite,
            gravitationalCurvature.y.isFinite,
            gravitationalCurvature.z.isFinite
        else {
            return .zero
        }

        // ========================================================
        // PHOTON DIRECTION
        // ========================================================

        let directionLength =
            simd_length(direction)

        guard
            directionLength.isFinite,
            directionLength > 0.0
        else {
            return gravitationalCurvature
        }

        let normalizedDirection =
            direction /
            directionLength

        // ========================================================
        // ELECTROMAGNETIC OPTICAL GRADIENT
        //
        // IMPORTANT:
        //
        // Do NOT use indexGradient() here because indexGradient()
        // differentiates totalIndex(), which already contains the
        // gravitational index.
        //
        // The gravitational contribution is already supplied by
        // qrtlPhotonCurvature().
        //
        // Therefore only the electromagnetic optical contribution
        // is differentiated here.
        // ========================================================

        let radius =
            max(
                Double(simd_length(position)),
                1.0
            )

        let h =
            Float(
                max(
                    radius * 1.0e-3,
                    1.0
                )
            )

        guard
            h.isFinite,
            h > 0.0
        else {
            return gravitationalCurvature
        }

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

        // ========================================================
        // ELECTROMAGNETIC OPTICAL CONTRIBUTION
        // ========================================================

        let electromagneticXPlus =
            electromagneticOpticalContribution(
                at: position + dx
            )

        let electromagneticXMinus =
            electromagneticOpticalContribution(
                at: position - dx
            )

        let electromagneticYPlus =
            electromagneticOpticalContribution(
                at: position + dy
            )

        let electromagneticYMinus =
            electromagneticOpticalContribution(
                at: position - dy
            )

        let electromagneticZPlus =
            electromagneticOpticalContribution(
                at: position + dz
            )

        let electromagneticZMinus =
            electromagneticOpticalContribution(
                at: position - dz
            )

        guard
            electromagneticXPlus.isFinite,
            electromagneticXMinus.isFinite,
            electromagneticYPlus.isFinite,
            electromagneticYMinus.isFinite,
            electromagneticZPlus.isFinite,
            electromagneticZMinus.isFinite
        else {
            return gravitationalCurvature
        }

        // ========================================================
        // CENTRAL DIFFERENCE
        //
        // grad(n_EM)
        // ========================================================

        let denominator =
            2.0 * Double(h)

        guard
            denominator.isFinite,
            denominator > 0.0
        else {
            return gravitationalCurvature
        }

        let electromagneticGradient =
            SIMD3<Float>(
                Float(
                    (
                        electromagneticXPlus -
                        electromagneticXMinus
                    ) /
                    denominator
                ),
                Float(
                    (
                        electromagneticYPlus -
                        electromagneticYMinus
                    ) /
                    denominator
                ),
                Float(
                    (
                        electromagneticZPlus -
                        electromagneticZMinus
                    ) /
                    denominator
                )
            )

        guard
            electromagneticGradient.x.isFinite,
            electromagneticGradient.y.isFinite,
            electromagneticGradient.z.isFinite
        else {
            return gravitationalCurvature
        }

        // ========================================================
        // REMOVE PARALLEL COMPONENT
        //
        // Only the transverse optical gradient bends the photon.
        // ========================================================

        let gradientParallel =
            simd_dot(
                electromagneticGradient,
                normalizedDirection
            )

        guard gradientParallel.isFinite
        else {
            return gravitationalCurvature
        }

        let transverseGradient =
            electromagneticGradient -
            normalizedDirection *
            gradientParallel

        guard
            transverseGradient.x.isFinite,
            transverseGradient.y.isFinite,
            transverseGradient.z.isFinite
        else {
            return gravitationalCurvature
        }

        // ========================================================
        // ELECTROMAGNETIC PHOTON COUPLING
        // ========================================================

        let electromagneticScale =
            max(
                parameters.photonEMCoupling,
                0.0
            )

        guard
            electromagneticScale.isFinite
        else {
            return gravitationalCurvature
        }

        // ========================================================
        // ELECTROMAGNETIC OPTICAL CURVATURE
        // ========================================================

        let opticalCurvature =
            -transverseGradient *
            Float(
                electromagneticScale
            )

        guard
            opticalCurvature.x.isFinite,
            opticalCurvature.y.isFinite,
            opticalCurvature.z.isFinite
        else {
            return gravitationalCurvature
        }

        // ========================================================
        // TOTAL QRTL PHOTON LENSING ACCELERATION
        //
        // QRTL gravitational curvature
        // +
        // electromagnetic optical curvature
        // ========================================================

        let result =
            gravitationalCurvature +
            opticalCurvature

        guard
            result.x.isFinite,
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
                Double(qrtlEnergy),

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

            Total optical index:
                \(s.totalIndex)

            ============================================================
            """
        )
    }
}
