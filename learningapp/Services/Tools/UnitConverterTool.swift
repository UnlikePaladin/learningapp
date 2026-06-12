import Foundation
import FoundationModels

/// Converts between common units: temperature, length, mass, volume, time, speed.
/// Lets the model give accurate conversions instead of approximating.
struct UnitConverterTool: Tool {
    let name = "unitConverter"
    let description = "Converts a value between units. Supports temperature (celsius/fahrenheit/kelvin), length (meters/feet/miles/etc), mass, volume, time, and speed."

    @Generable
    struct Arguments {
        @Guide(description: "The numeric value to convert.")
        var value: Double
        @Guide(description: "The unit the value is currently in (e.g., 'celsius', 'meters', 'pounds').")
        var fromUnit: String
        @Guide(description: "The unit to convert to (e.g., 'fahrenheit', 'feet', 'kilograms').")
        var toUnit: String
    }

    func call(arguments: Arguments) async throws -> String {
        let from = arguments.fromUnit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let to = arguments.toUnit.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Try each dimension category
        if let fromTemp = temperatureUnit(from), let toTemp = temperatureUnit(to) {
            return convert(arguments.value, from: fromTemp, to: toTemp)
        }
        if let fromLen = lengthUnit(from), let toLen = lengthUnit(to) {
            return convert(arguments.value, from: fromLen, to: toLen)
        }
        if let fromMass = massUnit(from), let toMass = massUnit(to) {
            return convert(arguments.value, from: fromMass, to: toMass)
        }
        if let fromVol = volumeUnit(from), let toVol = volumeUnit(to) {
            return convert(arguments.value, from: fromVol, to: toVol)
        }
        if let fromTime = timeUnit(from), let toTime = timeUnit(to) {
            return convert(arguments.value, from: fromTime, to: toTime)
        }
        if let fromSpeed = speedUnit(from), let toSpeed = speedUnit(to) {
            return convert(arguments.value, from: fromSpeed, to: toSpeed)
        }

        return "Error: Unsupported unit conversion from '\(arguments.fromUnit)' to '\(arguments.toUnit)'."
    }

    private func convert<U: Dimension>(_ value: Double, from: U, to: U) -> String {
        let measurement = Measurement(value: value, unit: from)
        let converted = measurement.converted(to: to)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 4
        let valueStr = formatter.string(from: NSNumber(value: converted.value)) ?? "\(converted.value)"
        return "\(valueStr) \(to.symbol)"
    }

    // MARK: - Unit lookups

    private func temperatureUnit(_ name: String) -> UnitTemperature? {
        switch name {
        case "c", "celsius", "°c": return .celsius
        case "f", "fahrenheit", "°f": return .fahrenheit
        case "k", "kelvin": return .kelvin
        default: return nil
        }
    }

    private func lengthUnit(_ name: String) -> UnitLength? {
        switch name {
        case "m", "meter", "meters": return .meters
        case "km", "kilometer", "kilometers": return .kilometers
        case "cm", "centimeter", "centimeters": return .centimeters
        case "mm", "millimeter", "millimeters": return .millimeters
        case "ft", "foot", "feet": return .feet
        case "in", "inch", "inches": return .inches
        case "mi", "mile", "miles": return .miles
        case "yd", "yard", "yards": return .yards
        default: return nil
        }
    }

    private func massUnit(_ name: String) -> UnitMass? {
        switch name {
        case "kg", "kilogram", "kilograms": return .kilograms
        case "g", "gram", "grams": return .grams
        case "mg", "milligram", "milligrams": return .milligrams
        case "lb", "lbs", "pound", "pounds": return .pounds
        case "oz", "ounce", "ounces": return .ounces
        default: return nil
        }
    }

    private func volumeUnit(_ name: String) -> UnitVolume? {
        switch name {
        case "l", "liter", "liters": return .liters
        case "ml", "milliliter", "milliliters": return .milliliters
        case "gal", "gallon", "gallons": return .gallons
        case "qt", "quart", "quarts": return .quarts
        case "cup", "cups": return .cups
        case "tbsp", "tablespoon", "tablespoons": return .tablespoons
        case "tsp", "teaspoon", "teaspoons": return .teaspoons
        default: return nil
        }
    }

    private func timeUnit(_ name: String) -> UnitDuration? {
        switch name {
        case "s", "sec", "second", "seconds": return .seconds
        case "min", "minute", "minutes": return .minutes
        case "h", "hr", "hour", "hours": return .hours
        default: return nil
        }
    }

    private func speedUnit(_ name: String) -> UnitSpeed? {
        switch name {
        case "mph", "miles_per_hour", "miles per hour": return .milesPerHour
        case "kph", "km/h", "kilometers_per_hour": return .kilometersPerHour
        case "m/s", "mps", "meters_per_second", "meters per second": return .metersPerSecond
        case "knot", "knots": return .knots
        default: return nil
        }
    }
}
