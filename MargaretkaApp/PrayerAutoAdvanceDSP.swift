import Foundation

// Minimal local equivalents used only by the prayer auto-advance feature.
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

func min(_ first: Int, _ second: Int, _ third: Int) -> Int {
    Swift.min(first, Swift.min(second, third))
}
