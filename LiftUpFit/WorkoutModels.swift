import Foundation

// MARK: - Exercise Type Enum
enum ExerciseType: String, CaseIterable, Codable {
    case reps = "reps"
    case time = "time"
    case distance = "distance"
    
    var displayName: String {
        switch self {
        case .reps: return "Reps"
        case .time: return "Time"
        case .distance: return "Distance"
        }
    }
}

// MARK: - Exercise Group Type Enum
enum ExerciseGroupType: String, CaseIterable, Codable {
    case single = "single"
    case superset = "superset"
    case circuit = "circuit"
    case dropSet = "drop_set"
    
    var displayName: String {
        switch self {
        case .single: return "Single Exercise"
        case .superset: return "Superset"
        case .circuit: return "Circuit"
        case .dropSet: return "Drop Set"
        }
    }
}

struct Workout: Identifiable, Codable {
    var id: String
    var userId: String
    var name: String
    var description: String?
    var exercises: [Exercise]?
    var duration: Int?
    var caloriesBurned: Int?
    var createdAt: Date
    var completedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case exercises
        case duration
        case caloriesBurned = "calories_burned"
        case createdAt = "created_at"
        case completedAt = "completed_at"
    }
}

struct Exercise: Identifiable, Codable {
    var id: String
    var name: String
    var description: String?
    var muscleGroups: [String]
    var exerciseType: ExerciseType
    var sets: Int
    var reps: Int?
    var weight: Double?
    var duration: Int? // in seconds
    var distance: Double? // in meters
    var restTime: Int?
    var image_url: String?
    var video_url: String?
    var instructions: String?
    var groupId: String? // for grouping exercises (supersets, circuits, etc.)
    var groupType: ExerciseGroupType?
    var groupOrder: Int? // order within the group

    var imageURL: URL? {
        guard let urlString = image_url else { return nil }
        return URL(string: urlString)
    }
    var videoURL: URL? {
        guard let urlString = video_url else { return nil }
        return URL(string: urlString)
    }
    
    // Computed properties for easier access
    var isTimeBased: Bool {
        return exerciseType == .time
    }
    
    var isRepBased: Bool {
        return exerciseType == .reps
    }
    
    var isDistanceBased: Bool {
        return exerciseType == .distance
    }
    
    var isGrouped: Bool {
        return groupId != nil
    }
    
    var formattedTarget: String {
        switch exerciseType {
        case .reps:
            if let reps = reps {
                return "\(reps) reps"
            }
            return "Reps"
        case .time:
            if let duration = duration {
                return formatDuration(duration)
            }
            return "Time"
        case .distance:
            if let distance = distance {
                return "\(Int(distance))m"
            }
            return "Distance"
        }
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        if minutes > 0 {
            return "\(minutes):\(String(format: "%02d", remainingSeconds))"
        } else {
            return "\(remainingSeconds)s"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case muscleGroups = "muscle_groups"
        case exerciseType = "exercise_type"
        case sets
        case reps
        case weight
        case duration
        case distance
        case restTime = "rest_time"
        case image_url
        case video_url
        case instructions
        case groupId = "group_id"
        case groupType = "group_type"
        case groupOrder = "group_order"
    }
}

// MARK: - Exercise Group Model
struct ExerciseGroup: Identifiable, Codable {
    var id: String
    var name: String?
    var groupType: ExerciseGroupType
    var exercises: [Exercise]
    var restTime: Int? // rest time between groups
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case groupType = "group_type"
        case exercises
        case restTime = "rest_time"
    }
}

struct WorkoutSet: Codable {
    let reps: Int?
    let weight: Double?
    let notes: String?
    let completedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case reps
        case weight
        case notes
        case completedAt = "completed_at"
    }
} 

struct SetLog: Identifiable, Codable {
    var id: UUID
    var setNumber: Int
    var reps: Int?
    var weight: Double?
    var duration: Int? // in seconds
    var distance: Double? // in meters
    var completed: Bool

    init(id: UUID = UUID(), setNumber: Int, reps: Int? = nil, weight: Double? = nil, duration: Int? = nil, distance: Double? = nil, completed: Bool = false) {
        self.id = id
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.distance = distance
        self.completed = completed
    }
}
