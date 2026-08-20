//
//  GlobularClusterDensity.swift
//  QRTL Gravity Lense
//
//  Converts the generated globular-cluster star positions
//  into a 3D cellular density field for QRTLField.
//

import Foundation
import simd

final class GlobularClusterDensityMap:
    GlobularClusterDensitySource {

    // ============================================================
    // SOURCE STAR DISTRIBUTION
    // ============================================================

    let positions:
        [SIMD3<Float>]

    let radius:
        Float

    // ============================================================
    // MASS MODEL
    // ============================================================

    let totalMass:
        Float

    let massPerStar:
        Float

    // ============================================================
    // CELLULAR AUTOMATA GRID
    // ============================================================

    let cellSize:
        Float

    private let cellVolume:
        Float

    private var densityGrid:
        [SIMD3<Int>: Float] = [:]

    // ============================================================
    // DENSITY NORMALIZATION
    // ============================================================

    let maximumDensity:
        Float

    // ============================================================
    // INITIALIZATION
    // ============================================================

    init(
        positions: [SIMD3<Float>],
        radius: Float,
        totalMass: Float,
        cellSize: Float = 0.20
    ) {

        self.positions =
            positions

        self.radius =
            max(
                radius,
                0.0001
            )

        self.totalMass =
            max(
                totalMass,
                0.0
            )

        self.cellSize =
            max(
                cellSize,
                0.0001
            )

        self.cellVolume =
            self.cellSize *
            self.cellSize *
            self.cellSize

        self.massPerStar =
            self.totalMass /
            max(
                Float(positions.count),
                1.0
            )

        // ========================================================
        // BUILD 3D CELLULAR DENSITY GRID
        // ========================================================

        var grid:
            [SIMD3<Int>: Float] = [:]

        for position in positions {

            let cell =
                Self.cellCoordinate(
                    position,
                    cellSize:
                        self.cellSize
                )

            let densityContribution =
                self.massPerStar /
                self.cellVolume

            grid[cell, default: 0.0] +=
                densityContribution
        }

        self.densityGrid =
            grid

        self.maximumDensity =
            grid.values.max() ?? 0.0
    }

    // ============================================================
    // CELL COORDINATE
    // ============================================================

    private static func cellCoordinate(
        _ position: SIMD3<Float>,
        cellSize: Float
    ) -> SIMD3<Int> {

        return SIMD3<Int>(
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

    // ============================================================
    // MASS DENSITY
    // ============================================================

    func density(
        at position: SIMD3<Float>
    ) -> Float {

        let distance =
            simd_length(
                position
            )

        guard
            distance <= radius
        else {
            return 0.0
        }

        let cell =
            Self.cellCoordinate(
                position,
                cellSize:
                    cellSize
            )

        return max(
            densityGrid[cell] ?? 0.0,
            0.0
        )
    }

    // ============================================================
    // NORMALIZED DENSITY
    // ============================================================

    func normalizedDensity(
        at position: SIMD3<Float>
    ) -> Float {

        guard
            maximumDensity > 0.0
        else {
            return 0.0
        }

        let value =
            density(
                at:
                    position
            ) /
            maximumDensity

        guard
            value.isFinite
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

    // ============================================================
    // CELL OCCUPANCY
    // ============================================================

    func containsCell(
        at position: SIMD3<Float>
    ) -> Bool {

        let cell =
            Self.cellCoordinate(
                position,
                cellSize:
                    cellSize
            )

        return densityGrid[cell] != nil
    }

    // ============================================================
    // CELL MASS
    // ============================================================

    func mass(
        at position: SIMD3<Float>
    ) -> Float {

        let density =
            self.density(
                at:
                    position
            )

        return density *
            cellVolume
    }

    // ============================================================
    // NUMBER OF OCCUPIED CELLS
    // ============================================================

    var occupiedCellCount:
        Int {

        return densityGrid.count
    }
}
