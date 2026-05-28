import MoreTouchCore
import MultitouchSupport

@MainActor class TouchHandler {
  static let shared = TouchHandler()
  private static let config = Config.shared
  private init() {
    Self.config.$tapToClick.onSet {
      self.tapToClick = $0
    }
    Self.config.$minimumFingers.onSet {
      Self.middleClickFingers = $0
    }
    Self.config.$mediaPlayPauseFingers.onSet {
      Self.mediaPlayPauseFingers = $0
    }
  }

  /// stored locally, since accessing the cache is more CPU-expensive than a local variable
  private var tapToClick = config.tapToClick

  private static var middleClickFingers = config.minimumFingers
  private static var mediaPlayPauseFingers = config.mediaPlayPauseFingers
  private static let allowMoreFingers = config.allowMoreFingers
  private static let maxDistanceDelta = config.maxDistanceDelta
  private static let maxTimeDelta = config.maxTimeDelta

  private var maybeTapAction: TapAction?
  private var touchStartTime: Date?
  private static var lastEmulatedTapActionTime: Date?
  private var tapPos1: SIMD2<Float> = .zero
  private var tapPos2: SIMD2<Float> = .zero
  private var tapFingerCount: Int32 = 0

  private let touchCallback: MTFrameCallbackFunction = {
    _, data, nFingers, _, _ in
    guard !AppUtils.isIgnoredAppBundle() else { return }

    let state = GlobalState.shared

    state.threeDown = TouchHandler.isMiddleClickFingerCount(nFingers)

    let handler = TouchHandler.shared

    guard handler.tapToClick else { return }

    guard nFingers != 0 else {
      handler.handleTouchEnd()
      return
    }

    let isTouchStart = nFingers > 0 && handler.touchStartTime == nil
    if isTouchStart {
      handler.touchStartTime = Date()
      handler.maybeTapAction = nil
      handler.tapPos1 = .zero
      handler.tapPos2 = .zero
      handler.tapFingerCount = 0
    } else if handler.maybeTapAction != nil, let touchStartTime = handler.touchStartTime {
      // Timeout check for tap actions
      let elapsedTime = -touchStartTime.timeIntervalSinceNow
      if elapsedTime > maxTimeDelta {
        handler.resetTapAction()
      }
    }

    if handler.tapFingerCount > nFingers {
      return
    }
    if handler.maybeTapAction == .mediaPlayPause && handler.tapFingerCount != nFingers {
      return
    }

    guard let tapAction = TouchHandler.tapAction(for: nFingers) else {
      handler.resetTapAction()
      return
    }

    handler.processTouches(data: data, nFingers: nFingers, tapAction: tapAction)

    return
  }

  private func processTouches(data: UnsafePointer<MTTouch>?, nFingers: Int32, tapAction: TapAction) {
    guard let data = data else { return }

    let isNewTapAction = maybeTapAction != tapAction || tapFingerCount != nFingers
    maybeTapAction = tapAction
    tapFingerCount = nFingers

    if isNewTapAction {
      tapPos1 = .zero
    } else {
      tapPos2 = .zero
    }

    for touch in UnsafeBufferPointer(start: data, count: Int(nFingers)) {
      let pos = SIMD2(touch.normalizedVector.position)
      if isNewTapAction {
        tapPos1 += pos
      } else {
        tapPos2 += pos
      }
    }

    if nFingers > 0 {
      if isNewTapAction {
        tapPos1 /= Float(nFingers)
        tapPos2 = tapPos1
      } else {
        tapPos2 /= Float(nFingers)
      }
    }
  }

  private func resetTapAction() {
    maybeTapAction = nil
    tapPos1 = .zero
    tapPos2 = .zero
    tapFingerCount = 0
  }

  private func handleTouchEnd() {
    guard let startTime = touchStartTime else { return }

    let elapsedTime = -startTime.timeIntervalSinceNow
    touchStartTime = nil

    guard let tapAction = maybeTapAction else { return }
    maybeTapAction = nil

    guard tapPos1.isNonZero && elapsedTime <= Self.maxTimeDelta else { return }

    let delta = tapPos1.delta(to: tapPos2)
    if delta < Self.maxDistanceDelta && shouldEmulate(tapAction) {
      log.info("Emulating \(tapAction.name)")
      Self.emulate(tapAction)
    }
  }

  private func shouldEmulate(_ tapAction: TapAction) -> Bool {
    switch tapAction {
    case .middleClick:
      return !shouldPreventMiddleClickEmulation()
    case .mediaPlayPause:
      return true
    }
  }

  private static func emulate(_ tapAction: TapAction) {
    if let lastTime = lastEmulatedTapActionTime,
       -lastTime.timeIntervalSinceNow < maxTimeDelta * 0.3 {
      return
    }
    lastEmulatedTapActionTime = .init()

    switch tapAction {
    case .middleClick:
      emulateMiddleClick()
    case .mediaPlayPause:
      MediaKeyController.playPause()
    }
  }

  private static func emulateMiddleClick() {
    // get the current pointer location
    let location = CGEvent(source: nil)?.location ?? .zero
    let buttonType: CGMouseButton = .center

    postMouseEvent(type: .otherMouseDown, button: buttonType, location: location)
    postMouseEvent(type: .otherMouseUp, button: buttonType, location: location)
  }

  private func shouldPreventMiddleClickEmulation() -> Bool {
    guard let naturalLastTime = GlobalState.shared.naturalMiddleClickLastTime else { return false }

    let elapsedTimeSinceNatural = -naturalLastTime.timeIntervalSinceNow
    return elapsedTimeSinceNatural <= Self.maxTimeDelta * 0.75 // fine-tuned multiplier
  }

  private static func postMouseEvent(
    type: CGEventType, button: CGMouseButton, location: CGPoint
  ) {
    CGEvent(
      mouseEventSource: nil, mouseType: type, mouseCursorPosition: location,
      mouseButton: button
    )?.post(tap: .cghidEventTap)
  }

  private static func tapAction(for nFingers: Int32) -> TapAction? {
    if mediaPlayPauseFingers > 0 && nFingers == mediaPlayPauseFingers {
      return .mediaPlayPause
    }

    guard isMiddleClickFingerCount(nFingers) else { return nil }
    return .middleClick
  }

  private static func isMiddleClickFingerCount(_ nFingers: Int32) -> Bool {
    guard middleClickFingers > 0 else { return false }
    if mediaPlayPauseFingers > 0 && nFingers == mediaPlayPauseFingers {
      return false
    }

    return allowMoreFingers ? nFingers >= middleClickFingers : nFingers == middleClickFingers
  }

  private var currentDeviceList: [MTDevice] = []
  func registerTouchCallback() {
    currentDeviceList = MTDevice.createList()
    currentDeviceList.forEach { $0.registerAndStart(touchCallback) }
  }
  func unregisterTouchCallback() {
    currentDeviceList.forEach { $0.unregisterAndStop(touchCallback) }
    currentDeviceList.removeAll()
  }
}

private enum TapAction {
  case middleClick
  case mediaPlayPause

  var name: String {
    switch self {
    case .middleClick:
      return "middle click"
    case .mediaPlayPause:
      return "media play/pause"
    }
  }
}

extension SIMD2 where Scalar == Float {
  init(_ point: MTPoint) { self.init(point.x, point.y) }
}
extension SIMD2 where Scalar: FloatingPoint {
  func delta(to other: SIMD2) -> Scalar {
    return abs(x - other.x) + abs(y - other.y)
  }

  var isNonZero: Bool { x != 0 || y != 0 }
}
