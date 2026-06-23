//
//  CRB_HubApp.swift
//  CRB Hub
//
//  Created by Nguyễn Hoàng Tuấn on 23/6/26.
//

import SwiftUI

@main
struct CRB_HubApp: App {
    @State private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .preferredColorScheme(.dark)
        }
    }
}
