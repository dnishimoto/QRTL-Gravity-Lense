//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/18/26.
//

import Foundation

struct LensingPipelineOutput {

    let experimentResult:
        QRTLExperimentResult

    let field:
        QRTLField

    let photonTraces:
        [PhotonTraceResult]

    let photonPaths:
        [[SIMD3<Float>]]

    let photonHits:
        [LensingProjectionHit]

    let projection:
        LensingProjectionResult

    let tracedPhotonCount:
        Int

    let successfulProjectionHits:
        Int
}
