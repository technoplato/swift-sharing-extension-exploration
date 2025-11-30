import SwiftUI
// import SQLiteData
import ReplayKit
import SharingFirestore
import FirebaseFirestore
import Sharing

struct ContentView: View {
    @SharedReader(
        .query(
            configuration: .init(
                path: "items",
                predicates: [.order(by: "timestamp", descending: true)],
                animation: .default
            )
        )
    )
    var items: IdentifiedArrayOf<Item>
    
    @Dependency(\.defaultFirestore) var database
    
    // let databaseChangePublisher = NotificationCenter.default.publisher(for: Notification.Name("DatabaseChanged"))
    
    // @State private var refreshID = UUID()
    @State private var showAlert = false

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
                // .id(refreshID) // Force rebuild
            }
            .navigationTitle("Items")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: deleteAllItems) {
                        Label("Clear Logs", systemImage: "trash")
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
        }
        // .onReceive(NotificationCenter.default.publisher(for: Notification.Name("com.halfjew22.swift-sharing-exploration.database_changed"))) { _ in
        //     print("ContentView received database change notification - Forcing Refresh")
        //     refreshID = UUID()
        //     showAlert = true
        // }
        // .alert("Database Changed", isPresented: $showAlert) {
        //     Button("OK", role: .cancel) { }
        // } message: {
        //     Text("Received notification from extension.")
        // }
        .onChange(of: items) { newItems in
            print("Items updated: \(newItems.map { $0.title })")
        }
    }
    
    private func addItem() {
        let newItem = Item(id: UUID(), title: "Item \(Date().formatted())", timestamp: Date())
        try? database.collection("items").addDocument(from: newItem)
    }
    
    private func deleteItems(offsets: IndexSet) {
        for index in offsets {
            let item = items[index]
            // Assuming ID is the document ID or we query by ID.
            // Firestore documents usually have an ID. If we saved with `addDocument(from:)`, the ID is auto-generated.
            // But our Item has an `id` property.
            // SharingFirestore's `addDocument(from:)` uses the `id` property if it's `Identifiable` and `id` is String? No, `addDocument` auto-generates ID.
            // If we want to use `item.id` as document ID, we should use `setData`.
            // However, `SharingFirestore` query returns documents.
            // Let's assume for now we just want to delete.
            // If we used `addDocument(from:)`, the document ID is not necessarily `item.id`.
            // But `SharingFirestore` might map it?
            // Actually, `IdentifiedArrayOf<Item>` uses `Item.id`.
            // If we want to delete, we need the document ID.
            // `SharingFirestore` decodes the document. If `Item` is `Codable`, it decodes fields.
            // `DocumentID` property wrapper is useful here.
            
            // For simplicity, let's query and delete, or assume we can't delete easily without DocumentID.
            // But wait, `SharingFirestore` documentation might say how to handle IDs.
            // Usually you add `@DocumentID var id: String?` to your model.
            // Our `Item` has `let id: UUID`.
            // If we want to delete, we should probably use a query to find the doc with this UUID, or change Item to use String ID and `@DocumentID`.
            
            // Let's try to delete by query for now (inefficient but works without changing model too much).
            
            database.collection("items").whereField("id", isEqualTo: item.id.uuidString).getDocuments { snapshot, error in
                snapshot?.documents.forEach { doc in
                    doc.reference.delete()
                }
            }
        }
    }
    
    private func deleteAllItems() {
        // Deleting all documents in a collection is not a simple operation in Firestore (requires batching).
        // For a demo, we can fetch and delete.
        database.collection("items").getDocuments { snapshot, error in
            snapshot?.documents.forEach { doc in
                doc.reference.delete()
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
