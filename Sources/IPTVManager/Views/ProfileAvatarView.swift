import SwiftUI
import AppKit

enum ProfileAsset {
    /// Loaded once and reused everywhere the avatar appears.
    static let image: NSImage? = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("profile.png"),
              let image = NSImage(contentsOf: url) else { return nil }
        return image
    }()
}

/// Circular avatar photo with a subtle ring, used to give the app a personal,
/// "branded" identity wherever the user should feel at home.
struct ProfileAvatarView: View {
    var diameter: CGFloat = 40
    var ringWidth: CGFloat = 2

    var body: some View {
        Group {
            if let nsImage = ProfileAsset.image {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(
            Circle().strokeBorder(
                LinearGradient(colors: [Color.accentColor, Color.accentColor.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing),
                lineWidth: ringWidth
            )
        )
        .shadow(color: .black.opacity(0.25), radius: diameter * 0.08, y: diameter * 0.04)
    }
}
