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
        contentSize = layout.contentSizeMaker(layoutRef)
    }

    open override func layoutSubviews() {
        super.layoutSubviews()

        layout.supplementaries.forEach { supplementary in
            supplementary.view.frame = supplementary.placement.frame(applying: layoutRef)
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

        public enum Placement {

            case pinnedTop(size: CGSize, alignment: Alignment = .center)

            case header(height: CGFloat, frameMaker: (_ layoutRef: LayoutRef) -> CGRect)

            case frame((_ layoutRef: LayoutRef) -> CGRect)

            var intrinsicPinnedHeight: CGFloat {
                switch self {
                case .pinnedTop(let size, _):
                    return size.height
                default:
                    return 0.0
                }
            }

            var intrinsicHeight: CGFloat {
                switch self {
                case .header(let height, _):
                    return height
                default:
                    return 0.0
                }
            }

            func frame(applying layoutRef: NonScrollView.LayoutRef) -> CGRect {
                switch self {
                case .pinnedTop(let size, let alignment):
                    return CGRect(origin: .init(x: (layoutRef.width - size.width) / 2, y: 0), size: size)
                case .header(_, let frameMaker), .frame(let frameMaker):
                    return frameMaker(layoutRef)
                }
            }
        }

        public enum Alignment {

            case leading

            case trailing

            case center
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

        public static func header(_ header: UIView, height: CGFloat) -> Supplementary {
            .init(
                view: header,
                placement: .header(height: height, frameMaker: { layoutRef in
                    CGRect(origin: .zero, size: .init(width: layoutRef.width, height: height))
                })
            )
        }

        public static func customView(configuration: CustomViewConfiguration) -> Supplementary {
            .init(
                view: configuration.customView,
                placement: configuration.placement
            )
        }
    }
}
