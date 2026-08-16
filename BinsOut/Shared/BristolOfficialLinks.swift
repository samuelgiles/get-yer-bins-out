import Foundation

enum BristolOfficialLinks {
    static let uprnFinder = makeURL("https://www.findmyaddress.co.uk/search")
    static let sortingGuide = makeURL("https://www.bristol.gov.uk/residents/bins-and-recycling/what-goes-in-your-bins-and-boxes")
    static let blackRecyclingBox = makeURL("https://www.bristol.gov.uk/residents/bins-and-recycling/what-goes-in-your-bins-and-boxes/black-recycling-box")
    static let wasteCompanySortingGuide = makeURL("https://bristolwastecompany.co.uk/household/get-it-sorted/")
    static let collectionInformation = makeURL("https://www.bristol.gov.uk/residents/bins-and-recycling/bins-and-recycling-collection-dates")
    static let serviceUpdates = makeURL("https://bristolwastecompany.co.uk/service-changes/")

    private static func makeURL(_ value: String) -> URL {
        guard let url = URL(string: value) else {
            preconditionFailure("A bundled Bristol guidance URL is invalid")
        }
        return url
    }
}
