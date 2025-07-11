//
//  UnitConverter.swift
//  LiftUpFit
//
//  Created by Richard Slagle on 6/28/25.
//

import Foundation

// MARK: - Unit Conversion Utilities

struct UnitConverter {
    
    // MARK: - Height Conversions
    
    /// Convert centimeters to feet and inches
    static func cmToFeetInches(_ cm: Double) -> (feet: Int, inches: Double) {
        let totalInches = cm / 2.54
        let feet = Int(totalInches / 12)
        let inches = totalInches.truncatingRemainder(dividingBy: 12)
        return (feet, inches)
    }
    
    /// Convert feet and inches to centimeters
    static func feetInchesToCm(feet: Int, inches: Double) -> Double {
        let totalInches = Double(feet) * 12 + inches
        return totalInches * 2.54
    }
    
    /// Format feet and inches as a string
    static func formatFeetInches(feet: Int, inches: Double) -> String {
        if inches == 0 {
            return "\(feet)'"
        } else {
            return "\(feet)' \(String(format: "%.1f", inches))\""
        }
    }
    
    /// Parse feet and inches from string (e.g., "5' 10.5\"", "5'10\"", "5' 10\"")
    static func parseFeetInches(_ string: String) -> (feet: Int, inches: Double)? {
        // Simple approach: extract all numbers from the string
        let numbers = string.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .compactMap { Double($0) }
            .filter { $0 > 0 }
        
        if numbers.count >= 2 {
            let feet = Int(numbers[0])
            let inches = numbers[1]
            return (feet, inches)
        } else if numbers.count == 1 {
            let feet = Int(numbers[0])
            return (feet, 0)
        }
        
        return nil
    }
    
    // MARK: - Weight Conversions
    
    /// Convert kilograms to pounds
    static func kgToLbs(_ kg: Double) -> Double {
        return kg * 2.20462
    }
    
    /// Convert pounds to kilograms
    static func lbsToKg(_ lbs: Double) -> Double {
        return lbs / 2.20462
    }
    
    /// Format pounds as a string
    static func formatLbs(_ lbs: Double) -> String {
        return String(format: "%.1f", lbs)
    }
    
    /// Format kilograms as a string
    static func formatKg(_ kg: Double) -> String {
        return String(format: "%.1f", kg)
    }
    
    // MARK: - Unit Preference Management
    
    static let defaultUnitPreference = "imperial"
    
    static func getUnitPreference() -> String {
        return UserDefaults.standard.string(forKey: "unitPreference") ?? defaultUnitPreference
    }
    
    static func setUnitPreference(_ preference: String) {
        UserDefaults.standard.set(preference, forKey: "unitPreference")
    }
    
    // MARK: - Display Helpers
    
    static func getHeightUnit() -> String {
        return getUnitPreference() == "imperial" ? "ft/in" : "cm"
    }
    
    static func getWeightUnit() -> String {
        return getUnitPreference() == "imperial" ? "lbs" : "kg"
    }
    
    static func formatHeight(_ cm: Double, preference: String? = nil) -> String {
        let unitPref = preference ?? getUnitPreference()
        
        if unitPref == "imperial" {
            let (feet, inches) = cmToFeetInches(cm)
            return formatFeetInches(feet: feet, inches: inches)
        } else {
            return "\(Int(cm)) cm"
        }
    }
    
    static func formatWeight(_ kg: Double, preference: String? = nil) -> String {
        let unitPref = preference ?? getUnitPreference()
        
        if unitPref == "imperial" {
            let lbs = kgToLbs(kg)
            return "\(formatLbs(lbs)) lbs"
        } else {
            return "\(formatKg(kg)) kg"
        }
    }
    
    // MARK: - Input Parsing
    
    static func parseHeightInput(_ input: String, preference: String? = nil) -> Double? {
        let unitPref = preference ?? getUnitPreference()
        
        if unitPref == "imperial" {
            guard let (feet, inches) = parseFeetInches(input) else { return nil }
            return feetInchesToCm(feet: feet, inches: inches)
        } else {
            return Double(input)
        }
    }
    
    static func parseWeightInput(_ input: String, preference: String? = nil) -> Double? {
        let unitPref = preference ?? getUnitPreference()
        
        if unitPref == "imperial" {
            guard let lbs = Double(input) else { return nil }
            return lbsToKg(lbs)
        } else {
            return Double(input)
        }
    }
    
    // MARK: - Test Functions
    
    static func testConversions() {
        // Test height conversions
        let testCm = 175.0
        let (feet, inches) = cmToFeetInches(testCm)
        let convertedCm = feetInchesToCm(feet: feet, inches: inches)
        print("Height test: \(testCm) cm = \(formatFeetInches(feet: feet, inches: inches)) = \(convertedCm) cm")
        
        // Test weight conversions
        let testKg = 70.0
        let lbs = kgToLbs(testKg)
        let convertedKg = lbsToKg(lbs)
        print("Weight test: \(testKg) kg = \(formatLbs(lbs)) lbs = \(convertedKg) kg")
        
        // Test parsing various formats
        let testCases = ["5' 10.5\"", "6' 3\"", "5'10\"", "5' 10\""]
        for testCase in testCases {
            if let parsedHeight = parseFeetInches(testCase) {
                let cm = feetInchesToCm(feet: parsedHeight.feet, inches: parsedHeight.inches)
                print("Parsing test: \(testCase) = \(parsedHeight.feet)' \(parsedHeight.inches)\" = \(cm) cm")
            } else {
                print("Parsing test: \(testCase) = FAILED")
            }
        }
    }
} 