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
}

// parseDockPrefs
do {
    func plist(_ body: String) -> Data {
        Data("""
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">\(body)</plist>
        """.utf8)
    }

    // Given an export with both keys, When parsing, Then both are read
    check("parseDockPrefs_ofSetKeys_returnsThem",
          parseDockPrefs(plist: plist("<dict><key>autohide</key><false/><key>autohide-delay</key><real>0.5</real><key>tilesize</key><integer>48</integer></dict>"))
              == DockPrefs(autohide: false, autohideDelay: 0.5))
    // Given integers, as `defaults write -int` stores them, When parsing, Then they count
    check("parseDockPrefs_ofIntegers_returnsThem",
          parseDockPrefs(plist: plist("<dict><key>autohide</key><integer>1</integer><key>autohide-delay</key><integer>0</integer></dict>"))
              == DockPrefs(autohide: true, autohideDelay: 0))
    // Given missing keys or an empty domain, When parsing, Then they are absent, not defaults
    check("parseDockPrefs_ofEmptyDomain_returnsAbsent", parseDockPrefs(plist: plist("<dict/>")) == DockPrefs(autohide: nil, autohideDelay: nil))
    check("parseDockPrefs_ofOneKey_returnsOtherAbsent",
          parseDockPrefs(plist: plist("<dict><key>autohide</key><true/></dict>")) == DockPrefs(autohide: true, autohideDelay: nil))
    // Given anything that can't be restored faithfully, When parsing, Then it is a failure
    check("parseDockPrefs_ofUnexpectedType_returnsNil",
          parseDockPrefs(plist: plist("<dict><key>autohide</key><string>yes</string></dict>")) == nil)
    check("parseDockPrefs_ofGarbage_returnsNil", parseDockPrefs(plist: Data("not a plist".utf8)) == nil)
    check("parseDockPrefs_ofNoOutput_returnsNil", parseDockPrefs(plist: Data()) == nil)
    check("parseDockPrefs_ofArray_returnsNil", parseDockPrefs(plist: plist("<array/>")) == nil)

    // Given prefs saved as a dictionary, When reading them back, Then absent stays absent
    for prefs in [DockPrefs(autohide: false, autohideDelay: 0.5), DockPrefs(autohide: true, autohideDelay: nil), DockPrefs(autohide: nil, autohideDelay: nil)] {
        check("dockPrefs_dictionary_roundTrips", DockPrefs(dictionary: prefs.dictionary) == prefs)
    }
    check("dockPrefs_dictionary_ofAbsentKeys_isEmpty", DockPrefs(autohide: nil, autohideDelay: nil).dictionary.isEmpty)
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

// LastCaptureCache
do {
    // Given a stored value, Then it is returned, and a new one replaces it
    var cache = LastCaptureCache<Int, String>()
    check("value_ofUnknownKey_isNil", cache.value(for: 1) == nil)
    cache.store("a", for: 1)
    check("value_ofStoredKey_isTheStoredValue", cache.value(for: 1) == "a")
    cache.store("b", for: 1)
    check("store_onAStoredKey_replacesTheValue", cache.value(for: 1) == "b")
    // Given two keys and one window closed, Then only the closed one is dropped
    cache.store("c", for: 2)
    cache.keepOnly([2])
    check("keepOnly_dropsTheKeysNotKept", cache.value(for: 1) == nil)
    check("keepOnly_keepsTheKeysKept", cache.value(for: 2) == "c")
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
    // Given M9's pinned icons, Then they sit between the launcher and the tasks
    let withPins = taskSlot(barWidth: 1000, pinnedWidth: 96)
    check("taskSlot_withPinnedIcons_startsAfterThem", withPins.x == 144 && withPins.width == 856)
    check("taskSlot_ofBarNarrowerThanLauncher_hasNoWidth", taskSlot(barWidth: 10).width == 0)

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
    // Given two pinned icons of about 48pt, Then tasks start after them and pins never shrink, even with no width left
    let slot = taskSlot(barWidth: 1000, pinnedWidth: 2 * pinnedIconWidth)
    check("pinnedIconWidth_isAbout48Points", pinnedIconWidth == 48)
    check("taskSlot_withTwoPinnedIcons_startsAfterThem", slot.x == 144 && slot.width == 856)
    check("taskSlot_withMorePinsThanFit_hasNoWidth", taskSlot(barWidth: 100, pinnedWidth: 3 * pinnedIconWidth).width == 0)
}

// pinnedAccessibilityLabel
do {
    // Given an app name, When building the label of its pinned icon, Then it reads the name and "pinned"
    check("pinnedAccessibilityLabel_readsNameThenPinned", pinnedAccessibilityLabel(appName: "Safari") == "Safari, pinned")
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

if failures > 0 {
    print("\(failures) check(s) failed")
    exit(1)
}
print("All checks passed")
