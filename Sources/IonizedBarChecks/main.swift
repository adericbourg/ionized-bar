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
    // Given two side-by-side displays
    let left = Display(id: 1, frame: CGRect(x: 0, y: 0, width: 1000, height: 1000))
    let right = Display(id: 2, frame: CGRect(x: 1000, y: 0, width: 1000, height: 1000))
    let displays = [left, right]

    // When assigning, Then the largest intersection wins
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

    // Given a display with a negative origin, When assigning, Then it can be picked
    let negative = Display(id: 3, frame: CGRect(x: -800, y: 0, width: 800, height: 600))
    check("assignDisplay_ofNegativeOriginDisplay_returnsIt",
          assignDisplay(windowFrame: CGRect(x: -500, y: 100, width: 200, height: 200), displays: [left, negative]) == negative)
}

// entryWidth
do {
    // Given a bar width and an entry count, When computing the width, Then it is capped at 220pt,
    // and below 48pt it goes icon-only.
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

// barFrame
do {
    // Given a screen with a non-zero origin (secondary display above-left of the primary)
    let screen = CGRect(x: -800, y: 1000, width: 800, height: 600)
    // When computing the bar frame, Then it is full width, 36pt high and flush with the screen bottom
    check("barFrame_ofOffsetScreen_isFullWidthAtBottom",
          barFrame(screenFrame: screen) == CGRect(x: -800, y: 1000, width: 800, height: 36))
    check("barFrame_ofCustomHeight_usesIt",
          barFrame(screenFrame: screen, height: 20).height == 20)
}

// clickAction
do {
    // Given an entry's state, When clicking, Then minimized restores (even if flagged active),
    // active minimizes, and anything else raises.
    check("clickAction_whenInactive_raises", clickAction(isActive: false, isMinimized: false) == .raise)
    check("clickAction_whenActive_minimizes", clickAction(isActive: true, isMinimized: false) == .minimize)
    check("clickAction_whenMinimized_restores", clickAction(isActive: false, isMinimized: true) == .restore)
    check("clickAction_whenMinimizedAndActive_restores", clickAction(isActive: true, isMinimized: true) == .restore)
}

// appsToGroup
do {
    // Given apps in bar order: pid 1 has 2 windows, pid 2 has 4, pid 3 has 2, pid 4 has 1 (9 entries)
    let counts: [(pid: Int32, count: Int)] = [(1, 2), (2, 4), (3, 2), (4, 1)]
    func grouped(barWidth: CGFloat, mode: GroupingMode) -> Set<Int32> {
        // When deciding, with a 100pt minimum entry width
        appsToGroup(windowCounts: counts, barWidth: barWidth, mode: mode, minEntryWidth: 100)
    }
    // Then
    check("appsToGroup_whenNever_groupsNothing", grouped(barWidth: 10, mode: .never).isEmpty)
    check("appsToGroup_whenAlways_groupsEveryMultiWindowApp", grouped(barWidth: 10_000, mode: .always) == [1, 2, 3])
    check("appsToGroup_whenFullAndEntriesFit_groupsNothing", grouped(barWidth: 900, mode: .whenFull).isEmpty)
    // 899pt / 9 entries is too narrow; merging pid 2 leaves 6 entries, which fit.
    check("appsToGroup_whenFull_groupsLargestAppFirstAndStops", grouped(barWidth: 899, mode: .whenFull) == [2])
    // 599pt / 6 entries is still too narrow; pids 1 and 3 tie, and the later one merges.
    check("appsToGroup_whenFullAndTied_groupsLaterApp", grouped(barWidth: 599, mode: .whenFull) == [2, 3])
    check("appsToGroup_whenFullAndNothingFits_groupsAllCandidates", grouped(barWidth: 10, mode: .whenFull) == [1, 2, 3])
    check("appsToGroup_ofSingleWindowApps_groupsNothing",
          appsToGroup(windowCounts: [(1, 1), (2, 1)], barWidth: 10, mode: .always, minEntryWidth: 100).isEmpty)
}

// barItems
do {
    // Given windows (pid, name) whose apps interleave on the bar
    let windows: [(pid: Int32, name: String)] = [(1, "a"), (2, "b"), (1, "c"), (3, "d")]
    func items(mode: GroupingMode) -> [BarItem<(pid: Int32, name: String)>] {
        // When building the bar's items
        barItems(windows, pid: \.pid, barWidth: 1000, mode: mode, minEntryWidth: 100)
    }
    func describe(_ items: [BarItem<(pid: Int32, name: String)>]) -> [String] {
        items.map { item in
            switch item {
            case .window(let window): window.name
            case .group(let pid, let windows): "\(pid):" + windows.map(\.name).joined()
            }
        }
    }
    // Then a group sits where its app's first window was, and keeps its windows in bar order
    check("barItems_whenAlways_groupsAtFirstWindowPosition", describe(items(mode: .always)) == ["1:ac", "b", "d"])
    check("barItems_whenNever_keepsEveryWindow", describe(items(mode: .never)) == ["a", "b", "c", "d"])
}

if failures > 0 {
    print("\(failures) check(s) failed")
    exit(1)
}
print("All checks passed")
