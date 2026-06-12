import Accelerate
import Foundation

enum CosineSimilarity {
    static func calculate(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }

        var dot = 0.0
        var lhsMag = 0.0
        var rhsMag = 0.0

        vDSP_dotprD(lhs, 1, rhs, 1, &dot, vDSP_Length(lhs.count))
        vDSP_svesqD(lhs, 1, &lhsMag, vDSP_Length(lhs.count))
        vDSP_svesqD(rhs, 1, &rhsMag, vDSP_Length(rhs.count))

        let denom = sqrt(lhsMag) * sqrt(rhsMag)
        guard denom > 0 else { return 0 }
        return dot / denom
    }
}
