import XCTest
@testable import BinsOut

final class CollectionActivityTitleTests: XCTestCase {
    func testGeneralWasteAndRecyclingUsesCombinedTitle() {
        let containers = [
            container("180L General Waste"),
            container("45L Black Recycling Box"),
            container("23L Food Waste Bin"),
        ]

        XCTAssertEqual(CollectionActivityTitle.title(for: containers), "Bins + Recycling")
    }

    func testRecyclingOnlyUsesRecyclingTitle() {
        let containers = [
            container("45L Black Recycling Box"),
            container("90L Blue Bag"),
        ]

        XCTAssertEqual(CollectionActivityTitle.title(for: containers), "Recycling")
    }

    func testWheelieBinAndRecyclingUsesCombinedTitle() {
        let containers = [
            container("Black wheelie bin"),
            container("Green recycling box"),
        ]

        XCTAssertEqual(CollectionActivityTitle.title(for: containers), "Bins + Recycling")
    }

    func testUnknownSingleContainerPreservesItsName() {
        let containers = [container("Purple trial container")]

        XCTAssertEqual(CollectionActivityTitle.title(for: containers), "Purple trial container")
    }

    func testCombinedGeneralAndRecyclingUsesBinSymbol() {
        let display = CollectionActivityDisplay.make(for: [
            container("180L General Waste"),
            container("45L Black Recycling Box"),
        ])

        XCTAssertEqual(display.title, "Bins + Recycling")
        XCTAssertEqual(display.symbolName, "trash.fill")
    }

    func testRecyclingUsesRecyclingSymbol() {
        let display = CollectionActivityDisplay.make(for: [
            container("90L Blue Bag"),
            container("55L Green Recycling Box"),
        ])

        XCTAssertEqual(display.title, "Recycling")
        XCTAssertEqual(display.symbolName, "arrow.3.trianglepath")
    }

    func testGardenWasteUsesGardenSymbol() {
        let display = CollectionActivityDisplay.make(for: [container("Garden waste bin")])

        XCTAssertEqual(display.title, "Garden waste")
        XCTAssertEqual(display.symbolName, "leaf.fill")
    }

    func testDynamicIslandDateDropsYearForNarrowTrailingRegion() {
        XCTAssertEqual(
            CollectionActivityDisplay.dynamicIslandDate(for: "21 Aug 2026"),
            "21 Aug"
        )
    }

    func testDynamicIslandDatePreservesUnexpectedInput() {
        XCTAssertEqual(
            CollectionActivityDisplay.dynamicIslandDate(for: "Collection day"),
            "Collection day"
        )
    }

    private func container(_ name: String) -> CollectionActivityAttributes.Container {
        CollectionActivityAttributes.Container(id: name, name: name, symbolName: "shippingbox")
    }
}
