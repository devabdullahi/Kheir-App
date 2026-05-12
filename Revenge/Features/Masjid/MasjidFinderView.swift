import SwiftUI
import MapKit

struct MasjidFinderView: View {
    @StateObject private var viewModel = MasjidFinderViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedMasjid: MasjidItem?
    @State private var showFilterSheet = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveBackground(colorScheme).ignoresSafeArea()

                if viewModel.locationDenied {
                    locationDeniedView
                } else {
                    content
                }
            }
            .navigationTitle("Nearby Masjids")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Picker("View", selection: $viewModel.viewMode) {
                            ForEach(MasjidFinderViewModel.ViewMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }

                        Button {
                            showFilterSheet = true
                        } label: {
                            Label("Search Radius", systemImage: "slider.horizontal.3")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    }
                }
            }
            .onAppear { viewModel.onAppear() }
            .sheet(item: $selectedMasjid) { masjid in
                masjidDetailSheet(masjid)
            }
            .sheet(isPresented: $showFilterSheet) {
                filterSheet
            }
        }
    }

    // MARK: - Main Content
    private var content: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Map
                Map(initialPosition: .region(viewModel.region)) {
                    ForEach(viewModel.masjids) { masjid in
                        Annotation(masjid.name, coordinate: masjid.coordinate) {
                            Image(systemName: "building.columns.fill")
                                .foregroundStyle(Color.adaptivePrimary(colorScheme))
                                .padding(6)
                                .background(Color.adaptiveCardSurface(colorScheme))
                                .clipShape(Circle())
                                .shadow(radius: 2)
                                .onTapGesture { selectedMasjid = masjid }
                        }
                    }
                }
                .frame(height: viewModel.viewMode == .map ? geo.size.height : geo.size.height * 0.45)

                if viewModel.viewMode == .split {
                    // List
                    if viewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(viewModel.masjids) { masjid in
                                    masjidCard(masjid)
                                        .onTapGesture { selectedMasjid = masjid }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Masjid Card
    private func masjidCard(_ masjid: MasjidItem) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "building.columns.fill")
                .font(.title2)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
                .frame(width: 44, height: 44)
                .background(Color.adaptivePrimary(colorScheme).opacity(0.12))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(masjid.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                Text(masjid.address)
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    .lineLimit(1)
            }

            Spacer()

            Text(masjid.distanceString)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
        }
        .padding(12)
        .background(Color.adaptiveCardSurface(colorScheme))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    // MARK: - Detail Sheet
    private func masjidDetailSheet(_ masjid: MasjidItem) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(masjid.name)
                    .font(.title2)
                    .fontWeight(.bold)

                Label(masjid.address, systemImage: "mappin")
                    .font(.subheadline)

                Label(masjid.distanceString, systemImage: "location")
                    .font(.subheadline)

                if let phone = masjid.phoneNumber {
                    Label(phone, systemImage: "phone")
                        .font(.subheadline)
                }

                if let url = masjid.url {
                    Link(destination: url) {
                        Label("Website", systemImage: "globe")
                    }
                }

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        viewModel.openInMaps(masjid)
                    } label: {
                        Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color.adaptivePrimary(colorScheme))

                    ShareLink(item: "\(masjid.name)\n\(masjid.address)") {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            .navigationTitle("Masjid Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { selectedMasjid = nil }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Filter Sheet
    private var filterSheet: some View {
        NavigationStack {
            List {
                Section("Search Radius") {
                    ForEach(MasjidFinderViewModel.SearchRadius.allCases, id: \.self) { radius in
                        Button {
                            viewModel.searchRadius = radius
                            viewModel.refreshSearch()
                            showFilterSheet = false
                        } label: {
                            HStack {
                                Text(radius.displayName)
                                Spacer()
                                if viewModel.searchRadius == radius {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                                }
                            }
                        }
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                    }
                }
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showFilterSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Location Denied View
    private var locationDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))

            Text("Location access is needed to find nearby masjids.")
                .multilineTextAlignment(.center)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.adaptivePrimary(colorScheme))
        }
        .padding()
    }
}
