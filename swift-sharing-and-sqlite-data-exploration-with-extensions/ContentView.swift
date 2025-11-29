import SwiftUI
import SQLiteData

struct ContentView: View {
    @FetchAll(Item.order(by: \.timestamp))
    var items: [Item]
    
    @Dependency(\.defaultDatabase) var database
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(items) { item in
                    VStack(alignment: .leading) {
                        Text(item.title)
                            .font(.headline)
                        Text(item.timestamp.formatted(date: .omitted, time: .standard))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Items")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        }
    }
    
    private func addItem() {
        let newItem = Item(id: UUID(), title: "Item \(Date().formatted())", timestamp: Date())
        try? database.write { db in
            try Item.insert { newItem }.execute(db)
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        try? database.write { db in
            for index in offsets {
                try Item.delete(items[index]).execute(db)
            }
        }
    }
}

#Preview {
    ContentView()
}
