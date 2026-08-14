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
The actual prediction is therefore not simply “gravity bends light.”
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
So the architecture is now capable of making a QRTL prediction, but the numerical prediction isn’t yet uniquely determined by QRTL because those missing relationships still contain parameters such as alphaQ, etaQ, chiQ, electromagneticCoupling, and photonEMCoupling.
The next step would be to eliminate those arbitrary bridges by deriving them from the QRTL assumptions. Then the ASCII pipeline becomes a genuine QRTL prediction pipeline rather than a QRTL-inspired computational model.


Below is a corrected, self-contained Swift implementation. It makes the GR baseline explicit through the weak-field effective index

\[
n_G=1-\frac{(1+\gamma_Q)\Phi_Q}{c^2},
\]

which reduces to \(n_G=1-2\Phi/c^2\) when \(\gamma_Q=1\). That is the weak-field GR refractive-index form and yields the standard \(4GM/(bc^2)\) point-mass deflection in the appropriate limit.[1][2]

The QRTL additions remain clearly isolated as an effective model: QRTL flux \(\to\) QRTL energy density \(\to\) gravitational source, plus an optional QRTL-induced EM-energy phase term. The code also removes the arbitrary magnetic-field direction, uses `electromagneticCoupling`, uses `gammaQ`, and replaces the incorrect negative EM gradient sign with a single total-index ray equation.

```swift
import Foundation
import simd

// ============================================================
// QRTL + WEAK-FIELD GRAVITATIONAL LENSING
//
// PIPELINE
//
// Baryonic mass density rho_B
//              |
//              v
// QRTL source S_Q = alpha_Q * rho_B
//              |
//              v
// QRTL radial flux J_Q
//              |
//              +---------------------------+
//              |                           |
//              v                           v
// QRTL energy density u_Q          Effective EM source j_eff
//              |                           |
//              v                           v
// Effective gravitating density    Effective EM energy u_EM,Q
// rho_eff = rho_B + eta_Q u_Q/c^2          |
//              |                           v
//              v                  n_EM = 1 + kappa_EM * u_EM,Q
// Poisson equation for Phi_Q                 |
//              |                              |
//              +--------------+---------------+
//                             |
//                             v
// n_total = n_G * n_EM
//
// n_G = 1 - (1 + gamma_Q) Phi_Q / c^2
//
// Ray equation:
// d kHat / ds = [ grad(ln n_total) ]_perpendicular
//
// GR BASELINE:
// eta_Q = 0
// electromagneticCoupling = 0
// photonEMCoupling = 0
// gammaQ = 1
//
// Then n_total = 1 - 2 Phi_Newton / c^2,
// and the far-field point-mass deflection is
// alpha = 4 G M / (b c^2).
// ============================================================
*/
// MARK: - Constants
import SwiftUI
import SceneKit
import simd
import Combine

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
    static let radiansToArcseconds = 206_264.80624709636
}

// ============================================================
// UTILITIES
// ============================================================

@inline(__always)
func clamped(_ value: Double, minimum: Double, maximum: Double) -> Double {
    min(max(value, minimum), maximum)
}

@inline(__always)
func transverseComponent(_ vector: SIMD3<Double>, relativeTo direction: SIMD3<Double>) -> SIMD3<Double> {
    vector - direction * simd_dot(vector, direction)
}

// ============================================================
// PARAMETERS
// ============================================================

struct QRTLParameters {
    var alphaQ: Double = 0.0
    var qrtlVelocity: Double = PhysicalConstants.c
    var interactionRate: Double = 0.0
    var chiQ: Double = 1.0
    var etaQ: Double = 0.0
    var gammaQ: Double = 1.0
    var electromagneticCoupling: Double = 0.0
    var electricFieldCoupling: Double = 1.0
    var magneticFieldCoupling: Double = 1.0
    var photonEMCoupling: Double = 0.0
    var epsilon: Double = 1.0e-12
    var potentialIntegrationSteps: Int = 4_000
}

// ============================================================
// MASS MODEL
// ============================================================

struct GaussianMassModel {
    let totalMass: Double
    let characteristicRadius: Double

    func density(r: Double) -> Double {
        let sigma = max(characteristicRadius, Double.leastNonzeroMagnitude)
        let normalization = totalMass / pow(2.0 * .pi, 1.5) / pow(sigma, 3.0)
        return normalization * exp(-r * r / (2.0 * sigma * sigma))
    }

    func enclosedMass(r: Double) -> Double {
        if r <= 0 { return 0 }
        let sigma = max(characteristicRadius, Double.leastNonzeroMagnitude)
        let x = r / (sqrt(2.0) * sigma)
        let fraction = erf(x) - sqrt(2.0 / .pi) * (r / sigma) * exp(-r * r / (2.0 * sigma * sigma))
        return clamped(totalMass * fraction, minimum: 0, maximum: totalMass)
    }
}

// ============================================================
// FIELD SAMPLES
// ============================================================

struct QRTLElectromagneticSample {
    let effectiveCurrent: SIMD3<Double>
    let electricEnergyDensity: Double
    let magneticEnergyDensity: Double
    let totalEnergyDensity: Double
}

struct QRTLFieldSample {
    let position: SIMD3<Double>
    let baryonicDensity: Double
    let qrtlCurrent: SIMD3<Double>
    let qrtlEnergyDensity: Double
    let effectiveGravitatingDensity: Double
    let gravitationalPotential: Double
    let gravitationalAcceleration: SIMD3<Double>
    let electromagnetic: QRTLElectromagneticSample
}

// ============================================================
// QRTL FIELD
// ============================================================

final class QRTLField {
    let massModel: GaussianMassModel
    let parameters: QRTLParameters

    init(massModel: GaussianMassModel, parameters: QRTLParameters) {
        self.massModel = massModel
        self.parameters = parameters
    }

    func density(at position: SIMD3<Double>) -> Double {
        massModel.density(r: simd_length(position))
    }

    func qrtlSource(at position: SIMD3<Double>) -> Double {
        parameters.alphaQ * density(at: position)
    }

    func qrtlCurrent(at position: SIMD3<Double>) -> SIMD3<Double> {
        let r = simd_length(position)
        if r <= parameters.epsilon { return .zero }
        let enclosed = massModel.enclosedMass(r: r)
        let attenuation = exp(-parameters.interactionRate * r / max(parameters.qrtlVelocity, parameters.epsilon))
        let magnitude = parameters.alphaQ * enclosed / (4.0 * .pi * r * r) * attenuation
        return (position / r) * magnitude
    }

    func qrtlEnergyDensity(at position: SIMD3<Double>) -> Double {
        let current = qrtlCurrent(at: position)
        let j2 = simd_dot(current, current)
        return j2 / (2.0 * max(parameters.chiQ, parameters.epsilon))
    }

    func effectiveGravitatingDensity(at position: SIMD3<Double>) -> Double {
        let rhoB = density(at: position)
        let uQ = qrtlEnergyDensity(at: position)
        return rhoB + parameters.etaQ * uQ / (PhysicalConstants.c * PhysicalConstants.c)
    }

    func enclosedEffectiveMass(r: Double) -> Double {
        if r <= 0 { return 0 }
        let steps = max(parameters.potentialIntegrationSteps, 100)
        let dr = r / Double(steps)
        var mass = 0.0
        for i in 0..<steps {
            let radius = (Double(i) + 0.5) * dr
            let pos = SIMD3<Double>(radius, 0, 0)
            let dens = effectiveGravitatingDensity(at: pos)
            mass += dens * 4.0 * .pi * radius * radius * dr
        }
        return mass
    }

    func gravitationalPotential(at position: SIMD3<Double>) -> Double {
        let r = simd_length(position)
        let sigma = massModel.characteristicRadius
        let outer = max(20.0 * sigma, 4.0 * r, sigma)
        let safeR = max(r, parameters.epsilon)
        let enclosed = enclosedEffectiveMass(r: safeR)
        let steps = max(parameters.potentialIntegrationSteps, 100)
        let dr = (outer - safeR) / Double(steps)
        var exterior = 0.0
        if dr > 0 {
            for i in 0..<steps {
                let radius = safeR + (Double(i) + 0.5) * dr
                let dens = effectiveGravitatingDensity(at: SIMD3(radius, 0, 0))
                exterior += dens * radius * dr
            }
        }
        return -PhysicalConstants.G * (enclosed / safeR + 4.0 * .pi * exterior)
    }

    func gravitationalAcceleration(at position: SIMD3<Double>) -> SIMD3<Double> {
        let r = simd_length(position)
        if r <= parameters.epsilon { return .zero }
        let enclosed = enclosedEffectiveMass(r: r)
        let mag = -PhysicalConstants.G * enclosed / (r * r)
        return (position / r) * mag
    }

    func electromagneticField(at position: SIMD3<Double>) -> QRTLElectromagneticSample {
        let r = max(simd_length(position), parameters.epsilon)
        let jq = qrtlCurrent(at: position)
        let jeff = parameters.electromagneticCoupling * jq
        let j2 = simd_dot(jeff, jeff)
        let geo = 32.0 * .pi * .pi * r * r
        let eScale = parameters.electricFieldCoupling * parameters.electricFieldCoupling
        let mScale = parameters.magneticFieldCoupling * parameters.magneticFieldCoupling
        let uE = eScale * j2 / (geo * PhysicalConstants.epsilon0)
        let uB = mScale * PhysicalConstants.mu0 * j2 / geo
        return QRTLElectromagneticSample(
            effectiveCurrent: jeff,
            electricEnergyDensity: uE,
            magneticEnergyDensity: uB,
            totalEnergyDensity: uE + uB
        )
    }

    func sample(at position: SIMD3<Double>) -> QRTLFieldSample {
        let em = electromagneticField(at: position)
        return QRTLFieldSample(
            position: position,
            baryonicDensity: density(at: position),
            qrtlCurrent: qrtlCurrent(at: position),
            qrtlEnergyDensity: qrtlEnergyDensity(at: position),
            effectiveGravitatingDensity: effectiveGravitatingDensity(at: position),
            gravitationalPotential: gravitationalPotential(at: position),
            gravitationalAcceleration: gravitationalAcceleration(at: position),
            electromagnetic: em
        )
    }
}

// ============================================================
// PHOTON RAY TRACER
// ============================================================

final class QRTLPhotonTracer {
    let field: QRTLField

    init(field: QRTLField) {
        self.field = field
    }

    func gravitationalIndex(at position: SIMD3<Double>) -> Double {
        let phi = field.gravitationalPotential(at: position)
        return 1.0 - (1.0 + field.parameters.gammaQ) * phi / (PhysicalConstants.c * PhysicalConstants.c)
    }

    func electromagneticIndex(at position: SIMD3<Double>) -> Double {
        let energy = field.electromagneticField(at: position).totalEnergyDensity
        return 1.0 + field.parameters.photonEMCoupling * energy
    }

    func totalIndex(at position: SIMD3<Double>) -> Double {
        gravitationalIndex(at: position) * electromagneticIndex(at: position)
    }

    func totalIndexGradient(at position: SIMD3<Double>) -> SIMD3<Double> {
        let r = max(simd_length(position), 1.0)
        let step = max(0.0005 * r, 1.0)
        let dx = SIMD3(step, 0, 0)
        let dy = SIMD3(0, step, 0)
        let dz = SIMD3(0, 0, step)
        let xp = totalIndex(at: position + dx)
        let xm = totalIndex(at: position - dx)
        let yp = totalIndex(at: position + dy)
        let ym = totalIndex(at: position - dy)
        let zp = totalIndex(at: position + dz)
        let zm = totalIndex(at: position - dz)
        return SIMD3(
            (xp - xm) / (2 * step),
            (yp - ym) / (2 * step),
            (zp - zm) / (2 * step)
        )
    }

    func trace(start: SIMD3<Double>,
               direction: SIMD3<Double>,
               totalDistance: Double,
               stepSize: Double) -> [SIMD3<Double>] {
        precondition(stepSize > 0 && totalDistance > 0)
        var pos = start
        var dir = simd_normalize(direction)
        var path: [SIMD3<Double>] = [pos]
        let nSteps = max(1, Int(totalDistance / stepSize))
        for _ in 0..<nSteps {
            let n = max(totalIndex(at: pos), 1e-30)
            let grad = totalIndexGradient(at: pos)
            let prop = grad / n
            let trans = transverseComponent(prop, relativeTo: dir)
            dir = simd_normalize(dir + trans * stepSize)
            pos += dir * stepSize
            path.append(pos)
        }
        return path
    }
}

// ============================================================
// DIAGNOSTICS
// ============================================================

struct LensingComparison {
    static func GRDeflection(mass: Double, impactParameter: Double) -> Double {
        4.0 * PhysicalConstants.G * mass / (impactParameter * PhysicalConstants.c * PhysicalConstants.c)
    }
    static func arcseconds(radians: Double) -> Double {
        radians * PhysicalConstants.radiansToArcseconds
    }
    static func angleBetween(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        let c = clamped(simd_dot(simd_normalize(a), simd_normalize(b)), minimum: -1, maximum: 1)
        return acos(c)
    }
}

struct QRTLExperimentResult {
    let qrtlDeflection: Double
    let grDeflection: Double
    let differencePercent: Double
    let qrtlDeflectionArcseconds: Double
    let grDeflectionArcseconds: Double
}

// ============================================================
// EXPERIMENT
// ============================================================

final class QRTLExperiment {
    let field: QRTLField
    let tracer: QRTLPhotonTracer

    init(mass: Double, radius: Double, parameters: QRTLParameters) {
        let model = GaussianMassModel(totalMass: mass, characteristicRadius: radius)
        self.field = QRTLField(massModel: model, parameters: parameters)
        self.tracer = QRTLPhotonTracer(field: field)
    }

    func run(impactParameter: Double,
             startDistance: Double,
             endDistance: Double,
             stepSize: Double) -> QRTLExperimentResult {
        let start = SIMD3(-startDistance, impactParameter, 0)
        let dir = SIMD3(1.0, 0.0, 0.0)
        let path = tracer.trace(start: start, direction: dir,
                                totalDistance: startDistance + endDistance,
                                stepSize: stepSize)
        guard path.count >= 3 else {
            return QRTLExperimentResult(qrtlDeflection: 0, grDeflection: 0, differencePercent: 0,
                                        qrtlDeflectionArcseconds: 0, grDeflectionArcseconds: 0)
        }
        let incoming = simd_normalize(path[1] - path[0])
        let outgoing = simd_normalize(path[path.count-1] - path[path.count-2])
        let qrtlAngle = LensingComparison.angleBetween(incoming, outgoing)
        let grAngle = LensingComparison.GRDeflection(mass: field.massModel.totalMass,
                                                     impactParameter: impactParameter)
        let diff = grAngle > 0 ? 100 * (qrtlAngle - grAngle) / grAngle : 0
        return QRTLExperimentResult(
            qrtlDeflection: qrtlAngle,
            grDeflection: grAngle,
            differencePercent: diff,
            qrtlDeflectionArcseconds: LensingComparison.arcseconds(radians: qrtlAngle),
            grDeflectionArcseconds: LensingComparison.arcseconds(radians: grAngle)
        )
    }
}

// ============================================================
// 3-D SCENE CONTROLLER
// ============================================================

final class LensingSceneController: ObservableObject {
    let scene = SCNScene()
    private var pathNodes: [SCNNode] = []
    private var massNode: SCNNode?
    private var planeNode: SCNNode?

    init() {
        setupCameraLights()
        addAxes()
    }

    private func setupCameraLights() {
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.zFar = 2e6
        cam.position = SCNVector3(0, 25_000, 60_000)
        cam.look(at: SCNVector3(0, 0, 0))
        scene.rootNode.addChildNode(cam)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 500
        scene.rootNode.addChildNode(ambient)

        let dir = SCNNode()
        dir.light = SCNLight()
        dir.light?.type = .directional
        dir.light?.intensity = 900
        dir.eulerAngles = SCNVector3(-Double.pi/4, Double.pi/4, 0)
        scene.rootNode.addChildNode(dir)
    }

    private func addAxes() {
        let len: Float = 20_000
        for (v, col) in [
            (SCNVector3(len, 0, 0), UIColor.red),
            (SCNVector3(0, len, 0), UIColor.green),
            (SCNVector3(0, 0, len), UIColor.blue)
        ] {
            let geo = SCNCylinder(radius: 30, height: CGFloat(len))
            let mat = SCNMaterial()
            mat.diffuse.contents = col
            geo.materials = [mat]
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(v.x/2, v.y/2, v.z/2)
            if v.x != 0 { node.eulerAngles.z = .pi/2 }
            if v.z != 0 { node.eulerAngles.x = .pi/2 }
            scene.rootNode.addChildNode(node)
        }
    }

    func clearPaths() {
        pathNodes.forEach { $0.removeFromParentNode() }
        pathNodes.removeAll()
        massNode?.removeFromParentNode()
        planeNode?.removeFromParentNode()
    }

    func addCentralMass(radius: Double) {
        let r = Float(max(radius * 0.8, 200))
        let sphere = SCNSphere(radius: CGFloat(r))
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.orange
        mat.emission.contents = UIColor.orange.withAlphaComponent(0.6)
        sphere.materials = [mat]
        let node = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(node)
        massNode = node
    }

    func addObservationPlane(atX x: Double, size: Double) {
        let plane = SCNPlane(width: CGFloat(size), height: CGFloat(size))
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.cyan.withAlphaComponent(0.15)
        mat.isDoubleSided = true
        plane.materials = [mat]
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(Float(x), 0, 0)
        node.eulerAngles.y = .pi / 2
        scene.rootNode.addChildNode(node)
        planeNode = node
    }

    func addPhotonPath(_ points: [SIMD3<Double>], color: UIColor, lineWidth: CGFloat = 2) {
        guard points.count > 1 else { return }
        var vertices: [SCNVector3] = points.map {
            SCNVector3(Float($0.x), Float($0.y), Float($0.z))
        }
        let source = SCNGeometrySource(vertices: vertices)
        var indices: [Int32] = []
        for i in 0..<vertices.count-1 {
            indices.append(Int32(i))
            indices.append(Int32(i+1))
        }
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geo = SCNGeometry(sources: [source], elements: [element])
        let mat = SCNMaterial()
        mat.diffuse.contents = color
        mat.emission.contents = color
        mat.lightingModel = .constant
        geo.materials = [mat]
        let node = SCNNode(geometry: geo)
        scene.rootNode.addChildNode(node)
        pathNodes.append(node)
    }

    /// Generate a fan of parallel rays representing photons from a distant source galaxy
    func generateSourceGalaxyRays(
        experiment: QRTLExperiment,
        impactParams: [Double],          // list of impact parameters (y)
        startDist: Double,
        endDist: Double,
        step: Double,
        color: UIColor
    ) {
        for b in impactParams {
            let start = SIMD3(-startDist, b, 0)
            let dir = SIMD3(1.0, 0.0, 0.0)
            let path = experiment.tracer.trace(
                start: start,
                direction: dir,
                totalDistance: startDist + endDist,
                stepSize: step
            )
            addPhotonPath(path, color: color)
        }
    }
}

// ============================================================
// SWIFTUI 3-D VIEW
// ============================================================

struct LensingSceneView: UIViewRepresentable {
    @ObservedObject var controller: LensingSceneController

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = controller.scene
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = UIColor.black
        view.antialiasingMode = .multisampling4X
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {}
}

// ============================================================
// MAIN CONTENT VIEW
// ============================================================

struct ContentView: View {
    // Source
    @State private var massSolar: Double = 1.0
    @State private var radiusSolar: Double = 1.0
    @State private var impactSolar: Double = 100.0

    // QRTL parameters (start pure GR)
    @State private var alphaQ: Double = 0.0
    @State private var etaQ: Double = 0.0
    @State private var gammaQ: Double = 1.0
    @State private var electromagneticCoupling: Double = 0.0
    @State private var photonEMCoupling: Double = 0.0
    @State private var chiQ: Double = 1.0
    @State private var interactionRate: Double = 0.0

    // Results & UI state
    @State private var result: QRTLExperimentResult?
    @State private var isRunning = false
    @State private var statusMessage = "Ready – pure GR baseline"
    @State private var show3D = false

    @StateObject private var sceneController = LensingSceneController()

    var body: some View {
        NavigationStack {
            Form {
                Section("Source") {
                    numericField("Mass (M☉)", value: $massSolar)
                    numericField("Radius (R☉)", value: $radiusSolar)
                    numericField("Impact b (R☉)", value: $impactSolar)
                }

                Section("QRTL Parameters") {
                    slider("α_Q", value: $alphaQ, range: 0...1e-5)
                    slider("η_Q", value: $etaQ, range: 0...10)
                    slider("γ_Q", value: $gammaQ, range: 0.5...1.5)
                    slider("χ_Q", value: $chiQ, range: 0.1...10)
                    slider("Γ_Q", value: $interactionRate, range: 0...1e-6)
                }

                Section("QRTL → EM → Photon") {
                    slider("g_QE", value: $electromagneticCoupling, range: 0...1e-10)
                    slider("κ_EM", value: $photonEMCoupling, range: 0...1e-20)
                }

                Section {
                    Button {
                        runExperiment(with3D: false)
                    } label: {
                        Label(isRunning ? "Running…" : "Run Numerical Experiment",
                              systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isRunning)
                    .buttonStyle(.borderedProminent)

                    Button {
                        runExperiment(with3D: true)
                    } label: {
                        Label("Run + Show 3D Photon Paths", systemImage: "cube.transparent")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isRunning)

                    Button("Reset to pure GR") { resetToGR() }
                        .disabled(isRunning)
                }

                if let r = result {
                    Section("Results") {
                        resultRow("QRTL α", r.qrtlDeflection, "rad")
                        resultRow("QRTL α", r.qrtlDeflectionArcseconds, "arcsec")
                        resultRow("GR α", r.grDeflection, "rad")
                        resultRow("GR α", r.grDeflectionArcseconds, "arcsec")
                        resultRow("Difference", r.differencePercent, "%")
                    }
                }

                Section("Status") {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("QRTL Lensing")
            .sheet(isPresented: $show3D) {
                NavigationStack {
                    LensingSceneView(controller: sceneController)
                        .ignoresSafeArea()
                        .navigationTitle("Source Galaxy Photons → Projected Plane")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { show3D = false }
                            }
                        }
                }
            }
        }
    }

    // MARK: - UI Helpers

    private func numericField(_ title: String, value: Binding<Double>) -> some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.3e", value.wrappedValue))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }

    private func resultRow(_ title: String, _ value: Double, _ unit: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(String(format: "%.6e %@", value, unit))
                .font(.body.monospacedDigit())
        }
    }

    private func resetToGR() {
        alphaQ = 0; etaQ = 0; gammaQ = 1
        electromagneticCoupling = 0; photonEMCoupling = 0
        chiQ = 1; interactionRate = 0
        result = nil
        statusMessage = "Reset to pure GR (α=η=g=κ=0, γ=1)"
    }

    private func runExperiment(with3D: Bool) {
        isRunning = true
        statusMessage = "Integrating photon trajectories…"
        result = nil
        sceneController.clearPaths()

        let mass = massSolar * PhysicalConstants.solarMass
        let radius = radiusSolar * PhysicalConstants.solarRadius
        let impact = impactSolar * PhysicalConstants.solarRadius

        var params = QRTLParameters()
        params.alphaQ = alphaQ
        params.etaQ = etaQ
        params.gammaQ = gammaQ
        params.chiQ = chiQ
        params.interactionRate = interactionRate
        params.electromagneticCoupling = electromagneticCoupling
        params.photonEMCoupling = photonEMCoupling

        DispatchQueue.global(qos: .userInitiated).async {
            let experiment = QRTLExperiment(mass: mass, radius: radius, parameters: params)

            // Single-ray numerical result
            let outcome = experiment.run(
                impactParameter: impact,
                startDistance: 5_000 * PhysicalConstants.solarRadius,
                endDistance: 5_000 * PhysicalConstants.solarRadius,
                stepSize: 0.05 * PhysicalConstants.solarRadius
            )

            // 3-D multi-ray visualization (source galaxy plane)
            if with3D {
                let startD = 4_000.0 * PhysicalConstants.solarRadius
                let endD   = 4_000.0 * PhysicalConstants.solarRadius
                let step   = 0.08 * PhysicalConstants.solarRadius

                // Impact parameters covering a “source galaxy” plane
                let impacts: [Double] = stride(from: -180.0, through: 180.0, by: 30.0)
                    .map { $0 * PhysicalConstants.solarRadius }

                DispatchQueue.main.async {
                    self.sceneController.addCentralMass(radius: radius)
                    self.sceneController.addObservationPlane(
                        atX: endD * 0.85,
                        size: 500 * PhysicalConstants.solarRadius
                    )
                    self.sceneController.generateSourceGalaxyRays(
                        experiment: experiment,
                        impactParams: impacts,
                        startDist: startD,
                        endDist: endD,
                        step: step,
                        color: .cyan
                    )
                }
            }

            DispatchQueue.main.async {
                self.result = outcome
                self.isRunning = false
                if with3D { self.show3D = true }

                if abs(outcome.differencePercent) < 0.8 &&
                    params.alphaQ == 0 && params.etaQ == 0 &&
                    params.electromagneticCoupling == 0 &&
                    params.photonEMCoupling == 0 {
                    self.statusMessage = "Pure GR baseline recovered"
                } else {
                    self.statusMessage = "QRTL / EM contributions active"
                }
            }
        }
    }
}

