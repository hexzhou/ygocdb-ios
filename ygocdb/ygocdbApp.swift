//
//  ygocdbApp.swift
//  ygocdb
//
//  Created by hexzhou on 2026/1/11.
//

import SwiftUI
import Combine

// MARK: - TabBar 显隐兼容层（iOS 15+）

private enum LegacyTabBarVisibilityCoordinator {
    private static var hiddenRequestIDs = Set<UUID>()
    private static var tabBarController: UITabBarController?
    private static var baseAdditionalSafeAreaBottom: CGFloat?

    static func register(tabBarController controller: UITabBarController?) {
        guard let controller else { return }
        if tabBarController !== controller {
            tabBarController = controller
            baseAdditionalSafeAreaBottom = controller.additionalSafeAreaInsets.bottom
        }
        applyVisibility()
    }

    static func setHidden(_ isHidden: Bool, for requestID: UUID) {
        if isHidden {
            hiddenRequestIDs.insert(requestID)
        } else {
            hiddenRequestIDs.remove(requestID)
        }
        applyVisibility()
    }

    static func removeRequest(_ requestID: UUID) {
        hiddenRequestIDs.remove(requestID)
        applyVisibility()
    }

    private static func applyVisibility() {
        DispatchQueue.main.async {
            guard let controller = tabBarController else { return }

            let shouldHide = !hiddenRequestIDs.isEmpty
            let baseBottom = baseAdditionalSafeAreaBottom ?? 0
            let windowBottomInset = controller.view.window?.safeAreaInsets.bottom ?? controller.view.safeAreaInsets.bottom
            let tabBarContentHeight = max(0, controller.tabBar.frame.height - windowBottomInset)

            controller.tabBar.isHidden = shouldHide
            controller.additionalSafeAreaInsets.bottom = baseBottom + (shouldHide ? -tabBarContentHeight : 0)
            controller.view.setNeedsLayout()
        }
    }
}

private struct LegacyTabBarVisibilityBridge: UIViewControllerRepresentable {
    let isHidden: Bool
    let requestID: UUID

    func makeUIViewController(context: Context) -> Controller {
        let controller = Controller()
        controller.requestID = requestID
        return controller
    }

    func updateUIViewController(_ uiViewController: Controller, context: Context) {
        uiViewController.requestID = requestID
        uiViewController.isHidden = isHidden
        uiViewController.refreshVisibility()
    }

    final class Controller: UIViewController {
        var requestID = UUID()
        var isHidden = false

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            refreshVisibility()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            refreshVisibility()
        }

        override func viewDidDisappear(_ animated: Bool) {
            super.viewDidDisappear(animated)
            LegacyTabBarVisibilityCoordinator.removeRequest(requestID)
        }

        deinit {
            LegacyTabBarVisibilityCoordinator.removeRequest(requestID)
        }

        func refreshVisibility() {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                LegacyTabBarVisibilityCoordinator.register(tabBarController: self.tabBarController)
                LegacyTabBarVisibilityCoordinator.setHidden(self.isHidden, for: self.requestID)
            }
        }
    }
}

private struct TabBarVisibilityModifier: ViewModifier {
    let isHidden: Bool
    @State private var requestID = UUID()

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.toolbar(isHidden ? .hidden : .visible, for: .tabBar)
        } else {
            content.background(
                LegacyTabBarVisibilityBridge(isHidden: isHidden, requestID: requestID)
                    .frame(width: 0, height: 0)
            )
        }
    }
}

struct HideTabBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.modifier(TabBarVisibilityModifier(isHidden: true))
    }
}

extension View {
    func hideTabBar() -> some View {
        modifier(HideTabBarModifier())
    }
}

struct SearchTabBarModifier: ViewModifier {
    let isSearching: Bool

    func body(content: Content) -> some View {
        content.modifier(TabBarVisibilityModifier(isHidden: isSearching))
    }
}

/// 全局方向管理器，用于按需锁定屏幕方向
class OrientationManager: ObservableObject {
    static let shared = OrientationManager()
    @Published var orientationLock: UIInterfaceOrientationMask = .portrait
}

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return OrientationManager.shared.orientationLock
    }
}

@main
struct ygocdbApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(settings.appearanceMode.colorScheme)
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SearchView()
                .tabItem {
                    Image(systemName: "magnifyingglass")
                    Text("搜索")
                }
                .tag(0)

            NavigationView {
                DeckBuilderListView()
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "rectangle.stack.fill")
                Text("组卡器")
            }
            .tag(1)

            DuelCalculatorView(selectedTab: $selectedTab)
                .hideTabBar()
                .tabItem {
                    Image(systemName: "bolt.shield.fill")
                    Text("决斗")
                }
                .tag(2)
        }
    }
}
