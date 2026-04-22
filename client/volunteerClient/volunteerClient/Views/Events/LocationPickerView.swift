import SwiftUI
import MapKit
import CoreLocation

struct LocationPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: LocationPickerViewModel

    let onSelect: (SelectedLocation) -> Void

    init(
        initialLocation: SelectedLocation?,
        onSelect: @escaping (SelectedLocation) -> Void
    ) {
        _viewModel = StateObject(wrappedValue: LocationPickerViewModel(initialLocation: initialLocation))
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 16) {
                    SearchBar(text: $viewModel.searchText)
                        .zIndex(2)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                VStack(spacing: 16) {
                    Color.clear
                        .frame(height: 68)

                    if !viewModel.completions.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.completions, id: \.self) { completion in
                                    Button {
                                        viewModel.chooseCompletion(completion)
                                    } label: {
                                        SearchCompletionRow(completion: completion)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .frame(maxHeight: 220)
                        .padding(.horizontal, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.gray.opacity(0.16), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .zIndex(10)
                    }

                    ZStack {
                        Map(
                            coordinateRegion: $viewModel.region,
                            interactionModes: .all,
                            showsUserLocation: false
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .frame(height: 320)

                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.pink)
                            .shadow(radius: 4)
                    }
                    .padding(.horizontal, 16)
                    .zIndex(0)

                    Button {
                        viewModel.useMapCenter()
                    } label: {
                        HStack {
                            if viewModel.isResolvingCenter {
                                ProgressView()
                            } else {
                                Image(systemName: "scope")
                            }

                            Text("Использовать центр карты")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground))
                        )
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Выбранная локация")
                            .font(.system(size: 17, weight: .semibold))

                        Text(viewModel.selectedAddress ?? "Сначала выберите адрес через поиск или используйте центр карты")
                            .foregroundStyle(viewModel.selectedAddress == nil ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                    .padding(.horizontal, 16)

                    if let errorText = viewModel.errorText {
                        Text(errorText)
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                    }

                    Spacer(minLength: 0)

                    Button {
                        guard let location = viewModel.selectedLocation else { return }
                        onSelect(location)
                        dismiss()
                    } label: {
                        HStack {
                            if viewModel.isLoadingSearchResult {
                                ProgressView()
                                    .tint(.white)
                            }

                            Text("Выбрать эту точку")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(viewModel.selectedLocation == nil ? Color.gray.opacity(0.45) : Color(red: 44/255, green: 67/255, blue: 102/255))
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.selectedLocation == nil)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .padding(.top, 68)
            }
            .background(Color(.systemGray6))
            .navigationTitle("Выбор локации")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }
}
