import SwiftUI

struct SortGuideView: View {
    private let items = SortingGuideItem.bristolOverview

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label {
                        Text("A quick orientation only. Bristol’s official guide is the current source of truth.")
                    } icon: {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.tint)
                    }
                }

                Section("Bristol containers") {
                    ForEach(items) { item in
                        HStack(alignment: .top) {
                            Image(systemName: item.symbolName)
                                .foregroundStyle(item.tint)
                                .font(.title2)
                                .frame(minWidth: 36)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                Text(item.summary)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical)
                        .accessibilityElement(children: .combine)
                    }
                }

                Section("Official guidance") {
                    Link(
                        "What goes in your bins and boxes",
                        destination: BristolOfficialLinks.sortingGuide
                    )
                    Link(
                        "Bristol Waste: Get it sorted",
                        destination: BristolOfficialLinks.wasteCompanySortingGuide
                    )
                }
            }
            .navigationTitle("Sort")
        }
    }
}

private struct SortingGuideItem: Identifiable {
    let id: String
    let name: String
    let summary: String
    let symbolName: String
    let tint: Color

    static let bristolOverview = [
        SortingGuideItem(id: "black-box", name: "Black recycling box", summary: "Glass and separately prepared special recycling.", symbolName: "shippingbox.fill", tint: .gray),
        SortingGuideItem(id: "green-box", name: "Green recycling box", summary: "Plastic packaging, cans and foil.", symbolName: "arrow.3.trianglepath", tint: .green),
        SortingGuideItem(id: "blue-bag", name: "Blue recycling bag", summary: "Cardboard, paper and clean cartons.", symbolName: "bag.fill", tint: .blue),
        SortingGuideItem(id: "food", name: "Brown food bin", summary: "Cooked and uncooked food waste.", symbolName: "fork.knife", tint: .brown),
        SortingGuideItem(id: "general", name: "Black wheelie bin", summary: "Household waste that cannot be recycled.", symbolName: "trash.fill", tint: .gray),
        SortingGuideItem(id: "garden", name: "Green garden bin", summary: "Garden waste for subscribed, eligible properties.", symbolName: "leaf.fill", tint: .mint),
        SortingGuideItem(id: "communal", name: "Communal containers", summary: "Property-specific containers for flats and shared sites.", symbolName: "building.2.fill", tint: .purple),
    ]
}
