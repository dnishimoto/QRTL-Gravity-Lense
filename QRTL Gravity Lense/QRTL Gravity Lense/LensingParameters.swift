
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

    var photonStepSize: Float {
        get { stepSize }
        set { stepSize = max(newValue, 0.00001) }
    }

    var maximumPhotonSteps: Int {
        get { maxSteps }
        set { maxSteps = max(newValue, 1) }
    }

    // ========================================================
    // PHOTON LENSING  (stronger defaults for clear two-image split)
    // ========================================================

    /// Overall QRTL optical-index / acceleration bending multiplier.
    var qrtlLensingStrength: Float = 0.40

    /// Maximum local angular change per integration step.
    var maximumPhotonBend: Float = 0.12

    /// Older controller name.
    var deflectionStrength: Float {
        get { qrtlLensingStrength }
        set { qrtlLensingStrength = max(newValue, 0.0) }
    }

    // ========================================================
    // QRTL FIELD COUPLING
    // ========================================================

    /// Coupling between the QRTL field and photon lensing.
    var qrtlFieldCoupling: Float = 8.0

    /// Electromagnetic field coupling.
    var electromagneticCoupling: Float = 5.0

    // ========================================================
    // MAGNETIC PHOTON COUPLING
    // ========================================================

    var magneticPhotonCoupling: Float = 1.0
    var magneticBendingStrength: Float = 1.0

    // ========================================================
    // PROJECTION PLANE  (wider so fewer hits are clipped)
    // ========================================================

    var projectionX: Float = 10.0

    /// Half-width of the projection plane in Y/Z.
    var projectionPlaneHalfExtent: Float = 18.0

    var projectionDistance: Float {
        get { projectionX }
        set { projectionX = newValue }
    }

    // ========================================================
    // MAXIMUM PROPAGATION RADIUS
    // ========================================================

    var maximumPropagationRadius: Float = 60.0

    // ========================================================
    // OPTIONAL INTERACTION PARAMETERS
    // ========================================================

    var interactionRate: Float = 0.0
    var currentCoupling: Float = 1.0
    var qrtlPhotonCoupling: Float = 0.25

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init(
        currentCoupling: Float = 1.0,
        maxRadius: Float = 60.0,
        stepSize: Float = 0.04,
        maxSteps: Int = 1500,
        qrtlLensingStrength: Float = 0.40,
        maximumPhotonBend: Float = 0.12,
        qrtlFieldCoupling: Float = 8.0,
        electromagneticCoupling: Float = 5.0,
        magneticPhotonCoupling: Float = 1.0,
        magneticBendingStrength: Float = 1.0,
        projectionX: Float = 10.0,
        projectionPlaneHalfExtent: Float = 18.0,
        maximumPropagationRadius: Float = 60.0,
        interactionRate: Float = 0.0,
        qrtlPhotonCoupling: Float = 0.25
    ) {
        self.currentCoupling = max(currentCoupling, 0.0)
        self.maxRadius = max(maxRadius, 0.001)
        self.stepSize = max(stepSize, 0.00001)
        self.maxSteps = max(maxSteps, 1)
        self.qrtlLensingStrength = max(qrtlLensingStrength, 0.0)
        self.maximumPhotonBend = max(maximumPhotonBend, 0.0)
        self.qrtlFieldCoupling = max(qrtlFieldCoupling, 0.0)
        self.electromagneticCoupling = max(electromagneticCoupling, 0.0)
        self.magneticPhotonCoupling = max(magneticPhotonCoupling, 0.0)
        self.magneticBendingStrength = max(magneticBendingStrength, 0.0)
        self.projectionX = projectionX
        self.projectionPlaneHalfExtent = max(projectionPlaneHalfExtent, 0.001)
        self.maximumPropagationRadius = max(maximumPropagationRadius, 0.001)
        self.interactionRate = max(interactionRate, 0.0)
        self.qrtlPhotonCoupling = max(qrtlPhotonCoupling, 0.0)
    }
}
