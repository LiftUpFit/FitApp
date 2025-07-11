import SwiftUI
import Foundation

// MARK: - Admin Panel Main View
struct AdminPanelView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var selectedTab = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 16) {
                    Text("Admin Panel")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("Manage your workout programs, days, and exercises")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemBackground))
                
                // Tab Selector
                HStack(spacing: 0) {
                    TabButton(title: "Programs", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabButton(title: "Exercises", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    TabButton(title: "Supersets", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                    TabButton(title: "Articles", isSelected: selectedTab == 3) {
                        selectedTab = 3
                    }
                }
                .padding(.horizontal)
                
                // Content
                TabView(selection: $selectedTab) {
                    ProgramsAdminView()
                        .tag(0)
                    
                    ExercisesAdminView()
                        .tag(1)
                    
                    SupersetsAdminView()
                        .tag(2)
                    
                    ArticleAdminView()
                        .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Programs Admin View
struct ProgramsAdminView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var programs: [WorkoutProgram] = []
    @State private var isLoading = true
    @State private var showingAddProgram = false
    @State private var selectedProgram: WorkoutProgram?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Add Button
            HStack {
                Text("Workout Programs")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { showingAddProgram = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "#404C61"))
                }
            }
            .padding()
            
            if isLoading {
                Spacer()
                ProgressView("Loading programs...")
                Spacer()
            } else if programs.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Programs Yet")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Create your first workout program to get started")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Add Program") {
                        showingAddProgram = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(programs) { program in
                            ProgramAdminCard(program: program) {
                                print("[DEBUG] Program tapped: \(program.id) - \(program.title)")
                                selectedProgram = program
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadPrograms()
        }
        .sheet(isPresented: $showingAddProgram) {
            AddProgramView { _ in
                Task { await loadPrograms() }
            }
        }
        .sheet(item: $selectedProgram, onDismiss: { selectedProgram = nil }) { program in
            ProgramDetailAdminView(program: program)
        }
    }
    
    private func loadPrograms() async {
        isLoading = true
        do {
            let response: [WorkoutProgram] = try await supabaseManager.client
                .from("workout_programs")
                .select("id::text, title, subtitle, image_url, is_new, duration, level, description")
                .order("title", ascending: true)
                .execute()
                .value
            
            await MainActor.run {
                self.programs = response
                self.isLoading = false
            }
        } catch {
            print("Error loading programs: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Program Admin Card
struct ProgramAdminCard: View {
    let program: WorkoutProgram
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Image
                if let url = program.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color(.systemGray5)
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            Color(.systemGray4)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "dumbbell")
                                .foregroundColor(.gray)
                        )
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(program.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        if let level = program.level {
                            Text(level)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                        
                        if let duration = program.duration {
                            Text(duration)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Program View
struct AddProgramView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var title = ""
    @State private var subtitle = ""
    @State private var description = ""
    @State private var level = "Foundation"
    @State private var duration = ""
    @State private var imageURL = ""
    @State private var isNew = false
    @State private var isSaving = false
    @State private var error: String?
    
    let onSave: (WorkoutProgram) -> Void
    
    private let levels = ["Foundation", "Rise", "Elevated"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Program Details") {
                    TextField("Title", text: $title)
                    TextField("Subtitle (Optional)", text: $subtitle)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Program Settings") {
                    Picker("Level", selection: $level) {
                        ForEach(levels, id: \.self) { level in
                            Text(level).tag(level)
                        }
                    }
                    
                    TextField("Duration (e.g., '8 weeks')", text: $duration)
                    TextField("Image URL (Optional)", text: $imageURL)
                    
                    Toggle("Mark as New", isOn: $isNew)
                }
            }
            .navigationTitle("Add Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveProgram()
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error {
                    Text(error)
                }
            }
        }
    }
    
    private func saveProgram() {
        guard !title.isEmpty else { return }
        
        isSaving = true
        error = nil
        
        Task {
            do {
                let program = WorkoutProgram(
                    id: UUID().uuidString,
                    title: title,
                    subtitle: subtitle.isEmpty ? nil : subtitle,
                    image_url: imageURL.isEmpty ? nil : imageURL,
                    is_new: isNew,
                    duration: duration.isEmpty ? nil : duration,
                    level: level,
                    description: description.isEmpty ? nil : description
                )
                
                try await supabaseManager.client
                    .from("workout_programs")
                    .insert(program)
                    .execute()
                
                await MainActor.run {
                    onSave(program)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isSaving = false
                }
            }
        }
    }
}

// MARK: - Program Detail Admin View
struct ProgramDetailAdminView: View {
    let program: WorkoutProgram
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var days: [ProgramDay] = []
    @State private var isLoading = true
    @State private var showingAddDay = false
    @State private var selectedDay: ProgramDay?
    @State private var error: String? = nil
    
    var body: some View {
        print("[DEBUG] ProgramDetailAdminView body for program: \(program.id) - \(program.title)")
        return NavigationView {
            VStack(spacing: 0) {
                // Program Info Header
                VStack(alignment: .leading, spacing: 12) {
                    Text(program.title)
                        .font(.title)
                        .fontWeight(.bold)
                    if let level = program.level {
                        Text("Level: \(level)")
                    }
                    if let duration = program.duration {
                        Text("Duration: \(duration)")
                    }
                    if let desc = program.description {
                        Text(desc)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()

                // Program Days Section (real data, interactive)
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Program Days")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: { showingAddDay = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color(hex: "#404C61"))
                        }
                    }
                    if let error = error {
                        Text(error)
                            .foregroundColor(.red)
                            .padding()
                    } else if isLoading {
                        ProgressView("Loading days...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if days.isEmpty {
                        Text("No days found for this program.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(days) { day in
                            Button(action: { selectedDay = day }) {
                                HStack {
                                    Text("Day \(day.day_number)")
                                        .fontWeight(.semibold)
                                    Text(day.title)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding()
                Spacer()
            }
            .task {
                print("[DEBUG] .task triggered for ProgramDetailAdminView, program.id: \(program.id)")
                if program.id.isEmpty {
                    print("[DEBUG] Program ID is empty, setting error state.")
                    error = "Invalid program ID. Please try again."
                    isLoading = false
                } else {
                    print("[DEBUG] Calling loadDays() for program.id: \(program.id)")
                    await loadDays()
                    print("[DEBUG] loadDays() completed for program.id: \(program.id)")
                }
            }
            .sheet(isPresented: $showingAddDay) {
                AddProgramDayView(program: program) { newDay in
                    days.append(newDay)
                }
            }
            .sheet(item: $selectedDay, onDismiss: { selectedDay = nil }) { day in
                ProgramDayDetailAdminView(day: day, program: program)
            }
        }
    }
    
    private func loadDays() async {
        print("[DEBUG] loadDays() started for program.id: \(program.id)")
        isLoading = true
        error = nil
        do {
            let fetched = try await supabaseManager.fetchProgramDays(programId: program.id)
            print("[DEBUG] fetchProgramDays returned \(fetched.count) days for program.id: \(program.id)")
            await MainActor.run {
                self.days = fetched
                self.isLoading = false
                if fetched.isEmpty {
                    self.error = "No days found for this program."
                }
            }
        } catch {
            print("[DEBUG] Error loading days: \(error)")
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
        print("[DEBUG] loadDays() finished for program.id: \(program.id)")
    }
}

// MARK: - Program Day Admin Card
struct ProgramDayAdminCard: View {
    let day: ProgramDay
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Day Number
                ZStack {
                    Circle()
                        .fill(Color(hex: "#404C61"))
                        .frame(width: 40, height: 40)
                    
                    Text("\(day.day_number)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let duration = day.duration {
                        Text("\(duration) minutes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Program Day View
struct AddProgramDayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var title = ""
    @State private var description = ""
    @State private var duration = ""
    @State private var imageURL = ""
    @State private var isSaving = false
    @State private var error: String?
    
    let program: WorkoutProgram
    let onSave: (ProgramDay) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Day Details") {
                    TextField("Title", text: $title)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Settings") {
                    TextField("Duration (minutes)", text: $duration)
                        .keyboardType(.numberPad)
                    TextField("Image URL (Optional)", text: $imageURL)
                }
            }
            .navigationTitle("Add Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveDay()
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error {
                    Text(error)
                }
            }
        }
    }
    
    private func saveDay() {
        guard !title.isEmpty else { return }
        
        isSaving = true
        error = nil
        
        Task {
            do {
                // Get the next day number
                let existingDays = try await supabaseManager.fetchProgramDays(programId: program.id)
                let nextDayNumber = existingDays.count + 1
                
                let day = ProgramDay(
                    id: UUID(),
                    program_id: UUID(uuidString: program.id) ?? UUID(),
                    day_number: nextDayNumber,
                    title: title,
                    description: description.isEmpty ? nil : description,
                    duration: Int(duration),
                    workout_id: nil,
                    image_url: imageURL.isEmpty ? nil : imageURL
                )
                
                try await supabaseManager.client
                    .from("program_days")
                    .insert(day)
                    .execute()
                
                await MainActor.run {
                    onSave(day)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isSaving = false
                }
            }
        }
    }
}

// MARK: - Program Day Detail Admin View
struct ProgramDayDetailAdminView: View {
    let day: ProgramDay
    let program: WorkoutProgram
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var dayExercises: [DayExercise] = []
    @State private var isLoading = true
    @State private var showingAddExercise = false
    
    var body: some View {
        print("[DEBUG] ProgramDayDetailAdminView body for day: \(day.id) - \(day.title)")
        return NavigationView {
            VStack(spacing: 0) {
                // Day Info Header
                VStack(alignment: .leading, spacing: 12) {
                    Text("Day \(day.day_number)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text(day.title)
                        .font(.title)
                        .fontWeight(.bold)
                    HStack(spacing: 16) {
                        if let duration = day.duration {
                            Label("\(duration) minutes", systemImage: "clock")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        if let level = program.level {
                            Label(level, systemImage: "chart.bar")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    if let desc = day.description {
                        Text(desc)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()

                // Exercises Section
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Exercises")
                            .font(.title2)
                            .fontWeight(.bold)
                        Spacer()
                        Button(action: { showingAddExercise = true }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundColor(Color(hex: "#404C61"))
                        }
                    }
                    .padding(.horizontal)
                    if isLoading {
                        ProgressView("Loading exercises...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if dayExercises.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 48))
                                .foregroundColor(.secondary)
                            Text("No Exercises Yet")
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("Add exercises to this day")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("Add Exercise") {
                                showingAddExercise = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(dayExercises) { dayExercise in
                                    DayExerciseAdminCard(dayExercise: dayExercise)
                                }
                            }
                            .padding()
                        }
                    }
                }
                Spacer()
            }
            .navigationTitle("Day \(day.day_number)")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await loadExercises()
            }
            .sheet(isPresented: $showingAddExercise) {
                AddExerciseToDayView(day: day) {
                    Task {
                        await loadExercises()
                    }
                }
            }
        }
    }
    
    private func loadExercises() async {
        print("🔍 ProgramDayDetailAdminView: Starting to load exercises for day: \(day.id)")
        isLoading = true
        do {
            let exercises = try await supabaseManager.fetchDayExercises(programDayId: day.id.uuidString)
            print("✅ ProgramDayDetailAdminView: Successfully loaded \(exercises.count) exercises")
            await MainActor.run {
                self.dayExercises = exercises
                self.isLoading = false
            }
        } catch {
            print("❌ ProgramDayDetailAdminView: Error loading exercises: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Day Exercise Admin Card
struct DayExerciseAdminCard: View {
    let dayExercise: DayExercise
    
    var body: some View {
        HStack(spacing: 16) {
            // Exercise Image
            if let url = dayExercise.exercise.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Color(.systemGray5)
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        Color(.systemGray4)
                    @unknown default:
                        EmptyView()
                    }
                }
                .frame(width: 50, height: 50)
                .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "figure.strengthtraining.traditional")
                            .foregroundColor(.gray)
                    )
            }
            
            // Exercise Info
            VStack(alignment: .leading, spacing: 4) {
                Text(dayExercise.exercise.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    Text("\(dayExercise.sets) sets")
                        .font(.caption)
                        .foregroundColor(.blue)
                    
                    if let reps = dayExercise.reps {
                        Text("\(reps) reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let restTime = dayExercise.restTime {
                        Text("\(restTime)s rest")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Add Exercise to Day View
struct AddExerciseToDayView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var exercises: [Exercise] = []
    @State private var selectedExercise: Exercise?
    @State private var sets = 3
    @State private var reps = 10
    @State private var restTime = 60
    @State private var orderIndex = 1
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var error: String?
    
    let day: ProgramDay
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isLoading {
                    ProgressView("Loading exercises...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack(spacing: 20) {
                        // Exercise Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Exercise")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            ScrollView {
                                LazyVStack(spacing: 8) {
                                    ForEach(exercises) { exercise in
                                        ExerciseSelectionCard(
                                            exercise: exercise,
                                            isSelected: selectedExercise?.id == exercise.id
                                        ) {
                                            selectedExercise = exercise
                                        }
                                    }
                                }
                            }
                        }
                        
                        if selectedExercise != nil {
                            // Exercise Settings
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Exercise Settings")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                HStack {
                                    Text("Sets:")
                                    Spacer()
                                    Stepper("\(sets)", value: $sets, in: 1...10)
                                }
                                
                                HStack {
                                    Text("Reps:")
                                    Spacer()
                                    Stepper("\(reps)", value: $reps, in: 1...50)
                                }
                                
                                HStack {
                                    Text("Rest Time:")
                                    Spacer()
                                    Stepper("\(restTime)s", value: $restTime, in: 30...300, step: 15)
                                }
                                Stepper("Order: \(orderIndex)", value: $orderIndex, in: 1...50)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        Spacer()
                    }
                    .padding()
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addExercise()
                    }
                    .disabled(selectedExercise == nil || isSaving)
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error {
                    Text(error)
                }
            }
        }
        .task {
            await loadExercises()
        }
    }
    
    private func loadExercises() async {
        isLoading = true
        do {
            let allExercises = try await supabaseManager.getAllExercises()
            print("[DEBUG] AddExerciseToDayView: Loaded \(allExercises.count) exercises")
            for ex in allExercises {
                print("[DEBUG] AddExerciseToDayView: Exercise: \(ex.id) - \(ex.name)")
            }
            await MainActor.run {
                self.exercises = allExercises
                self.isLoading = false
            }
        } catch {
            print("Error loading exercises: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func addExercise() {
        guard let exercise = selectedExercise else { return }
        
        isSaving = true
        error = nil
        
        Task {
            do {
                let programDayExercise = ProgramDayExercise(
                    id: UUID().uuidString,
                    program_day_id: day.id.uuidString,
                    exercise_id: exercise.id,
                    exercise_type: exercise.exerciseType.rawValue,
                    sets: sets,
                    reps: exercise.exerciseType == .time ? nil : reps,
                    weight: nil,
                    duration: exercise.exerciseType == .time ? exercise.duration : nil,
                    rest_time: restTime,
                    order_index: orderIndex
                )
                
                try await supabaseManager.client
                    .from("program_day_exercises")
                    .insert(programDayExercise)
                    .execute()
                
                await MainActor.run {
                    onSave()
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isSaving = false
                }
            }
        }
    }
}

// MARK: - Exercise Selection Card
struct ExerciseSelectionCard: View {
    let exercise: Exercise
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Exercise Image
                if let url = exercise.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color(.systemGray5)
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            Color(.systemGray4)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 40, height: 40)
                    .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "figure.strengthtraining.traditional")
                                .foregroundColor(.gray)
                        )
                }
                
                // Exercise Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(exercise.muscleGroups.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Selection Indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#404C61"))
                        .font(.title3)
                }
            }
            .padding()
            .background(isSelected ? Color(hex: "#404C61").opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color(hex: "#404C61") : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Exercises Admin View
struct ExercisesAdminView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var exercises: [Exercise] = []
    @State private var isLoading = true
    @State private var showingAddExercise = false
    @State private var selectedExercise: Exercise?
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Add Button
            HStack {
                Text("Exercises")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { showingAddExercise = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "#404C61"))
                }
            }
            .padding()
            
            if isLoading {
                Spacer()
                ProgressView("Loading exercises...")
                Spacer()
            } else if exercises.isEmpty {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    
                    Text("No Exercises Yet")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("Create exercises to use in your programs")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Add Exercise") {
                        showingAddExercise = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(exercises) { exercise in
                            ExerciseAdminCard(exercise: exercise) {
                                selectedExercise = exercise
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadExercises()
        }
        .sheet(isPresented: $showingAddExercise) {
            AddExerciseView { newExercise in
                exercises.append(newExercise)
            }
        }
        .sheet(item: $selectedExercise) { exercise in
            EditExerciseView(exercise: exercise) { updatedExercise in
                if let index = exercises.firstIndex(where: { $0.id == updatedExercise.id }) {
                    exercises[index] = updatedExercise
                }
            }
        }
    }
    
    private func loadExercises() async {
        isLoading = true
        do {
            let allExercises = try await supabaseManager.getAllExercises()
            await MainActor.run {
                self.exercises = allExercises
                self.isLoading = false
            }
        } catch {
            print("Error loading exercises: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - Exercise Admin Card
struct ExerciseAdminCard: View {
    let exercise: Exercise
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Exercise Image
                if let url = exercise.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color(.systemGray5)
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        case .failure:
                            Color(.systemGray4)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 60, height: 60)
                    .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "figure.strengthtraining.traditional")
                                .foregroundColor(.gray)
                        )
                }
                
                // Exercise Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    HStack {
                        Text(exercise.muscleGroups.joined(separator: ", "))
                            .font(.caption)
                            .foregroundColor(.blue)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(exercise.exerciseType.displayName)
                            .font(.caption2)
                            .foregroundColor(.orange)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(4)
                    }
                    
                    if let description = exercise.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack {
                        Text("\(exercise.sets) sets")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(exercise.formattedTarget)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Exercise View
struct AddExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var name = ""
    @State private var description = ""
    @State private var muscleGroups = ""
    @State private var imageURL = ""
    @State private var videoURL = ""
    @State private var selectedExerciseType: ExerciseType = .reps
    @State private var sets = 3
    @State private var reps = 10
    @State private var duration = 30
    @State private var distance = 100.0
    @State private var weight = ""
    @State private var restTime = 60
    @State private var orderIndex = 1
    @State private var isSaving = false
    @State private var error: String?
    
    let onSave: (Exercise) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exercise Details") {
                    TextField("Name", text: $name)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Exercise Type") {
                    Picker("Type", selection: $selectedExerciseType) {
                        ForEach(ExerciseType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Muscle Groups") {
                    TextField("Muscle Groups (comma separated)", text: $muscleGroups)
                        .placeholder(when: muscleGroups.isEmpty) {
                            Text("e.g., Chest, Triceps")
                                .foregroundColor(.secondary)
                        }
                }
                
                Section("Exercise Parameters") {
                    Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                    
                    switch selectedExerciseType {
                    case .reps:
                        Stepper("Reps: \(reps)", value: $reps, in: 1...50)
                    case .time:
                        Stepper("Duration: \(duration) seconds", value: $duration, in: 5...300, step: 5)
                    case .distance:
                        Stepper("Distance: \(Int(distance))m", value: $distance, in: 10...1000, step: 10)
                    }
                    
                    TextField("Weight (Optional)", text: $weight)
                        .keyboardType(.decimalPad)
                    
                    Stepper("Rest Time: \(restTime) seconds", value: $restTime, in: 0...300, step: 15)
                    Stepper("Order: \(orderIndex)", value: $orderIndex, in: 1...50)
                }
                
                Section("Media") {
                    TextField("Image URL (Optional)", text: $imageURL)
                    TextField("Video URL (Optional)", text: $videoURL)
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExercise()
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error {
                    Text(error)
                }
            }
        }
    }
    
    private func saveExercise() {
        guard !name.isEmpty else { return }
        
        isSaving = true
        error = nil
        
        Task {
            do {
                let muscleGroupsArray = muscleGroups
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                
                let exercise = Exercise(
                    id: UUID().uuidString,
                    name: name,
                    description: description.isEmpty ? nil : description,
                    muscleGroups: muscleGroupsArray.isEmpty ? ["Full Body"] : muscleGroupsArray,
                    exerciseType: selectedExerciseType,
                    sets: sets,
                    reps: selectedExerciseType == .reps ? reps : nil,
                    weight: weight.isEmpty ? nil : Double(weight),
                    duration: selectedExerciseType == .time ? duration : nil,
                    distance: selectedExerciseType == .distance ? distance : nil,
                    restTime: restTime,
                    image_url: imageURL.isEmpty ? nil : imageURL,
                    video_url: videoURL.isEmpty ? nil : videoURL,
                    instructions: nil,
                    groupId: nil,
                    groupType: nil,
                    groupOrder: orderIndex
                )
                
                try await supabaseManager.client
                    .from("exercises")
                    .insert(exercise)
                    .execute()
                
                await MainActor.run {
                    onSave(exercise)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isSaving = false
                }
            }
        }
    }
}

// MARK: - View Extension for Placeholder
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {
        
        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// MARK: - Preview
struct AdminPanelView_Previews: PreviewProvider {
    static var previews: some View {
        AdminPanelView()
            .environmentObject(SupabaseManager.shared)
    }
}

// MARK: - Supersets Admin View
struct SupersetsAdminView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var exercises: [Exercise] = []
    @State private var isLoading = true
    @State private var showingCreateSuperset = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with Add Button
            HStack {
                Text("Exercise Groups")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: { showingCreateSuperset = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(Color(hex: "#404C61"))
                }
            }
            .padding()
            
            if isLoading {
                Spacer()
                ProgressView("Loading exercises...")
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        // Show existing grouped exercises
                        let groupedExercises = organizeExercisesIntoGroups(exercises)
                        
                        ForEach(groupedExercises.filter { $0.groupType != .single }, id: \.id) { group in
                            SupersetGroupCard(group: group)
                        }
                        
                        if groupedExercises.filter({ $0.groupType != .single }).isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "link.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                
                                Text("No Exercise Groups Yet")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Text("Create supersets, circuits, and other exercise groups")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                Button("Create Group") {
                                    showingCreateSuperset = true
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
            }
        }
        .task {
            await loadExercises()
        }
        .sheet(isPresented: $showingCreateSuperset) {
            CreateSupersetView { _ in
                Task { await loadExercises() }
            }
        }
    }
    
    private func loadExercises() async {
        isLoading = true
        do {
            let allExercises = try await supabaseManager.getAllExercises()
            await MainActor.run {
                self.exercises = allExercises
                self.isLoading = false
            }
        } catch {
            print("Error loading exercises: \(error)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    private func organizeExercisesIntoGroups(_ exercises: [Exercise]) -> [ExerciseGroup] {
        var groups: [String: ExerciseGroup] = [:]
        
        for exercise in exercises {
            if let groupId = exercise.groupId {
                if groups[groupId] == nil {
                    groups[groupId] = ExerciseGroup(
                        id: groupId,
                        name: nil,
                        groupType: exercise.groupType ?? .single,
                        exercises: [],
                        restTime: nil
                    )
                }
                groups[groupId]?.exercises.append(exercise)
            } else {
                // Single exercise
                let singleGroup = ExerciseGroup(
                    id: exercise.id,
                    name: nil,
                    groupType: .single,
                    exercises: [exercise],
                    restTime: exercise.restTime
                )
                groups[exercise.id] = singleGroup
            }
        }
        
        // Sort exercises within each group
        for groupId in groups.keys {
            groups[groupId]?.exercises.sort { 
                ($0.groupOrder ?? 0) < ($1.groupOrder ?? 0)
            }
        }
        
        return Array(groups.values)
    }
}

// MARK: - Superset Group Card
struct SupersetGroupCard: View {
    let group: ExerciseGroup
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Group Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.groupType.displayName.uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    if let name = group.name {
                        Text(name)
                            .font(.subheadline)
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
            
            // Exercises in the group
            ForEach(group.exercises, id: \.id) { exercise in
                HStack {
                    Text("\(exercise.groupOrder ?? 0).")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    Text(exercise.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(exercise.sets) sets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(exercise.formattedTarget)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Create Superset View
struct CreateSupersetView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var exercises: [Exercise] = []
    @State private var selectedExercises: [Exercise] = []
    @State private var groupType: ExerciseGroupType = .superset
    @State private var groupName = ""
    @State private var restTime = 60
    @State private var isSaving = false
    @State private var error: String?
    
    let onSave: (ExerciseGroup) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Group Configuration
                Form {
                    Section("Group Configuration") {
                        Picker("Group Type", selection: $groupType) {
                            ForEach(ExerciseGroupType.allCases.filter { $0 != .single }, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        
                        TextField("Group Name (Optional)", text: $groupName)
                        
                        Stepper("Rest Time: \(restTime) seconds", value: $restTime, in: 0...300, step: 15)
                    }
                    
                    Section("Select Exercises") {
                        if selectedExercises.isEmpty {
                            Text("No exercises selected")
                                .foregroundColor(.secondary)
                        } else {
                            ForEach(selectedExercises, id: \.id) { exercise in
                                HStack {
                                    Text(exercise.name)
                                    Spacer()
                                    Button("Remove") {
                                        selectedExercises.removeAll { $0.id == exercise.id }
                                    }
                                    .foregroundColor(.red)
                                }
                            }
                        }
                        
                        Button("Add Exercise") {
                            // Show exercise picker
                        }
                        .foregroundColor(.blue)
                    }
                }
            }
            .navigationTitle("Create \(groupType.displayName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSuperset()
                    }
                    .disabled(selectedExercises.count < 2 || isSaving)
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error {
                    Text(error)
                }
            }
        }
        .task {
            await loadExercises()
        }
    }
    
    private func loadExercises() async {
        do {
            exercises = try await supabaseManager.getAllExercises()
        } catch {
            print("Error loading exercises: \(error)")
        }
    }
    
    private func saveSuperset() {
        guard selectedExercises.count >= 2 else { return }
        
        isSaving = true
        error = nil
        
        Task {
            do {
                let groupId = UUID().uuidString
                
                // Update each exercise with group information
                for (index, exercise) in selectedExercises.enumerated() {
                    var updatedExercise = exercise
                    updatedExercise.groupId = groupId
                    updatedExercise.groupType = groupType
                    updatedExercise.groupOrder = index + 1
                    
                    try await supabaseManager.client
                        .from("exercises")
                        .update([
                            "group_id": groupId,
                            "group_type": groupType.rawValue,
                            "group_order": String(index + 1)
                        ])
                        .eq("id", value: exercise.id)
                        .execute()
                }
                
                let group = ExerciseGroup(
                    id: groupId,
                    name: groupName.isEmpty ? nil : groupName,
                    groupType: groupType,
                    exercises: selectedExercises,
                    restTime: restTime
                )
                
                await MainActor.run {
                    onSave(group)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isSaving = false
                }
            }
        }
    }
}

// MARK: - Edit Exercise View
struct EditExerciseView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager
    
    let exercise: Exercise
    let onSave: (Exercise) -> Void
    
    @State private var name: String
    @State private var description: String
    @State private var muscleGroups: String
    @State private var selectedExerciseType: ExerciseType
    @State private var sets: Int
    @State private var reps: Int
    @State private var duration: Int
    @State private var distance: Double
    @State private var weight: String
    @State private var restTime: Int
    @State private var imageURL: String
    @State private var videoURL: String
    @State private var orderIndex: Int
    @State private var isSaving = false
    @State private var error: String?
    
    init(exercise: Exercise, onSave: @escaping (Exercise) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        
        // Initialize state with current exercise values
        _name = State(initialValue: exercise.name)
        _description = State(initialValue: exercise.description ?? "")
        _muscleGroups = State(initialValue: exercise.muscleGroups.joined(separator: ", "))
        _selectedExerciseType = State(initialValue: exercise.exerciseType)
        _sets = State(initialValue: exercise.sets)
        _reps = State(initialValue: exercise.reps ?? 10)
        _duration = State(initialValue: exercise.duration ?? 30)
        _distance = State(initialValue: exercise.distance ?? 100.0)
        _weight = State(initialValue: exercise.weight?.description ?? "")
        _restTime = State(initialValue: exercise.restTime ?? 60)
        _imageURL = State(initialValue: exercise.image_url ?? "")
        _videoURL = State(initialValue: exercise.video_url ?? "")
        _orderIndex = State(initialValue: exercise.groupOrder ?? 1)
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("Exercise Details") {
                    TextField("Name", text: $name)
                    TextField("Description (Optional)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Exercise Type") {
                    Picker("Type", selection: $selectedExerciseType) {
                        ForEach(ExerciseType.allCases, id: \.self) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section("Muscle Groups") {
                    TextField("Muscle Groups (comma separated)", text: $muscleGroups)
                        .placeholder(when: muscleGroups.isEmpty) {
                            Text("e.g., Chest, Triceps")
                                .foregroundColor(.secondary)
                        }
                }
                
                Section("Exercise Parameters") {
                    Stepper("Sets: \(sets)", value: $sets, in: 1...10)
                    
                    switch selectedExerciseType {
                    case .reps:
                        Stepper("Reps: \(reps)", value: $reps, in: 1...50)
                    case .time:
                        Stepper("Duration: \(duration) seconds", value: $duration, in: 5...300, step: 5)
                    case .distance:
                        Stepper("Distance: \(Int(distance))m", value: $distance, in: 10...1000, step: 10)
                    }
                    
                    TextField("Weight (Optional)", text: $weight)
                        .keyboardType(.decimalPad)
                    
                    Stepper("Rest Time: \(restTime) seconds", value: $restTime, in: 0...300, step: 15)
                    Stepper("Order: \(orderIndex)", value: $orderIndex, in: 1...50)
                }
                
                Section("Media") {
                    TextField("Image URL (Optional)", text: $imageURL)
                    TextField("Video URL (Optional)", text: $videoURL)
                }
            }
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveExercise()
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error {
                    Text(error)
                }
            }
        }
    }
    
    private func saveExercise() {
        guard !name.isEmpty else { return }
        
        isSaving = true
        error = nil
        
        Task {
            do {
                let muscleGroupsArray = muscleGroups
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                
                let updatedExercise = Exercise(
                    id: exercise.id,
                    name: name,
                    description: description.isEmpty ? nil : description,
                    muscleGroups: muscleGroupsArray.isEmpty ? ["Full Body"] : muscleGroupsArray,
                    exerciseType: selectedExerciseType,
                    sets: sets,
                    reps: selectedExerciseType == .reps ? reps : nil,
                    weight: weight.isEmpty ? nil : Double(weight),
                    duration: selectedExerciseType == .time ? duration : nil,
                    distance: selectedExerciseType == .distance ? distance : nil,
                    restTime: restTime,
                    image_url: imageURL.isEmpty ? nil : imageURL,
                    video_url: videoURL.isEmpty ? nil : videoURL,
                    instructions: exercise.instructions,
                    groupId: exercise.groupId,
                    groupType: exercise.groupType,
                    groupOrder: orderIndex
                )
                
                // Convert muscle groups array to JSON string
                let muscleGroupsData = try JSONSerialization.data(withJSONObject: updatedExercise.muscleGroups)
                let muscleGroupsString = String(data: muscleGroupsData, encoding: .utf8) ?? "[]"
                
                // Update exercise using individual field updates
                try await supabaseManager.client
                    .from("exercises")
                    .update([
                        "name": updatedExercise.name,
                        "muscle_groups": muscleGroupsString,
                        "exercise_type": updatedExercise.exerciseType.rawValue,
                        "sets": String(updatedExercise.sets),
                        "rest_time": String(updatedExercise.restTime ?? 60),
                        "order_index": String(orderIndex)
                    ])
                    .eq("id", value: exercise.id)
                    .execute()
                
                // Update optional fields separately if they exist
                if let description = updatedExercise.description {
                    try await supabaseManager.client
                        .from("exercises")
                        .update(["description": description])
                        .eq("id", value: exercise.id)
                        .execute()
                }
                
                if let reps = updatedExercise.reps {
                    try await supabaseManager.client
                        .from("exercises")
                        .update(["reps": String(reps)])
                        .eq("id", value: exercise.id)
                        .execute()
                }
                
                if let weight = updatedExercise.weight {
                    try await supabaseManager.client
                        .from("exercises")
                        .update(["weight": String(weight)])
                        .eq("id", value: exercise.id)
                        .execute()
                }
                
                if let duration = updatedExercise.duration {
                    try await supabaseManager.client
                        .from("exercises")
                        .update(["duration": String(duration)])
                        .eq("id", value: exercise.id)
                        .execute()
                }
                
                if let distance = updatedExercise.distance {
                    try await supabaseManager.client
                        .from("exercises")
                        .update(["distance": String(distance)])
                        .eq("id", value: exercise.id)
                        .execute()
                }
                
                if let imageURL = updatedExercise.image_url {
                    try await supabaseManager.client
                        .from("exercises")
                        .update(["image_url": imageURL])
                        .eq("id", value: exercise.id)
                        .execute()
                }
                
                if let videoURL = updatedExercise.video_url {
                    try await supabaseManager.client
                        .from("exercises")
                        .update(["video_url": videoURL])
                        .eq("id", value: exercise.id)
                        .execute()
                }
                
                await MainActor.run {
                    onSave(updatedExercise)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                    self.isSaving = false
                }
            }
        }
    }
} 
