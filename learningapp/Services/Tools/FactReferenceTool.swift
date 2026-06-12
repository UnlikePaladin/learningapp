import Foundation
import FoundationModels

/// Quick lookup of well-known scientific, mathematical, and astronomical constants.
/// Saves the model from hallucinating values and reduces token-output errors.
struct FactReferenceTool: Tool {
    let name = "lookupFact"
    let description = "Looks up a known scientific/math/astronomical constant by name (e.g., 'speed of light', 'pi', 'gravity', 'avogadro number')."

    @Generable
    struct Arguments {
        @Guide(description: "The fact or constant to look up. E.g., 'speed of light', 'pi', 'avogadro number', 'gravity', 'water boiling point'.")
        var fact: String
    }

    private static let facts: [String: String] = [
        // Physical constants
        "speed of light": "299,792,458 m/s",
        "gravitational acceleration": "9.80665 m/s² (Earth surface)",
        "gravity": "9.80665 m/s² (Earth surface)",
        "gravitational constant": "6.674 × 10⁻¹¹ N·m²/kg²",
        "boltzmann constant": "1.381 × 10⁻²³ J/K",
        "planck constant": "6.626 × 10⁻³⁴ J·s",
        "elementary charge": "1.602 × 10⁻¹⁹ C",
        "electron mass": "9.109 × 10⁻³¹ kg",
        "proton mass": "1.673 × 10⁻²⁷ kg",
        "neutron mass": "1.675 × 10⁻²⁷ kg",
        "atomic mass unit": "1.661 × 10⁻²⁷ kg",
        "speed of sound": "343 m/s (in air at 20°C)",
        "atmospheric pressure": "101.325 kPa (1 atm at sea level)",
        "vacuum permittivity": "8.854 × 10⁻¹² F/m",

        // Math constants
        "pi": "3.14159265358979",
        "e": "2.71828182845905",
        "euler number": "2.71828182845905",
        "golden ratio": "1.618033988749895",
        "phi": "1.618033988749895",
        "square root of 2": "1.41421356237310",
        "square root of 3": "1.73205080756888",

        // Chemistry
        "avogadro's number": "6.022 × 10²³ mol⁻¹",
        "avogadro number": "6.022 × 10²³ mol⁻¹",
        "gas constant": "8.314 J/(mol·K)",
        "atomic weight hydrogen": "1.008",
        "atomic weight carbon": "12.011",
        "atomic weight oxygen": "15.999",
        "atomic weight nitrogen": "14.007",
        "atomic weight sodium": "22.990",
        "atomic weight chlorine": "35.45",
        "atomic weight iron": "55.845",

        // Temperature reference points
        "water freezing point": "0 °C / 32 °F / 273.15 K",
        "water boiling point": "100 °C / 212 °F / 373.15 K (at 1 atm)",
        "absolute zero": "-273.15 °C / -459.67 °F / 0 K",
        "human body temperature": "37 °C / 98.6 °F",

        // Astronomical
        "earth radius": "6,371 km (mean)",
        "earth equatorial radius": "6,378 km",
        "earth mass": "5.972 × 10²⁴ kg",
        "earth orbital period": "365.25 days",
        "earth rotation period": "23 hours, 56 minutes (sidereal day)",
        "moon distance": "384,400 km (average)",
        "moon radius": "1,737 km",
        "moon mass": "7.342 × 10²² kg",
        "sun mass": "1.989 × 10³⁰ kg",
        "sun radius": "696,340 km",
        "sun-earth distance": "149,597,870.7 km (1 AU)",
        "light year": "9.461 × 10¹² km",
        "parsec": "3.086 × 10¹³ km (3.262 light years)",

        // Earth science
        "earth atmosphere composition": "78% N₂, 21% O₂, 0.93% Ar, 0.04% CO₂",
        "earth's age": "approximately 4.54 billion years",
    ]

    func call(arguments: Arguments) async throws -> String {
        let raw = arguments.fact.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let key = normalize(raw)

        // 1. Exact normalized match
        if let value = Self.facts[raw] {
            return "\(raw.capitalized): \(value)"
        }
        for (factKey, value) in Self.facts {
            if normalize(factKey) == key {
                return "\(factKey.capitalized): \(value)"
            }
        }

        // 2. Word-boundary match: every word in the search must appear as a whole word
        // in the candidate key (or vice versa). Prevents "pi" matching "precipitation".
        let queryWords = Set(words(in: raw))
        guard !queryWords.isEmpty else {
            return "Fact '\(arguments.fact)' not found."
        }

        var bestMatch: (key: String, value: String, score: Int)?
        for (factKey, factValue) in Self.facts {
            let factWords = Set(words(in: factKey))
            // The query must contain ALL the fact's words (e.g., user asks "speed of light in vacuum"
            // → matches "speed of light"). Single-word keys like "pi" can ONLY match via exact lookup
            // above; they must NOT match if the user typed something else longer.
            guard !factWords.isEmpty else { continue }
            if factWords.isSubset(of: queryWords) {
                let score = factWords.count
                if score > (bestMatch?.score ?? 0) {
                    bestMatch = (factKey, factValue, score)
                }
            }
        }

        if let match = bestMatch {
            return "\(match.key.capitalized): \(match.value)"
        }

        return "Fact '\(arguments.fact)' not found in the reference. Use only well-known constants like 'speed of light', 'pi', 'gravity', 'avogadro number', or 'water boiling point'."
    }

    /// Lowercased, punctuation-stripped string for direct comparison.
    private func normalize(_ s: String) -> String {
        s.lowercased()
            .components(separatedBy: CharacterSet.punctuationCharacters)
            .joined()
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Tokenize a key into individual words, with at-least-3-char length and stopword filtering.
    private func words(in s: String) -> [String] {
        let stop: Set<String> = ["of", "the", "a", "an", "and", "in", "to", "for"]
        return s.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count >= 2 && !stop.contains($0) }
    }
}
