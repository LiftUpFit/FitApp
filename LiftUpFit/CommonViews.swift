import SwiftUI
import AVKit

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .fontWeight(.bold)
                .foregroundColor(isSelected ? .black : .gray)
                .padding(.vertical, 8)
                .padding(.horizontal, 24)
                .background(isSelected ? Color(.systemGray5) : Color(.systemGray6))
                .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExerciseDemoView: View {
    let exerciseName: String
    let videoURL: URL?
    let imageURL: URL?
    let instructions: String
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Video or Image Demo
            if let videoURL = videoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .frame(height: 280)
                    .clipped()
            } else if let imageURL = imageURL {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .failure:
                        Color.gray
                    @unknown default:
                        Color.gray
                    }
                }
                .frame(height: 280)
                .clipped()
            } else {
                Color.gray.frame(height: 280)
            }

            // Exercise Name
            Text(exerciseName)
                .font(.title)
                .fontWeight(.bold)
                .padding(.top, 24)

            // Instructions
            VStack(alignment: .leading, spacing: 12) {
                Text("Instructions:")
                    .font(.headline)
                    .padding(.bottom, 4)

                ForEach(instructions.split(separator: "\n").map(String.init), id: \.self) { line in
                    HStack(alignment: .top) {
                        Text("•")
                        Text(line)
                    }
                }
            }
            .padding(.top, 16)
            .padding(.horizontal)

            Spacer()

            // Next Button
            Button(action: onNext) {
                Text("Next")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(hex: "#404C61"))
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
    }
}

struct FuelCategory: Identifiable, Hashable {
    let id: String
    let label: String
    let examples: [String]
}

let fuelCategories: [FuelCategory] = [
    .init(id: "Train", label: "Train", examples: ["Exercise breakdowns", "Workout structure tips", "Warm-up/mobility", "Training philosophy"]),
    .init(id: "Recover", label: "Recover", examples: ["Post-workout recovery", "Stretching/foam rolling", "Sleep quality", "Cold therapy"]),
    .init(id: "Mindset", label: "Mindset", examples: ["Motivation", "Goal-setting", "Routine ideas", "Plateau breaking"]),
    .init(id: "Eats", label: "Eats", examples: ["Recipes", "Meal timing", "Grocery lists", "Macro hacks"]),
    .init(id: "Boost", label: "Boost", examples: ["Supplements", "Gear reviews", "Pre-workout", "Energy optimization"]),
    .init(id: "Bold", label: "Bold", examples: ["Testimonials", "Member highlights", "Transformations", "Challenges", "Bold tips"])
]

struct FuelView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var articles: [Article] = []
    @State private var isLoading = true
    @State private var selectedArticle: Article? = nil
    @State private var selectedCategory: String? = nil

    var filteredArticles: [Article] {
        if let cat = selectedCategory {
            return articles.filter { $0.category?.caseInsensitiveCompare(cat) == .orderedSame }
        } else {
            return articles
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Category Selector
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        Button(action: { selectedCategory = nil }) {
                            Text("All")
                                .fontWeight(selectedCategory == nil ? .bold : .regular)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 18)
                                .background(selectedCategory == nil ? Color(hex: "#404C61") : Color(.systemGray5))
                                .foregroundColor(selectedCategory == nil ? .white : .primary)
                                .cornerRadius(16)
                        }
                        ForEach(fuelCategories) { cat in
                            Button(action: { selectedCategory = cat.id }) {
                                Text(cat.label)
                                    .fontWeight(selectedCategory == cat.id ? .bold : .regular)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 18)
                                    .background(selectedCategory == cat.id ? Color(hex: "#404C61") : Color(.systemGray5))
                                    .foregroundColor(selectedCategory == cat.id ? .white : .primary)
                                    .cornerRadius(16)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
                // Article Cards
                ScrollView {
                    LazyVStack(spacing: 20) {
                        ForEach(filteredArticles) { article in
                            Button(action: { selectedArticle = article }) {
                                VStack(alignment: .leading, spacing: 0) {
                                    // Article Image
                                    if let url = article.imageURL {
                                        AsyncImage(url: url) { phase in
                                            switch phase {
                                            case .empty: ProgressView()
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 220)
                                                    .clipped()
                                            case .failure: Color.gray.frame(height: 180)
                                            @unknown default: Color.gray.frame(height: 180)
                                            }
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                        .padding(.bottom, 0)
                                    }
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(article.title)
                                            .font(.system(size: 22, weight: .black, design: .default))
                                            .padding(.top, 12)
                                        if let summary = article.summary {
                                            Text(summary)
                                                .font(.body)
                                                .foregroundColor(.secondary)
                                                .padding(.bottom, 12)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: Color(.black).opacity(0.08), radius: 6, x: 0, y: 2)
                                .padding(.horizontal)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.vertical)
                }
                .navigationTitle("Fuel")
                .sheet(item: $selectedArticle) { article in
                    ArticleDetailView(article: article)
                }
                .task {
                    do {
                        articles = try await supabaseManager.getAllArticles()
                        isLoading = false
                    } catch {
                        // handle error
                        isLoading = false
                    }
                }
            }
        }
    }
}

struct ArticleDetailView: View {
    let article: Article
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let url = article.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty: ProgressView()
                        case .success(let image): image.resizable().aspectRatio(contentMode: .fit)
                        case .failure: Color.gray.frame(height: 200)
                        @unknown default: Color.gray.frame(height: 200)
                        }
                    }
                }
                Text(article.title)
                    .font(.title)
                    .fontWeight(.bold)
                if let author = article.author {
                    Text("By \(author)").font(.caption).foregroundColor(.secondary)
                }
                if let category = article.category {
                    Text(category).font(.caption2).foregroundColor(.blue)
                }
                if let date = article.created_at {
                    Text(date, style: .date).font(.caption2).foregroundColor(.secondary)
                }
                Divider()
                Text(article.content)
                    .font(.body)
                if let urlString = article.shop_url, 
                   let url = URL(string: urlString), 
                   !urlString.isEmpty,
                   let buttonText = article.button_text,
                   !buttonText.isEmpty {
                    Button(action: {
                        UIApplication.shared.open(url)
                    }) {
                        Text(buttonText)
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "#404C61"))
                            .cornerRadius(12)
                    }
                    .padding(.top, 24)
                }
            }
            .padding()
        }
    }
}

struct ArticleAdminView: View {
    @EnvironmentObject var supabaseManager: SupabaseManager
    @State private var articles: [Article] = []
    @State private var isLoading = true
    @State private var showingAddEdit = false
    @State private var editingArticle: Article? = nil

    var body: some View {
        NavigationView {
            VStack {
                if articles.isEmpty && !isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No articles yet")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text("Tap + to add your first article.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(articles) { article in
                            Button(action: {
                                editingArticle = article
                                showingAddEdit = true
                            }) {
                                VStack(alignment: .leading) {
                                    Text(article.title).font(.headline)
                                    if let summary = article.summary {
                                        Text(summary).font(.caption).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: deleteArticle)
                    }
                    .listStyle(.plain)
                    .refreshable {
                        await loadArticles()
                    }
                }
            }
            .navigationTitle("Manage Articles")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(action: { Task { await loadArticles() } }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        Button(action: {
                            editingArticle = nil
                            showingAddEdit = true
                        }) {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddEdit, onDismiss: { Task { await loadArticles() } }) {
                AddEditArticleView(article: editingArticle) { _ in
                    Task { await loadArticles() }
                }
                .environmentObject(supabaseManager)
            }
            .task {
                await loadArticles()
            }
        }
    }

    private func loadArticles() async {
        isLoading = true
        do {
            articles = try await supabaseManager.getAllArticles()
            isLoading = false
        } catch {
            isLoading = false
        }
    }

    private func deleteArticle(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        let article = articles[index]
        Task {
            do {
                try await supabaseManager.deleteArticle(id: article.id)
                await loadArticles()
            } catch {
                // handle error
            }
        }
    }
}

struct AddEditArticleView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var supabaseManager: SupabaseManager

    @State private var title: String
    @State private var content: String
    @State private var summary: String
    @State private var imageURL: String
    @State private var category: String
    @State private var author: String
    @State private var shopURL: String
    @State private var buttonText: String
    @State private var isSaving = false
    @State private var error: String?

    let article: Article?
    let onSave: (Article) -> Void

    init(article: Article?, onSave: @escaping (Article) -> Void) {
        self.article = article
        self.onSave = onSave
        _title = State(initialValue: article?.title ?? "")
        _content = State(initialValue: article?.content ?? "")
        _summary = State(initialValue: article?.summary ?? "")
        _imageURL = State(initialValue: article?.image_url ?? "")
        _category = State(initialValue: article?.category ?? "")
        _author = State(initialValue: article?.author ?? "")
        _shopURL = State(initialValue: article?.shop_url ?? "")
        _buttonText = State(initialValue: article?.button_text ?? "")
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Article Details") {
                    TextField("Title", text: $title)
                    TextField("Summary", text: $summary)
                    TextField("Category", text: $category)
                    TextField("Author", text: $author)
                }
                Section("Image") {
                    TextField("Image URL", text: $imageURL)
                }
                Section("Call-to-Action Button") {
                    TextField("Button Text", text: $buttonText)
                        .placeholder(when: buttonText.isEmpty) {
                            Text("e.g., 'Shop Now', 'Read More', 'Get Ebook'")
                                .foregroundColor(.secondary)
                        }
                    TextField("Button URL", text: $shopURL)
                        .placeholder(when: shopURL.isEmpty) {
                            Text("https://your-store.com or https://your-blog.com")
                                .foregroundColor(.secondary)
                        }
                    if !shopURL.isEmpty && !buttonText.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Button will show: \"\(buttonText)\"")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Helpful examples
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Examples:")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text("• 'Shop Now' → Link to your store")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("• 'Read More' → Link to full blog post")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("• 'Get Ebook' → Link to download page")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text("• 'Join Challenge' → Link to signup")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
                Section("Content") {
                    TextEditor(text: $content)
                        .frame(height: 200)
                }
            }
            .navigationTitle(article == nil ? "Add Article" : "Edit Article")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") { saveArticle() }
                        .disabled(title.isEmpty || content.isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: .constant(error != nil)) {
                Button("OK") { error = nil }
            } message: {
                if let error = error { Text(error) }
            }
        }
    }

    private func saveArticle() {
        isSaving = true
        error = nil
        Task {
            do {
                let newArticle = Article(
                    id: article?.id ?? UUID().uuidString,
                    title: title,
                    content: content,
                    summary: summary.isEmpty ? nil : summary,
                    image_url: imageURL.isEmpty ? nil : imageURL,
                    category: category.isEmpty ? nil : category,
                    created_at: article?.created_at ?? Date(),
                    author: author.isEmpty ? nil : author,
                    shop_url: shopURL.isEmpty ? nil : shopURL,
                    button_text: buttonText.isEmpty ? nil : buttonText
                )
                if article == nil {
                    try await supabaseManager.createArticle(article: newArticle)
                } else {
                    try await supabaseManager.updateArticle(article: newArticle)
                }
                await MainActor.run {
                    onSave(newArticle)
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
