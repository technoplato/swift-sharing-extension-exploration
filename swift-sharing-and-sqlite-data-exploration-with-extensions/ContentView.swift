import SwiftUI
import SQLiteData
import ReplayKit

struct ContentView: View {
    @FetchAll(Item.order(by: \.timestamp))
    var items: [Item]
    
    @Dependency(\.defaultDatabase) var database
    
    @State private var refreshID = UUID()
    
    init() {
        _ = DatabaseChangeObserver.shared
    }
    
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
            .id(refreshID)
            .navigationTitle("Items")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack {
                    Text("Start Broadcast")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    BroadcastPickerView()
                        .frame(width: 50, height: 50)
                }
                .padding()
                .background(.thinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding()
            }
            .onReceive(NotificationCenter.default.publisher(for: .databaseChanged)) { _ in
                refreshID = UUID()
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

struct BroadcastPickerView: UIViewRepresentable {
    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let picker = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        // picker.preferredExtension = "com.halfjew22.swift-sharing-and-sqlite-data-exploration-with-extensions.BroadcastExtension"
        picker.showsMicrophoneButton = false
        return picker
    }
    
    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {}
}

#Preview {
    ContentView()
}
