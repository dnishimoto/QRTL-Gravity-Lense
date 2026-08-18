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

struct LensingSceneView:
    UIViewRepresentable {

    @ObservedObject var controller:
        LensingSceneController

    func makeUIView(
        context:
            Context
    ) -> SCNView {

        let view =
            SCNView()

        view.scene =
            controller.scene

        view.allowsCameraControl =
            true

        view.autoenablesDefaultLighting =
            false

        view.backgroundColor =
            .black

        view.antialiasingMode =
            .multisampling4X

        return view
    }

    func updateUIView(
        _ uiView:
            SCNView,

        context:
            Context
    ) {
    }
}

