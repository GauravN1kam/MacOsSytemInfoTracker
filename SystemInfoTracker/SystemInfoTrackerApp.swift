//
//  SystemInfoTrackerApp.swift
//  SystemInfoTracker
//
//  Created by Gaurav Nikam on 19/04/26.
//

import SwiftUI

@main
struct SystemInfoTrackerApp: App {
    @StateObject private var monitor = SystemMonitor()
    
    var body: some Scene {
        // 'label' is what shows in the bar itself
        // 'content' is what shows when you click it
        MenuBarExtra {
            VStack {
                Text("System Health")
                    .font(.headline)
                Text("CPU Usage: \(Int(monitor.cpuUsage))%")
                
                Text("System Ram consumption: \(monitor.ramUsage)")
                
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding()
        } label: {
            // This is the icon/text always visible in the menu bar
            HStack {
                Image(systemName: "cpu")
                Text("\(Int(monitor.cpuUsage))%")
            }
        }
        .menuBarExtraStyle(.window) // Uses a popover style instead of a standard list
    }
}
