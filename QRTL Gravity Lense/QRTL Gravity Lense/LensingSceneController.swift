//
//  File.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/17/26.
//

import Foundation
import SwiftUI
import SceneKit
import Combine

final class LensingSceneController:
    ObservableObject {
    
    @Published private(set) var isRunning:
        Bool = false

    @Published private(set) var pipelineStatus:
        String = "Ready"

    @Published private(set) var lastPipelineOutput:
        LensingPipelineOutput?
    
    private(set) var values: [Float]
    
    let resolution: Int
    
    var maximumValue: Float {
        values.max() ?? 0.0
    }

    let clusterSceneRadius: Double = 0.75
    
    private var globularClusterNode: SCNNode?
    
    let scene =
        SCNScene()

    private var pathNodes:
        [SCNNode] =
        []

    private var sourceGalaxyNodes:
        [SCNNode] =
        []

    private var massNode:
        SCNNode?

    private var frontPlaneNode:
        SCNNode?

    private var bottomPlaneNode:
        SCNNode?

    private var photonPathNodes:
        [SCNNode] =
        []
    let sourceX: Float = -6.0
    let lensX: Float = 0.0
    let frontPlaneX: Float = 10.0

    let bottomY: Float = -5.0

    // Make the target substantially larger.
    let planeHalfExtent: Float = 8.0
    let heatmapHalfExtent: Float = 5.0
    
    private var projectionPlaneNode: SCNNode?
    
    private let photonPathRoot =
        SCNNode()
   

    // ========================================================
    // PHYSICAL LENSING DISTANCE
    //
    // These are deliberately separated from the visual scene.
    //
    // The compact SceneKit scene represents the geometry,
    // while the physics can use much larger distances.
    // ========================================================

    let physicalSourceDistance:
        Double =
        10.0 *
        PhysicalConstants.solarRadius

    let physicalObserverDistance:
        Double =
        10.0 *
        PhysicalConstants.solarRadius

    var sourcePhysicalX:
        Double {

        -physicalSourceDistance
    }

    var frontPlanePhysicalX:
        Double {

        physicalObserverDistance
    }

    var totalPhysicalDistance:
        Double {

        physicalObserverDistance +
        physicalSourceDistance
    }
    private var projectionAccumulator =
        LensingProjectionAccumulator()

    private let accumulator: ProjectionAccumulator
    
    private var projectionNode: SCNNode?
    private var projectionNodes: [SCNNode] = []
    var photons: [PhotonTraceResult] = []
    
    private var sourceGalaxyNode:
        SCNNode?

    var sourceGalaxyStars:
        [SourceGalaxyStar] = []
    

    // ========================================================
    // INITIALIZATION
    // ========================================================

    init(resolution: Int = 128) {
        self.resolution = resolution
        self.values = Array(
            repeating: 0.0,
            count: resolution * resolution
        )

        self.accumulator = ProjectionAccumulator(
            resolution: resolution,
            halfExtent: Double(planeHalfExtent)
        )

        setupCameraLights()
        addAxes()
        addBottomPlaceholder()
        addFrontProjectionPlane(empty: true)
    }


    // ============================================================
    // TRACE SOURCE GALAXY
    //
    // This belongs in LensingSceneController.
    //
    // It performs ONLY the photon-tracing stage.
    //
    // It does NOT modify SceneKit.
    //
    // It does NOT render anything.
    //
    // It returns immutable physics data.
    //
    // Controller pipeline:
    //
    //     QRTLField
    //          ↓
    //     traceSourceGalaxy()
    //          ↓
    //     PhotonTraceBatch
    //          ↓
    //     LensingProjectionResult
    //          ↓
    //     renderPipelineOutput()
    // ============================================================

    func traceSourceGalaxy(
        stars:
            [SourceGalaxyStar],

        field:
            QRTLField,

        parameters:
            LensingParameters,

        showPaths:
            Bool
    ) -> PhotonTraceBatch {

        // ========================================================
        // STORAGE
        // ========================================================

        var traces:
            [PhotonTraceResult] =
            []

        var paths:
            [[SIMD3<Float>]] =
            []

        var hits:
            [LensingProjectionHit] =
            []


        traces.reserveCapacity(
            stars.count
        )

        hits.reserveCapacity(
            stars.count
        )

        if showPaths {

            paths.reserveCapacity(
                stars.count
            )
        }


        // ========================================================
        // TRACE EVERY SOURCE STAR
        // ========================================================

        for star in stars {

            // ----------------------------------------------------
            // PHOTON ORIGIN
            //
            // Source galaxy occupies the Y-Z image plane.
            //
            // X is the photon propagation direction.
            // ----------------------------------------------------

            let origin =
                SIMD3<Float>(
                    -6.5,
                    star.position.y,
                    star.position.z
                )


            // ----------------------------------------------------
            // INITIAL PHOTON DIRECTION
            //
            // Photons propagate toward +X.
            // ----------------------------------------------------

            let direction =
                SIMD3<Float>(
                    1.0,
                    0.0,
                    0.0
                )


            // ====================================================
            // TRACE PHOTON
            // ====================================================

            let trace =
                tracePhoton(
                    origin:
                        origin,

                    direction:
                        direction,

                    field:
                        field,

                    parameters:
                        parameters
                )


            // ====================================================
            // STORE COMPLETE TRACE
            // ====================================================

            traces.append(
                trace
            )


            // ====================================================
            // STORE PHOTON PATH
            // ====================================================

            if showPaths,
               trace.positions.count >= 2 {

                paths.append(
                    trace.positions
                )
            }


            // ====================================================
            // PROJECTION HIT
            // ====================================================

            guard
                trace.hitProjection,

                let projectionPoint =
                    trace.projectionPosition

            else {
                continue
            }


            // ====================================================
            // PROJECT 3D → 2D
            //
            // Projection plane:
            //
            //     X = constant
            //
            // Image coordinates:
            //
            //     Y → horizontal
            //     Z → vertical
            // ====================================================

            let projectionCoordinates =
                SIMD2<Float>(
                    projectionPoint.y,
                    projectionPoint.z
                )


            // ====================================================
            // SOURCE GALAXY 2D COORDINATES
            // ====================================================

            let sourceCoordinates =
                SIMD2<Float>(
                    star.position.y,
                    star.position.z
                )


            // ====================================================
            // CREATE PROJECTION HIT
            // ====================================================

            let hit =
                LensingProjectionHit(

                    point:
                        projectionPoint,

                    coordinates:
                        projectionCoordinates,

                    sourceCoordinates:
                        sourceCoordinates,

                    direction:
                        trace.finalDirection,

                    traveledDistance:
                        trace.traveledDistance,

                    interactionCount:
                        trace.stepCount,

                    maximumMagneticField:
                        trace.maximumMagneticField,

                    maximumQRTLInfluence:
                        trace.maximumQRTLInfluence,

                    maximumMagneticPhotonInfluence:
                        trace.maximumMagneticPhotonInfluence,

                    sourceID:
                        star.id
                )


            // ====================================================
            // STORE HIT
            // ====================================================

            hits.append(
                hit
            )
        }


        // ========================================================
        // RETURN COMPLETE PHOTON BATCH
        // ========================================================

        return PhotonTraceBatch(

            traces:
                traces,

            paths:
                paths,

            hits:
                hits
        )
    }
    
    private func projectionPlaneIntersection(
        from start: SIMD3<Float>,
        to end: SIMD3<Float>,
        parameters: LensingParameters
    ) -> SIMD3<Float>? {

        let planeX =
            parameters.projectionDistance

        let halfExtent =
            parameters.projectionPlaneHalfExtent

        guard planeX.isFinite,
              halfExtent.isFinite,
              halfExtent > 0.0
        else {
            return nil
        }

        let x0 =
            start.x

        let x1 =
            end.x

        guard x0.isFinite,
              x1.isFinite
        else {
            return nil
        }

        let dx =
            x1 - x0

        guard dx.isFinite,
              abs(dx) > 0.000001
        else {
            return nil
        }

        let t =
            (planeX - x0) / dx

        guard t.isFinite,
              t >= 0.0,
              t <= 1.0
        else {
            return nil
        }

        let intersection =
            start +
            (end - start) * t

        guard intersection.x.isFinite,
              intersection.y.isFinite,
              intersection.z.isFinite
        else {
            return nil
        }

        guard abs(intersection.y) <= halfExtent,
              abs(intersection.z) <= halfExtent
        else {
            return nil
        }

        var result =
            intersection

        result.x =
            planeX

        return result
    }
    // ============================================================
    // TRACE PHOTON THROUGH QRTL + ELECTROMAGNETIC FIELD
    //
    // This is the physics portion of the photon pipeline.
    //
    // Pipeline:
    //
    // source position
    //      ↓
    // initial photon direction
    //      ↓
    // QRTL field sample
    //      ↓
    // electromagnetic field sample
    //      ↓
    // total optical index
    //      ↓
    // index gradient
    //      ↓
    // transverse gradient
    //      ↓
    // photon bending
    //      ↓
    // new photon direction
    //      ↓
    // new photon position
    //      ↓
    // projection-plane intersection
    //      ↓
    // PhotonTraceResult
    //
    // The controller owns this function so that ContentView only
    // orchestrates the experiment and rendering.
    // ============================================================

    func tracePhoton(
        origin: SIMD3<Float>,
        direction: SIMD3<Float>,
        field: QRTLField,
        parameters: LensingParameters
    ) -> PhotonTraceResult {

        // ========================================================
        // INITIAL PHOTON STATE
        // ========================================================

        var position =
            origin

        let initialLength =
            simd_length(direction)

        guard initialLength.isFinite,
              initialLength > 0.000001
        else {

            return PhotonTraceResult(
                positions: [origin],
                origin: origin,
                finalPosition: origin,
                finalDirection: .zero,
                hitProjection: false,
                projectionPosition: nil,
                stepCount: 0,
                traveledDistance: 0.0,
                maximumQRTLInfluence: 0.0,
                maximumMagneticField: 0.0,
                maximumMagneticPhotonInfluence: 0.0
            )
        }

        var photonDirection =
            simd_normalize(direction)

        guard photonDirection.x.isFinite,
              photonDirection.y.isFinite,
              photonDirection.z.isFinite
        else {

            return PhotonTraceResult(
                positions: [origin],
                origin: origin,
                finalPosition: origin,
                finalDirection: .zero,
                hitProjection: false,
                projectionPosition: nil,
                stepCount: 0,
                traveledDistance: 0.0,
                maximumQRTLInfluence: 0.0,
                maximumMagneticField: 0.0,
                maximumMagneticPhotonInfluence: 0.0
            )
        }

        // ========================================================
        // PHOTON PATH
        // ========================================================

        var positions:
            [SIMD3<Float>] = []

        positions.reserveCapacity(
            parameters.maximumPhotonSteps + 1
        )

        positions.append(
            position
        )

        // ========================================================
        // DIAGNOSTICS
        // ========================================================

        var maximumQRTLInfluence:
            Float = 0.0

        var maximumMagneticField:
            Float = 0.0

        var maximumMagneticPhotonInfluence:
            Float = 0.0

        var traveledDistance:
            Float = 0.0

        var stepCount:
            Int = 0

        // ========================================================
        // PHOTON PROPAGATION LOOP
        // ========================================================

        for _ in 0..<parameters.maximumPhotonSteps {

            stepCount += 1

            let previousPosition =
                position

            let previousDirection =
                photonDirection

            // ====================================================
            // SAMPLE QRTL / OPTICAL FIELD
            // ====================================================

            let sample =
                field.sample(
                    at:
                        position
                )

            let totalIndex =
                sample.totalIndex

            guard totalIndex.isFinite,
                  totalIndex > 0.000001
            else {
                break
            }

            // ====================================================
            // QRTL INFLUENCE
            // ====================================================

            let qrtlInfluence =
                field.influence(
                    at:
                        position
                )

            let qrtlMagnitude =
                simd_length(
                    qrtlInfluence
                )

            if qrtlMagnitude.isFinite {

                maximumQRTLInfluence =
                    max(
                        maximumQRTLInfluence,
                        qrtlMagnitude
                    )
            }

            // ====================================================
            // ELECTROMAGNETIC INFLUENCE
            // ====================================================

            let electromagneticInfluence =
                field.electromagneticInfluence(
                    at:
                        position
                )

            let magneticPhotonMagnitude =
                simd_length(
                    electromagneticInfluence
                )

            if magneticPhotonMagnitude.isFinite {

                maximumMagneticPhotonInfluence =
                    max(
                        maximumMagneticPhotonInfluence,
                        magneticPhotonMagnitude
                    )
            }

            // ====================================================
            // MAGNETIC FIELD
            // ====================================================

            let electromagneticField =
                field.electromagneticField(
                    at:
                        position
                )

            let magneticFieldMagnitude =
                simd_length(
                    electromagneticField
                )

            if magneticFieldMagnitude.isFinite {

                maximumMagneticField =
                    max(
                        maximumMagneticField,
                        magneticFieldMagnitude
                    )
            }

            // ====================================================
            // OPTICAL INDEX GRADIENT
            //
            // The gradient describes how the optical field changes
            // spatially around the lens.
            // ====================================================

            let gradient =
                field.indexGradient(
                    at:
                        position
                )

            guard gradient.x.isFinite,
                  gradient.y.isFinite,
                  gradient.z.isFinite
            else {
                break
            }

            // ====================================================
            // REMOVE LONGITUDINAL COMPONENT
            //
            // Only the component transverse to the photon direction
            // changes the photon trajectory.
            // ====================================================

            let longitudinal =
                simd_dot(
                    gradient,
                    photonDirection
                )

            let transverseGradient =
                gradient -
                photonDirection *
                longitudinal

            // ====================================================
            // OPTICAL BENDING
            // ====================================================

            let indexBending =
                transverseGradient /
                max(
                    totalIndex,
                    0.000001
                )

            guard indexBending.x.isFinite,
                  indexBending.y.isFinite,
                  indexBending.z.isFinite
            else {
                break
            }

            // ====================================================
            // STEP SIZE
            // ====================================================

            let step =
                parameters.photonStepSize

            guard step.isFinite,
                  step > 0.0
            else {
                break
            }

            // ====================================================
            // CHANGE PHOTON DIRECTION
            // ====================================================

            let directionChange =
                indexBending *
                parameters.deflectionStrength

            var nextDirection =
                photonDirection +
                directionChange *
                step

            let nextDirectionLength =
                simd_length(
                    nextDirection
                )

            guard nextDirectionLength.isFinite,
                  nextDirectionLength > 0.000001
            else {
                break
            }

            nextDirection =
                simd_normalize(
                    nextDirection
                )

            // ====================================================
            // ADVANCE PHOTON
            // ====================================================

            let nextPosition =
                position +
                nextDirection *
                step

            guard nextPosition.x.isFinite,
                  nextPosition.y.isFinite,
                  nextPosition.z.isFinite
            else {
                break
            }

            // ====================================================
            // PROJECTION PLANE
            //
            // The photon travels primarily along +X.
            //
            // Projection plane:
            //
            //     X = projectionDistance
            //
            // Y/Z become the image coordinates.
            // ====================================================

            if let intersection =
                projectionPlaneIntersection(
                    from:
                        previousPosition,

                    to:
                        nextPosition,

                    parameters:
                        parameters
                ) {

                position =
                    intersection

                positions.append(
                    intersection
                )

                traveledDistance +=
                    simd_distance(
                        previousPosition,
                        intersection
                    )

                // ====================================================
                // PHOTON HAS REACHED OBSERVATION PLANE
                // ====================================================

                return PhotonTraceResult(

                    positions:
                        positions,

                    origin:
                        origin,

                    finalPosition:
                        intersection,

                    finalDirection:
                        nextDirection,

                    hitProjection:
                        true,

                    projectionPosition:
                        intersection,

                    stepCount:
                        stepCount,

                    traveledDistance:
                        traveledDistance,

                    maximumQRTLInfluence:
                        maximumQRTLInfluence,

                    maximumMagneticField:
                        maximumMagneticField,

                    maximumMagneticPhotonInfluence:
                        maximumMagneticPhotonInfluence
                )
            }

            // ====================================================
            // COMMIT PHOTON STATE
            // ====================================================

            photonDirection =
                nextDirection

            position =
                nextPosition

            traveledDistance +=
                step

            positions.append(
                position
            )

            // ====================================================
            // STOP OUTSIDE LENSING VOLUME
            // ====================================================

            let distanceFromCenter =
                simd_length(
                    position
                )

            if distanceFromCenter.isFinite,
               distanceFromCenter >
                    parameters.maximumPropagationRadius {

                break
            }

            // ====================================================
            // SAFETY CHECK
            // ====================================================

            guard previousDirection.x.isFinite,
                  previousDirection.y.isFinite,
                  previousDirection.z.isFinite
            else {
                break
            }
        }

        // ========================================================
        // PHOTON DID NOT REACH PROJECTION PLANE
        // ========================================================

        return PhotonTraceResult(

            positions:
                positions,

            origin:
                origin,

            finalPosition:
                position,

            finalDirection:
                photonDirection,

            hitProjection:
                false,

            projectionPosition:
                nil,

            stepCount:
                stepCount,

            traveledDistance:
                traveledDistance,

            maximumQRTLInfluence:
                maximumQRTLInfluence,

            maximumMagneticField:
                maximumMagneticField,

            maximumMagneticPhotonInfluence:
                maximumMagneticPhotonInfluence
        )
    }
    // ============================================================
    // RENDER COMPLETE PIPELINE OUTPUT
    // ============================================================

    // ============================================================
    // RENDER COMPLETE QRTL LENSING PIPELINE
    //
    // Physics pipeline:
    //
    // QRTLExperiment
    //      ↓
    // QRTLField
    //      ↓
    // traceSourceGalaxy()
    //      ↓
    // PhotonTraceBatch
    //      ↓
    // LensingProjectionResult
    //      ↓
    // LensingPipelineOutput
    //      ↓
    // THIS FUNCTION
    //      ↓
    // SceneKit visualization
    // ============================================================

    func renderPipelineOutput(
        _ output:
            LensingPipelineOutput,

        showPhotonPaths:
            Bool
    ) {

        // ========================================================
        // CLEAR PREVIOUS DYNAMIC CONTENT
        // ========================================================

        clearDynamic()


        // ========================================================
        // SOURCE GALAXY
        //
        // This is the original background/source galaxy.
        // ========================================================

        addSourceGalaxy(
            radius:
                0.75,

            nStars:
                220
        )


        // ========================================================
        // QRTL LENS / GLOBULAR CLUSTER
        // ========================================================

        addGlobularCluster(
            radius:
                3.0
        )


        // ========================================================
        // QRTL FIELD HEATMAP
        //
        // The field is now carried inside the pipeline output.
        // ========================================================

        updateBottomHeatmap(
            field:
                output.field
        )


        // ========================================================
        // PROJECTION PLANE
        //
        // Photons propagate along +X.
        //
        // Therefore:
        //
        //     X = projection distance
        //     Y = horizontal image coordinate
        //     Z = vertical image coordinate
        // ========================================================

        func addProjectionPlane(
            halfExtent: Float,
            x: Double
        ) {

            projectionPlaneNode?.removeFromParentNode()

            let plane =
                SCNPlane(
                    width:
                        CGFloat(halfExtent * 2.0),

                    height:
                        CGFloat(halfExtent * 2.0)
                )

            let material =
                SCNMaterial()

            material.diffuse.contents =
                UIColor(
                    white: 0.08,
                    alpha: 0.18
                )

            material.isDoubleSided =
                true

            plane.materials =
                [material]

            let node =
                SCNNode(
                    geometry:
                        plane
                )

            node.position =
                SCNVector3(
                    Float(x),
                    0.0,
                    0.0
                )

            // SCNPlane initially lies in XY.
            // Rotate it so it lies in the YZ plane.
            node.eulerAngles =
                SCNVector3(
                    Float.pi / 2.0,
                    0.0,
                    0.0
                )

            projectionPlaneNode =
                node

            scene.rootNode.addChildNode(
                node
            )
        }


        // ========================================================
        // PROJECTED GALAXY
        //
        // Convert the accumulated photon hits into the visible
        // projected galaxy image.
        // ========================================================

        applyProjection(
            output.projection
        )


        // ========================================================
        // PHOTON PATHS
        // ========================================================

        clearPhotonPaths()


        guard showPhotonPaths
        else {
            return
        }


        // ========================================================
        // RENDER EVERY PHOTON PATH
        // ========================================================

        for (
            index,
            path
        )
        in output.photonPaths.enumerated() {

            guard path.count >= 2
            else {
                continue
            }


            addPhotonSpline(
                points:
                    path,

                index:
                    index
            )
        }
    }

    private func bendPhoton(
        position: SIMD3<Float>,
        direction: SIMD3<Float>,
        field: QRTLField,
        parameters: LensingParameters
    ) -> SIMD3<Float> {

        let incomingLength =
            simd_length(direction)

        guard incomingLength > 1.0e-6,
              incomingLength.isFinite
        else {
            return direction
        }

        let incoming =
            simd_normalize(direction)

        let fieldVector =
            field.vector(at: position)

        let fieldStrength =
            field.strength(at: position)

        guard fieldVector.x.isFinite,
              fieldVector.y.isFinite,
              fieldVector.z.isFinite,
              fieldStrength.isFinite,
              fieldStrength > 0.0
        else {
            return incoming
        }

        let fieldLength =
            simd_length(fieldVector)

        guard fieldLength > 1.0e-6,
              fieldLength.isFinite
        else {
            return incoming
        }

        let fieldDirection =
            simd_normalize(fieldVector)

        let coupling =
            max(
                0.0,
                parameters.qrtlPhotonCoupling
            )

        let influence =
            max(
                0.0,
                min(
                    1.0,
                    fieldStrength * coupling
                )
            )

        let blended =
            incoming * Float(1.0 - influence) +
            fieldDirection * Float(influence)

        let resultLength =
            simd_length(blended)

        guard resultLength > 1.0e-6,
              resultLength.isFinite
        else {
            return incoming
        }

        return simd_normalize(blended)
    }


    // ============================================================
    // MAKE PHOTON PAIR DIRECTIONS
    //
    // Creates the two initial photon directions emitted from
    // one source-galaxy star.
    //
    // These are the two rays that will subsequently be bent by
    // the QRTL field.
    //
    // ============================================================

    private func makePhotonPairDirections(
        for star: SourceGalaxyStar
    ) -> (
        left: SIMD3<Float>,
        right: SIMD3<Float>
    ) {

        let forward =
            SIMD3<Float>(
                1,
                0,
                0
            )

        let angle =
            Float.random(
                in:
                    -Float.pi...Float.pi
            )

        let transverse =
            SIMD3<Float>(
                0,
                cos(angle),
                sin(angle)
            )

        let offset =
            Float.random(
                in:
                    0.05...0.30
            )

        let left =
            simd_normalize(
                forward -
                transverse * offset
            )

        let right =
            simd_normalize(
                forward +
                transverse * offset
            )

        return (
            left,
            right
        )
    }
    // =============================================================
    // REMOVE PREVIOUS PROJECTION
    // =============================================================
    //
    // Removes only the previously rendered projection.
    // It does not remove:
    //   - source galaxy
    //   - globular cluster
    //   - photon paths
    //   - lensing field
    //
    // =============================================================

    func removePreviousProjection() {

        // ---------------------------------------------------------
        // Remove previous projection container
        // ---------------------------------------------------------

        projectionNode?.removeFromParentNode()
        projectionNode = nil


        // ---------------------------------------------------------
        // Remove any individually rendered projection nodes
        // ---------------------------------------------------------

        for node in projectionNodes {

            node.removeFromParentNode()
        }

        projectionNodes.removeAll(
            keepingCapacity: true
        )


        // ---------------------------------------------------------
        // Clear accumulated projection data
        // ---------------------------------------------------------

        projectionAccumulator.reset()
    }
 
    func applyProjection(
        _ projection:
            LensingProjectionResult
    ) {

        removePreviousProjection()

        accumulator.reset()

        for hit in projection.validHits {

            accumulator.addHit(
                y:
                    Double(
                        hit.coordinates.x
                    ),

                z:
                    Double(
                        hit.coordinates.y
                    ),

                weight:
                    1.5
            )
        }

        addFrontProjectionPlane(
            empty:
                false
        )
    }
    private func physicalToScene(
        _ position:
            SIMD3<Double>
    ) -> SCNVector3 {

        let scale =
            PhysicalConstants.solarRadius

        return SCNVector3(
            Float(
                position.x /
                scale
            ),

            Float(
                position.y /
                scale
            ),

            Float(
                position.z /
                scale
            )
        )
    }

    // ========================================================
    // CAMERA / LIGHTING
    // ========================================================

    private func setupCameraLights() {

        let cameraNode =
            SCNNode()

        let camera =
            SCNCamera()

        camera.zNear =
            0.01

        camera.zFar =
            100.0

        camera.fieldOfView =
            55

        cameraNode.camera =
            camera

        cameraNode.position =
            SCNVector3(
                60,
                6,
                0
            )

        cameraNode.look(
            at:
                SCNVector3(
                    0,
                    0,
                    0
                )
        )

        scene.rootNode.addChildNode(
            cameraNode
        )

        let keyNode =
            SCNNode()

        let keyLight =
            SCNLight()

        keyLight.type =
            .omni

        keyLight.intensity =
            1800

        keyLight.attenuationStartDistance =
            5

        keyLight.attenuationEndDistance =
            40

        keyNode.light =
            keyLight

        keyNode.position =
            SCNVector3(
                4,
                8,
                8
            )

        scene.rootNode.addChildNode(
            keyNode
        )

        let ambientNode =
            SCNNode()

        let ambient =
            SCNLight()

        ambient.type =
            .ambient

        ambient.intensity =
            300

        ambientNode.light =
            ambient

        scene.rootNode.addChildNode(
            ambientNode
        )
    }

    // ========================================================
    // AXES
    // ========================================================

    private func addAxes() {

        let length:
            Float =
            8.0

        let definitions:
            [
                (
                    SCNVector3,
                    UIColor
                )
            ] = [

                (
                    SCNVector3(
                        length,
                        0,
                        0
                    ),
                    .systemRed
                ),

                (
                    SCNVector3(
                        0,
                        length,
                        0
                    ),
                    .systemGreen
                ),

                (
                    SCNVector3(
                        0,
                        0,
                        length
                    ),
                    .systemBlue
                )
            ]

        for (
            vector,
            color
        ) in definitions {

            let axisLength =
                sqrt(
                    vector.x *
                    vector.x +
                    vector.y *
                    vector.y +
                    vector.z *
                    vector.z
                )

            let cylinder =
                SCNCylinder(
                    radius:
                        0.015,

                    height:
                        CGFloat(
                            axisLength
                        )
                )

            let material =
                SCNMaterial()

            material.diffuse.contents =
                color

            material.emission.contents =
                color

            material.lightingModel =
                .constant

            cylinder.materials =
                [material]

            let node =
                SCNNode(
                    geometry:
                        cylinder
                )

            node.position =
                SCNVector3(
                    vector.x / 2,
                    vector.y / 2,
                    vector.z / 2
                )

            if abs(vector.x) > 0 {

                node.eulerAngles.z =
                    .pi / 2
            }

            if abs(vector.z) > 0 {

                node.eulerAngles.x =
                    .pi / 2
            }

            scene.rootNode.addChildNode(
                node
            )
        }
    }

    // ========================================================
    // CLEAR
    // ========================================================

    func clearDynamic() {

        pathNodes.forEach {
            $0.removeFromParentNode()
        }

        pathNodes.removeAll()

        sourceGalaxyNodes.forEach {
            $0.removeFromParentNode()
        }

        sourceGalaxyNodes.removeAll()

        clearPhotonPaths()

        sourceGalaxyNode?
            .removeFromParentNode()

        sourceGalaxyNode =
            nil

        sourceGalaxyStars.removeAll(
            keepingCapacity: true
        )

        massNode?
            .removeFromParentNode()

        massNode =
            nil

        globularClusterNode?
            .removeFromParentNode()

        globularClusterNode =
            nil

        bottomPlaneNode?
            .removeFromParentNode()

        bottomPlaneNode =
            nil

        frontPlaneNode?
            .removeFromParentNode()

        frontPlaneNode =
            nil

        projectionPlaneNode?
            .removeFromParentNode()

        projectionPlaneNode =
            nil

        projectionNodes.forEach {
            $0.removeFromParentNode()
        }

        projectionNodes.removeAll(
            keepingCapacity: true
        )

        accumulator.reset()

        projectionAccumulator.reset()

        lastPipelineOutput =
            nil
    }

    func addSourceGalaxy(
        radius: Double = 0.75,
        nStars: Int = 220
    ) {

        // =========================================================
        // CLEAR PREVIOUS GALAXY
        // =========================================================

        sourceGalaxyNode?.removeFromParentNode()

        sourceGalaxyStars.removeAll(
            keepingCapacity: true
        )

        let galaxyNode =
            SCNNode()

        sourceGalaxyNode =
            galaxyNode


        // =========================================================
        // SOURCE GALAXY DISTANCE
        //
        // Photons travel in +X.
        //
        // Therefore the source galaxy starts at negative X
        // and travels toward the globular cluster at X = 0.
        // =========================================================

        let sourceX:
            Float = -6.5


        // =========================================================
        // GENERATE SOURCE GALAXY
        //
        // Galaxy lies primarily in the Y-Z plane.
        //
        // X = photon travel direction
        // Y = galaxy vertical/radial coordinate
        // Z = galaxy depth/radial coordinate
        // =========================================================

        for starID in 0..<nStars {

            // ---------------------------------------------------------
            // RANDOM ANGLE
            // ---------------------------------------------------------

            let theta = Double.random(
                in: 0.0...(2.0 * Double.pi)
            )

            // ---------------------------------------------------------
            // GALAXY RADIAL DISTRIBUTION
            //
            // sqrt() produces a broad disk distribution.
            // ---------------------------------------------------------

            let radialFraction =
                sqrt(
                    Double.random(
                        in:
                            0.0...1.0
                    )
                )


            let r =
                radius *
                radialFraction


            // ---------------------------------------------------------
            // Y / Z GALAXY POSITION
            // ---------------------------------------------------------

            let y =
                r *
                cos(theta)

            let z =
                r *
                sin(theta)


            // ---------------------------------------------------------
            // SMALL GALAXY THICKNESS ALONG X
            //
            // Keep the galaxy slightly three-dimensional.
            // ---------------------------------------------------------

            let xOffset =
                Double.random(
                    in:
                        -0.03...0.03
                )


            let position =
                SIMD3<Float>(
                    sourceX +
                        Float(xOffset),

                    Float(y),

                    Float(z)
                )


            // ---------------------------------------------------------
            // BRIGHTNESS
            // ---------------------------------------------------------

            let brightness =
                Float.random(
                    in:
                        0.5...1.0
                )


            // =========================================================
            // STORE SOURCE STAR
            //
            // IMPORTANT:
            // This is the position that runFullPipeline() will use
            // as the photon origin.
            // =========================================================

            sourceGalaxyStars.append(
                SourceGalaxyStar(
                    id:
                        starID,

                    position:
                        position,

                    brightness:
                        brightness
                )
            )


            // =========================================================
            // CREATE VISUAL STAR
            // =========================================================

            let starRadius =
                Float(
                    0.008 +
                    Double.random(
                        in:
                            0.0...0.012
                    )
                )


            let geometry =
                SCNSphere(
                    radius:
                        CGFloat(
                            starRadius
                        )
                )


            let material =
                SCNMaterial()

            material.diffuse.contents =
                UIColor.white

            material.emission.contents =
                UIColor.white

            material.lightingModel =
                .constant

            geometry.firstMaterial =
                material


            let starNode =
                SCNNode(
                    geometry:
                        geometry
                )


            starNode.position =
                SCNVector3(
                    position.x,
                    position.y,
                    position.z
                )


            galaxyNode.addChildNode(
                starNode
            )
        }


        // =========================================================
        // ADD GALAXY TO SCENE
        // =========================================================

        scene.rootNode.addChildNode(
            galaxyNode
        )
    }
 
    func addGlobularCluster(
        radius: Double = 5.0,
        nStars: Int = 3000
    ) {

        // =========================================================
        // CLEAR PREVIOUS CLUSTER
        // =========================================================

        globularClusterNode?.removeFromParentNode()


        // =========================================================
        // CREATE CLUSTER NODE
        // =========================================================

        let clusterNode =
            SCNNode()

        globularClusterNode =
            clusterNode


        // =========================================================
        // CREATE STARS THROUGHOUT SPHERICAL VOLUME
        // =========================================================

        for _ in 0..<nStars {

            // -----------------------------------------------------
            // RANDOM DIRECTION
            // -----------------------------------------------------

            let theta =
                Double.random(
                    in: 0.0...(2.0 * Double.pi)
                )

            let zDirection =
                Double.random(
                    in: -1.0...1.0
                )

            let radialXY =
                sqrt(
                    max(
                        0.0,
                        1.0 -
                        zDirection * zDirection
                    )
                )


            // -----------------------------------------------------
            // UNIFORM VOLUME DISTRIBUTION
            // -----------------------------------------------------

            let radialFraction =
                pow(
                    Double.random(
                        in: 0.0...1.0
                    ),
                    1.0 / 3.0
                )

            let r =
                radius *
                radialFraction


            // -----------------------------------------------------
            // SPHERICAL → CARTESIAN
            // -----------------------------------------------------

            let x =
                r *
                radialXY *
                cos(theta)

            let y =
                r *
                radialXY *
                sin(theta)

            let z =
                r *
                zDirection


            let position =
                SIMD3<Float>(
                    Float(x),
                    Float(y),
                    Float(z)
                )


            // -----------------------------------------------------
            // DISTANCE FROM CENTER
            // -----------------------------------------------------

            let distanceFromCenter =
                r


            // -----------------------------------------------------
            // CORE DENSITY
            // -----------------------------------------------------

            let normalizedRadius =
                radius > 0.0
                ? distanceFromCenter / radius
                : 0.0

            let coreFactor =
                max(
                    0.0,
                    1.0 -
                    normalizedRadius
                )


            // -----------------------------------------------------
            // STAR SIZE
            // -----------------------------------------------------

            let starRadius =
                Float(
                    0.009 +
                    Double.random(
                        in: 0.0...0.012
                    ) +
                    coreFactor * 0.008
                )


            // -----------------------------------------------------
            // CREATE STAR GEOMETRY
            // -----------------------------------------------------

            let starGeometry =
                SCNSphere(
                    radius:
                        CGFloat(
                            starRadius
                        )
                )


            let material =
                SCNMaterial()

            material.diffuse.contents =
                UIColor.white

            material.emission.contents =
                UIColor.white

            material.lightingModel =
                .constant

            starGeometry.firstMaterial =
                material


            // -----------------------------------------------------
            // CREATE STAR NODE
            // -----------------------------------------------------

            let starNode =
                SCNNode(
                    geometry:
                        starGeometry
                )

            starNode.position =
                SCNVector3(
                    position.x,
                    position.y,
                    position.z
                )


            clusterNode.addChildNode(
                starNode
            )
        }


        // =========================================================
        // ADD CLUSTER TO SCENE
        // =========================================================

        scene.rootNode.addChildNode(
            clusterNode
        )
    }

    // ========================================================
    // FRONT PROJECTION PLANE
    // ========================================================

    // Constants on LensingSceneController:
    // let frontPlaneX: Float = 8
    // let bottomY: Float = -4
    // let planeHalfExtent: Float = 6
    // let heatmapHalfExtent: Float = 7

    func addFrontProjectionPlane(empty: Bool) {
        frontPlaneNode?.removeFromParentNode()

        let size = CGFloat(planeHalfExtent * 2)
        let plane = SCNPlane(width: size, height: size)
        let mat = SCNMaterial()
        mat.isDoubleSided = true
        mat.lightingModel = .constant

        if empty {
            mat.diffuse.contents = UIColor.cyan.withAlphaComponent(0.4)
            mat.emission.contents = UIColor.cyan.withAlphaComponent(0.25)
        } else {
            let img = accumulator.makeImage()
            mat.diffuse.contents = img
            mat.emission.contents = img
        }
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(frontPlaneX, 0, 0)
        node.eulerAngles.y = .pi / 2
        node.name = "FrontProjectionPlane"
        scene.rootNode.addChildNode(node)
        frontPlaneNode = node
    }

    func updateBottomHeatmap(field: QRTLField) {
        bottomPlaneNode?.removeFromParentNode()

        let image = QRTLHeatmapGenerator.makeHeatmapImage(
            field: field,
            size: 128,
            halfExtent: Double(heatmapHalfExtent)   // scene units only
        )

        let size = CGFloat(heatmapHalfExtent * 2)
        let plane = SCNPlane(width: size, height: size)
        let mat = SCNMaterial()
        mat.isDoubleSided = true
        mat.lightingModel = .constant
        mat.diffuse.contents = image
        mat.emission.contents = image
        plane.materials = [mat]

        let node = SCNNode(geometry: plane)
        node.position = SCNVector3(frontPlaneX * 0.5, bottomY, 0)
        node.eulerAngles.x = -.pi / 2
        node.name = "HeatmapPlane"
        scene.rootNode.addChildNode(node)
        bottomPlaneNode = node
    }
    private func makeSolidImage(color: UIColor) -> UIImage {
        let res = resolution
        UIGraphicsBeginImageContextWithOptions(CGSize(width: res, height: res), false, 1.0)
        guard let ctx = UIGraphicsGetCurrentContext() else { return UIImage() }
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: res, height: res))
        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }

    // ========================================================
    // BOTTOM PLACEHOLDER
    // ========================================================

    func addBottomPlaceholder() {

        bottomPlaneNode?.removeFromParentNode()

        let size =
            heatmapHalfExtent *
            2.0

        let plane =
            SCNPlane(
                width:
                    CGFloat(size),

                height:
                    CGFloat(size)
            )

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor(
                white:
                    0.07,

                alpha:
                    0.9
            )

        material.emission.contents =
            UIColor(
                white:
                    0.02,

                alpha:
                    0.4
            )

        material.isDoubleSided =
            true

        plane.materials =
            [material]

        let node =
            SCNNode(
                geometry:
                    plane
            )

        node.position =
            SCNVector3(
                0,
                bottomY,
                0
            )

        node.eulerAngles.x =
            -.pi / 2

        scene.rootNode.addChildNode(
            node
        )

        bottomPlaneNode =
            node
    }

  
    // ========================================================
    // LENS MASS
    // ========================================================

    func addCluster(
        radius: Double,
        nStars: Int = 3000
    ) {

        // =========================================================
        // REMOVE PREVIOUS CLUSTER
        // =========================================================

        globularClusterNode?.removeFromParentNode()

        let clusterNode =
            SCNNode()

        globularClusterNode =
            clusterNode


        // =========================================================
        // CREATE STARS THROUGHOUT SPHERICAL VOLUME
        // =========================================================

        for _ in 0..<nStars {

            // -----------------------------------------------------
            // UNIFORM RANDOM DIRECTION
            // -----------------------------------------------------

            let theta =
                Double.random(
                    in: 0.0...(2.0 * Double.pi)
                )

            let phi =
                acos(
                    Double.random(
                        in: -1.0...1.0
                    )
                )


            // -----------------------------------------------------
            // UNIFORM VOLUME DISTRIBUTION
            //
            // Cube-root distribution prevents stars from being
            // concentrated toward the center.
            // -----------------------------------------------------

            let radialFraction =
                pow(
                    Double.random(
                        in: 0.0...1.0
                    ),
                    1.0 / 3.0
                )

            let r =
                radius *
                radialFraction


            // -----------------------------------------------------
            // SPHERICAL → CARTESIAN
            // -----------------------------------------------------

            let sinPhi =
                sin(phi)

            let x =
                r *
                sinPhi *
                cos(theta)

            let y =
                r *
                sinPhi *
                sin(theta)

            let z =
                r *
                cos(phi)


            // -----------------------------------------------------
            // STAR SIZE
            // -----------------------------------------------------

            let starRadius =
                0.006 +
                Double.random(
                    in: 0.0...0.010
                )


            // -----------------------------------------------------
            // STAR GEOMETRY
            // -----------------------------------------------------

            let star =
                SCNSphere(
                    radius:
                        CGFloat(
                            starRadius
                        )
                )


            let material =
                SCNMaterial()

            material.diffuse.contents =
                UIColor.white

            material.emission.contents =
                UIColor.white

            material.lightingModel =
                .constant

            star.firstMaterial =
                material


            // -----------------------------------------------------
            // STAR NODE
            // -----------------------------------------------------

            let starNode =
                SCNNode(
                    geometry:
                        star
                )

            starNode.position =
                SCNVector3(
                    x,
                    y,
                    z
                )


            clusterNode.addChildNode(
                starNode
            )
        }


        // =========================================================
        // ADD CLUSTER TO SCENE
        // =========================================================

        scene.rootNode.addChildNode(
            clusterNode
        )
    }

    // ========================================================
    // CYLINDER BETWEEN TWO SCENE POINTS
    //
    // This replaces the invalid SCNGeometryElement.lineWidth
    // approach.
    // ========================================================

    private func makeTubeSegment(
        from:
            SCNVector3,

        to:
            SCNVector3,

        radius:
            CGFloat,

        color:
            UIColor
    ) -> SCNNode {

        let start =
            SIMD3<Float>(
                from.x,
                from.y,
                from.z
            )

        let end =
            SIMD3<Float>(
                to.x,
                to.y,
                to.z
            )

        let delta =
            end -
            start

        let length =
            simd_length(
                delta
            )

        guard length >
                1.0e-6
        else {
            return SCNNode()
        }

        let cylinder =
            SCNCylinder(
                radius:
                    radius,

                height:
                    CGFloat(
                        length
                    )
            )

        let material =
            SCNMaterial()

        material.diffuse.contents =
            color

        material.emission.contents =
            color

        material.lightingModel =
            .constant

        cylinder.materials =
            [material]

        let node =
            SCNNode(
                geometry:
                    cylinder
            )

        node.position =
            SCNVector3(
                (
                    from.x +
                    to.x
                ) * 0.5,

                (
                    from.y +
                    to.y
                ) * 0.5,

                (
                    from.z +
                    to.z
                ) * 0.5
            )

        // SCNCylinder's local Y axis is its length axis.
        let direction =
            simd_normalize(
                delta
            )

        let up =
            SIMD3<Float>(
                0,
                1,
                0
            )

        let dot =
            simd_dot(
                up,
                direction
            )

        if dot > 0.9999 {

            node.simdOrientation =
                simd_quatf(
                    angle:
                        0,

                    axis:
                        SIMD3<Float>(
                            1,
                            0,
                            0
                        )
                )

        } else if dot < -0.9999 {

            node.simdOrientation =
                simd_quatf(
                    angle:
                        .pi,

                    axis:
                        SIMD3<Float>(
                            1,
                            0,
                            0
                        )
                )

        } else {

            let axis =
                simd_normalize(
                    simd_cross(
                        up,
                        direction
                    )
                )

            let angle =
                acos(
                    clamped(
                        Double(dot),
                        minimum:
                            -1,
                        maximum:
                            1
                    )
                )

            node.simdOrientation =
                simd_quatf(
                    angle:
                        Float(angle),

                    axis:
                        axis
                )
        }

        return node
    }

    // ========================================================
    // SMOOTH PHOTON PATH
    //
    // Catmull-Rom -> dense points -> cylindrical segments.
    // ========================================================

    @discardableResult
    func addSplinePhotonPath(
        controlPoints:
            [SIMD3<Double>],

        color:
            UIColor = .cyan,

        radius:
            CGFloat = 0.018,

        pointsPerSegment:
            Int = 6
    ) -> SCNNode? {

        guard controlPoints.count >= 2
        else {
            return nil
        }

        let physicalPoints =
            CatmullRomSpline.interpolate(
                points:
                    controlPoints,

                pointsPerSegment:
                    pointsPerSegment
            )

        guard physicalPoints.count >= 2
        else {
            return nil
        }

        let root =
            SCNNode()

        root.name =
            "PhotonSpline"

        let scenePoints =
            physicalPoints.map {
                physicalToScene($0)
            }

        for i in 0..<(scenePoints.count - 1) {

            let segment =
                makeTubeSegment(
                    from:
                        scenePoints[i],

                    to:
                        scenePoints[i + 1],

                    radius:
                        radius,

                    color:
                        color
                )

            root.addChildNode(
                segment
            )
        }

        scene.rootNode.addChildNode(
            root
        )

        photonPathNodes.append(
            root
        )

        return root
    }
    func renderPhotonPath(
        _ path: [SIMD3<Float>]
    ) {

        // ---------------------------------------------------------
        // VALIDATE PATH
        // ---------------------------------------------------------

        guard path.count >= 2 else {
            return
        }


        // ---------------------------------------------------------
        // CONVERT PHOTON PATH TO SCNVECTOR3
        // ---------------------------------------------------------

        let points =
            path.map {
                SCNVector3(
                    x: $0.x,
                    y: $0.y,
                    z: $0.z
                )
            }


        // ---------------------------------------------------------
        // CREATE SOURCE DATA
        // ---------------------------------------------------------

        let source =
            SCNGeometrySource(
                vertices:
                    points
            )


        // ---------------------------------------------------------
        // CREATE LINE INDICES
        // ---------------------------------------------------------

        var indices:
            [Int32] = []

        indices.reserveCapacity(
            (points.count - 1) * 2
        )


        for index in 0..<(points.count - 1) {

            indices.append(
                Int32(index)
            )

            indices.append(
                Int32(index + 1)
            )
        }


        // ---------------------------------------------------------
        // CREATE GEOMETRY ELEMENT
        // ---------------------------------------------------------

        let element =
            SCNGeometryElement(
                indices:
                    indices,

                primitiveType:
                    .line
            )


        // ---------------------------------------------------------
        // CREATE GEOMETRY
        // ---------------------------------------------------------

        let geometry =
            SCNGeometry(
                sources:
                    [source],

                elements:
                    [element]
            )


        // ---------------------------------------------------------
        // MATERIAL
        // ---------------------------------------------------------

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor.white.withAlphaComponent(0.1)

        material.emission.contents =
            UIColor.white.withAlphaComponent(0.1)

        material.lightingModel =
            .constant

        material.isDoubleSided =
            true

        geometry.firstMaterial =
            material


        // ---------------------------------------------------------
        // CREATE NODE
        // ---------------------------------------------------------

        let node =
            SCNNode(
                geometry:
                    geometry
            )


        // ---------------------------------------------------------
        // ADD TO PHOTON PATH COLLECTION
        // ---------------------------------------------------------

        photonPathNodes.append(
            node
        )


        // ---------------------------------------------------------
        // ADD TO SCENE
        // ---------------------------------------------------------

        scene.rootNode.addChildNode(
            node
        )
    }
    
    func addProjectionPlane(
        halfExtent: Float,
        x: Float
    ) {

        // Remove previous plane
        projectionPlaneNode?.removeFromParentNode()

        let size =
            CGFloat(halfExtent * 2.0)

        let geometry =
            SCNPlane(
                width: size,
                height: size
            )

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor(
                white: 0.25,
                alpha: 0.35
            )

        material.emission.contents =
            UIColor(
                white: 0.15,
                alpha: 0.35
            )

        material.lightingModel =
            .constant

        material.isDoubleSided =
            true

        geometry.firstMaterial =
            material

        let node =
            SCNNode(
                geometry:
                    geometry
            )

        // Photons travel along +X.
        // Rotate SCNPlane so it occupies Y-Z.
        node.eulerAngles.y =
            Float.pi / 2.0

        node.position =
            SCNVector3(
                x,
                0,
                0
            )

        projectionPlaneNode =
            node

        scene.rootNode.addChildNode(
            node
        )
    }
    func addPhotonPath(
        _ points:
            [SIMD3<Double>]
    ) {

        guard points.count > 1
        else {
            return
        }

        let controlPoints =
            points

        addSplinePhotonPath(
            controlPoints:
                controlPoints,

            color:
                .cyan,

            radius:
                0.008,

            pointsPerSegment:
                2
        )
    }
    // ============================================================
    // CLEAR PHOTON SPLINES
    // ============================================================

    func clearPhotonPaths() {

        photonPathRoot.childNodes.forEach {
            $0.removeFromParentNode()
        }

        photonPathNodes.forEach {
            $0.removeFromParentNode()
        }

        photonPathNodes.removeAll(
            keepingCapacity: true
        )
    }
    // ============================================================
    // ADD ONE PHOTON SPLINE
    // ============================================================

    func addPhotonSpline(
        points: [SIMD3<Float>],
        index: Int
    ) {

        guard points.count >= 2 else {
            return
        }

        // --------------------------------------------------------
        // FILTER INVALID POINTS
        // --------------------------------------------------------

        let validPoints =
            points.filter {

                $0.x.isFinite &&
                $0.y.isFinite &&
                $0.z.isFinite
            }

        guard validPoints.count >= 2 else {
            return
        }

        // --------------------------------------------------------
        // CREATE PATH NODE
        // --------------------------------------------------------

        let pathNode =
            SCNNode()

        pathNode.name =
            "PhotonPath_\(index)"

        // --------------------------------------------------------
        // CREATE SEGMENTS
        //
        // Each pair of adjacent photon positions becomes one
        // short cylinder.
        //
        // This gives us a continuous visible spline-like path.
        // --------------------------------------------------------

        for i in 0..<(validPoints.count - 1) {

            let p0 =
                validPoints[i]

            let p1 =
                validPoints[i + 1]

            let start =
                SCNVector3(
                    p0.x,
                    p0.y,
                    p0.z
                )

            let end =
                SCNVector3(
                    p1.x,
                    p1.y,
                    p1.z
                )

            let segment =
                makePhotonSegment(
                    from:
                        start,

                    to:
                        end
                )

            pathNode.addChildNode(
                segment
            )
        }

        // --------------------------------------------------------
        // ADD COMPLETE PATH TO PHOTON ROOT
        // --------------------------------------------------------

        photonPathRoot.addChildNode(
            pathNode
        )
    }
    // ============================================================
    // PHOTON SEGMENT
    //
    // Creates one visible cylindrical segment between two photon
    // positions.
    //
    // SceneKit cylinders are aligned along their local Y axis,
    // so the cylinder is rotated to point from `from` to `to`.
    //
    // ============================================================

    private func makePhotonSegment(
        from: SCNVector3,
        to: SCNVector3
    ) -> SCNNode {

        // --------------------------------------------------------
        // CONVERT TO SIMD
        // --------------------------------------------------------

        let start =
            SIMD3<Float>(
                from.x,
                from.y,
                from.z
            )

        let end =
            SIMD3<Float>(
                to.x,
                to.y,
                to.z
            )

        // --------------------------------------------------------
        // DIRECTION
        // --------------------------------------------------------

        let delta =
            end - start

        let length =
            simd_length(delta)

        // --------------------------------------------------------
        // PROTECT AGAINST ZERO-LENGTH SEGMENTS
        // --------------------------------------------------------

        guard length > 0.000001,
              length.isFinite
        else {
            return SCNNode()
        }

        let direction =
            simd_normalize(delta)

        // --------------------------------------------------------
        // CYLINDER
        //
        // Small radius keeps the photon path thin while still
        // making it visible in SceneKit.
        // --------------------------------------------------------

        let cylinder =
            SCNCylinder(
                radius: 0.012,
                height: CGFloat(length)
            )

        // --------------------------------------------------------
        // MATERIAL
        // --------------------------------------------------------

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor.cyan

        material.emission.contents =
            UIColor.cyan

        material.lightingModel =
            .constant

        material.isDoubleSided =
            true

        cylinder.firstMaterial =
            material

        // --------------------------------------------------------
        // NODE
        // --------------------------------------------------------

        let node =
            SCNNode(
                geometry:
                    cylinder
            )

        // --------------------------------------------------------
        // POSITION
        //
        // Put the cylinder halfway between the two photon
        // positions.
        // --------------------------------------------------------

        node.position =
            SCNVector3(
                (from.x + to.x) * 0.5,
                (from.y + to.y) * 0.5,
                (from.z + to.z) * 0.5
            )

        // --------------------------------------------------------
        // ROTATE CYLINDER
        //
        // SCNCylinder points along local +Y.
        //
        // We need local +Y to point in `direction`.
        // --------------------------------------------------------

        let up =
            SIMD3<Float>(
                0,
                1,
                0
            )

        let dot =
            simd_dot(
                up,
                direction
            )

        if dot > 0.9999 {

            // Already pointing along +Y.

            node.simdOrientation =
                simd_quatf(
                    angle: 0,
                    axis:
                        SIMD3<Float>(
                            1,
                            0,
                            0
                        )
                )

        } else if dot < -0.9999 {

            // Pointing along -Y.

            node.simdOrientation =
                simd_quatf(
                    angle: .pi,
                    axis:
                        SIMD3<Float>(
                            1,
                            0,
                            0
                        )
                )

        } else {

            // ----------------------------------------------------
            // GENERAL ROTATION
            // ----------------------------------------------------

            let rotationAxis =
                simd_normalize(
                    simd_cross(
                        up,
                        direction
                    )
                )

            let clampedDot =
                max(
                    -1.0,
                    min(
                        1.0,
                        Double(dot)
                    )
                )

            let angle =
                acos(
                    clampedDot
                )

            node.simdOrientation =
                simd_quatf(
                    angle:
                        Float(angle),

                    axis:
                        rotationAxis
                )
        }

        return node
    }
}

