// QRTLGravitySurfaceView.swift
// Visualizes a 3D curvilinear NURBS-like surface modeling space curvature from QRTL field gravity density.
// Also displays two photon paths (A & B) perturbed by the density.

import SwiftUI
import SceneKit
import simd


struct QRTLGravitySurfaceView: View {
    let field: QRTLField
    let gridSize: Int
    let extent: Float
    
    @State private var galaxyAProjections: [SCNNode] = []
    @State private var galaxyBProjections: [SCNNode] = []

    var body: some View {
        ZStack {
            Image(uiImage: QRTLHeatmapGenerator.makeHeatmapImage(field: field, size: 512, halfExtent: Double(extent)))
                .resizable()
                .aspectRatio(1, contentMode: .fit)
                .ignoresSafeArea()
            SceneView(
                scene: makeScene(),
                pointOfView: defaultCameraNode(),
                options: [.autoenablesDefaultLighting, .allowsCameraControl]
            )
            .ignoresSafeArea()
            .onAppear {
                // Compute and add galaxy projections on first appearance
                computeGalaxyProjections()
            }
        }
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        let surfaceNode = makeSurfaceNode()
        scene.rootNode.addChildNode(surfaceNode)
        let photonANode = makePhotonPathNode(seed: 123, color: .cyan)
        let photonBNode = makePhotonPathNode(seed: 456, color: .magenta)
        scene.rootNode.addChildNode(photonANode)
        scene.rootNode.addChildNode(photonBNode)
        for node in galaxyAProjections { scene.rootNode.addChildNode(node) }
        for node in galaxyBProjections { scene.rootNode.addChildNode(node) }
        return scene
    }
    
    private func defaultCameraNode() -> SCNNode {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, extent * 0.7, extent * 2.3)
        cameraNode.eulerAngles = SCNVector3(-0.38, 0, 0)
        return cameraNode
    }

    // Generates a mesh to represent the 'curved sheet' surface
    private func makeSurfaceNode() -> SCNNode {
        let node = SCNNode()
        let geometry = makeSurfaceGeometry()
        node.geometry = geometry
        node.geometry?.firstMaterial?.diffuse.contents = UIColor.systemTeal.withAlphaComponent(0.76)
        node.geometry?.firstMaterial?.specular.contents = UIColor.white
        node.geometry?.firstMaterial?.isDoubleSided = true
        return node
    }
    
    // Build a grid mesh, pulling y up according to normalized QRTL density and Borlgrino flow for curvature visualization
    private func makeSurfaceGeometry() -> SCNGeometry {
        let n = gridSize
        let size = extent
        var positions: [SCNVector3] = []
        var indices: [Int32] = []
        let start = -size
        let step = (2 * size) / Float(n-1)
        for j in 0..<n {
            for i in 0..<n {
                let x = start + Float(i) * step
                let z = start + Float(j) * step
                let base = SIMD3<Float>(x, 0, z)
                // --- CORE LOGIC FOR SPACETIME CURVATURE ---
                let density = field.normalizedDensity(at: base)
                let flow = field.bolgarinoFlux(at: base)
                let flowMag = simd_length(flow)
                let flowNorm = flowMag.isFinite && flowMag > 0 ? min(flowMag / (flowMag + 1), 1.0) : 0.0
                // Curvature = weighted sum (you can fine-tune weights as desired):
                let curvature = 0.65 * density + 0.35 * Float(flowNorm)
                // Height is now driven by both local mass density (gravity) and Borlgrino flow (QRTL dynamics):
                let y = curvature.isFinite ? curvature * 1.0 : 0 // Adjust scale for desired visual effect
                // ---
                positions.append(SCNVector3(x, y, z))
            }
        }
        for j in 0..<(n-1) {
            for i in 0..<(n-1) {
                let idx = Int32(j * n + i)
                indices.append(contentsOf: [
                    idx,
                    idx + 1,
                    idx + Int32(n),
                    idx + 1,
                    idx + 1 + Int32(n),
                    idx + Int32(n)
                ])
            }
        }
        let posSource = SCNGeometrySource(vertices: positions)
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        return SCNGeometry(sources: [posSource], elements: [element])
    }
    
    // Simulate a photon path (seeded randomness to create two distinct paths)
    private func makePhotonPathNode(seed: Int, color: UIColor) -> SCNNode {
        var path: [SCNVector3] = []
        let nSteps = gridSize * 2
        var rng = SeededRandomNumberGenerator(seed: UInt64(seed))
        
        // Start at far left, mid height, random z
        let x0 = -extent
        let y0: Float = 0.0
        let z0 = Float.random(in: -extent...extent, using: &rng)
        var pos = SIMD3<Float>(x0, y0, z0)
        var direction = SIMD3<Float>(1, 0, Float.random(in: -0.18...0.18, using: &rng))
        direction = simd_normalize(direction)
        
        for _ in 0..<nSteps {
            let base = SIMD3<Float>(pos.x, 0, pos.z)
            let lensing = field.qrtlLensingStrength(at: base, direction: direction)
            let curvature = lensing.isFinite ? lensing : 0
            // Deflect direction up (y) and sideways (z) proportionally to density
            let deflectY: Float = curvature * 0.32
            let deflectZ: Float = curvature * (Float.random(in: -0.09...0.09, using: &rng))
            direction += SIMD3<Float>(0, deflectY, deflectZ)
            direction = simd_normalize(direction)
            pos += direction * (extent * 2 / Float(nSteps))
            path.append(SCNVector3(pos.x, pos.y, pos.z))
        }
        let pathNode = SCNNode()
        let pathGeometry = SCNGeometry.line(from: path, color: color)
        pathNode.geometry = pathGeometry
        return pathNode
    }
    
    // --- Replace galaxy projection and photon tracing with QRTLPhotonTracer-based logic ---
    private func computeGalaxyProjections() {
        let nStars = 80
        let galaxyAcenter = SIMD3<Float>(-extent, 0.7, -0.7)
        let galaxyBcenter = SIMD3<Float>(-extent, -0.7, 0.7)
        let galaxyRadius = 0.25 * extent
        let tracer = QRTLPhotonTracer(field: field)
        var galaxyA: [SCNNode] = []
        var galaxyB: [SCNNode] = []
        for i in 0..<nStars {
            // Source for A
            let angleA = 2 * .pi * Float(i) / Float(nStars)
            let posA = galaxyAcenter + galaxyRadius * SIMD3<Float>(cos(angleA), sin(angleA), 0)
            let pathA = tracer.trace(start: SIMD3<Double>(Double(posA.x), Double(posA.y), Double(posA.z)), direction: SIMD3<Double>(1,0,0), totalDistance: Double(2*extent), stepSize: 2.0*Double(extent)/250)
            if let endA = pathA.last, Float(endA.x) >= extent {
                let node = SCNNode(geometry: SCNSphere(radius: 0.027 * Double(extent) / Double(gridSize)))
                node.position = SCNVector3(Float(endA.x), Float(endA.y), Float(endA.z))
                node.geometry?.firstMaterial?.diffuse.contents = UIColor.cyan
                galaxyA.append(node)
            }
            // Source for B
            let angleB = 2 * .pi * Float(i) / Float(nStars)
            let posB = galaxyBcenter + galaxyRadius * SIMD3<Float>(sin(angleB), cos(angleB), 0)
            let pathB = tracer.trace(start: SIMD3<Double>(Double(posB.x), Double(posB.y), Double(posB.z)), direction: SIMD3<Double>(1,0,0), totalDistance: Double(2*extent), stepSize: 2.0*Double(extent)/250)
            if let endB = pathB.last, Float(endB.x) >= extent {
                let node = SCNNode(geometry: SCNSphere(radius: 0.027 * Double(extent) / Double(gridSize)))
                node.position = SCNVector3(Float(endB.x), Float(endB.y), Float(endB.z))
                node.geometry?.firstMaterial?.diffuse.contents = UIColor.magenta
                galaxyB.append(node)
            }
        }
        galaxyAProjections = galaxyA
        galaxyBProjections = galaxyB
    }
    // --- End of edit ---
}

// Helper to make a colored line from points for SceneKit
extension SCNGeometry {
    static func line(from points: [SCNVector3], color: UIColor) -> SCNGeometry {
        guard points.count > 1 else {
            return SCNGeometry()
        }
        var vertices = points
        var indices: [Int32] = []
        for i in 0..<(points.count-1) {
            indices.append(Int32(i))
            indices.append(Int32(i+1))
        }
        let source = SCNGeometrySource(vertices: vertices)
        let element = SCNGeometryElement(indices: indices, primitiveType: .line)
        let geometry = SCNGeometry(sources: [source], elements: [element])
        let material = SCNMaterial()
        material.diffuse.contents = color
        material.isDoubleSided = true
        geometry.materials = [material]
        return geometry
    }
}

// Seeded RNG to get repeatable photon paths
struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var rng: UInt64
    init(seed: UInt64) { rng = seed }
    mutating func next() -> UInt64 {
        rng ^= rng >> 12; rng ^= rng << 25; rng ^= rng >> 27
        return rng &* 2685821657736338717
    }
}

// Usage Example (in a parent SwiftUI View):
// QRTLGravitySurfaceView(field: myQRTLField, gridSize: 32, extent: 2.0)
