//
//  OtoPageView.swift
//  OtoPageView
//
//  Created by foyoodo on 2024/6/1.
//

import SwiftUI
@_spi(Advanced) import SwiftUIIntrospect

public struct OtoPageView<Header: View>: UIViewControllerRepresentable {

    var pages: [any View]

    var header: Header

    var headerHeight: CGFloat

    public init(pages: [any View], @ViewBuilder header: () -> Header, headerHeight: CGFloat) {
        self.pages = pages
        self.header = header()
        self.headerHeight = headerHeight
    }

    public func makeUIViewController(context: Context) -> OtoPageViewController {
        let pageViewController = OtoPageViewController(
            header: HostingView(rootView: header.ignoresSafeArea()),
            height: headerHeight
        )
        pageViewController.mainScrollView.contentInsetAdjustmentBehavior = .never
        pageViewController.delegate = context.coordinator
        pageViewController.dataSource = context.coordinator
        return pageViewController
    }

    public func updateUIViewController(_ pageViewController: OtoPageViewController, context: Context) {
        pageViewController.setViewController(context.coordinator.viewControllers[0], direction: .forward, animated: true)

        if let navigationController = pageViewController.navigationController,
           let targets = navigationController.interactivePopGestureRecognizer?.value(forKey: "targets") as? NSMutableArray {
            let recognzier = UIPanGestureRecognizer()
            recognzier.delegate = pageViewController
            recognzier.setValue(targets, forKey: "targets")
            pageViewController.pageScrollView?.addGestureRecognizer(recognzier)
        }
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

extension OtoPageView {

    public class Coordinator: NSObject, OtoPageViewController.Delegate, OtoPageViewController.DataSource {

        var parent: OtoPageView

        var viewControllers: [UIViewController]

        init(_ parent: OtoPageView) {
            self.parent = parent
            self.viewControllers = parent.pages.map { content in
                PageHostingController(contentView: PageContentView {
                    AnyView(content.ignoresSafeArea(.all, edges: .top))
                })
            }
        }

        // MARK: OtoPageViewController.DataSource

        public func pageViewController(_ pageViewController: OtoPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let index = viewControllers.firstIndex(of: viewController) else {
                return nil
            }
            if index == 0 {
                return nil
            }
            return viewControllers[index - 1]
        }

        public func pageViewController(_ pageViewController: OtoPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let index = viewControllers.firstIndex(of: viewController) else {
                return nil
            }
            if index + 1 == viewControllers.count {
                return nil
            }
            return viewControllers[index + 1]
        }
    }
}

struct PageContentView<Content: View>: View {

    @Weak var scrollView: UIScrollView?

    @ViewBuilder var content: Content

    var body: some View {
        content
            .introspect(.scrollView, on: .iOS(.v14, .v15, .v16, .v17)) { scrollView in
                scrollView.isScrollEnabled = false
                self.scrollView = scrollView
            }
    }
}

class PageHostingController<Content: View>: UIHostingController<PageContentView<Content>>, PageScrollableController {

    let contentView: PageContentView<Content>

    var scrollableView: UIScrollView? {
        contentView.scrollView
    }

    init(contentView: PageContentView<Content>) {
        self.contentView = contentView

        super.init(rootView: contentView)
    }

    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
