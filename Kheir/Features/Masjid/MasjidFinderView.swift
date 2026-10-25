import SwiftUI
import MapKit

/// Nearby masjids on a hand-made paper map, with a list of cards below.
///
/// The map is for looking: kraft paper with torn roads, a tissue-paper park and
/// little masjid cut-outs standing where the masjids are relative to you. Tapping
/// a card in the list opens directions in Apple Maps or Google Maps.
struct MasjidFinderView: View {
    /// `true` when pushed onto an existing navigation stack (from Qibla);
    /// `false` when presented as a sheet, so it brings its own stack and Done button.
    var isPushed = false

    @State private var viewModel = MasjidFinderViewModel()
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var directionsTarget: MasjidItem?
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
            Button("Apple Maps") { viewModel.openInMaps(masjid) }
            Button("Google Maps") { viewModel.openInGoogleMaps(masjid) }
            ShareLink(item: "\(masjid.name)\n\(masjid.address)") {
                Text("Share")
            }
            Button("Cancel", role: .cancel) {}
        } message: { masjid in
            Text(masjid.address.isEmpty ? masjid.distanceString : "\(masjid.address) · \(masjid.distanceString)")
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
                                    directionsTarget = masjid
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

/// A decorative paper map: kraft base, torn cream roads, a tissue park and pond,
/// you in the middle, and a masjid cut-out standing at each masjid's direction
/// and (relative) distance from you.
struct PaperMasjidMap: View {
    let center: CLLocationCoordinate2D
    let masjids: [MasjidItem]
    var isLoading = false
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let placed = placements(in: size)
            ZStack {
                Canvas { ctx, size in drawMap(ctx, size: size) }
                PaperGrain(material: .kraft, seed: 125, dark: scheme == .dark)

                // You are here
                ZStack {
                    Circle().fill(Color.lightCardSurface).frame(width: 15, height: 15)
                    Circle().fill(Color.paperSky).frame(width: 9, height: 9)
                }
                .paperShadow(depth: 0.6)
                .position(x: size.width / 2, y: size.height / 2)
                .accessibilityHidden(true)

                // Farthest first so nearer cut-outs stand in front.
                ForEach(placed.reversed(), id: \.index) { item in
                    MasjidCutout(isNearest: item.index == 0, seed: 150 + item.index)
                        .scaleEffect(item.index == 0 ? 1.25 : 0.95, anchor: .bottom)
                        .position(item.point)
                }

                if isLoading && masjids.isEmpty {
                    PaperTag(text: "Looking for masjids…", color: Color.lightCardSurface, ink: .lightBodyText, seed: 126)
                        .position(x: size.width / 2, y: size.height / 2 + 30)
                }
            }
            .clipShape(CutShape(cornerRadius: 13, seed: 127))
        }
        .accessibilityElement()
        .accessibilityLabel(masjids.isEmpty ? "Paper map of your area" : "Paper map showing \(masjids.count) masjids around you")
    }

    private struct Placement { let index: Int; let point: CGPoint }

    /// Projects each masjid onto the card around the centre, scaled so the
    /// farthest one sits near the edge.
    private func placements(in size: CGSize) -> [Placement] {
        guard !masjids.isEmpty else { return [] }
        let cosLat = cos(center.latitude * .pi / 180)
        let offsets = masjids.map { m in
            CGVector(dx: (m.coordinate.longitude - center.longitude) * cosLat,
                     dy: -(m.coordinate.latitude - center.latitude))
        }
        let maxX = max(offsets.map { abs($0.dx) }.max() ?? 0, 1e-6)
        let maxY = max(offsets.map { abs($0.dy) }.max() ?? 0, 1e-6)
        let scale = min((size.width * 0.40) / maxX, (size.height * 0.36) / maxY)
        return offsets.enumerated().map { i, o in
            var x = size.width / 2 + o.dx * scale
            var y = size.height / 2 + o.dy * scale
            // keep the cut-outs (which stand up from their base) inside the card
            x = min(max(x, 26), size.width - 26)
            y = min(max(y, 46), size.height - 10)
            return Placement(index: i, point: CGPoint(x: x, y: y - 14))
        }
    }

    private func drawMap(_ ctx: GraphicsContext, size: CGSize) {
        let dark = scheme == .dark
        let kraft = dark ? Color(hex: "#6E5A3E") : Color(hex: "#D9C29A")
        let road = dark ? Color(hex: "#C9B48C") : Color.lightCardSurface
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(kraft))

        // Tissue park and pond: thin paper, see-through, soft edges.
        let park = CGRect(x: size.width * 0.06, y: size.height * 0.62, width: size.width * 0.34, height: size.height * 0.30)
        ctx.fill(tissueBlob(in: park, seed: 1), with: .color(PaperInk.parkTissue.opacity(0.8)))
        let pond = CGRect(x: size.width * 0.70, y: size.height * 0.06, width: size.width * 0.26, height: size.height * 0.20)
        ctx.fill(tissueBlob(in: pond, seed: 2), with: .color(Color.paperSky.opacity(0.7)))

        // Torn roads: a winding avenue across and a straight street down.
        var across = ctx
        across.addFilter(.shadow(color: .black.opacity(0.18), radius: 1, x: 0.6, y: 1.2))
        across.fill(tornStrip(width: size.width, y: size.height * 0.44, thickness: 15, roll: 10, seed: 3), with: .color(road))

        var down = ctx
        down.translateBy(x: size.width * 0.5, y: 0)
        down.rotate(by: .degrees(84))
        down.addFilter(.shadow(color: .black.opacity(0.18), radius: 1, x: 1.2, y: -0.6))
        down.fill(tornStrip(width: size.height * 1.1, y: -6, thickness: 13, roll: 3, seed: 4), with: .color(road))

        var lane = ctx
        lane.translateBy(x: 0, y: size.height * 0.80)
        lane.rotate(by: .degrees(-8))
        lane.addFilter(.shadow(color: .black.opacity(0.14), radius: 0.8, x: 0.5, y: 1))
        lane.fill(tornStrip(width: size.width * 1.1, y: 0, thickness: 8, roll: 4, seed: 5), with: .color(road.opacity(0.9)))
    }

    /// A horizontal strip whose top and bottom edges are both torn.
    private func tornStrip(width: CGFloat, y: CGFloat, thickness: CGFloat, roll: CGFloat, seed: Int) -> Path {
        let top = PaperNoise.tornLine(width: width + 20, y: y, amplitude: roll, seed: seed)
        let bottom = PaperNoise.tornLine(width: width + 20, y: y + thickness, amplitude: roll, seed: seed)
        var p = Path()
        // Both edges share the roll so the road keeps its width; only the rag differs.
        p.move(to: top[0])
        for pt in top.dropFirst() { p.addLine(to: pt) }
        for (k, pt) in bottom.enumerated().reversed() {
            let rag = (seeded(k, salt: Double(seed) + 21) - 0.5) * 2
            p.addLine(to: CGPoint(x: pt.x, y: pt.y + rag))
        }
        p.closeSubpath()
        return p
    }

    /// A soft irregular oval, like a torn piece of tissue paper.
    private func tissueBlob(in rect: CGRect, seed: Int) -> Path {
        var p = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let steps = 48
        for i in 0...steps {
            let a = Double(i) / Double(steps) * .pi * 2
            let wobble = 1 + 0.08 * sin(a * 3 + seeded(seed, salt: 1) * 6) + (seeded(i, salt: Double(seed)) - 0.5) * 0.05
            let pt = CGPoint(x: c.x + CGFloat(cos(a) * wobble) * rect.width / 2,
                             y: c.y + CGFloat(sin(a) * wobble) * rect.height / 2)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// A tiny masjid cut from card, standing on the map. The nearest one stands on a
/// mustard base and carries a terracotta "NEAREST" tag.
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
