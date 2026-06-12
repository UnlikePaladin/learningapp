import Foundation

enum MathError: Error, LocalizedError {
    case invalidCharacter(Character)
    case unexpectedToken(String)
    case unknownFunction(String)
    case unknownIdentifier(String)
    case divisionByZero
    case arityMismatch(String)
    case malformedNumber(String)
    case empty

    var errorDescription: String? {
        switch self {
        case .invalidCharacter(let c): "Invalid character: '\(c)'"
        case .unexpectedToken(let t): "Unexpected token: \(t)"
        case .unknownFunction(let f): "Unknown function: \(f)"
        case .unknownIdentifier(let id): "Unknown identifier: \(id)"
        case .divisionByZero: "Division by zero"
        case .arityMismatch(let f): "Wrong number of arguments to \(f)"
        case .malformedNumber(let s): "Malformed number: \(s)"
        case .empty: "Expression is empty"
        }
    }
}

/// Safe recursive-descent math evaluator. Replaces NSExpression because
/// NSExpression throws Objective-C exceptions that Swift can't catch,
/// causing the app to crash on bad input from the LLM.
///
/// Supports:
/// - Decimal numbers, including scientific notation (1.5e-3)
/// - Binary operators: + - * / ^
/// - Unary minus
/// - Parentheses
/// - Constants: pi, e
/// - Functions: sqrt, abs, pow(x,y), log, ln, exp, sin, cos, tan, min(x,y),
///   max(x,y), floor, ceil, round
struct MathEvaluator {
    private let chars: [Character]
    private var pos = 0

    private init(_ str: String) {
        // Strip commas (1,000 → 1000), whitespace, and lowercase identifiers
        let cleaned = str
            .replacingOccurrences(of: ",", with: "")
            .filter { !$0.isWhitespace }
            .lowercased()
        self.chars = Array(cleaned)
    }

    static func evaluate(_ str: String) throws -> Double {
        var ev = MathEvaluator(str)
        guard !ev.chars.isEmpty else { throw MathError.empty }
        let result = try ev.parseExpression()
        guard ev.pos == ev.chars.count else {
            throw MathError.unexpectedToken(String(ev.chars[ev.pos]))
        }
        return result
    }

    // MARK: - Grammar

    // expression := term (('+' | '-') term)*
    private mutating func parseExpression() throws -> Double {
        var left = try parseTerm()
        while pos < chars.count, chars[pos] == "+" || chars[pos] == "-" {
            let op = chars[pos]; pos += 1
            let right = try parseTerm()
            left = (op == "+") ? left + right : left - right
        }
        return left
    }

    // term := factor (('*' | '/') factor)*
    private mutating func parseTerm() throws -> Double {
        var left = try parseFactor()
        while pos < chars.count, chars[pos] == "*" || chars[pos] == "/" {
            let op = chars[pos]; pos += 1
            let right = try parseFactor()
            if op == "*" {
                left *= right
            } else {
                guard right != 0 else { throw MathError.divisionByZero }
                left /= right
            }
        }
        return left
    }

    // factor := unary ('^' factor)?     -- right-associative
    private mutating func parseFactor() throws -> Double {
        let base = try parseUnary()
        if pos < chars.count, chars[pos] == "^" {
            pos += 1
            let exp = try parseFactor()
            return pow(base, exp)
        }
        return base
    }

    // unary := ('-' | '+') unary | primary
    private mutating func parseUnary() throws -> Double {
        if pos < chars.count, chars[pos] == "-" {
            pos += 1
            return try -parseUnary()
        }
        if pos < chars.count, chars[pos] == "+" {
            pos += 1
            return try parseUnary()
        }
        return try parsePrimary()
    }

    // primary := number | '(' expression ')' | function-or-identifier
    private mutating func parsePrimary() throws -> Double {
        guard pos < chars.count else { throw MathError.unexpectedToken("end of input") }
        let c = chars[pos]

        if c.isNumber || c == "." {
            return try parseNumber()
        }
        if c == "(" {
            pos += 1
            let value = try parseExpression()
            guard pos < chars.count, chars[pos] == ")" else {
                throw MathError.unexpectedToken("expected ')'")
            }
            pos += 1
            return value
        }
        if c.isLetter {
            return try parseIdentifier()
        }
        throw MathError.invalidCharacter(c)
    }

    private mutating func parseNumber() throws -> Double {
        var s = ""
        while pos < chars.count, chars[pos].isNumber || chars[pos] == "." {
            s.append(chars[pos]); pos += 1
        }
        // Scientific notation: 1e5, 1.5e-3
        if pos < chars.count, chars[pos] == "e" {
            // Only consume 'e' as exponent marker if followed by digit/sign
            let lookahead = pos + 1 < chars.count ? chars[pos + 1] : " "
            if lookahead.isNumber || lookahead == "+" || lookahead == "-" {
                s.append(chars[pos]); pos += 1
                if pos < chars.count, chars[pos] == "+" || chars[pos] == "-" {
                    s.append(chars[pos]); pos += 1
                }
                while pos < chars.count, chars[pos].isNumber {
                    s.append(chars[pos]); pos += 1
                }
            }
        }
        guard let value = Double(s) else { throw MathError.malformedNumber(s) }
        return value
    }

    private mutating func parseIdentifier() throws -> Double {
        var name = ""
        while pos < chars.count, chars[pos].isLetter {
            name.append(chars[pos]); pos += 1
        }

        // Constants
        switch name {
        case "pi": return .pi
        case "e": return M_E
        default: break
        }

        // Function call
        guard pos < chars.count, chars[pos] == "(" else {
            throw MathError.unknownIdentifier(name)
        }
        pos += 1

        var args: [Double] = []
        if pos < chars.count, chars[pos] != ")" {
            args.append(try parseExpression())
            while pos < chars.count, chars[pos] == "," {
                pos += 1
                args.append(try parseExpression())
            }
        }
        guard pos < chars.count, chars[pos] == ")" else {
            throw MathError.unexpectedToken("expected ')' after function args")
        }
        pos += 1

        return try applyFunction(name, args: args)
    }

    private func applyFunction(_ name: String, args: [Double]) throws -> Double {
        switch (name, args.count) {
        case ("sqrt", 1): return Foundation.sqrt(args[0])
        case ("abs", 1): return Swift.abs(args[0])
        case ("pow", 2): return Foundation.pow(args[0], args[1])
        case ("log", 1): return Foundation.log10(args[0])
        case ("ln", 1): return Foundation.log(args[0])
        case ("exp", 1): return Foundation.exp(args[0])
        case ("sin", 1): return Foundation.sin(args[0])
        case ("cos", 1): return Foundation.cos(args[0])
        case ("tan", 1): return Foundation.tan(args[0])
        case ("floor", 1): return Foundation.floor(args[0])
        case ("ceil", 1): return Foundation.ceil(args[0])
        case ("round", 1): return Foundation.round(args[0])
        case ("min", 2): return Swift.min(args[0], args[1])
        case ("max", 2): return Swift.max(args[0], args[1])
        // Known function names with wrong arity
        case ("sqrt", _), ("abs", _), ("log", _), ("ln", _), ("exp", _),
             ("sin", _), ("cos", _), ("tan", _), ("floor", _), ("ceil", _), ("round", _),
             ("pow", _), ("min", _), ("max", _):
            throw MathError.arityMismatch(name)
        default:
            throw MathError.unknownFunction(name)
        }
    }
}
