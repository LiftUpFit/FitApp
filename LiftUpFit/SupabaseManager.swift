//
//  SupabaseManager.swift
//  LiftUpFit
//
//  Created by Richard Slagle on 6/28/25.
//

import Foundation
import Supabase

class SupabaseManager: ObservableObject {
    static let shared = SupabaseManager()
    
    let client: SupabaseClient
    
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var userProfile: UserProfile?
    
    // MARK: - Initializer
    private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: Config.supabaseURL)!,
            supabaseKey: Config.supabaseAnonKey
        )
        // Restore session if available
        Task {
            await restoreSession()
            await checkCurrentUser()
        }
    }

    // MARK: - Session Persistence
    private let sessionKey = "supabaseSession"

    func saveSession(_ session: Session) {
        if let sessionData = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(sessionData, forKey: sessionKey)
        }
    }

    func clearSession() {
        UserDefaults.standard.removeObject(forKey: sessionKey)
    }

    func restoreSession() async {
        if let sessionData = UserDefaults.standard.data(forKey: sessionKey),
           let session = try? JSONDecoder().decode(Session.self, from: sessionData) {
            do {
                try await client.auth.setSession(accessToken: session.accessToken, refreshToken: session.refreshToken)
            } catch {
                print("Failed to restore session: \(error)")
            }
        }
    }

    // MARK: - Auth
    @MainActor
    func checkCurrentUser() async {
        do {
            let session = try await client.auth.session
            self.currentUser = session.user
            self.isAuthenticated = true
            print("✅ User authenticated: \(session.user.email ?? "No email")")
        } catch {
            print("❌ No valid session found: \(error)")
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    @MainActor
    func signUp(email: String, password: String) async throws {
        let response = try await client.auth.signUp(email: email, password: password)
        self.currentUser = response.user
        self.isAuthenticated = true
        let user = response.user
        self.userProfile = try await getUserProfile(userId: user.id.uuidString)
        // Save session if available
        if let session = (response as? Session) ?? (response as? (session: Session, user: User))?.session {
            saveSession(session)
        }
    }

    @MainActor
    func signIn(email: String, password: String) async throws {
        let response = try await client.auth.signIn(email: email, password: password)
        self.currentUser = response.user
        self.isAuthenticated = true
        let user = response.user
        self.userProfile = try await getUserProfile(userId: user.id.uuidString)
        // Save session if available
        if let session = (response as? Session) ?? (response as? (session: Session, user: User))?.session {
            saveSession(session)
        }
    }
    
    @MainActor
    func signOut() async throws {
        try await client.auth.signOut()
        self.currentUser = nil
        self.isAuthenticated = false
        self.userProfile = nil
        clearSession()
    }
    
    // MARK: - User Profile
    func createUserProfile(userId: String, profile: UserProfile) async throws {
        try await client
            .from("profiles")
            .insert(profile)
            .execute()
    }
    
    func getUserProfile(userId: String) async throws -> UserProfile? {
        print("🔍 Fetching profile for user: \(userId)")
        let response: [UserProfile] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        
        if let profile = response.first {
            print("✅ Profile found: \(profile.fullName ?? "No name")")
        } else {
            print("❌ No profile found for user: \(userId)")
        }
        
        return response.first
    }
    
    func updateUserProfile(userId: String, profile: UserProfile) async throws {
        try await client
            .from("profiles")
            .update(profile)
            .eq("id", value: userId)
            .execute()
    }
    
    // MARK: - Workout Operations
    func createWorkout(workout: Workout) async throws {
        guard let userId = currentUser?.id.uuidString.lowercased(), !userId.isEmpty else {
            print("❌ Error: Attempted to create workout with missing userId. User must be authenticated.")
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated or userId missing for workout creation"])
        }
        var workoutWithUser = workout
        workoutWithUser.userId = userId // Ensure userId is set and lowercased
        print("🚨 Attempting to insert workout: \(workoutWithUser)")
        print("🚨 Authenticated userId: \(userId)")
        try await client
            .from("workouts")
            .insert(workoutWithUser)
            .execute()
    }
    
    func getUserWorkouts() async throws -> [Workout] {
        guard let userId = currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let response: [Workout] = try await client
            .from("workouts")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return response
    }
    
    func updateWorkout(workout: Workout) async throws {
        try await client
            .from("workouts")
            .update(workout)
            .eq("id", value: workout.id)
            .execute()
    }
    
    func deleteWorkout(workoutId: String) async throws {
        try await client
            .from("workouts")
            .delete()
            .eq("id", value: workoutId)
            .execute()
    }
    
    // MARK: - Log Completion
    struct UserWorkoutLog: Codable, Hashable {
        let user_id: String
        let workout_id: String
        let program_day_id: UUID
        let exercise_id: String
        let set_number: Int
        let reps: Int?
        let weight: Double?
        let completed_at: Date
    }
    
    struct WorkoutCompletion: Encodable {
        let duration: Int
        let completed_at: Date
    }
    
    func completeWorkout(programDayId: UUID, sets: [String: [WorkoutSet]], duration: TimeInterval) async throws {
        let durationMinutes = Int(duration / 60)
        let updateData = WorkoutCompletion(duration: durationMinutes, completed_at: Date())
        
        // Optionally update a workouts table if you have one (comment out if not needed)
        // try await client
        //     .from("workouts")
        //     .update(updateData)
        //     .eq("id", value: programDayId.uuidString)
        //     .execute()
        
        guard let userId = currentUser?.id.uuidString else {
            throw NSError(domain: "User not authenticated", code: 401)
        }
        
        var uploadLogs: [UserWorkoutLog] = []
        let now = Date()
        for (exerciseId, exerciseSets) in sets {
            for (idx, set) in exerciseSets.enumerated() {
                guard let reps = set.reps else { continue }
                let log = UserWorkoutLog(
                    user_id: userId,
                    workout_id: "",
                    program_day_id: programDayId,
                    exercise_id: exerciseId,
                    set_number: idx + 1,
                    reps: reps,
                    weight: set.weight,
                    completed_at: set.completedAt
                )
                uploadLogs.append(log)
            }
        }
        if !uploadLogs.isEmpty {
            try await client
                .from("user_workouts")
                .insert(uploadLogs)
                .execute()
        }
    }
    
    // MARK: - Exercises
    func getAllExercises() async throws -> [Exercise] {
        do {
            let response: [Exercise] = try await client
                .from("exercises")
                .select()
                .order("name", ascending: true)
                .limit(200)
                .execute()
                .value
            print("Fetched \(response.count) exercises:")
            for ex in response {
                print("Exercise: \(ex.id) - \(ex.name)")
            }
            return response
        } catch {
            print("❌ Error fetching or decoding exercises: \(error)")
            throw error
        }
    }
    
    func createExercise(exercise: Exercise) async throws {
        try await client
            .from("exercises")
            .insert(exercise)
            .execute()
    }
    
    struct ProgramEnrollment: Codable {
        let user_id: String
        let program_id: String
    }
    
    func enrollUserInProgram(programId: String) async throws {
        guard let userId = currentUser?.id else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        let enrollment = ProgramEnrollment(
            user_id: userId.uuidString,
            program_id: programId
        )
        try await client
            .from("user_program_enrollments")
            .insert(enrollment)
            .execute()
    }
    
    func isUserEnrolledInProgram(programId: String) async throws -> Bool {
        guard let userId = currentUser?.id else { return false }
        let response: [ProgramEnrollment] = try await client
            .from("user_program_enrollments")
            .select()
            .eq("user_id", value: userId.uuidString)
            .eq("program_id", value: programId)
            .limit(1)
            .execute()
            .value
        return !response.isEmpty
    }

    // MARK: - Workout Session Model (for inserting new sessions)
    struct NewWorkoutSession: Codable {
        let id: UUID
        let user_id: UUID
        let program_day_id: UUID
        let started_at: Date
        let completed_at: Date?
        let name: String
    }

    // MARK: - Create Workout Session
    func createWorkoutSession(workoutId: String, userId: String, programDayId: UUID, name: String) async throws {
        let lowercasedUserId = userId.lowercased()
        guard !lowercasedUserId.isEmpty else {
            print("❌ Error: Attempted to create workout session with missing userId. User must be authenticated.")
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated or userId missing for workout session creation"])
        }
        print("🚨 Attempting to insert workout session with userId: \(lowercasedUserId)")
        let supabaseSession = try await client.auth.session
        print("Supabase session: \(String(describing: supabaseSession))")
        print("Supabase user: \(String(describing: client.auth.currentUser))")
        guard let workoutUUID = UUID(uuidString: workoutId), let userUUID = UUID(uuidString: lowercasedUserId) else {
            print("❌ Invalid UUID for workoutId or userId")
            throw NSError(domain: "SupabaseManager", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid UUID for workoutId or userId"])
        }
        let session = NewWorkoutSession(
            id: workoutUUID,
            user_id: userUUID,
            program_day_id: programDayId,
            started_at: Date(),
            completed_at: nil,
            name: name
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let jsonData = try? encoder.encode(session), let jsonString = String(data: jsonData, encoding: .utf8) {
            print("🚨 JSON sent to Supabase: \(jsonString)")
        }
        try await client
            .from("workouts")
            .upsert(session)
            .execute()
    }

    // MARK: - Upload Workout Logs
    func uploadWorkoutLogs(workoutId: String, programDayId: UUID, logs: [String: [SetLog]]) async throws {
        guard let userId = currentUser?.id.uuidString else { return }
        var uploadLogs: [UserWorkoutLog] = []
        let now = Date()
        for (exerciseId, setLogs) in logs {
            for setLog in setLogs where setLog.completed {
                uploadLogs.append(UserWorkoutLog(
                    user_id: userId,
                    workout_id: workoutId,
                    program_day_id: programDayId,
                    exercise_id: exerciseId,
                    set_number: setLog.setNumber,
                    reps: setLog.reps,
                    weight: setLog.weight,
                    completed_at: now
                ))
            }
        }
        if !uploadLogs.isEmpty {
            try await client
                .from("user_workouts")
                .insert(uploadLogs)
                .execute()
        }
    }

    // Fetch logs for a workout session
    func fetchWorkoutLogs(workoutId: String) async throws -> [UserWorkoutLog] {
        let logs: [UserWorkoutLog] = try await client
            .from("user_workouts")
            .select()
            .eq("workout_id", value: workoutId)
            .order("set_number", ascending: true)
            .execute()
            .value
        return logs
    }

    // Delete logs for a workout session
    func deleteWorkoutLogs(workoutId: String) async throws {
        try await client
            .from("user_workouts")
            .delete()
            .eq("workout_id", value: workoutId)
            .execute()
    }

    // MARK: - Fuel Articles
    func getAllArticles() async throws -> [Article] {
        let response: [Article] = try await client
            .from("articles")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return response
    }

    // Create Article
    func createArticle(article: Article) async throws {
        try await client.from("articles").insert(article).execute()
    }

    // Update Article
    func updateArticle(article: Article) async throws {
        try await client.from("articles").update(article).eq("id", value: article.id).execute()
    }

    // Delete Article
    func deleteArticle(id: String) async throws {
        try await client.from("articles").delete().eq("id", value: id).execute()
    }

    func updateMonthlyGoal(userId: String, goal: Int) async throws {
        try await client
            .from("profiles")
            .update(["monthly_goal": goal])
            .eq("id", value: userId)
            .execute()
    }

    func updateMonthlyGoalText(userId: String, text: String) async throws {
        try await client
            .from("profiles")
            .update(["monthly_goal_text": text])
            .eq("id", value: userId)
            .execute()
    }


}

extension SupabaseManager {
    func fetchProgramDays(programId: String) async throws -> [ProgramDay] {
        let result: [ProgramDay] = try await client
            .from("program_days")
            .select()
            .eq("program_id", value: programId)
            .order("day_number", ascending: true)
            .execute()
            .value
        return result
    }
    
    func fetchProgramDayExercises(programDayId: UUID) async throws -> [ProgramDayExercise] {
        let result: [ProgramDayExercise] = try await client
            .from("program_day_exercises")
            .select()
            .eq("program_day_id", value: programDayId.uuidString)
            .order("order_index", ascending: true)
            .execute()
            .value
        return result
    }
    
    func fetchExercisesForProgramDay(programDayId: UUID) async throws -> [Exercise] {
        // First get the program day exercises
        let programDayExercises: [ProgramDayExercise] = try await client
            .from("program_day_exercises")
            .select()
            .eq("program_day_id", value: programDayId.uuidString)
            .order("order_index", ascending: true)
            .execute()
            .value
        
        // Then get all exercises
        let allExercises: [Exercise] = try await client
            .from("exercises")
            .select()
            .execute()
            .value
        
        // Filter exercises that match the program day exercises
        let exerciseIds = programDayExercises.map { $0.exercise_id }
        let filteredExercises = allExercises.filter { exercise in
            exerciseIds.contains(exercise.id)
        }
        
        return filteredExercises
    }
    
    func checkUserDayProgress(programDayId: UUID) async throws -> UserDayProgress? {
        guard let userId = currentUser?.id.uuidString else { return nil }
        
        let result: [UserDayProgress] = try await client
            .from("user_day_progress")
            .select()
            .eq("user_id", value: userId)
            .eq("program_day_id", value: programDayId.uuidString)
            .limit(1)
            .execute()
            .value
        
        return result.first
    }

    struct DayProgress: Encodable {
        let user_id: String
        let program_day_id: String
        let duration_minutes: Int?
        let notes: String?
    }

    func markDayAsCompleted(programDayId: UUID, durationMinutes: Int? = nil, notes: String? = nil) async throws {
        guard let userId = currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        let progress = DayProgress(
            user_id: userId,
            program_day_id: programDayId.uuidString,
            duration_minutes: durationMinutes,
            notes: notes
        )
        
        try await client
            .from("user_day_progress")
            .upsert(progress, onConflict: "user_id,program_day_id")
            .execute()
    }

    
    func getUserProgramProgress(programId: UUID) async throws -> [UserDayProgress] {
        guard let userId = currentUser?.id.uuidString else {
            throw NSError(domain: "SupabaseManager", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // First get all days for this program
        let programDays = try await fetchProgramDays(programId: programId.uuidString)
        let programDayIds = programDays.map { $0.id }
        
        // Then get progress for all those days
        let result: [UserDayProgress] = try await client
            .from("user_day_progress")
            .select()
            .eq("user_id", value: userId)
            .in("program_day_id", values: programDayIds.map { $0.uuidString })
            .execute()
            .value
        
        return result
    }

    func fetchDayExercises(programDayId: String) async throws -> [DayExercise] {
        print("🔍 Fetching day exercises for day: \(programDayId)")
        // First get the program day exercises
        let programDayExercises: [ProgramDayExercise] = try await client
            .from("program_day_exercises")
            .select("id::text, program_day_id::text, exercise_id::text, sets, reps, weight, duration, rest_time, order_index")
            .eq("program_day_id", value: programDayId)
            .order("order_index", ascending: true)
            .execute()
            .value
        print("📋 Found \(programDayExercises.count) program day exercises")
        // Then get all exercises
        let allExercises: [Exercise] = try await client
            .from("exercises")
            .select()
            .execute()
            .value
        print("💪 Found \(allExercises.count) total exercises")
        // Create a dictionary for faster lookup (convert to lowercase for case-insensitive comparison)
        let exerciseDict = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.id.lowercased(), $0) })
        // Combine the data
        var dayExercises: [DayExercise] = []
        for pde in programDayExercises {
            let exerciseId = pde.exercise_id.lowercased()
            print("🔗 Looking for exercise with ID: \(exerciseId)")
            if let exercise = exerciseDict[exerciseId] {
                print("✅ Found exercise: \(exercise.name)")
                dayExercises.append(DayExercise(programDayExercise: pde, exercise: exercise))
            } else {
                print("❌ Exercise not found for ID: \(exerciseId)")
            }
        }
        print("🎯 Created \(dayExercises.count) day exercises")
        return dayExercises
    }

    // Update all exercises for a program day: delete existing, insert new
    func updateProgramDayExercises(for day: ProgramDay, exercises: [Exercise]) async throws {
        print("[SupabaseManager] 🚀 updateProgramDayExercises called for day: \(day.id)")
        // Delete existing exercises for the day
        print("[SupabaseManager] 🗑️ Deleting existing exercises for day: \(day.id)")
        try await client
            .from("program_day_exercises")
            .delete()
            .eq("program_day_id", value: day.id)
            .execute()
        print("[SupabaseManager] ✅ Deleted existing exercises")
        // Insert new exercises
        for (index, exercise) in exercises.enumerated() {
            let normalizedExerciseId = exercise.id.lowercased()
            guard let exerciseUUID = UUID(uuidString: normalizedExerciseId) else {
                print("[SupabaseManager] ❌ Invalid exercise ID: \(exercise.id)")
                continue
            }
            let programDayExercise = ProgramDayExercise(
                id: UUID().uuidString,
                program_day_id: day.id.uuidString,
                exercise_id: exerciseUUID.uuidString,
                exercise_type: exercise.exerciseType.rawValue,
                sets: 3,
                reps: exercise.exerciseType == .time ? nil : 10,
                weight: nil,
                duration: exercise.exerciseType == .time ? exercise.duration : nil,
                rest_time: 60,
                order_index: index + 1
            )
            print("[SupabaseManager] �� Inserting exercise: \(exercise.name) (UUID: \(exerciseUUID))")
            try await client
                .from("program_day_exercises")
                .insert(programDayExercise)
                .execute()
            print("[SupabaseManager] ✅ Inserted exercise: \(exercise.name)")
        }
        print("[SupabaseManager] 🎯 updateProgramDayExercises completed for day: \(day.id)")
    }
}
