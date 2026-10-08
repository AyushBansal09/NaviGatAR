import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

enum QRCodeImage {
    private static let context = CIContext()

    static func make(_ string: String, scale: CGFloat = 12) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: scale, y: scale)),
              let cgImage = context.createCGImage(output, from: output.extent)
        else { return nil }
        return UIImage(cgImage: cgImage)
    }

    static func make(building: Building, location: Location) -> UIImage? {
        make(QRPayload(buildingID: building.id, locationID: location.id).string)
    }
}

/// Printable PDF with one large sign per location.
enum QRSignSheet {
    static func makePDF(for building: Building, locations: [Location]? = nil) throws -> URL {
        let pages = locations ?? building.sortedLocations
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter, prints fine on A4
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Signs", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let baseName = BuildingFile.suggestedFileName(for: building).replacingOccurrences(of: ".navigatar.json", with: "")
        let url = folder.appendingPathComponent("\(baseName) signs.pdf")

        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        try renderer.writePDF(to: url) { context in
            for location in pages {
                context.beginPage()
                let centered = NSMutableParagraphStyle()
                centered.alignment = .center

                draw("NaviGatAR", in: CGRect(x: 40, y: 50, width: 532, height: 30),
                     font: .systemFont(ofSize: 20, weight: .semibold), color: .systemPurple, style: centered)
                draw(location.name, in: CGRect(x: 40, y: 90, width: 532, height: 80),
                     font: .systemFont(ofSize: 40, weight: .bold), color: .black, style: centered)
                if !location.subtitle.isEmpty {
                    draw(location.subtitle, in: CGRect(x: 40, y: 175, width: 532, height: 30),
                         font: .systemFont(ofSize: 18), color: .darkGray, style: centered)
                }
                if let image = QRCodeImage.make(building: building, location: location) {
                    context.cgContext.interpolationQuality = .none
                    // 360 pt ≈ 12.7 cm: large enough to scan from a few metres.
                    image.draw(in: CGRect(x: 126, y: 220, width: 360, height: 360))
                }
                draw("Scan with the NaviGatAR app to get directions",
                     in: CGRect(x: 40, y: 600, width: 532, height: 30),
                     font: .systemFont(ofSize: 18, weight: .medium), color: .black, style: centered)
                draw("Mount flat on a wall at eye level (about 1.4 m / 4.5 ft). Keep it uncovered and well lit.\n\(building.name)",
                     in: CGRect(x: 60, y: 650, width: 492, height: 60),
                     font: .systemFont(ofSize: 12), color: .gray, style: centered)
            }
        }
        return url
    }

    private static func draw(_ text: String, in rect: CGRect, font: UIFont, color: UIColor, style: NSParagraphStyle) {
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
    }
}

/// UIKit share sheet, used for files that are generated on demand.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

struct SharedFile: Identifiable {
    let id = UUID()
    let url: URL
}
