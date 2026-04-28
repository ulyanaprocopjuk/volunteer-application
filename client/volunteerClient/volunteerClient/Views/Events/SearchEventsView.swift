import SwiftUI
import Combine

struct SearchEventsView: View {
    private let session: AppSession?
    @StateObject private var viewModel: SearchEventsViewModel
    @State private var searchText = ""
    @State private var selectedEvent: EventResponse?

    init(session: AppSession? = nil, api: EventAPIProtocol? = nil) {
        self.session = session
        _viewModel = StateObject(wrappedValue: SearchEventsViewModel(api: api))
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView

            searchBar
                .padding(.horizontal, 20)
                .padding(.top, 14)

            contentView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.white.ignoresSafeArea())
        .task(id: searchText) {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !query.isEmpty {
                try? await Task.sleep(nanoseconds: 350_000_000)
            }
            guard !Task.isCancelled else { return }
            await viewModel.loadEvents(searchText: query)
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
            EventDetailsView(event: event, session: session)
        }
    }

    private var headerView: some View {
        ZStack {
            Color(.systemGray6)
                .ignoresSafeArea(edges: .top)

            Text("События")
                .font(.system(size: 20, weight: .semibold, design: .serif))
                .foregroundColor(.black.opacity(0.78))
        }
        .frame(height: 60)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(red: 58/255, green: 145/255, blue: 233/255))

            TextField("Поиск событий", text: $searchText)
                .font(.system(size: 15, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.78))
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.gray.opacity(0.75))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.systemGray6))
        )
    }

    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading && viewModel.events.isEmpty {
            Spacer()
            ProgressView()
            Spacer()
        } else if viewModel.events.isEmpty {
            emptyState
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.events) { event in
                        Button {
                            selectedEvent = event
                        } label: {
                            MyEventCard(event: event)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 140)
            }
            .refreshable {
                await viewModel.loadEvents(searchText: searchText)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Text(searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                 ? "Событий пока нет"
                 : "Ничего не найдено")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundColor(.black.opacity(0.55))

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
final class SearchEventsViewModel: ObservableObject {
    @Published private(set) var events: [EventResponse] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let api: EventAPIProtocol
    private var currentLoadID: UUID?

    init(api: EventAPIProtocol? = nil) {
        self.api = api ?? EventAPI(baseURL: URL(string: AppConfig.baseURLString)!)
    }

    func loadEvents(searchText: String? = nil) async {
        let loadID = UUID()
        currentLoadID = loadID

        isLoading = true
        errorMessage = nil
        defer {
            if currentLoadID == loadID {
                isLoading = false
            }
        }

        do {
            let loadedEvents = try await api.fetchEventFeed(searchText: searchText, token: nil)
            guard currentLoadID == loadID else { return }
            events = loadedEvents
        } catch {
            guard currentLoadID == loadID else { return }
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SearchEventsView()
}
