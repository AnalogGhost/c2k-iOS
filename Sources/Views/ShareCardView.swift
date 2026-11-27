import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// The share image itself, laid out at 360 × 640 points and rendered at 3× for a 1080 × 1920
/// story-sized picture. Everything is drawn on the device: the route is the run's own GPS points.
struct ShareCardCanvas: View {
    let stats: ShareCardStats
    let route: [CGPoint]
    let background: ShareBackground
    let customPhoto: UIImage?

    static let size = CGSize(width: 360, height: 640)

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            backdrop
            VStack(alignment: .leading, spacing: 16) {
                Text(verbatim: "C2K").font(.system(size: 24, weight: .heavy, design: .rounded))
                Spacer(minLength: 0)
                if route.count > 1 {
                    RouteOutlineShape(points: route)
                        .stroke(.white, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                        .frame(width: 140, height: 140)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(headline)
                        .font(.system(size: 30, weight: .bold))
                        .lineLimit(3).minimumScaleFactor(0.7)
                    Text(subtitle).font(.system(size: 17, weight: .semibold)).opacity(0.9)
                }
                statsRow
                Text(verbatim: "hackerapps.com/apps/c2k").font(.system(size: 12, weight: .medium)).opacity(0.75)
            }
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(background == .sticker ? 0.7 : 0.35), radius: 4)
            .padding(28)
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    private var headline: String {
        stats.finishedProgram ? String(format: String(localized: "celebration_title"), stats.programName)
                              : stats.programName
    }

    private var subtitle: String {
        let date = stats.date.formatted(date: .abbreviated, time: .omitted)
        if stats.finishedProgram { return date }
        let weekDay = String(format: String(localized: "history_week_day"), stats.week, stats.day)
        return "\(weekDay)  ·  \(date)"
    }

    private var statsRow: some View {
        HStack(alignment: .top, spacing: 26) {
            stat(formatDuration(stats.durationSeconds), String(localized: "time"))
            if stats.distanceMeters > 0 {
                stat(String(format: "%.2f", locale: .current, stats.distanceMeters / 1000), String(localized: "km"))
            }
            if let pace = stats.paceSecondsPerKm {
                stat(String(format: String(localized: "workout_pace"), formatTime(pace)), String(localized: "pace"))
            }
        }
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.system(size: 24, weight: .bold).monospacedDigit())
            Text(label.uppercased()).font(.system(size: 11, weight: .semibold)).opacity(0.8)
        }
    }

    @ViewBuilder private var backdrop: some View {
        switch background {
        case .sticker:
            Color.clear
        case .gradient(let n):
            LinearGradient(colors: Self.gradients[n % Self.gradients.count], startPoint: .top, endPoint: .bottom)
        case .photo, .custom:
            ZStack {
                photo.resizable().scaledToFill()
                    .frame(width: Self.size.width, height: Self.size.height)
                // Darkens the lower half so the white text reads on any photo.
                LinearGradient(colors: [.black.opacity(0.25), .clear, .black.opacity(0.75)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
    }

    private var photo: Image {
        if case .custom = background, let customPhoto { return Image(uiImage: customPhoto) }
        return Image(background.assetName ?? "share-bg-01")
    }

    static let gradients: [[Color]] = [
        [.runOrange, Color(red: 0.55, green: 0.12, blue: 0.20)],
        [.walkBlue, Color(red: 0.08, green: 0.13, blue: 0.35)],
        [.warmCoolGreen, Color(red: 0.04, green: 0.30, blue: 0.32)],
    ]
}

/// Draws `RouteOutline` points (unit square) scaled into the largest square that fits.
struct RouteOutlineShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        let origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
        var path = Path()
        path.addLines(points.map { CGPoint(x: origin.x + $0.x * side, y: origin.y + $0.y * side) })
        return path
    }
}

/// A rendered share image. PNG keeps the sticker's transparency.
struct ShareCardImage: Transferable {
    let image: UIImage

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { $0.image.pngData() ?? Data() }
            .suggestedFileName("C2K.png")
    }
}

/// Preview of the share image with a choice of backdrop, and the share button.
struct ShareCardSheet: View {
    let stats: ShareCardStats
    let route: [CGPoint]
    /// Text shared alongside the image where the target app takes it.
    var message: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.displayScale) private var displayScale
    @State private var background: ShareBackground = .photo(1)
    @State private var customPhoto: UIImage?
    @State private var pickerItem: PhotosPickerItem?
    @State private var rendered: ShareCardImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                GeometryReader { geo in
                    let scale = min(geo.size.width / ShareCardCanvas.size.width,
                                    geo.size.height / ShareCardCanvas.size.height)
                    canvas
                        .background(background == .sticker ? Color.gray.opacity(0.3) : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 12 / max(scale, 0.01)))
                        .scaleEffect(scale)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
                backgroundPicker
                shareButton
            }
            .padding(.vertical, 16)
            .navigationTitle(String(localized: "share_card_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("share-card-done")
                }
            }
        }
        .accessibilityIdentifier("share-card-sheet")
        .task(id: background) { render() }
        .onChange(of: pickerItem) { _, item in loadPhoto(item) }
    }

    private var canvas: some View {
        ShareCardCanvas(stats: stats, route: route, background: background, customPhoto: customPhoto)
    }

    @ViewBuilder private var shareButton: some View {
        if let rendered {
            ShareLink(item: rendered, message: message.map { Text($0) },
                      preview: SharePreview(String(localized: "share_card_title"), image: Image(uiImage: rendered.image))) {
                Label(String(localized: "celebration_share"), systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 40)
            .accessibilityIdentifier("share-card-share")
        } else {
            ProgressView().frame(height: 50)
        }
    }

    private var backgroundPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    tile(selected: background == .custom) {
                        ZStack {
                            if let customPhoto {
                                Image(uiImage: customPhoto).resizable().scaledToFill()
                            } else {
                                Color.secondary.opacity(0.2)
                            }
                            Image(systemName: "photo.badge.plus").font(.title3).foregroundStyle(.white)
                                .shadow(radius: 2)
                        }
                    }
                }
                .accessibilityLabel(String(localized: "share_card_your_photo"))
                .accessibilityIdentifier("share-bg-custom")

                Button { background = .sticker } label: {
                    tile(selected: background == .sticker) {
                        ZStack {
                            Checkerboard().fill(Color.secondary.opacity(0.25))
                            Image(systemName: "square.dashed").font(.title3)
                        }
                    }
                }
                .accessibilityLabel(String(localized: "share_card_sticker"))
                .accessibilityIdentifier("share-bg-sticker")

                ForEach(Array(ShareBackground.builtIn.enumerated()), id: \.offset) { index, choice in
                    Button { background = choice } label: {
                        tile(selected: background == choice) { thumbnail(choice) }
                    }
                    .accessibilityLabel(String(format: String(localized: "share_card_background"), index + 1))
                    .accessibilityIdentifier(identifier(choice))
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 96)
    }

    @ViewBuilder private func thumbnail(_ choice: ShareBackground) -> some View {
        switch choice {
        case .gradient(let n):
            LinearGradient(colors: ShareCardCanvas.gradients[n], startPoint: .top, endPoint: .bottom)
        case .photo:
            if let image = ShareThumbnails.image(choice) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.secondary.opacity(0.2)
            }
        default:
            Color.clear
        }
    }

    private func tile<Content: View>(selected: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(width: 54, height: 96)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8)
                .strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 3))
            .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func identifier(_ choice: ShareBackground) -> String {
        switch choice {
        case .photo(let n): return "share-bg-photo-\(n)"
        case .gradient(let n): return "share-bg-gradient-\(n)"
        case .custom: return "share-bg-custom"
        case .sticker: return "share-bg-sticker"
        }
    }

    private func render() {
        let renderer = ImageRenderer(content: canvas)
        renderer.scale = 3
        renderer.isOpaque = background != .sticker
        rendered = renderer.uiImage.map(ShareCardImage.init)
    }

    private func loadPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            // Big enough to fill the 1080-wide image; a full camera photo would only use memory.
            let scale = min(1, 1440 / max(image.size.width, image.size.height))
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            customPhoto = await image.byPreparingThumbnail(ofSize: size) ?? image
            if background == .custom { render() } else { background = .custom }
        }
    }
}

/// Small decoded copies of the bundled photos, so the picker doesn't hold 13 full-size images.
@MainActor
private enum ShareThumbnails {
    private static var cache: [Int: UIImage] = [:]

    static func image(_ choice: ShareBackground) -> UIImage? {
        guard case .photo(let n) = choice, let name = choice.assetName else { return nil }
        if let cached = cache[n] { return cached }
        let thumb = UIImage(named: name)?.preparingThumbnail(of: CGSize(width: 108, height: 144))
        cache[n] = thumb
        return thumb
    }
}

/// The usual "transparent" pattern for the sticker choice.
private struct Checkerboard: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let size: CGFloat = 9
        for row in 0..<Int(ceil(rect.height / size)) {
            for col in 0..<Int(ceil(rect.width / size)) where (row + col).isMultiple(of: 2) {
                path.addRect(CGRect(x: CGFloat(col) * size, y: CGFloat(row) * size, width: size, height: size))
            }
        }
        return path
    }
}
