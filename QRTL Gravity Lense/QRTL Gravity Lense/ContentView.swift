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
    var potentialIntegrationSteps: Int = 2_500
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

    func qrtlCurrent(at position: SIMD3<Double>) -> SIMD3<Double> {
        let r = simd_length(position)
        if r <= parameters.epsilon { return .zero }
        let enclosed = massModel.enclosedMass(r: r)
        let attenuation = exp(-parameters.interactionRate * r / max(parameters.qrtlVelocity, parameters.epsilon))
        let magnitude = parameters.alphaQ * enclosed / (4.0 * .pi * r * r) * attenuation
        return (position / r) * magnitude
    }

    func qrtlEnergyDensity(at position: SIMD3<Double>) -> Double {
        let j = qrtlCurrent(at: position)
        return simd_dot(j, j) / (2.0 * max(parameters.chiQ, parameters.epsilon))
    }

    func effectiveGravitatingDensity(at position: SIMD3<Double>) -> Double {
        let rhoB = density(at: position)
        let uQ = qrtlEnergyDensity(at: position)
        return rhoB + parameters.etaQ * uQ / (PhysicalConstants.c * PhysicalConstants.c)
    }

    func enclosedEffectiveMass(r: Double) -> Double {
        if r <= 0 { return 0 }
        let steps = max(parameters.potentialIntegrationSteps, 60)
        let dr = r / Double(steps)
        var mass = 0.0
        for i in 0..<steps {
            let radius = (Double(i) + 0.5) * dr
            let dens = effectiveGravitatingDensity(at: SIMD3(radius, 0, 0))
            mass += dens * 4.0 * .pi * radius * radius * dr
        }
        return mass
    }

    func gravitationalPotential(at position: SIMD3<Double>) -> Double {
        let r = simd_length(position)
        let sigma = massModel.characteristicRadius
        let outer = max(12.0 * sigma, 2.5 * r, sigma)
        let safeR = max(r, parameters.epsilon)
        let enclosed = enclosedEffectiveMass(r: safeR)
        let steps = max(parameters.potentialIntegrationSteps, 60)
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

    func electromagneticField(at position: SIMD3<Double>) -> (energy: Double, currentMag: Double) {
        let r = max(simd_length(position), parameters.epsilon)
        let jq = qrtlCurrent(at: position)
        let jeff = parameters.electromagneticCoupling * jq
        let j2 = simd_dot(jeff, jeff)
        let geo = 32.0 * .pi * .pi * r * r
        let eScale = parameters.electricFieldCoupling * parameters.electricFieldCoupling
        let mScale = parameters.magneticFieldCoupling * parameters.magneticFieldCoupling
        let uE = eScale * j2 / (geo * PhysicalConstants.epsilon0)
        let uB = mScale * PhysicalConstants.mu0 * j2 / geo
        return (uE + uB, sqrt(simd_dot(jq, jq)))
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
        let (energy, _) = field.electromagneticField(at: position)
        return 1.0 + field.parameters.photonEMCoupling * energy
    }

    func totalIndex(at position: SIMD3<Double>) -> Double {
        gravitationalIndex(at: position) * electromagneticIndex(at: position)
    }

    func totalIndexGradient(at position: SIMD3<Double>) -> SIMD3<Double> {
        let r = max(simd_length(position), 1.0)
        let step = max(0.001 * r, 3.0)
        let dx = SIMD3(step, 0, 0)
        let dy = SIMD3(0, step, 0)
        let dz = SIMD3(0, 0, step)
        let xp = totalIndex(at: position + dx)
        let xm = totalIndex(at: position - dx)
        let yp = totalIndex(at: position + dy)
        let ym = totalIndex(at: position - dy)
        let zp = totalIndex(at: position + dz)
        let zm = totalIndex(at: position - dz)
        return SIMD3((xp-xm)/(2*step), (yp-ym)/(2*step), (zp-zm)/(2*step))
    }

    func trace(start: SIMD3<Double>, direction: SIMD3<Double>,
               totalDistance: Double, stepSize: Double) -> [SIMD3<Double>] {
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
// EXPERIMENT
// ============================================================

struct QRTLExperimentResult {
    let qrtlDeflection: Double
    let grDeflection: Double
    let differencePercent: Double
    let qrtlDeflectionArcseconds: Double
    let grDeflectionArcseconds: Double
}

final class QRTLExperiment {
    let field: QRTLField
    let tracer: QRTLPhotonTracer

    init(mass: Double, radius: Double, parameters: QRTLParameters) {
        let model = GaussianMassModel(totalMass: mass, characteristicRadius: radius)
        self.field = QRTLField(massModel: model, parameters: parameters)
        self.tracer = QRTLPhotonTracer(field: field)
    }

    func run(impactParameter: Double, startDistance: Double,
             endDistance: Double, stepSize: Double) -> QRTLExperimentResult {
        let start = SIMD3(-startDistance, impactParameter, 0)
        let path = tracer.trace(start: start, direction: SIMD3(1,0,0),
                                totalDistance: startDistance + endDistance, stepSize: stepSize)
        guard path.count >= 3 else {
            return QRTLExperimentResult(qrtlDeflection: 0, grDeflection: 0, differencePercent: 0,
                                        qrtlDeflectionArcseconds: 0, grDeflectionArcseconds: 0)
        }
        let incoming = simd_normalize(path[1] - path[0])
        let outgoing = simd_normalize(path[path.count-1] - path[path.count-2])
        let cos = clamped(simd_dot(incoming, outgoing), minimum: -1, maximum: 1)
        let qrtlAngle = acos(cos)
        let grAngle = 4.0 * PhysicalConstants.G * field.massModel.totalMass /
            (impactParameter * PhysicalConstants.c * PhysicalConstants.c)
        let diff = grAngle > 0 ? 100 * (qrtlAngle - grAngle) / grAngle : 0
        return QRTLExperimentResult(
            qrtlDeflection: qrtlAngle,
            grDeflection: grAngle,
            differencePercent: diff,
            qrtlDeflectionArcseconds: qrtlAngle * PhysicalConstants.radiansToArcseconds,
            grDeflectionArcseconds: grAngle * PhysicalConstants.radiansToArcseconds
        )
    }
}

// ============================================================
// HEATMAP (bottom plane)
// ============================================================

final class QRTLHeatmapGenerator {
    static func makeHeatmapImage(field: QRTLField, size: Int = 96, halfExtent: Double) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: size, height: size), true, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return UIImage() }

        var maxVal: Double = 1e-30
        var samples = [[Double]](repeating: [Double](repeating: 0, count: size), count: size)

        for j in 0..<size {
            for i in 0..<size {
                let x = -halfExtent + (Double(i)+0.5)*(2*halfExtent/Double(size))
                let z = -halfExtent + (Double(j)+0.5)*(2*halfExtent/Double(size))
                let pos = SIMD3(x, 0, z)
                let (em, jMag) = field.electromagneticField(at: pos)
                let val = jMag * 1e12 + em * 1e22
                samples[j][i] = val
                if val > maxVal { maxVal = val }
            }
        }

        for j in 0..<size {
            for i in 0..<size {
                let t = CGFloat(samples[j][i] / maxVal)
                let color: UIColor
                if t < 0.25 {
                    color = UIColor(red: 0, green: 0, blue: t*4, alpha: 1)
                } else if t < 0.5 {
                    color = UIColor(red: 0, green: (t-0.25)*4, blue: 1, alpha: 1)
                } else if t < 0.75 {
                    color = UIColor(red: (t-0.5)*4, green: 1, blue: 1-(t-0.5)*4, alpha: 1)
                } else {
                    color = UIColor(red: 1, green: 1, blue: max(0, 1-(t-0.75)*4), alpha: 1)
                }
                ctx.setFillColor(color.cgColor)
                ctx.fill(CGRect(x: i, y: size-1-j, width: 1, height: 1))
            }
        }
        let img = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return img
    }
}

// ============================================================
// PROJECTION ACCUMULATOR  ← the missing stage
// ============================================================

final class ProjectionAccumulator {
    let resolution: Int
    let halfExtent: Double          // physical size of the plane (same units as simulation)
    private var buffer: [[Float]]

    init(resolution: Int = 256, halfExtent: Double) {
        self.resolution = resolution
        self.halfExtent = halfExtent
        self.buffer = [[Float]](repeating: [Float](repeating: 0, count: resolution), count: resolution)
    }

    func reset() {
        for j in 0..<resolution {
            for i in 0..<resolution {
                buffer[j][i] = 0
            }
        }
    }

    /// Record a photon hit at physical (y,z) on the observation plane
    func addHit(y: Double, z: Double, weight: Float = 1.0) {
        let u = (y + halfExtent) / (2 * halfExtent)   // 0…1
        let v = (z + halfExtent) / (2 * halfExtent)
        let i = Int(u * Double(resolution - 1))
        let j = Int(v * Double(resolution - 1))
        guard i >= 0, i < resolution, j >= 0, j < resolution else { return }
        buffer[j][i] += weight
    }

    /// Convert the accumulator into a UIImage that can be used as a texture
    func makeImage() -> UIImage {
        var maxVal: Float = 1e-6
        for row in buffer {
            for v in row { if v > maxVal { maxVal = v } }
        }

        UIGraphicsBeginImageContextWithOptions(CGSize(width: resolution, height: resolution), false, 1)
        guard let ctx = UIGraphicsGetCurrentContext() else { return UIImage() }

        for j in 0..<resolution {
            for i in 0..<resolution {
                let t = CGFloat(buffer[j][i] / maxVal)
                // bright yellow-white galaxy light
                let alpha = min(1.0, t * 1.8)
                let color = UIColor(red: 1, green: 0.95, blue: 0.7, alpha: alpha)
                ctx.setFillColor(color.cgColor)
                ctx.fill(CGRect(x: i, y: resolution-1-j, width: 1, height: 1))
            }
        }
        let img = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return img
    }
}

// ============================================================
// 3-D SCENE CONTROLLER
// ============================================================

final class LensingSceneController: ObservableObject {
    let scene = SCNScene()
    private var pathNodes: [SCNNode] = []
    private var sourceGalaxyNodes: [SCNNode] = []
    private var massNode: SCNNode?
    private var frontPlaneNode: SCNNode?
    private var bottomPlaneNode: SCNNode?
    
  
    // ------------------------------------------------------------
    // 2. In LensingSceneController – replace the geometry constants
    // ------------------------------------------------------------
    let sourceX: Float       = -3200
    let frontPlaneX: Float   =  2600
    let bottomY: Float       = -1600
    let planeHalfExtent: Float = 1800
    let heatmapHalfExtent: Float = 2000
    let startDistance: Double = 3200          // now pure numbers
    let endDistance: Double   = 3200

    // Projection
    private let accumulator = ProjectionAccumulator(resolution: 192, halfExtent: 1800.0 * PhysicalConstants.solarRadius)

    init() {
        setupCameraLights()
        addAxes()
        addFrontProjectionPlane(empty: true)
        addBottomPlaceholder()
    }

    private func setupCameraLights() {
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.zNear = 1
        cam.camera?.zFar  = 20000          // large enough
        cam.position = SCNVector3(800, 1200, 3500)
        cam.look(at: SCNVector3(0, -200, 0))
        scene.rootNode.addChildNode(cam)
        // … lights stay the same
    }
    private func addAxes() {
        let len: Float = 1600
        for (v, col) in [
            (SCNVector3(len,0,0), UIColor.systemRed),
            (SCNVector3(0,len,0), UIColor.systemGreen),
            (SCNVector3(0,0,len), UIColor.systemBlue)
        ] {
            let geo = SCNCylinder(radius: 18, height: CGFloat(len))
            let mat = SCNMaterial(); mat.diffuse.contents = col
            geo.materials = [mat]
            let node = SCNNode(geometry: geo)
            node.position = SCNVector3(v.x/2, v.y/2, v.z/2)
            if v.x != 0 { node.eulerAngles.z = .pi/2 }
            if v.z != 0 { node.eulerAngles.x = .pi/2 }
            scene.rootNode.addChildNode(node)
        }
    }

    func clearDynamic() {
        pathNodes.forEach { $0.removeFromParentNode() }
        pathNodes.removeAll()
        sourceGalaxyNodes.forEach { $0.removeFromParentNode() }
        sourceGalaxyNodes.removeAll()
        massNode?.removeFromParentNode()
        massNode = nil
        bottomPlaneNode?.removeFromParentNode()
        bottomPlaneNode = nil
        accumulator.reset()
    }

    // MARK: - Source galaxy (real 2-D distribution)
    func addSourceGalaxy(radius: Double = 450 * PhysicalConstants.solarRadius, nStars: Int = 180) {
        sourceGalaxyNodes.forEach { $0.removeFromParentNode() }
        sourceGalaxyNodes.removeAll()

        // simple exponential-disk + spiral arms
        for _ in 0..<nStars {
            let r = radius * pow(Double.random(in: 0...1), 0.7)
            let theta = Double.random(in: 0...(2 * .pi))
            // weak spiral
            let arm = 0.6 * sin(2.5 * theta)
            let y = (r + arm * radius * 0.15) * cos(theta)
            let z = (r + arm * radius * 0.15) * sin(theta)

            let star = SCNSphere(radius: CGFloat.random(in: 12...28))
            let mat = SCNMaterial()
            mat.diffuse.contents = UIColor.yellow
            mat.emission.contents = UIColor.yellow.withAlphaComponent(0.9)
            mat.lightingModel = .constant
            star.materials = [mat]
            let node = SCNNode(geometry: star)
            node.position = SCNVector3(Float(sourceX), Float(y), Float(z))
            scene.rootNode.addChildNode(node)
            sourceGalaxyNodes.append(node)
        }
    }

    // MARK: - Front observation plane with projected image
    func addFrontProjectionPlane(empty: Bool) {
        frontPlaneNode?.removeFromParentNode()

        let size = planeHalfExtent * 2
        let plane = SCNPlane(width: CGFloat(size), height: CGFloat(size))
        let mat = SCNMaterial()
        if empty {
            mat.diffuse.contents = UIColor.cyan.withAlphaComponent(0.15)
            mat.emission.contents = UIColor.cyan.withAlphaComponent(0.05)
        } else {
            let img = accumulator.makeImage()
            mat.diffuse.contents = img
            mat.emission.contents = img
        }
        mat.isDoubleSided = true
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(Float(frontPlaneX), 0, 0)
        node.eulerAngles.y = .pi / 2
        scene.rootNode.addChildNode(node)
        frontPlaneNode = node
    }

    // MARK: - Bottom QRTL heatmap
    func addBottomPlaceholder() {
        let size = heatmapHalfExtent * 2
        let plane = SCNPlane(width: CGFloat(size), height: CGFloat(size))
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor(white: 0.07, alpha: 0.9)
        mat.isDoubleSided = true
        plane.materials = [mat]
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, Float(bottomY), 0)
        node.eulerAngles.x = -.pi / 2
        scene.rootNode.addChildNode(node)
        bottomPlaneNode = node
    }

    func updateBottomHeatmap(field: QRTLField) {
        bottomPlaneNode?.removeFromParentNode()
        
        let img = QRTLHeatmapGenerator.makeHeatmapImage(
            field: field,
            halfExtent: Double(heatmapHalfExtent)          // ← Fixed here
        )
        
        let size = heatmapHalfExtent * 2
        let plane = SCNPlane(width: CGFloat(size), height: CGFloat(size))
        
        let mat = SCNMaterial()
        mat.diffuse.contents = img
        mat.emission.contents = img
        mat.isDoubleSided = true
        plane.materials = [mat]
        
        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(0, Float(bottomY), 0)
        node.eulerAngles.x = -.pi / 2
        scene.rootNode.addChildNode(node)
        bottomPlaneNode = node
    }

    // MARK: - Globular cluster
    func addCluster(radius: Double) {
        massNode?.removeFromParentNode()
        let r = Float(max(radius * 1.1, 150))
        let sphere = SCNSphere(radius: CGFloat(r))
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.orange
        mat.emission.contents = UIColor.orange.withAlphaComponent(0.7)
        sphere.materials = [mat]
        let node = SCNNode(geometry: sphere)
        scene.rootNode.addChildNode(node)
        massNode = node
    }

    // MARK: - Photon path (optional visual aid)
    func addPhotonPath(_ points: [SIMD3<Double>]) {
        guard points.count > 1 else { return }
        let vertices = points.map { SCNVector3(Float($0.x), Float($0.y), Float($0.z)) }
        let source = SCNGeometrySource(vertices: vertices)
        var indices: [Int32] = []
        for i in 0..<vertices.count-1 {
            indices.append(Int32(i)); indices.append(Int32(i+1))
        }
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geo = SCNGeometry(sources: [source], elements: [element])
        let mat = SCNMaterial()
        mat.diffuse.contents = UIColor.cyan.withAlphaComponent(0.35)
        mat.emission.contents = UIColor.cyan.withAlphaComponent(0.35)
        mat.lightingModel = .constant
        geo.materials = [mat]
        let node = SCNNode(geometry: geo)
        scene.rootNode.addChildNode(node)
        pathNodes.append(node)
    }

    // MARK: - Core pipeline: source → rays → plane hits → image
    func runProjectionPipeline(experiment: QRTLExperiment,
                               sourceRadius: Double,
                               nRaysPerSide: Int,
                               step: Double,
                               showPaths: Bool = false) {
        accumulator.reset()

        let half = sourceRadius
        let dy = 2 * half / Double(nRaysPerSide - 1)

        for iy in 0..<nRaysPerSide {
            for iz in 0..<nRaysPerSide {
                let y = -half + Double(iy) * dy
                let z = -half + Double(iz) * dy
                
                // skip corners of the square to make a roughly circular galaxy
                if y*y + z*z > half*half * 1.05 { continue }

                // Explicit Double conversion – fixes the Scalar conflict
                let start = SIMD3<Double>(Double(sourceX), y, z)
                
                let path = experiment.tracer.trace(
                    start: start,
                    direction: SIMD3<Double>(1, 0, 0),
                    totalDistance: startDistance + endDistance,
                    stepSize: step
                )

                if showPaths && (iy % 4 == 0 && iz % 4 == 0) {
                    addPhotonPath(path)
                }

                // Find intersection with the observation plane (x = frontPlaneX)
                for k in 1..<path.count {
                    let p0 = path[k-1]
                    let p1 = path[k]
                    
                    if (p0.x - Double(frontPlaneX)) * (p1.x - Double(frontPlaneX)) <= 0 {
                        let t = (Double(frontPlaneX) - p0.x) / (p1.x - p0.x + 1e-30)
                        let yHit = p0.y + t * (p1.y - p0.y)
                        let zHit = p0.z + t * (p1.z - p0.z)
                        accumulator.addHit(y: yHit, z: zHit)
                        break
                    }
                }
            }
        }

        // Apply the accumulated image onto the observation plane
        addFrontProjectionPlane(empty: false)
    }
}

// ============================================================
// SWIFTUI SCENE VIEW
// ============================================================

struct LensingSceneView: UIViewRepresentable {
    @ObservedObject var controller: LensingSceneController
    func makeUIView(context: Context) -> SCNView {
        let v = SCNView()
        v.scene = controller.scene
        v.allowsCameraControl = true
        v.autoenablesDefaultLighting = false
        v.backgroundColor = .black
        v.antialiasingMode = .multisampling4X
        return v
    }
    func updateUIView(_ uiView: SCNView, context: Context) {}
}

// ============================================================
// HALF-SHEET CONTROLS
// ============================================================

struct ControlsSheet: View {
    @Binding var massSolar: Double
    @Binding var radiusSolar: Double
    @Binding var alphaQ: Double
    @Binding var etaQ: Double
    @Binding var gammaQ: Double
    @Binding var electromagneticCoupling: Double
    @Binding var photonEMCoupling: Double
    @Binding var chiQ: Double
    @Binding var interactionRate: Double
    @Binding var result: QRTLExperimentResult?
    @Binding var isRunning: Bool
    @Binding var statusMessage: String
    var onRun: () -> Void
    var onReset: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Globular Cluster (10⁶ M☉)") {
                    HStack {
                        Text("Mass (M☉)")
                        Spacer()
                        TextField("", value: $massSolar, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
                    }
                    HStack {
                        Text("Radius (R☉)")
                        Spacer()
                        TextField("", value: $radiusSolar, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 100)
                    }
                }
                Section("QRTL / Bolgarino") {
                    slider("α_Q", value: $alphaQ, range: 0...3e-5)
                    slider("η_Q", value: $etaQ, range: 0...20)
                    slider("γ_Q", value: $gammaQ, range: 0.5...1.5)
                    slider("χ_Q", value: $chiQ, range: 0.1...10)
                    slider("Γ_Q", value: $interactionRate, range: 0...3e-6)
                }
                Section("EM Coupling") {
                    slider("g_QE", value: $electromagneticCoupling, range: 0...1e-9)
                    slider("κ_EM", value: $photonEMCoupling, range: 0...1e-19)
                }
                Section {
                    Button(action: onRun) {
                        Label(isRunning ? "Running…" : "Run Full Projection Pipeline", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(isRunning)
                    .buttonStyle(.borderedProminent)
                    Button("Reset to pure GR", action: onReset).disabled(isRunning)
                }
                if let r = result {
                    Section("Deflection") {
                        Text("QRTL: \(String(format: "%.4e", r.qrtlDeflectionArcseconds)) arcsec")
                        Text("GR:   \(String(format: "%.4e", r.grDeflectionArcseconds)) arcsec")
                        Text("Δ:    \(String(format: "%.2f", r.differencePercent)) %")
                    }
                }
                Section("Status") {
                    Text(statusMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("QRTL Lensing")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func slider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.3e", value.wrappedValue))
                    .font(.caption.monospaced()).foregroundStyle(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
}

// ============================================================
// MAIN VIEW
// ============================================================

struct ContentView: View {
    @State private var massSolar: Double = 1_000_000
    @State private var radiusSolar: Double = 35
    @State private var alphaQ: Double = 5e-6
    @State private var etaQ: Double = 3.0
    @State private var gammaQ: Double = 1.0
    @State private var electromagneticCoupling: Double = 2e-11
    @State private var photonEMCoupling: Double = 5e-21
    @State private var chiQ: Double = 1.0
    @State private var interactionRate: Double = 0.0

    @State private var result: QRTLExperimentResult?
    @State private var isRunning = false
    @State private var statusMessage = "Ready – source galaxy → QRTL lens → projected images"
    @State private var showControls = false

    @StateObject private var scene = LensingSceneController()

    var body: some View {
        ZStack {
            LensingSceneView(controller: scene)
                .ignoresSafeArea()

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button { showControls = true } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(16)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding([.trailing, .bottom], 28)
                }
            }
        }
        .sheet(isPresented: $showControls) {
            ControlsSheet(
                massSolar: $massSolar,
                radiusSolar: $radiusSolar,
                alphaQ: $alphaQ,
                etaQ: $etaQ,
                gammaQ: $gammaQ,
                electromagneticCoupling: $electromagneticCoupling,
                photonEMCoupling: $photonEMCoupling,
                chiQ: $chiQ,
                interactionRate: $interactionRate,
                result: $result,
                isRunning: $isRunning,
                statusMessage: $statusMessage,
                onRun: runFullPipeline,
                onReset: reset
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            scene.addCluster(radius: radiusSolar * PhysicalConstants.solarRadius)
            scene.addSourceGalaxy()
        }
    }

    private func reset() {
        alphaQ = 0; etaQ = 0; gammaQ = 1
        electromagneticCoupling = 0; photonEMCoupling = 0
        chiQ = 1; interactionRate = 0
        result = nil
        statusMessage = "Reset to pure GR"
        scene.clearDynamic()
        scene.addCluster(radius: radiusSolar * PhysicalConstants.solarRadius)
        scene.addSourceGalaxy()
        scene.addFrontProjectionPlane(empty: true)
        scene.addBottomPlaceholder()
    }

    private func runFullPipeline() {
        isRunning = true
        statusMessage = "Tracing 2-D source galaxy through QRTL field…"
        result = nil
        scene.clearDynamic()

        let mass = massSolar * PhysicalConstants.solarMass
        let radius = radiusSolar * PhysicalConstants.solarRadius

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

            // Diagnostic single-ray deflection
            let outcome = experiment.run(
                impactParameter: 100 * PhysicalConstants.solarRadius,
                startDistance: scene.startDistance,
                endDistance: scene.endDistance,
                stepSize: 0.08 * PhysicalConstants.solarRadius
            )

            DispatchQueue.main.async {
                // 1. Source galaxy
                self.scene.addSourceGalaxy()

                // 2. Lens
                self.scene.addCluster(radius: radius)

                // 3. Bottom QRTL heatmap
                self.scene.updateBottomHeatmap(field: experiment.field)

                // 4. Full projection pipeline → two (or more) images on the front plane
                self.scene.runProjectionPipeline(
                    experiment: experiment,
                    sourceRadius: 480 * PhysicalConstants.solarRadius,
                    nRaysPerSide: 28,               // 28×28 ≈ 600 rays (circular mask)
                    step: 0.10 * PhysicalConstants.solarRadius,
                    showPaths: false                // set true if you want to see a few cyan trajectories
                )

                self.result = outcome
                self.isRunning = false
                self.statusMessage = "Projection complete – lensed galaxy images on front plane"
            }
        }
    }
}

