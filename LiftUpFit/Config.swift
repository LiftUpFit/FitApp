//
//  Config.swift
//  LiftUpFit
//
//  Created by Richard Slagle on 6/28/25.
//

import Foundation

enum Config {
    // MARK: - Supabase Configuration
    // Replace these with your actual Supabase project credentials
    // You can find these in your Supabase project dashboard under Settings > API
    
    static let supabaseURL = "https://jwpxcthgehwbelyvltyp.supabase.co"
    static let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp3cHhjdGhnZWh3YmVseXZsdHlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTExNjc5MDMsImV4cCI6MjA2Njc0MzkwM30.zz0DQ6SWEE9maxG24Q_NFzuT-KUfjtGhmKh8MkwjC1Q"
    
    // MARK: - App Configuration
    static let appName = "LiftUpFit"
    static let appVersion = "1.0.0"
    
    // MARK: - Database Table Names
    struct Tables {
        static let profiles = "profiles"
        static let workouts = "workouts"
        static let exercises = "exercises"
        static let userWorkouts = "user_workouts"
    }
    
    // MARK: - Validation Rules
    struct Validation {
        static let minPasswordLength = 6
        static let maxPasswordLength = 128
        static let maxNameLength = 100
        static let maxDescriptionLength = 500
    }
} 
