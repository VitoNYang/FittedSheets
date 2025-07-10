import UIKit

class SheetPresentationController: UIPresentationController {
    private let options: SheetOptions
    private let sheetViewController: SheetViewController
    private var isAnimating = false
    
    override init(presentedViewController: UIViewController, presenting presentingViewController: UIViewController?) {
        guard let sheetViewController = presentedViewController as? SheetViewController else {
            fatalError("SheetPresentationController must be used with SheetViewController")
        }
        self.options = sheetViewController.options
        self.sheetViewController = sheetViewController
        super.init(presentedViewController: presentedViewController, presenting: presentingViewController)
    }
    
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else { return .zero }
        return containerView.bounds
    }
    
    override func presentationTransitionWillBegin() {
        guard let containerView = containerView else { return }
        
        self.sheetViewController.overlayView.frame = containerView.bounds
        
        // Add the presented view to the container
        if let presentedView = presentedView {
            containerView.addSubview(presentedView)
            presentedView.frame = frameOfPresentedViewInContainerView
        }
        
        isAnimating = true
        
        // Animate alongside the transition
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }
            self.sheetViewController.overlayView.alpha = 1
            
            // Handle presenter scaling
            if self.options.shrinkPresentingViewController {
                self.setPresentor(percentComplete: 0)
            }
        }, completion: { [weak self] _ in
            self?.isAnimating = false
        })
    }
    
    override func dismissalTransitionWillBegin() {
        isAnimating = true
        
        // Animate alongside the dismissal
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }
            self.sheetViewController.overlayView.alpha = 0
            
            // Restore presenter scaling
            if self.options.shrinkPresentingViewController {
                self.restorePresentor()
            }
        }, completion: { [weak self] _ in
            self?.isAnimating = false
        })
    }
    
    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        // Only update layout when not animating
        if !isAnimating {
            presentedView?.frame = frameOfPresentedViewInContainerView
        }
    }
    
    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        // Only update layout when not animating
        if !isAnimating {
            presentedView?.frame = frameOfPresentedViewInContainerView
        }
    }
    
    override func presentationTransitionDidEnd(_ completed: Bool) {
        if !completed {
            self.sheetViewController.overlayView.alpha = 0
            if self.options.shrinkPresentingViewController {
                self.restorePresentor()
            }
        }
    }
    
    override func dismissalTransitionDidEnd(_ completed: Bool) {
        if completed, sheetViewController.isBeingDismissed {
            self.sheetViewController.didDismiss?(self.sheetViewController)
        }
    }
    
    // MARK: - Presenter Scaling
    
    func setPresentor(percentComplete: CGFloat) {
        guard self.options.shrinkPresentingViewController, let presenter = self.sheetViewController.presenter else { return }
        
        var scale: CGFloat = min(1, 0.92 + (0.08 * percentComplete))
        let topSafeArea = UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.compatibleSafeAreaInsets.top ?? 0
        
        presenter.view.layer.transform = CATransform3DConcat(
            CATransform3DMakeTranslation(0, (1 - percentComplete) * topSafeArea/2, 0),
            CATransform3DMakeScale(scale, scale, 1)
        )
        presenter.view.layer.cornerRadius = self.options.presentingViewCornerRadius * (1 - percentComplete)
        
        if SheetOptions.shrinkingNestedPresentingViewControllers {
            let presenters = SheetTransition.currentPresenters.reversed().dropFirst()
            for lowerPresenter in presenters {
                scale *= 0.92
                lowerPresenter.view.layer.transform = CATransform3DConcat(
                    CATransform3DMakeTranslation(0, (1 - percentComplete) * topSafeArea/2, 0),
                    CATransform3DMakeScale(scale, scale, 1)
                )
            }
        }
    }
    
    func restorePresentor() {
        guard let presenter = self.sheetViewController.presenter else { return }
        
        SheetTransition.currentPresenters.removeAll(where: { $0 == presenter })
        let topSafeArea = UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.compatibleSafeAreaInsets.top ?? 0
        
        UIView.animate(
            withDuration: self.options.transitionDuration,
            animations: {
                if self.options.shrinkPresentingViewController {
                    presenter.view.layer.transform = CATransform3DMakeScale(1, 1, 1)
                    presenter.view.layer.cornerRadius = 0
                }
                
                if SheetOptions.shrinkingNestedPresentingViewControllers {
                    var scale: CGFloat = 1.0
                    let presenters = SheetTransition.currentPresenters.reversed()
                    for lowerPresenter in presenters {
                        scale *= 0.92
                        lowerPresenter.view.layer.transform = CATransform3DConcat(
                            CATransform3DMakeTranslation(0, topSafeArea/2, 0),
                            CATransform3DMakeScale(scale, scale, 1)
                        )
                    }
                }
            }
        )
    }
} 
