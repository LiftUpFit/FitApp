import Foundation

struct WorkoutProgram: Identifiable, Codable {
    var id: String
    var title: String
    var subtitle: String?
    var image_url: String?
    var is_new: Bool?
    var duration: String?
    var level: String?
    var description: String?
    
    var imageURL: URL? {
        guard let urlString = image_url else { return nil }
        return URL(string: urlString)
    }

    var isNew: Bool { is_new ?? false }
    var programLevel: String { level ?? "" }
    var programDuration: String { duration ?? "" }
}

struct ProgramDay: Identifiable, Codable {
    var id: UUID
    var program_id: UUID
    var day_number: Int
    var title: String
    var description: String?
    var duration: Int? // in minutes
    var workout_id: String?
    var image_url: String?
    
    var imageURL: URL? {
        guard let urlString = image_url else { return nil }
        return URL(string: urlString)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case program_id = "program_id"
        case day_number = "day_number"
        case title
        case description
        case duration
        case workout_id = "workout_id"
        case image_url
    }
}

struct ProgramDayExercise: Identifiable, Codable {
    var id: String
    var program_day_id: String
    var exercise_id: String
    var exercise_type: String? // "reps", "time", "distance"
    var sets: Int
    var reps: Int?
    var weight: Double?
    var duration: Int? // in seconds
    var distance: Double? // in meters
    var rest_time: Int? // in seconds
    var order_index: Int
    var group_id: String? // for grouping exercises (supersets, circuits, etc.)
    var group_type: String? // "single", "superset", "circuit", "drop_set"
    var group_order: Int? // order within the group
    
    enum CodingKeys: String, CodingKey {
        case id
        case program_day_id = "program_day_id"
        case exercise_id = "exercise_id"
        case exercise_type = "exercise_type"
        case sets
        case reps
        case weight
        case duration
        case distance
        case rest_time = "rest_time"
        case order_index = "order_index"
        case group_id = "group_id"
        case group_type = "group_type"
        case group_order = "group_order"
    }
    
    // Convenience initializer for backward compatibility
    init(id: String, program_day_id: String, exercise_id: String, sets: Int, reps: Int?, weight: Double?, duration: Int?, rest_time: Int?, order_index: Int) {
        self.id = id
        self.program_day_id = program_day_id
        self.exercise_id = exercise_id
        self.exercise_type = "reps"
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.distance = nil
        self.rest_time = rest_time
        self.order_index = order_index
        self.group_id = nil
        self.group_type = nil
        self.group_order = nil
    }
    
    // Full initializer
    init(id: String, program_day_id: String, exercise_id: String, exercise_type: String? = "reps", sets: Int, reps: Int?, weight: Double?, duration: Int?, distance: Double? = nil, rest_time: Int?, order_index: Int, group_id: String? = nil, group_type: String? = nil, group_order: Int? = nil) {
        self.id = id
        self.program_day_id = program_day_id
        self.exercise_id = exercise_id
        self.exercise_type = exercise_type
        self.sets = sets
        self.reps = reps
        self.weight = weight
        self.duration = duration
        self.distance = distance
        self.rest_time = rest_time
        self.order_index = order_index
        self.group_id = group_id
        self.group_type = group_type
        self.group_order = group_order
    }
}

struct UserDayProgress: Identifiable, Codable {
    let id: UUID
    let user_id: String
    let program_day_id: UUID
    let completed_at: Date
    let duration_minutes: Int?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case user_id = "user_id"
        case program_day_id = "program_day_id"
        case completed_at = "completed_at"
        case duration_minutes = "duration_minutes"
        case notes
    }
}

// Combined model for easier use in UI
struct DayExercise: Identifiable {
    let id: String
    let exercise: Exercise
    let sets: Int
    let reps: Int?
    let weight: Double?
    let duration: Int?
    let distance: Double?
    let restTime: Int?
    let orderIndex: Int
    let groupId: String?
    let groupType: ExerciseGroupType?
    let groupOrder: Int?
    
    init(programDayExercise: ProgramDayExercise, exercise: Exercise) {
        self.id = programDayExercise.id
        self.exercise = exercise
        self.sets = programDayExercise.sets
        self.reps = programDayExercise.reps
        self.weight = programDayExercise.weight
        self.duration = programDayExercise.duration
        self.distance = programDayExercise.distance
        self.restTime = programDayExercise.rest_time
        self.orderIndex = programDayExercise.order_index
        self.groupId = programDayExercise.group_id
        self.groupType = ExerciseGroupType(rawValue: programDayExercise.group_type ?? "single")
        self.groupOrder = programDayExercise.group_order
    }
}

struct Article: Identifiable, Codable {
    var id: String
    var title: String
    var content: String
    var summary: String?
    var image_url: String?
    var category: String?
    var created_at: Date?
    var author: String?
    var shop_url: String?
    var button_text: String?

    var imageURL: URL? {
        guard let urlString = image_url else { return nil }
        return URL(string: urlString)
    }
} 
