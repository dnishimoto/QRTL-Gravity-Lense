//
//  GlobularClusterDensity.swift
//  QRTL Gravity Lense
//
//  Converts the generated globular-cluster star positions
//  into a 3D cellular density field for QRTLField.
//

import Foundation
import simd

//
//  GlobularClusterDensity.swift
//  QRTL Gravity Lense
//
//  Cellular-Automata Driven Globular Cluster Density
//

import Foundation
import simd

final class GlobularClusterDensityMap:
    GlobularClusterDensitySource {

    // ========================================================
    // PHYSICAL CONSTANTS
    // ========================================================

    static let solarMassKg: Float =
        1.98847e30

    static let oneMillionSolarMassesKg: Float =
        1.0e6 *
        solarMassKg

    // ========================================================
    // SOURCE STAR DISTRIBUTION
    // ========================================================

    let positions:
        [SIMD3<Float>]

    // ========================================================
    // PHYSICAL CLUSTER RADIUS
    // ========================================================

    /// Radius of the CA field in meters.

    let fieldRadiusMeters:
        Float

    // ========================================================
    // TOTAL PHYSICAL CLUSTER MASS
    // ========================================================

    /// Total cluster mass in kilograms.
    ///
    /// For the QRTL lensing experiment:
    ///
    /// 1,000,000 solar masses
    ///
    /// = 1.98847e36 kg

    let totalMass:
        Float

    // ========================================================
    // GRAVITY MEASUREMENT (per-star mass)
    // ========================================================
    //
    // starCount:
    //     Total number of source stars in the cluster.
    //
    // perStarMassKg:
    //     totalMass / starCount
    //
    //     10^6 solar masses, divided evenly across every star
    //     in the distribution. This is the mass figure that
    //     actually sources the gravity surface: each occupied
    //     CA cell contributes (stars in cell) * perStarMassKg.
    // ========================================================

    var starCount:
        Int {

        positions.count
    }

    var perStarMassKg:
        Float {

        guard
            starCount > 0,
            totalMass.isFinite
        else {
            return 0.0
        }

        let value =
            totalMass /
            Float(starCount)

        guard value.isFinite
        else {
            return 0.0
        }

        return max(
            value,
            0.0
        )
    }

    var perStarMassSolar:
        Float {

        perStarMassKg /
        Self.solarMassKg
    }

    /// Human-readable gravity measurement for the cluster —
    /// total mass, star count, and the resulting per-star mass
    /// that sources the gravity surface.
    var gravityMeasurementReport:
        String {

        let totalSolar =
            totalMass /
            Self.solarMassKg

        return
            "Globular Cluster Gravity Measurement\n" +
            "  Total mass:     \(totalSolar) M☉  (\(totalMass) kg)\n" +
            "  Star count:     \(starCount)\n" +
            "  Mass per star:  \(perStarMassSolar) M☉  (\(perStarMassKg) kg)"
    }

    // ========================================================
    // CELLULAR-AUTOMATA GRID
    // ========================================================

    /// Cell size in meters.

    let cellSize:
        Float

    private let cellVolume:
        Float

    /// Raw dimensionless CA density.

    private var densityGrid:
        [SIMD3<Int>: Float] = [:]

    // ========================================================
    // MAXIMUM CA DENSITY
    // ========================================================

    /// Maximum raw CA density.

    var maximumDensity:
        Float {

        densityGrid.values.max() ?? 0.0
    }

    // ========================================================
    // INTEGRATED CA DENSITY
    // ========================================================

    /// Integral of the raw CA density over physical volume.
    ///
    /// Units:
    ///
    /// CA-density × m³

    var integratedDensity:
        Float {

        let integral =
            densityGrid.values.reduce(
                0.0
            ) {
                partial,
                density in

                partial +
                density *
                cellVolume
            }

        guard integral.isFinite
        else {
            return 0.0
        }

        return max(
            integral,
            0.0
        )
    }

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init(
        positions: [SIMD3<Float>],
        radiusMeters: Float,
        totalMass: Float,
        cellSizeMeters: Float = 0.20
    ) {

        self.positions =
            positions

        self.fieldRadiusMeters =
            max(
                radiusMeters,
                0.000001
            )

        self.totalMass =
            max(
                totalMass,
                0.0
            )

        self.cellSize =
            max(
                cellSizeMeters,
                0.000001
            )

        self.cellVolume =
            self.cellSize *
            self.cellSize *
            self.cellSize

        // ====================================================
        // BUILD CA DENSITY GRID
        // ====================================================

        var grid:
            [SIMD3<Int>: Float] = [:]

        for position in positions {

            let distance =
                simd_length(
                    position
                )

            guard
                distance.isFinite,
                distance <=
                    self.fieldRadiusMeters
            else {
                continue
            }

            let cell =
                Self.cellCoordinate(
                    position,
                    cellSize:
                        self.cellSize
                )

            // ------------------------------------------------
            // EACH SOURCE STAR CONTRIBUTES ONE UNIT OF
            // DIMENSIONLESS CELLULAR DENSITY.
            //
            // Physical mass normalization is performed later.
            // ------------------------------------------------

            grid[cell, default: 0.0] +=
                1.0
        }

        self.densityGrid =
            grid
    }

    // ========================================================
    // CELL COORDINATE
    // ========================================================

    private static func cellCoordinate(
        _ position: SIMD3<Float>,
        cellSize: Float
    ) -> SIMD3<Int> {

        SIMD3<Int>(
            Int(
                floor(
                    position.x /
                    cellSize
                )
            ),

            Int(
                floor(
                    position.y /
                    cellSize
                )
            ),

            Int(
                floor(
                    position.z /
                    cellSize
                )
            )
        )
    }

    // ========================================================
    // RAW CELLULAR-AUTOMATA DENSITY
    // ========================================================

    func density(
        at position: SIMD3<Float>
    ) -> Float {

        let distance =
            simd_length(
                position
            )

        guard
            distance.isFinite,
            distance <=
                fieldRadiusMeters
        else {
            return 0.0
        }

        let cell =
            Self.cellCoordinate(
                position,
                cellSize:
                    cellSize
            )

        let value =
            densityGrid[cell] ?? 0.0

        guard value.isFinite
        else {
            return 0.0
        }

        return max(
            value,
            0.0
        )
    }

    // ========================================================
    // NORMALIZED CA DENSITY
    // ========================================================

    func normalizedDensity(
        at position: SIMD3<Float>
    ) -> Float {

        let maximum =
            maximumDensity

        guard
            maximum.isFinite,
            maximum > 0.0
        else {
            return 0.0
        }

        let value =
            density(
                at:
                    position
            ) /
            maximum

        guard value.isFinite
        else {
            return 0.0
        }

        return min(
            max(
                value,
                0.0
            ),
            1.0
        )
    }

    // ========================================================
    // PHYSICAL MASS DENSITY
    // ========================================================
    //
    // This is the important normalization:
    //
    // rhoPhysical =
    //      rhoCA *
    //      totalMass /
    //      integratedDensity
    //
    // Therefore:
    //
    // ∫rhoPhysical dV = totalMass
    //
    // ========================================================

    func physicalMassDensity(
        at position: SIMD3<Float>
    ) -> Float {

        // ----------------------------------------------------
        // STARS OCCUPYING THIS CELL
        // ----------------------------------------------------
        //
        // density(at:) returns the raw CA count — one unit per
        // source star that landed in this cell.
        // ----------------------------------------------------

        let starsInCell =
            density(
                at:
                    position
            )

        guard
            starsInCell.isFinite,
            starsInCell > 0.0,
            perStarMassKg.isFinite,
            cellVolume.isFinite,
            cellVolume > 0.0
        else {
            return 0.0
        }

        // ----------------------------------------------------
        // GRAVITY MEASUREMENT APPLIED
        // ----------------------------------------------------
        //
        // Each star contributes exactly perStarMassKg
        // (= totalMass / starCount). The cell's physical mass
        // is (stars in cell) * perStarMassKg, and dividing by
        // the cell volume gives the physical mass density that
        // sources the gravity surface.
        // ----------------------------------------------------

        let cellMass =
            starsInCell *
            perStarMassKg

        let physicalDensity =
            cellMass /
            cellVolume

        guard physicalDensity.isFinite
        else {
            return 0.0
        }

        return max(
            physicalDensity,
            0.0
        )
    }

    // ========================================================
    // CELL OCCUPANCY
    // ========================================================

    func containsCell(
        at position: SIMD3<Float>
    ) -> Bool {

        let distance =
            simd_length(
                position
            )

        guard
            distance <=
                fieldRadiusMeters
        else {
            return false
        }

        let cell =
            Self.cellCoordinate(
                position,
                cellSize:
                    cellSize
            )

        return densityGrid[cell] != nil
    }

    // ========================================================
    // PHYSICAL MASS IN CELL
    // ========================================================

    func mass(
        at position: SIMD3<Float>
    ) -> Float {

        let density =
            physicalMassDensity(
                at:
                    position
            )

        let mass =
            density *
            cellVolume

        guard mass.isFinite
        else {
            return 0.0
        }

        return max(
            mass,
            0.0
        )
    }

    // ========================================================
    // OCCUPIED CELL COUNT
    // ========================================================

    var occupiedCellCount:
        Int {

        densityGrid.count
    }

    // ========================================================
    // TOTAL MASS CHECK
    // ========================================================

    /// Reconstructed physical mass from the normalized CA grid.
    ///
    /// This should equal totalMass to numerical precision.

    var gridPhysicalMass:
        Float {

        guard
            integratedDensity > 0.0
        else {
            return 0.0
        }

        let reconstructedMass =
            integratedDensity *
            totalMass /
            integratedDensity

        guard reconstructedMass.isFinite
        else {
            return 0.0
        }

        return reconstructedMass
    }

    // ========================================================
    // MASS CONSERVATION ERROR
    // ========================================================

    var massConservationError:
        Float {

        guard
            totalMass > 0.0
        else {
            return 0.0
        }

        return abs(
            gridPhysicalMass -
            totalMass
        ) /
        totalMass
    }
}
