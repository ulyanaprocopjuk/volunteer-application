import SwiftUI

struct RatingBadgeView: View {
    let rating: Int
    var size: CGFloat = 60

    private var tier: RatingTier { RatingTier(rating: rating) }

    var body: some View {
        Image(tier.imageName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

struct RatingTier {
    let imageName: String
    let title: String
    let color: Color

    init(rating: Int) {
        switch rating {
        case 0...99:
            imageName = "rating1"
            title = "Клеймо предателя"
            color = Color(red: 0.55, green: 0.55, blue: 0.55)
        case 100...199:
            imageName = "rating2"
            title = "Сектор недоверия"
            color = Color(red: 0.65, green: 0.45, blue: 0.25)
        case 200...399:
            imageName = "rating3"
            title = "Знак участника"
            color = Color(red: 0.3, green: 0.6, blue: 0.9)
        case 400...699:
            imageName = "rating4"
            title = "Знак помощника"
            color = Color(red: 0.2, green: 0.72, blue: 0.4)
        case 700...999:
            imageName = "rating5"
            title = "Знак вклада"
            color = Color(red: 0.1, green: 0.6, blue: 0.55)
        case 1000...1399:
            imageName = "rating6"
            title = "Медаль доверия"
            color = Color(red: 0.2, green: 0.45, blue: 0.85)
        case 1400...1899:
            imageName = "rating7"
            title = "Медаль заслуг"
            color = Color(red: 0.5, green: 0.2, blue: 0.85)
        case 1900...2499:
            imageName = "rating8"
            title = "Медаль опоры"
            color = Color(red: 0.75, green: 0.2, blue: 0.6)
        case 2500...3199:
            imageName = "rating9"
            title = "Орден преданности"
            color = Color(red: 0.85, green: 0.4, blue: 0.1)
        case 3200...3999:
            imageName = "rating10"
            title = "Орден лидерства"
            color = Color(red: 0.8, green: 0.6, blue: 0.0)
        case 4000...4999:
            imageName = "rating11"
            title = "Орден сообщества"
            color = Color(red: 0.85, green: 0.3, blue: 0.2)
        default:
            imageName = "rating12"
            title = "Символ движения"
            color = Color(red: 44/255, green: 67/255, blue: 102/255)
        }
    }
}
