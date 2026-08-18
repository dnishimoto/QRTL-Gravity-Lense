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

// ============================================================
// QRTL FIELD
// ============================================================

final class QRTLField {

    let massModel: GaussianMassModel
    let parameters: QRTLParameters
    let referenceDensity: Float

    init(massModel: GaussianMassModel, parameters: QRTLParameters) {
        self.massModel = massModel
        self.parameters = parameters

        let centerDensity = massModel.density(at: .zero)
        self.referenceDensity = max(Float(centerDensity), 0.000001)
    }

    func massDensity(at position: SIMD3<Float>) -> Float {
        let p = SIMD3<Double>(Double(position.x), Double(position.y), Double(position.z))
        return Float(massModel.density(at: p))
    }

    func normalizedDensity(at position: SIMD3<Float>) -> Float {
        let density = massDensity(at: position)
        return min(max(density / referenceDensity, 0.0), 1.0)
    }

    /// Inward QRTL / gravity-like influence ∝ α_Q × density / r²
    func influence(at position: SIMD3<Float>) -> SIMD3<Float> {
        let radius = simd_length(position)
        guard radius > 0.000001 else { return .zero }

        let inwardDirection = -position / radius
        let density = normalizedDensity(at: position)
        let distanceFalloff = 1.0 / max(radius * radius, 0.01)
        let strength = Float(parameters.alphaQ) * density * distanceFalloff
        return inwardDirection * strength
    }

    /// Radial EM-like influence; stronger in dense core (upper rays bend out, lower rays bend out)
    func electromagneticInfluence(at position: SIMD3<Float>) -> SIMD3<Float> {
        let radius = simd_length(position)
        guard radius.isFinite, radius > 0.000001 else { return .zero }

        let radialDirection = position / radius
        let density = normalizedDensity(at: position)
        guard density.isFinite, density > 0.0 else { return .zero }

        let sampleDistance = max(radius * 0.01, 0.001)
        let inwardPosition = position - radialDirection * sampleDistance
        let inwardDensity = normalizedDensity(at: inwardPosition)
        let densityGradient = (density - inwardDensity) / Float(sampleDistance)

        let qrtlMagnitude = simd_length(influence(at: position))
        let electromagneticCoupling = Float(parameters.electromagneticCoupling)
        let photonEMCoupling = Float(parameters.photonEMCoupling)

        let densityTerm = density
        let gradientTerm = max(densityGradient, 0.0)

        let fieldStrength =
            (densityTerm + gradientTerm) *
            (1.0 + qrtlMagnitude) *
            electromagneticCoupling *
            photonEMCoupling

        guard fieldStrength.isFinite, fieldStrength > 0.0 else { return .zero }

        let field = radialDirection * fieldStrength
        guard field.x.isFinite, field.y.isFinite, field.z.isFinite else { return .zero }
        return field
    }
}
