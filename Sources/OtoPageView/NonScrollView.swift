//
//  NonScrollView.swift
//  OtoPageView
//
//  Created by foyoodo on 2024/6/1.
//

import UIKit

open class NonScrollView: UIScrollView {

    public private(set) lazy var scrollRecognizer = ScrollRecognizer(scrollView: self)

    open override var contentOffset: CGPoint {
        didSet {
            scrollRecognizer.updateContentOffset(contentOffset)
        }
    }

    public let layout: Layout

    var layoutRef: LayoutRef {
        .init(
            contentOffset: contentOffset,
            adjustedContentInset: superview?.safeAreaInsets ?? adjustedContentInset,
            size: bounds.size
        )
    }

    public init(frame: CGRect = .zero, layout: Layout) {
        self.layout = layout

        super.init(frame: frame)

        layout.supplementaries.forEach { addSubview($0.view) }
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open func invalidateLayout() {
        layout.supplementaries.forEach { supplementary in
            switch supplementary.placement {
            case .pinnedTop, .topSafeArea:
                bringSubviewToFront(supplementary.view)
            default: ()
            }
        }
        contentSize = layout.contentSizeMaker(layoutRef)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        var originRef: CGPoint = .zero
        layout.supplementaries.forEach { supplementary in
            supplementary.view.frame = supplementary.placement.frame(applying: layoutRef, originRef: originRef)
            if case .header = supplementary.placement {
                originRef.y = supplementary.view.frame.maxY
            }
        }
    }
}

extension NonScrollView {

    public final class ScrollRecognizer {

        public var onChange: ((_ recognizer: ScrollRecognizer) -> ())?

        var oldContentOffset: CGPoint = .zero

        var contentOffset: CGPoint = .zero

        public var translation: CGPoint {
            .init(x: contentOffset.x - oldContentOffset.x, y: contentOffset.y - oldContentOffset.y)
        }

        weak var scrollView: NonScrollView!

        public init(scrollView: NonScrollView) {
            self.scrollView = scrollView
        }

        fileprivate func updateContentOffset(_ newValue: CGPoint) {
            oldContentOffset = contentOffset
            contentOffset = newValue
            onChange?(self)
        }
    }

    open class Layout {

        let supplementaries: [Supplementary]

        let contentSizeMaker: (LayoutRef) -> CGSize

        public init(
            supplementaries: [Supplementary] = [],
            contentSizeMaker: @escaping (_ layoutRef: LayoutRef) -> CGSize
        ) {
            self.supplementaries = supplementaries
            self.contentSizeMaker = contentSizeMaker
        }
    }

    public struct LayoutRef {

        public let contentOffset: CGPoint

        public let adjustedContentInset: UIEdgeInsets

        public let size: CGSize

        public var width: CGFloat {
            size.width
        }

        public var height: CGFloat {
            size.height
        }
    }

    public struct Supplementary {

        public enum SupplementaryType {

            case header

            case customView(UIView)
        }

        public enum Distribution {

            case none

            case below([SupplementaryType])

            public static func below(_ supplementaries: SupplementaryType...) -> Self {
                .below(supplementaries)
            }
        }

        public enum Alignment {

            case stretch

            case center

            case leading

            case trailing
        }

        public enum Placement {

            case pinnedTop(
                size: CGSize,
                distribution: Distribution = .none,
                alignment: Alignment = .stretch,
                shouldIgnoreSafeArea: Bool = false
            )

            case topSafeArea(shouldStretch: Bool, opacityChanged: ((_ opacity: Double) -> ())? = nil)

            case header(height: CGFloat, frameMaker: (_ layoutRef: LayoutRef) -> CGRect)

            case frame((_ layoutRef: LayoutRef) -> CGRect)

            var intrinsicPinnedHeight: CGFloat {
                switch self {
                case .pinnedTop(let size, _, _, _):
                    return size.height
                default:
                    return 0.0
                }
            }

            var intrinsicHeight: CGFloat {
                switch self {
                case .pinnedTop(let size, _, _, _):
                    return size.height
                case .header(let height, _):
                    return height
                default:
                    return 0.0
                }
            }

            func frame(applying layoutRef: NonScrollView.LayoutRef, originRef: CGPoint = .zero) -> CGRect {
                switch self {
                case .pinnedTop(let size, let distribution, let alignment, let shouldIgnoreSafeArea):
                    var frame: CGRect
                    switch alignment {
                    case .stretch:
                        frame = .init(x: 0, y: layoutRef.contentOffset.y, width: layoutRef.width, height: size.height)
                    case .center:
                        frame = .init(origin: .init(x: (layoutRef.width - size.width) / 2, y: layoutRef.contentOffset.y), size: size)
                    case .leading:
                        frame = .init(origin: layoutRef.contentOffset, size: size)
                    case .trailing:
                        frame = .init(origin: .init(x: layoutRef.width - size.width, y: layoutRef.contentOffset.y), size: size)
                    }

                    if !shouldIgnoreSafeArea {
                        frame.origin.y += layoutRef.adjustedContentInset.top
                    }

                    if case .below = distribution {
                        frame.origin.y = max(frame.origin.y, originRef.y)
                    }

                    return frame
                case .topSafeArea(let shouldStretch, let opacityChanged):
                    let frame = CGRect(
                        x: 0,
                        y: layoutRef.contentOffset.y,
                        width: layoutRef.width,
                        height: shouldStretch ? max(layoutRef.adjustedContentInset.top, originRef.y - layoutRef.contentOffset.y) : layoutRef.adjustedContentInset.top
                    )
                    opacityChanged?(1.0 - max(0, min(1, (frame.height - layoutRef.adjustedContentInset.top) / layoutRef.adjustedContentInset.top)))
                    return frame
                case .header(_, let frameMaker), .frame(let frameMaker):
                    return frameMaker(layoutRef)
                }
            }
        }

        public struct CustomViewConfiguration {

            public let customView: UIView

            public let placement: Placement
        }

        public let view: UIView

        public let placement: Placement

        private init(view: UIView, placement: Placement) {
            self.view = view
            self.placement = placement
        }

        /// Placing a custom view as the header that scrolls with the main scroll view.
        /// - Parameters:
        ///   - header: The custom header view.
        ///   - height: The height of the header.
        /// - Returns: The supplementary configuration.
        public static func header(_ header: UIView, height: CGFloat) -> Supplementary {
            .init(
                view: header,
                placement: .header(height: height) { layoutRef in
                    CGRect(origin: .zero, size: .init(width: layoutRef.width, height: height))
                }
            )
        }

        /// Placing a custom view pinned at the top of the safe area.
        /// - Parameters:
        ///   - view: The custom view, by default, is a blur effect view.
        ///   - shouldStretch: Should the view stretch to fill the header supplementary views.
        ///   - opacityChanged: The calculated opacity during layout subviews has changed.
        /// - Returns: The supplementary configuration.
        public static func topSafeArea(
            view: UIView = UIVisualEffectView(effect: UIBlurEffect(style: .regular)),
            shouldStretch: Bool = true,
            opacityChanged: ((_ view: UIView, _ opacity: Double) -> ())? = nil
        ) -> Supplementary {
            .init(
                view: view,
                placement: .topSafeArea(
                    shouldStretch: shouldStretch,
                    opacityChanged: opacityChanged.map { closure in 
                        { opacity in closure(view, opacity) }
                    }
                )
            )
        }

        /// Placing a custom view with configuration.
        /// - Parameter configuration: The custom view configuration.
        /// - Returns: The supplementary configuration.
        public static func customView(configuration: CustomViewConfiguration) -> Supplementary {
            .init(
                view: configuration.customView,
                placement: configuration.placement
            )
        }
    }
}
