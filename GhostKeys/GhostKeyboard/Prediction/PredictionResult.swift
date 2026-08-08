import Foundation

struct PredictionResult {
    let word: String
    let score: Double
    let isAutocorrect: Bool

    init(word: String, score: Double, isAutocorrect: Bool = false) {
        self.word = word
        self.score = score
        self.isAutocorrect = isAutocorrect
    }
}
