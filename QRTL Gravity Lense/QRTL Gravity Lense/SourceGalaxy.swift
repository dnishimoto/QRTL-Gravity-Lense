//
//  SourceGalaxy.swift
//  QRTL Gravity Lense
//

import simd

// ================================================================
// SOURCE GALAXY
// ================================================================
//
// SINGLE AUTHORITATIVE DEFINITION of the source galaxy's stellar
// distribution.
//
// Before this class existed, the source galaxy was defined
// independently, and inconsistently, in three separate places:
//
//   1. LensingSceneController.generateYourExistingSourceGalaxyPositions()
//      — sourceX = -8.0, majorRadius = 2.8, minorRadius = 1.15,
//        spiral + bulge shape. Populated `sourceGalaxyPositions`,
//        which drove the VISIBLE stars and the continuous photon
//        emitter.
//
//   2. LensingSceneController.traceSourceGalaxy() read from a
//      DIFFERENT array, `sourceGalaxyStars`, which was declared but
//      never populated anywhere — so the initial photon batch (the
//      white photon-path lines) traced ZERO photons every run.
//
//   3. QRTLGravitySurfaceEntity.computeGalaxyProjections() defined
//      its own separate galaxy — a plain circular disk at
//      (-extent, 0, 0), radius 0.25 * extent — completely
//      disconnected from either of the above. This is what the
//      cyan traveling particles originated from.
//
// Three call sites, three different galaxies, none of them
// necessarily agreeing on where "the source galaxy" actually is.
// This class replaces all three with one generator that every
// consumer (visual star rendering, the initial trace batch, the
// continuous emitter, and the traveling-particle surface) reads
// from identically.
//
// COORDINATE CONVENTION (authoritative — matches QRTLExperiment
// and QRTLGravitySurfaceEntity exactly):
//
//     X = photon propagation direction
//     Y = transverse coordinate
//     Z = transverse coordinate
//
// The galaxy is therefore a disk (with a small central bulge)
// lying in the Y-Z plane, offset along -X — "behind" the lens,
// with photons traveling toward +X.
//
// Generation is fully deterministic (golden-angle placement, no
// randomness), so the same SourceGalaxy configuration always
// produces the same star positions — repeatable runs, same as
// QRTLExperiment's seeded stellar distribution.
// ================================================================

final class SourceGalaxy {

    // ============================================================
    // CONFIGURATION
    // ============================================================

    let centerX: Float
    let majorRadius: Float
    let minorRadius: Float
    let starCount: Int
    let bulgeFraction: Float
    let spiralTurns: Float

    // ============================================================
    // GENERATED STAR POSITIONS
    //
    // Computed once at init — deterministic, so every consumer
    // (visual rendering, initial trace batch, continuous emitter,
    // traveling-particle surface) reading `starPositions` gets the
    // exact same distribution.
    // ============================================================

    let starPositions: [SIMD3<Float>]

    // ============================================================
    // PHOTON PROPAGATION DIRECTION
    //
    // Always +X, matching the authoritative coordinate convention.
    // ============================================================

    var propagationDirection: SIMD3<Float> {

        SIMD3<Float>(
            1.0,
            0.0,
            0.0
        )
    }

    // ============================================================
    // INITIALIZATION
    // ============================================================

    init(
        centerX: Float = -8.0,
        majorRadius: Float = 2.8,
        minorRadius: Float = 1.15,
        starCount: Int = 220,
        bulgeFraction: Float = 0.20,
        spiralTurns: Float = 2.15
    ) {

        self.centerX = centerX
        self.majorRadius = majorRadius
        self.minorRadius = minorRadius
        self.starCount = starCount
        self.bulgeFraction = bulgeFraction
        self.spiralTurns = spiralTurns

        self.starPositions =
            Self.generate(
                centerX: centerX,
                majorRadius: majorRadius,
                minorRadius: minorRadius,
                starCount: starCount,
                bulgeFraction: bulgeFraction,
                spiralTurns: spiralTurns
            )
    }

    // ============================================================
    // GENERATION
    //
    // Extracted from the original
    // generateYourExistingSourceGalaxyPositions() implementation,
    // unchanged in behavior — a small central bulge plus a
    // two-arm spiral disk, placed with the golden angle for a
    // natural, non-clustered, fully deterministic distribution.
    //
    // - This function does NOT trace photons.
    // - This function does NOT apply gravitational lensing.
    // - The QRTLPhotonTracer applies the QRTL field later.
    // ============================================================

    private static func generate(
        centerX: Float,
        majorRadius: Float,
        minorRadius: Float,
        starCount: Int,
        bulgeFraction: Float,
        spiralTurns: Float
    ) -> [SIMD3<Float>] {

        guard starCount > 0 else {
            return []
        }

        var positions: [SIMD3<Float>] = []

        positions.reserveCapacity(
            starCount
        )

        let goldenAngle =
            Float.pi * (3.0 - sqrt(5.0))

        // --------------------------------------------------------
        // CENTRAL BULGE
        // --------------------------------------------------------

        let bulgeCount =
            Int(
                Float(starCount) *
                Float(bulgeFraction)
            )

        if bulgeCount > 0 {

            for i in 0..<bulgeCount {

                let t =
                    Float(i) /
                    Float(
                        max(bulgeCount - 1, 1)
                    )

                let radius =
                    0.20 +
                    0.75 * sqrt(t)

                let angle =
                    Float(i) * goldenAngle

                let y =
                    radius *
                    0.55 *
                    cos(angle)

                let z =
                    radius *
                    0.55 *
                    sin(angle)

                positions.append(
                    SIMD3<Float>(
                        centerX,
                        y,
                        z
                    )
                )
            }
        }

        // --------------------------------------------------------
        // SPIRAL DISK
        // --------------------------------------------------------

        let diskCount =
            starCount - bulgeCount

        if diskCount > 0 {

            for i in 0..<diskCount {

                let t =
                    Float(i) /
                    Float(
                        max(diskCount - 1, 1)
                    )

                // Concentrate more stars toward the inner disk.
                let radialFraction =
                    pow(t, 0.72)

                let radius =
                    majorRadius *
                    radialFraction

                let baseAngle =
                    Float(i) * goldenAngle

                let spiralAngle =
                    baseAngle +
                    radialFraction *
                    spiralTurns *
                    2.0 *
                    Float.pi

                // Elliptical disk.
                let y =
                    radius *
                    cos(spiralAngle)

                let z =
                    minorRadius *
                    radialFraction *
                    sin(spiralAngle)

                // Small vertical thickness.
                //
                // Deterministic pseudo-thickness rather than random
                // values so repeated pipeline runs produce the same
                // source galaxy.
                let thicknessPhase =
                    Float(i) * 1.6180339887

                let verticalOffset =
                    0.08 *
                    sin(thicknessPhase)

                positions.append(
                    SIMD3<Float>(
                        centerX,
                        y,
                        z + verticalOffset
                    )
                )
            }
        }

        return positions
    }
}
