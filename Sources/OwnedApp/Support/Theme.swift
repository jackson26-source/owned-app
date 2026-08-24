import SwiftUI
import UIKit

/// Owned's shared visual identity, carried over from the marketing site
/// at owned.macless.dev: a warm paper background, a serif headline face,
/// small monospace "eyebrow" labels, and a single rust accent color used
/// everywhere something needs to stand out. Defined once here so every
/// screen in the app draws from the same palette instead of drifting
/// toward SwiftUI's default blue-and-white system look.
enum Theme {

    // MARK: - Colors

    /// Warm, slightly-yellow paper background — the site's --bg token.
    static let background = Color(
        light: UIColor(red: 0.980, green: 0.973, blue: 0.953, alpha: 1), // #FAF8F3
        dark: UIColor(red: 0.086, green: 0.078, blue: 0.067, alpha: 1)
    )

    /// Slightly darker panel fill, used for cards — the site's --bg-panel token.
    static let panel = Color(
        light: UIColor(red: 0.949, green: 0.937, blue: 0.902, alpha: 1), // #F2EFE6
        dark: UIColor(red: 0.129, green: 0.118, blue: 0.098, alpha: 1)
    )

    /// Hairline border/divider color — the site's --border token.
    static let border = Color(
        light: UIColor(red: 0.886, green: 0.867, blue: 0.816, alpha: 1), // #E2DDD0
        dark: UIColor(red: 0.243, green: 0.224, blue: 0.192, alpha: 1)
    )

    /// Primary text — the site's --text token.
    static let textPrimary = Color(
        light: UIColor(red: 0.141, green: 0.129, blue: 0.110, alpha: 1), // #24211C
        dark: UIColor(red: 0.949, green: 0.937, blue: 0.902, alpha: 1)
    )

    /// Secondary/dimmed text — the site's --text-dim token.
    static let textDim = Color(
        light: UIColor(red: 0.420, green: 0.396, blue: 0.345, alpha: 1), // #6B6558
        dark: UIColor(red: 0.702, green: 0.678, blue: 0.612, alpha: 1)
    )

    /// Faintest text, for the least important labels — the site's --text-faint token.
    static let textFaint = Color(
        light: UIColor(red: 0.580, green: 0.553, blue: 0.486, alpha: 1), // #948D7C
        dark: UIColor(red: 0.553, green: 0.525, blue: 0.463, alpha: 1)
    )

    /// The one accent color, used everywhere something needs to stand out:
    /// links, buttons, the selected tab, the hero stat's number. Matches
    /// the homepage's --accent token exactly (a warm rust/terracotta,
    /// deliberately not the default iOS blue). Brightened a bit in dark
    /// mode so it still reads clearly against a dark ground.
    static let accent = Color(
        light: UIColor(red: 0.659, green: 0.275, blue: 0.118, alpha: 1), // #A8461E
        dark: UIColor(red: 0.831, green: 0.408, blue: 0.243, alpha: 1)   // #D4683E
    )

    // MARK: - Type

    /// The homepage sets headlines in Georgia; Georgia ships as a system
    /// font on iOS, so the same serif carries straight into the app with
    /// no font file to bundle.
    static func serif(_ size: CGFloat) -> Font {
        .custom("Georgia-Bold", size: size)
    }

    /// Small monospace "eyebrow" labels, matching the site's --mono
    /// kicker text (e.g. "A PURCHASE TRACKER, NOT A SHOPPING APP").
    static func eyebrow(_ size: CGFloat = 12) -> Font {
        .system(size: size, weight: .semibold, design: .monospaced)
    }

    // MARK: - App-wide chrome

    /// Configures UIKit's appearance proxies so every navigation bar, tab
    /// bar, and list in the app picks up the same paper-and-rust identity
    /// as the marketing site, without having to restyle each screen by
    /// hand. Call once, before the first view renders.
    static func applyAppearance() {
        let bg = UIColor(background)
        let panelColor = UIColor(panel)
        let accentColor = UIColor(accent)
        let primaryText = UIColor(textPrimary)
        let titleFont = UIFont(name: "Georgia-Bold", size: 17) ?? .boldSystemFont(ofSize: 17)
        let largeTitleFont = UIFont(name: "Georgia-Bold", size: 28) ?? .boldSystemFont(ofSize: 28)

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = bg
        navAppearance.shadowColor = UIColor(border)
        navAppearance.titleTextAttributes = [.foregroundColor: primaryText, .font: titleFont]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: primaryText, .font: largeTitleFont]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = accentColor

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = panelColor
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = accentColor

        UITableView.appearance().backgroundColor = bg
    }
}

private extension Color {
    /// Convenience for defining a color that adapts to light/dark mode
    /// from two UIColor values, without needing a color asset in the
    /// asset catalog for every token.
    init(light: UIColor, dark: UIColor) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark : light
        })
    }
}
