import Foundation
import Combine

// 1. Ensure the class is an ObservableObject
class SystemMonitor: ObservableObject {
    // 2. Mark the variable as @Published so the UI updates
    @Published var cpuUsage: Double = 0.0
    
    private var timer: Timer?

    init() {
        startMonitoring()
    }

    func startMonitoring() {
        // Use [weak self] to prevent memory leaks with the timer
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // For testing, we'll keep the random number
            // In a real app, you'd call your C-function here
            self.cpuUsage = getCPUUsage()
        }
    }
    
    func getCPUUsage() -> Double {
        var cpuLoad = host_cpu_load_info()
        var count = UInt32(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &cpuLoad) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        if result != KERN_SUCCESS { return 0.0 }
        
        // Note: To get a percentage, you must subtract the previous
        // total ticks from the current ticks.
        let totalTicks = cpuLoad.cpu_ticks.0 + cpuLoad.cpu_ticks.1 + cpuLoad.cpu_ticks.2 + cpuLoad.cpu_ticks.3
        return Double(totalTicks) // Simplified for brevity
    }
}
