import AppKit
import Testing
@testable import MeetCue

struct PanelDragTests {
    let frame = NSRect(x: 1000, y: 700, width: 452, height: 88)

    @Test func followsTheMouseFromWhereTheDragStarted() throws {
        var drag = PanelDrag()
        #expect(drag.topRight == nil)
        drag.update(CGSize(width: 5, height: 5), mouse: NSPoint(x: 1205, y: 745), frame: frame)
        #expect(drag.topRight == NSPoint(x: 1457, y: 783))
        drag.update(CGSize(width: -95, height: 45), mouse: NSPoint(x: 1105, y: 705), frame: frame)
        #expect(drag.topRight == NSPoint(x: 1357, y: 743))
    }

    @Test func endingSettlesWhereThePanelWasPlaced() {
        var drag = PanelDrag()
        drag.update(CGSize(width: 2, height: 0), mouse: NSPoint(x: 1202, y: 750), frame: frame)
        drag.update(CGSize(width: 900, height: 0), mouse: NSPoint(x: 2100, y: 750), frame: frame)
        let clamped = NSRect(x: 1468, y: 700, width: 452, height: 88)
        drag.update(nil, mouse: NSPoint(x: 2100, y: 750), frame: clamped)
        #expect(drag.topRight == NSPoint(x: 1920, y: 788))
        drag.update(CGSize(width: 0, height: 10), mouse: NSPoint(x: 1700, y: 740), frame: clamped)
        #expect(drag.topRight == NSPoint(x: 1920, y: 778))
    }

    @Test func endingWithoutADragLeavesItInTheCorner() {
        var drag = PanelDrag()
        drag.update(nil, mouse: .zero, frame: frame)
        #expect(drag.topRight == nil)
    }

    @Test func resetReturnsToTheCorner() {
        var drag = PanelDrag()
        drag.update(CGSize(width: 10, height: 10), mouse: NSPoint(x: 1210, y: 740), frame: frame)
        drag.reset()
        #expect(drag.topRight == nil)
    }
}
