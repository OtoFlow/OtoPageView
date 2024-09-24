//
//  HostingView.swift
//  OtoPageView
//
//  Created by foyoodo on 2024/6/3.
//

import SwiftUI

public final class HostingView<Content: View>: UIView {

    private var hostingViewController: UIHostingController<Content>

    public init(rootView: Content, frame: CGRect = .zero) {
        hostingViewController = UIHostingController(rootView: rootView)

        super.init(frame: frame)

        hostingViewController.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        addSubview(hostingViewController.view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
