
// ============================================================
// GLOBULAR CLUSTER DENSITY SOURCE PROTOCOL
// ============================================================

import Foundation
import simd

protocol GlobularClusterDensitySource {

    // ============================================================
    // MASS DENSITY
    // ============================================================

    func density(
        at position: SIMD3<Float>
    ) -> Float

    // ============================================================
    // DIRECT GRAVITATIONAL FIELD
    // ============================================================

    func gravitationalPotential(
        at position: SIMD3<Float>
    ) -> Double

    func gravitationalAcceleration(
        at position: SIMD3<Float>
    ) -> SIMD3<Float>

    // ============================================================
    // CLUSTER PROPERTIES
    // ============================================================

    var totalMass: Float { get }

    var maximumDensity: Float { get }

    var integratedDensity: Float { get }

    var fieldRadiusMeters: Float { get }

    var starCount: Int { get }

    var perStarMassKg: Float { get }
}
