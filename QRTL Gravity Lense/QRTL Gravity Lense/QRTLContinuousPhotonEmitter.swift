

import Foundation
import Combine
import simd

final class QRTLContinuousPhotonEmitter: ObservableObject {

    // ============================================================
    // MARK: - Published State
    // ============================================================

    @Published private(set) var emittedPhotonCount: Int = 0
    @Published private(set) var completedPhotonCount: Int = 0
    @Published private(set) var projectionHitCount: Int = 0
    @Published private(set) var activePhotonCount: Int = 0

    @Published private(set) var isEmitting: Bool = false

    // ============================================================
    // MARK: - Configuration
    // ============================================================

    var photonsPerSecond: Double = 30.0

    var maximumActivePhotons: Int = 1000

    // How frequently the emission timer checks for new photons.
    var emissionInterval: TimeInterval = 1.0 / 30.0

    // ============================================================
    // MARK: - Photon Source
    // ============================================================

    private var sourcePhotonProvider:
        (() -> [PhotonEmission])?

    // ============================================================
    // MARK: - Physics
    // ============================================================

    private var field: QRTLField?

    private var lensingParameters:
        LensingParameters?

    // ============================================================
    // MARK: - Callback
    // ============================================================

    private var photonHandler:
        ((PhotonEmission) -> Void)?

    private var completionHandler:
        ((PhotonEmission) -> Void)?

    // ============================================================
    // MARK: - Timer
    // ============================================================

    private var timer: DispatchSourceTimer?

    private let queue =
        DispatchQueue(
            label: "com.qrtl.continuous-photon-emitter",
            qos: .userInitiated
        )

    private var accumulator: Double = 0.0

    private var lastEmissionTime:
        TimeInterval?

    // ============================================================
    // MARK: - Photon Description
    // ============================================================

    struct PhotonEmission {

        let id: UUID

        let origin: SIMD3<Float>

        let direction: SIMD3<Float>

        let emissionTime: TimeInterval

        let sourceIndex: Int
    }

    // ============================================================
    // MARK: - Configuration
    // ============================================================

    func configure(
        field: QRTLField,
        parameters: LensingParameters,
        sourceProvider:
            @escaping () -> [PhotonEmission],
        onPhoton:
            @escaping (PhotonEmission) -> Void,
        onCompletion:
            @escaping (PhotonEmission) -> Void
    ) {

        self.field = field

        self.lensingParameters =
            parameters

        self.sourcePhotonProvider =
            sourceProvider

        self.photonHandler =
            onPhoton

        self.completionHandler =
            onCompletion
    }

    // ============================================================
    // MARK: - Start
    // ============================================================

    func start() {

        guard !isEmitting else {
            return
        }

        guard field != nil else {
            print(
                "QRTLContinuousPhotonEmitter: " +
                "cannot start without QRTLField."
            )

            return
        }

        guard lensingParameters != nil else {
            print(
                "QRTLContinuousPhotonEmitter: " +
                "cannot start without LensingParameters."
            )

            return
        }

        isEmitting = true

        accumulator = 0.0

        lastEmissionTime =
            CFAbsoluteTimeGetCurrent()

        let newTimer =
            DispatchSource.makeTimerSource(
                queue: queue
            )

        newTimer.schedule(
            deadline: .now(),
            repeating: emissionInterval
        )

        newTimer.setEventHandler { [weak self] in

            self?.emitFrame()
        }

        timer = newTimer

        newTimer.resume()

        print(
            "QRTL continuous photon emission STARTED"
        )
    }

    // ============================================================
    // MARK: - Stop
    // ============================================================

    func stop() {

        guard isEmitting else {
            return
        }

        isEmitting = false

        timer?.setEventHandler {}

        timer?.cancel()

        timer = nil

        lastEmissionTime = nil

        print(
            "QRTL continuous photon emission STOPPED"
        )
    }

    // ============================================================
    // MARK: - Reset
    // ============================================================

    func resetCounters() {

        emittedPhotonCount = 0
        completedPhotonCount = 0
        projectionHitCount = 0
        activePhotonCount = 0
    }

    // ============================================================
    // MARK: - Continuous Emission
    // ============================================================

    private func emitFrame() {

        guard isEmitting else {
            return
        }

        guard
            let sourceProvider =
                sourcePhotonProvider
        else {
            return
        }

        let now =
            CFAbsoluteTimeGetCurrent()

        let previous =
            lastEmissionTime ?? now

        let deltaTime =
            max(
                0.0,
                now - previous
            )

        lastEmissionTime = now

        accumulator +=
            deltaTime * photonsPerSecond

        let numberToEmit =
            Int(accumulator)

        guard numberToEmit > 0 else {
            return
        }

        accumulator -=
            Double(numberToEmit)

        guard
            activePhotonCount <
                maximumActivePhotons
        else {
            return
        }

        let availableCapacity =
            maximumActivePhotons -
            activePhotonCount

        let actualCount =
            min(
                numberToEmit,
                availableCapacity
            )

        guard actualCount > 0 else {
            return
        }

        let sources =
            sourceProvider()

        guard !sources.isEmpty else {
            return
        }

        for index in 0..<actualCount {

            let source =
                sources[
                    Int.random(
                        in: 0..<sources.count
                    )
                ]

            let photon =
                PhotonEmission(
                    id: UUID(),
                    origin: source.origin,
                    direction: source.direction,
                    emissionTime: now,
                    sourceIndex: source.sourceIndex
                )

            emittedPhotonCount += 1

            activePhotonCount += 1

            photonHandler?(photon)
        }
    }

    // ============================================================
    // MARK: - Photon Completion
    // ============================================================

    func photonCompleted(
        hitProjectionPlane: Bool
    ) {

        queue.async { [weak self] in

            guard let self else {
                return
            }

            self.activePhotonCount =
                max(
                    0,
                    self.activePhotonCount - 1
                )

            self.completedPhotonCount += 1

            if hitProjectionPlane {

                self.projectionHitCount += 1
            }

            self.completionHandler?(
                PhotonEmission(
                    id: UUID(),
                    origin: .zero,
                    direction: SIMD3<Float>(
                        0,
                        0,
                        1
                    ),
                    emissionTime:
                        CFAbsoluteTimeGetCurrent(),
                    sourceIndex: -1
                )
            )
        }
    }

    // ============================================================
    // MARK: - Deinit
    // ============================================================

    deinit {

        timer?.cancel()
    }
}
