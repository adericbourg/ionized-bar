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

// entryAccessibilityLabel
do {
    // Given an entry's title, app and state, When building its label
    func label(title: String = "Notes", isActive: Bool = false, isMinimized: Bool = false) -> String {
        entryAccessibilityLabel(title: title, appName: "TextEdit", isActive: isActive, isMinimized: isMinimized)
    }
    // Then it reads title, app, then state; minimized wins over active, as in clickAction
    check("entryAccessibilityLabel_whenInactive_readsTitleAndApp", label() == "Notes, TextEdit")
    check("entryAccessibilityLabel_whenActive_endsWithActive", label(isActive: true) == "Notes, TextEdit, active")
    check("entryAccessibilityLabel_whenMinimized_endsWithMinimized", label(isMinimized: true) == "Notes, TextEdit, minimized")
    check("entryAccessibilityLabel_whenMinimizedAndActive_endsWithMinimized", label(isActive: true, isMinimized: true) == "Notes, TextEdit, minimized")
    check("entryAccessibilityLabel_ofEmptyTitle_startsWithApp", label(title: "") == "TextEdit")
    check("entryAccessibilityLabel_ofEmptyTitleWhenActive_startsWithApp", label(title: "", isActive: true) == "TextEdit, active")
}

// groupAccessibilityLabel
do {
    // Given a group of 3 windows, When building its label
    func label(isActive: Bool = false, isMinimized: Bool = false) -> String {
        groupAccessibilityLabel(appName: "TextEdit", windowCount: 3, isActive: isActive, isMinimized: isMinimized)
    }
    // Then it names the app and the count, then the state; minimized wins over active
    check("groupAccessibilityLabel_whenInactive_readsAppAndCount", label() == "TextEdit, 3 windows")
    check("groupAccessibilityLabel_whenActive_endsWithActive", label(isActive: true) == "TextEdit, 3 windows, active")
    check("groupAccessibilityLabel_whenMinimized_endsWithMinimized", label(isMinimized: true) == "TextEdit, 3 windows, minimized")
    check("groupAccessibilityLabel_whenMinimizedAndActive_endsWithMinimized", label(isActive: true, isMinimized: true) == "TextEdit, 3 windows, minimized")
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

// hideDock, restoreDock
do {
    final class FakeDock {
        var current: DockPrefs
        var saved: DockPrefs?
        var calls: [String] = []
        var logs: [String] = []
        var isReadOK = true
        var isWriteOK = true
        var isRelaunchOK = true
        var isSaveOK = true
        var isOtherCopyRunning = false

        init(current: DockPrefs, saved: DockPrefs? = nil) {
            self.current = current
            self.saved = saved
        }

        var store: DockStore {
            DockStore(
                read: { self.calls.append("read"); return self.isReadOK ? self.current : nil },
                write: { prefs in
                    self.calls.append("write")
                    if self.isWriteOK { self.current = prefs }
                    return self.isWriteOK
                },
                relaunchDock: { self.calls.append("relaunch"); return self.isRelaunchOK },
                loadSaved: { self.saved },
                save: { prefs in
                    self.calls.append("save")
                    if self.isSaveOK { self.saved = prefs }
                    return self.isSaveOK
                },
                clearSaved: { self.calls.append("clear"); self.saved = nil },
                isOtherCopyRunning: { self.isOtherCopyRunning },
                log: { self.logs.append($0) }
            )
        }
    }
    let user = DockPrefs(autohide: false, autohideDelay: 0.5)
    let absent = DockPrefs(autohide: nil, autohideDelay: nil)

    // Given a first run, When hiding, Then originals are saved before any write
    let firstRun = FakeDock(current: user)
    check("hideDock_whenFirstRun_returnsTrue", hideDock(firstRun.store))
    check("hideDock_whenFirstRun_savesBeforeWriting", firstRun.calls == ["read", "save", "write", "relaunch"])
    check("hideDock_whenFirstRun_savesOriginals", firstRun.saved == user)
    check("hideDock_whenFirstRun_writesHiddenValues", firstRun.current == .hidden)
    check("hideDock_whenFirstRun_logsNothing", firstRun.logs.isEmpty)

    // Given a delay left by another taskbar or a lost saved state, When hiding, Then both keys count as absent, so restoring shows the Dock
    for (name, delay) in [("HiddenValue", DockPrefs.hidden.autohideDelay!), ("Threshold", DockPrefs.leftoverDelayThreshold)] {
        let leftover = FakeDock(current: DockPrefs(autohide: true, autohideDelay: delay))
        check("hideDock_ofDelayAt\(name)_returnsTrue", hideDock(leftover.store))
        check("hideDock_ofDelayAt\(name)_savesAbsent", leftover.saved == absent)
        check("hideDock_ofDelayAt\(name)_logsOnce", leftover.logs.count == 1)
        restoreDock(leftover.store)
        check("restoreDock_ofDelayAt\(name)_leavesKeysAbsent", leftover.current == absent && leftover.saved == nil)
    }

    // Given a large delay a person could have set, When hiding, Then it is kept as an original
    let largeDelay = DockPrefs(autohide: true, autohideDelay: 59.5)
    let largeButReal = FakeDock(current: largeDelay)
    _ = hideDock(largeButReal.store)
    check("hideDock_ofDelayBelowThreshold_keepsIt", largeButReal.saved == largeDelay && largeButReal.logs.isEmpty)

    // Given autohide on with no delay set, When hiding, Then it is a real preference and is kept
    let autohideOnly = DockPrefs(autohide: true, autohideDelay: nil)
    let noDelay = FakeDock(current: autohideOnly)
    _ = hideDock(noDelay.store)
    check("hideDock_ofAbsentDelay_keepsAutohide", noDelay.saved == autohideOnly)

    // Given originals left by a crash and a Dock still hidden, When hiding, Then they are kept and the Dock is hidden again
    let crashed = FakeDock(current: .hidden, saved: user)
    check("hideDock_whenCrashed_returnsTrue", hideDock(crashed.store))
    check("hideDock_whenCrashed_keepsOriginals", crashed.saved == user && !crashed.calls.contains("save"))
    check("hideDock_whenCrashed_hidesAsNormal", crashed.calls == ["write", "relaunch"] && crashed.current == .hidden)
    let crashedWithHugeSaved = DockPrefs(autohide: true, autohideDelay: 1000)
    let oldState = FakeDock(current: .hidden, saved: crashedWithHugeSaved)
    _ = hideDock(oldState.store)
    check("hideDock_whenCrashed_leavesSavedStateAsIs", oldState.saved == crashedWithHugeSaved && oldState.logs.isEmpty)

    // Given absent keys, When a run crashes and the next one quits, Then saved "both absent" still counts and they end up absent
    let absentKeys = FakeDock(current: absent)
    _ = hideDock(absentKeys.store)
    check("hideDock_ofAbsentKeys_savesThemAsAbsent", absentKeys.saved == absent)
    _ = hideDock(absentKeys.store)
    check("hideDock_whenCrashedWithAbsentKeys_keepsThemAbsent", absentKeys.saved == absent)
    restoreDock(absentKeys.store)
    check("restoreDock_ofAbsentKeys_removesThem", absentKeys.current == absent && absentKeys.saved == nil)

    // Given a failed read or save, When hiding, Then the Dock is left alone
    let readFails = FakeDock(current: user)
    readFails.isReadOK = false
    check("hideDock_whenReadFails_returnsFalse", !hideDock(readFails.store))
    check("hideDock_whenReadFails_doesNotHide", readFails.calls == ["read"] && readFails.saved == nil)
    let saveFails = FakeDock(current: user)
    saveFails.isSaveOK = false
    check("hideDock_whenSaveFails_returnsFalse", !hideDock(saveFails.store))
    check("hideDock_whenSaveFails_doesNotHide", saveFails.calls == ["read", "save"] && saveFails.current == user)

    // Given a failed write or Dock relaunch, When hiding, Then it reports failure and the originals stay for the restore
    let hideWriteFails = FakeDock(current: user)
    hideWriteFails.isWriteOK = false
    check("hideDock_whenWriteFails_returnsFalse", !hideDock(hideWriteFails.store) && hideWriteFails.saved == user)
    let hideRelaunchFails = FakeDock(current: user)
    hideRelaunchFails.isRelaunchOK = false
    check("hideDock_whenRelaunchFails_returnsFalse", !hideDock(hideRelaunchFails.store) && hideRelaunchFails.saved == user)

    // Given saved originals, When restoring, Then they are written, the Dock relaunched and only then the state cleared
    let restored = FakeDock(current: .hidden, saved: user)
    restoreDock(restored.store)
    check("restoreDock_writesRelaunchesThenClears", restored.calls == ["write", "relaunch", "clear"])
    check("restoreDock_writesOriginalsAndClearsState", restored.current == user && restored.saved == nil)

    // Given nothing saved, When restoring, Then nothing happens
    let nothingSaved = FakeDock(current: user)
    restoreDock(nothingSaved.store)
    check("restoreDock_whenNothingSaved_doesNothing", nothingSaved.calls.isEmpty && nothingSaved.current == user)

    // Given a failed write, When restoring, Then the state stays so a later restore can still succeed
    let restoreFails = FakeDock(current: .hidden, saved: user)
    restoreFails.isWriteOK = false
    restoreDock(restoreFails.store)
    check("restoreDock_whenWriteFails_keepsState", restoreFails.saved == user && !restoreFails.calls.contains("clear"))
    restoreFails.isWriteOK = true
    restoreDock(restoreFails.store)
    check("restoreDock_afterFailedWrite_canRetry", restoreFails.current == user && restoreFails.saved == nil)

    // Given a failed Dock relaunch, When restoring, Then the state is cleared, as the prefs are back
    let restoreRelaunchFails = FakeDock(current: .hidden, saved: user)
    restoreRelaunchFails.isRelaunchOK = false
    restoreDock(restoreRelaunchFails.store)
    check("restoreDock_whenRelaunchFails_clearsState", restoreRelaunchFails.current == user && restoreRelaunchFails.saved == nil)

    // Given another copy still running, When restoring, Then the Dock stays hidden, and the last copy to quit restores it
    let twoCopies = FakeDock(current: .hidden, saved: user)
    twoCopies.isOtherCopyRunning = true
    restoreDock(twoCopies.store)
    check("restoreDock_whenOtherCopyRunning_keepsDockHidden", twoCopies.calls.isEmpty && twoCopies.current == .hidden && twoCopies.saved == user)
    check("restoreDock_whenOtherCopyRunning_logsOnce", twoCopies.logs.count == 1)
    twoCopies.isOtherCopyRunning = false
    restoreDock(twoCopies.store)
    check("restoreDock_whenLastCopyQuits_restoresOriginals", twoCopies.current == user && twoCopies.saved == nil)
}

// DockLock
do {
    let path = NSTemporaryDirectory() + "ionized-bar-checks-\(UUID().uuidString).lock"
    defer { try? FileManager.default.removeItem(atPath: path) }
    guard let first = DockLock(path: path), let second = DockLock(path: path) else {
        check("DockLock_opensItsFile", false)
        exit(1)
    }

    // Given a single copy, When it quits, Then it is the last
    first.hold()
    check("isOtherCopyRunning_whenAlone_returnsFalse", !first.isOtherCopyRunning())

    // Given a copy that checked at launch and holds again, When another quits, Then it is still seen
    first.hold()
    check("isOtherCopyRunning_whenOtherCopyHolds_returnsTrue", second.isOtherCopyRunning())

    // Given two copies quitting one after the other (killall), When each checks, Then only the last one to check is alone
    second.hold()
    first.hold()
    check("isOtherCopyRunning_whenBothQuit_firstReturnsTrue", first.isOtherCopyRunning())
    check("isOtherCopyRunning_whenBothQuit_lastOneReturnsFalse", !second.isOtherCopyRunning())
}

// overlapsBar / pushedFrame
do {
    // Given a screen at a non-zero origin with a 25pt menu bar (Cocoa coordinates, bar 36pt at the bottom)
    let screen = CGRect(x: -800, y: 1000, width: 800, height: 600)
    let visible = CGRect(x: -800, y: 1000, width: 800, height: 575)
    let bar = barFrame(screenFrame: screen)
    let above = CGRect(x: -700, y: 1100, width: 300, height: 200)
    let over = CGRect(x: -700, y: 1010, width: 300, height: 200)
    check("overlapsBar_ofWindowAbove_isFalse", !overlapsBar(above, bar: bar))
    check("overlapsBar_ofWindowTouchingTop_isFalse", !overlapsBar(CGRect(x: -700, y: 1036, width: 300, height: 200), bar: bar))
    check("overlapsBar_ofWindowOverBar_isTrue", overlapsBar(over, bar: bar))
    check("overlapsBar_ofEmptyWindowInsideBar_isFalse", !overlapsBar(CGRect(x: bar.midX, y: bar.midY, width: 0, height: 10), bar: bar))
    // Given a window that fits, When pushing, Then it moves up and keeps its size, x and width
    check("pushedFrame_ofOverlappingWindow_movesUp",
          pushedFrame(over, screenFrame: screen, visibleFrame: visible, barHeight: 36) == CGRect(x: -700, y: 1036, width: 300, height: 200))
    check("pushedFrame_ofWindowAbove_isUnchanged",
          pushedFrame(above, screenFrame: screen, visibleFrame: visible, barHeight: 36) == above)
    // Given a window taller than the space between bar and menu bar, Then it shrinks to it
    let tall = CGRect(x: -700, y: 1000, width: 300, height: 600)
    check("pushedFrame_ofTooTallWindow_shrinksToAvailableArea",
          pushedFrame(tall, screenFrame: screen, visibleFrame: visible, barHeight: 36) == CGRect(x: -700, y: 1036, width: 300, height: 539))
    // Given a window hanging below the screen, Then it ends above the bar
    let below = CGRect(x: -700, y: 900, width: 300, height: 300)
    check("pushedFrame_ofWindowBelowScreen_endsAboveBar",
          pushedFrame(below, screenFrame: screen, visibleFrame: visible, barHeight: 36) == CGRect(x: -700, y: 1036, width: 300, height: 300))
}

// pushTarget
do {
    // Given a screen with a 25pt menu bar and a 36pt bar at the bottom
    let screen = CGRect(x: 0, y: 0, width: 800, height: 600)
    let visible = CGRect(x: 0, y: 0, width: 800, height: 575)
    let over = CGRect(x: 100, y: 10, width: 300, height: 200)
    func target(_ window: CGRect, isMinimized: Bool = false, isFullScreen: Bool = false, visibleFrame: CGRect = visible) -> CGRect? {
        pushTarget(window, isMinimized: isMinimized, isFullScreen: isFullScreen, screenFrame: screen, visibleFrame: visibleFrame)
    }
    check("pushTarget_ofOverlappingWindow_isItsPushedFrame", target(over) == CGRect(x: 100, y: 36, width: 300, height: 200))
    // Given a window clear of the bar but taller than the room, Then pushedFrame must not get to shrink it
    check("pushTarget_ofTallWindowClearOfBar_isNil", target(CGRect(x: 100, y: 36, width: 300, height: 564)) == nil)
    check("pushTarget_ofMinimizedWindow_isNil", target(over, isMinimized: true) == nil)
    check("pushTarget_ofFullScreenWindow_isNil", target(screen, isFullScreen: true) == nil)
    // Given no room above the bar (a negative room would give a negative height), Then no push
    check("pushTarget_whenVisibleTopIsBelowBarTop_isNil", target(over, visibleFrame: CGRect(x: 0, y: 0, width: 800, height: 20)) == nil)
    check("pushTarget_whenVisibleTopIsAtBarTop_isNil", target(over, visibleFrame: CGRect(x: 0, y: 0, width: 800, height: 36)) == nil)
}

// PushMemory
do {
    let frame = CGRect(x: 100, y: 900, width: 300, height: 200)
    let other = CGRect(x: 100, y: 920, width: 300, height: 180)
    let pushed = CGRect(x: 100, y: 700, width: 300, height: 200)

    // Given a window just seen over the bar, When its frame holds, Then it waits and then pushes
    var settling = PushMemory(now: 0)
    check("step_whenFrameJustSeen_waits", settling.step(frame: frame, wantsPush: true, isMouseDown: false, now: 0) == .wait)
    check("step_beforeSettleTime_waits", settling.step(frame: frame, wantsPush: true, isMouseDown: false, now: PushMemory.settleTime - 0.01) == .wait)
    // Given a frame that changes just before the settle time, Then the wait restarts
    check("step_whenFrameChanges_restartsWait", settling.step(frame: other, wantsPush: true, isMouseDown: false, now: PushMemory.settleTime) == .wait)
    check("step_afterFrameChange_stillWaits", settling.step(frame: other, wantsPush: true, isMouseDown: false, now: PushMemory.settleTime * 1.5) == .wait)
    check("step_whenFrameHolds_pushes", settling.step(frame: other, wantsPush: true, isMouseDown: false, now: PushMemory.settleTime * 2 + 0.01) == .push)

    // Given a window that doesn't need a push, Then nothing is pending, mouse or not
    var clear = PushMemory(now: 0)
    check("step_withoutTarget_isIdle", clear.step(frame: frame, wantsPush: false, isMouseDown: false, now: 0) == .idle)
    check("step_withoutTargetAndMouseDown_isIdle", clear.step(frame: frame, wantsPush: false, isMouseDown: true, now: 10) == .idle)

    // Given a settled frame under a held mouse button (a drag), Then it waits for the release
    var dragged = PushMemory(now: 0)
    _ = dragged.step(frame: frame, wantsPush: true, isMouseDown: true, now: 0)
    check("step_whenMouseDown_waits", dragged.step(frame: frame, wantsPush: true, isMouseDown: true, now: 10) == .wait)
    check("step_afterMouseUp_pushes", dragged.step(frame: frame, wantsPush: true, isMouseDown: false, now: 10.1) == .push)

    // Given a push that leaves the window where it was (minimum size, failed AX call)
    var stuck = PushMemory(now: 0)
    _ = stuck.step(frame: frame, wantsPush: true, isMouseDown: false, now: 0)
    check("step_stuck_firstPush", stuck.step(frame: frame, wantsPush: true, isMouseDown: false, now: 1) == .push)
    // Then the result is awaited, and that frame is not pushed again however long it stays
    check("step_afterPush_awaitsResult", stuck.step(frame: frame, wantsPush: true, isMouseDown: false, now: 1 + PushMemory.settleTime + 0.01) == .wait)
    check("step_whenResultSettles_doesNotPushAgain", stuck.step(frame: frame, wantsPush: true, isMouseDown: false, now: 1 + PushMemory.resultSettleTime + 0.01) == .idle)
    check("step_onEndedFrame_staysIdle", stuck.step(frame: frame, wantsPush: true, isMouseDown: false, now: 100) == .idle)
    // When its frame changes to another one, Then it may be pushed again, even back on the frame it ended at
    check("step_whenEndedFrameChanges_waits", stuck.step(frame: other, wantsPush: true, isMouseDown: false, now: 101) == .wait)
    check("step_afterEndedFrameChange_pushes", stuck.step(frame: other, wantsPush: true, isMouseDown: false, now: 102) == .push)
    _ = stuck.step(frame: other, wantsPush: true, isMouseDown: false, now: 104)
    check("step_onOtherEndedFrame_staysIdle", stuck.step(frame: other, wantsPush: true, isMouseDown: false, now: 105) == .idle)
    _ = stuck.step(frame: frame, wantsPush: false, isMouseDown: false, now: 106)
    _ = stuck.step(frame: other, wantsPush: true, isMouseDown: false, now: 107)
    check("step_whenBackOnFormerEndedFrame_pushes", stuck.step(frame: other, wantsPush: true, isMouseDown: false, now: 108) == .push)

    // Given an app that repositions itself over the bar right after the push, Then that frame is where it ended
    var fighter = PushMemory(now: 0)
    _ = fighter.step(frame: frame, wantsPush: true, isMouseDown: false, now: 0)
    _ = fighter.step(frame: frame, wantsPush: true, isMouseDown: false, now: 1)
    check("step_whenAppMovesAfterPush_waits", fighter.step(frame: pushed, wantsPush: false, isMouseDown: false, now: 1.1) == .wait)
    check("step_whenAppMovesBack_waits", fighter.step(frame: frame, wantsPush: true, isMouseDown: false, now: 1.2) == .wait)
    check("step_whenAppSettlesOverBar_doesNotPush", fighter.step(frame: frame, wantsPush: true, isMouseDown: false, now: 1.2 + PushMemory.resultSettleTime + 0.01) == .idle)

    // Given a user grabbing the window while the result is awaited, Then the frame under the mouse is no result
    var grabbed = PushMemory(now: 0)
    _ = grabbed.step(frame: frame, wantsPush: true, isMouseDown: false, now: 0)
    _ = grabbed.step(frame: frame, wantsPush: true, isMouseDown: false, now: 1)
    check("step_whenMouseDownOnResult_waits", grabbed.step(frame: other, wantsPush: true, isMouseDown: true, now: 5) == .wait)
    _ = grabbed.step(frame: other, wantsPush: true, isMouseDown: true, now: 10)
    check("step_afterMouseUpOnResult_recordsIt", grabbed.step(frame: other, wantsPush: true, isMouseDown: false, now: 10.1) == .idle)

    // Given a push skipped because the snapshot was stale, Then it isn't taken for a result and is retried once settled
    var stale = PushMemory(now: 0)
    _ = stale.step(frame: frame, wantsPush: true, isMouseDown: false, now: 0)
    _ = stale.step(frame: frame, wantsPush: true, isMouseDown: false, now: 1)
    stale.pushWasStale()
    check("step_afterStalePush_waits", stale.step(frame: other, wantsPush: true, isMouseDown: false, now: 1.1) == .wait)
    check("step_afterStalePush_pushes", stale.step(frame: other, wantsPush: true, isMouseDown: false, now: 1.1 + PushMemory.settleTime + 0.01) == .push)

    // Given a window that goes fullscreen while the result is awaited, Then it ends idle and pushes nothing
    var fullScreen = PushMemory(now: 0)
    _ = fullScreen.step(frame: frame, wantsPush: true, isMouseDown: false, now: 0)
    _ = fullScreen.step(frame: frame, wantsPush: true, isMouseDown: false, now: 1)
    check("step_whenTargetGoneWhileAwaiting_waits", fullScreen.step(frame: other, wantsPush: false, isMouseDown: false, now: 1.1) == .wait)
    check("step_whenTargetGoneAndSettled_isIdle", fullScreen.step(frame: other, wantsPush: false, isMouseDown: false, now: 5) == .idle)

    check("lastSeen_followsLastStep", fullScreen.lastSeen == 5)
}

// matchWindow
do {
    let frame = CGRect(x: 100, y: 100, width: 400, height: 300)
    let mine = CaptureCandidate(id: 1, pid: 7, bounds: frame.insetBy(dx: 1, dy: 1))
    // Given one candidate of the pid within 2pt, Then it matches
    check("matchWindow_ofOneCandidateWithin2pt_returnsItsId", matchWindow(pid: 7, frame: frame, candidates: [mine]) == 1)
    // Given other pids and frames around it, Then it still matches
    let otherPid = CaptureCandidate(id: 2, pid: 8, bounds: frame)
    let otherFrame = CaptureCandidate(id: 3, pid: 7, bounds: frame.offsetBy(dx: 50, dy: 0))
    check("matchWindow_amongUnrelatedCandidates_returnsTheOne", matchWindow(pid: 7, frame: frame, candidates: [otherPid, otherFrame, mine]) == 1)
    // Given a candidate 3pt off, Then no match
    check("matchWindow_of3ptOff_returnsNil", matchWindow(pid: 7, frame: frame, candidates: [CaptureCandidate(id: 4, pid: 7, bounds: frame.offsetBy(dx: 3, dy: 0))]) == nil)
    // Given two same-pid candidates with the same frame (another Space, hidden), Then ambiguous
    check("matchWindow_ofTwoMatches_returnsNil", matchWindow(pid: 7, frame: frame, candidates: [mine, CaptureCandidate(id: 5, pid: 7, bounds: frame)]) == nil)
    check("matchWindow_ofNoCandidates_returnsNil", matchWindow(pid: 7, frame: frame, candidates: []) == nil)
}

// previewFrame
do {
    let screen = CGRect(x: 1000, y: 0, width: 1000, height: 800)
    let size = CGSize(width: 320, height: 100)
    // Given an entry mid-bar, Then the panel is centered above it, with the gap
    check("previewFrame_ofMidBarEntry_isCenteredAboveIt", previewFrame(entry: CGRect(x: 1400, y: 0, width: 200, height: 36), size: size, screen: screen, gap: 4) == CGRect(x: 1340, y: 40, width: 320, height: 100))
    // Given an entry at either edge of a non-primary screen, Then the panel stays on that screen, the gap from its edge
    check("previewFrame_ofLeftEdgeEntry_staysOnScreen", previewFrame(entry: CGRect(x: 1000, y: 0, width: 48, height: 36), size: size, screen: screen, gap: 4).minX == 1004)
    check("previewFrame_ofRightEdgeEntry_staysOnScreen", previewFrame(entry: CGRect(x: 1952, y: 0, width: 48, height: 36), size: size, screen: screen, gap: 4).maxX == 1996)
    // Given a half-point center, Then the origin is on an integer point, so the panel stays sharp
    check("previewFrame_ofFractionalCenter_roundsTheOrigin", previewFrame(entry: CGRect(x: 1400, y: 0, width: 201, height: 36), size: size, screen: screen, gap: 4).minX == 1341)
}

// isInPreviewGap
do {
    let entry = CGRect(x: 100, y: 0, width: 48, height: 36)
    let panel = CGRect(x: 4, y: 40, width: 320, height: 100)
    // Given the pointer between the entry and the panel, Then it is in the gap, the whole panel's width
    check("isInPreviewGap_ofPointBetween_isTrue", isInPreviewGap(CGPoint(x: 120, y: 38), entry: entry, panel: panel))
    check("isInPreviewGap_ofPointBesideTheEntryUnderThePanel_isTrue", isInPreviewGap(CGPoint(x: 300, y: 38), entry: entry, panel: panel))
    // Given the pointer level with the gap but past the panel's sides, Then it has left sideways
    check("isInPreviewGap_ofPointLeftOfThePanel_isFalse", !isInPreviewGap(CGPoint(x: 2, y: 38), entry: entry, panel: panel))
    check("isInPreviewGap_ofPointRightOfThePanel_isFalse", !isInPreviewGap(CGPoint(x: 324, y: 38), entry: entry, panel: panel))
    // Given the pointer on the panel or on the entry, Then it is not in the gap
    check("isInPreviewGap_ofPointOnThePanel_isFalse", !isInPreviewGap(CGPoint(x: 120, y: 40), entry: entry, panel: panel))
    check("isInPreviewGap_ofPointOnTheEntry_isFalse", !isInPreviewGap(CGPoint(x: 120, y: 35), entry: entry, panel: panel))
    // Given a stale panel frame below the entry's top edge (hidden panel on another screen), Then it is not in the gap, and doesn't trap
    check("isInPreviewGap_ofPanelBelowTheEntry_isFalse", !isInPreviewGap(CGPoint(x: 120, y: 38), entry: entry, panel: CGRect(x: 4, y: -500, width: 320, height: 100)))
}

// fittedSize
do {
    let box = CGSize(width: 300, height: 200)
    // Given a wide image, Then the width limits it
    check("fittedSize_ofWideImage_fillsTheWidth", fittedSize(CGSize(width: 640, height: 320), within: box) == CGSize(width: 300, height: 150))
    // Given a tall image, Then the height limits it
    check("fittedSize_ofTallImage_fillsTheHeight", fittedSize(CGSize(width: 320, height: 640), within: box) == CGSize(width: 100, height: 200))
    // Given a small image, Then it is not upscaled
    check("fittedSize_ofSmallImage_keepsItsSize", fittedSize(CGSize(width: 40, height: 20), within: box) == CGSize(width: 40, height: 20))
}

// fuzzyFilter
do {
    let names = ["Activity Monitor", "Google Chrome", "Google Docs", "Slack", "Safari", "System Settings", "Visual Studio Code", "Terminal", "1Password", "Karabiner-Elements", "Firefox"]
    func found(_ q: String) -> [String] { fuzzyFilter(names, query: q, name: { $0 }) }
    // Given an empty or blank search, Then everything is listed in the given order
    check("fuzzyFilter_ofEmptyQuery_returnsEverything", found("") == names && found("  ") == names)
    // Given a prefix, a word start and a substring, Then they rank in that order
    check("fuzzyFilter_ofPrefix_ranksBeforeWordStartAndSubstring", fuzzyFilter(["Mail Chat", "Chat", "Unchat", "Chatter"], query: "chat", name: { $0 }) == ["Chat", "Chatter", "Mail Chat", "Unchat"])
    check("fuzzyFilter_ofWordStart_findsTheApp", found("mon").first == "Activity Monitor" && found("studio") == ["Visual Studio Code"])
    check("fuzzyFilter_ofCaseAndAccents_ignoresThem", found("SLACK") == ["Slack"] && fuzzyFilter(["Café"], query: "cafe", name: { $0 }) == ["Café"])
    // Given partial names, Then they find the app
    check("fuzzyFilter_ofPartialName_findsTheApp", found("goo ch") == ["Google Chrome"] && found("vsc") == ["Visual Studio Code"])
    // Given typos, Then they still find the app
    check("fuzzyFilter_ofSwappedLetters_findsTheApp", found("slcak") == ["Slack"] && found("terminla") == ["Terminal"])
    check("fuzzyFilter_ofWrongLetter_findsTheApp", found("safsri") == ["Safari"] && found("firefax") == ["Firefox"])
    check("fuzzyFilter_ofMissingOrExtraLetter_findsTheApp", found("termnal") == ["Terminal"] && found("slackk") == ["Slack"] && found("1pasword") == ["1Password"])
    check("fuzzyFilter_ofTypoInSecondWord_findsTheApp", found("google crhome") == ["Google Chrome"] && found("karabiner-elemnts") == ["Karabiner-Elements"])
    // Given a 3-letter query with a typo, or an unrelated one, Then nothing matches
    check("fuzzyFilter_ofShortQueryWithTypo_findsNothing", found("slx").isEmpty && found("zq").isEmpty)
    check("fuzzyFilter_ofUnrelatedQuery_findsNothing", found("photoshop").isEmpty)
}

// taskSlot
do {
    // Given a 1000pt bar, When asking where its tasks go, Then they start after the launcher and share the rest
    let slot = taskSlot(barWidth: 1000)
    check("taskSlot_startsAfterTheLauncher", slot.x == launcherWidth && launcherWidth == 48)
    check("taskSlot_sharesTheWidthLeft", slot.width == 952)
    // Given pinned icons, Then they sit between the launcher and the tasks
    let withPins = taskSlot(barWidth: 1000, pinnedWidth: 96)
    check("taskSlot_withPinnedIcons_startsAfterThem", withPins.x == 144 && withPins.width == 856)
    check("taskSlot_ofBarNarrowerThanLauncher_hasNoWidth", taskSlot(barWidth: 10).width == 0)
    // Given a clock, Then tasks keep their start and lose its width
    let withClock = taskSlot(barWidth: 1000, pinnedWidth: 96, clockWidth: 100)
    check("taskSlot_withClock_endsBeforeIt", withClock.x == 144 && withClock.width == 756)
    check("taskSlot_withClockWiderThanTheRoomLeft_hasNoWidth", taskSlot(barWidth: 100, clockWidth: 100).width == 0)

    // Given a width where the full bar would still fit but the width left doesn't
    check("entryWidth_ofWidthLeft_isAnEqualShareOfIt",
          entryWidth(barWidth: slot.width, entryCount: 8) == EntryWidth(width: 119, isIconOnly: false))
    let counts: [(pid: Int32, count: Int)] = [(1, 5), (2, 3)]
    check("appsToGroup_whenFullOfWholeBar_groupsNothing",
          appsToGroup(windowCounts: counts, barWidth: 1000, mode: .whenFull, minEntryWidth: 120).isEmpty)
    check("appsToGroup_whenFullOfWidthLeft_groups",
          appsToGroup(windowCounts: counts, barWidth: slot.width, mode: .whenFull, minEntryWidth: 120) == [1])
}

// listApplications
do {
    // Given a folder with two apps, a non-app, and a Utilities subfolder holding an app
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("ionized-bar-checks-\(UUID().uuidString)")
    let fm = FileManager.default
    for dir in ["Zed.app", "alpha.app", "notes.txt", "Utilities/Terminal.app", "Utilities/Deep/Hidden.app", ".Secret.app"] {
        try? fm.createDirectory(at: root.appendingPathComponent(dir), withIntermediateDirectories: true)
    }
    defer { try? fm.removeItem(at: root) }
    // When listing it with a missing folder
    let apps = listApplications(in: [root, root.appendingPathComponent("missing")])
    // Then apps come sorted by name, without the extension, and only one Utilities level
    check("listApplications_sortsByNameAndIncludesUtilities", apps.map(\.name) == ["alpha", "Terminal", "Zed"])

    // Given a bundle declaring a category, and one whose Info.plist is broken
    let plistURL = { (app: String) in root.appendingPathComponent(app).appendingPathComponent("Contents/Info.plist") }
    try? fm.createDirectory(at: plistURL("Zed.app").deletingLastPathComponent(), withIntermediateDirectories: true)
    try? fm.createDirectory(at: plistURL("alpha.app").deletingLastPathComponent(), withIntermediateDirectories: true)
    let plist = try? PropertyListSerialization.data(fromPropertyList: ["LSApplicationCategoryType": "public.app-category.developer-tools"], format: .xml, options: 0)
    try? plist?.write(to: plistURL("Zed.app"))
    try? Data("not a plist".utf8).write(to: plistURL("alpha.app"))
    // When listing it
    let categories = Dictionary(uniqueKeysWithValues: listApplications(in: [root]).map { ($0.name, $0.category) })
    // Then the declared one is read, and a broken or missing plist gives Other
    check("listApplications_readsTheDeclaredCategory", categories["Zed"] == .development)
    check("listApplications_ofBrokenOrMissingPlist_givesOther", categories["alpha"] == .other && categories["Terminal"] == .other)
}

// AppCategory
do {
    let category = { (name: String) in AppCategory(categoryType: "public.app-category.\(name)") }
    check("init_ofDeveloperTools_isDevelopment", category("developer-tools") == .development)
    check("init_ofEducationGroup_isEducation", ["education", "reference", "books"].allSatisfy { category($0) == .education })
    check("init_ofGameSubcategories_isGames", ["games", "board-games", "action-games"].allSatisfy { category($0) == .games })
    check("init_ofGraphicsGroup_isGraphics", ["graphics-design", "photography"].allSatisfy { category($0) == .graphics })
    check("init_ofInternetGroup_isInternet", ["social-networking", "news"].allSatisfy { category($0) == .internet })
    check("init_ofMultimediaGroup_isMultimedia", ["music", "video", "entertainment"].allSatisfy { category($0) == .multimedia })
    check("init_ofOfficeGroup_isOffice", ["productivity", "business", "finance"].allSatisfy { category($0) == .office })
    check("init_ofUtilities_isUtilities", category("utilities") == .utilities)
    check("init_ofUnknownOrMissing_isOther", category("travel") == .other && AppCategory(categoryType: nil) == .other && AppCategory(categoryType: "junk") == .other)
}

// LauncherList
do {
    let app = { (name: String, path: String) in InstalledApp(name: name, url: URL(fileURLWithPath: path)) }
    let safari = app("Safari", "/Applications/Safari.app")
    let slack = app("Slack", "/Applications/Slack.app")
    let notes = app("Notes", "/System/Applications/Notes.app")

    // Given no apps read yet
    var list = LauncherList()
    // Then nothing is selected, and moving does nothing
    list.moveSelection(by: 1)
    check("LauncherList_whenEmpty_selectsNothing", list.selected == nil && list.selectedIndex == nil)

    // When the apps arrive
    list.setApps([notes, safari, slack])
    // Then all show, with the top row selected
    check("setApps_withEmptyQuery_listsAllAndSelectsTop", list.rows == [notes, safari, slack] && list.selected == notes)

    // When moving past either end
    list.moveSelection(by: -1)
    check("moveSelection_aboveTop_staysOnTop", list.selectedIndex == 0)
    list.moveSelection(by: 1)
    check("moveSelection_down_selectsNextRow", list.selected == safari)
    list.moveSelection(by: 1)
    list.moveSelection(by: 1)
    check("moveSelection_belowBottom_staysOnBottom", list.selected == slack)

    // When a fresh read arrives with the selected app still in it, and an app above it gone
    let zoom = app("Zoom", "/Applications/Zoom.app")
    list.setApps([safari, slack, zoom])
    // Then the selection stays on that app, even if its row moved
    check("setApps_withSelectedAppStillListed_keepsItSelected", list.selected == slack && list.selectedIndex == 1)

    // When it arrives without the selected app
    list.setApps([notes, safari])
    check("setApps_withoutSelectedApp_selectsTop", list.selectedIndex == 0)

    // When the same name is in two folders: the URL tells them apart
    let otherNotes = app("Notes", "/Users/me/Applications/Notes.app")
    list.setApps([notes, otherNotes])
    list.moveSelection(by: 1)
    list.setApps([otherNotes, notes])
    check("setApps_withRepeatedName_keepsSelectionByURL", list.selected == otherNotes && list.selectedIndex == 0)

    // When the query changes
    list.setApps([notes, safari, slack])
    list.moveSelection(by: 2)
    list.setQuery("saf")
    // Then rows are filtered, and the selection goes back to the top row
    check("setQuery_filtersAndSelectsTop", list.rows == [safari] && list.selected == safari)

    // When apps arrive while a query is typed
    list.setApps([notes, safari, slack, app("Safari Preview", "/Applications/Safari Preview.app")])
    check("setApps_withQuery_keepsFiltering", list.rows.map(\.name) == ["Safari", "Safari Preview"])

    // When nothing matches
    list.setQuery("qqqq")
    list.moveSelection(by: 1)
    // Then there is nothing to open
    check("setQuery_withNoMatch_selectsNothing", list.rows.isEmpty && list.selected == nil)

    // When the query is cleared
    list.setQuery("")
    check("setQuery_empty_listsAllAndSelectsTop", list.rows.count == 4 && list.selectedIndex == 0)
}

// LauncherList: no-match state and VoiceOver announcement
do {
    let apps = ["Calculator", "Mail", "Safari"].map { InstalledApp(name: $0, url: URL(fileURLWithPath: "/fake/\($0).app")) }
    var list = LauncherList()
    // Given no list read yet and no query
    // Then that isn't a failed search
    check("hasNoMatch_beforeTheListIsRead_isFalse", !list.hasNoMatch)
    list.setApps(apps)
    // When listing everything
    check("hasNoMatch_withNoQuery_isFalse", !list.hasNoMatch)
    check("resultsAnnouncement_ofSeveralRows_givesCountAndSelection", list.resultsAnnouncement == "3 applications, Calculator selected")
    // When one row matches
    list.setQuery("safari")
    check("hasNoMatch_withMatches_isFalse", !list.hasNoMatch)
    check("resultsAnnouncement_ofOneRow_isSingular", list.resultsAnnouncement == "1 application, Safari selected")
    // When nothing matches
    list.setQuery("zzzzqqq")
    check("hasNoMatch_withNoRows_isTrue", list.hasNoMatch)
    check("resultsAnnouncement_ofNoRows_saysSo", list.resultsAnnouncement == LauncherList.noMatchMessage)
}

// LauncherList: views
do {
    let app = { (name: String, category: AppCategory) in InstalledApp(name: name, url: URL(fileURLWithPath: "/fake/\(name).app"), category: category) }
    let xcode = app("Xcode", .development)
    let chrome = app("Chrome", .other)
    let notes = app("Notes", .office)
    let finder = app("Finder", .other)
    var list = LauncherList()
    list.setApps([chrome, notes, xcode])

    // Given nothing pinned, When opening, Then All Applications shows
    list.reset(favorites: [])
    check("reset_withoutFavorites_opensAllApplications", list.view == .all && list.rows == [chrome, notes, xcode] && !list.showsGrid)

    // Given pins, one outside the listed apps, When opening, Then they show as a grid, in pinning order
    list.reset(favorites: [finder, xcode])
    check("reset_withFavorites_opensFavoritesAsGrid", list.view == .favorites && list.rows == [finder, xcode] && list.showsGrid && list.selected == finder)

    // Then the sidebar has the two fixed views and only the groups with apps, in order, with Other last
    check("sidebarItems_hideEmptyGroupsAndKeepOtherLast", list.sidebarItems == [.favorites, .all, .category(.development), .category(.office), .category(.other)])
    check("title_namesTheView", LauncherView.all.title == "All Applications" && LauncherView.category(.office).title == "Office")

    // When picking a group, Then only its apps show, as a list
    list.setView(.category(.office))
    check("setView_ofCategory_listsItsAppsOnly", list.rows == [notes] && list.selected == notes && !list.showsGrid)

    // When searching from a group, Then all apps are searched, and clearing returns to the group
    list.setQuery("xcode")
    check("setQuery_fromCategory_searchesAllApps", list.rows == [xcode])
    list.setQuery("")
    check("setQuery_cleared_returnsToTheView", list.view == .category(.office) && list.rows == [notes])

    // When searching from Favorites, Then the results are a list, not a grid
    list.reset(favorites: [xcode])
    list.setQuery("notes")
    check("setQuery_fromFavorites_showsAList", list.rows == [notes] && !list.showsGrid)

    // When picking a view during a search, Then the search ends
    list.setView(.all)
    check("setView_clearsTheQuery", list.query.isEmpty && list.rows == [chrome, notes, xcode])

    // When a fresh read drops the last app of the current group, Then the list falls back to all apps
    list.setView(.category(.development))
    list.setApps([chrome, notes])
    check("setApps_withoutTheViewsGroup_fallsBackToAll", list.view == .all && list.rows == [chrome, notes])

    // When reopening after a search, Then the query is gone
    list.setQuery("notes")
    list.reset(favorites: [])
    check("reset_clearsTheQuery", list.query.isEmpty && list.rows == [chrome, notes])

    // Given Favorites with no pins, Then that is neither a failed search nor announced as one
    list.setView(.favorites)
    check("hasNoFavorites_ofEmptyFavorites_isTrue", list.hasNoFavorites && !list.hasNoMatch && list.resultsAnnouncement == LauncherList.noFavoritesMessage)
    check("viewAnnouncement_ofEmptyFavorites_saysHowToPin", list.viewAnnouncement == "Favorites, \(LauncherList.noFavoritesMessage)")
    list.setQuery("notes")
    check("hasNoFavorites_whileSearching_isFalse", !list.hasNoFavorites)
    list.setView(.all)
    check("viewAnnouncement_ofSeveralRows_givesTitleAndCount", list.viewAnnouncement == "All Applications, 2 applications")
    list.setView(.category(.office))
    check("viewAnnouncement_ofOneRow_isSingular", list.viewAnnouncement == "Office, 1 application")

    // Given Office showing, When resting the pointer on a sidebar row, Then only another view is a target
    check("hoverTarget_ofAnotherRow_returnsItsView", list.hoverTarget(sidebarRow: 1) == .all)
    check("hoverTarget_ofCurrentView_returnsNil", list.hoverTarget(sidebarRow: 2) == nil)
    check("hoverTarget_ofRowOutsideTheSidebar_returnsNil", list.hoverTarget(sidebarRow: -1) == nil && list.hoverTarget(sidebarRow: list.sidebarItems.count) == nil)

    // Given a search, When resting the pointer on another view, Then the search stays
    list.setQuery("notes")
    check("hoverTarget_duringASearch_returnsNil", list.hoverTarget(sidebarRow: 1) == nil)
}

// LauncherList: hover and grid movement
do {
    let apps = (0..<7).map { InstalledApp(name: "App\($0)", url: URL(fileURLWithPath: "/fake/\($0).app")) }
    var list = LauncherList()
    list.setApps(apps)

    // When the pointer is over a row, Then it is the selection
    list.select(index: 3)
    check("select_ofRow_movesTheSelection", list.selectedIndex == 3)
    // When the pointer is over nothing, Then the selection stays
    list.select(index: -1)
    list.select(index: 7)
    check("select_outOfRange_keepsTheSelection", list.selectedIndex == 3)

    // Given 7 items in 3 columns: 0 1 2 / 3 4 5 / 6
    list.reset(favorites: apps)
    list.moveGridSelection(byRows: -1, columns: 3)
    check("moveGridSelection_upFromFirstRow_stays", list.selectedIndex == 0)
    list.moveGridSelection(byRows: 1, columns: 3)
    check("moveGridSelection_down_keepsTheColumn", list.selectedIndex == 3)
    list.select(index: 5)
    list.moveGridSelection(byRows: 1, columns: 3)
    check("moveGridSelection_downWithNothingBelow_goesToTheLastItem", list.selectedIndex == 6)
    list.moveGridSelection(byRows: 1, columns: 3)
    check("moveGridSelection_downFromLastRow_stays", list.selectedIndex == 6)
    list.moveGridSelection(byRows: -1, columns: 3)
    check("moveGridSelection_up_keepsTheColumn", list.selectedIndex == 3)
}

// launcherFrame
do {
    let screen = CGRect(x: 1000, y: 0, width: 1000, height: 800)
    let size = CGSize(width: 360, height: 420)
    // Given the button at the screen's left edge
    let button = CGRect(x: 1000, y: 0, width: 48, height: 36)
    // Then the panel is above it, on that screen, with its full size
    check("launcherFrame_ofButtonAtLeftEdge_staysOnScreenAboveIt",
          launcherFrame(button: button, size: size, screen: screen, gap: 4) == CGRect(x: 1004, y: 40, width: 360, height: 420))
    // Given a screen too short and too narrow for the panel
    let small = CGRect(x: 0, y: 0, width: 300, height: 200)
    let fitted = launcherFrame(button: CGRect(x: 0, y: 0, width: 48, height: 36), size: size, screen: small, gap: 4)
    // Then it shrinks to stay fully on screen, with the gap kept
    check("launcherFrame_onSmallScreen_shrinksToFit", fitted == CGRect(x: 4, y: 40, width: 292, height: 156))
}

// pins
do {
    // Given pins in pinning order
    let pins = ["a", "b", "c"]
    let all: Set = ["a", "b", "c"]
    check("pinning_ofNewApp_appendsLast", pinning("d", in: pins) == ["a", "b", "c", "d"])
    check("pinning_ofPinnedApp_changesNothing", pinning("b", in: pins) == pins)
    check("unpinning_removesOnlyThatApp", unpinning("b", in: pins) == ["a", "c"])
    // Setting off: only the bar with a task for the app hides its icon
    check("visiblePins_whenOffAndTaskOnThisBar_hidesIt",
          visiblePins(pins, keepsVisible: false, taskBundleIDs: ["b"], installedBundleIDs: all) == ["a", "c"])
    check("visiblePins_whenOffAndTaskOnAnotherBarOnly_keepsIt",
          visiblePins(pins, keepsVisible: false, taskBundleIDs: [], installedBundleIDs: all) == pins)
    check("visiblePins_whenOffAndRunningWithNoWindows_keepsIt",
          visiblePins(pins, keepsVisible: false, taskBundleIDs: ["x"], installedBundleIDs: all) == pins)
    // Setting on: always visible, even with a task here
    check("visiblePins_whenOn_keepsItWithATask",
          visiblePins(pins, keepsVisible: true, taskBundleIDs: ["a", "b", "c"], installedBundleIDs: all) == pins)
    // Uninstalled: hidden in both modes, and the saved list is untouched
    check("visiblePins_ofUninstalledApp_hidesItWhenOn",
          visiblePins(pins, keepsVisible: true, taskBundleIDs: [], installedBundleIDs: ["a", "c"]) == ["a", "c"])
    check("visiblePins_ofUninstalledApp_hidesItWhenOff",
          visiblePins(pins, keepsVisible: false, taskBundleIDs: [], installedBundleIDs: ["a", "c"]) == ["a", "c"])
}

// movingPin
do {
    // Given every pin shown on the bar
    let pins = ["a", "b", "c", "d"]
    check("movingPin_toTheRight_landsAfterThePinPassed",
          movingPin(in: pins, shown: pins, from: 0, to: 2) == ["b", "c", "a", "d"])
    check("movingPin_toTheLeft_landsBeforeThePinPassed",
          movingPin(in: pins, shown: pins, from: 3, to: 1) == ["a", "d", "b", "c"])
    // Given "b" hidden on this bar, Then it stays where it is relative to the pins that don't move
    check("movingPin_withHiddenPins_keepsThemInPlace",
          movingPin(in: pins, shown: ["a", "c", "d"], from: 2, to: 1) == ["a", "b", "d", "c"]
          && movingPin(in: pins, shown: ["a", "c", "d"], from: 0, to: 1) == ["b", "c", "a", "d"])
    check("movingPin_toItsOwnPlace_changesNothing", movingPin(in: pins, shown: pins, from: 1, to: 1) == pins)
    check("movingPin_ofIndexOutOfRange_changesNothing",
          movingPin(in: pins, shown: pins, from: 4, to: 0) == pins && movingPin(in: pins, shown: pins, from: 0, to: 4) == pins)
    // Given a pin removed since the bar last showed it, Then it doesn't come back
    check("movingPin_ofPinNoLongerSaved_changesNothing",
          movingPin(in: ["a", "b"], shown: ["a", "b", "x"], from: 2, to: 0) == ["a", "b"])
    // Given a pin passed that was removed since, Then there is nothing to land next to
    check("movingPin_pastPinNoLongerSaved_changesNothing",
          movingPin(in: ["a", "b"], shown: ["a", "x", "b"], from: 0, to: 1) == ["a", "b"])
}

// pinMenuTitle
do {
    // Given an app that is not pinned, then one that is
    check("pinMenuTitle_ofUnpinnedApp_isPin", pinMenuTitle(bundleID: "a", pins: ["b"]) == "Pin")
    check("pinMenuTitle_ofPinnedApp_isUnpin", pinMenuTitle(bundleID: "b", pins: ["a", "b"]) == "Unpin")
    // Given an app with no bundle identifier: nothing to pin, so no item
    check("pinMenuTitle_withNoBundleID_isNil", pinMenuTitle(bundleID: nil, pins: ["a"]) == nil)
}

// pinnedIconWidth
do {
    // Given two pinned icons of about 36pt, Then tasks start after them and pins never shrink, even with no width left
    let slot = taskSlot(barWidth: 1000, pinnedWidth: 2 * pinnedIconWidth)
    check("pinnedIconWidth_isAbout36Points", pinnedIconWidth == 36)
    check("taskSlot_withTwoPinnedIcons_startsAfterThem", slot.x == 120 && slot.width == 880)
    check("taskSlot_withMorePinsThanFit_hasNoWidth", taskSlot(barWidth: 100, pinnedWidth: 3 * pinnedIconWidth).width == 0)
}

// TaskOrder
do {
    typealias Task = (pid: Int32, name: String)
    // The name's first character stands for the app: "a1" and "a2" are windows of the same app.
    func tasks(_ names: String) -> [Task] {
        names.split(separator: " ").map { (Int32($0.first!.asciiValue!), String($0)) }
    }
    func seeing(_ names: String, alive: String? = nil) -> TaskOrder<String> {
        var order = TaskOrder<String>()
        order.update(seen: tasks(names).map(\.name), alive: Set(tasks(alive ?? names).map(\.name)))
        return order
    }
    func items(_ order: TaskOrder<String>, _ names: String, mode: GroupingMode = .never, barWidth: CGFloat = 1000) -> [BarItem<Task>] {
        barItems(order.sorted(tasks(names), key: \.name), pid: \.pid, barWidth: barWidth, mode: mode, minEntryWidth: 100)
    }
    func shown(_ order: TaskOrder<String>, _ names: String, mode: GroupingMode = .never) -> String {
        items(order, names, mode: mode).map { $0.windows.map(\.name).joined(separator: "+") }.joined(separator: " ")
    }
    func moving(_ order: TaskOrder<String>, on names: String, mode: GroupingMode = .never, from: Int, to: Int) -> TaskOrder<String> {
        var moved = order
        moved.move(items(order, names, mode: mode), from: from, to: to, key: \.name)
        return moved
    }

    // Given no move yet, Then windows keep the order they were first seen in
    check("sorted_withNoMove_keepsFirstSeenOrder", shown(seeing("a b c"), "c a b") == "a b c")

    // Given a b c d, When moving a window right and left, Then it lands at that index
    let moved = moving(seeing("a b c d"), on: "a b c d", from: 0, to: 2)
    check("move_ofWindowToTheRight_landsAtIndex", shown(moved, "a b c d") == "b c a d")
    check("move_ofWindowToTheLeft_landsAtIndex", shown(moving(seeing("a b c d"), on: "a b c d", from: 3, to: 1), "a b c d") == "a d b c")

    // Given a re-ordered bar, When a window opens, Then it goes last, even after a window moved to the end
    var withNew = moved
    withNew.update(seen: ["a", "b", "c", "d", "e"], alive: ["a", "b", "c", "d", "e"])
    check("update_ofNewWindow_goesLast", shown(withNew, "a b c d e") == "b c a d e")
    var withNewAfterEnd = moving(seeing("a b c"), on: "a b c", from: 0, to: 2)
    withNewAfterEnd.update(seen: ["a", "b", "c", "d"], alive: ["a", "b", "c", "d"])
    check("update_ofNewWindowAfterMoveToEnd_goesLast", shown(withNewAfterEnd, "a b c d") == "b c a d")

    // Given b left (another Space or display) and alive, When others move and return, Then b keeps its place
    var returning = seeing("a b c d")
    returning.update(seen: ["a", "c", "d"], alive: ["a", "b", "c", "d"])
    check("update_ofAliveWindowLeaving_keepsIt", returning.keys.contains("b"))
    returning = moving(returning, on: "a c d", from: 2, to: 0)
    check("move_withAWindowAway_movesTheOthers", shown(returning, "a c d") == "d a c")
    returning.update(seen: ["a", "b", "c", "d"], alive: ["a", "b", "c", "d"])
    check("update_ofReturningWindow_keepsItsPlaceAmongTheUnmoved", shown(returning, "a b c d") == "d a b c")

    // Given b away and its neighbour c closed, When b returns, Then it's still after a and before d
    var neighbourClosed = seeing("a b c d")
    neighbourClosed.update(seen: ["a", "c", "d"], alive: ["a", "b", "c", "d"])
    neighbourClosed.update(seen: ["a", "d"], alive: ["a", "b", "d"])
    neighbourClosed.update(seen: ["a", "b", "d"], alive: ["a", "b", "d"])
    check("update_ofReturningWindow_afterNeighbourClosed_keepsItsPlace", shown(neighbourClosed, "a b d") == "a b d")

    // Given a window destroyed while away, Then its key goes
    var destroyed = seeing("a b c")
    destroyed.update(seen: ["a", "c"], alive: ["a", "c"])
    check("update_ofDestroyedWindow_dropsItsKey", destroyed.keys == ["a", "c"])
    // Given a snapshot that still lists a window already reported destroyed, Then it stays in place until it's gone
    var lagging = seeing("a b c")
    lagging.update(seen: ["a", "b", "c"], alive: ["a", "c"])
    check("update_ofListedWindowNotAlive_keepsItsPlace", lagging.keys == ["a", "b", "c"])

    // Given a mover past either end, Then it clamps; dropped where it started, nothing changes
    check("move_pastTheRightEnd_clamps", shown(moving(seeing("a b c"), on: "a b c", from: 0, to: 99), "a b c") == "b c a")
    check("move_pastTheLeftEnd_clamps", shown(moving(seeing("a b c"), on: "a b c", from: 2, to: -5), "a b c") == "c a b")
    // Given a mover already at the end it's pushed past, or no items at all, Then nothing changes
    check("move_ofLastPastTheRightEnd_changesNothing", moving(seeing("a b c"), on: "a b c", from: 2, to: 99).keys == ["a", "b", "c"])
    check("move_ofFirstPastTheLeftEnd_changesNothing", moving(seeing("a b c"), on: "a b c", from: 0, to: -5).keys == ["a", "b", "c"])
    check("move_withNoItems_changesNothing", moving(seeing("a b"), on: "", from: 0, to: 0).keys == ["a", "b"])
    let interleaved = seeing("a1 b a2 c")
    check("move_toWhereItStarted_changesNothing", moving(interleaved, on: "a1 b a2 c", mode: .always, from: 0, to: 0).keys == interleaved.keys)

    // Given a group whose windows interleave with b, When moving the group, Then it moves as one and its list keeps its order
    let groupMoved = moving(interleaved, on: "a1 b a2 c", mode: .always, from: 0, to: 2)
    check("move_ofGroup_movesAsOne", shown(groupMoved, "a1 b a2 c", mode: .always) == "b c a1+a2")
    check("move_ofGroupToTheLeft_movesAsOne", shown(moving(seeing("b a1 c a2"), on: "b a1 c a2", mode: .always, from: 1, to: 0), "b a1 c a2", mode: .always) == "a1+a2 b c")
    // Then ungrouping leaves its windows next to each other, where the group was
    check("move_ofGroup_staysAdjacentWhenUngrouped", shown(groupMoved, "a1 b a2 c", mode: .never) == "b c a1 a2")
    // Given When full on a narrow bar, When moving the group, Then the mode change to Never keeps its windows adjacent
    let whenFull = items(interleaved, "a1 b a2 c", mode: .whenFull, barWidth: 300)
    var acrossModes = interleaved
    acrossModes.move(whenFull, from: 0, to: 1, key: \.name)
    check("move_ofGroupWhenFull_staysAdjacentWithNever", whenFull.count == 3 && shown(acrossModes, "a1 b a2 c", mode: .never) == "b a1 a2 c")

    // Given a group that interleaves with c, When moving b past the group, Then b lands right after it, ahead of c
    let pastGroup = moving(seeing("b a1 c a2"), on: "b a1 c a2", mode: .always, from: 0, to: 1)
    check("move_pastInterleavedGroup_landsRightAfterIt", shown(pastGroup, "b a1 c a2", mode: .always) == "a1+a2 b c")
    // Given a group moved as one, When a window passes it either way, Then the group's windows aren't split
    let passed = moving(groupMoved, on: "a1 b a2 c", mode: .always, from: 0, to: 2)
    check("move_pastMovedGroup_keepsItAdjacent", shown(passed, "a1 b a2 c", mode: .never) == "c a1 a2 b")
    check("move_beforeMovedGroup_keepsItAdjacent", shown(moving(passed, on: "a1 b a2 c", mode: .always, from: 2, to: 1), "a1 b a2 c", mode: .never) == "c b a1 a2")

    // Given two bars sharing one order, When moving on bar 1, Then bar 2 doesn't change, even interleaved in the list
    let twoBars = moving(seeing("a x b y c z"), on: "a b c", from: 2, to: 0)
    check("move_onOneBar_movesThere", shown(twoBars, "a b c") == "c a b")
    check("move_onOneBar_leavesTheOtherBarAlone", shown(twoBars, "x y z") == "x y z")
    let bothMoved = moving(twoBars, on: "x y z", from: 0, to: 2)
    check("move_onTheOtherBar_leavesThisBarAlone", shown(bothMoved, "a b c") == "c a b" && shown(bothMoved, "x y z") == "y z x")
    // Given b sent to bar 2, When bar 2 re-orders around it and b comes back, Then it's in its place on bar 1
    let whileOnBar2 = moving(twoBars, on: "x b y z", from: 3, to: 0)
    check("move_ofWindowOnAnotherBar_movesThereOnly", shown(whileOnBar2, "x b y z") == "z x b y")
    check("sorted_ofWindowBackFromAnotherBar_keepsItsPlace", shown(whileOnBar2, "a b c") == "c a b")

    // Given stale items whose window is gone, When moving, Then the order doesn't change
    var stale = seeing("a b c")
    let staleItems = items(stale, "a b c")
    stale.update(seen: ["a", "b"], alive: ["a", "b"])
    let beforeStale = stale.keys
    stale.move(staleItems, from: 0, to: 2, key: \.name)
    check("move_ontoAGoneWindow_changesNothing", stale.keys == beforeStale)
    // Given a mover, or a passed group's other window, closed since the items were built, Then neither comes back
    stale.move(staleItems, from: 2, to: 0, key: \.name)
    check("move_ofAGoneWindow_changesNothing", stale.keys == beforeStale)
    var staleGroup = seeing("b a1 a2 c")
    let staleGroupItems = items(staleGroup, "b a1 a2 c", mode: .always)
    staleGroup.update(seen: ["b", "a1", "c"], alive: ["b", "a1", "c"])
    staleGroup.move(staleGroupItems, from: 0, to: 1, key: \.name)
    check("move_pastGroupWithAGoneWindow_changesNothing", staleGroup.keys == ["b", "a1", "c"])

    // Given an app listing a window twice, When moving it, Then nothing traps
    check("move_ofGroupWithDuplicateWindow_movesIt", shown(moving(seeing("f e e"), on: "f e e", mode: .always, from: 1, to: 0), "f e e", mode: .always) == "e+e f")
    check("move_ontoItsOwnDuplicate_changesNothing", moving(seeing("e e f"), on: "e e f", from: 1, to: 0).keys == ["e", "f"])
}

// Dragging an entry
do {
    // Given a press, Then a slip of up to 4pt stays a click, in any direction
    let press = CGPoint(x: 100, y: 10)
    check("isPastDragThreshold_ofNoMove_isFalse", !isPastDragThreshold(from: press, to: press))
    check("isPastDragThreshold_of4ptSlip_isFalse", !isPastDragThreshold(from: press, to: CGPoint(x: 104, y: 10)))
    check("isPastDragThreshold_of4ptDiagonalSlip_isFalse", !isPastDragThreshold(from: press, to: CGPoint(x: 98, y: 13)))
    check("isPastDragThreshold_ofMoveRight_isTrue", isPastDragThreshold(from: press, to: CGPoint(x: 105, y: 10)))
    check("isPastDragThreshold_ofMoveLeft_isTrue", isPastDragThreshold(from: press, to: CGPoint(x: 95, y: 10)))
    check("isPastDragThreshold_ofMoveAcross_isTrue", isPastDragThreshold(from: press, to: CGPoint(x: 100, y: 5)))
    check("isPastDragThreshold_ofDiagonalMove_isTrue", isPastDragThreshold(from: press, to: CGPoint(x: 104, y: 14)))

    // Given 4 entries of 100pt after a launcher and pins at 148, one grabbed 30pt into it
    func x(_ pointerX: CGFloat, grab: CGFloat = 30, width: CGFloat = 100, count: Int = 4) -> CGFloat {
        draggedEntryX(pointerX: pointerX, grabOffset: grab, slotX: 148, entryWidth: width, entryCount: count)
    }
    check("draggedEntryX_followsThePointer", x(300) == 270)
    // Past the end slots the entry keeps following, with resistance, and never goes a full entry width past
    check("draggedEntryX_beforeTheFirstSlot_rubberBands", x(100) < 148 && x(100) > 48 && x(0) < x(100) && x(0) > 48)
    check("draggedEntryX_pastTheLastSlot_rubberBands", x(500) > 448 && x(500) < 548 && x(5000) > x(500) && x(5000) < 548)
    check("draggedEntryX_justPastTheEnd_followsThePointerClosely", abs(x(490) - 458) < 4)
    // Given icon only, packed left: the end is the last entry's slot, not the bar's end
    check("draggedEntryX_whenPackedLeft_rubberBandsPastTheLastEntry", x(5000, grab: 10, width: 48, count: 3) > 244 && x(5000, grab: 10, width: 48, count: 3) < 292)
    check("draggedEntryX_ofOneEntry_rubberBandsBothWays", x(5000, count: 1) > 148 && x(5000, count: 1) < 248 && x(0, count: 1) < 148 && x(0, count: 1) > 48)
    check("draggedEntryX_ofZeroWidthEntries_stopsAtTheStart", x(5000, grab: 0, width: 0, count: 4) == 148)
    // Given a window opening mid-drag narrows the entries, Then the pointer stays on the entry
    check("draggedEntryX_whenEntryNarrowedPastTheGrab_keepsThePointerOnIt", x(300, grab: 90, width: 50) == 250)

    func index(_ entryX: CGFloat, from: Int = 1, width: CGFloat = 100, count: Int = 4) -> Int {
        dragTargetIndex(entryX: entryX, from: from, slotX: 148, entryWidth: width, entryCount: count)
    }
    check("dragTargetIndex_atItsSlot_isItsIndex", index(248) == 1)
    check("dragTargetIndex_underHalfWayRight_staysPut", index(297) == 1)
    check("dragTargetIndex_pastHalfWayRight_isTheNext", index(299) == 2)
    check("dragTargetIndex_underHalfWayLeft_staysPut", index(199) == 1)
    check("dragTargetIndex_pastHalfWayLeft_isThePrevious", index(197) == 0)
    check("dragTargetIndex_farRight_reachesTheLast", index(448, from: 0) == 3)
    check("dragTargetIndex_farLeft_reachesTheFirst", index(148, from: 3) == 0)
    check("dragTargetIndex_pastTheRightEnd_isTheLast", index(1_000_000) == 3)
    check("dragTargetIndex_pastTheLeftEnd_isTheFirst", index(-1_000_000) == 0)
    check("dragTargetIndex_ofOneEntry_isZero", index(1000, from: 0, count: 1) == 0 && index(-1000, from: 0, count: 1) == 0)
    check("dragTargetIndex_ofZeroWidthEntries_staysPut", index(500, from: 2, width: 0) == 2)
    check("dragTargetIndex_ofNoEntries_staysPut", index(500, from: 0, width: 0, count: 0) == 0)

    // Given a group entry, When dropped where the index says, Then it moves as one
    typealias Task = (pid: Int32, name: String)
    let tasks: [Task] = [(1, "b"), (2, "a1"), (2, "a2"), (3, "c")]
    var order = TaskOrder<String>()
    order.update(seen: tasks.map(\.name), alive: Set(tasks.map(\.name)))
    let items = barItems(order.sorted(tasks, key: \.name), pid: \.pid, barWidth: 300, mode: .always, minEntryWidth: 100)
    let to = dragTargetIndex(entryX: draggedEntryX(pointerX: 5000, grabOffset: 0, slotX: 48, entryWidth: 100, entryCount: items.count), from: 1, slotX: 48, entryWidth: 100, entryCount: items.count)
    order.move(items, from: 1, to: to, key: \.name)
    check("dragTargetIndex_ofGroupEntryToTheEnd_movesItsWindowsAsOne", order.keys == ["b", "c", "a1", "a2"])
}

// clockText
do {
    // Given 2026-11-04 14:09:05 UTC, read in UTC
    let utc = TimeZone(identifier: "UTC")!
    let afternoon = Date(timeIntervalSince1970: 1793801345)
    let french = Locale(identifier: "fr_FR")
    let american = Locale(identifier: "en_US")
    func text(_ settings: ClockSettings, _ date: Date = afternoon, locale: Locale = french, timeZone: TimeZone = utc) -> (time: String, date: String?) {
        clockText(date: date, settings: settings, locale: locale, timeZone: timeZone)
    }
    // ICU separates the time from AM/PM with a narrow no-break space, depending on the locale's data.
    func plain(_ string: String) -> String { string.replacingOccurrences(of: "\u{202F}", with: " ") }

    // When formatting the time, Then each format gives its form, with and without seconds
    check("clockText_of24Hour_isZeroPadded", text(.init(timeFormat: .twentyFourHour)).time == "14:09")
    check("clockText_of24HourWithSeconds_addsThem", text(.init(showsSeconds: true, timeFormat: .twentyFourHour)).time == "14:09:05")
    check("clockText_of12Hour_hasNoLeadingZero", plain(text(.init(timeFormat: .twelveHour), locale: american).time) == "2:09 PM")
    check("clockText_of12HourWithSeconds_addsThem",
          plain(text(.init(showsSeconds: true, timeFormat: .twelveHour), locale: american).time) == "2:09:05 PM")
    check("clockText_of12Hour_overridesA24HourLocale", plain(text(.init(timeFormat: .twelveHour)).time).hasPrefix("2:09 "))
    check("clockText_of24Hour_overridesA12HourLocale", text(.init(timeFormat: .twentyFourHour), locale: american).time == "14:09")
    check("clockText_ofSystemTime_followsTheLocale", text(.init()).time == "14:09")
    check("clockText_ofSystemTimeWithSeconds_followsTheLocale", text(.init(showsSeconds: true)).time == "14:09:05")
    check("clockText_ofSystemTimeIn12HourLocale_followsTheLocale", plain(text(.init(), locale: american).time) == "2:09 PM")

    // Given midnight and noon, When in 12-hour, Then they read 12 rather than 0
    let midnight = Date(timeIntervalSince1970: 1793836800)
    check("clockText_of12HourMidnight_is12AM", plain(text(.init(timeFormat: .twelveHour), midnight, locale: american).time) == "12:00 AM")
    check("clockText_of12HourNoon_is12PM",
          plain(text(.init(timeFormat: .twelveHour), midnight.addingTimeInterval(43200), locale: american).time) == "12:00 PM")
    check("clockText_of24HourMidnight_is00", text(.init(timeFormat: .twentyFourHour), midnight).time == "00:00")

    // When the date is off, Then there is none, whatever its format
    check("clockText_withDateOff_hasNoDate", text(.init(dateFormat: .iso)).date == nil)

    // When the date is on, Then each format gives its form
    check("clockText_ofIsoDate_isYearFirst", text(.init(showsDate: true, dateFormat: .iso)).date == "2026-11-04")
    check("clockText_ofDayMonthYear_isDayFirst", text(.init(showsDate: true, dateFormat: .dayMonthYear), locale: american).date == "04/11/2026")
    check("clockText_ofSystemDate_followsTheLocale", text(.init(showsDate: true)).date == "04/11/2026")

    // Given a locale with another calendar or other digits, Then the fixed formats don't follow it
    let thai = Locale(identifier: "th_TH")
    let arabic = Locale(identifier: "ar_SA")
    check("clockText_ofIsoDate_ignoresTheLocaleCalendar", text(.init(showsDate: true, dateFormat: .iso), locale: thai).date == "2026-11-04")
    check("clockText_ofDayMonthYear_ignoresTheLocaleCalendar", text(.init(showsDate: true, dateFormat: .dayMonthYear), locale: thai).date == "04/11/2026")
    check("clockText_ofIsoDate_ignoresTheLocaleDigits", text(.init(showsDate: true, dateFormat: .iso), locale: arabic).date == "2026-11-04")

    // Given another time zone, Then the time and the date are the local ones
    let tokyo = TimeZone(identifier: "Asia/Tokyo")!
    let lateEvening = Date(timeIntervalSince1970: 1793833200)
    let inTokyo = text(.init(timeFormat: .twentyFourHour, showsDate: true, dateFormat: .iso), lateEvening, timeZone: tokyo)
    check("clockText_inAnotherTimeZone_isLocal", inTokyo.time == "08:00" && inTokyo.date == "2026-11-05")

    // Given the sample used for measuring, Then it has two digits everywhere
    let widest = text(.init(showsSeconds: true, timeFormat: .twentyFourHour, showsDate: true, dateFormat: .iso), clockWidestDate)
    check("clockWidestDate_hasTwoDigitsEverywhere", widest.time == "22:58:58" && widest.date == "2026-12-28")
    check("clockWidestDate_in12Hour_hasATwoDigitHour",
          plain(text(.init(timeFormat: .twelveHour), clockWidestDate, locale: american).time) == "10:58 PM")
}

// clockAccessibilityLabel
do {
    // Given a date shown in a numeric format, When read by VoiceOver, Then the date is spelled out
    let afternoon = Date(timeIntervalSince1970: 1793801345)
    let label = clockAccessibilityLabel(
        date: afternoon, settings: .init(timeFormat: .twentyFourHour, showsDate: true, dateFormat: .iso),
        locale: Locale(identifier: "en_US"), timeZone: TimeZone(identifier: "UTC")!
    )
    check("clockAccessibilityLabel_spellsOutTheDate", label == "14:09, Wednesday, November 4, 2026")
    // Given no date, Then only the time is read
    let timeOnly = clockAccessibilityLabel(
        date: afternoon, settings: .init(timeFormat: .twentyFourHour),
        locale: Locale(identifier: "en_US"), timeZone: TimeZone(identifier: "UTC")!
    )
    check("clockAccessibilityLabel_withDateOff_isTheTime", timeOnly == "14:09")
}

// nextClockTick
do {
    let boundary = Date(timeIntervalSince1970: 1793887740)
    let justAfter = boundary.addingTimeInterval(0.25)
    // Given seconds shown, Then the next tick is the next whole second
    check("nextClockTick_withSeconds_ofJustAfterABoundary_isTheNextSecond",
          nextClockTick(after: justAfter, showsSeconds: true) == boundary.addingTimeInterval(1))
    check("nextClockTick_withSeconds_ofABoundary_isStrictlyAfterIt",
          nextClockTick(after: boundary, showsSeconds: true) == boundary.addingTimeInterval(1))
    // Given seconds hidden, Then the next tick is the next whole minute
    check("nextClockTick_withoutSeconds_ofJustAfterABoundary_isTheNextMinute",
          nextClockTick(after: justAfter, showsSeconds: false) == boundary.addingTimeInterval(60))
    check("nextClockTick_withoutSeconds_ofABoundary_isStrictlyAfterIt",
          nextClockTick(after: boundary, showsSeconds: false) == boundary.addingTimeInterval(60))
}

// usableArea
do {
    // Given a screen with a menu bar, When computing the area, Then the bar and the menu bar are out
    let area = usableArea(screenFrame: CGRect(x: 100, y: 0, width: 1000, height: 800), visibleFrame: CGRect(x: 100, y: 0, width: 1000, height: 770))
    check("usableArea_excludesTheBarAndTheMenuBar", area == CGRect(x: 100, y: 36, width: 1000, height: 734))
}

// anchoredOrigin
do {
    let current = CGRect(x: 600, y: 0, width: 400, height: 800)
    let target = CGRect(x: 800, y: 0, width: 200, height: 800)
    // Given a move refused by a minimum width, Then the far edge stays where it is and the window doesn't slide off
    check("anchoredOrigin_whenSizeIsRefused_keepsTheFarEdge",
          anchoredOrigin(target: target, current: current, actualSize: CGSize(width: 300, height: 800)) == CGPoint(x: 700, y: 0))
    check("anchoredOrigin_whenSizeIsAccepted_returnsTheTarget",
          anchoredOrigin(target: target, current: current, actualSize: target.size) == target.origin)
    // Given an origin that doesn't change, Then the window keeps it whatever the size it took
    let growing = CGRect(x: 600, y: 0, width: 200, height: 800)
    check("anchoredOrigin_whenOriginIsUnchanged_keepsIt",
          anchoredOrigin(target: growing, current: current, actualSize: CGSize(width: 300, height: 800)) == current.origin)
}

// JointResize
do {
    let area = CGRect(x: 0, y: 0, width: 1000, height: 800)
    let left = CGRect(x: 0, y: 0, width: 700, height: 800)
    let right = CGRect(x: 700, y: 0, width: 300, height: 800)
    let top = CGRect(x: 0, y: 0, width: 1000, height: 300)
    let bottom = CGRect(x: 0, y: 300, width: 1000, height: 500)
    func drag(_ frame: CGRect, others: [(window: String, frame: CGRect)], areas: [CGRect] = [area]) -> JointResize<String> {
        JointResize(driver: "driver", frame: frame, others: others, areas: areas)
    }

    // Given a 70/30 split, When dragging the left window's right edge, Then the right window's left edge follows
    var fromLeft = drag(left, others: [("right", right)])
    check("init_ofLeftRightSplit_follows", fromLeft.followers == ["right"])
    let followed = fromLeft.follow(driverFrame: CGRect(x: 0, y: 0, width: 600, height: 800))
    check("follow_ofLeftWindow_movesTheRightWindowsLeftEdge", followed.map(\.frame) == [CGRect(x: 600, y: 0, width: 400, height: 800)])
    // When the frame hasn't changed, Then nothing is written
    check("follow_whenFrameIsUnchanged_returnsNothing", fromLeft.follow(driverFrame: CGRect(x: 0, y: 0, width: 600, height: 800)).isEmpty)
    // When dragging back, Then the follower goes back
    check("follow_whenDraggedBack_restoresTheFollower", fromLeft.follow(driverFrame: left).map(\.frame) == [right])

    // Given the same split, When dragging the right window's left edge, Then the left window's right edge follows
    var fromRight = drag(right, others: [("left", left)])
    check("follow_ofRightWindow_movesTheLeftWindowsRightEdge",
          fromRight.follow(driverFrame: CGRect(x: 800, y: 0, width: 200, height: 800)).map(\.frame) == [CGRect(x: 0, y: 0, width: 800, height: 800)])

    // Given a top/bottom split, When dragging the shared edge, Then the other window follows
    var fromTop = drag(top, others: [("bottom", bottom)])
    check("follow_ofTopWindow_movesTheBottomWindowsTopEdge",
          fromTop.follow(driverFrame: CGRect(x: 0, y: 0, width: 1000, height: 400)).map(\.frame) == [CGRect(x: 0, y: 400, width: 1000, height: 400)])

    // Given a small gap between the windows, Then they are joint and the gap is preserved
    var withGap = drag(CGRect(x: 0, y: 0, width: 690, height: 800), others: [("right", right)])
    check("follow_whenWindowsHaveAGap_preservesIt",
          withGap.follow(driverFrame: CGRect(x: 0, y: 0, width: 590, height: 800)).map(\.frame) == [CGRect(x: 600, y: 0, width: 400, height: 800)])

    // Given two windows stacked on the other side, Then both follow; a window stacked on the driver's side doesn't
    let stacked = drag(left, others: [("right", right), ("behindRight", right), ("behindLeft", left)])
    check("init_ofStackedWindows_followsAllOnTheOtherSide", stacked.followers == ["right", "behindRight"])

    // Given windows that don't fill the area, Then they aren't joint
    check("init_whenDriverDoesNotReachTheEnd_followsNothing", drag(CGRect(x: 100, y: 0, width: 600, height: 800), others: [("right", right)]).followers.isEmpty)
    check("init_whenOtherIsNotFullHeight_followsNothing", drag(left, others: [("right", CGRect(x: 700, y: 0, width: 300, height: 400))]).followers.isEmpty)
    check("init_whenWindowsAreFarApart_followsNothing", drag(CGRect(x: 0, y: 0, width: 400, height: 800), others: [("right", right)]).followers.isEmpty)
    // Given a split on another display, Then it isn't joint across displays
    let otherArea = CGRect(x: 1000, y: 0, width: 1000, height: 800)
    check("init_ofWindowOnAnotherDisplay_followsNothing",
          drag(left, others: [("other", CGRect(x: 1000, y: 0, width: 300, height: 800))], areas: [area, otherArea]).followers.isEmpty)
    check("init_ofSplitOnSecondDisplay_follows",
          drag(CGRect(x: 1000, y: 0, width: 700, height: 800), others: [("right", CGRect(x: 1700, y: 0, width: 300, height: 800))], areas: [area, otherArea]).followers == ["right"])
    // Given frames measured on Zentty: one window under the bar, the other a text row short of the area
    let measuredArea = CGRect(x: 0, y: 40, width: 2056, height: 1253)
    let underTheBar = CGRect(x: 1028, y: 40, width: 1028, height: 1289)
    let rowShort = CGRect(x: 0, y: 40, width: 1028, height: 1228)
    check("init_whenDriverGoesPastTheArea_follows", drag(underTheBar, others: [("left", rowShort)], areas: [measuredArea]).followers == ["left"])
    check("init_whenOtherStopsARowShort_follows", drag(rowShort, others: [("right", underTheBar)], areas: [measuredArea]).followers == ["right"])
    // Given a maximized window and a window on the display next to it, Then their touching edges aren't a shared edge
    check("init_ofMaximizedWindowNextToAnotherDisplay_followsNothing",
          drag(area, others: [("next", CGRect(x: 1000, y: 0, width: 700, height: 800))], areas: [area, CGRect(x: 1000, y: 0, width: 1000, height: 800)]).followers.isEmpty)

    // Given no areas (setting off), Then nothing follows
    check("init_withoutAreas_followsNothing", drag(left, others: [("right", right)], areas: []).followers.isEmpty)

    // Given a corner drag, Then the drag separates for good, even if the height comes back
    var corner = drag(left, others: [("right", right)])
    check("follow_whenAnotherEdgeMoves_returnsNothing", corner.follow(driverFrame: CGRect(x: 0, y: 0, width: 600, height: 700)).isEmpty)
    check("follow_afterSeparating_returnsNothing", corner.follow(driverFrame: CGRect(x: 0, y: 0, width: 500, height: 800)).isEmpty)
    check("isFollowing_afterSeparating_isFalse", !corner.isFollowing)

    // Given a window restored to its size when dragged away, Then its partner doesn't follow
    var dragged = drag(left, others: [("right", right)])
    check("follow_whenFarEdgeMoves_returnsNothing", dragged.follow(driverFrame: CGRect(x: 50, y: 0, width: 500, height: 800)).isEmpty)

    // Given a follower stopped by its minimum size, Then the driver goes back to its edge
    var blocked = drag(left, others: [("right", right), ("behindRight", right)])
    let grown = CGRect(x: 0, y: 0, width: 900, height: 800)
    _ = blocked.follow(driverFrame: grown)
    let stopped = CGRect(x: 750, y: 0, width: 250, height: 800)
    check("snapBack_whenFollowerStoppedShort_returnsItsEdge",
          blocked.snapBack(driverFrame: grown, followerFrames: [CGRect(x: 900, y: 0, width: 100, height: 800), stopped]) == CGRect(x: 0, y: 0, width: 750, height: 800))
    check("snapBack_withinTolerance_returnsNil",
          blocked.snapBack(driverFrame: grown, followerFrames: [CGRect(x: 910, y: 0, width: 90, height: 800), CGRect(x: 900, y: 0, width: 100, height: 800)]) == nil)
    // Given the right window as the driver, Then the driver's left edge goes back
    var blockedFromRight = drag(right, others: [("left", left)])
    let shrunkLeft = CGRect(x: 400, y: 0, width: 600, height: 800)
    _ = blockedFromRight.follow(driverFrame: shrunkLeft)
    check("snapBack_ofRightWindow_movesItsLeftEdge",
          blockedFromRight.snapBack(driverFrame: shrunkLeft, followerFrames: [CGRect(x: 0, y: 0, width: 500, height: 800)]) == CGRect(x: 500, y: 0, width: 500, height: 800))
    // Given a separated drag, Then the driver stays where the user left it
    check("snapBack_afterSeparating_returnsNil", corner.snapBack(driverFrame: CGRect(x: 0, y: 0, width: 500, height: 700), followerFrames: [right]) == nil)
}

// monthGrid
do {
    let utc = TimeZone(identifier: "UTC")!
    let monday = 2, sunday = 1
    func day(_ year: Int, _ month: Int, _ day: Int, in timeZone: TimeZone = utc) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
    let farFromToday = day(2000, 1, 1)
    func grid(_ year: Int, _ month: Int, firstWeekday: Int = monday, today: Date = farFromToday) -> [CalendarWeek] {
        monthGrid(month: day(year, month, 15), today: today, firstWeekday: firstWeekday, timeZone: utc)
    }

    // Given months of different shapes, Then the grid has only the rows they need
    check("monthGrid_ofFourWeekFebruary_hasFourRows", grid(2027, 2).count == 4)
    check("monthGrid_ofSixWeekMonth_hasSixRows", grid(2026, 8).count == 6)
    check("monthGrid_hasSevenDaysPerRow", grid(2026, 8).allSatisfy { $0.days.count == 7 })

    // Given November 2026, starting on a Sunday, Then the first row starts in October, shaded
    let november = grid(2026, 11)
    check("monthGrid_mondayFirst_startsInThePreviousMonth", november[0].days[0].number == 26 && !november[0].days[0].isInMonth)
    check("monthGrid_mondayFirst_marksTheFirstOfTheMonthInMonth", november[0].days[6].number == 1 && november[0].days[6].isInMonth)
    check("monthGrid_endsInTheNextMonth", november.last!.days.last!.number == 6 && !november.last!.days.last!.isInMonth)
    let sundayFirst = grid(2026, 11, firstWeekday: sunday)
    check("monthGrid_sundayFirst_startsOnTheFirst", sundayFirst[0].days[0].number == 1 && sundayFirst[0].days[0].isInMonth)

    // Given the turn of 2026, Monday first, Then the numbers are ISO's
    check("monthGrid_mondayFirst_numbersLastWeekOf2026As53", grid(2026, 12).last!.number == 53 && grid(2026, 12).last!.days[0].number == 28)
    check("monthGrid_mondayFirst_numbersFirstFullWeekOf2027As1", grid(2027, 1)[1].number == 1 && grid(2027, 1)[1].days[0].number == 4)
    check("monthGrid_ofNovember2026_numbersFirstRow44", november[0].number == 44)
    // Given Sunday first, Then week 1 is still the first with four days in the new year
    check("monthGrid_sundayFirst_numbersFirstFullWeekOf2027As1", grid(2027, 1, firstWeekday: sunday)[1].number == 1 && grid(2027, 1, firstWeekday: sunday)[1].days[0].number == 3)

    // Given a today in the month, Then only that day is marked
    let withToday = grid(2026, 11, today: day(2026, 11, 4))
    let marked = withToday.flatMap(\.days).filter(\.isToday)
    check("monthGrid_marksOnlyToday", marked.count == 1 && marked[0].number == 4)

    // Given the month of a DST change, Then no day is skipped or repeated
    let paris = TimeZone(identifier: "Europe/Paris")!
    let march = monthGrid(month: day(2026, 3, 15, in: paris), today: farFromToday, firstWeekday: monday, timeZone: paris)
    check("monthGrid_acrossDST_listsEveryDayOnce", march.flatMap(\.days).filter(\.isInMonth).map(\.number) == Array(1...31))

    // FirstWeekday
    check("calendarWeekday_ofSystem_followsTheSystem", FirstWeekday.system.calendarWeekday(system: 7) == 7)
    check("calendarWeekday_ofMonday_is2", FirstWeekday.monday.calendarWeekday(system: 7) == 2)
    check("calendarWeekday_ofSunday_is1", FirstWeekday.sunday.calendarWeekday(system: 7) == 1)

    // movedMonth: from the 31st, each step lands in the next month, even a shorter one
    let january = day(2027, 1, 31)
    let february = movedMonth(january, by: 1, timeZone: utc)
    let backInDecember = movedMonth(january, by: -1, timeZone: utc)
    check("movedMonth_fromThe31st_landsInTheNextMonth", calendarTitle(month: february, locale: Locale(identifier: "en_US"), timeZone: utc) == "February 2027")
    check("movedMonth_backwards_crossesTheYear", calendarTitle(month: backInDecember, locale: Locale(identifier: "en_US"), timeZone: utc) == "December 2026")

    // Text follows the locale
    check("calendarTitle_ofFrench_isLocalized", calendarTitle(month: day(2026, 11, 4), locale: Locale(identifier: "fr_FR"), timeZone: utc) == "novembre 2026")
    check("calendarWeekdayHeaders_mondayFirst_startOnMonday", calendarWeekdayHeaders(firstWeekday: monday, locale: Locale(identifier: "en_US")) == ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"])
    check("calendarWeekdayHeaders_sundayFirst_startOnSunday", calendarWeekdayHeaders(firstWeekday: sunday, locale: Locale(identifier: "en_US")).first == "Sun")

    // Accessibility: the full date, and today said aloud
    let today = withToday.flatMap(\.days).first(where: \.isToday)!
    let tomorrow = withToday.flatMap(\.days).first { $0.number == 5 }!
    let english = Locale(identifier: "en_US")
    check("calendarDayAccessibilityLabel_ofADay_isTheFullDate", calendarDayAccessibilityLabel(tomorrow, locale: english, timeZone: utc) == "Thursday, November 5, 2026")
    check("calendarDayAccessibilityLabel_ofToday_saysSo", calendarDayAccessibilityLabel(today, locale: english, timeZone: utc) == "Wednesday, November 4, 2026, today")

    // Month selector
    let isoToday = day(2026, 11, 4)
    let monthPicks = calendarMonthPicks(month: day(2026, 3, 31), today: isoToday, locale: english, timeZone: utc)
    check("calendarMonthPicks_hasTwelveMonths", monthPicks.count == 12 && monthPicks.first?.text == "January" && monthPicks.last?.text == "December")
    check("calendarMonthPicks_ofFrench_isLocalized", calendarMonthPicks(month: isoToday, today: isoToday, locale: Locale(identifier: "fr_FR"), timeZone: utc).dropFirst(10).first?.text == "novembre")
    check("calendarMonthPicks_marksOnlyTheCurrentMonth", monthPicks.filter(\.isCurrent).map(\.text) == ["November"])
    check("calendarMonthPicks_ofAnotherYear_marksNothing", !calendarMonthPicks(month: day(2027, 3, 1), today: isoToday, locale: english, timeZone: utc).contains(where: \.isCurrent))
    // Given a viewed date on the 31st, Then each pick is still in its own month, even a shorter one
    check("calendarMonthPicks_fromThe31st_landsInEachMonth", monthPicks.map(\.accessibilityLabel) == (1...12).map { calendarTitle(month: day(2026, $0, 1), locale: english, timeZone: utc) })
    check("calendarMonthPicks_datesAreInTheirMonth", monthPicks.map { calendarTitle(month: $0.date, locale: english, timeZone: utc) } == monthPicks.map(\.accessibilityLabel))

    // Year selector
    let yearPicks = calendarYearPicks(month: day(2026, 3, 31), today: isoToday, locale: english, timeZone: utc)
    check("calendarYearPicks_ofAPage_hasItsTwelveYears", yearPicks.map(\.text) == (2016...2027).map(String.init))
    check("calendarYearPicks_marksOnlyTheCurrentYear", yearPicks.filter(\.isCurrent).map(\.text) == ["2026"])
    check("calendarYearPicks_datesAreInTheirYear", yearPicks.map { calendarYearTitle(month: $0.date, locale: english, timeZone: utc) } == yearPicks.map(\.text))
    check("calendarYearPicks_ofTheNextPage_startsAfterTheEdge", calendarYearPicks(month: day(2028, 1, 1), today: isoToday, locale: english, timeZone: utc).first?.text == "2028")
    check("calendarYearPicks_ofThePageEdge_staysOnItsPage", calendarYearPicks(month: day(2027, 12, 31), today: isoToday, locale: english, timeZone: utc).last?.text == "2027")

    // Titles of the selectors
    check("calendarYearTitle_isTheYear", calendarYearTitle(month: isoToday, locale: english, timeZone: utc) == "2026")
    check("calendarYearPageTitle_isTheRange", calendarYearPageTitle(month: isoToday, locale: english, timeZone: utc) == "2016 – 2027")
}

if failures > 0 {
    print("\(failures) check(s) failed")
    exit(1)
}
print("All checks passed")
