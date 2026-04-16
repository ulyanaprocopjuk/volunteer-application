import Foundation

extension VolunteerEvent {
    static let mockData: [VolunteerEvent] = [
        VolunteerEvent(
            id: UUID(),
            title: "Volunteer for ‘Music Festival’",
            status: .open,
            priority: .high,
            description: "MelodyMakers is dedicated to uniting communities through the power of music. We showcase local artists and help create a vibrant festival experience for everyone.",
            location: "Patan Dhoka, Lalitpur",
            startDate: .make(2024, 12, 1, 10, 30),
            endDate: .make(2024, 12, 1, 14, 30),
            durationHours: 4,
            organizerName: "MelodyMakers Events",
            publishedAt: .make(2024, 11, 25),
            currentVolunteers: 3,
            neededVolunteers: 4,
            imageName: "music.mic"
        ),
        VolunteerEvent(
            id: UUID(),
            title: "Animal Shelter Support",
            status: .open,
            priority: .low,
            description: "Support the shelter with tasks such as pet care, cleaning, and walking dogs.",
            location: "New Road, Kathmandu",
            startDate: .make(2024, 12, 5, 11, 0),
            endDate: .make(2024, 12, 5, 15, 0),
            durationHours: 4,
            organizerName: "Animal Care Center",
            publishedAt: .make(2024, 11, 27),
            currentVolunteers: 5,
            neededVolunteers: 7,
            imageName: "pawprint.fill"
        ),
        VolunteerEvent(
            id: UUID(),
            title: "Food Distribution Drive",
            status: .open,
            priority: .high,
            description: "Help distribute food packages, assist with logistics, and support coordinators during the event.",
            location: "City Center",
            startDate: .make(2024, 12, 12, 9, 0),
            endDate: .make(2024, 12, 12, 14, 0),
            durationHours: 5,
            organizerName: "CareBridge",
            publishedAt: .make(2024, 11, 30),
            currentVolunteers: 8,
            neededVolunteers: 10,
            imageName: "fork.knife"
        )
    ]
}
