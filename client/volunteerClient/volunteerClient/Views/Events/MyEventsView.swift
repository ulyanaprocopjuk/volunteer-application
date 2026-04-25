import SwiftUI

struct MyEventsView: View {
    @ObservedObject var viewModel: MyEventsViewModel
    let onCreateEvent: () -> Void

    @State private var selectedEvent: EventResponse?

    var body: some View {
        VStack(spacing: 0) {
            headerView
                .padding(.horizontal, 24)
                .padding(.top, 18)

            if viewModel.isLoading && viewModel.events.isEmpty {
                Spacer()
                ProgressView()
                Spacer()
            } else if viewModel.isEmpty {
                emptyState
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 24) {
                        ForEach(viewModel.events) { event in
                            Button {
                                selectedEvent = event
                            } label: {
                                EventSummaryCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 140)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemGray6))
        .task {
            await viewModel.loadMyEvents()
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { _ in viewModel.errorMessage = nil }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .fullScreenCover(item: $selectedEvent) { event in
            EventDetailsView(event: event)
        }
    }

    private var headerView: some View {
        HStack {
            Text("Мои события")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(.black.opacity(0.85))

            Spacer()

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
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Text("У вас пока нет событий")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.55))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    let vm = MyEventsViewModel(session: AppSession())
    return MyEventsView(viewModel: vm, onCreateEvent: {})
}
