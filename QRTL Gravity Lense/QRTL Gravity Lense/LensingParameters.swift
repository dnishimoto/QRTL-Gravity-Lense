//
//  LensingParameters.swift
//  QRTL Gravity Lense
//
//  Canonical parameters for QRTL photon propagation,
//  gravitational lensing, electromagnetic refraction,
//  continuous photon emission, and projection-plane geometry.
//

import Foundation


//
//  LensingParameters.swift
//  QRTL Gravity Lense
//
//  Unified photon-lensing parameters.
//  Provides both the current descriptive names and the legacy
//  PhotonTracer compatibility names.
//

import Foundation

struct LensingParameters {
    
    // ============================================================
        // PHOTON INTEGRATION
        // ============================================================

        /// Maximum number of integration steps allowed for one photon.
        let maximumPhotonSteps: Int

        /// Scene-space integration step used by the photon tracer.
        let stepSize: Float

        // ============================================================
        // PHOTON TERMINATION
        // ============================================================

        /// Maximum scene-space radius allowed during tracing.
        let maxRadius: Float

        /// Distance from the lens to the projection/observer plane.
        let projectionDistance: Float

        // ============================================================
        // LENSING / CURVATURE
        // ============================================================

        let deflectionStrength: Float

    // ============================================================
    // MARK: - PHOTON PROPAGATION
    // ============================================================

    /// Legacy PhotonTracer name.
    let maxSteps: Int


    /// Current descriptive name.
    let photonStepSize: Float

    /// Current descriptive name.
    let maximumPropagationRadius: Float

    /// Continuous photon emission rate.
    let photonEmissionRate: Float

    /// Maximum number of photons ContentView may trace.
    let maximumPhotonCount: Int

    // ============================================================
    // MARK: - GRAVITATIONAL DEFLECTION
    // ============================================================

    let targetPlaneZ: Float

    /// QRTL-specific lensing multiplier.
    var qrtlLensingStrength: Float

    /// Maximum allowed QRTL bending contribution.
    var maximumPhotonBend: Float

    // ============================================================
    // MARK: - PROJECTION PLANE
    // ============================================================

    /// Legacy PhotonTracer projection-plane X coordinate.
    let projectionX: Float

    /// Current descriptive projection-plane X coordinate.
    let targetPlaneX: Float

    /// Half-width / half-height of the projection plane.
    let projectionPlaneHalfExtent: Float

    // ============================================================
    // MARK: - QRTL FIELD COUPLING
    // ============================================================

    /// Coupling between QRTL field and photon propagation.
    var qrtlFieldCoupling: Float

    /// Additional QRTL photon coupling.
    var qrtlPhotonCoupling: Float

    // ============================================================
    // MARK: - ELECTROMAGNETIC COUPLING
    // ============================================================

    /// Electromagnetic field coupling.
    var electromagneticCoupling: Float

    /// Direct magnetic influence on photon propagation.
    var magneticPhotonCoupling: Float

    /// Magnetic bending multiplier.
    var magneticBendingStrength: Float

    /// Current-to-photon coupling.
    var currentCoupling: Float

    // ============================================================
    // MARK: - OPTIONAL INTERACTION
    // ============================================================

    var interactionRate: Float

    // ============================================================
    // MARK: - INITIALIZATION
    // ============================================================

    init(
        targetPlaneZ: Float = 20.0,
        maximumPhotonSteps: Int = 100,
           stepSize: Float = 0.1,
           maxRadius: Float = 20.0,
           projectionDistance: Float = 20.0,
           deflectionStrength: Float = 1.0,
        
        maxSteps: Int = 100,

        projectionX: Float = 10.0,
        projectionPlaneHalfExtent: Float = 10.0,

        maximumPhotonCount: Int = 1000,

        maximumPropagationRadius: Float = 20.0,
        photonStepSize: Float = 0.20,
        photonEmissionRate: Float = 60.0,
  
        qrtlLensingStrength: Float = 1.0,
        maximumPhotonBend: Float = 0.35,

        qrtlFieldCoupling: Float = 1.0,
        qrtlPhotonCoupling: Float = 0.25,

        electromagneticCoupling: Float = 0.0,
        magneticPhotonCoupling: Float = 0.0,
        magneticBendingStrength: Float = 0.0,
        currentCoupling: Float = 0.0,

        targetPlaneX: Float? = nil,

        interactionRate: Float = 0.0
    ) {

        // ========================================================
        // PHOTON PROPAGATION
        // ========================================================

        self.targetPlaneZ = targetPlaneZ

        
        let safeMaxSteps = max(
            1,
            maxSteps
        )

        let safeStepSize =
            stepSize.isFinite && stepSize > 0.0
            ? stepSize
            : 0.01

        let safeMaxRadius =
            maxRadius.isFinite && maxRadius > 0.0
            ? maxRadius
            : 20.0

        self.maxSteps = safeMaxSteps
        self.stepSize = safeStepSize
        self.maxRadius = safeMaxRadius

        // ========================================================
        // CURRENT / DESCRIPTIVE PHOTON VALUES
        // ========================================================

        self.maximumPhotonSteps = max(
            1,
            maximumPhotonSteps
        )

        self.photonStepSize =
            photonStepSize.isFinite && photonStepSize > 0.0
            ? photonStepSize
            : 0.20

        self.maximumPropagationRadius =
            maximumPropagationRadius.isFinite &&
            maximumPropagationRadius > 0.0
            ? maximumPropagationRadius
            : 20.0

        self.photonEmissionRate = max(
            photonEmissionRate.isFinite
            ? photonEmissionRate
            : 0.0,
            0.0
        )

        self.maximumPhotonCount = max(
            1,
            maximumPhotonCount
        )

        // ========================================================
        // GRAVITATIONAL DEFLECTION
        // ========================================================

        self.deflectionStrength =
            deflectionStrength.isFinite
            ? deflectionStrength
            : 1.0

        self.qrtlLensingStrength = max(
            qrtlLensingStrength.isFinite
            ? qrtlLensingStrength
            : 0.0,
            0.0
        )

        self.maximumPhotonBend = max(
            maximumPhotonBend.isFinite
            ? maximumPhotonBend
            : 0.0,
            0.0
        )

        // ========================================================
        // PROJECTION PLANE
        // ========================================================

        let safeProjectionX =
            projectionX.isFinite
            ? projectionX
            : 10.0

        let resolvedTargetPlaneX =
            targetPlaneX ??
            safeProjectionX

        let safeTargetPlaneX =
            resolvedTargetPlaneX.isFinite
            ? resolvedTargetPlaneX
            : safeProjectionX

        self.projectionX = safeProjectionX
        self.targetPlaneX = safeTargetPlaneX

        self.projectionPlaneHalfExtent =
            projectionPlaneHalfExtent.isFinite &&
            projectionPlaneHalfExtent > 0.0
            ? projectionPlaneHalfExtent
            : 10.0

        // ========================================================
        // QRTL FIELD COUPLING
        // ========================================================

        self.qrtlFieldCoupling = max(
            qrtlFieldCoupling.isFinite
            ? qrtlFieldCoupling
            : 0.0,
            0.0
        )

        self.qrtlPhotonCoupling = max(
            qrtlPhotonCoupling.isFinite
            ? qrtlPhotonCoupling
            : 0.0,
            0.0
        )

        // ========================================================
        // ELECTROMAGNETIC COUPLING
        // ========================================================

        self.electromagneticCoupling = max(
            electromagneticCoupling.isFinite
            ? electromagneticCoupling
            : 0.0,
            0.0
        )

        self.magneticPhotonCoupling = max(
            magneticPhotonCoupling.isFinite
            ? magneticPhotonCoupling
            : 0.0,
            0.0
        )

        self.magneticBendingStrength = max(
            magneticBendingStrength.isFinite
            ? magneticBendingStrength
            : 0.0,
            0.0
        )

        self.currentCoupling = max(
            currentCoupling.isFinite
            ? currentCoupling
            : 0.0,
            0.0
        )

        // ========================================================
        // OPTIONAL INTERACTION
        // ========================================================

        self.interactionRate = max(
            interactionRate.isFinite
            ? interactionRate
            : 0.0,
            0.0
        )
        


              self.projectionDistance = projectionDistance

    }
}

