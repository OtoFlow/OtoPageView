//
//  OtoPageViewController.swift
//  OtoPageView
//
//  Created by foyoodo on 2024/6/1.
//

import UIKit

public protocol PageScrollable where Self: UIViewController {

    var scrollView: UIScrollView? { get }
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
        (pageViewController.viewControllers?.first as? PageScrollable)?.scrollView
    }

    private var pageOrigin: CGPoint = .zero

    private lazy var pageViewController: UIPageViewController = {
        let vc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        vc.delegate = self
        vc.dataSource = self
        return vc
    }()

    open weak var delegate: (any Delegate)?

    open weak var dataSource: (any DataSource)?

    public let supplymentaries: [NonScrollView.Supplementary]

    public convenience init(header: UIView, height: CGFloat) {
        self.init(supplymentaries: [
            .header(header, height: height)
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

        mainScrollView.invalidateLayout()

        DispatchQueue.main.async {
            (viewController as? PageScrollable)?.scrollView?.isScrollEnabled = false
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
        for case let vc as PageScrollable in pageViewController.viewControllers ?? [] {
            DispatchQueue.main.async {
                vc.scrollView?.isScrollEnabled = false
            }
        }

        mainScrollView.invalidateLayout()
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
