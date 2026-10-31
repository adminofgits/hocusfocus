import AppKit
import Testing
@testable import HocusFocus

struct DelaySliderTests {
    @MainActor @Test func presetMarkersMatchNativeThumbAtDifferentWidths() {
        for width in [280.0, 328.0, 400.0] {
            let view = DelaySliderView(frame: NSRect(x: 0, y: 0, width: width, height: 54))
            view.layoutSubtreeIfNeeded()
            // Measure the displayed control, after AppKit initializes drawing geometry.
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let slider = view.slider
            let cell = slider.cell as! NSSliderCell
            for value in [0, 150, 400, 750, 1_000] {
                slider.doubleValue = Double(value)
                _ = cell.barRect(flipped: slider.isFlipped)
                let thumbX = slider.convert(cell.knobRect(flipped: slider.isFlipped), to: view).midX
                #expect(abs(view.markerX(for: value) - thumbX) < 0.01, "width \(width), delay \(value)")
                #expect(slider.doubleValue == Double(value))
            }
        }
    }

    @MainActor @Test func measuringMarkersDoesNotWriteToTheTrackingCell() {
        let view = DelaySliderView(frame: NSRect(x: 0, y: 0, width: 328, height: 54))
        let cell = TrackingCell()
        view.slider.cell = cell
        view.slider.minValue = 0
        view.slider.maxValue = 1_000
        view.layoutSubtreeIfNeeded()
        view.slider.doubleValue = 150
        let writesBeforeMeasurement = cell.valueWrites
        let positions = [150, 400, 750].map { view.markerX(for: $0) }
        #expect(cell.valueWrites == writesBeforeMeasurement)
        #expect(view.slider.doubleValue == 150)
        #expect(positions[0] < positions[1])
        #expect(positions[1] < positions[2])
        for value in [150, 400, 750] {
            view.slider.doubleValue = Double(value)
            #expect(abs(view.slider.displayedThumbRect.midX - view.markerX(for: value)) < 0.01)
        }
    }
}

private final class TrackingCell: NSSliderCell {
    var valueWrites = 0
    override var doubleValue: Double {
        get { super.doubleValue }
        set { valueWrites += 1; super.doubleValue = newValue }
    }

    // Model AppKit returning its cached drag position while tracking.
    override func knobRect(flipped: Bool) -> NSRect {
        NSRect(x: 48, y: 2, width: 20, height: 16)
    }
}
