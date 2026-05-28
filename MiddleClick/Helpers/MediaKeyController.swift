import AppKit
import IOKit.hidsystem

enum MediaKeyController {
  static func playPause() {
    postAuxControlButton(key: NX_KEYTYPE_PLAY, state: NX_KEYDOWN)
    postAuxControlButton(key: NX_KEYTYPE_PLAY, state: NX_KEYUP)
  }

  private static func postAuxControlButton(key: Int32, state: Int32) {
    let data1 = (Int(key) << 16) | (Int(state) << 8)

    NSEvent.otherEvent(
      with: .systemDefined,
      location: .zero,
      modifierFlags: [],
      timestamp: 0,
      windowNumber: 0,
      context: nil,
      subtype: Int16(NX_SUBTYPE_AUX_CONTROL_BUTTONS),
      data1: data1,
      data2: -1
    )?.cgEvent?.post(tap: .cghidEventTap)
  }
}
