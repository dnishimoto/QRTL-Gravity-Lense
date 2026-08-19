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
    // Gravitational QRTL → photon coupling
    var qrtlFieldCoupling: Double = 1.0
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

