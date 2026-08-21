//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/20/26.
//

import Foundation
import simd

// ============================================================
// GLOBULAR CLUSTER DENSITY SOURCE PROTOCOL
// ============================================================

protocol GlobularClusterDensitySource {

    // ========================================================
    // CONTINUOUS MASS DENSITY
    // ========================================================

    func density(
        at position: SIMD3<Float>
    ) -> Float

    // ========================================================
    // CLUSTER DENSITY PROPERTIES
    // ========================================================

    var totalMass: Float { get }

    var maximumDensity: Float { get }

    var integratedDensity: Float { get }

    var fieldRadiusMeters: Float { get }

    // ========================================================
    // GRAVITY MEASUREMENT
    // ========================================================

    var starCount: Int { get }

    // ========================================================
    // MASS PER SOURCE STAR
    // ========================================================

    var perStarMassKg: Float { get }
}
