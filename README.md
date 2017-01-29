
# Elastic

[![Carthage compatible](https://img.shields.io/badge/Carthage-Compatible-brightgreen.svg?style=flat)](https://github.com/Carthage/Carthage)
[![Version](https://img.shields.io/cocoapods/v/Elastic.svg?style=flat)](http://cocoapods.org/pods/Elastic)
[![License](https://img.shields.io/cocoapods/l/Elastic.svg?style=flat)](https://github.com/lkzhao/Elastic/blob/master/LICENSE?raw=true)
![Xcode 8.2+](https://img.shields.io/badge/Xcode-8.2%2B-blue.svg)
![iOS 8.0+](https://img.shields.io/badge/iOS-8.0%2B-blue.svg)
![Swift 3.0+](https://img.shields.io/badge/Swift-3.0%2B-orange.svg)

Fancy elastic transition powered by **Metal**, **UIKit Dynamics**, & **[Hero](https://github.com/lkzhao/Hero)**:

<a href="http://lkzhao.com/video/?path=%5Cpublic%5Cposts%5Chero%5CElastic.mov"><img src="https://github.com/lkzhao/Elastic/blob/master/Resources/elastic.png?raw=true" width="300"/></a>

A proof of concept inspired by [Álvaro Carreras's Slide Concept](https://dribbble.com/shots/899177-Slide-Concept). Not really optimized and does not support older devices.

Supports UINavigationController, UITabBarController, & Modal Present. Since it is powered by Hero, the other views can still benefit from animations constructed by Hero.

## Requirements
* Xcode 8.2
* Swift 3.0.2
* Metal compatible devices (iPhone 5s or newer)

Won't work on simulator.

## Installation
```ruby
pod "Elastic"
```

## Usage
```swift
  override func viewDidLoad() {
    super.viewDidLoad()
    // 1. Enable the plugin
    ElasticHeroPlugin.isEnabled = true
    
    // 2. setup a gesture recognizer
    let leftGR = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(pan(gr:)))
    leftGR.edges = UIRectEdge.left
    view.addGestureRecognizer(leftGR)
    
    // 3. set the heroModifier of the elastic view to be
    view.heroModifiers = [.elastic(edge: .left, gestureRecognizer: leftGR)]
  }
    
  func pan(gr:UIScreenEdgePanGestureRecognizer){
    if gr.state == .began {
      // 4. perform your transition when the gesture recognizer begans. the rest will be handled automatically
      performSegue(withIdentifier: "next", sender: nil)
    }
  }
```

The elastic view doesn't have to be the gesture recognizer's view. For example, the following code makes the next view controller's view elastic.

```swift
  // This replaces step 3
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    let vc = segue.destination
    vc.view.heroModifiers = [.elastic(edge: .right, gestureRecognizer: rightGR)]
  }
```


## License

Elastic is available under the MIT license. See the LICENSE file for more info.
