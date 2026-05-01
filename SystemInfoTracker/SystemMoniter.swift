import Foundation
import Combine

class SystemMonitor: ObservableObject {
    @Published var cpuUsage: Double = 0.0
    @Published var ramUsage: Double = 0.0
    
    // Store the previous state of ticks
    private var previousTicks = host_cpu_load_info()
    private var hasPreviousState = false
    private var timer: Timer?
    
    init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            let cpu = self.calculateCPUPercentage()
            let ram = self.getMemoryUsage()
            DispatchQueue.main.async {
                self.cpuUsage = cpu
                self.ramUsage = ram
            }
        }
    }
    
    private func calculateCPUPercentage() -> Double {
        var resultStats = host_cpu_load_info()
        var count = UInt32(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &resultStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return 0.0 }
        
        if !hasPreviousState {
            previousTicks = resultStats
            hasPreviousState = true
            return 0.0
        }
        
        let userDiff = Double(resultStats.cpu_ticks.0 - previousTicks.cpu_ticks.0)
        let systemDiff = Double(resultStats.cpu_ticks.1 - previousTicks.cpu_ticks.1)
        let idleDiff = Double(resultStats.cpu_ticks.2 - previousTicks.cpu_ticks.2)
        let niceDiff = Double(resultStats.cpu_ticks.3 - previousTicks.cpu_ticks.3)
        
        let totalDiff = userDiff + systemDiff + idleDiff + niceDiff
        let activeDiff = userDiff + systemDiff + niceDiff
        
        // Store current for next calculation
        previousTicks = resultStats
        
        return totalDiff > 0 ? (activeDiff / totalDiff) * 100.0 : 0.0
    }
    
    func getMemoryUsage() -> Double {
        var stats = vm_statistics64()
        var count = UInt32(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            print("Error: Could not retrieve host statistics.")
            return 0.0
        }
        
        let pageSize = UInt64(vm_kernel_page_size)
        
        // 1. Calculate individual components
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        
        // Note: 'Inactive' memory is technically used, but macOS will purge it
        // if other apps need RAM. Most monitors exclude it from "Used %"
        // to give a more accurate picture of memory pressure.
        
        // 2. Total "Actually Used" Memory
        let usedMemory = active + wired + compressed
        
        // 3. Get total physical memory
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        
        // 4. Return as percentage
        let percentage = (Double(usedMemory) / Double(totalMemory)) * 100.0
        
        // Clamp the value between 0 and 100 just in case
        return max(0, min(100, percentage))
    }
}
