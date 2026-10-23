import Darwin
import Foundation

/// Speicherverbrauch von Dropper – derselbe Wert wie „Speicher“ in der Aktivitätsanzeige.
enum MemoryUsage {
    static let launchDate = Date()
    private(set) static var peak: UInt64 = 0

    /// Aktueller Verbrauch in Bytes (`phys_footprint`), `nil` falls nicht lesbar.
    static func current() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { raw in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), raw, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }
        peak = max(peak, info.phys_footprint)
        return info.phys_footprint
    }

    /// Laufzeit seit dem Start, z. B. „3 Std. 12 Min.“.
    static var uptimeText: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: Date().timeIntervalSince(launchDate)) ?? ""
    }
}
