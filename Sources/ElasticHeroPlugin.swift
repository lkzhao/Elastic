// The MIT License (MIT)
//
// Copyright (c) 2016 Luke Zhao <me@lkzhao.com>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit
import Hero

class DynamicItem:NSObject, UIDynamicItem{
  var center: CGPoint = CGPoint.zero{
    didSet{
      onNewValue?(center)
    }
  }
  var onNewValue: ((CGPoint) -> Void)?
  var bounds: CGRect{
    return CGRect(x: center.x-1, y: center.y-1, width: 2, height: 2)
  }
  var transform = CGAffineTransform.identity
}

extension HeroModifier {
  public static func elastic(edge:Edge, gestureRecognizer:UIPanGestureRecognizer) -> HeroModifier {
    return HeroModifier { targetState in
      var dictionary = targetState["elastic"] as? [Edge:UIPanGestureRecognizer] ?? [Edge:UIPanGestureRecognizer]()
      dictionary[edge] = gestureRecognizer
      targetState["elastic"] = dictionary
    }
  }
}

public class ElasticHeroPlugin: HeroPlugin {
  var elasticView: ElasticShapeView!
  var dragItem = DynamicItem()
  var shiftItem = DynamicItem()
  var animator: UIDynamicAnimator!
  var collisionBehavior: UICollisionBehavior!
  var dragResistanceBehavior: UIDynamicItemBehavior!
  var shiftResistanceBehavior: UIDynamicItemBehavior!
  var dragAttachmentBehavior: UIAttachmentBehavior!
  var shiftAttachmentBehavior: UIAttachmentBehavior!
  
  var view:UIView?
  var edge:Edge = .left
  var gestureRecognizer:UIPanGestureRecognizer!
  var appearing = false
  var touchLocation:CGPoint {
    return gestureRecognizer.location(in: elasticView)
  }
  var bounds:CGRect{
    return context.container.bounds
  }

  public override func canAnimate(view: UIView, appearing: Bool) -> Bool {
    if self.view != nil {
      // we can only animate one view
      return false
    }
    if let gestureRecognizers = context[view]?["elastic"] as? [Edge:UIPanGestureRecognizer]{
      for (edge, gestureRecognizer) in gestureRecognizers {
        if gestureRecognizer.state == .began || gestureRecognizer.state == .changed {
          self.view = view
          self.edge = appearing ? edge.opposite : edge
          self.appearing = appearing
          self.gestureRecognizer = gestureRecognizer
          return true
        }
      }
    }
    return false
  }
  
  public override func animate(fromViews: [UIView], toViews: [UIView]) -> TimeInterval {
    guard let view = fromViews.first ?? toViews.first else { return 0 }
    elasticView = ElasticShapeView(frame:view.frame)
    context.container.addSubview(elasticView)
    context.unhide(view: view)
    elasticView.setUpTexture(view:view)
    context.hide(view: view)
    elasticView.layer.shadowColor = UIColor.black.cgColor
    elasticView.layer.shadowRadius = 5
    elasticView.layer.shadowOffset = CGSize(width: 0, height: 0)
    elasticView.layer.shadowOpacity = 0.3
    elasticView.layer.masksToBounds = false
    
    dragItem.center = target(for: touchLocation, finished: false)
    shiftItem.center = target(for: touchLocation, finished: false)
    shiftItem.onNewValue = { [unowned self] _ in
      self.update()
    }

    elasticView.shift = shiftItem.center - closedTarget(for: shiftItem.center)
    elasticView.edge = edge
    elasticView.touchPosition = touchLocation
    
    animator = UIDynamicAnimator(referenceView: context.container)
    
    collisionBehavior = UICollisionBehavior(items: [shiftItem, dragItem])
    collisionBehavior.translatesReferenceBoundsIntoBoundary = true
    collisionBehavior.collisionMode = .boundaries
    animator.addBehavior(collisionBehavior)
    
    dragResistanceBehavior = UIDynamicItemBehavior(items: [dragItem])
    dragResistanceBehavior.resistance = 30.0
    dragResistanceBehavior.elasticity = 0
    animator.addBehavior(dragResistanceBehavior)
    
    shiftResistanceBehavior = UIDynamicItemBehavior(items: [shiftItem])
    shiftResistanceBehavior.resistance = 6.0
    shiftResistanceBehavior.elasticity = 0
    animator.addBehavior(shiftResistanceBehavior)
    
    dragAttachmentBehavior = UIAttachmentBehavior(item: dragItem, attachedToAnchor: touchLocation)
    dragAttachmentBehavior.length = 0
    dragAttachmentBehavior.frequency = 10.0
    dragAttachmentBehavior.damping = 1.0
    animator.addBehavior(dragAttachmentBehavior)
    
    shiftAttachmentBehavior = UIAttachmentBehavior(item: shiftItem, attachedTo: dragItem)
    shiftAttachmentBehavior.damping = 0.4
    shiftAttachmentBehavior.frequency = 1.5
    shiftAttachmentBehavior.length = 50
    animator.addBehavior(shiftAttachmentBehavior)

    self.gestureRecognizer.addTarget(self, action: #selector(pan))
    
    return .infinity
  }
  
  var ending = false
  func update(){
    if ending && !bounds.contains(shiftItem.center) && !bounds.contains(dragItem.center) {
      let p = shiftItem.center
      if p.distance(target(for: p, finished: true)) < p.distance(target(for: p, finished: false)) {
        Hero.shared.end()
      } else {
        Hero.shared.cancel()
      }
      shiftItem.onNewValue = nil
      return
    }
    let current = shiftItem.center.clamp(bounds)
    let closed = closedTarget(for: current)
    let opened = openedTarget(for: current)
    let initial = target(for: current, finished: false)
    let final = target(for: current, finished: true)

    elasticView.touchPosition = dragItem.center.clamp(bounds)
    elasticView.shift = current - closed

    let overlayProgress:CGFloat = current.distance(opened) / closed.distance(opened)
    elasticView.overlayColor = UIColor.clear.withAlphaComponent(0.08 * overlayProgress)
    elasticView.layer.shadowOpacity = 0.1 + 0.2 * Float(overlayProgress)

    let progress:CGFloat = current.distance(initial) / final.distance(initial)
    Hero.shared.update(progress: Double(progress))
  }
  
  public func pan(){
    switch gestureRecognizer.state{
    case .changed:
      dragAttachmentBehavior.anchorPoint = touchLocation
    default:
      gestureRecognizer!.removeTarget(self, action: #selector(pan))
      animator.removeBehavior(dragAttachmentBehavior)
      animator.removeBehavior(collisionBehavior)
      shiftAttachmentBehavior.length = 0
      dragResistanceBehavior.resistance = 0
      shiftResistanceBehavior.resistance = 0

      ending = true

      let field = UIGravityBehavior(items: [dragItem, shiftItem])

      var velocity = gestureRecognizer!.velocity(in: nil)
      if velocity.distance(.zero) < 100 {
        velocity = touchLocation - bounds.center
      }
      switch edge{
      case .left, .right:
        field.gravityDirection = CGVector(dx: velocity.x > 0 ? 1 : -1, dy: 0)
      default:
        field.gravityDirection = CGVector(dx: 0, dy: velocity.y > 0 ? 1 : -1)
      }
      
      animator.addBehavior(field)
    }
  }
  
  public override func clean() {
    animator.removeAllBehaviors()
    animator = nil
    elasticView?.removeFromSuperview()
    elasticView = nil
    gestureRecognizer = nil
  }

  func closedTarget(for touchLocation:CGPoint) -> CGPoint {
    return openedTarget(for: touchLocation, with: self.edge.opposite)
  }
  func openedTarget(for touchLocation:CGPoint, with edge:Edge? = nil) -> CGPoint {
    let edge = edge ?? self.edge
    switch edge {
    case .left, .right:
      return CGPoint(x: (edge == .left) ? bounds.maxX : bounds.minX, y: touchLocation.y)
    case .top, .bottom:
      return CGPoint(x: touchLocation.x, y: (edge == .bottom) ? bounds.minY : bounds.maxY)
    }
  }
  func target(for touchLocation:CGPoint, finished:Bool) -> CGPoint {
    if appearing == finished {
      return closedTarget(for: touchLocation)
    } else {
      return openedTarget(for: touchLocation)
    }
  }
}
