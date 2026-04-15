import SwiftUI

enum AppTheme {
    static let workspaceBackground = Color(red: 0.95, green: 0.955, blue: 0.965)
    static let panelBackground = Color.white
    static let panelSecondaryBackground = Color(red: 0.966, green: 0.971, blue: 0.978)

    static let readerBackground = Color(red: 0.973, green: 0.955, blue: 0.878)
    static let readerPanelBackground = Color(red: 0.98, green: 0.965, blue: 0.902)
    static let readerSecondaryBackground = Color(red: 0.949, green: 0.929, blue: 0.843)

    static let overlayShadow = Color.black.opacity(0.08)
}

enum AppLayout {
    static let pagePadding: CGFloat = 24
    static let standardContentMaxWidth: CGFloat = 1280
    static let readerContentMaxWidth: CGFloat = 1360
    static let playerContentMaxWidth: CGFloat = 1380
}

enum ReaderLayoutMetrics {
    static let pageContentPadding: CGFloat = 28
    static let spreadColumnGap: CGFloat = 20
    static let spreadDividerWidth: CGFloat = 1
    static let bottomScreenPadding: CGFloat = 14

    static var pageInset: CGFloat { pageContentPadding * 2 }
    static var spreadReservedWidth: CGFloat { spreadColumnGap * 2 + spreadDividerWidth }
}
