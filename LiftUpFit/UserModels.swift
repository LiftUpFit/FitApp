import Foundation

struct UserProfile: Codable {
    let id: String
    var email: String
    var fullName: String?
    var age: Int?
    var weight: Double?
    var height: Double?
    var fitnessLevel: String?
    var goals: [String]?
    var unitPreference: String?
    var createdAt: Date
    var updatedAt: Date
    var role: String?
    var monthlyGoal: Int?
    var monthlyGoalText: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case fullName = "full_name"
        case age
        case weight
        case height
        case fitnessLevel = "fitness_level"
        case goals
        case unitPreference = "unit_preference"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case role
        case monthlyGoal = "monthly_goal"
        case monthlyGoalText = "monthly_goal_text"
    }
}

struct ProgramEnrollment: Codable {
    let user_id: String
    let program_id: String
} 

 