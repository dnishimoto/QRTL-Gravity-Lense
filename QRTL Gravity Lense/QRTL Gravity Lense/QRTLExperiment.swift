//
//  QRTLExperiment.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/18/26.
//

import Foundation
import simd

// ============================================================
// QRTL EXPERIMENT
// ============================================================
//
// Authoritative physics experiment.
//
// Physical pipeline:
//
// BARYONIC MASS
//      ↓
// GLOBULAR CLUSTER STAR POSITIONS
//      ↓
// GLOBULAR CLUSTER DENSITY MAP
//      ↓
// PHYSICAL MASS DENSITY
//      ↓
// STELLAR GRAVITATIONAL POTENTIAL
//      ↓
// STELLAR GRAVITATIONAL ACCELERATION
//      ↓
// QRTL FIELD
//      ↓
// QRTL ENERGY DENSITY
//      ↓
// QRTL GRAVITY INDEX
//      ↓
// QRTL GRAVITATIONAL POTENTIAL
//      ↓
// QRTL GRAVITATIONAL ACCELERATION
//      ↓
// TRANSVERSE GRAVITY
//      ↓
// EINSTEIN-STYLE PHOTON CURVATURE
//      ↓
// PHOTON TRACER
//      ↓
// PHOTON TRACE RESULT
//      ↓
// MEASURED QRTL PHOTON DEFLECTION
//      ↓
// GENERAL RELATIVITY REFERENCE
//      ↓
// QRTL / GR COMPARISON
//
// ============================================================

final class QRTLExperiment {

    // ========================================================
    // FIELD
    // ========================================================

    let field: QRTLField

    // ========================================================
    // PARAMETERS
    // ========================================================

    let parameters: QRTLParameters

    // ========================================================
    // PHYSICAL CONSTANTS
    // ========================================================

    private static let solarMassKg: Double =
        1.98847e30

    private static let defaultClusterMassKg: Double =
        1.0e6 * solarMassKg

    // ========================================================
    // CLUSTER CONFIGURATION
    // ========================================================

    private let clusterMassKg: Double

    private let clusterRadiusMeters: Double

    private let starCount: Int = 1000

    // ========================================================
    // STAR POSITIONS
    // ========================================================

    //
    // These positions are retained so the experiment and
    // density map use the SAME physical stellar distribution.
    //
    let starPositions: [SIMD3<Float>]

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init(
        mass: Double,
        radius: Double,
        parameters: QRTLParameters
    ) {

        self.parameters = parameters

        // ====================================================
        // TOTAL CLUSTER MASS
        // ====================================================

        let resolvedClusterMassKg: Double

        if mass.isFinite && mass > 0.0 {

            resolvedClusterMassKg = mass

        } else {

            resolvedClusterMassKg =
                Self.defaultClusterMassKg
        }

        self.clusterMassKg =
            resolvedClusterMassKg

        // ====================================================
        // CLUSTER RADIUS
        // ====================================================

        let resolvedRadius: Double =
            radius.isFinite && radius > 0.0
            ? radius
            : 1.0e-6

        self.clusterRadiusMeters =
            resolvedRadius

        let clusterRadiusFloat =
            Float(resolvedRadius)

        // ====================================================
        // STAR DISTRIBUTION
        // ====================================================
        //
        // Generate the physical 3D stellar distribution.
        //
        // The same positions are passed directly into
        // GlobularClusterDensityMap.
        //
        // Therefore:
        //
        //     stars
        //       ↓
        //     density map
        //       ↓
        //     QRTLField
        //
        // all describe the same lens.
        //
        // ====================================================

        var positions:
            [SIMD3<Float>] = []

        positions.reserveCapacity(
            starCount
        )

        for _ in 0..<starCount {

            let theta =
                Float.random(
                    in: 0.0...(2.0 * Float.pi)
                )

            let zDirection =
                Float.random(
                    in: -1.0...1.0
                )

            let radialXY =
                sqrt(
                    max(
                        0.0,
                        1.0 -
                        zDirection *
                        zDirection
                    )
                )

            let randomUnit =
                Float.random(
                    in: 0.0...1.0
                )

            // Uniform spherical-volume distribution.
            let radialFraction =
                pow(
                    randomUnit,
                    Float(1.0 / 3.0)
                )

            let r =
                clusterRadiusFloat *
                radialFraction

            let x =
                r *
                radialXY *
                cos(theta)

            let y =
                r *
                radialXY *
                sin(theta)

            let z =
                r *
                zDirection

            positions.append(
                SIMD3<Float>(
                    x,
                    y,
                    z
                )
            )
        }

        self.starPositions =
            positions

        // ====================================================
        // GLOBULAR CLUSTER DENSITY MAP
        // ====================================================
        //
        // This is the physical source of the lens.
        //
        // It contains:
        //
        // • total cluster mass
        // • cluster radius
        // • 3,000 stars
        // • per-star mass
        // • actual 3D star positions
        // • physical mass density
        // • stellar gravitational potential
        // • stellar gravitational acceleration
        //
        // ====================================================

        let densityMap =
            GlobularClusterDensityMap(
                clusterMassKg:
                    resolvedClusterMassKg,

                clusterRadiusMeters:
                    clusterRadiusFloat,

                starPositions:
                    positions,

                plummerScaleFraction:
                    0.30
            )

        // ====================================================
        // AUTHORITATIVE QRTL FIELD
        // ====================================================
        //
        // IMPORTANT:
        //
        // Current QRTLField owns the QRTL gravity model.
        //
        // The field receives the actual 3D stellar mass model.
        //
        // It then calculates:
        //
        // physical density
        //       ↓
        // QRTL source
        //       ↓
        // Bolgarino flux
        //       ↓
        // QRTL current
        //       ↓
        // QRTL energy density
        //       ↓
        // QRTL gravity index
        //       ↓
        // QRTL gravitational acceleration
        //       ↓
        // photon curvature
        //
        // ====================================================

        self.field =
            QRTLField(
                densitySource:
                    densityMap,

                parameters:
                    parameters
            )
    }

    // ========================================================
    // RUN EXPERIMENT
    // ========================================================

    func run(
        impactParameter: Double,
        startDistance: Double,
        endDistance: Double,
        stepSize: Double
    ) -> QRTLExperimentResult {

        // ====================================================
        // SAFE INPUTS
        // ====================================================

        let safeImpactParameter =
            max(
                abs(impactParameter),
                1.0e-9
            )

        let safeStartDistance =
            max(
                startDistance,
                1.0e-9
            )

        let safeEndDistance =
            max(
                endDistance,
                1.0e-9
            )

        let safeStepSize =
            max(
                stepSize,
                1.0e-9
            )

        // ====================================================
        // PHOTON ORIGIN
        // ====================================================
        //
        // Physical coordinates:
        //
        //     X = photon propagation direction
        //     Y = impact parameter
        //     Z = transverse direction
        //
        // Photon starts at -X and travels toward +X.
        //
        // ====================================================

        let origin =
            SIMD3<Float>(
                Float(-safeStartDistance),
                Float(safeImpactParameter),
                0.0
            )

        let direction =
            SIMD3<Float>(
                1.0,
                0.0,
                0.0
            )

        // ====================================================
        // TOTAL TRAVEL DISTANCE
        // ====================================================

        let totalDistance =
            safeStartDistance +
            safeEndDistance

        // ====================================================
        // INTEGRATION STEPS
        // ====================================================

        let calculatedMaxSteps =
            max(
                Int(
                    ceil(
                        totalDistance /
                        safeStepSize
                    )
                ),
                1
            )

        // ====================================================
        // CURRENT LENSING PARAMETERS
        // ====================================================
        //
        // The photon tracer queries the current QRTLField.
        //
        // In particular, QRTLField supplies:
        //
        //     qrtlGravitationalAcceleration(at:)
        //
        //     qrtlTransverseGravity(
        //         at:photonDirection:
        //     )
        //
        //     qrtlPhotonCurvature(
        //         at:direction:
        //     )
        //
        //     qrtlLensingAcceleration(
        //         at:direction:
        //     )
        //
        // The QRTL gravity index is therefore part of the
        // actual photon-curvature calculation.
        //
        // Electromagnetic photon bending remains disabled
        // here so the gravitational QRTL prediction can be
        // compared independently with GR.
        //
        // ====================================================

        let lensingParameters =
            LensingParameters(

                maximumPropagationRadius:
                    Float(
                        max(
                            totalDistance,
                            0.001
                        )
                    ),

                photonStepSize:
                    Float(
                        safeStepSize
                    ),

                maximumPhotonSteps:
                    calculatedMaxSteps,

                deflectionStrength:
                    1.0,

                qrtlLensingStrength:
                    Float(
                        parameters.chiQ
                    ),

                maximumPhotonBend:
                    0.35,

                qrtlFieldCoupling:
                    1.0,

                qrtlPhotonCoupling:
                    1.0,

                electromagneticCoupling:
                    0.0,

                magneticPhotonCoupling:
                    0.0,

                magneticBendingStrength:
                    0.0,

                currentCoupling:
                    0.0,

                targetPlaneX:
                    Float(
                        safeEndDistance
                    ),

                projectionPlaneHalfExtent:
                    18.0,

                interactionRate:
                    0.0
            )

        // ====================================================
        // QRTL GRAVITY INDEX DIAGNOSTIC
        // ====================================================
        //
        // The QRTLField now contains a global calibration
        // relationship between the physical stellar mass
        // density and the QRTL effective energy density.
        //
        // This is NOT a GR value.
        //
        // It is a QRTL calibration quantity used to put the
        // QRTL gravitational prediction onto the physical
        // mass scale.
        //
        // ====================================================

      
        print("")
        print("============================================================")
        print("QRTL EXPERIMENT")
        print("============================================================")
        print("Cluster mass:")
        print(clusterMassKg)
        print("Cluster radius:")
        print(clusterRadiusMeters)
        print("Star count:")
        print(starPositions.count)
        print("Per-star mass:")
        print("QRTL gravity index:")
           print("============================================================")
        print("")

        // ====================================================
        // PHOTON TRACER
        // ====================================================

        let tracer =
            QRTLPhotonTracer(
                field:
                    field
            )

        let trace =
            tracer.tracePhoton(
                origin:
                    origin,

                direction:
                    direction,

                parameters:
                    lensingParameters
            )

        // ====================================================
        // VALIDATE TRACE
        // ====================================================

        guard
            trace.positions.count >= 2
        else {

            return zeroResult()
        }

        // ====================================================
        // PHOTON POSITIONS
        // ====================================================

        let positions =
            trace.positions

        // ====================================================
        // INCOMING DIRECTION
        // ====================================================

        let incomingVector =
            positions[1] -
            positions[0]

        let incomingLength =
            simd_length(
                incomingVector
            )

        guard
            incomingLength.isFinite,
            incomingLength > 0.000001
        else {

            return zeroResult()
        }

        let incoming =
            incomingVector /
            incomingLength

        // ====================================================
        // OUTGOING DIRECTION
        // ====================================================

        var outgoing =
            trace.finalDirection

        let outgoingLength =
            simd_length(
                outgoing
            )

        if
            !outgoingLength.isFinite ||
            outgoingLength <= 0.000001
        {

            let finalIndex =
                positions.count - 1

            let outgoingVector =
                positions[finalIndex] -
                positions[finalIndex - 1]

            let fallbackLength =
                simd_length(
                    outgoingVector
                )

            guard
                fallbackLength.isFinite,
                fallbackLength > 0.000001
            else {

                return zeroResult()
            }

            outgoing =
                outgoingVector /
                fallbackLength

        } else {

            outgoing /=
                outgoingLength
        }

        // ====================================================
        // DEFLECTION ANGLE
        // ====================================================
        //
        // This is the measured deflection produced by the
        // QRTLField-driven photon integration.
        //
        // ====================================================

        let dotProduct =
            simd_dot(
                incoming,
                outgoing
            )

        let cosine =
            min(
                max(
                    dotProduct,
                    -1.0
                ),
                1.0
            )

        let qrtlAngleFloat =
            acos(
                cosine
            )

        guard
            qrtlAngleFloat.isFinite
        else {

            return zeroResult()
        }

        let qrtlAngle =
            Double(
                qrtlAngleFloat
            )

        guard
            qrtlAngle.isFinite
        else {

            return zeroResult()
        }

        // ====================================================
        // GENERAL RELATIVITY REFERENCE
        // ====================================================
        //
        // Weak-field point-mass reference:
        //
        //     alpha_GR = 4GM / (b c²)
        //
        // This is intentionally independent of the QRTL
        // calculation.
        //
        // QRTL predicts its own deflection.
        //
        // GR supplies the reference prediction.
        //
        // ====================================================

        let G =
            Double(
                PhysicalConstants.G
            )

        let c =
            Double(
                PhysicalConstants.c
            )

        let cSquared =
            c * c

        let denominator =
            safeImpactParameter *
            cSquared

        guard
            denominator.isFinite,
            denominator > 0.0
        else {

            return zeroResult()
        }

        let grAngle =
            4.0 *
            G *
            clusterMassKg /
            denominator

        guard
            grAngle.isFinite
        else {

            return zeroResult()
        }

        // ====================================================
        // DIFFERENCE FROM GENERAL RELATIVITY
        // ====================================================

        let differencePercent: Double

        if grAngle > 0.0 {

            differencePercent =
                100.0 *
                (
                    qrtlAngle -
                    grAngle
                ) /
                grAngle

        } else {

            differencePercent =
                0.0
        }

        // ====================================================
        // ARCSECONDS
        // ====================================================

        let radiansToArcseconds =
            Double(
                PhysicalConstants
                    .radiansToArcseconds
            )

        let qrtlArcseconds =
            qrtlAngle *
            radiansToArcseconds

        let grArcseconds =
            grAngle *
            radiansToArcseconds

        // ====================================================
        // FINAL RESULT
        // ====================================================

        return QRTLExperimentResult(

            qrtlDeflection:
                qrtlAngle,

            grDeflection:
                grAngle,

            differencePercent:
                differencePercent,

            qrtlDeflectionArcseconds:
                qrtlArcseconds,

            grDeflectionArcseconds:
                grArcseconds
        )
    }

    // ========================================================
    // ZERO RESULT
    // ========================================================

    private func zeroResult()
        -> QRTLExperimentResult {

        return QRTLExperimentResult(

            qrtlDeflection:
                0.0,

            grDeflection:
                0.0,

            differencePercent:
                0.0,

            qrtlDeflectionArcseconds:
                0.0,

            grDeflectionArcseconds:
                0.0
        )
    }
}
