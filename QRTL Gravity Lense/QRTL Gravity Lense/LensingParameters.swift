
//
//  Canonical parameters for QRTL photon propagation,
//  gravitational lensing, electromagnetic refraction,
//  and projection-plane geometry.
//

import Foundation

// ============================================================
// LENSING PARAMETERS
// ============================================================
//
// Single authoritative parameter model used by:
//
//     QRTLPhotonTracer
//     ContentView
//     QRTLExperiment
//     LensingSceneController
//
// ============================================================

struct LensingParameters {
    // ============================================================
       // PHOTON PROPAGATION
       // ============================================================

       /// Photon integration step in meters.
       let photonStepSize: Float

       /// Maximum photon propagation distance in meters.
       let maximumPropagationRadius: Float

       // ============================================================
       // PROJECTION PLANE
       // ============================================================

       /// Projection plane X coordinate in meters.
       let targetPlaneX: Float

       /// Physical half-width of projection plane in meters.
       let projectionPlaneHalfExtent: Float

       // ============================================================
       // LENSING
       // ============================================================

       let maximumPhotonSteps: Int

       let deflectionStrength: Float
  
 
    /// QRTL-specific lensing multiplier.
    var qrtlLensingStrength: Float = 1.0

    /// Maximum QRTL bending contribution per integration step.
    var maximumPhotonBend: Float = 0.35

    // ========================================================
    // QRTL FIELD COUPLING
    // ========================================================

    /// Coupling between the QRTL field and photon propagation.
    var qrtlFieldCoupling: Float = 1.0

    /// Additional QRTL photon coupling.
    var qrtlPhotonCoupling: Float = 0.25

    // ========================================================
    // ELECTROMAGNETIC COUPLING
    // ========================================================

    /// Electromagnetic field coupling.
    var electromagneticCoupling: Float = 0.0

    /// Direct magnetic influence on photon propagation.
    var magneticPhotonCoupling: Float = 0.0

    /// Magnetic bending multiplier.
    var magneticBendingStrength: Float = 0.0

    /// Current-to-photon coupling.
    var currentCoupling: Float = 0.0

    // ========================================================
    // OPTIONAL INTERACTION
    // ========================================================

    var interactionRate: Float = 0.0

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init(
        maximumPropagationRadius: Float = 20.0,
        photonStepSize: Float = 0.20,
        maximumPhotonSteps: Int = 100,
        deflectionStrength: Float = 1.0,
        qrtlLensingStrength: Float = 1.0,
        maximumPhotonBend: Float = 0.35,
        qrtlFieldCoupling: Float = 1.0,
        qrtlPhotonCoupling: Float = 0.25,
        electromagneticCoupling: Float = 0.0,
        magneticPhotonCoupling: Float = 0.0,
        magneticBendingStrength: Float = 0.0,
        currentCoupling: Float = 0.0,
        targetPlaneX: Float = 10.0,
        projectionPlaneHalfExtent: Float = 18.0,
        interactionRate: Float = 0.0
    ) {

        self.maximumPropagationRadius =
            max(
                maximumPropagationRadius,
                0.001
            )

        self.photonStepSize =
            max(
                photonStepSize,
                0.00001
            )

        self.maximumPhotonSteps =
            max(
                maximumPhotonSteps,
                1
            )

        self.deflectionStrength =
            max(
                deflectionStrength,
                0.0
            )

        self.qrtlLensingStrength =
            max(
                qrtlLensingStrength,
                0.0
            )

        self.maximumPhotonBend =
            max(
                maximumPhotonBend,
                0.0
            )

        self.qrtlFieldCoupling =
            max(
                qrtlFieldCoupling,
                0.0
            )

        self.qrtlPhotonCoupling =
            max(
                qrtlPhotonCoupling,
                0.0
            )

        self.electromagneticCoupling =
            max(
                electromagneticCoupling,
                0.0
            )

        self.magneticPhotonCoupling =
            max(
                magneticPhotonCoupling,
                0.0
            )

        self.magneticBendingStrength =
            max(
                magneticBendingStrength,
                0.0
            )

        self.currentCoupling =
            max(
                currentCoupling,
                0.0
            )

        self.targetPlaneX =
            targetPlaneX

        self.projectionPlaneHalfExtent =
            max(
                projectionPlaneHalfExtent,
                0.001
            )

        self.interactionRate =
            max(
                interactionRate,
                0.0
            )
    }
}
