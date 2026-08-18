
import Foundation

// ============================================================
// LENSING PARAMETERS
//
// Unified parameter set used by:
//
// • QRTLField
// • tracePhoton()
// • ContentView
// • LensingSceneController
//
// Includes compatibility names used by the older scene
// controller so the entire project can use one parameter type.
// ============================================================

struct LensingParameters {
    var qrtlPhotonCoupling: Float = 0.25
    var currentCoupling: Float = 1.0
    // ========================================================
    // PHOTON INTEGRATION
    // ========================================================
    var maxRadius: Float = 60.0
    /// Photon integration step in scene units.
    var stepSize: Float = 0.04

    /// Maximum number of integration steps.
    var maxSteps: Int = 1500

    // --------------------------------------------------------
    // BACKWARD-COMPATIBILITY ALIASES
    // --------------------------------------------------------

    /// Older name used by LensingSceneController.
    var photonStepSize: Float {
        get {
            stepSize
        }
        set {
            stepSize = max(newValue, 0.00001)
        }
    }

    /// Older name used by LensingSceneController.
    var maximumPhotonSteps: Int {
        get {
            maxSteps
        }
        set {
            maxSteps = max(newValue, 1)
        }
    }

    // ========================================================
    // PHOTON LENSING
    // ========================================================

    /// Overall QRTL optical-index bending multiplier.
    var qrtlLensingStrength: Float = 0.2

    /// Maximum local angular change per integration step.
    var maximumPhotonBend: Float = 0.05

    /// Older controller name.
    var deflectionStrength: Float {
        get {
            qrtlLensingStrength
        }
        set {
            qrtlLensingStrength = max(newValue, 0.0)
        }
    }

    // ========================================================
    // QRTL FIELD COUPLING
    // ========================================================

    /// Coupling between the QRTL field and photon lensing.
    var qrtlFieldCoupling: Float = 5.0

    /// Electromagnetic field coupling.
    var electromagneticCoupling: Float = 5.0

    // ========================================================
    // MAGNETIC PHOTON COUPLING
    // ========================================================

    /// Strength of direct magnetic contribution to photon
    /// bending diagnostics.
    var magneticPhotonCoupling: Float = 1.0

    /// Scaling applied to magnetic bending.
    var magneticBendingStrength: Float = 1.0

    // ========================================================
    // PROJECTION PLANE
    // ========================================================

    /// X coordinate of the observation/projection plane.
    var projectionX: Float = 8.0

    /// Half-width of the projection plane in Y/Z.
    var projectionPlaneHalfExtent: Float = 6.0

    /// Older name used by LensingSceneController.
    var projectionDistance: Float {
        get {
            projectionX
        }
        set {
            projectionX = newValue
        }
    }

    // ========================================================
    // MAXIMUM PROPAGATION RADIUS
    // ========================================================

    /// Maximum radial distance a photon is allowed to travel
    /// from the origin before the trace is terminated.
    var maximumPropagationRadius: Float = 20.0

    // ========================================================
    // OPTIONAL INTERACTION PARAMETERS
    // ========================================================

    var interactionRate: Float = 0.0

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init(
        currentCoupling: Float = 1.0,
        maxRadius: Float = 60.0,
        stepSize: Float = 0.04,
        maxSteps: Int = 1500,
        qrtlLensingStrength: Float = 0.2,
        maximumPhotonBend: Float = 0.05,
        qrtlFieldCoupling: Float = 5.0,
        electromagneticCoupling: Float = 5.0,
        magneticPhotonCoupling: Float = 1.0,
        magneticBendingStrength: Float = 1.0,
        projectionX: Float = 8.0,
        projectionPlaneHalfExtent: Float = 6.0,
        maximumPropagationRadius: Float = 20.0,
        interactionRate: Float = 0.0
    ) {

        self.stepSize =
            max(
                stepSize,
                0.00001
            )

        self.maxSteps =
            max(
                maxSteps,
                1
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

        self.projectionX =
            projectionX

        self.projectionPlaneHalfExtent =
            max(
                projectionPlaneHalfExtent,
                0.001
            )

        self.maximumPropagationRadius =
            max(
                maximumPropagationRadius,
                0.001
            )

        self.interactionRate =
            max(
                interactionRate,
                0.0
            )
    }
}
