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
    check("assignDisplay_ofStraddlingWindow_returnsDisplayWithMostArea",
          assignDisplay(windowFrame: CGRect(x: 800, y: 100, width: 400, height: 200), displays: displays) == left)
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

if failures > 0 {
    print("\(failures) check(s) failed")
    exit(1)
}
print("All checks passed")
