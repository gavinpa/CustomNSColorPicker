import Cocoa

@objc(ColorPickerFixer_ColorPickerFixer)
public class ColorPickerFixer: NSColorPicker, NSColorPickingCustom {

    private var PickerView: ColorPickerFixerView!
    private var IsUpdatingFromExternal = false

    // MARK: - NSColorPickingCustom

    public required init?(pickerMask Mask: Int, colorPanel OwningColorPanel: NSColorPanel) {
        super.init(pickerMask: Mask, colorPanel: OwningColorPanel)
    }

    public func supportsMode(_ Mode: NSColorPanel.Mode) -> Bool {
        return true
    }

    public func currentMode() -> NSColorPanel.Mode {
        return .wheel
    }

    public func provideNewView(_ InitialRequest: Bool) -> NSView {
        if PickerView == nil {
            PickerView = ColorPickerFixerView(frame: NSRect(x: 0, y: 0, width: 280, height: 400))
            PickerView.OnColorChanged = { [weak self] Color in
                guard let StrongSelf = self, !StrongSelf.IsUpdatingFromExternal else { return }
                StrongSelf.colorPanel.color = Color
            }
        }
        return PickerView
    }

    public func setColor(_ NewColor: NSColor) {
        IsUpdatingFromExternal = true
        PickerView?.SetColor(NewColor)
        IsUpdatingFromExternal = false
    }

    public override func insertNewButtonImage(_ NewButtonImage: NSImage, in ButtonCell: NSButtonCell) {
        let Size = NSSize(width: 24, height: 24)
        let Image = NSImage(size: Size, flipped: false) { Rect in
            let Center = NSPoint(x: Rect.midX, y: Rect.midY)
            let Radius = min(Rect.width, Rect.height) / 2.0 - 2.0
            let Steps = 36
            for I in 0..<Steps {
                let StartAngle = CGFloat(I) / CGFloat(Steps) * 360.0
                let EndAngle = CGFloat(I + 1) / CGFloat(Steps) * 360.0
                let Hue = CGFloat(I) / CGFloat(Steps)
                NSColor(hue: Hue, saturation: 0.9, brightness: 0.9, alpha: 1.0).setFill()
                let Path = NSBezierPath()
                Path.move(to: Center)
                Path.appendArc(withCenter: Center, radius: Radius,
                              startAngle: StartAngle, endAngle: EndAngle, clockwise: false)
                Path.close()
                Path.fill()
            }
            NSColor.white.setFill()
            let InnerRect = NSRect(x: Center.x - Radius * 0.3, y: Center.y - Radius * 0.3,
                                   width: Radius * 0.6, height: Radius * 0.6)
            NSBezierPath(ovalIn: InnerRect).fill()
            return true
        }
        ButtonCell.image = Image
    }

    public override var minContentSize: NSSize {
        return NSSize(width: 280, height: 320)
    }

    public override func viewSizeChanged(_ sender: Any?) {}

    public override var buttonToolTip: String {
        return "Gavins Color Picker"
    }
}

// MARK: - Main Picker View

class ColorPickerFixerView: NSView {

    var OnColorChanged: ((NSColor) -> Void)?

    private var CurrentHue: CGFloat = 0.0
    private var CurrentSaturation: CGFloat = 1.0
    private var CurrentBrightness: CGFloat = 1.0
    private var CurrentAlpha: CGFloat = 1.0

    private var WheelView: ColorWheelView!
    private var BrightnessSlider: NSSlider!
    private var HexField: NSTextField!
    private var PreviewWell: NSView!

    private var RedSlider: LabeledSlider!
    private var GreenSlider: LabeledSlider!
    private var BlueSlider: LabeledSlider!

    private var SliderContainer: NSView!
    private var IsUpdating = false

    // Auto Layout constraint for keeping the wheel square
    private var WheelHeightConstraint: NSLayoutConstraint!
    
    override var intrinsicContentSize: NSSize {
        NSSize(width: 280, height: 320)
    }
    
    func fittingSize() -> NSSize {
        intrinsicContentSize
    }

    override init(frame FrameRect: NSRect) {
        super.init(frame: FrameRect)
        SetupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        SetupUI()
    }

    private func SetupUI() {
        wantsLayer = true

        let Margin: CGFloat = 14
        let SliderColumnWidth: CGFloat = 24
        let SliderGap: CGFloat = 8

        // ---- Color Wheel ----
        WheelView = ColorWheelView()
        WheelView.translatesAutoresizingMaskIntoConstraints = false
        WheelView.OnColorPicked = { [weak self] Hue, Saturation in
            guard let StrongSelf = self, !StrongSelf.IsUpdating else { return }
            StrongSelf.CurrentHue = Hue
            StrongSelf.CurrentSaturation = Saturation
            StrongSelf.SyncFromHSB()
        }
        addSubview(WheelView)

        // ---- Brightness Slider ----
        BrightnessSlider = NSSlider()
        BrightnessSlider.translatesAutoresizingMaskIntoConstraints = false
        BrightnessSlider.sliderType = .linear
        BrightnessSlider.isVertical = true
        BrightnessSlider.minValue = 0
        BrightnessSlider.maxValue = 1
        BrightnessSlider.doubleValue = 1
        BrightnessSlider.target = self
        BrightnessSlider.action = #selector(BrightnessChanged(_:))
        BrightnessSlider.isContinuous = true
        addSubview(BrightnessSlider)

        // ---- Preview Well ----
        PreviewWell = NSView()
        PreviewWell.translatesAutoresizingMaskIntoConstraints = false
        PreviewWell.wantsLayer = true
        PreviewWell.layer?.cornerRadius = 8
        PreviewWell.layer?.borderWidth = 2
        PreviewWell.layer?.borderColor = NSColor.shadowColor.withAlphaComponent(0.5).cgColor
        addSubview(PreviewWell)

        // ---- Hex Label ----
        let HashLabel = NSTextField(labelWithString: "#")
        HashLabel.translatesAutoresizingMaskIntoConstraints = false
        HashLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        HashLabel.textColor = .secondaryLabelColor
        addSubview(HashLabel)

        // ---- Hex Field ----
        HexField = NSTextField()
        HexField.translatesAutoresizingMaskIntoConstraints = false
        HexField.focusRingType = .exterior
        HexField.font = NSFont.systemFont(ofSize: 12)
        HexField.placeholderString = "FF0000"
        HexField.alignment = .left
        HexField.bezelStyle = .roundedBezel
        HexField.target = self
        HexField.action = #selector(HexFieldChanged(_:))
        addSubview(HexField)

        // ---- Slider Container ----
        SliderContainer = NSView()
        SliderContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(SliderContainer)

        RedSlider = LabeledSlider(LabelText: "R", MaxValue: 255)
        GreenSlider = LabeledSlider(LabelText: "G", MaxValue: 255)
        BlueSlider = LabeledSlider(LabelText: "B", MaxValue: 255)

        for Slider in [RedSlider!, GreenSlider!, BlueSlider!] {
            Slider.translatesAutoresizingMaskIntoConstraints = false
            Slider.OnValueChanged = { [weak self] _ in
                self?.SlidersChanged()
            }
            SliderContainer.addSubview(Slider)
        }

        // ============================================================
        // Auto Layout Constraints
        // ============================================================

        // Wheel: pinned to top, leading, with trailing space for brightness slider
        NSLayoutConstraint.activate([
            WheelView.topAnchor.constraint(equalTo: topAnchor, constant: Margin),
            WheelView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Margin),
            WheelView.trailingAnchor.constraint(equalTo: BrightnessSlider.leadingAnchor, constant: -SliderGap),
        ])
        // Keep wheel square (height = width)
        WheelHeightConstraint = WheelView.heightAnchor.constraint(equalTo: WheelView.widthAnchor)
        WheelHeightConstraint.priority = .defaultHigh
        WheelHeightConstraint.isActive = true
        
        WheelView.heightAnchor.constraint(lessThanOrEqualToConstant: 220).isActive = true

        // Brightness slider: right edge, aligned to wheel top/bottom
        NSLayoutConstraint.activate([
            BrightnessSlider.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Margin),
            BrightnessSlider.topAnchor.constraint(equalTo: WheelView.topAnchor),
            BrightnessSlider.bottomAnchor.constraint(equalTo: WheelView.bottomAnchor),
            BrightnessSlider.widthAnchor.constraint(equalToConstant: SliderColumnWidth),
        ])

        // Preview well: below wheel row
        NSLayoutConstraint.activate([
            PreviewWell.topAnchor.constraint(equalTo: WheelView.bottomAnchor, constant: 10),
            PreviewWell.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Margin),
            PreviewWell.widthAnchor.constraint(equalToConstant: 46),
            PreviewWell.heightAnchor.constraint(equalToConstant: 28),
        ])

        // Hash label: vertically centered with preview well
        NSLayoutConstraint.activate([
            HashLabel.centerYAnchor.constraint(equalTo: PreviewWell.centerYAnchor),
            HashLabel.leadingAnchor.constraint(equalTo: PreviewWell.trailingAnchor, constant: 10),
        ])

        // Hex field: right of hash, fills remaining width
        NSLayoutConstraint.activate([
            HexField.centerYAnchor.constraint(equalTo: PreviewWell.centerYAnchor),
            HexField.leadingAnchor.constraint(equalTo: HashLabel.trailingAnchor, constant: 2),
            HexField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Margin),
            HexField.heightAnchor.constraint(equalToConstant: 24),
        ])

        // Slider container: below mode selector, fills width
        let SliderRowHeight: CGFloat = 20
        NSLayoutConstraint.activate([
            SliderContainer.topAnchor.constraint(equalTo: HexField.bottomAnchor, constant: 8),
            SliderContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: Margin),
            SliderContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Margin),
            SliderContainer.heightAnchor.constraint(equalToConstant: SliderRowHeight * 3 + 4),
            SliderContainer.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -Margin),
        ])

        // Individual sliders inside the container: stack vertically, fill width
        NSLayoutConstraint.activate([
            RedSlider.topAnchor.constraint(equalTo: SliderContainer.topAnchor),
            RedSlider.leadingAnchor.constraint(equalTo: SliderContainer.leadingAnchor),
            RedSlider.trailingAnchor.constraint(equalTo: SliderContainer.trailingAnchor),
            RedSlider.heightAnchor.constraint(equalToConstant: SliderRowHeight),

            GreenSlider.topAnchor.constraint(equalTo: RedSlider.bottomAnchor, constant: 2),
            GreenSlider.leadingAnchor.constraint(equalTo: SliderContainer.leadingAnchor),
            GreenSlider.trailingAnchor.constraint(equalTo: SliderContainer.trailingAnchor),
            GreenSlider.heightAnchor.constraint(equalToConstant: SliderRowHeight),

            BlueSlider.topAnchor.constraint(equalTo: GreenSlider.bottomAnchor, constant: 2),
            BlueSlider.leadingAnchor.constraint(equalTo: SliderContainer.leadingAnchor),
            BlueSlider.trailingAnchor.constraint(equalTo: SliderContainer.trailingAnchor),
            BlueSlider.heightAnchor.constraint(equalToConstant: SliderRowHeight),
        ])
        
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)

        // Initial sync
        SyncFromHSB()
    }

    // MARK: - Color Sync

    func SetColor(_ Color: NSColor) {
        guard let Converted = Color.usingColorSpace(.sRGB) else { return }
        IsUpdating = true
        CurrentHue = Converted.hueComponent
        CurrentSaturation = Converted.saturationComponent
        CurrentBrightness = Converted.brightnessComponent
        CurrentAlpha = Converted.alphaComponent
        UpdateAllControls()
        IsUpdating = false
    }

    private func SyncFromHSB() {
        IsUpdating = true
        UpdateAllControls()
        IsUpdating = false

        let Color = NSColor(hue: CurrentHue, saturation: CurrentSaturation,
                           brightness: CurrentBrightness, alpha: CurrentAlpha)
        OnColorChanged?(Color)
    }

    private func UpdateAllControls() {
        let Color = NSColor(hue: CurrentHue, saturation: CurrentSaturation,
                           brightness: CurrentBrightness, alpha: CurrentAlpha)

        WheelView.SetHueSaturation(CurrentHue, CurrentSaturation)
        BrightnessSlider.doubleValue = Double(CurrentBrightness)
        PreviewWell.layer?.backgroundColor = Color.cgColor
        PreviewWell.layer?.borderColor = Color.highlight(withLevel: 0.5)?.cgColor

        guard let Rgb = Color.usingColorSpace(.sRGB) else { return }
        let R = To255(Rgb.redComponent)
        let G = To255(Rgb.greenComponent)
        let B = To255(Rgb.blueComponent)
        HexField.stringValue = String(format: "%02X%02X%02X", R, G, B)

        RedSlider.SetValue(CGFloat(R))
        GreenSlider.SetValue(CGFloat(G))
        BlueSlider.SetValue(CGFloat(B))
    }

    // MARK: - Actions

    @objc private func BrightnessChanged(_ Sender: NSSlider) {
        guard !IsUpdating else { return }
        CurrentBrightness = CGFloat(Sender.doubleValue)
        SyncFromHSB()
    }

    @objc private func HexFieldChanged(_ Sender: NSTextField) {
        guard !IsUpdating else { return }
        let Hex = Sender.stringValue.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard Hex.count == 6, let HexInt = UInt64(Hex, radix: 16) else { return }

        let R = CGFloat((HexInt >> 16) & 0xFF) / 255.0
        let G = CGFloat((HexInt >> 8) & 0xFF) / 255.0
        let B = CGFloat(HexInt & 0xFF) / 255.0

        let Color = NSColor(srgbRed: R, green: G, blue: B, alpha: CurrentAlpha)
        CurrentHue = Color.hueComponent
        CurrentSaturation = Color.saturationComponent
        CurrentBrightness = Color.brightnessComponent
        SyncFromHSB()
    }

    @objc private func CopyHex(_ Sender: Any) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("#" + HexField.stringValue, forType: .string)
    }

    @objc private func PasteHex(_ Sender: Any) {
        guard let Pasted = NSPasteboard.general.string(forType: .string) else { return }
        let Cleaned = Pasted.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        if Cleaned.count == 6 {
            HexField.stringValue = Cleaned.uppercased()
            HexFieldChanged(HexField)
        }
    }

    @objc private func ModeChanged(_ Sender: NSSegmentedControl) {
        RedSlider.SetLabel("R"); RedSlider.SetMaxValue(255)
        GreenSlider.SetLabel("G"); GreenSlider.SetMaxValue(255)
        BlueSlider.SetLabel("B"); BlueSlider.SetMaxValue(255)
        IsUpdating = true
        UpdateAllControls()
        IsUpdating = false
    }

    private func SlidersChanged() {
        guard !IsUpdating else { return }
        let R = RedSlider.GetValue() / 255.0
        let G = GreenSlider.GetValue() / 255.0
        let B = BlueSlider.GetValue() / 255.0
        let Color = NSColor(srgbRed: R, green: G, blue: B, alpha: CurrentAlpha)
        CurrentHue = Color.hueComponent
        CurrentSaturation = Color.saturationComponent
        CurrentBrightness = Color.brightnessComponent
        SyncFromHSB()
    }
}

// MARK: - Color Wheel View

final class ColorWheelView: NSView {

    var OnColorPicked: ((_ Hue: CGFloat, _ Saturation: CGFloat) -> Void)?

    private var WheelCGImage: CGImage?
    private var RenderedSize: CGSize = .zero
    private var RenderedScale: CGFloat = 0

    private var SelectedHue: CGFloat = 0
    private var SelectedSaturation: CGFloat = 1
    private var IsDragging = false

    override init(frame FrameRect: NSRect) {
        super.init(frame: FrameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    func SetHueSaturation(_ Hue: CGFloat, _ Saturation: CGFloat) {
        SelectedHue = Hue
        SelectedSaturation = Saturation
        needsDisplay = true
    }

    // Always draw inside a centered square
    private var wheelRect: CGRect {
        let d = min(bounds.width, bounds.height)
        return CGRect(
            x: bounds.midX - d * 0.5,
            y: bounds.midY - d * 0.5,
            width: d,
            height: d
        )
    }

    override func layout() {
        super.layout()
        RenderWheelIfNeeded(force: true)
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        RenderWheelIfNeeded(force: true)
        needsDisplay = true
    }

    private func RenderWheelIfNeeded(force: Bool = false) {
        let size = wheelRect.size
        guard size.width > 2, size.height > 2 else { return }

        let scale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2.0

        if !force, RenderedSize == size, RenderedScale == scale, WheelCGImage != nil {
            return
        }

        RenderedSize = size
        RenderedScale = scale
        WheelCGImage = RenderWheelCGImage(size: size, scale: scale)
    }

    private func RenderWheelCGImage(size: CGSize, scale: CGFloat) -> CGImage? {
        let W = max(1, Int((size.width * scale).rounded()))
        let H = max(1, Int((size.height * scale).rounded()))

        let bytesPerPixel = 4
        let bytesPerRow = W * bytesPerPixel
        let bitsPerComponent = 8
        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

        guard let ctx = CGContext(
            data: nil,
            width: W,
            height: H,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        guard let data = ctx.data else { return nil }
        let ptr = data.bindMemory(to: UInt8.self, capacity: H * bytesPerRow)

        let cx = CGFloat(W - 1) * 0.5
        let cy = CGFloat(H - 1) * 0.5
        let radius = min(CGFloat(W), CGFloat(H)) * 0.5

        for y in 0..<H {
            for x in 0..<W {
                let fx = CGFloat(x) - cx
                let fy = cy - CGFloat(y) // pixel space Y flip so it matches view space
                let dist = sqrt(fx * fx + fy * fy)

                let idx = y * bytesPerRow + x * bytesPerPixel

                if dist > radius {
                    ptr[idx + 0] = 0
                    ptr[idx + 1] = 0
                    ptr[idx + 2] = 0
                    ptr[idx + 3] = 0
                    continue
                }

                var angle = atan2(fy, fx)
                if angle < 0 { angle += 2.0 * .pi }

                let hue = angle / (2.0 * .pi)
                let sat = min(dist / radius, 1.0)

                let (r, g, b) = HsvToRgb(H: hue, S: sat, V: 1.0)

                ptr[idx + 0] = UInt8((r * 255.0).rounded())
                ptr[idx + 1] = UInt8((g * 255.0).rounded())
                ptr[idx + 2] = UInt8((b * 255.0).rounded())
                ptr[idx + 3] = 255
            }
        }

        return ctx.makeImage()
    }

    private func HsvToRgb(H: CGFloat, S: CGFloat, V: CGFloat) -> (CGFloat, CGFloat, CGFloat) {
        if S <= 0 { return (V, V, V) }

        let hh = (H * 6.0).truncatingRemainder(dividingBy: 6.0)
        let i = Int(hh)
        let f = hh - CGFloat(i)

        let p = V * (1.0 - S)
        let q = V * (1.0 - S * f)
        let t = V * (1.0 - S * (1.0 - f))

        switch i {
        case 0: return (V, t, p)
        case 1: return (q, V, p)
        case 2: return (p, V, t)
        case 3: return (p, q, V)
        case 4: return (t, p, V)
        default: return (V, p, q)
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        RenderWheelIfNeeded()

        let r = wheelRect

        if let cg = WheelCGImage, let ctx = NSGraphicsContext.current?.cgContext {
            ctx.saveGState()
            ctx.interpolationQuality = .high
            ctx.draw(cg, in: r)
            ctx.restoreGState()
        }

        // border uses wheelRect, not bounds
        NSColor.separatorColor.setStroke()
        let border = NSBezierPath(ovalIn: r.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()

        // selection indicator uses wheelRect center/radius
        let center = NSPoint(x: r.midX, y: r.midY)
        let radius = min(r.width, r.height) * 0.5
        let angle = SelectedHue * 2.0 * .pi
        let dist = SelectedSaturation * radius

        let selX = center.x + cos(angle) * dist
        let selY = center.y + sin(angle) * dist
        let indicatorRect = NSRect(x: selX - 6, y: selY - 6, width: 12, height: 12)

        NSColor.white.setStroke()
        let indicator = NSBezierPath(ovalIn: indicatorRect)
        indicator.lineWidth = 2
        indicator.stroke()

        NSColor.black.setStroke()
        let inner = NSBezierPath(ovalIn: indicatorRect.insetBy(dx: 1, dy: 1))
        inner.lineWidth = 1
        inner.stroke()
    }

    override func mouseDown(with event: NSEvent) { IsDragging = true; HandleMouse(event) }
    override func mouseDragged(with event: NSEvent) { if IsDragging { HandleMouse(event) } }
    override func mouseUp(with event: NSEvent) { IsDragging = false }

    private func HandleMouse(_ event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let r = wheelRect

        let center = NSPoint(x: r.midX, y: r.midY)
        let radius = min(r.width, r.height) * 0.5

        let dx = p.x - center.x
        let dy = p.y - center.y
        let distance = sqrt(dx * dx + dy * dy)

        var angle = atan2(dy, dx)
        if angle < 0 { angle += 2.0 * .pi }

        SelectedHue = angle / (2.0 * .pi)
        SelectedSaturation = min(distance / radius, 1.0)

        needsDisplay = true
        OnColorPicked?(SelectedHue, SelectedSaturation)
    }
}

@inline(__always)
private func To255(_ C01: CGFloat) -> Int {
    Int((C01 * 255.0).rounded())
}

// MARK: - Labeled Slider

final class LabeledSlider: NSView {

    var OnValueChanged: ((CGFloat) -> Void)?

    private var LabelField: NSTextField!
    private var SliderControl: NSSlider!
    private var ValueField: NSTextField!

    private var MaxVal: Int = 255
    private var IsSyncingUI = false
    private var CurrentIntValue: Int = 0

    private var LastUserSetValue: Int?
    private var LastUserSetTimestamp: CFTimeInterval = 0

    private let LabelWidth: CGFloat = 16
    private let ValueFieldWidth: CGFloat = 36
    private let InternalPadding: CGFloat = 4

    private func MarkUserSet(_ V: Int) {
        LastUserSetValue = V
        LastUserSetTimestamp = CACurrentMediaTime()
    }

    private func ShouldIgnoreExternal(_ V: Int) -> Bool {
        guard let Last = LastUserSetValue else { return false }
        let Dt = CACurrentMediaTime() - LastUserSetTimestamp
        return Dt < 0.25 && V == Last - 1
    }

    convenience init(LabelText: String, MaxValue: CGFloat) {
        self.init(frame: .zero)
        self.MaxVal = max(0, Int(MaxValue.rounded()))

        LabelField = NSTextField(labelWithString: LabelText)
        LabelField.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        LabelField.textColor = .secondaryLabelColor
        addSubview(LabelField)

        SliderControl = NSSlider()
        SliderControl.sliderType = .linear
        SliderControl.minValue = 0
        SliderControl.maxValue = Double(self.MaxVal)
        SliderControl.isContinuous = true
        SliderControl.target = self
        SliderControl.action = #selector(SliderMoved(_:))
        SliderControl.numberOfTickMarks = MaxVal + 1
        SliderControl.allowsTickMarkValuesOnly = true
        SliderControl.integerValue = 0
        SliderControl.numberOfTickMarks = 0
        addSubview(SliderControl)

        ValueField = NSTextField()
        ValueField.isEditable = true
        ValueField.isBordered = true
        ValueField.drawsBackground = true
        ValueField.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        ValueField.textColor = .secondaryLabelColor
        ValueField.alignment = .right
        ValueField.stringValue = "0"
        ValueField.target = self
        ValueField.action = #selector(ValueEdited(_:))

        let Fmt = NumberFormatter()
        Fmt.numberStyle = .none
        Fmt.allowsFloats = false
        Fmt.minimum = 0
        Fmt.maximum = NSNumber(value: self.MaxVal)
        ValueField.formatter = Fmt

        addSubview(ValueField)

        ApplyValue(0, SendCallback: false)
    }

    // Lay out children based on current bounds
    override func layout() {
        super.layout()

        let B = bounds
        let H = B.height

        LabelField?.frame = NSRect(x: 0, y: 0, width: LabelWidth, height: H)

        let SliderX = LabelWidth + InternalPadding
        let SliderW = B.width - LabelWidth - ValueFieldWidth - InternalPadding * 2
        SliderControl?.frame = NSRect(x: SliderX, y: 0, width: max(SliderW, 20), height: H)

        ValueField?.frame = NSRect(x: B.width - ValueFieldWidth, y: 0, width: ValueFieldWidth, height: H)
    }

    func SetLabel(_ Text: String) {
        LabelField.stringValue = Text
    }

    func SetMaxValue(_ Max: CGFloat) {
        MaxVal = max(0, Int(Max.rounded()))
        SliderControl.maxValue = Double(MaxVal)
        ApplyValue(CurrentIntValue, SendCallback: false)
    }

    func GetValue() -> CGFloat {
        CGFloat(CurrentIntValue)
    }

    func SetValue(_ Value: CGFloat) {
        let Clamped = max(0, min(Value, CGFloat(MaxVal)))
        let Snapped = Int((Clamped + 1e-6).rounded())
        ApplyValue(Snapped, SendCallback: false)
    }

    // MARK: - Internal Single Source of Truth

    private func ApplyValue(_ NewValue: Int, SendCallback: Bool) {
        let Clamped = max(0, min(NewValue, MaxVal))
        if !SendCallback && ShouldIgnoreExternal(Clamped) {
            return
        }

        guard Clamped != CurrentIntValue else { return }

        CurrentIntValue = Clamped

        IsSyncingUI = true
        SliderControl.integerValue = Clamped
        ValueField.stringValue = String(Clamped)

        MarkUserSet(Clamped)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            self.IsSyncingUI = false
        }

        if SendCallback {
            OnValueChanged?(CGFloat(Clamped))
        }
    }

    // MARK: - Actions

    @objc private func SliderMoved(_ Sender: NSSlider) {
        if IsSyncingUI { return }
        ApplyValue(Int(Sender.doubleValue.rounded()), SendCallback: true)
    }

    @objc private func ValueEdited(_ Sender: NSTextField) {
        if IsSyncingUI { return }
        let Typed = Int(Sender.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        ApplyValue(Typed, SendCallback: true)
    }
}
