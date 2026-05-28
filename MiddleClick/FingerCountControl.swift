import AppKit

class FingerCountControl: NSView {
  private let label = NSTextField()
  private let segmentedControl = NSSegmentedControl()
  private let customField = NSTextField()
  private let title: String
  private let getValue: () -> Int
  private let setValue: (Int) -> Void

  private let quickOptions = [0, 3, 4]
  private let maxCustomFingers = 10

  var onValueChanged: ((Int) -> Void)?

  init(title: String, getValue: @escaping () -> Int, setValue: @escaping (Int) -> Void) {
    self.title = title
    self.getValue = getValue
    self.setValue = setValue

    super.init(frame: .zero)
    setupUI()
    updateLabel()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private func setupUI() {
    let viewHeight: CGFloat = 22
    let viewWidth: CGFloat = 280
    let leftPadding: CGFloat = 14
    let rightPadding: CGFloat = -8

    // Set view frame
    self.frame = NSRect(x: 0, y: 0, width: viewWidth, height: viewHeight)

    setupLabel()
    setupSegmentedControl()
    setupCustomField()

    NSLayoutConstraint.activate([
      segmentedControl.widthAnchor.constraint(equalToConstant: 88),
      customField.widthAnchor.constraint(equalToConstant: 38),

      // Label positioning
      label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leftPadding),
      label.centerYAnchor.constraint(equalTo: centerYAnchor),

      // Selector positioning
      customField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: rightPadding),
      customField.centerYAnchor.constraint(equalTo: centerYAnchor),

      segmentedControl.trailingAnchor.constraint(equalTo: customField.leadingAnchor, constant: -6),
      segmentedControl.centerYAnchor.constraint(equalTo: centerYAnchor),

      // Label doesn't overlap selector
      label.trailingAnchor.constraint(lessThanOrEqualTo: segmentedControl.leadingAnchor, constant: -8),
    ])
  }

  private func setupSegmentedControl() {
    segmentedControl.segmentCount = quickOptions.count

    for (index, fingers) in quickOptions.enumerated() {
      segmentedControl.setLabel(fingers == 0 ? "Off" : "\(fingers)", forSegment: index)
      segmentedControl.setWidth(fingers == 0 ? 40 : 24, forSegment: index)
    }

    segmentedControl.target = self
    segmentedControl.action = #selector(selectFingerCount)
    segmentedControl.segmentStyle = .roundRect
    segmentedControl.trackingMode = .selectOne
    segmentedControl.controlSize = .small
    segmentedControl.translatesAutoresizingMaskIntoConstraints = false
    segmentedControl.focusRingType = .none
    addSubview(segmentedControl)
  }

  private func setupCustomField() {
    customField.alignment = .center
    customField.font = .menuFont(ofSize: 0)
    customField.controlSize = .small
    customField.placeholderString = "5"
    customField.target = self
    customField.action = #selector(commitCustomFingerCount)
    customField.translatesAutoresizingMaskIntoConstraints = false
    customField.focusRingType = .none
    addSubview(customField)
  }

  private func setupLabel() {
    label.isEditable = false
    label.isBordered = false
    label.drawsBackground = false
    label.alignment = .left
    label.font = .menuFont(ofSize: 0)
    label.translatesAutoresizingMaskIntoConstraints = false
    addSubview(label)
  }

  private func updateLabel() {
    let fingers = getValue()
    label.stringValue = "\(title): \(displayValue(for: fingers))"
    segmentedControl.selectedSegment = quickOptions.firstIndex(of: fingers) ?? -1
    customField.stringValue = quickOptions.contains(fingers) ? "" : "\(fingers)"
  }

  private func displayValue(for fingers: Int) -> String {
    return fingers > 0 ? "\(fingers)" : "Off"
  }

  @objc private func selectFingerCount() {
    let selectedSegment = segmentedControl.selectedSegment
    guard quickOptions.indices.contains(selectedSegment) else { return }

    let newValue = quickOptions[selectedSegment]
    applyFingerCount(newValue)
  }

  @objc private func commitCustomFingerCount() {
    guard let newValue = Int(customField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) else {
      updateLabel()
      return
    }

    applyFingerCount(min(newValue, maxCustomFingers))
  }

  private func applyFingerCount(_ newValue: Int) {
    guard newValue != getValue() else { return }

    setValue(newValue)
    updateLabel()
    onValueChanged?(newValue)
  }

  func refresh() {
    updateLabel()
  }
}
