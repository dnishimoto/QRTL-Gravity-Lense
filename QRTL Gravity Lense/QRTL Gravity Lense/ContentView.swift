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

    let totalMass: Double

    let characteristicRadius: Double

    func density(
        r: Double
    ) -> Double {

        let sigma =
            max(
                characteristicRadius,
                Double.leastNonzeroMagnitude
            )

        let normalization =
            totalMass /
            pow(
                2.0 * .pi,
                1.5
            ) /
            pow(
                sigma,
                3.0
            )

        return normalization *
            exp(
                -r * r /
                (
                    2.0 *
                    sigma *
                    sigma
                )
            )
    }

    func enclosedMass(
        r: Double
    ) -> Double {

        if r <= 0 {
            return 0
        }

        let sigma =
            max(
                characteristicRadius,
                Double.leastNonzeroMagnitude
            )

        let x =
            r /
            (
                sqrt(2.0) *
                sigma
            )

        let fraction =
            erf(x) -
            sqrt(
                2.0 / .pi
            ) *
            (
                r /
                sigma
            ) *
            exp(
                -r * r /
                (
                    2.0 *
                    sigma *
                    sigma
                )
            )

        return clamped(
            totalMass * fraction,
            minimum: 0,
            maximum: totalMass
        )
    }
}

// ============================================================
// QRTL FIELD
// ============================================================

final class QRTLField {

    let massModel:
        GaussianMassModel

    let parameters:
        QRTLParameters

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
    }

    func density(
        at position:
            SIMD3<Double>
    ) -> Double {

        massModel.density(
            r:
                simd_length(
                    position
                )
        )
    }

    // --------------------------------------------------------
    // QRTL RADIAL CURRENT
    // --------------------------------------------------------

    func qrtlCurrent(
        at position:
            SIMD3<Double>
    ) -> SIMD3<Double> {

        let r =
            simd_length(position)

        if r <= parameters.epsilon {
            return .zero
        }

        let enclosed =
            massModel.enclosedMass(
                r: r
            )

        let velocity =
            max(
                parameters.qrtlVelocity,
                parameters.epsilon
            )

        let attenuation =
            exp(
                -parameters.interactionRate *
                r /
                velocity
            )

        let magnitude =
            parameters.alphaQ *
            enclosed /
            (
                4.0 *
                .pi *
                r *
                r
            ) *
            attenuation

        return (
            position /
            r
        ) *
        magnitude
    }

    // --------------------------------------------------------
    // QRTL ENERGY DENSITY
    // --------------------------------------------------------

    func qrtlEnergyDensity(
        at position:
            SIMD3<Double>
    ) -> Double {

        let current =
            qrtlCurrent(
                at: position
            )

        let currentSquared =
            simd_dot(
                current,
                current
            )

        return currentSquared /
            (
                2.0 *
                max(
                    parameters.chiQ,
                    parameters.epsilon
                )
            )
    }

    // --------------------------------------------------------
    // EFFECTIVE GRAVITATING DENSITY
    // --------------------------------------------------------

    func effectiveGravitatingDensity(
        at position:
            SIMD3<Double>
    ) -> Double {

        let rhoB =
            density(
                at: position
            )

        let uQ =
            qrtlEnergyDensity(
                at: position
            )

        let c2 =
            PhysicalConstants.c *
            PhysicalConstants.c

        return rhoB +
            parameters.etaQ *
            uQ /
            c2
    }

    // --------------------------------------------------------
    // GRAVITATIONAL POTENTIAL
    //
    // Gaussian baryonic mass has an analytic potential:
    //
    // Phi = -GM erf(r / sqrt(2)sigma) / r
    //
    // The QRTL contribution is represented as an effective
    // enclosed QRTL mass.
    // --------------------------------------------------------

    func gravitationalPotential(
        at position:
            SIMD3<Double>
    ) -> Double {

        let r =
            max(
                simd_length(position),
                parameters.epsilon
            )

        let sigma =
            max(
                massModel.characteristicRadius,
                parameters.epsilon
            )

        let x =
            r /
            (
                sqrt(2.0) *
                sigma
            )

        let baryonicPotential =
            -PhysicalConstants.G *
            massModel.totalMass *
            erf(x) /
            r

        let uQ =
            qrtlEnergyDensity(
                at: position
            )

        let qrtlMassEquivalent =
            parameters.etaQ *
            uQ *
            (
                4.0 / 3.0
            ) *
            .pi *
            pow(
                r,
                3.0
            ) /
            (
                PhysicalConstants.c *
                PhysicalConstants.c
            )

        let qrtlPotential =
            -PhysicalConstants.G *
            qrtlMassEquivalent /
            r

        return baryonicPotential +
            qrtlPotential
    }

    // --------------------------------------------------------
    // EFFECTIVE ELECTROMAGNETIC ENERGY
    // --------------------------------------------------------

    func electromagneticField(
        at position:
            SIMD3<Double>
    ) -> (
        energy: Double,
        currentMag: Double
    ) {

        let r =
            max(
                simd_length(position),
                parameters.epsilon
            )

        let jq =
            qrtlCurrent(
                at: position
            )

        let jeff =
            parameters.electromagneticCoupling *
            jq

        let j2 =
            simd_dot(
                jeff,
                jeff
            )

        let geometry =
            32.0 *
            .pi *
            .pi *
            r *
            r

        let electricScale =
            parameters.electricFieldCoupling *
            parameters.electricFieldCoupling

        let magneticScale =
            parameters.magneticFieldCoupling *
            parameters.magneticFieldCoupling

        let uE =
            electricScale *
            j2 /
            (
                geometry *
                PhysicalConstants.epsilon0
            )

        let uB =
            magneticScale *
            PhysicalConstants.mu0 *
            j2 /
            geometry

        return (
            uE + uB,
            sqrt(
                simd_dot(
                    jq,
                    jq
                )
            )
        )
    }
}

// ============================================================
// PHOTON RAY TRACER
// ============================================================

final class QRTLPhotonTracer {

    let field:
        QRTLField

    init(
        field:
            QRTLField
    ) {

        self.field =
            field
    }

    // --------------------------------------------------------
    // GRAVITATIONAL INDEX
    // --------------------------------------------------------

    func gravitationalIndex(
        at position:
            SIMD3<Double>
    ) -> Double {

        let phi =
            field.gravitationalPotential(
                at: position
            )

        let c2 =
            PhysicalConstants.c *
            PhysicalConstants.c

        return 1.0 -
            (
                1.0 +
                field.parameters.gammaQ
            ) *
            phi /
            c2
    }

    // --------------------------------------------------------
    // EM INDEX
    // --------------------------------------------------------

    func electromagneticIndex(
        at position:
            SIMD3<Double>
    ) -> Double {

        let result =
            field.electromagneticField(
                at: position
            )

        return 1.0 +
            field.parameters.photonEMCoupling *
            result.energy
    }

    // --------------------------------------------------------
    // TOTAL INDEX
    //
    // n_total = n_G * n_EM
    // --------------------------------------------------------

    func totalIndex(
        at position:
            SIMD3<Double>
    ) -> Double {

        let nG =
            gravitationalIndex(
                at: position
            )

        let nEM =
            electromagneticIndex(
                at: position
            )

        let value =
            nG * nEM

        if value.isFinite {
            return max(
                value,
                1.0e-12
            )
        }

        return 1.0
    }

    // --------------------------------------------------------
    // TOTAL INDEX GRADIENT
    //
    // Central finite difference.
    //
    // Six index evaluations are required.
    // --------------------------------------------------------

    func totalIndexGradient(
        at position:
            SIMD3<Double>
    ) -> SIMD3<Double> {

        let r =
            simd_length(position)

        guard r > 1.0 else {
            return .zero
        }

        let step =
            max(
                r * 0.002,
                1.0e5
            )

        let dx =
            SIMD3<Double>(
                step,
                0,
                0
            )

        let dy =
            SIMD3<Double>(
                0,
                step,
                0
            )

        let dz =
            SIMD3<Double>(
                0,
                0,
                step
            )

        let xp =
            totalIndex(
                at: position + dx
            )

        let xm =
            totalIndex(
                at: position - dx
            )

        let yp =
            totalIndex(
                at: position + dy
            )

        let ym =
            totalIndex(
                at: position - dy
            )

        let zp =
            totalIndex(
                at: position + dz
            )

        let zm =
            totalIndex(
                at: position - dz
            )

        return SIMD3<Double>(
            (xp - xm) /
                (2.0 * step),

            (yp - ym) /
                (2.0 * step),

            (zp - zm) /
                (2.0 * step)
        )
    }

    // --------------------------------------------------------
    // TRACE
    // --------------------------------------------------------

    func trace(
        start:
            SIMD3<Double>,

        direction:
            SIMD3<Double>,

        totalDistance:
            Double,

        stepSize:
            Double
    ) -> [SIMD3<Double>] {

        var position =
            start

        var directionVector =
            simd_normalize(
                direction
            )

        var path:
            [SIMD3<Double>] = [
                position
            ]

        let minimumStep =
            field.parameters.minimumStepSolarRadii *
            PhysicalConstants.solarRadius

        let effectiveStep =
            max(
                stepSize,
                minimumStep
            )

        let calculatedSteps =
            Int(
                ceil(
                    totalDistance /
                    effectiveStep
                )
            )

        let nSteps =
            min(
                max(
                    calculatedSteps,
                    1
                ),
                field.parameters.maximumRaySteps
            )

        path.reserveCapacity(
            nSteps + 1
        )

        for _ in 0..<nSteps {

            let n =
                max(
                    totalIndex(
                        at: position
                    ),
                    1.0e-12
                )

            let gradient =
                totalIndexGradient(
                    at: position
                )

            let propagationGradient =
                gradient /
                n

            let transverse =
                transverseComponent(
                    propagationGradient,
                    relativeTo:
                        directionVector
                )

            var newDirection =
                directionVector +
                transverse *
                effectiveStep

            let magnitude =
                simd_length(
                    newDirection
                )

            guard magnitude.isFinite,
                  magnitude > 1.0e-20
            else {
                break
            }

            newDirection =
                simd_normalize(
                    newDirection
                )

            directionVector =
                newDirection

            position +=
                directionVector *
                effectiveStep

            guard position.x.isFinite,
                  position.y.isFinite,
                  position.z.isFinite
            else {
                break
            }

            path.append(
                position
            )
        }

        return path
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
// HEATMAP
// ============================================================

final class QRTLHeatmapGenerator {

    static func makeHeatmapImage(
        field:
            QRTLField,

        size:
            Int = 64,

        halfExtent:
            Double
    ) -> UIImage {

        UIGraphicsBeginImageContextWithOptions(
            CGSize(
                width:
                    size,

                height:
                    size
            ),

            true,

            1
        )

        guard let context =
            UIGraphicsGetCurrentContext()
        else {
            return UIImage()
        }

        var maxValue =
            1.0e-30

        var samples =
            [[Double]](
                repeating:
                    [Double](
                        repeating:
                            0,

                        count:
                            size
                    ),

                count:
                    size
            )

        for j in 0..<size {

            for i in 0..<size {

                let x =
                    -halfExtent +
                    (
                        Double(i) +
                        0.5
                    ) *
                    (
                        2.0 *
                        halfExtent /
                        Double(size)
                    )

                let z =
                    -halfExtent +
                    (
                        Double(j) +
                        0.5
                    ) *
                    (
                        2.0 *
                        halfExtent /
                        Double(size)
                    )

                let position =
                    SIMD3<Double>(
                        x,
                        0,
                        z
                    )

                let result =
                    field.electromagneticField(
                        at:
                            position
                    )

                let value =
                    result.currentMag *
                    1.0e12 +
                    result.energy *
                    1.0e22

                samples[j][i] =
                    value

                maxValue =
                    max(
                        maxValue,
                        value
                    )
            }
        }

        for j in 0..<size {

            for i in 0..<size {

                let t =
                    CGFloat(
                        clamped(
                            samples[j][i] /
                            maxValue,

                            minimum:
                                0,

                            maximum:
                                1
                        )
                    )

                let color:
                    UIColor

                if t < 0.25 {

                    color =
                        UIColor(
                            red:
                                0,

                            green:
                                0,

                            blue:
                                t * 4.0,

                            alpha:
                                1
                        )

                } else if t < 0.5 {

                    color =
                        UIColor(
                            red:
                                0,

                            green:
                                (t - 0.25) * 4.0,

                            blue:
                                1,

                            alpha:
                                1
                        )

                } else if t < 0.75 {

                    color =
                        UIColor(
                            red:
                                (t - 0.5) * 4.0,

                            green:
                                1,

                            blue:
                                1 -
                                (t - 0.5) * 4.0,

                            alpha:
                                1
                        )

                } else {

                    color =
                        UIColor(
                            red:
                                1,

                            green:
                                1,

                            blue:
                                max(
                                    0,
                                    1 -
                                    (t - 0.75) * 4.0
                                ),

                            alpha:
                                1
                        )
                }

                context.setFillColor(
                    color.cgColor
                )

                context.fill(
                    CGRect(
                        x:
                            i,

                        y:
                            size -
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

// ============================================================
// PROJECTION RESULT
// ============================================================

struct LensingProjectionResult {

    let hits:
        [(y: Double, z: Double)]

    let paths:
        [[SIMD3<Double>]]

    static func calculate(
        experiment:
            QRTLExperiment,

        sourceX:
            Double,

        frontPlaneX:
            Double,

        sourceRadius:
            Double,

        nRaysPerSide:
            Int,

        step:
            Double,

        showPaths:
            Bool
    ) -> LensingProjectionResult {

        let tracer =
            experiment.tracer

        let count =
            max(
                nRaysPerSide,
                2
            )

        let solarRadius =
            PhysicalConstants.solarRadius

        let sourcePhysicalX =
            sourceX *
            solarRadius

        let frontPhysicalX =
            frontPlaneX *
            solarRadius

        let half =
            sourceRadius

        let spacing =
            (
                2.0 *
                half
            ) /
            Double(
                count - 1
            )

        let totalDistance =
            frontPhysicalX -
            sourcePhysicalX

        var hits:
            [(y: Double, z: Double)] =
            []

        var paths:
            [[SIMD3<Double>]] =
            []

        hits.reserveCapacity(
            count * count
        )

        for iy in 0..<count {

            for iz in 0..<count {

                let y =
                    -half +
                    Double(iy) *
                    spacing

                let z =
                    -half +
                    Double(iz) *
                    spacing

                if y * y +
                    z * z >
                    half * half {

                    continue
                }

                let start =
                    SIMD3<Double>(
                        sourcePhysicalX,
                        y,
                        z
                    )

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
                            step
                    )

                guard path.count >= 2
                else {
                    continue
                }

                var hit:
                    (
                        y: Double,
                        z: Double
                    )?

                for k in 1..<path.count {

                    let p0 =
                        path[k - 1]

                    let p1 =
                        path[k]

                    let dx =
                        p1.x -
                        p0.x

                    guard abs(dx) >
                        1.0e-12
                    else {
                        continue
                    }

                    let a =
                        p0.x -
                        frontPhysicalX

                    let b =
                        p1.x -
                        frontPhysicalX

                    guard a * b <= 0
                    else {
                        continue
                    }

                    let t =
                        (
                            frontPhysicalX -
                            p0.x
                        ) /
                        dx

                    guard t >= 0,
                          t <= 1
                    else {
                        continue
                    }

                    let yHit =
                        p0.y +
                        t *
                        (
                            p1.y -
                            p0.y
                        )

                    let zHit =
                        p0.z +
                        t *
                        (
                            p1.z -
                            p0.z
                        )

                    hit =
                        (
                            yHit,
                            zHit
                        )

                    break
                }

                guard let hit
                else {
                    continue
                }

                hits.append(
                    hit
                )

                // ----------------------------------------------------
                // Only render a subset of rays.
                //
                // This prevents hundreds of SceneKit photon objects.
                // ----------------------------------------------------

                if showPaths &&
                    iy % 3 == 0 &&
                    iz % 3 == 0 {

                    let maxControlPoints =
                        8

                    var controlPoints:
                        [SIMD3<Double>] =
                        []

                    let stride =
                        max(
                            1,
                            path.count /
                            maxControlPoints
                        )

                    var index =
                        0

                    while index <
                            path.count &&
                          controlPoints.count <
                            maxControlPoints {

                        controlPoints.append(
                            path[index]
                        )

                        index +=
                            stride
                    }

                    controlPoints.append(
                        SIMD3<Double>(
                            frontPhysicalX,
                            hit.y,
                            hit.z
                        )
                    )

                    paths.append(
                        controlPoints
                    )
                }
            }
        }

        return LensingProjectionResult(
            hits:
                hits,

            paths:
                paths
        )
    }
}

// ============================================================
// 3-D SCENE CONTROLLER
// ============================================================

final class LensingSceneController:
    ObservableObject {

    let scene =
        SCNScene()

    private var pathNodes:
        [SCNNode] =
        []

    private var sourceGalaxyNodes:
        [SCNNode] =
        []

    private var massNode:
        SCNNode?

    private var frontPlaneNode:
        SCNNode?

    private var bottomPlaneNode:
        SCNNode?

    private var photonPathNodes:
        [SCNNode] =
        []
    let sourceX: Float = -6.0
    let lensX: Float = 0.0
    let frontPlaneX: Float = 10.0

    let bottomY: Float = -5.0

    // Make the target substantially larger.
    let planeHalfExtent: Float = 8.0
    let heatmapHalfExtent: Float = 5.0
   

    // ========================================================
    // PHYSICAL LENSING DISTANCE
    //
    // These are deliberately separated from the visual scene.
    //
    // The compact SceneKit scene represents the geometry,
    // while the physics can use much larger distances.
    // ========================================================

    let physicalSourceDistance:
        Double =
        10.0 *
        PhysicalConstants.solarRadius

    let physicalObserverDistance:
        Double =
        10.0 *
        PhysicalConstants.solarRadius

    var sourcePhysicalX:
        Double {

        -physicalSourceDistance
    }

    var frontPlanePhysicalX:
        Double {

        physicalObserverDistance
    }

    var totalPhysicalDistance:
        Double {

        physicalObserverDistance +
        physicalSourceDistance
    }

    private let accumulator =
        ProjectionAccumulator(
            resolution:
                128,

            halfExtent:
                1800.0 *
                PhysicalConstants.solarRadius
        )

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init() {

        setupCameraLights()

        addAxes()

        addFrontProjectionPlane(
            empty:
                true
        )

        addBottomPlaceholder()
    }

    // ========================================================
    // PHYSICAL -> SCENE
    // ========================================================

    private func physicalToScene(
        _ position:
            SIMD3<Double>
    ) -> SCNVector3 {

        let scale =
            PhysicalConstants.solarRadius

        return SCNVector3(
            Float(
                position.x /
                scale
            ),

            Float(
                position.y /
                scale
            ),

            Float(
                position.z /
                scale
            )
        )
    }

    // ========================================================
    // CAMERA / LIGHTING
    // ========================================================

    private func setupCameraLights() {

        let cameraNode =
            SCNNode()

        let camera =
            SCNCamera()

        camera.zNear =
            0.01

        camera.zFar =
            100.0

        camera.fieldOfView =
            55

        cameraNode.camera =
            camera

        cameraNode.position =
            SCNVector3(
                10,
                6,
                15
            )

        cameraNode.look(
            at:
                SCNVector3(
                    0,
                    0,
                    0
                )
        )

        scene.rootNode.addChildNode(
            cameraNode
        )

        let keyNode =
            SCNNode()

        let keyLight =
            SCNLight()

        keyLight.type =
            .omni

        keyLight.intensity =
            1800

        keyLight.attenuationStartDistance =
            5

        keyLight.attenuationEndDistance =
            40

        keyNode.light =
            keyLight

        keyNode.position =
            SCNVector3(
                4,
                8,
                8
            )

        scene.rootNode.addChildNode(
            keyNode
        )

        let ambientNode =
            SCNNode()

        let ambient =
            SCNLight()

        ambient.type =
            .ambient

        ambient.intensity =
            300

        ambientNode.light =
            ambient

        scene.rootNode.addChildNode(
            ambientNode
        )
    }

    // ========================================================
    // AXES
    // ========================================================

    private func addAxes() {

        let length:
            Float =
            8.0

        let definitions:
            [
                (
                    SCNVector3,
                    UIColor
                )
            ] = [

                (
                    SCNVector3(
                        length,
                        0,
                        0
                    ),
                    .systemRed
                ),

                (
                    SCNVector3(
                        0,
                        length,
                        0
                    ),
                    .systemGreen
                ),

                (
                    SCNVector3(
                        0,
                        0,
                        length
                    ),
                    .systemBlue
                )
            ]

        for (
            vector,
            color
        ) in definitions {

            let axisLength =
                sqrt(
                    vector.x *
                    vector.x +
                    vector.y *
                    vector.y +
                    vector.z *
                    vector.z
                )

            let cylinder =
                SCNCylinder(
                    radius:
                        0.015,

                    height:
                        CGFloat(
                            axisLength
                        )
                )

            let material =
                SCNMaterial()

            material.diffuse.contents =
                color

            material.emission.contents =
                color

            material.lightingModel =
                .constant

            cylinder.materials =
                [material]

            let node =
                SCNNode(
                    geometry:
                        cylinder
                )

            node.position =
                SCNVector3(
                    vector.x / 2,
                    vector.y / 2,
                    vector.z / 2
                )

            if abs(vector.x) > 0 {

                node.eulerAngles.z =
                    .pi / 2
            }

            if abs(vector.z) > 0 {

                node.eulerAngles.x =
                    .pi / 2
            }

            scene.rootNode.addChildNode(
                node
            )
        }
    }

    // ========================================================
    // CLEAR
    // ========================================================

    func clearDynamic() {

        pathNodes.forEach {
            $0.removeFromParentNode()
        }

        pathNodes.removeAll()

        photonPathNodes.forEach {
            $0.removeFromParentNode()
        }

        photonPathNodes.removeAll()

        sourceGalaxyNodes.forEach {
            $0.removeFromParentNode()
        }

        sourceGalaxyNodes.removeAll()

        massNode?.removeFromParentNode()

        massNode =
            nil

        bottomPlaneNode?.removeFromParentNode()

        bottomPlaneNode =
            nil

        frontPlaneNode?.removeFromParentNode()

        frontPlaneNode =
            nil

        accumulator.reset()
    }

    // ========================================================
    // SOURCE GALAXY
    // ========================================================

    func addSourceGalaxy(
        radius: Double = 0.75,
        nStars: Int = 220
    ) {
        // Remove any previous galaxy
        sourceGalaxyNodes.forEach {
            $0.removeFromParentNode()
        }

        sourceGalaxyNodes.removeAll()

        // Create stars
        for _ in 0..<nStars {

            // Random radial distance
            let r =
                radius *
                pow(
                    Double.random(in: 0.0...1.0),
                    0.7
                )

            // Random angular position
            let theta =
                Double.random(
                    in: 0.0...(2.0 * Double.pi)
                )

            // Spiral-arm modulation
            let arm =
                0.12 *
                sin(
                    2.5 * theta
                )

            // Galaxy Y coordinate
            let y =
                (
                    r +
                    arm * radius
                ) *
                cos(theta)

            // Galaxy Z coordinate
            let z =
                (
                    r +
                    arm * radius
                ) *
                sin(theta)

            // Create star
            let star =
                SCNSphere(
                    radius:
                        CGFloat(
                            Double.random(
                                in: 0.015...0.035
                            )
                        )
                )

            // Star appearance
            let material =
                SCNMaterial()

            material.diffuse.contents =
                UIColor.yellow

            material.emission.contents =
                UIColor.yellow

            material.lightingModel =
                .constant

            star.materials =
                [material]

            // Create node
            let node =
                SCNNode(
                    geometry: star
                )

            // Place galaxy at the source plane
            node.position =
                SCNVector3(
                    sourceX,
                    Float(y),
                    Float(z)
                )

            // Add to SceneKit
            scene.rootNode.addChildNode(
                node
            )

            sourceGalaxyNodes.append(
                node
            )
        }
    }

    // ========================================================
    // FRONT PROJECTION PLANE
    // ========================================================

    func addFrontProjectionPlane(
        empty: Bool
    ) {
        // ------------------------------------------------------------
        // Remove previous target plane
        // ------------------------------------------------------------

        frontPlaneNode?.removeFromParentNode()

        // ------------------------------------------------------------
        // Larger target plane
        //
        // planeHalfExtent = 10.0
        // therefore:
        //
        // width  = 20 SceneKit units
        // height = 20 SceneKit units
        // ------------------------------------------------------------

        let size =
            planeHalfExtent * 2.0

        let plane =
            SCNPlane(
                width: CGFloat(size),
                height: CGFloat(size)
            )

        let material =
            SCNMaterial()

        // ------------------------------------------------------------
        // Plane contents
        // ------------------------------------------------------------

        if empty {

            material.diffuse.contents =
                UIColor.cyan.withAlphaComponent(0.18)

            material.emission.contents =
                UIColor.cyan.withAlphaComponent(0.10)

        } else {

            let image =
                accumulator.makeImage()

            material.diffuse.contents =
                image

            material.emission.contents =
                image
        }

        material.isDoubleSided =
            true

        material.transparency =
            0.85

        material.lightingModel =
            .constant

        plane.materials =
            [material]

        // ------------------------------------------------------------
        // Target plane node
        // ------------------------------------------------------------

        let node =
            SCNNode(
                geometry: plane
            )

        node.name =
            "TargetProjectionPlane"

        node.position =
            SCNVector3(
                frontPlaneX,
                0,
                0
            )

        // ------------------------------------------------------------
        // SCNPlane starts in XY.
        //
        // Rotate 90 degrees around Y so the plane becomes YZ.
        // This places the observation plane at:
        //
        // X = frontPlaneX
        // ------------------------------------------------------------

        node.eulerAngles.y =
            Float.pi / 2.0

        scene.rootNode.addChildNode(
            node
        )

        frontPlaneNode =
            node

        // ============================================================
        // TARGET PLANE BORDER
        //
        // Cylinders are used instead of SCNGeometryElement.line,
        // because SCNGeometryElement has no lineWidth property.
        // ============================================================

        let borderRadius: CGFloat =
            0.035

        let half =
            planeHalfExtent

        let corners: [SCNVector3] = [

            SCNVector3(
                frontPlaneX,
                -half,
                -half
            ),

            SCNVector3(
                frontPlaneX,
                 half,
                -half
            ),

            SCNVector3(
                frontPlaneX,
                 half,
                 half
            ),

            SCNVector3(
                frontPlaneX,
                -half,
                 half
            )
        ]

        for i in 0..<4 {

            let p0 =
                corners[i]

            let p1 =
                corners[
                    (i + 1) % 4
                ]

            let dx =
                p1.x - p0.x

            let dy =
                p1.y - p0.y

            let dz =
                p1.z - p0.z

            let length =
                sqrt(
                    dx * dx +
                    dy * dy +
                    dz * dz
                )

            guard length > 0.0001 else {
                continue
            }

            let cylinder =
                SCNCylinder(
                    radius:
                        borderRadius,

                    height:
                        CGFloat(length)
                )

            let borderMaterial =
                SCNMaterial()

            borderMaterial.diffuse.contents =
                UIColor.cyan

            borderMaterial.emission.contents =
                UIColor.cyan

            borderMaterial.lightingModel =
                .constant

            cylinder.materials =
                [borderMaterial]

            let borderNode =
                SCNNode(
                    geometry:
                        cylinder
                )

            // --------------------------------------------------------
            // Center the cylinder between its two endpoints.
            // --------------------------------------------------------

            borderNode.position =
                SCNVector3(
                    (p0.x + p1.x) * 0.5,
                    (p0.y + p1.y) * 0.5,
                    (p0.z + p1.z) * 0.5
                )

            // --------------------------------------------------------
            // SCNCylinder's local Y axis is its length axis.
            // Point that axis toward p1.
            // --------------------------------------------------------

            borderNode.look(
                at: p1,
                up: SCNVector3(
                    0,
                    0,
                    1
                ),
                localFront: SCNVector3(
                    0,
                    1,
                    0
                )
            )

            node.addChildNode(
                borderNode
            )
        }
    }

    // ========================================================
    // BOTTOM PLACEHOLDER
    // ========================================================

    func addBottomPlaceholder() {

        bottomPlaneNode?.removeFromParentNode()

        let size =
            heatmapHalfExtent *
            2.0

        let plane =
            SCNPlane(
                width:
                    CGFloat(size),

                height:
                    CGFloat(size)
            )

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor(
                white:
                    0.07,

                alpha:
                    0.9
            )

        material.emission.contents =
            UIColor(
                white:
                    0.02,

                alpha:
                    0.4
            )

        material.isDoubleSided =
            true

        plane.materials =
            [material]

        let node =
            SCNNode(
                geometry:
                    plane
            )

        node.position =
            SCNVector3(
                0,
                bottomY,
                0
            )

        node.eulerAngles.x =
            -.pi / 2

        scene.rootNode.addChildNode(
            node
        )

        bottomPlaneNode =
            node
    }

    // ========================================================
    // HEATMAP
    // ========================================================

    func updateBottomHeatmap(
        field: QRTLField
    ) {
        bottomPlaneNode?.removeFromParentNode()

        let image =
            QRTLHeatmapGenerator.makeHeatmapImage(
                field: field,
                size: 96,
                halfExtent:
                    Double(heatmapHalfExtent) *
                    PhysicalConstants.solarRadius
            )

        let size =
            heatmapHalfExtent * 2.0

        let plane =
            SCNPlane(
                width: CGFloat(size),
                height: CGFloat(size)
            )

        let material =
            SCNMaterial()

        material.diffuse.contents =
            image

        material.emission.contents =
            image

        material.isDoubleSided =
            true

        plane.materials =
            [material]

        let node =
            SCNNode(
                geometry: plane
            )

        node.position =
            SCNVector3(
                0,
                bottomY,
                0
            )

        node.eulerAngles.x =
            -.pi / 2

        scene.rootNode.addChildNode(
            node
        )

        bottomPlaneNode =
            node
    }

    // ========================================================
    // LENS MASS
    // ========================================================

    func addCluster(
        radius:
            Double
    ) {

        massNode?.removeFromParentNode()

        let sceneRadius =
            radius /
            PhysicalConstants.solarRadius

        let visualRadius =
            Float(
                max(
                    sceneRadius,
                    0.08
                )
            )

        let sphere =
            SCNSphere(
                radius:
                    CGFloat(
                        visualRadius
                    )
            )

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor.orange

        material.emission.contents =
            UIColor.orange

        material.lightingModel =
            .constant

        sphere.materials =
            [material]

        let node =
            SCNNode(
                geometry:
                    sphere
            )

        node.position =
            SCNVector3(
                0,
                0,
                0
            )

        scene.rootNode.addChildNode(
            node
        )

        massNode =
            node
    }

    // ========================================================
    // CYLINDER BETWEEN TWO SCENE POINTS
    //
    // This replaces the invalid SCNGeometryElement.lineWidth
    // approach.
    // ========================================================

    private func makeTubeSegment(
        from:
            SCNVector3,

        to:
            SCNVector3,

        radius:
            CGFloat,

        color:
            UIColor
    ) -> SCNNode {

        let start =
            SIMD3<Float>(
                from.x,
                from.y,
                from.z
            )

        let end =
            SIMD3<Float>(
                to.x,
                to.y,
                to.z
            )

        let delta =
            end -
            start

        let length =
            simd_length(
                delta
            )

        guard length >
                1.0e-6
        else {
            return SCNNode()
        }

        let cylinder =
            SCNCylinder(
                radius:
                    radius,

                height:
                    CGFloat(
                        length
                    )
            )

        let material =
            SCNMaterial()

        material.diffuse.contents =
            color

        material.emission.contents =
            color

        material.lightingModel =
            .constant

        cylinder.materials =
            [material]

        let node =
            SCNNode(
                geometry:
                    cylinder
            )

        node.position =
            SCNVector3(
                (
                    from.x +
                    to.x
                ) * 0.5,

                (
                    from.y +
                    to.y
                ) * 0.5,

                (
                    from.z +
                    to.z
                ) * 0.5
            )

        // SCNCylinder's local Y axis is its length axis.
        let direction =
            simd_normalize(
                delta
            )

        let up =
            SIMD3<Float>(
                0,
                1,
                0
            )

        let dot =
            simd_dot(
                up,
                direction
            )

        if dot > 0.9999 {

            node.simdOrientation =
                simd_quatf(
                    angle:
                        0,

                    axis:
                        SIMD3<Float>(
                            1,
                            0,
                            0
                        )
                )

        } else if dot < -0.9999 {

            node.simdOrientation =
                simd_quatf(
                    angle:
                        .pi,

                    axis:
                        SIMD3<Float>(
                            1,
                            0,
                            0
                        )
                )

        } else {

            let axis =
                simd_normalize(
                    simd_cross(
                        up,
                        direction
                    )
                )

            let angle =
                acos(
                    clamped(
                        Double(dot),
                        minimum:
                            -1,
                        maximum:
                            1
                    )
                )

            node.simdOrientation =
                simd_quatf(
                    angle:
                        Float(angle),

                    axis:
                        axis
                )
        }

        return node
    }

    // ========================================================
    // SMOOTH PHOTON PATH
    //
    // Catmull-Rom -> dense points -> cylindrical segments.
    // ========================================================

    @discardableResult
    func addSplinePhotonPath(
        controlPoints:
            [SIMD3<Double>],

        color:
            UIColor = .cyan,

        radius:
            CGFloat = 0.018,

        pointsPerSegment:
            Int = 6
    ) -> SCNNode? {

        guard controlPoints.count >= 2
        else {
            return nil
        }

        let physicalPoints =
            CatmullRomSpline.interpolate(
                points:
                    controlPoints,

                pointsPerSegment:
                    pointsPerSegment
            )

        guard physicalPoints.count >= 2
        else {
            return nil
        }

        let root =
            SCNNode()

        root.name =
            "PhotonSpline"

        let scenePoints =
            physicalPoints.map {
                physicalToScene($0)
            }

        for i in 0..<(scenePoints.count - 1) {

            let segment =
                makeTubeSegment(
                    from:
                        scenePoints[i],

                    to:
                        scenePoints[i + 1],

                    radius:
                        radius,

                    color:
                        color
                )

            root.addChildNode(
                segment
            )
        }

        scene.rootNode.addChildNode(
            root
        )

        photonPathNodes.append(
            root
        )

        return root
    }

    // ========================================================
    // APPLY PROJECTION
    // ========================================================

    func applyProjection(
        _ projection:
            LensingProjectionResult
    ) {

        accumulator.reset()

        photonPathNodes.forEach {
            $0.removeFromParentNode()
        }

        photonPathNodes.removeAll()

        for hit in projection.hits {

            accumulator.addHit(
                y:
                    hit.y,

                z:
                    hit.z
            )
        }

        for controlPoints in projection.paths {

            guard controlPoints.count >= 2
            else {
                continue
            }

            addSplinePhotonPath(
                controlPoints:
                    controlPoints,

                color:
                    .cyan,

                radius:
                    0.012,

                pointsPerSegment:
                    5
            )
        }

        addFrontProjectionPlane(
            empty:
                false
        )
    }

    // ========================================================
    // LEGACY RAW PATH
    //
    // Kept for debugging.
    //
    // IMPORTANT:
    // There is intentionally NO lineWidth property here.
    // SCNGeometryElement has no lineWidth member.
    // ========================================================

    func addPhotonPath(
        _ points:
            [SIMD3<Double>]
    ) {

        guard points.count > 1
        else {
            return
        }

        let controlPoints =
            points

        addSplinePhotonPath(
            controlPoints:
                controlPoints,

            color:
                .cyan,

            radius:
                0.008,

            pointsPerSegment:
                2
        )
    }
}

// ============================================================
// SCENE VIEW
// ============================================================

struct LensingSceneView:
    UIViewRepresentable {

    @ObservedObject var controller:
        LensingSceneController

    func makeUIView(
        context:
            Context
    ) -> SCNView {

        let view =
            SCNView()

        view.scene =
            controller.scene

        view.allowsCameraControl =
            true

        view.autoenablesDefaultLighting =
            false

        view.backgroundColor =
            .black

        view.antialiasingMode =
            .multisampling4X

        return view
    }

    func updateUIView(
        _ uiView:
            SCNView,

        context:
            Context
    ) {
    }
}

// ============================================================
// CONTROLS
// ============================================================

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

        scene.addCluster(
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

    // ========================================================
    // FULL PIPELINE
    // ========================================================

    private func runFullPipeline() {

        guard !isRunning else {
            return
        }

        isRunning = true
        result = nil

        statusMessage = "Starting QRTL lensing pipeline…"

        // ------------------------------------------------------------
        // Capture all SwiftUI values BEFORE entering background thread.
        // ------------------------------------------------------------

        let mass =
            massSolar *
            PhysicalConstants.solarMass

        let radius =
            radiusSolar *
            PhysicalConstants.solarRadius

        let sourceXValue =
            Double(scene.sourceX)

        let frontPlaneXValue =
            Double(scene.frontPlaneX)

        let sourceRadius =
            0.75 *
            PhysicalConstants.solarRadius

        let showPaths =
            showPhotonPaths

        var params =
            QRTLParameters()

        params.alphaQ =
            alphaQ

        params.etaQ =
            etaQ

        params.gammaQ =
            gammaQ

        params.chiQ =
            chiQ

        params.interactionRate =
            interactionRate

        params.electromagneticCoupling =
            electromagneticCoupling

        params.photonEMCoupling =
            photonEMCoupling

        // ------------------------------------------------------------
        // Clear only on the main thread.
        // ------------------------------------------------------------

        scene.clearDynamic()

        // ------------------------------------------------------------
        // Run physics in background.
        // ------------------------------------------------------------

        DispatchQueue.global(
            qos: .userInitiated
        ).async {

            autoreleasepool {

                let experiment =
                    QRTLExperiment(
                        mass: mass,
                        radius: radius,
                        parameters: params
                    )

                // ----------------------------------------------------
                // Stage 1
                // ----------------------------------------------------

                DispatchQueue.main.async {
                    self.statusMessage =
                        "Stage 1/4 — calculating GR/QRTL deflection…"
                }

                let outcome =
                    experiment.run(
                        impactParameter:
                            0.15 *
                            PhysicalConstants.solarRadius,

                        startDistance:
                            6.0 *
                            PhysicalConstants.solarRadius,

                        endDistance:
                            6.0 *
                            PhysicalConstants.solarRadius,

                        stepSize:
                            0.15 *
                            PhysicalConstants.solarRadius
                    )

                // ----------------------------------------------------
                // Stage 2
                // ----------------------------------------------------

                DispatchQueue.main.async {
                    self.statusMessage =
                        "Stage 2/4 — tracing photon projection…"
                }

                let projection =
                    LensingProjectionResult.calculate(
                        experiment:
                            experiment,

                        sourceX:
                            sourceXValue,

                        frontPlaneX:
                            frontPlaneXValue,

                        sourceRadius:
                            sourceRadius,

                        // Start small enough to guarantee responsiveness.
                        nRaysPerSide:
                            12,

                        step:
                            0.15 *
                            PhysicalConstants.solarRadius,

                        showPaths:
                            showPaths
                    )

                // ----------------------------------------------------
                // Stage 3
                // ----------------------------------------------------

                DispatchQueue.main.async {
                    self.statusMessage =
                        "Stage 3/4 — preparing projection scene…"
                }

                // ----------------------------------------------------
                // Stage 4
                // ----------------------------------------------------

                DispatchQueue.main.async {

                    self.statusMessage =
                        "Stage 4/4 — rendering projection…"

                    // Source galaxy
                    self.scene.addSourceGalaxy(
                        radius: 0.75,
                        nStars: 220
                    )

                    // Central lensing mass
                    self.scene.addCluster(
                        radius: radius
                    )

                    // QRTL heatmap
                    self.scene.updateBottomHeatmap(
                        field:
                            experiment.field
                    )

                    // Photon paths + destination plane
                    self.scene.applyProjection(
                        projection
                    )

                    // Results
                    self.result =
                        outcome

                    self.statusMessage =
                        "Projection complete — " +
                        "\(projection.hits.count) photon hits, " +
                        "\(projection.paths.count) visible paths"

                    self.isRunning =
                        false
                }
            }
        }
    }
}
