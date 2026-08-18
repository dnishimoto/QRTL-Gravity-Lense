/*
The current code is predicting this, in simplified ASCII:
QRTL LENSING PREDICTION
=======================

     BARYONIC MASS
          |
          v
 +----------------+
 | Mass density   |
 |     rho_B      |
 +----------------+
          |
          v
 QRTL SOURCE TERM
   S_Q = alpha*rho
          |
          v
BOLGARINO / QRTL
   RADIAL FLUX
       J_Q
          |
+---------+---------+
|                   |
v                   v
QRTL ENERGY          EFFECTIVE EM
u_Q                  CURRENT
|                   |
v                   v
GRAVITATIONAL        EM ENERGY
SOURCE             u_EM,Q
|                   |
v                   v
rho_effective          n_EM
|                   |
v                   |
QRTL POTENTIAL Phi_Q     |
|                   |
v                   |
n_G                  |
|                   |
+---------+---------+
          |
          v
     TOTAL INDEX
     n_total
   = n_G * n_EM
          |
          v
   PHOTON ENTERS
     QRTL FIELD
          |
          v
+----------------------+
| At every step:       |
|                      |
| calculate grad(n)    |
| calculate transverse |
| component            |
| change photon angle  |
+----------------------+
          |
          v
 CURVED PHOTON PATH
          |
          v
 MEASURE DEFLECTION
          |
+---------+---------+
|                   |
v                   v
QRTL alpha          GR alpha
|                   |
+---------+---------+
          |
          v
 COMPARE THE TWO
The actual prediction is therefore not simply "gravity bends light."
It is:
Mass
|
+--> QRTL source
|
+--> QRTL current
|
+--> gravitational contribution
|
+--> electromagnetic contribution
          |
          v
   photon trajectory
          |
          v
   predicted alpha_QRTL
Then the code asks:
DOES

alpha_QRTL
|
v
---------------------
|                   |
v                   v
alpha_GR          observations
|                   |
+---------+---------+
|
v
AGREEMENT?
What would make this a genuine QRTL prediction?
The critical point is that the current code still has some unanswered links:
QRTL THEORY
|
v
Bolgarino production
|
v
J_Q
|
|   <-- QRTL must derive this relationship
v
u_Q
|
|   <-- QRTL must derive this relationship
v
gravity
and:
J_Q
|
v
EM field
|
|   <-- QRTL must derive this coupling
v
photon propagation
So the architecture is now capable of making a QRTL prediction, but the numerical prediction isn't yet uniquely determined by QRTL because those missing relationships still contain parameters such as alphaQ, etaQ, chiQ, electromagneticCoupling, and photonEMCoupling.
The next step would be to eliminate those arbitrary bridges by deriving them from the QRTL assumptions. Then the ASCII pipeline becomes a genuine QRTL prediction pipeline rather than a QRTL-inspired computational model.


Below is a corrected, self-contained Swift implementation. It makes the GR baseline explicit through the weak-field effective index

  n_G = 1 - (1+gamma_Q) * Phi_Q / c^2,

which reduces to n_G = 1 - 2*Phi/c^2 when gamma_Q = 1. That is the weak-field GR refractive-index form and yields the standard 4GM/(bc^2)
point-mass deflection in the appropriate limit.

The QRTL additions remain clearly isolated as an effective model: QRTL flux -> QRTL energy density -> gravitational source, plus an optional
QRTL-induced EM-energy phase term. The code also removes the arbitrary magnetic-field direction, uses `electromagneticCoupling`, uses `gammaQ`,
and replaces the incorrect negative EM gradient sign with a single total-index ray equation.

NEW IN THIS REVISION: photon paths from the source galaxy to the destination observation plane are now rendered as smooth Catmull-Rom
spline curves (built as chains of oriented cylinders / tubes) instead of raw straight-segment polylines. See CatmullRomSpline and
LensingSceneController.addSplinePhotonPath, and the updated runProjectionPipeline.
*/
import SwiftUI
import SceneKit
import simd
import Combine
import UIKit

// ============================================================
// PHYSICAL CONSTANTS
// ============================================================

enum PhysicalConstants {

    static let G = 6.67430e-11

    static let c = 299_792_458.0

    static let epsilon0 = 8.8541878128e-12

    static let mu0 = 1.25663706212e-6

    static let solarMass = 1.98847e30

    static let solarRadius = 6.957e8

    static let radiansToArcseconds =
        206_264.80624709636
}

// ============================================================
// NUMERICAL UTILITIES
// ============================================================

@inline(__always)
func clamped(
    _ value: Double,
    minimum: Double,
    maximum: Double
) -> Double {

    min(
        max(value, minimum),
        maximum
    )
}

@inline(__always)
func transverseComponent(
    _ vector: SIMD3<Double>,
    relativeTo direction: SIMD3<Double>
) -> SIMD3<Double> {

    vector -
    direction *
    simd_dot(vector, direction)
}

// ============================================================
// CATMULL-ROM SPLINE
// ============================================================

enum CatmullRomSpline {

    static func interpolate(
        points: [SIMD3<Double>],
        pointsPerSegment: Int = 8
    ) -> [SIMD3<Double>] {

        guard points.count >= 2 else {
            return points
        }

        let segments =
            max(
                pointsPerSegment,
                1
            )

        if points.count == 2 {

            let p0 = points[0]
            let p1 = points[1]

            var result:
                [SIMD3<Double>] = []

            result.reserveCapacity(
                segments + 1
            )

            for step in 0...segments {

                let t =
                    Double(step) /
                    Double(segments)

                result.append(
                    p0 +
                    (p1 - p0) * t
                )
            }

            return result
        }

        var extended =
            points

        extended.insert(
            points[0] +
            (points[0] - points[1]),
            at: 0
        )

        extended.append(
            points[points.count - 1] +
            (
                points[points.count - 1] -
                points[points.count - 2]
            )
        )

        var result:
            [SIMD3<Double>] = []

        let segmentCount =
            extended.count - 3

        for i in 0..<segmentCount {

            let p0 = extended[i]
            let p1 = extended[i + 1]
            let p2 = extended[i + 2]
            let p3 = extended[i + 3]

            let startStep =
                i == 0 ? 0 : 1

            for step in startStep...segments {

                let t =
                    Double(step) /
                    Double(segments)

                let t2 =
                    t * t

                let t3 =
                    t2 * t

                let a =
                    -0.5 * t3 +
                    t2 -
                    0.5 * t

                let b =
                    1.5 * t3 -
                    2.5 * t2 +
                    1.0

                let c =
                    -1.5 * t3 +
                    2.0 * t2 +
                    0.5 * t

                let d =
                    0.5 * t3 -
                    0.5 * t2

                let point =
                    p0 * a +
                    p1 * b +
                    p2 * c +
                    p3 * d

                result.append(point)
            }
        }

        return result
    }
}

// ============================================================
// QRTL PARAMETERS
// ============================================================

struct QRTLParameters {

    // QRTL source strength.
    var alphaQ: Double = 0.0

    // Bolgarino / QRTL propagation velocity.
    var qrtlVelocity:
        Double =
        PhysicalConstants.c

    // Radial attenuation rate.
    var interactionRate: Double = 0.0

    // Converts QRTL current into QRTL energy density.
    var chiQ: Double = 1.0

    // Converts QRTL energy density into effective gravitating density.
    var etaQ: Double = 0.0

    // Post-Newtonian PPN-style gamma parameter.
    //
    // gammaQ = 1 gives:
    //
    // n_G = 1 - 2 Phi / c²
    //
    // for the weak-field GR limit.
    var gammaQ: Double = 1.0

    // QRTL current -> effective EM current coupling.
    var electromagneticCoupling:
        Double = 0.0

    // Electric-field scaling.
    var electricFieldCoupling:
        Double = 1.0

    // Magnetic-field scaling.
    var magneticFieldCoupling:
        Double = 1.0

    // EM field -> photon-index coupling.
    var photonEMCoupling:
        Double = 0.0

    var epsilon:
        Double = 1.0e-12

    // Numerical lower bound.
    var minimumStepSolarRadii:
        Double = 0.05

    // Safety limit for rays.
    var maximumRaySteps:
        Int = 800
}

// ============================================================
// MASS MODEL
// ============================================================

struct GaussianMassModel {

    // =========================================================
    // TOTAL MASS
    // =========================================================

    let totalMass:
        Double


    // =========================================================
    // CHARACTERISTIC RADIUS
    //
    // Controls the spatial size of the Gaussian mass
    // distribution.
    // =========================================================

    let characteristicRadius:
        Double


    // =========================================================
    // INITIALIZER
    // =========================================================

    init(
        totalMass:
            Double,

        characteristicRadius:
            Double
    ) {

        self.totalMass =
            totalMass

        self.characteristicRadius =
            max(
                characteristicRadius,
                0.000001
            )
    }


    // =========================================================
    // MASS DENSITY
    //
    // 3D Gaussian distribution:
    //
    //     rho(r) =
    //     M / ((2π)^(3/2) σ³)
    //     × exp(-r² / (2σ²))
    //
    // The integral over all space is approximately TOTAL MASS.
    // =========================================================

    func density(
        at position:
            SIMD3<Double>
    ) -> Double {

        let sigma =
            characteristicRadius


        // -----------------------------------------------------
        // Distance from lens center.
        // -----------------------------------------------------

        let radiusSquared =
            position.x * position.x +
            position.y * position.y +
            position.z * position.z


        // -----------------------------------------------------
        // Gaussian normalization.
        // -----------------------------------------------------

        let normalization =
            totalMass /
            (
                pow(
                    2.0 * Double.pi,
                    1.5
                ) *
                pow(
                    sigma,
                    3.0
                )
            )


        // -----------------------------------------------------
        // Gaussian falloff.
        // -----------------------------------------------------

        let exponent =
            -radiusSquared /
            (
                2.0 *
                sigma *
                sigma
            )


        return
            normalization *
            exp(exponent)
    }


    // =========================================================
    // NORMALIZED DENSITY
    //
    // Returns density relative to the center.
    //
    // Center = 1
    // Far away → 0
    // =========================================================

    func normalizedDensity(
        at position:
            SIMD3<Double>
    ) -> Double {

        let sigma =
            characteristicRadius


        let radiusSquared =
            position.x * position.x +
            position.y * position.y +
            position.z * position.z


        let exponent =
            -radiusSquared /
            (
                2.0 *
                sigma *
                sigma
            )


        return
            exp(exponent)
    }
}

final class QRTLField {

    // =========================================================
    // MASS MODEL
    // =========================================================

    let massModel:
        GaussianMassModel


    // =========================================================
    // QRTL PARAMETERS
    // =========================================================

    let parameters:
        QRTLParameters


    // =========================================================
    // REFERENCE DENSITY
    //
    // Density at the center of the lens.
    // Used to normalize the local cluster density.
    // =========================================================

    let referenceDensity:
        Float


    // =========================================================
    // INITIALIZER
    // =========================================================

    init(
        massModel:
            GaussianMassModel,

        parameters:
            QRTLParameters
    ) {

        self.massModel =
            massModel

        self.parameters =
            parameters


        // -----------------------------------------------------
        // Calculate central reference density.
        // -----------------------------------------------------

        let centerDensity =
            massModel.density(
                at:
                    SIMD3<Double>(
                        0.0,
                        0.0,
                        0.0
                    )
            )


        self.referenceDensity =
            max(
                Float(centerDensity),
                0.000001
            )
    }


    // =========================================================
    // MASS DENSITY
    //
    // Returns the local mass density at the photon position.
    //
    // This is sampled at EVERY photon integration step.
    // =========================================================

    func massDensity(
        at position:
            SIMD3<Float>
    ) -> Float {

        let p =
            SIMD3<Double>(
                Double(position.x),
                Double(position.y),
                Double(position.z)
            )

        return Float(
            massModel.density(
                at:
                    p
            )
        )
    }


    // =========================================================
    // NORMALIZED DENSITY
    //
    // 0.0 = negligible density
    // 1.0 = maximum/reference density
    // =========================================================

    func normalizedDensity(
        at position:
            SIMD3<Float>
    ) -> Float {

        let density =
            massDensity(
                at:
                    position
            )

        return min(
            max(
                density /
                referenceDensity,
                0.0
            ),
            1.0
        )
    }


    // =========================================================
    // QRTL / GRAVITY INFLUENCE
    //
    // The photon is pulled toward the lens center.
    //
    // Density controls how strongly the local mass
    // distribution contributes.
    // =========================================================

    func influence(
        at position:
            SIMD3<Float>
    ) -> SIMD3<Float> {

        let radius =
            simd_length(
                position
            )


        guard radius >
            0.000001
        else {

            return
                SIMD3<Float>.zero
        }


        // -----------------------------------------------------
        // Direction toward lens center.
        // -----------------------------------------------------

        let inwardDirection =
            -position /
            radius


        // -----------------------------------------------------
        // Local cluster density.
        // -----------------------------------------------------

        let density =
            normalizedDensity(
                at:
                    position
            )


        // -----------------------------------------------------
        // Distance falloff.
        // -----------------------------------------------------

        let distanceFalloff =
            1.0 /
            max(
                radius * radius,
                0.01
            )


        // -----------------------------------------------------
        // QRTL field strength.
        // -----------------------------------------------------

        let strength =
            Float(
                parameters.alphaQ
            ) *
            density *
            distanceFalloff


        return
            inwardDirection *
            strength
    }


    // =========================================================
    // ELECTROMAGNETIC INFLUENCE
    //
    // The electromagnetic field changes continuously with
    // the density of the globular cluster.
    //
    // The photon therefore experiences:
    //
    //     low density  -> weak distortion
    //     high density -> strong distortion
    //     low density  -> weak distortion
    //
    // as it passes through the cluster.
    // =========================================================

    // =============================================================
    // ELECTROMAGNETIC PHOTON INFLUENCE
    //
    // The EM field is centered on the globular cluster.
    //
    // Its magnitude follows the local QRTL / mass density.
    // Its direction is radial from the cluster center.
    //
    // Therefore:
    //
    //        upper photon → bends upward
    //
    //              ↑
    //              │
    //              ●  cluster
    //              │
    //              ↓
    //
    //        lower photon → bends downward
    //
    // This produces the two-sided lensing geometry.
    // =============================================================

    func electromagneticInfluence(
        at position:
            SIMD3<Float>
    ) -> SIMD3<Float> {

        // =========================================================
        // DISTANCE FROM CLUSTER CENTER
        // =========================================================

        let radius =
            simd_length(position)

        guard radius.isFinite,
              radius > 0.000001
        else {
            return .zero
        }


        // =========================================================
        // RADIAL DIRECTION
        // =========================================================

        let radialDirection =
            position / radius


        // =========================================================
        // LOCAL DENSITY
        // =========================================================

        let density =
            normalizedDensity(
                at: position
            )

        guard density.isFinite,
              density > 0.0
        else {
            return .zero
        }


        // =========================================================
        // SAMPLE DENSITY A LITTLE CLOSER TO THE CENTER
        //
        // This gives us the local density gradient.
        // =========================================================

        let sampleDistance =
            max(
                radius * 0.01,
                0.001
            )


        let inwardPosition =
            position -
            radialDirection *
            sampleDistance


        let inwardDensity =
            normalizedDensity(
                at:
                    inwardPosition
            )


        // =========================================================
        // DENSITY GRADIENT
        //
        // Positive value means density increases toward the center.
        // =========================================================

        let densityGradient =
            (
                density -
                inwardDensity
            ) /
            Float(sampleDistance)


        // =========================================================
        // LOCAL QRTL FIELD
        // =========================================================

        let qrtlVector =
            influence(
                at:
                    position
            )

        let qrtlMagnitude =
            simd_length(
                qrtlVector
            )


        // =========================================================
        // COUPLINGS
        // =========================================================

        let electromagneticCoupling =
            Float(
                parameters.electromagneticCoupling
            )

        let photonEMCoupling =
            Float(
                parameters.photonEMCoupling
            )


        // =========================================================
        // DENSITY-DEPENDENT FIELD STRENGTH
        //
        // The first term makes the field stronger in dense regions.
        //
        // The second term makes the bending respond to the CHANGE
        // in density as the photon moves through the cluster.
        // =========================================================

        let densityTerm =
            density


        let gradientTerm =
            max(
                densityGradient,
                0.0
            )


        let fieldStrength =
            (
                densityTerm +
                gradientTerm
            )
            *
            (
                1.0 +
                qrtlMagnitude
            )
            *
            electromagneticCoupling
            *
            photonEMCoupling


        guard fieldStrength.isFinite,
              fieldStrength > 0.0
        else {
            return .zero
        }


        // =========================================================
        // RADIAL FIELD
        // =========================================================

        let field =
            radialDirection *
            fieldStrength


        guard field.x.isFinite,
              field.y.isFinite,
              field.z.isFinite
        else {
            return .zero
        }


        return field
    }
}

// ============================================================
// EXPERIMENT RESULT
// ============================================================

struct QRTLExperimentResult {

    let qrtlDeflection:
        Double

    let grDeflection:
        Double

    let differencePercent:
        Double

    let qrtlDeflectionArcseconds:
        Double

    let grDeflectionArcseconds:
        Double
}

// ============================================================
// EXPERIMENT
// ============================================================

final class QRTLExperiment {

    let field:
        QRTLField

    let tracer:
        QRTLPhotonTracer

    init(
        mass:
            Double,

        radius:
            Double,

        parameters:
            QRTLParameters
    ) {

        let model =
            GaussianMassModel(
                totalMass:
                    mass,

                characteristicRadius:
                    radius
            )

        self.field =
            QRTLField(
                massModel:
                    model,

                parameters:
                    parameters
            )

        self.tracer =
            QRTLPhotonTracer(
                field:
                    self.field
            )
    }

    func run(
        impactParameter:
            Double,

        startDistance:
            Double,

        endDistance:
            Double,

        stepSize:
            Double
    ) -> QRTLExperimentResult {

        let start =
            SIMD3<Double>(
                -startDistance,
                impactParameter,
                0
            )

        let totalDistance =
            startDistance +
            endDistance

        let path =
            tracer.trace(
                start:
                    start,

                direction:
                    SIMD3<Double>(
                        1,
                        0,
                        0
                    ),

                totalDistance:
                    totalDistance,

                stepSize:
                    stepSize
            )

        guard path.count >= 3 else {

            return QRTLExperimentResult(
                qrtlDeflection:
                    0,

                grDeflection:
                    0,

                differencePercent:
                    0,

                qrtlDeflectionArcseconds:
                    0,

                grDeflectionArcseconds:
                    0
            )
        }

        let incoming =
            simd_normalize(
                path[1] -
                path[0]
            )

        let outgoing =
            simd_normalize(
                path[path.count - 1] -
                path[path.count - 2]
            )

        let cosine =
            clamped(
                simd_dot(
                    incoming,
                    outgoing
                ),

                minimum:
                    -1,

                maximum:
                    1
            )

        let qrtlAngle =
            acos(
                cosine
            )

        // --------------------------------------------------------
        // Standard weak-field GR point-mass deflection.
        //
        // alpha = 4GM / bc²
        // --------------------------------------------------------

        let grAngle =
            4.0 *
            PhysicalConstants.G *
            field.massModel.totalMass /
            (
                impactParameter *
                PhysicalConstants.c *
                PhysicalConstants.c
            )

        let difference =
            grAngle > 0
            ? 100.0 *
                (
                    qrtlAngle -
                    grAngle
                ) /
                grAngle
            : 0

        return QRTLExperimentResult(

            qrtlDeflection:
                qrtlAngle,

            grDeflection:
                grAngle,

            differencePercent:
                difference,

            qrtlDeflectionArcseconds:
                qrtlAngle *
                PhysicalConstants.radiansToArcseconds,

            grDeflectionArcseconds:
                grAngle *
                PhysicalConstants.radiansToArcseconds
        )
    }
}




// ============================================================
// PROJECTION ACCUMULATOR
// ============================================================

final class ProjectionAccumulator {

    let resolution:
        Int

    let halfExtent:
        Double

    private var buffer:
        [[Float]]

    init(
        resolution:
            Int = 128,

        halfExtent:
            Double
    ) {

        self.resolution =
            resolution

        self.halfExtent =
            halfExtent

        self.buffer =
            [[Float]](
                repeating:
                    [Float](
                        repeating:
                            0,

                        count:
                            resolution
                    ),

                count:
                    resolution
            )
    }

    func reset() {

        for j in 0..<resolution {

            for i in 0..<resolution {

                buffer[j][i] =
                    0
            }
        }
    }

    func addHit(
        y:
            Double,

        z:
            Double,

        weight:
            Float = 1.0
    ) {

        let u =
            (
                y +
                halfExtent
            ) /
            (
                2.0 *
                halfExtent
            )

        let v =
            (
                z +
                halfExtent
            ) /
            (
                2.0 *
                halfExtent
            )

        guard u >= 0,
              u <= 1,
              v >= 0,
              v <= 1
        else {
            return
        }

        let i =
            Int(
                u *
                Double(
                    resolution - 1
                )
            )

        let j =
            Int(
                v *
                Double(
                    resolution - 1
                )
            )

        guard i >= 0,
              i < resolution,
              j >= 0,
              j < resolution
        else {
            return
        }

        buffer[j][i] +=
            weight
    }

    func makeImage() -> UIImage {

        var maxValue:
            Float =
            1.0e-6

        for row in buffer {

            for value in row {

                maxValue =
                    max(
                        maxValue,
                        value
                    )
            }
        }

        UIGraphicsBeginImageContextWithOptions(
            CGSize(
                width:
                    resolution,

                height:
                    resolution
            ),

            false,

            1
        )

        guard let context =
            UIGraphicsGetCurrentContext()
        else {
            return UIImage()
        }

        for j in 0..<resolution {

            for i in 0..<resolution {

                let t =
                    CGFloat(
                        buffer[j][i] /
                        maxValue
                    )

                let alpha =
                    min(
                        1.0,
                        t * 1.8
                    )

                let color =
                    UIColor(
                        red:
                            1,

                        green:
                            0.95,

                        blue:
                            0.7,

                        alpha:
                            alpha
                    )

                context.setFillColor(
                    color.cgColor
                )

                context.fill(
                    CGRect(
                        x:
                            i,

                        y:
                            resolution -
                            1 -
                            j,

                        width:
                            1,

                        height:
                            1
                    )
                )
            }
        }

        let image =
            UIGraphicsGetImageFromCurrentImageContext()
            ?? UIImage()

        UIGraphicsEndImageContext()

        return image
    }
}



struct LensingProjectionResult {

    // =========================================================
    // ALL PROJECTION HITS
    // =========================================================

    /// Every photon that produced a projection-plane hit.
    let hits: [LensingProjectionHit]


    // =========================================================
    // VALID PROJECTION HITS
    // =========================================================

    /// Hits that passed the projection-plane validity checks.
    let validHits: [LensingProjectionHit]


    // =========================================================
    // PROJECTED CENTER
    // =========================================================

    let projectedCenter: SIMD3<Float>


    // =========================================================
    // PROJECTION BOUNDS
    // =========================================================

    let minimum: SIMD3<Float>

    let maximum: SIMD3<Float>


    // =========================================================
    // PROJECTION DIMENSIONS
    // =========================================================

    let width: Float

    let height: Float

    let depth: Float


    // =========================================================
    // VALIDITY
    // =========================================================

    var isValid: Bool {

        !validHits.isEmpty
    }


    // =========================================================
    // INITIALIZER
    // =========================================================

    init(
        hits: [LensingProjectionHit],
        validHits: [LensingProjectionHit],
        projectedCenter: SIMD3<Float>,
        minimum: SIMD3<Float>,
        maximum: SIMD3<Float>,
        width: Float,
        height: Float,
        depth: Float
    ) {

        self.hits =
            hits

        self.validHits =
            validHits

        self.projectedCenter =
            projectedCenter

        self.minimum =
            minimum

        self.maximum =
            maximum

        self.width =
            width

        self.height =
            height

        self.depth =
            depth
    }


    // =========================================================
    // CALCULATE PROJECTION RESULT
    // =========================================================

    static func calculate(
        from hits: [LensingProjectionHit]
    ) -> LensingProjectionResult {

        // -----------------------------------------------------
        // NO HITS
        // -----------------------------------------------------

        guard !hits.isEmpty else {

            let zero =
                SIMD3<Float>(
                    0,
                    0,
                    0
                )

            return LensingProjectionResult(
                hits: [],
                validHits: [],
                projectedCenter: zero,
                minimum: zero,
                maximum: zero,
                width: 0,
                height: 0,
                depth: 0
            )
        }


        // -----------------------------------------------------
        // FILTER FINITE HITS
        // -----------------------------------------------------

        let validHits =
            hits.filter { hit in

                let p =
                    hit.point

                return
                    p.x.isFinite &&
                    p.y.isFinite &&
                    p.z.isFinite
            }


        // -----------------------------------------------------
        // NO VALID HITS
        // -----------------------------------------------------

        guard !validHits.isEmpty else {

            let zero =
                SIMD3<Float>(
                    0,
                    0,
                    0
                )

            return LensingProjectionResult(
                hits: hits,
                validHits: [],
                projectedCenter: zero,
                minimum: zero,
                maximum: zero,
                width: 0,
                height: 0,
                depth: 0
            )
        }


        // -----------------------------------------------------
        // INITIAL BOUNDS
        // -----------------------------------------------------

        var minimum =
            validHits[0].point

        var maximum =
            validHits[0].point


        // -----------------------------------------------------
        // CALCULATE 3D BOUNDS
        // -----------------------------------------------------

        for hit in validHits {

            let point =
                hit.point


            minimum.x =
                min(
                    minimum.x,
                    point.x
                )

            minimum.y =
                min(
                    minimum.y,
                    point.y
                )

            minimum.z =
                min(
                    minimum.z,
                    point.z
                )


            maximum.x =
                max(
                    maximum.x,
                    point.x
                )

            maximum.y =
                max(
                    maximum.y,
                    point.y
                )

            maximum.z =
                max(
                    maximum.z,
                    point.z
                )
        }


        // -----------------------------------------------------
        // DIMENSIONS
        // -----------------------------------------------------

        let width =
            max(
                maximum.x - minimum.x,
                0.0001
            )

        let height =
            max(
                maximum.y - minimum.y,
                0.0001
            )

        let depth =
            max(
                maximum.z - minimum.z,
                0.0001
            )


        // -----------------------------------------------------
        // PROJECTED CENTER
        // -----------------------------------------------------

        let projectedCenter =
            (
                minimum
                + maximum
            )
            * 0.5


        // -----------------------------------------------------
        // RETURN RESULT
        // -----------------------------------------------------

        return LensingProjectionResult(

            hits:
                hits,

            validHits:
                validHits,

            projectedCenter:
                projectedCenter,

            minimum:
                minimum,

            maximum:
                maximum,

            width:
                width,

            height:
                height,

            depth:
                depth
        )
    }
}



struct ControlsSheet:
    View {

    @Binding var massSolar:
        Double

    @Binding var radiusSolar:
        Double

    @Binding var alphaQ:
        Double

    @Binding var etaQ:
        Double

    @Binding var gammaQ:
        Double

    @Binding var electromagneticCoupling:
        Double

    @Binding var photonEMCoupling:
        Double

    @Binding var chiQ:
        Double

    @Binding var interactionRate:
        Double

    @Binding var result:
        QRTLExperimentResult?

    @Binding var isRunning:
        Bool

    @Binding var statusMessage:
        String

    var onRun:
        () -> Void

    var onReset:
        () -> Void

    var body:
        some View {

        NavigationStack {

            Form {

                Section(
                    "Lens Mass"
                ) {

                    HStack {

                        Text(
                            "Mass (M☉)"
                        )

                        Spacer()

                        TextField(
                            "",
                            value:
                                $massSolar,

                            format:
                                .number
                        )
                        .keyboardType(
                            .decimalPad
                        )
                        .multilineTextAlignment(
                            .trailing
                        )
                        .frame(
                            width:
                                120
                        )
                    }

                    HStack {

                        Text(
                            "Radius (R☉)"
                        )

                        Spacer()

                        TextField(
                            "",
                            value:
                                $radiusSolar,

                            format:
                                .number
                        )
                        .keyboardType(
                            .decimalPad
                        )
                        .multilineTextAlignment(
                            .trailing
                        )
                        .frame(
                            width:
                                120
                        )
                    }
                }

                Section(
                    "QRTL / Bolgarino"
                ) {

                    slider(
                        "α_Q",
                        value:
                            $alphaQ,

                        range:
                            0...3e-5
                    )

                    slider(
                        "η_Q",
                        value:
                            $etaQ,

                        range:
                            0...20
                    )

                    slider(
                        "γ_Q",
                        value:
                            $gammaQ,

                        range:
                            0.5...1.5
                    )

                    slider(
                        "χ_Q",
                        value:
                            $chiQ,

                        range:
                            0.1...10
                    )

                    slider(
                        "Γ_Q",
                        value:
                            $interactionRate,

                        range:
                            0...3e-6
                    )
                }

                Section(
                    "EM Coupling"
                ) {

                    slider(
                        "g_QE",
                        value:
                            $electromagneticCoupling,

                        range:
                            0...1e-9
                    )

                    slider(
                        "κ_EM",
                        value:
                            $photonEMCoupling,

                        range:
                            0...1e-19
                    )
                }

                Section {

                    Button(
                        action:
                            onRun
                    ) {

                        Label(
                            isRunning
                            ? "Running…"
                            : "Run Full Projection Pipeline",

                            systemImage:
                                "play.fill"
                        )
                        .frame(
                            maxWidth:
                                .infinity
                        )
                    }
                    .disabled(
                        isRunning
                    )
                    .buttonStyle(
                        .borderedProminent
                    )

                    Button(
                        "Reset to pure GR",
                        action:
                            onReset
                    )
                    .disabled(
                        isRunning
                    )
                }

                if let result {

                    Section(
                        "Deflection"
                    ) {

                        Text(
                            "QRTL: " +
                            String(
                                format:
                                    "%.4e",
                                result.qrtlDeflectionArcseconds
                            ) +
                            " arcsec"
                        )

                        Text(
                            "GR:   " +
                            String(
                                format:
                                    "%.4e",
                                result.grDeflectionArcseconds
                            ) +
                            " arcsec"
                        )

                        Text(
                            "Δ:    " +
                            String(
                                format:
                                    "%.2f",
                                result.differencePercent
                            ) +
                            " %"
                        )
                    }
                }

                Section(
                    "Status"
                ) {

                    Text(
                        statusMessage
                    )
                    .font(
                        .footnote
                    )
                    .foregroundStyle(
                        .secondary
                    )
                }
            }

            .navigationTitle(
                "QRTL Lensing"
            )

            .navigationBarTitleDisplayMode(
                .inline
            )
        }
    }

    private func slider(
        _ title:
            String,

        value:
            Binding<Double>,

        range:
            ClosedRange<Double>
    ) -> some View {

        VStack(
            alignment:
                .leading
        ) {

            HStack {

                Text(
                    title
                )

                Spacer()

                Text(
                    String(
                        format:
                            "%.3e",
                        value.wrappedValue
                    )
                )
                .font(
                    .caption.monospaced()
                )
                .foregroundStyle(
                    .secondary
                )
            }

            Slider(
                value:
                    value,

                in:
                    range
            )
        }
    }
}

// ============================================================
// MAIN CONTENT VIEW
// ============================================================

struct ContentView:
    View {

    @State private var massSolar:
        Double =
        1_000_000

    @State private var radiusSolar:
        Double =
        35

    @State private var alphaQ:
        Double =
        5e-6

    @State private var etaQ:
        Double =
        3.0

    @State private var gammaQ:
        Double =
        1.0

    @State private var electromagneticCoupling:
        Double =
        2e-11

    @State private var photonEMCoupling:
        Double =
        5e-21

    @State private var chiQ:
        Double =
        1.0

    @State private var interactionRate:
        Double =
        0.0

    @State private var result:
        QRTLExperimentResult?

    @State private var isRunning:
        Bool =
        false

    @State private var statusMessage:
        String =
        "Ready — source galaxy → QRTL lens → observation plane"

    @State private var showControls:
        Bool =
        false

    @State private var showPhotonPaths:
        Bool =
        true

    @StateObject private var scene =
        LensingSceneController()

    var body:
        some View {

        ZStack {

            LensingSceneView(
                controller:
                    scene
            )
            .ignoresSafeArea()

            VStack {

                Spacer()

                Toggle(
                    isOn:
                        $showPhotonPaths
                ) {

                    Label(
                        "Smooth Photon Paths",
                        systemImage:
                            "wave.3.forward"
                    )
                    .labelStyle(
                        .titleAndIcon
                    )
                }
                .padding(
                    .horizontal
                )
                .padding(
                    .bottom,
                    16
                )
                .foregroundColor(
                    .white
                )
                .background(
                    .ultraThinMaterial,
                    in:
                        Capsule()
                )
                .tint(
                    .pink
                )
                .frame(
                    maxWidth:
                        250
                )

                HStack {

                    Spacer()

                    Button {

                        showControls =
                            true

                    } label: {

                        Image(
                            systemName:
                                "slider.horizontal.3"
                        )
                        .font(
                            .title2.weight(
                                .semibold
                            )
                        )
                        .foregroundStyle(
                            .white
                        )
                        .padding(
                            16
                        )
                        .background(
                            .ultraThinMaterial,
                            in:
                                Circle()
                        )
                    }
                    .padding(
                        [
                            .trailing,
                            .bottom
                        ],
                        28
                    )
                }
            }
        }

        .sheet(
            isPresented:
                $showControls
        ) {

            ControlsSheet(

                massSolar:
                    $massSolar,

                radiusSolar:
                    $radiusSolar,

                alphaQ:
                    $alphaQ,

                etaQ:
                    $etaQ,

                gammaQ:
                    $gammaQ,

                electromagneticCoupling:
                    $electromagneticCoupling,

                photonEMCoupling:
                    $photonEMCoupling,

                chiQ:
                    $chiQ,

                interactionRate:
                    $interactionRate,

                result:
                    $result,

                isRunning:
                    $isRunning,

                statusMessage:
                    $statusMessage,

                onRun:
                    runFullPipeline,

                onReset:
                    reset
            )
            .presentationDetents(
                [
                    .medium,
                    .large
                ]
            )
            .presentationDragIndicator(
                .visible
            )
        }

        .onAppear {

            runFullPipeline()
        }
    }

    // ========================================================
    // RESET
    // ========================================================

    private func reset() {

        guard !isRunning
        else {
            return
        }

        alphaQ =
            0

        etaQ =
            0

        gammaQ =
            1

        electromagneticCoupling =
            0

        photonEMCoupling =
            0

        chiQ =
            1

        interactionRate =
            0

        result =
            nil

        statusMessage =
            "Reset to pure GR"

        scene.clearDynamic()

        scene.addGlobularCluster(
            radius:
                radiusSolar *
                PhysicalConstants.solarRadius
        )

        scene.addSourceGalaxy()

        scene.addFrontProjectionPlane(
            empty:
                true
        )

        scene.addBottomPlaceholder()
    }

    private func runFullPipeline() {

        guard !isRunning else { return }

        isRunning = true
        result = nil
        statusMessage = "Starting QRTL lensing pipeline…"

        // --------------------------------------------------------
        // Capture UI values on the main thread
        // --------------------------------------------------------
        let mass = massSolar * PhysicalConstants.solarMass
        let showPaths = showPhotonPaths

        // Scene-scale geometry (must match heatmap + photon tracer)
        let sourceGalaxyRadius: Float = 0.75
        let photonCount = 1200
        let clusterSceneRadius: Double = 3.0          // scene units
        let frontPlaneX = scene.frontPlaneX           // e.g. 8 or 10

        var params = QRTLParameters()
        params.alphaQ = alphaQ
        params.etaQ = etaQ
        params.gammaQ = gammaQ
        params.chiQ = chiQ
        params.interactionRate = interactionRate
        params.electromagneticCoupling = electromagneticCoupling
        params.photonEMCoupling = photonEMCoupling

        scene.clearDynamic()

        DispatchQueue.global(qos: .userInitiated).async {

            autoreleasepool {

                // =================================================
                // STAGE 1 — Field (scene units)
                // =================================================
                DispatchQueue.main.async {
                    self.statusMessage = "Stage 1/4 — building QRTL field…"
                }

                let massModel = GaussianMassModel(
                    totalMass: mass,
                    characteristicRadius: clusterSceneRadius   // ← scene units, not metres
                )

                let field = QRTLField(
                    massModel: massModel,
                    parameters: params
                )

                let experiment = QRTLExperiment(
                    mass: mass,
                    radius: clusterSceneRadius * PhysicalConstants.solarRadius, // diagnostic only
                    parameters: params
                )

                let outcome = experiment.run(
                    impactParameter: 0.15 * PhysicalConstants.solarRadius,
                    startDistance: 6.0 * PhysicalConstants.solarRadius,
                    endDistance: 6.0 * PhysicalConstants.solarRadius,
                    stepSize: 0.15 * PhysicalConstants.solarRadius
                )

                // =================================================
                // STAGE 2 — Trace photons
                // =================================================
                DispatchQueue.main.async {
                    self.statusMessage = "Stage 2/4 — tracing photon population…"
                }

                var lensingParameters = LensingParameters()
                lensingParameters.stepSize = 0.04
                lensingParameters.maxSteps = 1200
                lensingParameters.deflectionStrength = 0.15      // stronger for visible bend
                lensingParameters.qrtlFieldCoupling = 5.0
                lensingParameters.electromagneticCoupling = 5.0
                lensingParameters.magneticPhotonCoupling = 1.0
                lensingParameters.magneticBendingStrength = 1.0
                lensingParameters.projectionDistance = frontPlaneX
                lensingParameters.projectionPlaneHalfExtent = 6.0

                var hits: [LensingProjectionHit] = []
                hits.reserveCapacity(photonCount)

                var photonTraces: [PhotonTraceResult] = []
                if showPaths {
                    photonTraces.reserveCapacity(photonCount)
                }

                for _ in 0..<photonCount {

                    let theta = Float.random(in: 0...(2 * .pi))
                    let radialFraction = sqrt(Float.random(in: 0...1))
                    let r = sourceGalaxyRadius * radialFraction

                    let sourceY = r * cos(theta)
                    let sourceZ = r * sin(theta)

                    let origin = SIMD3<Float>(-6.5, sourceY, sourceZ)
                    let direction = SIMD3<Float>(1, 0, 0)

                    let trace = self.tracePhoton(
                        origin: origin,
                        direction: direction,
                        field: field,                    // same scene-unit field
                        parameters: lensingParameters
                    )

                    if showPaths {
                        photonTraces.append(trace)
                    }

                    if let hit = self.makeHit(
                        from: trace,
                        sourceID: 0,
                        sourceCoordinates: SIMD2(sourceY, sourceZ)
                    ) {
                        hits.append(hit)
                    }
                }

                let projection = LensingProjectionResult.calculate(from: hits)

                // =================================================
                // STAGE 3 — Prepare scene
                // =================================================
                DispatchQueue.main.async {
                    self.statusMessage = "Stage 3/4 — preparing scene…"
                }

                // =================================================
                // STAGE 4 — Render
                // =================================================
                DispatchQueue.main.async {

                    self.statusMessage = "Stage 4/4 — rendering projection…"

                    // 1. Source galaxy
                    self.scene.addSourceGalaxy(
                        radius: Double(sourceGalaxyRadius),
                        nStars: 220
                    )

                    // 2. Globular cluster (lens)
                    self.scene.addGlobularCluster(
                        radius: clusterSceneRadius,
                        nStars: 3000
                    )

                    // 3. Bottom plane = QRTL heatmap (same field, scene units)
                    self.scene.updateBottomHeatmap(field: field)

                    // 4. Front plane = yellow projected galaxies
                    self.scene.applyProjection(projection)

                    // 5. Optional photon paths
                    if showPaths {
                        for trace in photonTraces {
                            self.scene.renderPhotonPath(trace.path)
                        }
                    }

                    self.result = outcome
                    self.statusMessage =
                        "Done — \(projection.validHits.count) hits on front plane"
                    self.isRunning = false
                }
            }
        }
    }

    
    // =====================================================
    // CONVERT TRACE TO PROJECTION HIT
    // =====================================================

    func makeHit(
        from trace: PhotonTraceResult,
        sourceID: Int,
        sourceCoordinates: SIMD2<Float>
    ) -> LensingProjectionHit? {

        guard
            let point =
                trace.projectionPoint,

            let coordinates =
                trace.projectionCoordinates
        else {
            return nil
        }

        return LensingProjectionHit(

            point:
                point,

            coordinates:
                coordinates,

            sourceCoordinates:
                sourceCoordinates,

            direction:
                trace.finalDirection,

            traveledDistance:
                trace.traveledDistance,

            interactionCount:
                trace.stepCount,

            maximumMagneticField:
                trace.maximumMagneticField,

            maximumQRTLInfluence:
                trace.maximumQRTLInfluence,

            maximumMagneticPhotonInfluence:
                trace.maximumMagneticPhotonInfluence,

            sourceID:
                sourceID
        )
    }
    func tracePhoton(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        field: QRTLField,
        parameters: LensingParameters
    ) -> PhotonTraceResult {

        // =========================================================
        // INITIALIZE POSITION
        // =========================================================

        var position =
            origin


        // =========================================================
        // INITIALIZE DIRECTION
        // =========================================================

        var rayDirection =
            simd_normalize(direction)


        // =========================================================
        // PHOTON PATH
        // =========================================================

        var path:
            [SIMD3<Float>] = []

        path.reserveCapacity(
            parameters.maxSteps + 1
        )

        path.append(
            position
        )


        // =========================================================
        // DIAGNOSTICS
        // =========================================================

        var traveledDistance:
            Float = 0.0

        var stepCount:
            Int = 0

        var maximumMagneticField:
            Float = 0.0

        var maximumQRTLInfluence:
            Float = 0.0

        var maximumMagneticPhotonInfluence:
            Float = 0.0


        // =========================================================
        // TARGET PROJECTION PLANE
        //
        // Photon travels primarily along +X.
        //
        // Projection plane:
        //
        //     X = projectionDistance
        // =========================================================

        let targetX =
            parameters.projectionDistance


        // =========================================================
        // INTEGRATE PHOTON PATH
        // =========================================================

        for _ in 0..<parameters.maxSteps {

            stepCount += 1


            // =====================================================
            // CURRENT DISTANCE FROM LENS
            // =====================================================

            let radius =
                simd_length(
                    position
                )


            if radius >
                parameters.maxRadius {

                break
            }


            // =====================================================
            // SAMPLE QRTL FIELD
            //
            // This vector represents the local QRTL/gravity
            // influence on the photon.
            //
            // It should point toward the lens.
            // =====================================================

            let qrtlInfluence =
                field.influence(
                    at:
                        position
                )


            let qrtlMagnitude =
                simd_length(
                    qrtlInfluence
                )


            maximumQRTLInfluence =
                max(
                    maximumQRTLInfluence,
                    qrtlMagnitude
                )


            // =====================================================
            // QRTL / GRAVITY DEFLECTION
            // =====================================================

            let qrtlDeflection =
                qrtlInfluence *
                parameters.qrtlFieldCoupling *
                parameters.deflectionStrength


            // =====================================================
            // SAMPLE ELECTROMAGNETIC FIELD
            //
            // IMPORTANT:
            //
            // This must be the LOCAL EM field at the photon
            // position. It is therefore different at different
            // locations inside the globular cluster.
            // =====================================================

            let electromagneticInfluence =
                field.electromagneticInfluence(
                    at:
                        position
                )


            let electromagneticMagnitude =
                simd_length(
                    electromagneticInfluence
                )


            maximumMagneticPhotonInfluence =
                max(
                    maximumMagneticPhotonInfluence,
                    electromagneticMagnitude
                )


            // =====================================================
            // ELECTROMAGNETIC PHOTON DEFLECTION
            // =====================================================

            let electromagneticDeflection =
                electromagneticInfluence *
                parameters.electromagneticCoupling *
                parameters.magneticPhotonCoupling *
                parameters.magneticBendingStrength


            // =====================================================
            // MAGNETIC FIELD DIAGNOSTIC
            //
            // If electromagneticInfluence represents the magnetic
            // field used for photon bending, use its magnitude here.
            // =====================================================

            maximumMagneticField =
                max(
                    maximumMagneticField,
                    electromagneticMagnitude
                )


            // =====================================================
            // NET LOCAL DEFLECTION
            //
            //                 QRTL
            //                  ↓
            //
            //       EM →  PHOTON  ← EM
            //
            // The actual vector directions come from the two fields.
            // =====================================================

            let totalDeflection =
                qrtlDeflection +
                electromagneticDeflection


            // =====================================================
            // UPDATE PHOTON DIRECTION
            // =====================================================

            let newDirection =
                rayDirection +
                totalDeflection


            if simd_length_squared(
                newDirection
            ) >
                0.000000001 {

                rayDirection =
                    simd_normalize(
                        newDirection
                    )
            }


            // =====================================================
            // SAVE PREVIOUS POSITION
            // =====================================================

            let previousPosition =
                position


            // =====================================================
            // ADVANCE PHOTON
            // =====================================================

            position +=
                rayDirection *
                parameters.stepSize


            traveledDistance +=
                parameters.stepSize


            // =====================================================
            // RECORD PHOTON PATH
            // =====================================================

            path.append(
                position
            )


            // =====================================================
            // TARGET PLANE INTERSECTION
            // =====================================================

            let previousX =
                previousPosition.x

            let currentX =
                position.x


            if previousX < targetX &&
                currentX >= targetX {

                let dx =
                    currentX -
                    previousX


                guard
                    abs(dx) >
                        0.000001
                else {
                    continue
                }


                // =================================================
                // EXACT INTERSECTION WITH X = TARGET
                // =================================================

                let t =
                    (
                        targetX -
                        previousX
                    ) / dx


                let hitPoint =
                    previousPosition +
                    (
                        position -
                        previousPosition
                    ) * t


                // =================================================
                // 2D PROJECTION COORDINATES
                //
                // X = depth
                // Y = horizontal image coordinate
                // Z = vertical image coordinate
                // =================================================

                let projectionCoordinates =
                    SIMD2<Float>(
                        hitPoint.y,
                        hitPoint.z
                    )


                // =================================================
                // SUCCESSFUL PHOTON TRACE
                // =================================================

                return PhotonTraceResult(

                    path:
                        path,

                    projectionPoint:
                        hitPoint,

                    projectionCoordinates:
                        projectionCoordinates,

                    finalDirection:
                        rayDirection,

                    traveledDistance:
                        traveledDistance,

                    stepCount:
                        stepCount,

                    maximumMagneticField:
                        maximumMagneticField,

                    maximumQRTLInfluence:
                        maximumQRTLInfluence,

                    maximumMagneticPhotonInfluence:
                        maximumMagneticPhotonInfluence,

                    reachedTarget:
                        true
                )
            }
        }


        // =========================================================
        // PHOTON DID NOT REACH TARGET
        // =========================================================

        return PhotonTraceResult(

            path:
                path,

            projectionPoint:
                nil,

            projectionCoordinates:
                nil,

            finalDirection:
                rayDirection,

            traveledDistance:
                traveledDistance,

            stepCount:
                stepCount,

            maximumMagneticField:
                maximumMagneticField,

            maximumQRTLInfluence:
                maximumQRTLInfluence,

            maximumMagneticPhotonInfluence:
                maximumMagneticPhotonInfluence,

            reachedTarget:
                false
        )
    }
}
struct LensingParameters {


    var stepSize: Float
    var maxSteps: Int
    var maxRadius: Float
    var deflectionStrength: Float


    // =========================================================
    // QRTL / ELECTROMAGNETIC COUPLING
    // =========================================================

    var magneticPhotonCoupling: Float
    var magneticBendingStrength: Float
    var qrtlFieldCoupling: Float
    var currentCoupling: Float
    var electromagneticCoupling: Float


    // =========================================================
    // PROJECTION
    // =========================================================

    var projectionDistance: Float
    var projectionPlaneHalfExtent: Float


    // =========================================================
    // INITIALIZER
    // =========================================================

    init(
        stepSize: Float = 0.05,
        maxSteps: Int = 20_000,
        maxRadius: Float = 500.0,
        deflectionStrength: Float = 0.01,

        magneticPhotonCoupling: Float = 1.0,
        magneticBendingStrength: Float = 1.0,
        qrtlFieldCoupling: Float = 1.0,
        currentCoupling: Float = 1.0,
        electromagneticCoupling: Float = 1.0,

        projectionDistance: Float = 6.0,
        projectionPlaneHalfExtent: Float = 3.0
    ) {

        self.stepSize =
            stepSize

        self.maxSteps =
            maxSteps

        self.maxRadius =
            maxRadius

        self.deflectionStrength =
            deflectionStrength

        self.magneticPhotonCoupling =
            magneticPhotonCoupling

        self.magneticBendingStrength =
            magneticBendingStrength

        self.qrtlFieldCoupling =
            qrtlFieldCoupling

        self.currentCoupling =
            currentCoupling

        self.electromagneticCoupling =
            electromagneticCoupling

        self.projectionDistance =
            projectionDistance

        self.projectionPlaneHalfExtent =
            projectionPlaneHalfExtent
    }


  
}
struct PhotonTraceResult {

    // ---------------------------------------------------------
    // PHOTON PATH
    // ---------------------------------------------------------

    let path: [SIMD3<Float>]


    // ---------------------------------------------------------
    // PROJECTION
    // ---------------------------------------------------------

    /// Exact intersection with the target projection plane.
    let projectionPoint: SIMD3<Float>?

    /// 2D coordinates on the projection plane.
    let projectionCoordinates: SIMD2<Float>?


    // ---------------------------------------------------------
    // FINAL PHOTON STATE
    // ---------------------------------------------------------

    /// Photon direction at the projection-plane intersection.
    let finalDirection: SIMD3<Float>

    /// Total distance traveled by the photon.
    let traveledDistance: Float

    /// Number of integration steps completed.
    let stepCount: Int


    // ---------------------------------------------------------
    // FIELD DIAGNOSTICS
    // ---------------------------------------------------------

    /// Maximum magnetic-field magnitude encountered.
    let maximumMagneticField: Float

    /// Maximum QRTL-field influence encountered.
    let maximumQRTLInfluence: Float

    /// Maximum magnetic photon influence encountered.
    let maximumMagneticPhotonInfluence: Float


    // ---------------------------------------------------------
    // TARGET STATUS
    // ---------------------------------------------------------

    let reachedTarget: Bool
}
