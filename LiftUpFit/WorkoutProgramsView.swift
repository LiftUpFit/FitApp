import SwiftUI
import Foundation
import AVKit
    

class WorkoutProgramsViewModel: ObservableObject {
    @Published var programs: [WorkoutProgram] = []
    @Published var isLoading = false
    @Published var error: String?
    @Published var selectedLevel: String = "All Levels"
    
    let levels = ["All Levels", "Foundation", "Rise", "Elevated"]
    
    var filteredPrograms: [WorkoutProgram] {
        if selectedLevel == "All Levels" {
            return programs
        } else {
            return programs.filter { $0.level?.caseInsensitiveCompare(selectedLevel) == .orderedSame }
        }
    }
    
    func fetchPrograms(supabaseManager: SupabaseManager) async {
        await MainActor.run { self.isLoading = true }
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
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct WorkoutProgramsView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @StateObject private var viewModel = WorkoutProgramsViewModel()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                // FEATURED Section
                if !viewModel.programs.filter({ $0.isNew }).isEmpty {
                    Text("FEATURED")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                        .padding(.top, 8)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.programs.filter { $0.isNew }, id: \.id) { program in
                                NavigationLink(destination: ProgramDetailView(program: program)) {
                                    ProgramCard(program: program)
                                        .padding(.horizontal, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                // Foundation Plans
                if !viewModel.programs.filter({ $0.level?.caseInsensitiveCompare("Foundation") == .orderedSame }).isEmpty {
                    Text("Foundation Plans")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.programs.filter { $0.level?.caseInsensitiveCompare("Foundation") == .orderedSame }, id: \.id) { program in
                                NavigationLink(destination: ProgramDetailView(program: program)) {
                                    ProgramCard(program: program)
                                        .padding(.horizontal, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                // Rise Plans
                if !viewModel.programs.filter({ $0.level?.caseInsensitiveCompare("Rise") == .orderedSame }).isEmpty {
                    Text("Rise Plans")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.programs.filter { $0.level?.caseInsensitiveCompare("Rise") == .orderedSame }, id: \.id) { program in
                                NavigationLink(destination: ProgramDetailView(program: program)) {
                                    ProgramCard(program: program)
                                        .padding(.horizontal, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                // Elevated Plans
                if !viewModel.programs.filter({ $0.level?.caseInsensitiveCompare("Elevated") == .orderedSame }).isEmpty {
                    Text("Elevated Plans")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(viewModel.programs.filter { $0.level?.caseInsensitiveCompare("Elevated") == .orderedSame }, id: \.id) { program in
                                NavigationLink(destination: ProgramDetailView(program: program)) {
                                    ProgramCard(program: program)
                                        .padding(.horizontal, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Ascend")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await viewModel.fetchPrograms(supabaseManager: supabaseManager)
        }
    }
}

struct ProgramDetailView: View {
    let program: WorkoutProgram
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var days: [ProgramDay] = []
    @State private var isLoading = true
    @State private var error: String?
    @State private var isEnrolling = false
    @State private var isEnrolled = false
    @State private var enrollError: String?
    @State private var showEnrollSuccess = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let url = program.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Color(.systemGray5)
                                .frame(height: 240)
                                .cornerRadius(16)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 240)
                                .clipped()
                                .cornerRadius(16)
                        case .failure:
                            Color(.systemGray4)
                                .frame(height: 240)
                                .cornerRadius(16)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(height: 240)
                    .cornerRadius(16)
                }
                Text(program.title)
                    .font(.title)
                    .fontWeight(.bold)
                HStack(spacing: 12) {
                    if let level = program.level {
                        Label(level, systemImage: "chart.bar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    if let duration = program.duration {
                        Label(duration, systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                if let desc = program.description {
                    Text(desc)
                        .font(.body)
                        .padding(.top, 8)
                }
                Divider()
                Text("Program Breakdown")
                    .font(.headline)
                    .padding(.bottom, 4)
                if isLoading {
                    ProgressView("Loading days...")
                        .padding(.vertical)
                } else if let error = error {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                        .padding(.vertical)
                } else if days.isEmpty {
                    Text("No days found for this program.")
                        .foregroundColor(.secondary)
                        .padding(.vertical)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                            NavigationLink(destination: DayDetailView(day: day, program: program)) {
                                ProgramDayTimelineCard(day: day, isFirst: idx == 0, isLast: idx == days.count - 1, program: program)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                Spacer(minLength: 32)
                if isEnrolled {
                    Button(action: {}) {
                        Label("Enrolled!", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(true)
                } else {
                    Button(action: enroll) {
                        if isEnrolling {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            Text("Start Program")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                    }
                    .background(Color(hex: "#404C61"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled(isEnrolling)
                }
                if let enrollError = enrollError {
                    Text(enrollError)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.top, 4)
                }
                if showEnrollSuccess {
                    Text("You have been enrolled in this program!")
                        .foregroundColor(.green)
                        .font(.caption)
                        .padding(.top, 4)
                }
            }
            .padding()
        }
        .navigationTitle(program.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDays()
            await checkEnrollment()
        }
    }
    
    private func loadDays() async {
        isLoading = true
        error = nil
        do {
            let programId = program.id
            
            let fetched = try await supabaseManager.fetchProgramDays(programId: programId)
            await MainActor.run {
                self.days = fetched
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    private func checkEnrollment() async {
        let programId = program.id
        do {
            let enrolled = try await supabaseManager.isUserEnrolledInProgram(programId: programId)
            await MainActor.run {
                self.isEnrolled = enrolled
            }
        } catch {
            // Ignore error
        }
    }
    
    private func enroll() {
        Task {
            isEnrolling = true
            enrollError = nil
            showEnrollSuccess = false
            let programId = program.id
            do {
                try await supabaseManager.enrollUserInProgram(programId: programId)
                await MainActor.run {
                    self.isEnrolled = true
                    self.showEnrollSuccess = true
                    self.isEnrolling = false
                }
            } catch {
                await MainActor.run {
                    self.enrollError = error.localizedDescription
                    self.isEnrolling = false
                }
            }
        }
    }
}

struct ProgramCard: View {
    let program: WorkoutProgram
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 8) {
                // Image and bookmark icon
                ZStack(alignment: .topTrailing) {
                    if let url = program.imageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .empty:
                                Color(.systemGray5)
                                    .frame(height: 200)
                                    .cornerRadius(16)
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(16)
                            case .failure:
                                Color(.systemGray4)
                                    .frame(height: 200)
                                    .cornerRadius(16)
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(height: 200)
                        .cornerRadius(16)
                    } else {
                        Color(.systemGray5)
                            .frame(height: 200)
                            .cornerRadius(16)
                    }
                    // Bookmark icon
                    Button(action: {}) {
                        Image(systemName: "bookmark")
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                            .padding(8)
                    }
                }
                Text(program.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Text(program.programDuration)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(program.programLevel)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 4, x: 0, y: 2)
            .frame(width: 240)
            // NEW badge
            if program.isNew {
                Text("NEW")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.black)
                    .cornerRadius(8)
                    .padding(10)
            }
        }
    }
}

struct TopWorkoutCard: View {
    let rank: Int
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(.systemGray5)
                .frame(width: 180, height: 120)
                .cornerRadius(16)
            Text("#\(rank)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(6)
                .background(Color.black.opacity(0.7))
                .cornerRadius(8)
                .padding(8)
        }
    }
}

// MARK: - Timeline Day Card
struct ProgramDayTimelineCard: View {
    let day: ProgramDay
    let isFirst: Bool
    let isLast: Bool
    let program: WorkoutProgram
    
    var isRestDay: Bool {
        day.title.lowercased().contains("rest")
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white)
                .shadow(color: Color(.black).opacity(0.06), radius: 4, x: 0, y: 2)
            HStack(spacing: 0) {
                // Day image or fallback
                if let url = day.imageURL {
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
                    .frame(width: 90, height: 90)
                    .cornerRadius(16, corners: [.topLeft, .bottomLeft])
                } else if isRestDay {
                    ZStack {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 90, height: 90)
                            .cornerRadius(16, corners: [.topLeft, .bottomLeft])
                        Image(systemName: "bed.double.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    }
                } else {
                    ZStack {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 90, height: 90)
                            .cornerRadius(16, corners: [.topLeft, .bottomLeft])
                        Image(systemName: "figure.strengthtraining.traditional")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(isRestDay ? "REST DAY" : day.title.uppercased())
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                        .lineLimit(2)
                    if isRestDay {
                        Text("Rest Day")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    } else {
                        HStack(spacing: 16) {
                            if let duration = day.duration {
                                Text("\(duration) mins")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            if let level = program.level {
                                Text(level)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.leading, 16)
                Spacer()
            }
            .frame(height: 90)
        }
        .padding(.vertical, 4)
    }
}

// Helper for corner radius on specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = 16.0
    var corners: UIRectCorner = .allCorners
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

// MARK: - Day Detail View

struct DayDetailView: View {
    let day: ProgramDay
    let program: WorkoutProgram
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var isStartingWorkout = false
    @State private var dayExercises: [DayExercise] = []
    @State private var isLoadingExercises = true
    @State private var userProgress: UserDayProgress?
    @State private var isLoadingProgress = true
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
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
                }
                
                // Completion Status
                if let progress = userProgress {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Completed")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                            
                            Text(progress.completed_at, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            if let duration = progress.duration_minutes {
                                Text("Duration: \(duration) minutes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Description
                if let description = day.description, !description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About This Day")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // Program Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Program: \(program.title)")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let level = program.level {
                        Text("Level: \(level)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    if let duration = program.duration {
                        Text("Duration: \(duration)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Exercises Section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Today's Exercises")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if isLoadingExercises {
                        ProgressView("Loading exercises...")
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else if dayExercises.isEmpty {
                        Text("No exercises found for this day.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(dayExercises) { dayExercise in
                                DayExerciseCard(dayExercise: dayExercise)
                            }
                        }
                    }
                }
                
                // Action Buttons
                VStack(spacing: 12) {
                    if userProgress == nil {
                        Button("Start Today's Workout") {
                            isStartingWorkout = true
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#404C61"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    } else {
                        Button("Workout Again") {
                            isStartingWorkout = true
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(hex: "#404C61"))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Day \(day.day_number)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadExercises()
            await loadProgress()
        }
        .sheet(isPresented: $isStartingWorkout) {
            if !dayExercises.isEmpty {
                WorkoutSessionView(day: day, program: program, dayExercises: dayExercises)
                    .environmentObject(supabaseManager)
            } else {
                Text("No exercises assigned to this day.")
            }
        }
    }
    
    private func loadExercises() async {
        isLoadingExercises = true
        do {
            print("🔍 Loading exercises for day: \(day.id)")
            let dayExercises = try await supabaseManager.fetchDayExercises(programDayId: day.id.uuidString)
            await MainActor.run {
                self.dayExercises = dayExercises
                self.isLoadingExercises = false
            }
        } catch {
            print("❌ Error loading exercises: \(error)")
            await MainActor.run {
                self.isLoadingExercises = false
            }
        }
    }
    
    private func loadProgress() async {
        isLoadingProgress = true
        do {
            let progress = try await supabaseManager.checkUserDayProgress(programDayId: day.id)
            await MainActor.run {
                self.userProgress = progress
                self.isLoadingProgress = false
            }
        } catch {
            print("Error loading progress: \(error)")
            await MainActor.run {
                self.isLoadingProgress = false
            }
        }
    }
}

// MARK: - Day Exercise Row Component

struct DayExerciseRow: View {
    let dayExercise: DayExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayExercise.exercise.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    if let description = dayExercise.exercise.description {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(dayExercise.sets) sets")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    
                    if let reps = dayExercise.reps {
                        Text("\(reps) reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            HStack {
                Text(dayExercise.exercise.muscleGroups.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                Spacer()
                
                if let restTime = dayExercise.restTime {
                    Label("\(restTime)s rest", systemImage: "timer")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Redesigned Exercise Logging Card for WorkoutSessionView
struct ExerciseLoggingCard: View {
    let exercise: Exercise
    let sets: Int
    @Binding var setLogs: [SetLog]
    let unit: String
    let restTime: Int?
    let onPlayVideo: (() -> Void)?
    let onSetCompleted: (Int?) -> Void
    @State private var showRestTimer = false
    @State private var restTimerSeconds = 60

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
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
                        .frame(width: 90, height: 90)
                        .cornerRadius(16, corners: [.topLeft, .bottomLeft])
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(width: 90, height: 90)
                            .cornerRadius(16, corners: [.topLeft, .bottomLeft])
                        Image(systemName: "figure.strengthtraining.traditional")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .foregroundColor(.gray)
                    }
                    Button(action: { if exercise.videoURL != nil { onPlayVideo?() } }) {
                        Image(systemName: "play.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(Color.white.opacity(0.7))
                    }
                    .opacity(exercise.videoURL == nil ? 0 : 1)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name.uppercased())
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .lineLimit(2)
                        .padding(.top, 8)
                    HStack(spacing: 16) {
                        Text("\(sets) Sets")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                        Text(exercise.formattedTarget)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
                Spacer()
            }
            .padding([.top, .horizontal])
            // Grid header
            HStack {
                Spacer().frame(width: 90)
                Text(unit)
                    .font(.headline)
                    .foregroundColor(.gray)
                    .frame(width: 80, alignment: .center)
                Text(exercise.exerciseType.displayName)
                    .font(.headline)
                    .foregroundColor(.gray)
                    .frame(width: 80, alignment: .center)
                Spacer()
            }
            .padding(.horizontal)
            // Set rows
            VStack(spacing: 8) {
                ForEach(0..<sets, id: \.self) { idx in
                    HStack(spacing: 16) {
                        Spacer().frame(width: 90)
                        TextField(unit, text: Binding(
                            get: { setLogs[idx].weight == nil ? "" : String(format: "%.0f", setLogs[idx].weight ?? 0) },
                            set: { setLogs[idx].weight = Double($0) }
                        ))
                        .keyboardType(.decimalPad)
                        .frame(width: 80, height: 40)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .multilineTextAlignment(.center)
                        
                        // Dynamic input field based on exercise type
                        Group {
                            switch exercise.exerciseType {
                            case .reps:
                                TextField("Reps", text: Binding(
                                    get: { setLogs[idx].reps == nil ? "" : String(setLogs[idx].reps ?? 0) },
                                    set: { setLogs[idx].reps = Int($0) }
                                ))
                                .keyboardType(.numberPad)
                            case .time:
                                TextField("Time", text: Binding(
                                    get: { 
                                        if let duration = setLogs[idx].duration {
                                            let minutes = duration / 60
                                            let seconds = duration % 60
                                            return "\(minutes):\(String(format: "%02d", seconds))"
                                        }
                                        return ""
                                    },
                                    set: { 
                                        let components = $0.split(separator: ":")
                                        if components.count == 2,
                                           let minutes = Int(components[0]),
                                           let seconds = Int(components[1]) {
                                            setLogs[idx].duration = minutes * 60 + seconds
                                        }
                                    }
                                ))
                                .keyboardType(.numbersAndPunctuation)
                            case .distance:
                                TextField("Distance", text: Binding(
                                    get: { setLogs[idx].distance == nil ? "" : String(format: "%.0f", setLogs[idx].distance ?? 0) },
                                    set: { setLogs[idx].distance = Double($0) }
                                ))
                                .keyboardType(.decimalPad)
                            }
                        }
                        .frame(width: 80, height: 40)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .multilineTextAlignment(.center)
                        Button(action: {
                            setLogs[idx].completed.toggle()
                            onSetCompleted(restTime)
                        }) {
                            Image(systemName: setLogs[idx].completed ? "checkmark.circle.fill" : "circle")
                                .resizable()
                                .frame(width: 28, height: 28)
                                .foregroundColor(setLogs[idx].completed ? Color(#colorLiteral(red:0.25, green:0.3, blue:0.38, alpha:1)) : .gray)
                        }
                        .padding(.leading, 8)
                    }
                }
            }
            .padding(.bottom, 16)
            .padding(.horizontal)
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color(.black).opacity(0.08), radius: 8, x: 0, y: 4)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }
}

// Redesigned WorkoutSessionView
struct WorkoutSessionView: View {
    let day: ProgramDay
    let program: WorkoutProgram
    let dayExercises: [DayExercise]
    // Remove workoutId from the initializer, generate a new one for each session
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var exerciseLogs: [String: [SetLog]] = [:] // [exerciseId: [SetLog]]
    @State private var isWorkoutCompleted = false
    @State private var workoutStartTime = Date()
    @State private var showingCompletionAlert = false
    @State private var showCongrats = false
    // For video modal (future)
    @State private var showingVideo = false
    @State private var selectedDemoExercise: Exercise? = nil
    @State private var showRestTimer = false
    @State private var restTimerSeconds = 60
    
    // Get user unit preference
    var unit: String {
        supabaseManager.userProfile?.unitPreference == "metric" ? "Kg" : "Lbs"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    GroupedExerciseListView(
                        dayExercises: dayExercises.sorted { $0.orderIndex < $1.orderIndex },
                        unit: unit,
                        exerciseLogs: $exerciseLogs,
                        onPlayVideo: { exercise in
                            selectedDemoExercise = exercise
                            showingVideo = true
                        },
                        onSetCompleted: { restTime in
                            if let restTime = restTime {
                                restTimerSeconds = restTime
                                showRestTimer = true
                            }
                        }
                    )
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
                    Task {
                        do {
                            let programDayId = day.id
                            let userId = supabaseManager.currentUser?.id.uuidString ?? ""
                            let sessionName = "Day \(day.day_number) - \(program.title)"
                            // Always generate a new unique UUID for each workout session
                            let newWorkoutId = UUID().uuidString
                            try await supabaseManager.createWorkoutSession(workoutId: newWorkoutId, userId: userId, programDayId: programDayId, name: sessionName)
                            // Then log the sets
                            try await supabaseManager.deleteWorkoutLogs(workoutId: newWorkoutId)
                            try await supabaseManager.uploadWorkoutLogs(workoutId: newWorkoutId, programDayId: programDayId, logs: exerciseLogs)
                            try await supabaseManager.markDayAsCompleted(programDayId: programDayId, durationMinutes: Int(Date().timeIntervalSince(workoutStartTime) / 60))
                            await MainActor.run {
                                isWorkoutCompleted = true
                                showCongrats = true
                            }
                        } catch {
                            print("Error logging workout: \(error)")
                            // Optionally show an error alert
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showCongrats) {
                VStack(spacing: 24) {
                    Image(systemName: "checkmark.seal.fill")
                        .resizable()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.green)
                    Text("Workout Complete!")
                        .font(.title)
                        .fontWeight(.bold)
                    Button("Close") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .sheet(isPresented: $showingVideo) {
            if let exercise = selectedDemoExercise {
                ExerciseDemoView(
                    exerciseName: exercise.name,
                    videoURL: exercise.videoURL,
                    imageURL: exercise.imageURL,
                    instructions: exercise.instructions ?? "",
                    onNext: { showingVideo = false }
                )
            } else {
                Text("No video available.")
            }
        }
        .sheet(isPresented: $showRestTimer) {
            RestTimerView(isPresented: $showRestTimer, secondsLeft: restTimerSeconds) {
                // Called when timer ends or is skipped
            }
        }
    }
}

// MARK: - Color extension for hex
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// Preview
struct WorkoutProgramsView_Previews: PreviewProvider {
    static var previews: some View {
        WorkoutProgramsView()
    }
}

// Modern card for exercise preview in DayDetailView
struct DayExerciseCard: View {
    let dayExercise: DayExercise
    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            ZStack {
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
                    .frame(width: 90, height: 90)
                    .cornerRadius(16, corners: [.topLeft, .bottomLeft])
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: 90, height: 90)
                        .cornerRadius(16, corners: [.topLeft, .bottomLeft])
                    Image(systemName: "figure.strengthtraining.traditional")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                }
                Button(action: {}) {
                    Image(systemName: "play.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .opacity(0) // Placeholder for future video
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(dayExercise.exercise.name.uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                    .lineLimit(2)
                HStack(spacing: 16) {
                    if let reps = dayExercise.reps {
                        Text("\(reps) Reps")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Text("\(dayExercise.sets) Sets")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.leading, 16)
            Spacer()
        }
        .frame(height: 90)
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color(.black).opacity(0.05), radius: 4, x: 0, y: 2)
        .padding(.vertical, 4)
    }
}

// Add RestTimerView
struct RestTimerView: View {
    @Binding var isPresented: Bool
    @State var secondsLeft: Int
    let onDone: () -> Void
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text(String(format: "%02d:%02d", secondsLeft / 60, secondsLeft % 60))
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "#404C61"))
                .padding(.top, 40)
            HStack(spacing: 24) {
                Button(action: { if secondsLeft > 10 { secondsLeft -= 10 } }) {
                    Text("-10S")
                        .font(.headline)
                        .frame(width: 100, height: 44)
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
                Button(action: { secondsLeft += 10 }) {
                    Text("+10S")
                        .font(.headline)
                        .frame(width: 100, height: 44)
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
            Button(action: {
                isPresented = false
                onDone()
            }) {
                Text("SKIP")
                    .font(.headline)
                    .frame(width: 120, height: 48)
                    .background(Color(hex: "#404C61"))
                    .foregroundColor(.white)
                    .cornerRadius(24)
            }
            Spacer()
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { timer in
                if secondsLeft > 0 {
                    secondsLeft -= 1
                } else {
                    timer.invalidate()
                    isPresented = false
                    onDone()
                }
            }
        }
    }
} 
