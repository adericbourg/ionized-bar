import CoreGraphics
import Foundation
import IonizedBarCore

nonisolated(unsafe) var failures = 0

func check(_ name: String, _ isOK: Bool) {
    if !isOK {
        failures += 1
        print("FAIL \(name)")
    }
}

let primaryHeight: CGFloat = 1000

// flipRect
do {
    // Given a window on a secondary display above the primary (AX y negative)
    let ax = CGRect(x: 100, y: -500, width: 300, height: 200)
    // When flipping
    let cocoa = flipRect(ax, primaryScreenHeight: primaryHeight)
    // Then y' = H - y - h
    check("flipRect_ofWindowAbovePrimary_returnsCocoaOrigin", cocoa == CGRect(x: 100, y: 1300, width: 300, height: 200))
    check("flipRect_appliedTwice_returnsOriginal", flipRect(cocoa, primaryScreenHeight: primaryHeight) == ax)
}

// assignDisplay
do {
    let left = Display(id: 1, frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
    let right = Display(id: 2, frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000))
    let displays = [left, right]

    check("assignDisplay_ofWindowInsideSecond_returnsSecond",
          assignDisplay(windowFrame: CGRect(x: 1100, y: 100, width: 200, height: 200), displays: displays) == right)
    check("assignDisplay_ofWindowMostlyOnSecond_returnsSecond",
          assignDisplay(windowFrame: CGRect(x: 900, y: 100, width: 400, height: 200), displays: displays) == right)
    check("assignDisplay_ofWindowMostlyOnFirst_returnsFirst",
          assignDisplay(windowFrame: CGRect(x: 700, y: 100, width: 400, height: 200), displays: [right, left]) == left)
    check("assignDisplay_whenTie_returnsFirst",
          assignDisplay(windowFrame: CGRect(x: 900, y: 100, width: 200, height: 200), displays: displays) == left)
    check("assignDisplay_whenNothingIntersects_returnsNil",
          assignDisplay(windowFrame: CGRect(x: 5000, y: 5000, width: 10, height: 10), displays: displays) == nil)

    let negative = Display(id: 3, frame: CGRect(x: -800, y: 0, width: 800, height: 600))
    check("assignDisplay_ofNegativeOriginDisplay_returnsIt",
          assignDisplay(windowFrame: CGRect(x: -500, y: 100, width: 200, height: 200), displays: [left, negative]) == negative)
}

// entryWidth
do {
    check("entryWidth_ofFewEntries_capsAtMax",
          entryWidth(barWidth: 1000, entryCount: 2) == EntryWidth(width: 220, isIconOnly: false))
    check("entryWidth_ofManyEntries_shrinks",
          entryWidth(barWidth: 1000, entryCount: 10) == EntryWidth(width: 100, isIconOnly: false))
    check("entryWidth_ofExactlyThreshold_isNotIconOnly",
          entryWidth(barWidth: 480, entryCount: 10) == EntryWidth(width: 48, isIconOnly: false))
    check("entryWidth_ofBelowThreshold_isIconOnly",
          entryWidth(barWidth: 470, entryCount: 10) == EntryWidth(width: 47, isIconOnly: true))
    check("entryWidth_ofZeroEntries_returnsZeroNotIconOnly",
          entryWidth(barWidth: 1000, entryCount: 0) == EntryWidth(width: 0, isIconOnly: false))
}

// isRealWindow
do {
    // Given a subrole and a window state, When filtering, Then only standard windows pass,
    // plus the AXDialog that AppKit reports for them while minimized or hidden.
    check("isRealWindow_ofStandard_returnsTrue", isRealWindow(subrole: "AXStandardWindow", isMinimized: false, isAppHidden: false))
    check("isRealWindow_ofDialogWhenMinimized_returnsTrue", isRealWindow(subrole: "AXDialog", isMinimized: true, isAppHidden: false))
    check("isRealWindow_ofDialogWhenAppHidden_returnsTrue", isRealWindow(subrole: "AXDialog", isMinimized: false, isAppHidden: true))
    check("isRealWindow_ofDialogWhenNeither_returnsFalse", !isRealWindow(subrole: "AXDialog", isMinimized: false, isAppHidden: false))
    check("isRealWindow_ofNoSubroleWhenAppHidden_returnsFalse", !isRealWindow(subrole: nil, isMinimized: false, isAppHidden: true))
    check("isRealWindow_ofSystemDialogWhenAppHidden_returnsFalse", !isRealWindow(subrole: "AXSystemDialog", isMinimized: false, isAppHidden: true))
    check("isRealWindow_ofUnknownWhenMinimized_returnsFalse", !isRealWindow(subrole: "AXUnknown", isMinimized: true, isAppHidden: false))
}

// isOnCurrentSpace
do {
    // Given a window of pid 1, and an on-screen list
    let frame = CGRect(x: 100, y: 100, width: 300, height: 200)
    func isListed(pid: Int32 = 1, isMinimized: Bool = false, isAppHidden: Bool = false, onScreen: [OnScreenWindow]) -> Bool {
        // When filtering
        isOnCurrentSpace(pid: pid, frame: frame, isMinimized: isMinimized, isAppHidden: isAppHidden, onScreen: onScreen)
    }
    // Then
    check("isOnCurrentSpace_whenMinimized_returnsTrue", isListed(isMinimized: true, onScreen: []))
    check("isOnCurrentSpace_whenAppHidden_returnsTrue", isListed(isAppHidden: true, onScreen: []))
    check("isOnCurrentSpace_whenNotInList_returnsFalse", !isListed(onScreen: []))
    check("isOnCurrentSpace_whenSameBounds_returnsTrue", isListed(onScreen: [OnScreenWindow(pid: 1, bounds: frame)]))
    check("isOnCurrentSpace_whenOtherPidHasSameBounds_returnsFalse", !isListed(onScreen: [OnScreenWindow(pid: 2, bounds: frame)]))
    check("isOnCurrentSpace_whenEveryEdgeOff2pt_returnsTrue",
          isListed(onScreen: [OnScreenWindow(pid: 1, bounds: CGRect(x: 102, y: 98, width: 296, height: 204))]))
    // The bounds below move one edge by 3pt, and keep the others in place.
    check("isOnCurrentSpace_whenLeftEdgeOff3pt_returnsFalse",
          !isListed(onScreen: [OnScreenWindow(pid: 1, bounds: CGRect(x: 103, y: 100, width: 297, height: 200))]))
    check("isOnCurrentSpace_whenTopEdgeOff3pt_returnsFalse",
          !isListed(onScreen: [OnScreenWindow(pid: 1, bounds: CGRect(x: 100, y: 103, width: 300, height: 197))]))
    check("isOnCurrentSpace_whenRightEdgeOff3pt_returnsFalse",
          !isListed(onScreen: [OnScreenWindow(pid: 1, bounds: CGRect(x: 100, y: 100, width: 303, height: 200))]))
    check("isOnCurrentSpace_whenBottomEdgeOff3pt_returnsFalse",
          !isListed(onScreen: [OnScreenWindow(pid: 1, bounds: CGRect(x: 100, y: 100, width: 300, height: 203))]))
    check("isOnCurrentSpace_whenSecondEntryMatches_returnsTrue",
          isListed(onScreen: [OnScreenWindow(pid: 1, bounds: .zero), OnScreenWindow(pid: 1, bounds: frame)]))
}

if failures > 0 {
    print("\(failures) check(s) failed")
    exit(1)
}
print("All checks passed")
