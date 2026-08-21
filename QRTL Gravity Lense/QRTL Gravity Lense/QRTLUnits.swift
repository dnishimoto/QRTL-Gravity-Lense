//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/20/26.
//


import Foundation

struct QRTLUnits {

    // ============================================================
    // ASTRONOMICAL UNITS
    // ============================================================

    static let metersPerParsec: Double =
        3.0856775814913673e16

    static let kilogramsPerSolarMass: Double =
        1.98847e30

    // ============================================================
    // ASTRONOMICAL → SI
    // ============================================================

    static func parsecsToMeters(
        _ parsecs: Double
    ) -> Double {

        parsecs * metersPerParsec
    }

    static func solarMassesToKilograms(
        _ solarMasses: Double
    ) -> Double {

        solarMasses * kilogramsPerSolarMass
    }

    // ============================================================
    // SI → ASTRONOMICAL
    // ============================================================

    static func metersToParsecs(
        _ meters: Double
    ) -> Double {

        meters / metersPerParsec
    }

    static func kilogramsToSolarMasses(
        _ kilograms: Double
    ) -> Double {

        kilograms / kilogramsPerSolarMass
    }
}
