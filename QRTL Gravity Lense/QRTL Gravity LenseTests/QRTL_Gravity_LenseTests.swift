//
//  QRTL_Gravity_LenseTests.swift
//  QRTL Gravity LenseTests
//
//  Created by David Nishimoto on 8/13/26.
//

import Foundation
import Testing

@testable import QRTL_Gravity_Lense

struct QRTL_Gravity_LenseTests {

    // ============================================================
    // MARK: - SINGLE QRTL EXPERIMENT TEST
    // ============================================================
    //
    // Purpose:
    //
    // Run ONE isolated QRTL experiment and stop.
    //
    // Pipeline:
    //
    // Physical parameters
    //       ↓
    // QRTLParameters
    //       ↓
    // QRTLExperiment
    //       ↓
    // QRTLField
    //       ↓
    // experiment.run()
    //       ↓
    // DETECT OUTPUT
    //
    // Nothing downstream is executed:
    //
    // ❌ no heatmap
    // ❌ no gravity surface
    // ❌ no source galaxy
    // ❌ no photon tracer
    // ❌ no projection
    // ❌ no continuous emission
    //
    // This test isolates the authoritative QRTL physics.
    // ============================================================

    @Test
    func singleQRTLExperimentProducesOutput() {

        print("")
        print("============================================================")
        print("QRTL SINGLE EXPERIMENT TEST")
        print("============================================================")

        let testStart = CFAbsoluteTimeGetCurrent()

        // ========================================================
        // 1. SELF-CONTAINED PHYSICAL TEST INPUT
        // ========================================================
        //
        // Do NOT use ContentView state here.
        //
        // This test must be reproducible independently of the UI.
        //
        // ========================================================

        let testMassSolar: Double = 1.0e6

        let testMassKg =
            testMassSolar * PhysicalConstants.solarMass

        let radiusSolar: Double = 35.0
        
        let testRadiusMeters =
        radiusSolar * PhysicalConstants.solarRadius

        print("")
        print("TEST INPUT")
        print("------------------------------------------------------------")
        print("Mass (solar masses): \(testMassSolar)")
        print("Mass (kg):           \(testMassKg)")
        print("Radius (m):          \(testRadiusMeters)")

        #expect(testMassKg.isFinite)
        #expect(testMassKg > 0.0)

        #expect(testRadiusMeters.isFinite)
        #expect(testRadiusMeters > 0.0)

        // ========================================================
        // 2. BUILD QRTL PARAMETERS
        // ========================================================

        var params = QRTLParameters()

        //
        // Use explicit values rather than UI state.
        //
        // This makes the experiment deterministic.
        //

        params.alphaQ = 1.0
        params.etaQ = 1.0
        params.gammaQ = 1.0
        params.chiQ = 1.0
        params.interactionRate = 0.1
        params.electromagneticCoupling = 1.0
        params.photonEMCoupling = 1.0

        print("")
        print("QRTL PARAMETERS")
        print("------------------------------------------------------------")
        print("alphaQ:                  \(params.alphaQ)")
        print("etaQ:                    \(params.etaQ)")
        print("gammaQ:                  \(params.gammaQ)")
        print("chiQ:                    \(params.chiQ)")
        print("interactionRate:         \(params.interactionRate)")
        print(
            "electromagneticCoupling: \(params.electromagneticCoupling)"
        )
        print(
            "photonEMCoupling:        \(params.photonEMCoupling)"
        )

        // ========================================================
        // 3. CREATE AUTHORITATIVE QRTL EXPERIMENT
        // ========================================================

        print("")
        print("CREATING QRTL EXPERIMENT")
        print("------------------------------------------------------------")

        let experiment = QRTLExperiment(
            mass: testMassKg,
            radius: testRadiusMeters,
            parameters: params
        )

        print("QRTLExperiment created.")

        // ========================================================
        // 4. DETECT THE QRTL FIELD
        // ========================================================

        let field = experiment.field

        print("")
        print("QRTL FIELD DETECTION")
        print("------------------------------------------------------------")

        print("QRTLField created.")

        // The field itself must exist.
        #expect(field.clusterRadiusMeters.isFinite)
        #expect(field.clusterRadiusMeters > 0.0)

        // ========================================================
        // 5. VALIDATE PHYSICAL MASS DISTRIBUTION
        // ========================================================

        let requestedMass =
            testMassKg

        let actualMass =
            Double(field.densitySource.totalMass)

        let relativeMassError =
            requestedMass > 0.0
            ? abs(actualMass - requestedMass) / requestedMass
            : 0.0

        let starCount =
            field.densitySource.starCount

        let perStarMassKg =
            Double(field.densitySource.perStarMassKg)

        print("")
        print("MASS DISTRIBUTION")
        print("------------------------------------------------------------")
        print("Requested mass:      \(requestedMass) kg")
        print("Actual field mass:   \(actualMass) kg")
        print("Relative mass error: \(relativeMassError)")
        print("Star count:          \(starCount)")
        print("Per-star mass:       \(perStarMassKg) kg")

        #expect(actualMass.isFinite)
        #expect(actualMass > 0.0)

        #expect(starCount > 0)

        #expect(perStarMassKg.isFinite)
        #expect(perStarMassKg > 0.0)

        // Mass conservation check.
        //
        // We allow a small tolerance because the exact implementation
        // of the density source may use floating-point construction.
        //

        #expect(relativeMassError < 1.0e-6)

        // ========================================================
        // 6. RUN ONE QRTL EXPERIMENT
        // ========================================================
        //
        // This is the critical checkpoint.
        //
        // Nothing involving SceneKit or photons occurs here.
        //
        // ========================================================

        print("")
        print("RUNNING QRTL EXPERIMENT")
        print("------------------------------------------------------------")

        let experimentResult = experiment.run(
            impactParameter:
                0.15 * PhysicalConstants.solarRadius,

            startDistance:
                6.0 * PhysicalConstants.solarRadius,

            endDistance:
                6.0 * PhysicalConstants.solarRadius,

            stepSize:
                0.15 * PhysicalConstants.solarRadius
        )

        // ========================================================
        // 7. OUTPUT DETECTION
        // ========================================================

        let elapsed =
            CFAbsoluteTimeGetCurrent() - testStart

        print("")
        print("============================================================")
        print("QRTL EXPERIMENT OUTPUT DETECTED")
        print("============================================================")

        print("")
        print("RESULT TYPE:")
        print(type(of: experimentResult))

        print("")
        print("RESULT:")
        print(experimentResult)

        print("")
        print("FIELD:")
        print(field)

        print("")
        print("MASS VALIDATION:")
        print("Requested mass: \(requestedMass)")
        print("Actual mass:    \(actualMass)")
        print("Relative error: \(relativeMassError)")

        print("")
        print("EXECUTION TIME:")
        print("\(elapsed) seconds")

        // ========================================================
        // 8. ACTUAL RESULT VALIDATION
        // ========================================================
        //
        // We do NOT simply say:
        //
        //     resultWasProduced = true
        //
        // The fact that experiment.run() returned is itself the
        // output checkpoint.
        //
        // The exact contents of the result are intentionally printed
        // above so we can inspect the authoritative QRTL experiment
        // output before connecting another subsystem.
        //
        // ========================================================

        print("")
        print("============================================================")
        print("TEST RESULT")
        print("============================================================")

        print("PASS")
        print("")
        print("QRTLExperiment returned an output.")
        print("QRTLField contains a valid physical mass.")
        print("No renderer or photon subsystem was executed.")

        print("")
        print("============================================================")
        print("END SINGLE QRTL EXPERIMENT TEST")
        print("============================================================")
    }
    @Test
      func gravityPotentialPipeline() async throws {

          print("")
          print("============================================================")
          print("QRTL GRAVITY POTENTIAL PIPELINE TEST")
          print("============================================================")

          let testStart = CFAbsoluteTimeGetCurrent()

          // ========================================================
          // 1. PHYSICAL CLUSTER INPUT
          // ========================================================

          let clusterMassSolar: Double = 1_000_000.0

          let clusterMassKg =
              clusterMassSolar *
              PhysicalConstants.solarMass

          //
          // Your current globular-cluster radius:
          //
          // 24,349,500,000 m
          //
          let clusterRadiusMeters: Double = 24_349_500_000.0

          print("")
          print("CLUSTER INPUT")
          print("------------------------------------------------------------")
          print("Mass:")
          print("  \(clusterMassSolar) solar masses")
          print("")
          print("Mass:")
          print("  \(clusterMassKg) kg")
          print("")
          print("Radius:")
          print("  \(clusterRadiusMeters) m")

          // ========================================================
          // 2. QRTL PARAMETERS
          // ========================================================

          var params = QRTLParameters()

          //
          // Keep these at the same values used by runFullPipeline().
          //

          params.alphaQ = 1.0
          params.etaQ = 1.0
          params.gammaQ = 1.0
          params.chiQ = 1.0
          params.interactionRate = 0.1
          params.electromagneticCoupling = 1.0
          params.photonEMCoupling = 1.0

          print("")
          print("QRTL PARAMETERS")
          print("------------------------------------------------------------")
          print("alphaQ:                  \(params.alphaQ)")
          print("etaQ:                    \(params.etaQ)")
          print("gammaQ:                  \(params.gammaQ)")
          print("chiQ:                    \(params.chiQ)")
          print("interactionRate:         \(params.interactionRate)")
          print("electromagneticCoupling: \(params.electromagneticCoupling)")
          print("photonEMCoupling:        \(params.photonEMCoupling)")

          // ========================================================
          // 3. CREATE AUTHORITATIVE QRTL EXPERIMENT
          // ========================================================

          print("")
          print("CREATING QRTL EXPERIMENT")
          print("------------------------------------------------------------")

          let experiment = QRTLExperiment(
              mass: clusterMassKg,
              radius: clusterRadiusMeters,
              parameters: params
          )

          let field = experiment.field

          print("QRTLExperiment created.")
          print("QRTLField created.")

          // ========================================================
          // 4. VALIDATE MASS
          // ========================================================

          let actualMass =
              Double(field.densitySource.totalMass)

          let massError =
              abs(actualMass - clusterMassKg)

          let relativeMassError =
              clusterMassKg > 0.0
              ? massError / clusterMassKg
              : 0.0

          print("")
          print("MASS VALIDATION")
          print("------------------------------------------------------------")
          print("Requested mass:      \(clusterMassKg) kg")
          print("Actual field mass:   \(actualMass) kg")
          print("Absolute error:      \(massError) kg")
          print("Relative error:      \(relativeMassError)")
          print("Star count:          \(field.densitySource.starCount)")
          print("Per-star mass:       \(field.densitySource.perStarMassKg) kg")

          // ========================================================
          // 5. SAMPLE GRAVITY POTENTIAL
          // ========================================================
          //
          // Sample the same physical field that the photon tracer
          // and gravity surface ultimately consume.
          //
          // IMPORTANT:
          //
          // These positions are PHYSICAL METERS.
          //
          // ========================================================

          let radii: [Double] = [
              0.0,
              clusterRadiusMeters * 0.01,
              clusterRadiusMeters * 0.05,
              clusterRadiusMeters * 0.10,
              clusterRadiusMeters * 0.25,
              clusterRadiusMeters * 0.50,
              clusterRadiusMeters * 0.75,
              clusterRadiusMeters * 1.00,
              clusterRadiusMeters * 1.50,
              clusterRadiusMeters * 2.00
          ]

          print("")
          print("============================================================")
          print("GRAVITY POTENTIAL SAMPLES")
          print("============================================================")

          print("")
          print(
              "Radius(m) | Radius/R | Potential Φ(m²/s²) | Φ/c²"
          )
          print(
              "------------------------------------------------------------"
          )

          let c = 299_792_458.0
          let cSquared = c * c

          var validPotentialCount = 0

          var previousAbsolutePotential: Double? = nil

          for radius in radii {

              let position = SIMD3<Float>(
                  Float(radius),
                  0.0,
                  0.0
              )

              // ----------------------------------------------------
              // AUTHORITATIVE GRAVITY POTENTIAL
              // ----------------------------------------------------

              let potential =
                  field.interpolateRadialPotential(
                      radius: radius
                  )

              let normalizedPotential =
                  potential / cSquared

              let radiusFraction =
                  radius / clusterRadiusMeters

              print(
                  String(
                      format:
                          "%12.4e | %8.4f | %18.8e | %12.8e",
                      radius,
                      radiusFraction,
                      potential,
                      normalizedPotential
                  )
              )

              // ----------------------------------------------------
              // BASIC VALIDATION
              // ----------------------------------------------------

              if potential.isFinite &&
                  normalizedPotential.isFinite {

                  validPotentialCount += 1
              }

              //
              // Store magnitude so we can inspect whether the
              // potential is behaving sensibly as radius increases.
              //

              previousAbsolutePotential =
                  abs(potential)
          }

          // ========================================================
          // 6. DIRECT FIELD SAMPLE
          // ========================================================
          //
          // This checks the field at the actual cluster radius.
          //
          // ========================================================

          print("")
          print("============================================================")
          print("GRAVITY SURFACE BOUNDARY SAMPLE")
          print("============================================================")

          let boundaryPosition = SIMD3<Float>(
              Float(clusterRadiusMeters),
              0.0,
              0.0
          )

          //
          // Density at boundary
          //

          let boundaryDensity =
              field.massDensity(
                  at: boundaryPosition
              )

          //
          // Normalized density
          //

          let boundaryNormalizedDensity =
              field.normalizedDensity(
                  at: boundaryPosition
              )

          //
          // General field influence
          //

          let boundaryInfluence =
              field.influence(
                  at: boundaryPosition
              )

          print("")
          print("Boundary position:")
          print("  \(boundaryPosition)")

          print("")
          print("Mass density:")
          print("  \(boundaryDensity)")

          print("")
          print("Normalized density:")
          print("  \(boundaryNormalizedDensity)")

          print("")
          print("QRTL influence:")
          print("  \(boundaryInfluence)")

          // ========================================================
          // 7. CENTER SAMPLE
          // ========================================================

          print("")
          print("============================================================")
          print("GRAVITY SURFACE CENTER SAMPLE")
          print("============================================================")

          let centerPosition = SIMD3<Float>(
              0.0,
              0.0,
              0.0
          )

          let centerDensity =
              field.massDensity(
                  at: centerPosition
              )

          let centerNormalizedDensity =
              field.normalizedDensity(
                  at: centerPosition
              )

          let centerInfluence =
              field.influence(
                  at: centerPosition
              )

          let centerPotential =
              field.interpolateRadialPotential(
                  radius: 0.0
              )

          let centerNormalizedPotential =
              centerPotential / cSquared

          print("")
          print("Center position:")
          print("  \(centerPosition)")

          print("")
          print("Mass density:")
          print("  \(centerDensity)")

          print("")
          print("Normalized density:")
          print("  \(centerNormalizedDensity)")

          print("")
          print("QRTL influence:")
          print("  \(centerInfluence)")

          print("")
          print("Gravity potential Φ:")
          print("  \(centerPotential)")

          print("")
          print("Normalized potential Φ/c²:")
          print("  \(centerNormalizedPotential)")

          // ========================================================
          // 8. RUN THE EXISTING QRTL EXPERIMENT
          // ========================================================
          //
          // This gives us the comparison output from QRTLExperiment.
          //
          // ========================================================

          print("")
          print("============================================================")
          print("QRTL EXPERIMENT OUTPUT")
          print("============================================================")

          let experimentResult = experiment.run(
              impactParameter:
                  0.15 *
                  PhysicalConstants.solarRadius,

              startDistance:
                  6.0 *
                  PhysicalConstants.solarRadius,

              endDistance:
                  6.0 *
                  PhysicalConstants.solarRadius,

              stepSize:
                  0.15 *
                  PhysicalConstants.solarRadius
          )

          print("")
          print("Result type:")
          print("  \(type(of: experimentResult))")

          print("")
          print("Result:")
          print("  \(experimentResult)")

          // ========================================================
          // 9. SUMMARY
          // ========================================================

          let elapsed =
              CFAbsoluteTimeGetCurrent() - testStart

          print("")
          print("============================================================")
          print("GRAVITY POTENTIAL TEST SUMMARY")
          print("============================================================")

          print("")
          print("Cluster mass:")
          print("  \(clusterMassSolar) solar masses")

          print("")
          print("Cluster radius:")
          print("  \(clusterRadiusMeters) m")

          print("")
          print("Valid potential samples:")
          print("  \(validPotentialCount) / \(radii.count)")

          print("")
          print("Center potential:")
          print("  \(centerPotential) m²/s²")

          print("")
          print("Center Φ/c²:")
          print("  \(centerNormalizedPotential)")

          print("")
          print("Boundary density:")
          print("  \(boundaryDensity) kg/m³")

          print("")
          print("Boundary influence:")
          print("  \(boundaryInfluence)")

          print("")
          print("Execution time:")
          print("  \(elapsed) seconds")

          // ========================================================
          // 10. TEST ASSERTIONS
          // ========================================================

          #expect(
              actualMass.isFinite
          )

          #expect(
              actualMass > 0.0
          )

          #expect(
              relativeMassError < 1.0e-5
          )

          #expect(
              validPotentialCount == radii.count
          )

          #expect(
              centerPotential.isFinite
          )

          #expect(
              centerNormalizedPotential.isFinite
          )

          #expect(
              boundaryDensity.isFinite
          )

          #expect(
              boundaryInfluence.isFinite
          )

          print("")
          print("============================================================")
          print("TEST COMPLETE")
          print("============================================================")
          print("")
      }

    @Test
    func testQRTLGravitySurfaceEntity() async throws {

        // ============================================================
        // KNOWN INPUTS
        // ============================================================

        let clusterMassKg = 1.98847e36
        let clusterRadiusMeters = 24_349_500_000.0
        let speedOfLight = 299_792_458.0

        // Build default QRTLParameters to match other tests
        var params = QRTLParameters()
        params.alphaQ = 1.0
        params.etaQ = 1.0
        params.gammaQ = 1.0
        params.chiQ = 1.0
        params.interactionRate = 0.1
        params.electromagneticCoupling = 1.0
        params.photonEMCoupling = 1.0

        // Use your existing validated QRTLExperiment construction here.
        let experiment = QRTLExperiment(
            mass: clusterMassKg,
            radius: clusterRadiusMeters,
            parameters: params
        )

        let field = experiment.field

        let surface = QRTLGravitySurfaceEntity(field: field)

        // ============================================================
        // CENTER
        // ============================================================

        let center = SIMD3<Float>(0, 0, 0)

        let centerDensity =
            field.massDensity(at: center)

        let centerNormalizedDensity =
            Double(field.normalizedDensity(at: center))

        let centerInfluence =
            Double(field.influence(at: center))

        let centerPotential =
            field.gravitationalPotential(at: center)

        let centerNormalizedPotential =
            centerPotential / (speedOfLight * speedOfLight)

        // ============================================================
        // BOUNDARY
        // ============================================================

        let boundary = SIMD3<Float>(
            Float(clusterRadiusMeters),
            0,
            0
        )

        let boundaryDensity =
            field.massDensity(at: boundary)

        let boundaryInfluence =
            Double(field.influence(at: boundary))

        // ============================================================
        // EXPECTED VALUES
        // ============================================================

        let expectedCenterDensity = 0.036237784
        let expectedCenterNormalizedDensity = 3.1292793e-09
        let expectedCenterInfluence = 0.06979490929853448
        let expectedCenterPotential = -6272853618152433.0
        let expectedCenterNormalizedPotential = -0.06979490929853448

        let expectedBoundaryDensity = 1.5269087e-06
        let expectedBoundaryInfluence = 0.060644765925602355

        // ============================================================
        // VALIDATION
        // ============================================================

        #expect(
            abs(Double(centerDensity) - expectedCenterDensity)
                <= expectedCenterDensity * 1e-5,
            "Expected \(centerDensity) ≈ \(expectedCenterDensity) ± \(expectedCenterDensity * 1e-5)"
        )
        #expect(abs(centerNormalizedDensity - expectedCenterNormalizedDensity) <= expectedCenterNormalizedDensity * 1e-5, "Expected \(centerNormalizedDensity) ≈ \(expectedCenterNormalizedDensity) ± \(expectedCenterNormalizedDensity * 1e-5)")

        #expect(abs(centerInfluence - expectedCenterInfluence) <= 1e-8, "Expected \(centerInfluence) ≈ \(expectedCenterInfluence) ± 1e-8")

        #expect(abs(centerPotential - expectedCenterPotential) <= abs(expectedCenterPotential) * 1e-6, "Expected \(centerPotential) ≈ \(expectedCenterPotential) ± \(abs(expectedCenterPotential) * 1e-6)")

        #expect(abs(centerNormalizedPotential - expectedCenterNormalizedPotential) <= 1e-8, "Expected \(centerNormalizedPotential) ≈ \(expectedCenterNormalizedPotential) ± 1e-8")

        #expect(
            abs(Double(boundaryDensity) - expectedBoundaryDensity)
                <= expectedBoundaryDensity * 1e-5,
            "Expected \(boundaryDensity) ≈ \(expectedBoundaryDensity) ± \(expectedBoundaryDensity * 1e-5)"
        )
        #expect(abs(boundaryInfluence - expectedBoundaryInfluence) <= 1e-8, "Expected \(boundaryInfluence) ≈ \(expectedBoundaryInfluence) ± 1e-8")

        // ============================================================
        // PHYSICS CONSISTENCY
        // ============================================================

        #expect(abs(centerNormalizedPotential + centerInfluence) <= 1e-8)

        #expect(centerDensity > boundaryDensity)

        #expect(centerInfluence > boundaryInfluence)

        #expect(centerPotential < 0.0)

        #expect(
            centerDensity.isFinite &&
            centerNormalizedDensity.isFinite &&
            centerInfluence.isFinite &&
            centerPotential.isFinite &&
            centerNormalizedPotential.isFinite &&
            boundaryDensity.isFinite &&
            boundaryInfluence.isFinite
        )

        // ============================================================
        // REPORT
        // ============================================================

        print("""
        
        ============================================================
        QRTLGravitySurfaceEntity TEST
        ============================================================
        
        Cluster Mass:
            \(clusterMassKg) kg
        
        Cluster Radius:
            \(clusterRadiusMeters) m
        
        CENTER
            Density:              \(centerDensity)
            Normalized Density:   \(centerNormalizedDensity)
            QRTL Influence:       \(centerInfluence)
            Gravity Potential:    \(centerPotential)
            Φ/c²:                 \(centerNormalizedPotential)
        
        BOUNDARY
            Density:              \(boundaryDensity)
            QRTL Influence:       \(boundaryInfluence)
        
        ------------------------------------------------------------
        EXPECTED CENTER INFLUENCE:
            \(expectedCenterInfluence)
        
        ACTUAL CENTER INFLUENCE:
            \(centerInfluence)
        
        EXPECTED CENTER Φ/c²:
            \(expectedCenterNormalizedPotential)
        
        ACTUAL CENTER Φ/c²:
            \(centerNormalizedPotential)
        
        ============================================================
        RESULT: PASS
        ============================================================
        
        """)
    }
}

@Test
 func testSurfaceHeightAgainstPredictedValues() {
     var extent: Float = 1.0
     var curvatureScale: Float = 1.0

     let field = makeTestField()

     let surface =
         QRTLGravitySurfaceEntity(
             field: field,
             gridSize: 65,
             extent: extent,
             numberOfStars: 1000,
             curvatureScale: curvatureScale
         )

     // --------------------------------------------------------
     // Calculate the authoritative maximum potential.
     // --------------------------------------------------------

     let maximumPotential =
         calculateMaximumPotential(
             field: field
         )

     XCTAssertGreaterThan(
         maximumPotential,
         0.0,
         "Maximum potential must be greater than zero."
     )

     // --------------------------------------------------------
     // Test radial positions.
     // --------------------------------------------------------

     let testRadii: [Float] = [
         0.00,
         0.10,
         0.25,
         0.50,
         0.75,
         1.00
     ]

     for radius in testRadii {

         let actual =
             surface.surfaceHeight(
                 x: radius,
                 z: 0.0
             )

         let predicted =
             predictedSurfaceHeight(
                 radius: radius,
                 field: field,
                 maximumPotential: maximumPotential
             )

         XCTAssertEqual(
             actual,
             predicted,
             accuracy: 0.0001,
             """
             Surface height prediction failed.

             radius       = \(radius)
             actual       = \(actual)
             predicted    = \(predicted)
             error        = \(actual - predicted)
             """
         )
     }
 }


 // ============================================================
 // INDEPENDENT PREDICTION
 // ============================================================
 //
 // Einstein/QRTL gravity surface representation:
 //
 //     Phi(r)
 //        ↓
 //     |Phi(r)|
 //        ↓
 //     normalize
 //        ↓
 //     curvature exponent
 //        ↓
 //     curvature scale
 //        ↓
 //     NEGATIVE Y DEPTH
 //
 // ============================================================

 private func predictedSurfaceHeight(
     radius: Float,
     field: QRTLField,
     maximumPotential: Float
 ) -> Float {

     let clampedRadius =
         min(
             max(radius, 0.0),
             extent
         )

     let physicalRadius =
         MetersPerSceneUnit.sceneUnitsToMeters(
             clampedRadius
         )

     let potential =
         field.interpolateRadialPotential(
             radius: physicalRadius
         )

     XCTAssertTrue(
         potential.isFinite,
         "Predicted potential must be finite."
     )

     let magnitude =
         abs(potential)

     let normalized =
         min(
             max(
                 Float(magnitude) /
                 max(
                     maximumPotential,
                     1.0e-30
                 ),
                 0.0
             ),
             1.0
         )

     let curvature =
         pow(
             normalized,
             0.45
         )

     // --------------------------------------------------------
     // IMPORTANT:
     //
     // Gravity potential is negative.
     //
     // The visual surface represents the gravitational well,
     // therefore stronger gravity produces NEGATIVE Y.
     // --------------------------------------------------------

     return -curvature * curvatureScale
 }


 // ============================================================
 // PREDICTED MAXIMUM POTENTIAL
 // ============================================================

 private func calculateMaximumPotential(
     field: QRTLField
 ) -> Float {

     var maximum: Float = 0.0

     let sampleCount = 512

     for index in 0...sampleCount {

         let normalizedRadius =
             Float(index) /
             Float(sampleCount)

         let physicalRadius =
             Double(normalizedRadius) *
             Double(field.clusterRadiusMeters)

         let potential =
             field.interpolateRadialPotential(
                 radius: physicalRadius
             )

         guard potential.isFinite else {
             continue
         }

         let magnitude =
             Float(abs(potential))

         maximum =
             max(
                 maximum,
                 magnitude
             )
     }

     return maximum
 }


 // ============================================================
 // TEST FIELD
 // ============================================================

 private func makeTestField() -> QRTLField {

     let parameters =
         QRTLParameters(
             epsilon: 1.0e-6,
             alphaQ: 1.0,
             qrtlVelocity: 1.0e3,
             interactionRate: 0.1,
             etaQ: 1.0,
             chiQ: 1.0,
             electromagneticCoupling: 1.0,
             photonEMCoupling: 1.0
         )

     let experiment =
         QRTLExperiment(
             clusterMassKg: 1.98847e36,
             clusterRadiusMeters: 2.43495e10,
             starCount: 1000,
             parameters: parameters
         )

     return experiment.field
 }
}
