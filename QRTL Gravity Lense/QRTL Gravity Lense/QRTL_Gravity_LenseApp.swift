//
//  QRTL_Gravity_LenseApp.swift
//  QRTL Gravity Lense
//
//  Created by David Nishimoto on 8/13/26.
//

import SwiftUI
import CoreData

@main
struct QRTL_Gravity_LenseApp: App {

    let persistenceController =
        PersistenceController.shared

    var body: some Scene {

        WindowGroup {

            ContentView()
                .environment(
                    \.managedObjectContext,
                    persistenceController
                        .container
                        .viewContext
                )
        }
    }
}
