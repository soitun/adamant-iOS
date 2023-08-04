//
//  ContextMenuOverlayViewModel.swift
//  
//
//  Created by Stanislav Jelezoglo on 07.07.2023.
//

import SwiftUI
import CommonKit

final class ContextMenuOverlayViewModel: ObservableObject {
    let contentView: UIView
    let contentViewSize: CGSize
    let locationOnScreen: CGPoint
    let menu: AMenuViewController?
    let upperContentView: AnyView?
    let upperContentSize: CGSize
    let animationDuration: TimeInterval
    
    var upperContentViewLocation: CGPoint = .zero
    var contentViewLocation: CGPoint = .zero
    var menuLocation: CGPoint = .zero
    var startOffsetForContentView: CGFloat = .zero
    
    var startOffsetForUpperContentView: CGFloat {
        locationOnScreen.y - (upperContentSize.height + minContentsSpace)
    }
    
    var menuSize: CGSize {
        menu?.menuSize ?? .init(width: 250, height: 300)
    }
    
    weak var delegate: OverlayViewDelegate?
    
    @Published var additionalMenuVisible = false
    @Published var shouldScroll: Bool = false
    
    init(
        contentView: UIView,
        contentViewSize: CGSize,
        locationOnScreen: CGPoint,
        menu: AMenuViewController?,
        upperContentView: AnyView?,
        upperContentSize: CGSize,
        animationDuration: TimeInterval
    ) {
        self.contentView = contentView
        self.contentViewSize = contentViewSize
        self.locationOnScreen = locationOnScreen
        self.menu = menu
        self.upperContentView = upperContentView
        self.upperContentSize = upperContentSize
        self.animationDuration = animationDuration
        
        startOffsetForContentView = locationOnScreen.y
        contentViewLocation = calculateContentViewLocation()
        menuLocation = calculateMenuLocation()
        upperContentViewLocation = calculateUpperContentViewLocation()
        shouldScroll = shoudScroll()
    }
    
    @MainActor func dismiss() async {
        await animate(duration: animationDuration) {
            self.additionalMenuVisible.toggle()
        }
        
        delegate?.didDissmis()
    }
    
    func update(locationOnScreen: CGPoint) {
        startOffsetForContentView = locationOnScreen.y
    }
}

private extension ContextMenuOverlayViewModel {
    func calculateContentViewLocation() -> CGPoint {
        .init(
            x: locationOnScreen.x,
            y: calculateOffsetForContentView()
        )
    }
    
    func calculateUpperContentViewLocation() -> CGPoint {
        .init(
            x: isNeedToMoveFromTrailing()
            ? calculateLeadingOffset(for: upperContentSize.width)
            : locationOnScreen.x,
            y: calculateOffsetForUpperContentView()
        )
    }
    
    func calculateMenuLocation() -> CGPoint {
        .init(
            x: isNeedToMoveFromTrailing()
            ? calculateLeadingOffset(for: menuSize.width)
            : locationOnScreen.x,
            y: minContentsSpace
        )
    }
    
    func calculateMenuTopOffset() -> CGFloat {
        calculateOffsetForContentView()
        + contentViewSize.height
        + minContentsSpace
    }
    
    func calculateLeadingOffset(for width: CGFloat) -> CGFloat {
        (locationOnScreen.x + contentViewSize.width) - width
    }
    
    func isNeedToMoveFromTrailing() -> Bool {
        return UIScreen.main.bounds.width < locationOnScreen.x + menuSize.width + minBottomOffset
    }
    
    func calculateOffsetForUpperContentView() -> CGFloat {
        let offset = calculateOffsetForContentView()
        - (upperContentSize.height + minContentsSpace)
        
        return offset < .zero
        ? minBottomOffset
        : offset
    }
    
    func calculateOffsetForContentView() -> CGFloat {
        guard !shoudScroll() else {
            return minBottomOffset
        }
        
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
    
    func shoudScroll() -> Bool {
        guard contentViewSize.height
                + menuSize.height
                + minBottomOffset
                < UIScreen.main.bounds.height
        else {
            return true
        }
        
        return false
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
        UIScreen.main.bounds.height - bottomPosition < (menuSize.height + minBottomOffset)
    }
    
    func getOffsetToMoveFromBottom() -> CGFloat {
        UIScreen.main.bounds.height
        - menuSize.height
        - contentViewSize.height
        - minBottomOffset
    }
    
}

private let estimateMenuRowHeight: CGFloat = 50
private let minBottomOffset: CGFloat = 50
private let minContentsSpace: CGFloat = 15
