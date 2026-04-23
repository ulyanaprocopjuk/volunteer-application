import SwiftUI

struct MyEventsView: View {
    let onCreateEvent: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onCreateEvent) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 42, height: 42)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white)
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGray6))
    }
}

#Preview {
    MyEventsView(onCreateEvent: {})
}
