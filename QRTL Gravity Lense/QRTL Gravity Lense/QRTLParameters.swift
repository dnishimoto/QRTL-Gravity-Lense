//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/17/26.
//
//
//  QRTLField.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/17/26.
//

import Foundation
import simd

// ============================================================
// QRTL PARAMETERS
// ============================================================

struct QRTLParameters {

    /// QRTL source strength (scene-unit visualization needs O(0.01–0.1))
    var alphaQ: Double = 0.05

    /// Bolgarino / QRTL propagation velocity
    var qrtlVelocity: Double = PhysicalConstants.c

    /// Radial attenuation rate
    var interactionRate: Double = 0.0

    /// Converts QRTL current into QRTL energy density
    var chiQ: Double = 1.0

    /// Converts QRTL energy density into effective gravitating density
    var etaQ: Double = 1.0

    /// PPN-style gamma (1 ≈ GR weak-field spatial curvature weight in simple models)
    var gammaQ: Double = 1.0

    /// QRTL → effective EM current coupling
    var electromagneticCoupling: Double = 0.05

    var electricFieldCoupling: Double = 1.0
    var magneticFieldCoupling: Double = 1.0

    /// EM → photon refractive-index coupling (was ~0 / 1e-21 — main reason EM did nothing)
    var photonEMCoupling: Double = 0.05

    var epsilon: Double = 1.0e-12

    /// Minimum integration step in **scene units** (not metres / solar radii)
    var minimumStep: Double = 0.02

    /// Safety limit for rays
    var maximumRaySteps: Int = 2000

    // Kept for compatibility with older call sites; prefer `minimumStep` in scene units
    var minimumStepSolarRadii: Double {
        get { minimumStep }
        set { minimumStep = newValue }
    }
}

// ============================================================
// MASS MODEL
// ============================================================

struct GaussianMassModel {

    let totalMass: Double
    let characteristicRadius: Double

    init(totalMass: Double, characteristicRadius: Double) {
        self.totalMass = totalMass
        self.characteristicRadius = max(characteristicRadius, 0.000001)
    }

    /// ρ(r) = M / ((2π)^{3/2} σ³) × exp(-r² / (2σ²))
    func density(at position: SIMD3<Double>) -> Double {
        let sigma = characteristicRadius
        let radiusSquared =
            position.x * position.x +
            position.y * position.y +
            position.z * position.z

        let normalization =
            totalMass /
            (pow(2.0 * Double.pi, 1.5) * pow(sigma, 3.0))

        let exponent = -radiusSquared / (2.0 * sigma * sigma)
        return normalization * exp(exponent)
    }

    /// Center = 1, far away → 0
    func normalizedDensity(at position: SIMD3<Double>) -> Double {
        let sigma = characteristicRadius
        let radiusSquared =
            position.x * position.x +
            position.y * position.y +
            position.z * position.z
        let exponent = -radiusSquared / (2.0 * sigma * sigma)
        return exp(exponent)
    }
}

