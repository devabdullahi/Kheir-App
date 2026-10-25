import SwiftUI
import MapKit

/// Nearby masjids on a hand-made paper map, with a list of cards below.
///
/// The map shows real streets with a paper treatment and a masjid cut-out standing
/// on each masjid's actual location. Tapping a card in the list opens directions in
/// Apple Maps or Google Maps.
struct MasjidFinderView: View {
    /// `true` when pushed onto an existing navigation stack (from Qibla);
    /// `false` when presented as a sheet, so it brings its own stack and Done button.
    var isPushed = false

    @State private var viewModel = MasjidFinderViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var directionsTarget: MasjidItem?
    /// The maps app chosen the first time; long-press a card for the other one.
    @AppStorage("preferredMapsApp") private var preferredMaps = ""
    @State private var showFilterSheet = false

    var body: some View {
        if isPushed {
            screen
        } else {
            NavigationStack {
                screen
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("Done") { dismiss() }
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.adaptivePrimary(colorScheme))
                        }
                    }
            }
        }
    }

    private var screen: some View {
        Group {
            if viewModel.locationDenied {
                locationDeniedView
            } else {
                content
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .navigationTitle("Nearby Masjids")
        .toolbarTitleDisplayMode(.inline)
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
                    PaperIconView(.gear, size: 22)
                }
                .accessibilityLabel("Map options")
            }
        }
        .onAppear { viewModel.onAppear() }
        .confirmationDialog(
            directionsTarget.map { "Directions to \($0.name)" } ?? "Directions",
            isPresented: Binding(
                get: { directionsTarget != nil },
                set: { if !$0 { directionsTarget = nil } }
            ),
            titleVisibility: .visible,
            presenting: directionsTarget
        ) { masjid in
            Button("Apple Maps") { preferredMaps = "apple"; viewModel.openInMaps(masjid) }
            Button("Google Maps") { preferredMaps = "google"; viewModel.openInGoogleMaps(masjid) }
            ShareLink(item: "\(masjid.name)\n\(masjid.address)") {
                Text("Share")
            }
            Button("Cancel", role: .cancel) {}
        } message: { masjid in
            Text((masjid.address.isEmpty ? masjid.distanceString : "\(masjid.address) · \(masjid.distanceString)") + "\nYour choice is remembered; long-press a masjid for the other app.")
        }
        .sheet(isPresented: $showFilterSheet) {
            filterSheet
        }
    }

    // MARK: - Main Content

    private var content: some View {
        ScrollView {
            VStack(spacing: 14) {
                PaperMasjidMap(
                    center: viewModel.region.center,
                    masjids: Array(viewModel.masjids.prefix(7)),
                    isLoading: viewModel.isLoading
                )
                .frame(height: viewModel.viewMode == .map ? 440 : 240)
                .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1.2, radius: 18, seed: 121, padding: 6)
                .animation(.open(0.3), value: viewModel.viewMode)
                .quickPlace(0)

                if viewModel.viewMode == .split {
                    if viewModel.isLoading && viewModel.masjids.isEmpty {
                        ProgressView()
                            .tint(Color.adaptivePrimary(colorScheme))
                            .padding(.top, 24)
                    } else if viewModel.masjids.isEmpty {
                        emptyCard
                            .quickPlace(1)
                    } else {
                        LazyVStack(spacing: 10) {
                            ForEach(Array(viewModel.masjids.enumerated()), id: \.element.id) { index, masjid in
                                Button {
                                    // After the first choice, open that app straight away.
                                    switch preferredMaps {
                                    case "apple": viewModel.openInMaps(masjid)
                                    case "google": viewModel.openInGoogleMaps(masjid)
                                    default: directionsTarget = masjid
                                    }
                                } label: {
                                    masjidCard(masjid, index: index)
                                }
                                .buttonStyle(PaperPressStyle())
                                .contextMenu { contextActions(masjid) }
                                .quickPlace(min(index + 1, 9))
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Masjid Card

    private func masjidCard(_ masjid: MasjidItem, index: Int) -> some View {
        HStack(spacing: 12) {
            PaperIconView(.masjid, size: 30)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(masjid.name)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .lineLimit(1)
                    if index == 0 {
                        PaperTag(text: "Nearest", color: .paperTerracotta, ink: .lightCardSurface, seed: 131)
                            .scaleEffect(0.85)
                    }
                }
                Text(masjid.address.isEmpty ? masjid.distanceString : "\(masjid.distanceString) · \(masjid.address)")
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Image(systemName: "arrow.up.right")
                .font(.system(size: 15, weight: .black))
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
        }
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1, radius: 16, seed: 122 + index, padding: 14)
        .paperTilt(122 + index, max: 0.7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(masjid.name), \(masjid.distanceString)\(index == 0 ? ", nearest" : "")")
        .accessibilityHint("Opens directions")
    }

    @ViewBuilder
    private func contextActions(_ masjid: MasjidItem) -> some View {
        Button { viewModel.openInMaps(masjid) } label: {
            Label("Apple Maps", systemImage: "map")
        }
        Button { viewModel.openInGoogleMaps(masjid) } label: {
            Label("Google Maps", systemImage: "globe")
        }
        if let phone = masjid.phoneNumber,
           let url = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
            Link(destination: url) { Label(phone, systemImage: "phone") }
        }
        if let url = masjid.url {
            Link(destination: url) { Label("Website", systemImage: "safari") }
        }
        ShareLink(item: "\(masjid.name)\n\(masjid.address)") {
            Label("Share", systemImage: "square.and.arrow.up")
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            PaperIconView(.masjid, size: 36)
            Text("No masjids found nearby")
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.adaptiveText(colorScheme))
            Text("Try a wider search radius from the menu.")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1, seed: 128)
    }

    // MARK: - Filter Sheet

    private var filterSheet: some View {
        NavigationStack {
            VStack(spacing: 10) {
                ForEach(Array(MasjidFinderViewModel.SearchRadius.allCases.enumerated()), id: \.element) { index, radius in
                    let selected = viewModel.searchRadius == radius
                    Button {
                        viewModel.searchRadius = radius
                        viewModel.refreshSearch()
                        showFilterSheet = false
                    } label: {
                        HStack {
                            Text(radius.displayName)
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                            Spacer()
                            PaperCheckbox(isOn: selected, size: 22, seed: 140 + index)
                        }
                        .paperPiece(
                            Color.adaptiveCardSurface(colorScheme),
                            material: .card,
                            depth: selected ? 1.2 : 0.5,
                            radius: 14,
                            seed: 140 + index,
                            padding: 14
                        )
                    }
                    .buttonStyle(PaperPressStyle())
                    .accessibilityAddTraits(selected ? .isSelected : [])
                }
                Spacer()
            }
            .padding(20)
            .paperBackground()
            .navigationTitle("Search Radius")
            .toolbarTitleDisplayMode(.inline)
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
        VStack(spacing: 14) {
            PaperIconView(.pin, size: 40)

            Text("Location access is needed to find nearby masjids.")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)

            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                PaperButtonLabel(title: "Open Settings", seed: 129)
            }
            .buttonStyle(PaperPressStyle())
        }
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1.2, seed: 130)
        .padding(24)
    }
}

// MARK: - Paper Map

/// Real Apple Maps streets given a paper treatment (muted, kraft-tinted, grained,
/// cut edges), with a paper masjid cut-out standing on each masjid's actual
/// location. Framed to fit you and the masjids shown.
struct PaperMasjidMap: View {
    let center: CLLocationCoordinate2D
    let masjids: [MasjidItem]
    var isLoading = false
    @State private var position: MapCameraPosition = .automatic
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Map(position: $position, interactionModes: [.pan, .zoom]) {
                UserAnnotation()
                // Farthest first so the nearest cut-out stands in front.
                ForEach(Array(masjids.enumerated()).reversed(), id: \.element.id) { index, masjid in
                    Annotation(masjid.name, coordinate: masjid.coordinate, anchor: .bottom) {
                        MasjidCutout(isNearest: index == 0, seed: 150 + index)
                            .scaleEffect(index == 0 ? 1.15 : 0.85, anchor: .bottom)
                    }
                    .annotationTitles(index == 0 ? .automatic : .hidden)
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControls { MapUserLocationButton() }

            // Paper over the streets: a kraft wash and fibres, never blocking touches.
            Color(hex: scheme == .dark ? "#3A2E28" : "#D9C29A")
                .opacity(scheme == .dark ? 0.35 : 0.30)
                .blendMode(.multiply)
                .allowsHitTesting(false)
            PaperGrain(material: .kraft, seed: 125, dark: scheme == .dark)
                .allowsHitTesting(false)

            if isLoading && masjids.isEmpty {
                PaperTag(text: "Looking for masjids…", color: Color.lightCardSurface, ink: .lightBodyText, seed: 126)
            }
        }
        .clipShape(CutShape(cornerRadius: 13, seed: 127))
        .onAppear { position = .region(fittingRegion) }
        .onChange(of: masjids.map(\.id)) { _, _ in
            withAnimation(.open(0.4)) { position = .region(fittingRegion) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(masjids.isEmpty ? "Map of your area" : "Map showing \(masjids.count) masjids around you")
    }

    /// A region containing you and every masjid shown, with a margin for the cut-outs.
    private var fittingRegion: MKCoordinateRegion {
        let coords = [center] + masjids.map(\.coordinate)
        let lats = coords.map(\.latitude), lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(), let minLon = lons.min(), let maxLon = lons.max() else {
            return MKCoordinateRegion(center: center, latitudinalMeters: 3_000, longitudinalMeters: 3_000)
        }
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.5),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.5)
        )
        let mid = CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2 + span.latitudeDelta * 0.06, longitude: (minLon + maxLon) / 2)
        return MKCoordinateRegion(center: mid, span: span)
    }
}

private struct MasjidCutout: View {
    let isNearest: Bool
    let seed: Int

    var body: some View {
        ZStack(alignment: .bottom) {
            // contact shadow on the map
            Ellipse()
                .fill(Color(red: 0.16, green: 0.08, blue: 0.02).opacity(0.22))
                .frame(width: 34, height: 7)
                .offset(x: 2, y: 3)

            if isNearest {
                CutShape(cornerRadius: 1.5, edge: .torn, seed: seed)
                    .fill(Color.islamicGold)
                    .frame(width: 36, height: 7)
                    .offset(y: 3)
                    .paperShadow(depth: 0.4)
            }

            Canvas { ctx, size in
                let ox = size.width / 2, oy = size.height
                func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: ox + x, y: oy + y) }
                let hall = isNearest ? Color.lightCardSurface : Color.lightCardElevated
                let dome = isNearest ? Color.lightPrimary : Color.darkPrimary

                // minaret
                var minaret = Path()
                minaret.addRect(CGRect(x: ox + 14, y: oy - 21, width: 3.4, height: 21))
                minaret.move(to: pt(13.6, -21)); minaret.addLine(to: pt(15.7, -26)); minaret.addLine(to: pt(17.8, -21)); minaret.closeSubpath()
                ctx.fill(minaret, with: .color(.paperKraft))
                // hall
                ctx.fill(Path(CGRect(x: ox - 13, y: oy - 11, width: 26, height: 11)), with: .color(hall))
                // dome
                var d = Path()
                d.move(to: pt(-8.5, -11))
                d.addCurve(to: pt(0, -23), control1: pt(-8.5, -17), control2: pt(-4.7, -20.6))
                d.addCurve(to: pt(8.5, -11), control1: pt(4.7, -20.6), control2: pt(8.5, -17))
                d.closeSubpath()
                ctx.fill(d, with: .color(dome))
                // finial and crescent
                ctx.fill(Path(CGRect(x: ox - 0.5, y: oy - 27, width: 1, height: 4)), with: .color(Color(hex: "#C79A3A")))
                ctx.fill(Path(ellipseIn: CGRect(x: ox - 1.8, y: oy - 30, width: 3.2, height: 3.2)), with: .color(Color(hex: "#C79A3A")))
                // door and windows
                var door = Path()
                door.move(to: pt(-2.4, 0)); door.addLine(to: pt(-2.4, -5.2))
                door.addArc(center: pt(0, -5.2), radius: 2.4, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
                door.addLine(to: pt(2.4, 0)); door.closeSubpath()
                ctx.fill(door, with: .color(.lightPrimary))
                ctx.fill(Path(roundedRect: CGRect(x: ox - 9, y: oy - 9.5, width: 3, height: 3), cornerRadius: 1.5), with: .color(Color.paperKraft.opacity(0.8)))
                ctx.fill(Path(roundedRect: CGRect(x: ox + 6, y: oy - 9.5, width: 3, height: 3), cornerRadius: 1.5), with: .color(Color.paperKraft.opacity(0.8)))
            }
            .frame(width: 40, height: 32)
            .shadow(color: Color(red: 0.12, green: 0.06, blue: 0.02).opacity(0.4), radius: 0.7, x: 0.6, y: 1.2)
            .shadow(color: Color(red: 0.12, green: 0.06, blue: 0.02).opacity(0.22), radius: 2, x: 1.4, y: 2.6)
        }
        .frame(width: 44, height: 36)
        .overlay(alignment: .top) {
            if isNearest {
                Text("NEAREST")
                    .font(.system(size: 7.5, weight: .black, design: .rounded))
                    .foregroundStyle(Color.lightCardSurface)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2.5)
                    .paperPiece(.paperTerracotta, material: .construction, depth: 0.5, edge: .torn, radius: 1.5, seed: seed + 3, padding: nil)
                    .rotationEffect(.degrees(-4))
                    .offset(y: -18)
                    .fixedSize()
            }
        }
        .accessibilityHidden(true)
    }
}
