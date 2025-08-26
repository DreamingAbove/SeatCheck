import SwiftUI
import SwiftData

// MARK: - Session History View
struct SessionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var sessions: [Session]
    
    private var completedSessions: [Session] {
        sessions.filter { !$0.isActive }.sorted { $0.completedAt ?? $0.createdAt > $1.completedAt ?? $1.createdAt }
    }
    
    private var currentStreak: Int {
        calculateCurrentStreak()
    }
    
    private var longestStreak: Int {
        calculateLongestStreak()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Stats Header
                VStack(spacing: 16) {
                    HStack(spacing: 30) {
                        StatCard(
                            title: "Current Streak",
                            value: "\(currentStreak)",
                            subtitle: "days",
                            color: .orange
                        )
                        
                        StatCard(
                            title: "Longest Streak",
                            value: "\(longestStreak)",
                            subtitle: "days",
                            color: .blue
                        )
                    }
                    
                    HStack(spacing: 30) {
                        StatCard(
                            title: "Total Sessions",
                            value: "\(completedSessions.count)",
                            subtitle: "completed",
                            color: .green
                        )
                        
                        StatCard(
                            title: "Success Rate",
                            value: "\(successRate)%",
                            subtitle: "items collected",
                            color: .purple
                        )
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                
                // Session List
                if completedSessions.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Completed Sessions")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Text("Start your first session to see your history here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(completedSessions) { session in
                            SessionHistoryRow(session: session)
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Session History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var successRate: Int {
        guard !completedSessions.isEmpty else { return 0 }
        
        let totalItems = completedSessions.reduce(0) { $0 + $1.checklistItems.count }
        let collectedItems = completedSessions.reduce(0) { $0 + $1.checklistItems.filter { $0.isCollected }.count }
        
        return totalItems > 0 ? Int((Double(collectedItems) / Double(totalItems)) * 100) : 0
    }
    
    private func calculateCurrentStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var currentDate = today
        var streak = 0
        
        // Check if today has a completed session
        let todaySessions = completedSessions.filter { session in
            guard let completedAt = session.completedAt else { return false }
            return calendar.isDate(completedAt, inSameDayAs: today)
        }
        
        if todaySessions.isEmpty {
            return 0
        }
        
        // Count consecutive days with completed sessions
        while true {
            let daySessions = completedSessions.filter { session in
                guard let completedAt = session.completedAt else { return false }
                return calendar.isDate(completedAt, inSameDayAs: currentDate)
            }
            
            if daySessions.isEmpty {
                break
            }
            
            streak += 1
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
        
        return streak
    }
    
    private func calculateLongestStreak() -> Int {
        let calendar = Calendar.current
        var longestStreak = 0
        var currentStreak = 0
        var lastDate: Date?
        
        // Group sessions by day
        let sessionsByDay = Dictionary(grouping: completedSessions) { session in
            guard let completedAt = session.completedAt else { return session.createdAt }
            return calendar.startOfDay(for: completedAt)
        }
        
        let sortedDays = sessionsByDay.keys.sorted()
        
        for day in sortedDays {
            if let last = lastDate {
                let daysBetween = calendar.dateComponents([.day], from: last, to: day).day ?? 0
                
                if daysBetween == 1 {
                    // Consecutive day
                    currentStreak += 1
                } else {
                    // Gap in streak
                    longestStreak = max(longestStreak, currentStreak)
                    currentStreak = 1
                }
            } else {
                currentStreak = 1
            }
            
            lastDate = day
        }
        
        // Check final streak
        longestStreak = max(longestStreak, currentStreak)
        
        return longestStreak
    }
}

// MARK: - Stat Card
struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Session History Row
struct SessionHistoryRow: View {
    let session: Session
    
    private var completionDate: Date {
        session.completedAt ?? session.createdAt
    }
    
    private var collectedCount: Int {
        session.checklistItems.filter { $0.isCollected }.count
    }
    
    private var totalCount: Int {
        session.checklistItems.count
    }
    
    var body: some View {
        HStack {
            // Session Icon
            Image(systemName: session.preset.icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            // Session Details
            VStack(alignment: .leading, spacing: 4) {
                Text(session.preset.rawValue)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(completionDate, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(collectedCount)/\(totalCount) items collected")
                    .font(.caption)
                    .foregroundColor(collectedCount == totalCount ? .green : .orange)
            }
            
            Spacer()
            
            // End Signal Icon
            if let endSignal = session.endSignal {
                Image(systemName: endSignal.icon)
                    .font(.title3)
                    .foregroundColor(endSignal.color)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview
#Preview {
    SessionHistoryView()
        .modelContainer(for: [Session.self, ChecklistItem.self, Settings.self], inMemory: true)
}
