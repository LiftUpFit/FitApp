//
//  ProfileViews.swift
//  LiftUpFit
//
//  Created by Richard Slagle on 6/28/25.
//

import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    static let profileUpdated = Notification.Name("profileUpdated")
}

// MARK: - Enhanced Profile View

struct ProfileView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var userProfile: UserProfile?
    @State private var isLoading = true
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading profile...")
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Profile Header
                            ProfileHeaderView(userProfile: userProfile)
                            
                            // Macro Recommendations - Always show if we have any profile data
                            if let profile = userProfile, profile.age != nil || profile.weight != nil || profile.height != nil {
                                MacroRecommendationsView(profile: profile)
                            }
                            
                            // Profile Information
                            ProfileInfoCard(userProfile: userProfile)
                            
                            // Fitness Goals
                            if let profile = userProfile, !(profile.goals?.isEmpty ?? true) {
                                FitnessGoalsCard(goals: profile.goals ?? [])
                            }
                            
                            // Sign Out Button
                            
                            Button("Sign Out") {
                                Task {
                                    do {
                                        try await supabaseManager.signOut()
                                    } catch {
                                        print("Sign out error: \(error)")
                                    }
                                }
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#404C61"))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    .refreshable {
                        await loadProfile()
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingEditProfile = true
                    }
                }
            }
            .sheet(isPresented: $showingEditProfile) {
                EditProfileView(userProfile: userProfile)
                    .environmentObject(supabaseManager)
            }
            .onReceive(NotificationCenter.default.publisher(for: .profileUpdated)) { _ in
                Task {
                    await loadProfile()
                }
            }
        }
        .onAppear {
            Task {
                await loadProfile()
            }
        }
    }
    
    private func loadProfile() async {
        print("🔄 Loading profile...")
        guard let userId = supabaseManager.currentUser?.id.uuidString else { 
            print("❌ No current user found")
            await MainActor.run {
                isLoading = false
            }
            return 
        }
        
        print("👤 Current user ID: \(userId)")
        
        do {
            let profile = try await supabaseManager.getUserProfile(userId: userId)
            
            await MainActor.run {
                self.userProfile = profile
                self.isLoading = false
                print("✅ Profile loaded successfully: \(profile?.fullName ?? "No name")")
            }
        } catch {
            print("❌ Error loading profile: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Profile Header View

struct ProfileHeaderView: View {
    let userProfile: UserProfile?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)
            
            Text(userProfile?.fullName ?? "User")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(userProfile?.email ?? "")
                .font(.body)
                .foregroundColor(.secondary)
            
            if let profile = userProfile, profile.isProfileComplete {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Profile Complete")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.orange)
                    Text("Complete your profile for personalized recommendations")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Macro Recommendations View

struct MacroRecommendationsView: View {
    let profile: UserProfile
    @State private var showingMacroDetails = false
    
    var macroCalculator: MacroCalculator {
        MacroCalculator(profile: profile)
    }
    
    var isProfileDataSufficient: Bool {
        return profile.age != nil && profile.weight != nil && profile.height != nil && profile.fitnessLevel != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Daily Macro Recommendations")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if isProfileDataSufficient {
                    Button("Details") {
                        showingMacroDetails = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            
            if isProfileDataSufficient {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    MacroCard(
                        title: "Calories",
                        value: "\(macroCalculator.dailyCalories)",
                        unit: "kcal",
                        color: .orange,
                        icon: "flame"
                    )
                    
                    MacroCard(
                        title: "Protein",
                        value: "\(macroCalculator.protein)",
                        unit: "g",
                        color: .red,
                        icon: "dumbbell"
                    )
                    
                    MacroCard(
                        title: "Carbs",
                        value: "\(macroCalculator.carbs)",
                        unit: "g",
                        color: .green,
                        icon: "leaf"
                    )
                    
                    MacroCard(
                        title: "Fats",
                        value: "\(macroCalculator.fats)",
                        unit: "g",
                        color: .yellow,
                        icon: "drop"
                    )
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text("Complete your profile to see personalized macro recommendations")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Text("Missing: \(missingFields)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .sheet(isPresented: $showingMacroDetails) {
            MacroDetailsView(profile: profile)
        }
    }
    
    private var missingFields: String {
        var missing: [String] = []
        if profile.age == nil { missing.append("Age") }
        if profile.weight == nil { missing.append("Weight") }
        if profile.height == nil { missing.append("Height") }
        if profile.fitnessLevel == nil { missing.append("Fitness Level") }
        return missing.joined(separator: ", ")
    }
}

struct MacroCard: View {
    let title: String
    let value: String
    let unit: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(unit)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Macro Details View

struct MacroDetailsView: View {
    let profile: UserProfile
    @Environment(\.dismiss) private var dismiss
    
    var macroCalculator: MacroCalculator {
        MacroCalculator(profile: profile)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Macro Breakdown")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Based on your profile: \(profile.age ?? 0) years, \(UnitConverter.formatHeight(profile.height ?? 0, preference: profile.unitPreference)), \(UnitConverter.formatWeight(profile.weight ?? 0, preference: profile.unitPreference)), \(profile.fitnessLevel ?? "Beginner") level")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // Daily Calories
                    MacroDetailCard(
                        title: "Daily Calories",
                        value: "\(macroCalculator.dailyCalories)",
                        unit: "kcal",
                        description: "Your daily calorie target for \(macroCalculator.goalDescription.lowercased())",
                        color: .orange
                    )
                    
                    // Protein
                    MacroDetailCard(
                        title: "Protein",
                        value: "\(macroCalculator.protein)",
                        unit: "g",
                        description: "\(macroCalculator.proteinPercentage)% of daily calories • \(macroCalculator.proteinPerUnit) \(macroCalculator.proteinUnit)",
                        color: .red
                    )
                    
                    // Carbs
                    MacroDetailCard(
                        title: "Carbohydrates",
                        value: "\(macroCalculator.carbs)",
                        unit: "g",
                        description: "\(macroCalculator.carbsPercentage)% of daily calories",
                        color: .green
                    )
                    
                    // Fats
                    MacroDetailCard(
                        title: "Fats",
                        value: "\(macroCalculator.fats)",
                        unit: "g",
                        description: "\(macroCalculator.fatsPercentage)% of daily calories",
                        color: .yellow
                    )
                    
                    // Recommendations
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommendations")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            RecommendationRow(
                                icon: "clock",
                                text: "Eat \(macroCalculator.mealsPerDay) meals per day"
                            )
                            RecommendationRow(
                                icon: "drop",
                                text: "Drink \(String(format: "%.1f", macroCalculator.waterIntake)) \(macroCalculator.waterUnit) of water daily"
                            )
                            RecommendationRow(
                                icon: "bed.double",
                                text: "Get 7-9 hours of sleep"
                            )
                            RecommendationRow(
                                icon: "figure.walk",
                                text: "Include \(macroCalculator.workoutFrequency) workouts per week"
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Macro Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct MacroDetailCard: View {
    let title: String
    let value: String
    let unit: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text(value)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(color)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct RecommendationRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
        }
    }
}

// MARK: - Profile Info Card

struct ProfileInfoCard: View {
    let userProfile: UserProfile?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Profile Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ProfileInfoRow(title: "Age", value: userProfile?.age?.description ?? "Not set", icon: "calendar")
                
                if let height = userProfile?.height {
                    ProfileInfoRow(
                        title: "Height", 
                        value: UnitConverter.formatHeight(height, preference: userProfile?.unitPreference), 
                        icon: "ruler"
                    )
                } else {
                    ProfileInfoRow(title: "Height", value: "Not set", icon: "ruler")
                }
                
                if let weight = userProfile?.weight {
                    ProfileInfoRow(
                        title: "Weight", 
                        value: UnitConverter.formatWeight(weight, preference: userProfile?.unitPreference), 
                        icon: "scalemass"
                    )
                } else {
                    ProfileInfoRow(title: "Weight", value: "Not set", icon: "scalemass")
                }
                
                ProfileInfoRow(title: "Fitness Level", value: userProfile?.fitnessLevel ?? "Not set", icon: "figure.strengthtraining.traditional")
                
                ProfileInfoRow(
                    title: "Units", 
                    value: (userProfile?.unitPreference ?? UnitConverter.defaultUnitPreference).capitalized, 
                    icon: "ruler"
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct ProfileInfoRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Fitness Goals Card

struct FitnessGoalsCard: View {
    let goals: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fitness Goals")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                ForEach(goals, id: \.self) { goal in
                    Text(goal)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Edit Profile View

struct EditProfileView: View {
    let userProfile: UserProfile?
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager
    
    @State private var fullName: String = ""
    @State private var age: String = ""
    @State private var height: String = ""
    @State private var weight: String = ""
    @State private var fitnessLevel: String = "Beginner"
    @State private var selectedGoals: Set<String> = []
    @State private var unitPreference: String = UnitConverter.defaultUnitPreference
    @State private var isLoading = false
    
    let fitnessLevels = ["Beginner", "Intermediate", "Advanced", "Expert"]
    let availableGoals = [
        "Build Muscle",
        "Lose Fat",
        "Improve Strength",
        "Increase Endurance",
        "Maintain Weight",
        "Improve Flexibility",
        "Better Overall Health",
        "Sports Performance"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Personal Information") {
                    TextField("Full Name", text: $fullName)
                    
                    HStack {
                        TextField("Age", text: $age)
                            .keyboardType(.numberPad)
                        Text("years")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        TextField("Height", text: $height)
                            .keyboardType(.default)
                        Text(unitPreference == "imperial" ? "ft/in (e.g., 5' 10.5\")" : "cm")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        TextField("Weight", text: $weight)
                            .keyboardType(.decimalPad)
                        Text(unitPreference == "imperial" ? "lbs" : "kg")
                            .foregroundColor(.secondary)
                    }
                }
                
                Section("Unit Preferences") {
                    Picker("Measurement Units", selection: $unitPreference) {
                        Text("Imperial (ft/in, lbs)").tag("imperial")
                        Text("Metric (cm, kg)").tag("metric")
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    Text(unitPreference == "imperial" ? 
                         "Height: Enter as feet and inches (e.g., 5' 10.5\")" : 
                         "Height: Enter in centimeters")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(unitPreference == "imperial" ? 
                         "Weight: Enter in pounds" : 
                         "Weight: Enter in kilograms")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Section("Fitness Level") {
                    Picker("Fitness Level", selection: $fitnessLevel) {
                        ForEach(fitnessLevels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Fitness Goals") {
                    ForEach(availableGoals, id: \.self) { goal in
                        Button(action: {
                            if selectedGoals.contains(goal) {
                                selectedGoals.remove(goal)
                            } else {
                                selectedGoals.insert(goal)
                            }
                        }) {
                            HStack {
                                Text(goal)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedGoals.contains(goal) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                if !fullName.isEmpty && !age.isEmpty && !height.isEmpty && !weight.isEmpty {
                    Section("Preview") {
                        MacroPreviewCard(
                            fullName: fullName,
                            age: Int(age) ?? 0,
                            height: parseHeightInput() ?? 0,
                            weight: parseWeightInput() ?? 0,
                            fitnessLevel: fitnessLevel,
                            goals: Array(selectedGoals),
                            unitPreference: unitPreference
                        )
                    }
                }
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProfile()
                    }
                    .disabled(isFormInvalid || isLoading)
                }
            }
        }
        .onAppear {
            loadCurrentProfile()
        }
    }
    
    private var isFormInvalid: Bool {
        fullName.isEmpty || age.isEmpty || height.isEmpty || weight.isEmpty || selectedGoals.isEmpty
    }
    
    private func parseHeightInput() -> Double? {
        return UnitConverter.parseHeightInput(height, preference: unitPreference)
    }
    
    private func parseWeightInput() -> Double? {
        return UnitConverter.parseWeightInput(weight, preference: unitPreference)
    }
    
    private func loadCurrentProfile() {
        guard let profile = userProfile else { return }
        
        fullName = profile.fullName ?? ""
        age = profile.age?.description ?? ""
        unitPreference = profile.unitPreference ?? UnitConverter.defaultUnitPreference
        
        // Initialize height and weight fields
        height = ""
        weight = ""
        
        // Load height and weight in the user's preferred units
        if let heightCm = profile.height, heightCm > 0 {
            if unitPreference == "imperial" {
                let (feet, inches) = UnitConverter.cmToFeetInches(heightCm)
                height = UnitConverter.formatFeetInches(feet: feet, inches: inches)
            } else {
                height = "\(Int(heightCm))"
            }
        }
        
        if let weightKg = profile.weight, weightKg > 0 {
            if unitPreference == "imperial" {
                let lbs = UnitConverter.kgToLbs(weightKg)
                weight = UnitConverter.formatLbs(lbs)
            } else {
                weight = UnitConverter.formatKg(weightKg)
            }
        }
        
        fitnessLevel = profile.fitnessLevel ?? "Beginner"
        selectedGoals = Set(profile.goals ?? [])
    }
    
    private func saveProfile() {
        isLoading = true
        
        Task {
            do {
                guard let userId = supabaseManager.currentUser?.id.uuidString else { return }
                
                let parsedHeight = parseHeightInput()
                let parsedWeight = parseWeightInput()
                
                // Only update height and weight if they have valid values
                let finalHeight = parsedHeight != nil && parsedHeight! > 0 ? parsedHeight : userProfile?.height
                let finalWeight = parsedWeight != nil && parsedWeight! > 0 ? parsedWeight : userProfile?.weight
                
                let updatedProfile = UserProfile(
                    id: userId,
                    email: userProfile?.email ?? "",
                    fullName: fullName,
                    age: Int(age),
                    weight: finalWeight,
                    height: finalHeight,
                    fitnessLevel: fitnessLevel,
                    goals: Array(selectedGoals),
                    unitPreference: unitPreference,
                    createdAt: userProfile?.createdAt ?? Date(),
                    updatedAt: Date()
                )
                
                try await supabaseManager.updateUserProfile(userId: userId, profile: updatedProfile)
                
                await MainActor.run {
                    isLoading = false
                    // Post notification to refresh the profile view
                    NotificationCenter.default.post(name: .profileUpdated, object: nil)
                    dismiss()
                }
            } catch {
                print("Error updating profile: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Macro Preview Card

struct MacroPreviewCard: View {
    let fullName: String
    let age: Int
    let height: Double
    let weight: Double
    let fitnessLevel: String
    let goals: [String]
    let unitPreference: String
    
    var macroCalculator: MacroCalculator {
        let profile = UserProfile(
            id: "",
            email: "",
            fullName: fullName,
            age: age,
            weight: weight,
            height: height,
            fitnessLevel: fitnessLevel,
            goals: goals,
            unitPreference: unitPreference,
            createdAt: Date(),
            updatedAt: Date()
        )
        return MacroCalculator(profile: profile)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Estimated Daily Macros")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                VStack {
                    Text("\(macroCalculator.dailyCalories)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.orange)
                    Text("Calories")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("\(macroCalculator.protein)g")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    Text("Protein")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("\(macroCalculator.carbs)g")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    Text("Carbs")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack {
                    Text("\(macroCalculator.fats)g")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    Text("Fats")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Macro Calculator

struct MacroCalculator {
    let profile: UserProfile
    
    // BMR calculation using Mifflin-St Jeor Equation
    var bmr: Double {
        guard let age = profile.age, let weight = profile.weight, let height = profile.height else { return 0 }
        
        // BMR = 10 × weight(kg) + 6.25 × height(cm) - 5 × age(y) + 5 (for men)
        // For women, use + 161 instead of + 5
        // Using male calculation as default
        // Note: weight and height are always stored in metric units in the database
        return 10 * weight + 6.25 * height - 5 * Double(age) + 5
    }
    
    // Activity multiplier based on fitness level
    var activityMultiplier: Double {
        switch profile.fitnessLevel {
        case "Beginner": return 1.2
        case "Intermediate": return 1.375
        case "Advanced": return 1.55
        case "Expert": return 1.725
        default: return 1.2
        }
    }
    
    // Goal adjustment based on primary goal
    var goalMultiplier: Double {
        let goals = profile.goals ?? []
        
        if goals.contains("Lose Fat") {
            return 0.85 // 15% deficit
        } else if goals.contains("Build Muscle") {
            return 1.1 // 10% surplus
        } else {
            return 1.0 // Maintenance
        }
    }
    
    var dailyCalories: Int {
        return Int(bmr * activityMultiplier * goalMultiplier)
    }
    
    var protein: Int {
        let goals = profile.goals ?? []
        let weight = profile.weight ?? 0
        
        if goals.contains("Build Muscle") {
            return Int(weight * 2.2) // 2.2g per kg for muscle building
        } else if goals.contains("Lose Fat") {
            return Int(weight * 2.0) // 2.0g per kg for fat loss
        } else {
            return Int(weight * 1.8) // 1.8g per kg for maintenance
        }
    }
    
    var proteinPerKg: Double {
        let weight = profile.weight ?? 1
        return Double(protein) / weight
    }
    
    // Display protein per unit based on user preference
    var proteinPerUnit: String {
        let weight = profile.weight ?? 1
        let proteinPerKg = Double(protein) / weight
        
        if profile.unitPreference == "imperial" {
            let proteinPerLbs = proteinPerKg / 2.20462
            return String(format: "%.1f", proteinPerLbs)
        } else {
            return String(format: "%.1f", proteinPerKg)
        }
    }
    
    var proteinUnit: String {
        return profile.unitPreference == "imperial" ? "g per lb" : "g per kg"
    }
    
    var proteinCalories: Int {
        return protein * 4
    }
    
    var proteinPercentage: Int {
        return Int((Double(proteinCalories) / Double(dailyCalories)) * 100)
    }
    
    var fats: Int {
        return Int(Double(dailyCalories) * 0.25 / 9) // 25% of calories from fat
    }
    
    var fatCalories: Int {
        return fats * 9
    }
    
    var fatsPercentage: Int {
        return Int((Double(fatCalories) / Double(dailyCalories)) * 100)
    }
    
    var carbs: Int {
        let remainingCalories = dailyCalories - proteinCalories - fatCalories
        return Int(Double(remainingCalories) / 4)
    }
    
    var carbCalories: Int {
        return carbs * 4
    }
    
    var carbsPercentage: Int {
        return Int((Double(carbCalories) / Double(dailyCalories)) * 100)
    }
    
    var goalDescription: String {
        let goals = profile.goals ?? []
        
        if goals.contains("Lose Fat") {
            return "Fat Loss"
        } else if goals.contains("Build Muscle") {
            return "Muscle Building"
        } else {
            return "Maintenance"
        }
    }
    
    var mealsPerDay: Int {
        let goals = profile.goals ?? []
        
        if goals.contains("Build Muscle") {
            return 5
        } else {
            return 4
        }
    }
    
    var waterIntake: Double {
        let weight = profile.weight ?? 0
        let litersPerKg = 0.033 // 33ml per kg body weight
        
        if profile.unitPreference == "imperial" {
            // Convert to ounces (1 liter = 33.814 ounces)
            return weight * litersPerKg * 33.814
        } else {
            return weight * litersPerKg
        }
    }
    
    var waterUnit: String {
        return profile.unitPreference == "imperial" ? "oz" : "liters"
    }
    
    var workoutFrequency: Int {
        switch profile.fitnessLevel {
        case "Beginner": return 3
        case "Intermediate": return 4
        case "Advanced": return 5
        case "Expert": return 6
        default: return 3
        }
    }
}

// MARK: - UserProfile Extension

extension UserProfile {
    var isProfileComplete: Bool {
        return age != nil && weight != nil && height != nil && fitnessLevel != nil && !(goals?.isEmpty ?? true)
    }
} 
