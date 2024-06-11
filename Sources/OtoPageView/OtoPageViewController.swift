//
//  OtoPageViewController.swift
//  OtoPageView
//
//  Created by foyoodo on 2024/6/1.
//

import UIKit

public protocol PageScrollableController: UIViewController {

    var scrollableView: UIScrollView? { get }
}

open class OtoPageViewController: UIViewController {

    public lazy var mainScrollView: NonScrollView = {
        let pinnedHeight = supplymentaries.reduce(0.0) { max($0, $1.placement.intrinsicPinnedHeight) }
        let contentHeight = supplymentaries.reduce(0.0) { $0 + $1.placement.intrinsicHeight }
        pageOrigin = CGPoint(x: 0, y: pinnedHeight + contentHeight)
        let layout = NonScrollView.Layout(supplementaries: supplymentaries + [
            .customView(configuration: .init(customView: pageViewController.view, placement: .frame({ [unowned self] layoutRef in
                CGRect(origin: .init(x: 0, y: pageOrigin.y), size: .init(width: layoutRef.width, height: layoutRef.height - pinnedHeight))
            })))
        ]) { [unowned self] layoutRef in
            if let scrollView = currentScrollView {
                return .init(
                    width: layoutRef.width,
                    height: scrollView.contentSize.height + scrollView.contentInset.top + scrollView.contentInset.bottom + contentHeight + scrollView.adjustedContentInset.top + scrollView.adjustedContentInset.bottom
                )
            }
            return .init(width: layoutRef.width, height: layoutRef.height + contentHeight)
        }
        let scrollView = NonScrollView(layout: layout)
        scrollView.scrollRecognizer.onChange = { [weak self] recognizer in
            guard let self, let currentScrollView else {
                return
            }
            let translation = recognizer.translation
            if recognizer.contentOffset.y >= contentHeight {
                currentScrollView.contentOffset.y += translation.y
                pageOrigin.y += translation.y
            } else {
                pageOrigin.y = contentHeight
                currentScrollView.contentOffset.y = -currentScrollView.contentInset.top
            }
        }
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    public var currentScrollView: UIScrollView? {
        (currentViewController as? PageScrollableController)?.scrollableView
    }

    public var currentViewController: UIViewController? {
        pageViewController.viewControllers?.first
    }

    private var pageOrigin: CGPoint = .zero

    private lazy var pageViewController: UIPageViewController = {
        let vc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        vc.delegate = self
        vc.dataSource = self
        return vc
    }()

    public var pageScrollView: UIScrollView? {
        for case let scrollView as UIScrollView in pageViewController.view.subviews {
            return scrollView
        }
        return nil
    }

    open weak var delegate: (any Delegate)?

    open weak var dataSource: (any DataSource)?

    public let supplymentaries: [NonScrollView.Supplementary]

    private var contentSizeObservation: NSKeyValueObservation?
    private var contentInsetObservation: NSKeyValueObservation?

    public convenience init(header: UIView, height: CGFloat) {
        self.init(supplymentaries: [
            .header(header, height: height),
        ])
    }

    public init(supplymentaries: [NonScrollView.Supplementary]) {
        self.supplymentaries = supplymentaries

        super.init(nibName: nil, bundle: nil)
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(mainScrollView)

        NSLayoutConstraint.activate([
            mainScrollView.topAnchor.constraint(equalTo: view.topAnchor),
            mainScrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            mainScrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    open func setViewController(
        _ viewController: UIViewController,
        direction: UIPageViewController.NavigationDirection,
        animated: Bool
    ) {
        pageViewController.setViewControllers([viewController], direction: direction, animated: animated)

        DispatchQueue.main.async {
            (viewController as? PageScrollableController)?.scrollableView?.isScrollEnabled = false
        }

        observeCurrentScrollViewContentIfNeeded()
    }

    private func observeCurrentScrollViewContentIfNeeded() {
        contentSizeObservation?.invalidate()
        contentSizeObservation = currentScrollView?.observe(\.contentSize, options: [.new, .old, .initial]) { [unowned self] _, contentSize in
            if contentSize.oldValue == contentSize.newValue {
                return
            }
            mainScrollView.invalidateLayout()
        }

        contentInsetObservation?.invalidate()
        contentInsetObservation = currentScrollView?.observe(\.contentInset, options: [.new, .old, .initial]) { [unowned self] _, contentInset in
            if contentInset.oldValue == contentInset.newValue {
                return
            }
            mainScrollView.invalidateLayout()
        }
    }
}

extension OtoPageViewController {

    public protocol Delegate: AnyObject {

    }

    public protocol DataSource: AnyObject {

        func pageViewController(_ pageViewController: OtoPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController?

        func pageViewController(_ pageViewController: OtoPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController?
    }
}

extension OtoPageViewController: UIPageViewControllerDelegate {

    public func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        for case let vc as PageScrollableController in pageViewController.viewControllers ?? [] {
            DispatchQueue.main.async {
                vc.scrollableView?.isScrollEnabled = false
            }
        }

        observeCurrentScrollViewContentIfNeeded()
    }
}

extension OtoPageViewController: UIPageViewControllerDataSource {

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        dataSource?.pageViewController(self, viewControllerBefore: viewController)
    }

    public func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        dataSource?.pageViewController(self, viewControllerAfter: viewController)
    }
}

extension OtoPageViewController: UIGestureRecognizerDelegate {

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let panGestureRecognizer = gestureRecognizer as? UIPanGestureRecognizer,
              let dataSource = dataSource
        else {
            return false
        }

        guard let currentViewController,
              dataSource.pageViewController(self, viewControllerBefore: currentViewController) == nil
        else {
            return false
        }

        let isLeftToRight = UIApplication.shared.userInterfaceLayoutDirection == .leftToRight
        let velocity = panGestureRecognizer.velocity(in: nil)

        if velocity.x * (isLeftToRight ? 1 : -1) <= 0 {
            return false
        }

        return abs(velocity.x) > abs(velocity.y)
    }
}
