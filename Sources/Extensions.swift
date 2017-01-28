import UIKit

let π:CGFloat = CGFloat(M_PI)

@objc public enum Edge:Int{
  case top, bottom, left, right
  var opposite:Edge {
    switch self {
    case .left:
      return .right
    case .right:
      return .left
    case .bottom:
      return .top
    case .top:
      return .bottom
    }
  }
  public func toUIRectEdge() -> UIRectEdge{
    switch self {
    case .left:
      return .left
    case .right:
      return .right
    case .bottom:
      return .bottom
    case .top:
      return .top
    }
  }
}


extension UIView {
  func takeSnapshot() -> UIImage {
    UIGraphicsBeginImageContextWithOptions(frame.size, true, UIScreen.main.scale)
    drawHierarchy(in: CGRect(origin:.zero, size:frame.size) , afterScreenUpdates: true)
    let image = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return image!
  }
}
