import Foundation

// Minimal local equivalents used only by PrayerAutoAdvanceController.swift.
// They keep the feature extractor self-contained without importing Accelerate
// into the speech capture file.
typealias vDSP_Length = UInt

func vDSP_measqv(
    _ values: UnsafePointer<Float>,
    _ stride: Int,
    _ result: inout Float,
    _ count: vDSP_Length
) {
    guard count > 0 else {
        result = 0
        return
    }
    var sum: Float = 0
    var index = 0
    for _ in 0..<Int(count) {
        let value = values[index]
        sum += value * value
        index += stride
    }
    result = sum / Float(count)
}
