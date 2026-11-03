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

if failures > 0 {
    print("\(failures) check(s) failed")
    exit(1)
}
print("All checks passed")
