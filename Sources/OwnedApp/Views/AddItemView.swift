import SwiftUI

struct AddItemView: View {
      @EnvironmentObject private var itemStore: ItemStore
      @Environment(\.dismiss) private var dismiss

      @State private var name = ""
      @State private var retailer = ""
      @State private var priceText = ""
      @State private var purchaseDate = Date()

      @State private var trackReturnWindow = true
      @State private var returnWindowDays = 30

      @State private var trackWarranty = false
      @State private var warrantyDate = Calendar.current.date(byAdding: .year, value: 1, to: Date()) ?? Date()

      @State private var isPresentingCamera = false
      @State private var capturedImage: UIImage?

      var body: some View {
                NavigationStack {
                              Form {
                                                Section("What did you buy") {
                                                                      TextField("Item name", text: $name)
                                                                      TextField("Retailer", text: $retailer)
                                                                      TextField("Price (optional)", text: $priceText)
                                                                          .keyboardType(.decimalPad)
                                                                      DatePicker("Purchase date", selection: $purchaseDate, displayedComponents: .date)
                                                }

                                                Section("Receipt") {
                                                                      if let capturedImage {
                                                                                                Image(uiImage: capturedImage)
                                                                                                    .resizable()
                                                                                                    .scaledToFit()
                                                                                                    .frame(maxHeight: 200)
                                                                      }
                                                                      Button(capturedImage == nil ? "Take a photo" : "Retake photo") {
                                                                                                isPresentingCamera = true
                                                                      }
                                                }

                                                Section("Return window") {
                                                                      Toggle("Track a return deadline", isOn: $trackReturnWindow)
                                                                      if trackReturnWindow {
                                                                                                Stepper("Return within \(returnWindowDays) days", value: $returnWindowDays, in: 1...365)
                                                                      }
                                                }

                                                Section("Warranty") {
                                                                      Toggle("Track a warranty", isOn: $trackWarranty)
                                                                      if trackWarranty {
                                                                                                DatePicker("Warranty expires", selection: $warrantyDate, displayedComponents: .date)
                                                                      }
                                                }
                              }
                              .navigationTitle("Add purchase")
                              .toolbar {
                                                ToolbarItem(placement: .cancellationAction) {
                                                                      Button("Cancel") { dismiss() }
                                                }
                                                ToolbarItem(placement: .confirmationAction) {
                                                                      Button("Save") { save() }
                                                                          .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                                                }
                              }
                              .fullScreenCover(isPresented: $isPresentingCamera) {
                                                CameraCapture { image in
                                                                                   capturedImage = image
                                                              }
                                                .ignoresSafeArea()
                              }
                }
      }

      private func save() {
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
                              receiptPhotoFilename: receiptFilename
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
