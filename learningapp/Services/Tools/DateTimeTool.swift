import Foundation
import FoundationModels

/// Lets the model do date and duration math accurately.
struct DateTimeTool: Tool {
    let name = "dateTime"
    let description = "Date math. Operations: 'difference' (years/days between two dates), 'add' (add days/months/years to a date), 'now' (current date)."

    @Generable
    struct Arguments {
        @Guide(description: "Operation: 'difference', 'add', or 'now'.")
        var operation: String
        @Guide(description: "First date in YYYY-MM-DD format. Used for 'difference' (start) or 'add' (base date). Pass empty string if not used.")
        var date1: String
        @Guide(description: "Second date in YYYY-MM-DD format. Used for 'difference' (end). Pass empty string if not used.")
        var date2: String
        @Guide(description: "Numeric amount to add. Negative for subtraction. Used only for 'add'. Pass 0 if not used.")
        var amount: Int
        @Guide(description: "Unit for 'add': 'days', 'months', or 'years'. Pass empty string if not used.")
        var unit: String
    }

    func call(arguments: Arguments) async throws -> String {
        let op = arguments.operation.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone(identifier: "UTC")
        let calendar = Calendar(identifier: .gregorian)

        switch op {
        case "now":
            let outputFormatter = DateFormatter()
            outputFormatter.dateStyle = .long
            return outputFormatter.string(from: Date())

        case "difference":
            guard let d1 = formatter.date(from: arguments.date1.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let d2 = formatter.date(from: arguments.date2.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return "Error: Dates must be in YYYY-MM-DD format."
            }
            let components = calendar.dateComponents([.year, .month, .day], from: d1, to: d2)
            let totalDays = calendar.dateComponents([.day], from: d1, to: d2).day ?? 0
            let years = components.year ?? 0
            let months = components.month ?? 0
            let days = components.day ?? 0
            return "Difference: \(years) years, \(months) months, \(days) days (\(abs(totalDays)) days total)"

        case "add":
            guard let base = formatter.date(from: arguments.date1.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return "Error: date1 must be in YYYY-MM-DD format."
            }
            let unit = arguments.unit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let component: Calendar.Component
            switch unit {
            case "day", "days": component = .day
            case "month", "months": component = .month
            case "year", "years": component = .year
            default: return "Error: unit must be 'days', 'months', or 'years'."
            }
            guard let result = calendar.date(byAdding: component, value: arguments.amount, to: base) else {
                return "Error: Could not perform date arithmetic."
            }
            return formatter.string(from: result)

        default:
            return "Error: operation must be 'difference', 'add', or 'now'."
        }
    }
}
