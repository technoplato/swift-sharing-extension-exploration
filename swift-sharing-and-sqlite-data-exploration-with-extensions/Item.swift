import Foundation
import SQLiteData

@Table
struct Item: Identifiable {
    let id: UUID
    var title: String
    var timestamp: Date
}
