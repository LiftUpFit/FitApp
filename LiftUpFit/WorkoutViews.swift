import SwiftUI

// MARK: - Workout List View

struct WorkoutListView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var workouts: [Workout] = []
    @State private var isLoading = true
    @State private var showingCreateWorkout = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Loading workouts...")
                } else if workouts.isEmpty {
                    EmptyWorkoutView(showingCreateWorkout: $showingCreateWorkout)
                } else {
                    List {
                        ForEach(workouts, id: \.id) { workout in
                            NavigationLink(destination: WorkoutDetailView(workout: workout)) {
                                WorkoutRowView(workout: workout)
                            }
                        }
                        .onDelete(perform: deleteWorkout)
                    }
                    .refreshable {
                        await loadWorkouts()
                    }
                }
            }
            .navigationTitle("My Workouts")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingCreateWorkout = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateWorkout) {
                CreateWorkoutView()
                    .environmentObject(supabaseManager)
            }
        }
        .onAppear {
            Task {
                await loadWorkouts()
            }
        }
    }
    
    private func loadWorkouts() async {
        isLoading = true
        do {
            workouts = try await supabaseManager.getUserWorkouts()
            await MainActor.run {
                isLoading = false
            }
        } catch {
            print("Error loading workouts: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func deleteWorkout(offsets: IndexSet) {
        Task {
            for index in offsets {
                let workout = workouts[index]
                do {
                    try await supabaseManager.deleteWorkout(workoutId: workout.id)
                } catch {
                    print("Error deleting workout: \(error)")
                }
            }
            await loadWorkouts()
        }
    }
}

// MARK: - Empty State View

struct EmptyWorkoutView: View {
    @Binding var showingCreateWorkout: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "dumbbell")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Workouts Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create your first workout to start tracking your fitness journey")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button("Create Workout") {
                showingCreateWorkout = true
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Workout Row View

struct WorkoutRowView: View {
    let workout: Workout
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let description = workout.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(workout.exercises?.count ?? 0)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text("exercises")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            HStack {
                if let duration = workout.duration {
                    Label("\(duration) min", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let calories = workout.caloriesBurned {
                    Label("\(calories) cal", systemImage: "flame")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(workout.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Workout View

struct CreateWorkoutView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager
    
    @State private var workoutName = ""
    @State private var workoutDescription = ""
    @State private var selectedExercises: [Exercise] = []
    @State private var showingExercisePicker = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Workout Details") {
                    TextField("Workout Name", text: $workoutName)
                    TextField("Description (Optional)", text: $workoutDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Exercises") {
                    if selectedExercises.isEmpty {
                        Text("No exercises added yet")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(selectedExercises, id: \.id) { exercise in
                            ExerciseRowView(exercise: exercise)
                        }
                        .onDelete(perform: removeExercise)
                    }
                    
                    Button("Add Exercise") {
                        showingExercisePicker = true
                    }
                }
            }
            .navigationTitle("Create Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createWorkout()
                    }
                    .disabled(workoutName.isEmpty || selectedExercises.isEmpty || isLoading)
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView(selectedExercises: $selectedExercises)
                    .environmentObject(supabaseManager)
            }
        }
    }
    
    private func removeExercise(offsets: IndexSet) {
        selectedExercises.remove(atOffsets: offsets)
    }
    
    private func createWorkout() {
        isLoading = true
        
        Task {
            do {
                let workout = Workout(
                    id: UUID().uuidString, // If Workout.id is String
                    userId: supabaseManager.currentUser?.id.uuidString.lowercased() ?? "",
                    name: workoutName,
                    description: workoutDescription.isEmpty ? nil : workoutDescription,
                    exercises: selectedExercises,
                    duration: nil,
                    caloriesBurned: nil,
                    createdAt: Date(),
                    completedAt: nil
                )
                
                try await supabaseManager.createWorkout(workout: workout)
                
                await MainActor.run {
                    isLoading = false
                    dismiss()
                }
            } catch {
                print("Error creating workout: \(error)")
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Exercise Picker View

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager
    @Binding var selectedExercises: [Exercise]
    
    @State private var exercises: [Exercise] = []
    @State private var isLoading = true
    @State private var searchText = ""
    
    var filteredExercises: [Exercise] {
        if searchText.isEmpty {
            return exercises
        } else {
            return exercises.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(searchText) ||
                exercise.muscleGroups.contains { muscle in
                    muscle.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                if isLoading {
                    ProgressView("Loading exercises...")
                } else {
                    List {
                        ForEach(filteredExercises, id: \.id) { exercise in
                            Button(action: {
                                if selectedExercises.contains(where: { $0.id == exercise.id }) {
                                    selectedExercises.removeAll { $0.id == exercise.id }
                                } else {
                                    selectedExercises.append(exercise)
                                }
                            }) {
                                HStack {
                                    ExerciseRowView(exercise: exercise)
                                    
                                    Spacer()
                                    
                                    if selectedExercises.contains(where: { $0.id == exercise.id }) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .searchable(text: $searchText, prompt: "Search exercises...")
                }
            }
            .navigationTitle("Select Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await loadExercises()
            }
        }
    }
    
    private func loadExercises() async {
        do {
            exercises = try await supabaseManager.getAllExercises()
            await MainActor.run {
                isLoading = false
            }
        } catch {
            print("Error loading exercises: \(error)")
            await MainActor.run {
                isLoading = false
            }
        }
    }
}

// MARK: - Exercise Row View

struct ExerciseRowView: View {
    let exercise: Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(exercise.name)
                .font(.headline)
                .foregroundColor(.primary)
            
            if let description = exercise.description {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                Text(exercise.muscleGroups.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(exercise.sets) sets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(exercise.formattedTarget)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Workout Detail View

struct WorkoutDetailView: View {
    let workout: Workout
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var isTrackingWorkout = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(workout.name)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    if let description = workout.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("\(workout.exercises?.count ?? 0) exercises", systemImage: "dumbbell")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(workout.createdAt, style: .date)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                
                // Action Button
                Button("Start Workout") {
                    isTrackingWorkout = true
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                
                // Exercises List
                VStack(alignment: .leading, spacing: 16) {
                    Text("Exercises")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(workout.exercises ?? [], id: \.id) { exercise in
                        ExerciseDetailRowView(exercise: exercise)
                    }
                }
            }
        }
        .navigationTitle("Workout Details")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isTrackingWorkout) {
            WorkoutTrackingView(workout: workout)
                .environmentObject(supabaseManager)
        }
    }
}

// MARK: - Exercise Detail Row View

struct ExerciseDetailRowView: View {
    let exercise: Exercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                    
                    if let description = exercise.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(exercise.sets) sets")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(exercise.formattedTarget)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(exercise.muscleGroups.joined(separator: ", "))
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .padding(.horizontal)
    }
}

// MARK: - Workout Tracking View (Advanced Logging UI)

struct WorkoutTrackingView: View {
    let workout: Workout
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var exerciseLogs: [String: [SetLog]] = [:] // [exerciseId: [SetLog]]
    @State private var isWorkoutCompleted = false
    @State private var workoutStartTime = Date()
    @State private var showingCompletionAlert = false
    @State private var showCongrats = false
    @State private var timer: Timer? = nil
    @State private var elapsedTime: TimeInterval = 0
    // For video modal (future)
    @State private var showingVideo: Bool = false
    @State private var videoURL: URL? = nil

    // Get user unit preference
    var unit: String {
        supabaseManager.userProfile?.unitPreference == "metric" ? "Kg" : "Lbs"
    }

    var formattedTime: String {
        let totalSeconds = Int(elapsedTime)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Timer
            HStack {
                Text(formattedTime)
                    .font(.system(size: 40, weight: .black, design: .rounded))
                    .padding(.top, 16)
                Spacer()
                Button(action: { resetTimer() }) {
                    Image(systemName: "timer")
                        .font(.title2)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal)

            ScrollView {
                VStack(spacing: 16) {
                    ForEach(workout.exercises ?? [], id: \.id) { exercise in
                        ExerciseLoggingCard(
                            exercise: exercise,
                            sets: exercise.sets,
                            setLogs: Binding(
                                get: { exerciseLogs[exercise.id] ?? (1...exercise.sets).map { SetLog(setNumber: $0) } },
                                set: { exerciseLogs[exercise.id] = $0 }
                            ),
                            unit: unit,
                            restTime: exercise.restTime,
                            onPlayVideo: nil, // For future video integration
                            onSetCompleted: { _ in /* Optionally show rest timer or handle set completion */ }
                        )
                    }
                }
                .padding(.horizontal)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            Spacer()
            Button(action: {
                showingCompletionAlert = true
            }) {
                Text("Finish Workout")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#404C61"))
                    .foregroundColor(.white)
                    .cornerRadius(24)
            }
            .padding([.horizontal, .bottom])
            .alert("Finish Workout?", isPresented: $showingCompletionAlert) {
                Button("Yes", role: .destructive) {
                    isWorkoutCompleted = true
                    showCongrats = true
                    // Save logs here (implement as needed)
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            stopTimer()
        }
    }

    // Timer helpers
    private func startTimer() {
        workoutStartTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime = Date().timeIntervalSince(workoutStartTime)
        }
    }
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    private func resetTimer() {
        workoutStartTime = Date()
        elapsedTime = 0
    }
}

// MARK: - Exercise Group Card View

struct ExerciseGroupCard: View {
    let group: ExerciseGroup
    let unit: String
    @Binding var exerciseLogs: [String: [SetLog]]
    let onPlayVideo: ((Exercise) -> Void)?
    let onSetCompleted: (Int?) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Group Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.groupType.displayName.uppercased())
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.blue)
                    
                    if let name = group.name {
                        Text(name)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                if let restTime = group.restTime {
                    Label("\(restTime)s rest", systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Exercises in the group
            ForEach(group.exercises, id: \.id) { exercise in
                ExerciseLoggingCard(
                    exercise: exercise,
                    sets: exercise.sets,
                    setLogs: Binding(
                        get: { exerciseLogs[exercise.id] ?? (1...exercise.sets).map { SetLog(setNumber: $0) } },
                        set: { exerciseLogs[exercise.id] = $0 }
                    ),
                    unit: unit,
                    restTime: exercise.restTime,
                    onPlayVideo: { onPlayVideo?(exercise) },
                    onSetCompleted: onSetCompleted
                )
            }
        }
        .background(Color.blue.opacity(0.05))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
        .padding(.vertical, 8)
    }
}

// MARK: - Grouped Exercise List View

struct GroupedExerciseListView: View {
    let dayExercises: [DayExercise]
    let unit: String
    @Binding var exerciseLogs: [String: [SetLog]]
    let onPlayVideo: ((Exercise) -> Void)?
    let onSetCompleted: (Int?) -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(dayExercises.sorted { $0.orderIndex < $1.orderIndex }) { dayExercise in
                ExerciseLoggingCard(
                    exercise: dayExercise.exercise,
                    sets: dayExercise.sets,
                    setLogs: Binding(
                        get: { exerciseLogs[dayExercise.exercise.id] ?? (1...dayExercise.sets).map { SetLog(setNumber: $0) } },
                        set: { exerciseLogs[dayExercise.exercise.id] = $0 }
                    ),
                    unit: unit,
                    restTime: dayExercise.restTime,
                    onPlayVideo: { onPlayVideo?(dayExercise.exercise) },
                    onSetCompleted: onSetCompleted
                )
            }
        }
    }
}


