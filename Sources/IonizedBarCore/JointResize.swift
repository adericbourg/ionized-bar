import CoreGraphics

/// How far joint windows can be from each other, and how short of the area's ends. Absorbs apps that size in steps:
/// measured on Zentty, a window pushed off the bar stops 25 pt short of it, one text row.
let jointTolerance: CGFloat = 32

/// Cocoa coordinates. The room `pushedFrame` leaves: from the bar's top to `visibleFrame`'s top.
public func usableArea(screenFrame: CGRect, visibleFrame: CGRect, barHeight: CGFloat) -> CGRect {
    let bottom = screenFrame.minY + barHeight
    return CGRect(x: screenFrame.minX, y: bottom, width: screenFrame.width, height: visibleFrame.maxY - bottom)
}

/// Where to put a window that took `actualSize` when asked for `target.size`: an origin that moves means the far edge
/// is the fixed one, and a window stopped by its minimum size must not slide past it.
public func anchoredOrigin(target: CGRect, current: CGRect, actualSize: CGSize) -> CGPoint {
    CGPoint(
        x: target.minX == current.minX ? target.minX : target.maxX - actualSize.width,
        y: target.minY == current.minY ? target.minY : target.maxY - actualSize.height
    )
}

private enum Edge: CaseIterable {
    case minX, maxX, minY, maxY

    var opposite: Edge {
        switch self {
        case .minX: .maxX
        case .maxX: .minX
        case .minY: .maxY
        case .maxY: .minY
        }
    }

    func position(in rect: CGRect) -> CGFloat {
        switch self {
        case .minX: rect.minX
        case .maxX: rect.maxX
        case .minY: rect.minY
        case .maxY: rect.maxY
        }
    }

    /// Whether `rect` gets to this edge of `area`, within the tolerance. Going past it is fine: a window waiting to be
    /// pushed off the bar, or one that resisted the push, still fills the area.
    func reaches(_ area: CGRect, from rect: CGRect) -> Bool {
        let distance = position(in: area) - position(in: rect)
        return self == .minX || self == .minY ? distance >= -jointTolerance : distance <= jointTolerance
    }

    /// Never past the opposite edge: a frame with a negative size means nothing to an app.
    func moved(_ rect: CGRect, to position: CGFloat) -> CGRect {
        switch self {
        case .minX:
            let x = min(position, rect.maxX)
            return CGRect(x: x, y: rect.minY, width: rect.maxX - x, height: rect.height)
        case .maxX:
            return CGRect(x: rect.minX, y: rect.minY, width: max(position, rect.minX) - rect.minX, height: rect.height)
        case .minY:
            let y = min(position, rect.maxY)
            return CGRect(x: rect.minX, y: y, width: rect.width, height: rect.maxY - y)
        case .maxY:
            return CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: max(position, rect.minY) - rect.minY)
        }
    }
}

/// One drag of one window: what it moves, from the frames before the drag. All frames share one coordinate system, flipped or not.
/// There is no stored link between windows, so windows are joint for as long as their geometry says so.
public struct JointResize<Window> {
    public let driver: Window
    private let baseline: CGRect
    private let followerBaselines: [(window: Window, frame: CGRect)]
    private let sharedEdge: Edge
    private var lastFrame: CGRect
    private var isSeparated = false

    public var followers: [Window] { followerBaselines.map(\.window) }
    public var isFollowing: Bool { !followerBaselines.isEmpty && !isSeparated }

    public init(driver: Window, frame: CGRect, others: [(window: Window, frame: CGRect)], areas: [CGRect]) {
        self.driver = driver
        baseline = frame
        lastFrame = frame
        for area in areas {
            for edge in Edge.allCases {
                let joint = others.filter { Self.areJoint(frame, $0.frame, sharing: edge, area: area) }
                if !joint.isEmpty {
                    followerBaselines = joint
                    sharedEdge = edge
                    return
                }
            }
        }
        followerBaselines = []
        sharedEdge = .maxX
    }

    /// The frames to write for the driver's current frame. Empty once another of the driver's edges has moved
    /// (a corner drag, or a tiled window restoring its size as it leaves): the windows have separated for this drag.
    public mutating func follow(driverFrame: CGRect) -> [(window: Window, frame: CGRect)] {
        guard isFollowing, driverFrame != lastFrame else { return [] }
        lastFrame = driverFrame
        // Exact but for rounding: unlike `jointTolerance`, a few points here are a real corner drag.
        let hasOtherEdgeMoved = Edge.allCases.contains { $0 != sharedEdge && abs($0.position(in: driverFrame) - $0.position(in: baseline)) > 1 }
        guard !hasOtherEdgeMoved else {
            isSeparated = true
            return []
        }
        let delta = sharedEdge.position(in: driverFrame) - sharedEdge.position(in: baseline)
        let moving = sharedEdge.opposite
        return followerBaselines.map { ($0.window, moving.moved($0.frame, to: moving.position(in: $0.frame) + delta)) }
    }

    /// The driver's frame when a follower stopped short of it, by a minimum size for instance, with `followerFrames`
    /// in the order of `followers`. The follower furthest from where it should be wins, as it is the one that can't go further.
    public func snapBack(driverFrame: CGRect, followerFrames: [CGRect]) -> CGRect? {
        guard isFollowing else { return nil }
        let moving = sharedEdge.opposite
        let edges = zip(followerBaselines, followerFrames).map { before, now in
            moving.position(in: now) - (moving.position(in: before.frame) - sharedEdge.position(in: baseline))
        }
        let driverEdge = sharedEdge.position(in: driverFrame)
        guard let edge = edges.max(by: { abs($0 - driverEdge) < abs($1 - driverEdge) }), abs(edge - driverEdge) > jointTolerance else { return nil }
        return sharedEdge.moved(driverFrame, to: edge)
    }

    /// `edge` is on `driver`, inside the area: a maximized window only touches a window on the next display.
    /// Its opposite and `other`'s `edge` get to the area's ends, and both span the area the other way.
    private static func areJoint(_ driver: CGRect, _ other: CGRect, sharing edge: Edge, area: CGRect) -> Bool {
        let shared = edge.position(in: driver)
        let across = Edge.allCases.filter { $0 != edge && $0 != edge.opposite }
        return abs(shared - edge.opposite.position(in: other)) <= jointTolerance
            && abs(shared - edge.position(in: area)) > jointTolerance
            && abs(shared - edge.opposite.position(in: area)) > jointTolerance
            && edge.opposite.reaches(area, from: driver)
            && edge.reaches(area, from: other)
            && across.allSatisfy { $0.reaches(area, from: driver) && $0.reaches(area, from: other) }
    }
}
