import SwiftUI

struct AddItemView: View {
    @EnvironmentObject private var itemStore: ItemStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var purchases = PurchaseService.shared

    @State private var name = ""
    @State private var retailer = ""
    @State private var priceText = ""
    @State private var purchaseDate = Date()
    @State private var category: ItemCategory?

    @State private var trackReturnWindow = true
    @State private var returnWindowDays = 30

    @State private var trackWarranty = false
    @State private var warrantyDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

    @State private var isPresentingCamera = false
    @State private var capturedImage: UIImage?

    /// Presented instead of saving once the free tier's lifetime item cap
    /// is hit - see `PurchaseService.freeItemLimit`.
    @State private var isPresentingPaywall = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Item name", text: $name)
                    TextField("Retailer", text: $retailer)
                    TextField("Price (optional)", text: $priceText)
                        .keyboardType(.decimalPad)
                    DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date)
                    Picker("Category", selection: $category) {
                        Text("Uncategorized").tag(ItemCategory?.none)
                        ForEach(ItemCategory.allCases) { option in
                            Label(option.label, systemImage: option.systemImage).tag(ItemCategory?.some(option))
                        }
                    }
                } header: {
                    Theme.sectionHeader("What did you buy")
                }
                .listRowBackground(Theme.panel)

                Section {
                    if let capturedImage {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                    }
                    Button(capturedImage == nil ? "Take a photo" : "Retake photo") {
                        isPresentingCamera = true
                    }
                    .foregroundStyle(Theme.accent)
                    .fontWeight(.semibold)
                } header: {
                    Theme.sectionHeader("Receipt")
                }
                .listRowBackground(Theme.panel)

                Section {
                    Toggle("Track a return deadline", isOn: $trackReturnWindow)
                    if trackReturnWindow {
                        Stepper("Return within \(returnWindowDays) days", value: $returnWindowDays, in: 1...365)
                    }
                } header: {
                    Theme.sectionHeader("Return window")
                }
                .listRowBackground(Theme.panel)

                Section {
                    Toggle("Track a warranty", isOn: $trackWarranty)
                    if trackWarranty {
                        DatePicker("Warranty expires", selection: $warrantyDate, displayedComponents: .date)
                    }
                } header: {
                    Theme.sectionHeader("Warranty")
                }
                .listRowBackground(Theme.panel)
            }
            .themedScrollBackground()
            .monospacedDigit()
            .navigationTitle("Add purchase")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .fullScreenCover(isPresented: $isPresentingCamera) {
                CameraCapture { image in
                    capturedImage = image
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $isPresentingPaywall) {
                PaywallSheet()
            }
        }
    }

    private func save() {
        // Lifetime cap on free manual tracking - counts every item ever
        // created, not just currently-unresolved ones, so resolving an
        // item never reopens a free "slot." Once Pro is unlocked this
        // never triggers again. Show the paywall instead of saving; the
        // form's state is preserved, so tapping Save again after
        // unlocking goes straight through.
        if itemStore.items.count >= PurchaseService.freeItemLimit && !purchases.hasUnlockedPro {
            isPresentingPaywall = true
            return
        }

        var deadlines: [TrackedDeadline] = []

        if trackReturnWindow, let returnDate = Calendar.current.date(byAdding: .day, value: returnWindowDays, to: purchaseDate) {
            deadlines.append(TrackedDeadline(kind: .returnWindow, date: returnDate))
        }
        if trackWarranty {
            deadlines.append(TrackedDeadline(kind: .warranty, date: warrantyDate))
        }

        let priceCents = Int((Double(priceText) ?? 0) * 100)
        let receiptFilename = capturedImage.flatMap { PhotoStorage.save($0) }

        let item = TrackedItem(
            name: name.trimmingCharacters(in: .whitespaces),
            retailer: retailer.trimmingCharacters(in: .whitespaces),
            purchaseDate: purchaseDate,
            priceCents: priceCents > 0 ? priceCents : nil,
            deadlines: deadlines,
            receiptPhotoFilename: receiptFilename,
            category: category
        )

        itemStore.add(item)

        Task {
            let granted = await NotificationService.shared.requestAuthorizationIfNeeded()
            if granted {
                for deadline in item.deadlines {
                    NotificationService.shared.scheduleReminder(for: item, deadline: deadline)
                }
            }
        }

        dismiss()
    }
}

#Preview {
    AddItemView()
        .environmentObject(ItemStore())
}
