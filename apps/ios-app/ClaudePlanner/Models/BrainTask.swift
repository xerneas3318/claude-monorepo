import Foundation

struct BrainTask: Identifiable, Hashable {
    let id: String
    let category: String
    let text: String
    let checked: Bool
    let order: Int
    let date: String?
    let notes: String?

    var hasNotes: Bool { (notes?.isEmpty == false) }
}
