//
//  TrainerWatchApp.swift
//  TrainerWatch Watch App
//
//  Created by Iván Karkoszka on 09/09/2026.
//

import SwiftUI
import TrainerCore

@main
struct TrainerWatch_Watch_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.locale, ConfiguracionDeIdioma.localeEfectivo)
        }
    }
}
