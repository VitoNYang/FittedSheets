//
//  SheetTransitioningDelegate.swift
//  FittedSheetsPod
//
//  Created by Gordon Tucker on 8/4/20.
//  Copyright © 2020 Gordon Tucker. All rights reserved.
//

#if os(iOS) || os(tvOS) || os(watchOS)
import UIKit

public class SheetTransition: NSObject, UIViewControllerAnimatedTransitioning {
    var presenting = true
    weak var presenter: UIViewController?
    var options: SheetOptions
    
    /// Cache of presenters so we can do the experimental shrinkingNestedPresentingViewControllers behavior
    static var currentPresenters: [UIViewController] = []
    
    init(options: SheetOptions) {
        self.options = options
        super.init()
    }

    public func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return self.options.transitionDuration
    }

    public func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let containerView = transitionContext.containerView
        if self.presenting {
            guard let presenter = transitionContext.viewController(forKey: .from), let sheet = transitionContext.viewController(forKey: .to) as? SheetViewController else {
                transitionContext.completeTransition(true)
                return
            }
            sheet.presenter = presenter
            
            if SheetOptions.shrinkingNestedPresentingViewControllers {
                SheetTransition.currentPresenters.append(presenter)
            }
            
            // Set initial state
            sheet.contentViewController.view.transform = .identity
            UIView.performWithoutAnimation {
                sheet.view.layoutIfNeeded()
            }
            sheet.contentViewController.updatePreferredHeight()
            sheet.resize(to: sheet.currentSize, animated: false)
            let contentView = sheet.contentViewController.contentView
            contentView.transform = CGAffineTransform(translationX: 0, y: contentView.bounds.height)
            
            let heightPercent = contentView.bounds.height / UIScreen.main.bounds.height
            
            // Animate the view with a spring effect
            UIView.animate(
                withDuration: self.options.transitionDuration,
                delay: 0,
                usingSpringWithDamping: self.options.transitionDampening + ((heightPercent - 0.2) * 1.25 * 0.17),
                initialSpringVelocity: self.options.transitionVelocity * heightPercent,
                options: self.options.transitionAnimationOptions,
                animations: {
                    contentView.transform = .identity
                },
                completion: { _ in
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                }
            )
        } else {
            guard let presenter = transitionContext.viewController(forKey: .to),
            let sheet = transitionContext.viewController(forKey: .from) as? SheetViewController else {
                transitionContext.completeTransition(true)
                return
            }

            if SheetOptions.shrinkingNestedPresentingViewControllers {
                SheetTransition.currentPresenters.removeAll(where: { $0 == presenter })
            }
            
            let contentView = sheet.contentViewController.contentView

            UIView.animate(
                withDuration: self.transitionDuration(using: transitionContext),
                animations: {
                    contentView.transform = CGAffineTransform(translationX: 0, y: contentView.bounds.height)
                },
                completion: { _ in
                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                }
            )
        }
    }

    
}

#endif // os(iOS) || os(tvOS) || os(watchOS)
