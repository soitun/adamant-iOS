//
//  ContextMenuOverlayViewModel.swift
//  
//
//  Created by Stanislav Jelezoglo on 07.07.2023.
//

import SwiftUI

class ContextMenuOverlayViewModel: ObservableObject {
    let contentView: UIView
    let contentViewSize: CGSize
    let locationOnScreen: CGPoint
    let menu: UIMenu
    let menuAlignment: Alignment
    let upperContentView: AnyView?
    let upperContentSize: CGSize
    
    var upperContentViewLocation: CGPoint = .zero
    var menuLocation: CGPoint = .zero
    var menuWidth: CGFloat = 300
    
    var finalOffsetForContentView: CGFloat = .zero
    var finalOffsetForUpperContentView: CGFloat = .zero
    
    var startOffsetForContentView: CGFloat {
        locationOnScreen.y
    }
    
    var startOffsetForUpperContentView: CGFloat {
        locationOnScreen.y - (upperContentSize.height + minContentsSpace)
    }
    
    var menuHeight: CGFloat {
        calculateEstimateMenuHeight()
    }
    
    let transition = AnyTransition.asymmetric(
        insertion: .scale(scale: 0.9, anchor: .center),
        removal: .identity
    )
    
    let topContentTransition = AnyTransition.asymmetric(
        insertion: .scale(scale: 0, anchor: .bottom),
        removal: AnyTransition.opacity.combined(
            with: .scale(scale: 0, anchor: .bottom)
        )
    )
    
    let menuTransition = AnyTransition.asymmetric(
        insertion: .scale(scale: 0, anchor: .top),
        removal: AnyTransition.opacity.combined(
            with: .scale(scale: 0, anchor: .top)
        )
    )
    
    weak var delegate: OverlayViewDelegate?
    
    @Published var isContextMenuVisible = false
    
    init(
        contentView: UIView,
        contentViewSize: CGSize,
        locationOnScreen: CGPoint,
        menu: UIMenu,
        menuAlignment: Alignment,
        upperContentView: AnyView?,
        upperContentSize: CGSize
    ) {
        self.contentView = contentView
        self.contentViewSize = contentViewSize
        self.locationOnScreen = locationOnScreen
        self.menu = menu
        self.menuAlignment = menuAlignment
        self.upperContentView = upperContentView
        self.upperContentSize = upperContentSize
        
        finalOffsetForContentView = calculateOffsetForContentView()
        finalOffsetForUpperContentView = calculateOffsetForUpperContentView()
        menuLocation = calculateMenuLocation()
        upperContentViewLocation = calculateUpperContentViewLocation()
    }
    
    func dismiss() {
        withAnimation(.easeInOut(duration: animationDuration)) {
            isContextMenuVisible.toggle()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
            self.delegate?.didDissmis()
        }
    }
}

private extension ContextMenuOverlayViewModel {
    func calculateUpperContentViewLocation() -> CGPoint {
        .init(
            x: isNeedToMoveFromTrailing()
            ? calculateLeadingOffset(for: upperContentSize.width)
            : locationOnScreen.x,
            y: .zero
        )
    }
    
    func calculateMenuLocation() -> CGPoint {
        .init(
            x: isNeedToMoveFromTrailing()
            ? calculateLeadingOffset(for: menuWidth)
            : locationOnScreen.x,
            y: .zero
        )
    }
    
    func calculateLeadingOffset(for width: CGFloat) -> CGFloat {
        (locationOnScreen.x + contentViewSize.width) - width
    }
    
    func isNeedToMoveFromTrailing() -> Bool {
        UIScreen.main.bounds.width < locationOnScreen.x + upperContentSize.width + minBottomOffset
    }
    
    func calculateOffsetForUpperContentView() -> CGFloat {
        calculateOffsetForContentView()
        - (upperContentSize.height + minContentsSpace)
    }
    
    func calculateOffsetForContentView() -> CGFloat {
        if isNeedToMoveFromBottom(
            for: locationOnScreen.y + contentViewSize.height
        ) {
            return getOffsetToMoveFromBottom()
        }
        
        if isNeedToMoveFromTop() {
            return getOffsetToMoveFromTop()
        }
        
        return locationOnScreen.y
    }
    
    func calculateEstimateMenuHeight() -> CGFloat {
        CGFloat(menu.children.count) * estimateMenuRowHeight
    }
    
    func isNeedToMoveFromTop() -> Bool {
        locationOnScreen.y - minContentsSpace - upperContentSize.height < minBottomOffset
    }
    
    func getOffsetToMoveFromTop() -> CGFloat {
        minContentsSpace
        + upperContentSize.height
        + minBottomOffset
    }
    
    func isNeedToMoveFromBottom(for bottomPosition: CGFloat) -> Bool {
        UIScreen.main.bounds.height - bottomPosition < (menuHeight + minBottomOffset)
    }
    
    func getOffsetToMoveFromBottom() -> CGFloat {
        UIScreen.main.bounds.height
        - menuHeight
        - contentViewSize.height
        - minBottomOffset
    }
    
}

private let animationDuration: TimeInterval = 0.2
private let estimateMenuRowHeight: CGFloat = 50
private let minBottomOffset: CGFloat = 50
private let minContentsSpace: CGFloat = 10
