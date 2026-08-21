//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/20/26.
//


import Foundation

struct QRTLVisualizationScale {

    // ============================================================
    // DISPLAY SCALE
    // ============================================================

    /// Physical parsecs represented by one SceneKit unit.
    static let parsecsPerSceneUnit: Double = 5.0

    // ============================================================
    // ASTRONOMICAL → SCENE
    // ============================================================

    static func parsecsToSceneUnits(
        _ parsecs: Double
    ) -> Float {

        Float(
            parsecs /
            parsecsPerSceneUnit
        )
    }

    // ============================================================
    // SCENE → ASTRONOMICAL
    // ============================================================

    static func sceneUnitsToParsecs(
        _ sceneUnits: Float
    ) -> Double {

        Double(sceneUnits) *
        parsecsPerSceneUnit
    }

    // ============================================================
    // METERS → SCENE
    // ============================================================

    static func metersToSceneUnits(
        _ meters: Double
    ) -> Float {

        Float(
            meters /
            QRTLUnits.metersPerParsec /
            parsecsPerSceneUnit
        )
    }

    // ============================================================
    // SCENE → METERS
    // ============================================================

    static func sceneUnitsToMeters(
        _ sceneUnits: Float
    ) -> Double {

        Double(sceneUnits) *
        parsecsPerSceneUnit *
        QRTLUnits.metersPerParsec
    }
}
