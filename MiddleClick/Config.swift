import Foundation
import ConfigCore

final class Config: ConfigCore {
  required init() {
    Self.options.cacheAll = true
  }

  @UserDefault("fingers")
  var minimumFingers = 3

  @UserDefault var mediaPlayPauseFingers = 4

  @UserDefault var allowMoreFingers = false

  @UserDefault var maxDistanceDelta: Float = 0.05

  /// In milliseconds
  @UserDefault(transformGet: { $0 / 1000 })
  var maxTimeDelta = 300.0

  @UserDefault var tapToClick = SystemPermissions.getIsSystemTapToClickEnabled

  @UserDefault var ignoredAppBundles = Set<String>()

  func setMiddleClickFingers(_ fingers: Int) {
    let fingers = Self.normalizedGestureFingerCount(fingers)

    if fingers > 0 && mediaPlayPauseFingers == fingers {
      mediaPlayPauseFingers = 0
    }
    minimumFingers = fingers
  }

  func setMediaPlayPauseFingers(_ fingers: Int) {
    let fingers = Self.normalizedGestureFingerCount(fingers)

    if fingers > 0 && minimumFingers == fingers {
      minimumFingers = 0
    }
    mediaPlayPauseFingers = fingers
  }

  func normalizeGestureFingerCounts() {
    minimumFingers = Self.normalizedGestureFingerCount(minimumFingers)
    mediaPlayPauseFingers = Self.normalizedGestureFingerCount(mediaPlayPauseFingers)
  }

  func resolveGestureFingerConflicts() {
    normalizeGestureFingerCounts()

    guard minimumFingers > 0, minimumFingers == mediaPlayPauseFingers else { return }

    if UserDefaults.standard.object(forKey: "mediaPlayPauseFingers") == nil {
      mediaPlayPauseFingers = 0
    } else {
      minimumFingers = 0
    }
  }

  private static func normalizedGestureFingerCount(_ fingers: Int) -> Int {
    if fingers == 0 { return 0 }
    if fingers < 3 { return 0 }
    return min(fingers, 10)
  }
}
