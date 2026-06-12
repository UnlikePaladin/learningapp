import Foundation
import FoundationModels

/// Lets the model do reliable arithmetic. Uses a safe in-house parser so bad input
/// from the model can never crash the app the way NSExpression does.
struct CalculatorTool: Tool {
    let name = "calculator"
    let description = "Evaluates a math expression and returns the result. Use for any arithmetic. Supports +, -, *, /, ^, parentheses, sqrt(), pow(x,y), abs(), log(), ln(), exp(), sin/cos/tan, min/max, floor/ceil/round, and constants pi/e."

    @Generable
    struct Arguments {
        @Guide(description: "A math expression to evaluate. Use only numbers (no commas, no units, no '==' or comparisons), standard operators (+, -, *, /, ^), parentheses, and supported functions (sqrt, pow, abs, log, ln, exp, sin, cos, tan, min, max). Examples: '2 + 3*4', 'sqrt(16) + 5', 'pow(2,10)'.")
        var expression: String
    }

    func call(arguments: Arguments) async throws -> String {
        do {
            let value = try await MathEvaluator.evaluate(arguments.expression)
            return formatNumber(value)
        } catch let error as MathError {
            return "Error: \(error.errorDescription ?? "invalid expression"). Pass only numbers and supported operators/functions — no units, no commas, no comparisons."
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    private func formatNumber(_ value: Double) -> String {
        if !value.isFinite {
            return "Error: result is not a finite number"
        }
        if value == value.rounded(), abs(value) < 1e15 {
            return String(Int64(value))
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 6
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
