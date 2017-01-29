//
//  ViewController.swift
//  ElasticExamples
//
//  Created by Luke Zhao on 2017-01-20.
//  Copyright © 2017 lkzhao. All rights reserved.
//

import UIKit
import Elastic
import Hero

extension CGFloat {
  static var random:CGFloat {
    return CGFloat(arc4random()) / CGFloat(UInt32.max)
  }
}

extension UIColor {
  static var random: UIColor {
    return UIColor(red:   .random/2 + 0.5,
                   green: .random/2 + 0.5,
                   blue:  .random/2 + 0.5,
                   alpha: 1.0)
  }
}

class ViewController: UIViewController {

  @IBOutlet weak var label: UILabel!
  var leftGR:UIScreenEdgePanGestureRecognizer!
  var rightGR:UIScreenEdgePanGestureRecognizer!

  override func viewDidLoad() {
    super.viewDidLoad()
    ElasticHeroPlugin.enable()
    
    view.backgroundColor = .random
    
    rightGR = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(pan(gr:)))
    rightGR.edges = UIRectEdge.right
    view.addGestureRecognizer(rightGR)
    
    leftGR = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(pan(gr:)))
    leftGR.edges = UIRectEdge.left
    view.addGestureRecognizer(leftGR)
    
    label.heroModifiers = [.fade, .scale(0.5)]
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    let count = navigationController!.childViewControllers.count
    label.text = "\(count)"
    title = "\(count)"
  }
  
  func pan(gr:UIScreenEdgePanGestureRecognizer){
    if gr.edges == .right && gr.state == .began {
      performSegue(withIdentifier: "next", sender: nil)
    }
    if gr.edges == .left && gr.state == .began && navigationController!.viewControllers.count > 1 {
      view.heroModifiers = [.elastic(edge: .left, gestureRecognizer: leftGR)]
      let _ = navigationController?.popViewController(animated: true)
    }
  }

  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    let vc = segue.destination
    vc.view.heroModifiers = [.elastic(edge: .right, gestureRecognizer: rightGR)]
  }
}
