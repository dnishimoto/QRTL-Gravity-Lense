//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/20/26.
//

import Foundation


struct GravitySurfaceDiagnostics {

    // ============================================================
    // FIELD STATISTICS
    // ============================================================

    var sampleCount: Int = 0

    var minimumFieldIntensity: Float = 0.0

    var maximumFieldIntensity: Float = 0.0

    var averageFieldIntensity: Float = 0.0

    var centerFieldIntensity: Float = 0.0

    // ============================================================
    // RADIAL FIELD VALIDATION
    // ============================================================

    var radialSamples:
        [(radius: Float, intensity: Float)] = []

    var radialIncreasingViolations: Int = 0

    var radialDecreasingViolations: Int = 0

    // ============================================================
    // SYMMETRY VALIDATION
    // ============================================================

    var symmetryMaximumError: Float = 0.0

    var symmetryAverageError: Float = 0.0

    // ============================================================
    // SURFACE DEPTH
    // ============================================================

    var centerDepth: Float = 0.0

    var rimDepth: Float = 0.0

    // ============================================================
    // SURFACE CURVATURE
    // ============================================================

    var curvatureSamples: Int = 0

    var concaveCenter: Bool = false

    var curvatureMagnitude: Float = 0.0
}

