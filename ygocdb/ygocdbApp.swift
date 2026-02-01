//
//  ygocdbApp.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import SwiftUI

@main
struct ygocdbApp: App {
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            SearchView()
                .preferredColorScheme(settings.appearanceMode.colorScheme)
        }
    }
}
