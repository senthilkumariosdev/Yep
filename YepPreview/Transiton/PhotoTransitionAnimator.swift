//
//  PhotoTransitionAnimator.swift
//  Yep
//
//  Created by NIX on 16/6/17.
//  Copyright © 2016年 Catch Inc. All rights reserved.
//

import UIKit

class PhotoTransitionAnimator: NSObject {

    var startingView: UIView?
    var endingView: UIView?

    var startingViewForAnimation: UIView?
    var endingViewForAnimation: UIView?

    var isDismissing: Bool = false

    var animationDurationWithZooming: NSTimeInterval = 0.5
    var animationDurationWithoutZooming: NSTimeInterval = 0.3

    var animationDurationFadeRatio: NSTimeInterval = 4
    var animationDurationEndingViewFadeInRatio: NSTimeInterval = 0.1
    var animationDurationStartingViewFadeOutRatio: NSTimeInterval = 0.05

    var zoomingAnimationSpringDamping: CGFloat = 0.9

    var shouldPerformZoomingAnimation: Bool {
        return (startingView != nil) && (endingView != nil)
    }
}

extension PhotoTransitionAnimator: UIViewControllerAnimatedTransitioning {

    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {

        if shouldPerformZoomingAnimation {
            return animationDurationWithZooming
        } else {
            return animationDurationWithoutZooming
        }
    }

    func animateTransition(transitionContext: UIViewControllerContextTransitioning) {

        setupTransitionContainerHierarchyWithTransitionContext(transitionContext)

        performFadeAnimationWithTransitionContext(transitionContext)

        if shouldPerformZoomingAnimation {
            performZoomingAnimationWithTransitionContext(transitionContext)
        }
    }

    private func setupTransitionContainerHierarchyWithTransitionContext(transitionContext: UIViewControllerContextTransitioning) {

        let fromView = transitionContext.viewForKey(UITransitionContextFromViewKey)!
        let toView = transitionContext.viewForKey(UITransitionContextToViewKey)!

        let toViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!

        toView.frame = transitionContext.finalFrameForViewController(toViewController)

        let containerView = transitionContext.containerView()!

        if !toView.isDescendantOfView(containerView) {
            containerView.addSubview(toView)
        }

        if isDismissing {
            containerView.bringSubviewToFront(fromView)
        }
    }

    private func performFadeAnimationWithTransitionContext(transitionContext: UIViewControllerContextTransitioning) {

        let fromView = transitionContext.viewForKey(UITransitionContextFromViewKey)!
        let toView = transitionContext.viewForKey(UITransitionContextToViewKey)!

        let viewToFade: UIView
        let beginningAlpha: CGFloat
        let endingAlpha: CGFloat
        if isDismissing {
            viewToFade = fromView
            beginningAlpha = 1
            endingAlpha = 0
        } else {
            viewToFade = toView
            beginningAlpha = 0
            endingAlpha = 1
        }

        viewToFade.alpha = beginningAlpha

        let duration = fadeDurationForTransitionContext(transitionContext)

        UIView.animateWithDuration(duration, animations: {
            viewToFade.alpha = endingAlpha

        }, completion: { [unowned self] finished in
            if self.shouldPerformZoomingAnimation {
                self.completeTransitionWithTransitionContext(transitionContext)
            }
        })
    }

    private func performZoomingAnimationWithTransitionContext(transitionContext: UIViewControllerContextTransitioning) {

        let containerView = transitionContext.containerView()!

        guard let startingView = startingView else {
            return
        }
        guard let endingView = endingView else {
            return
        }
        let startingViewForAnimation = self.startingViewForAnimation ?? newAnimationViewFromView(startingView)
        let endingViewForAnimation = self.startingViewForAnimation ?? newAnimationViewFromView(endingView)

        let finalEndingViewTransform = endingView.transform

        let translatedStartingViewCenter = centerPointForView(startingView, translatedToContainerView: containerView)
        startingViewForAnimation.center = translatedStartingViewCenter

        let endingViewInitialTransform = startingViewForAnimation.frame.height / endingViewForAnimation.frame.height
        endingViewForAnimation.transform = CGAffineTransformScale(endingViewForAnimation.transform, endingViewInitialTransform, endingViewInitialTransform)
        endingViewForAnimation.center = translatedStartingViewCenter
        endingViewForAnimation.alpha = 0

        containerView.addSubview(startingViewForAnimation)
        containerView.addSubview(endingViewForAnimation)

        startingView.alpha = 0
        endingView.alpha = 0

        let fadeInDuration = transitionDuration(transitionContext) * animationDurationEndingViewFadeInRatio
        let fadeOutDuration = transitionDuration(transitionContext) * animationDurationStartingViewFadeOutRatio

        UIView.animateWithDuration(fadeInDuration, delay: 0, options: [.AllowAnimatedContent, .BeginFromCurrentState], animations: { 
            endingViewForAnimation.alpha = 1

        }, completion: { finished in
            UIView.animateWithDuration(fadeOutDuration, delay: 0, options: [.AllowAnimatedContent, .BeginFromCurrentState], animations: { 
                startingViewForAnimation.alpha = 0

            }, completion: { finished in
                startingViewForAnimation.removeFromSuperview()
            })
        })

        let startingViewFinalTransform = 1.0 / endingViewInitialTransform
        let translatedEndingViewFinalCenter = centerPointForView(endingView, translatedToContainerView: containerView)

        UIView.animateWithDuration(transitionDuration(transitionContext), delay: 0, usingSpringWithDamping: zoomingAnimationSpringDamping, initialSpringVelocity: 0, options: [.AllowAnimatedContent, .BeginFromCurrentState], animations: { 
            endingViewForAnimation.transform = finalEndingViewTransform
            endingViewForAnimation.center = translatedEndingViewFinalCenter
            startingViewForAnimation.transform = CGAffineTransformScale(startingViewForAnimation.transform, startingViewFinalTransform, startingViewFinalTransform)
            startingViewForAnimation.center = translatedEndingViewFinalCenter

        }, completion: { [unowned self] finished in
            endingViewForAnimation.removeFromSuperview()
            endingView.alpha = 1
            startingView.alpha = 1

            self.completeTransitionWithTransitionContext(transitionContext)
        })
    }

    private func newAnimationViewFromView(view: UIView) -> UIView {

        let animationView: UIView

        if view.layer.contents != nil {
            if let image = (view as? UIImageView)?.image {
                animationView = UIImageView(image: image)
                animationView.bounds = view.bounds
            } else {
                animationView = UIView()
                animationView.layer.contents = view.layer.contents
                animationView.layer.bounds = view.layer.bounds
            }

            animationView.layer.cornerRadius = view.layer.cornerRadius
            animationView.layer.masksToBounds = view.layer.masksToBounds
            animationView.contentMode = view.contentMode
            animationView.transform = view.transform

        } else {
            animationView = view.snapshotViewAfterScreenUpdates(true)
        }

        return animationView
    }

    private func centerPointForView(view: UIView, translatedToContainerView containerView: UIView) -> CGPoint {

        guard let superview = view.superview else {
            fatalError("No superview")
        }

        var centerPoint = view.center

        if let scrollView = superview as? UIScrollView {
            if scrollView.zoomScale != 1.0 {
                centerPoint.x += (scrollView.bounds.width - scrollView.contentSize.width) / 2 + scrollView.contentOffset.x
                centerPoint.y += (scrollView.bounds.height - scrollView.contentSize.height) / 2 + scrollView.contentOffset.y
            }
        }

        return superview.convertPoint(centerPoint, toView: containerView)
    }

    private func fadeDurationForTransitionContext(transitionContext: UIViewControllerContextTransitioning) -> NSTimeInterval {

        if shouldPerformZoomingAnimation {
            return transitionDuration(transitionContext) * animationDurationFadeRatio
        } else {
            return transitionDuration(transitionContext)
        }
    }

    private func completeTransitionWithTransitionContext(transitionContext: UIViewControllerContextTransitioning) {

        if transitionContext.isInteractive() {
            if transitionContext.transitionWasCancelled() {
                transitionContext.cancelInteractiveTransition()
            } else {
                transitionContext.finishInteractiveTransition()
            }
        }

        transitionContext.completeTransition(!transitionContext.transitionWasCancelled())
    }
}
