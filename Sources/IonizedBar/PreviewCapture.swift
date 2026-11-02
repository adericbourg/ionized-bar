import AppKit
import IonizedBarCore
import ScreenCaptureKit

/// Callers must check `Settings.showsPreviews` first: this touches ScreenCaptureKit unconditionally.
enum PreviewCapture {
    /// Longest side of a thumbnail, in pixels.
    static let maxPixels = 640

    /// Nil when the window can't be matched with certainty, on denial, or on any error (logged without titles).
    /// `frame` is the entry's AX frame. Minimized windows are listed too, since `onScreenWindowsOnly` is false.
    @MainActor
    static func thumbnail(pid: Int32, frame: CGRect) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            // Layer 0 only: menus, overlays and the like aren't windows an entry stands for.
            let windows = content.windows.filter { $0.windowLayer == 0 }
            let candidates = windows.compactMap { window in
                window.owningApplication.map { CaptureCandidate(id: window.windowID, pid: $0.processID, bounds: window.frame) }
            }
            guard let id = matchWindow(pid: pid, frame: frame, candidates: candidates),
                  let window = windows.first(where: { $0.windowID == id }) else {
                log("preview: no unique window for pid=\(pid)")
                return nil
            }
            let configuration = SCStreamConfiguration()
            let scale = min(1, CGFloat(maxPixels) / max(window.frame.width, window.frame.height))
            configuration.width = max(1, Int(window.frame.width * scale))
            configuration.height = max(1, Int(window.frame.height * scale))
            configuration.showsCursor = false
            return try await SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration)
        } catch {
            log("preview: capture failed for pid=\(pid): \(error)")
            return nil
        }
    }
}
