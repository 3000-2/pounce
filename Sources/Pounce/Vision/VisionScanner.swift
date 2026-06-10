import AppKit
import CoreGraphics
import PounceCore
import ScreenCaptureKit
import Vision

@MainActor
enum VisionScanner {
    static func scanFrontWindow(pid: pid_t, startID: Int) async -> [HintTarget] {
        guard ScreenRecordingPermission.isGranted else {
            ScreenRecordingPermission.request()
            return []
        }
        guard let windowBounds = frontmostWindowBounds(pid: pid) else { return [] }
        let displayID = displayContaining(windowBounds)
        guard let image = await captureDisplay(displayID) else { return [] }

        let displayBounds = CGDisplayBounds(displayID)
        let boxes = await recognizeTextBoxes(in: image)

        var targets: [HintTarget] = []
        var id = startID
        for box in boxes {
            let rect = CoordinateConversion.screenRect(fromVisionBoundingBox: box, displayBounds: displayBounds)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            guard windowBounds.contains(center) else { continue }
            targets.append(HintTarget(id: id, frame: rect, kind: .screenPoint))
            id += 1
        }
        return targets
    }

    private static func captureDisplay(_ displayID: CGDirectDisplayID) async -> CGImage? {
        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first(where: { $0.displayID == displayID })
                ?? content.displays.first else { return nil }
            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.width = CGDisplayPixelsWide(displayID)
            config.height = CGDisplayPixelsHigh(displayID)
            config.showsCursor = false
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        } catch {
            NSLog("Pounce: screen capture failed — \(error.localizedDescription)")
            return nil
        }
    }

    private static func recognizeTextBoxes(in image: CGImage) async -> [CGRect] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .fast
                request.usesLanguageCorrection = false
                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                do {
                    try handler.perform([request])
                    let boxes = (request.results ?? [])
                        .filter { $0.topCandidates(1).first?.string.isEmpty == false }
                        .map(\.boundingBox)
                    continuation.resume(returning: boxes)
                } catch {
                    continuation.resume(returning: [])
                }
            }
        }
    }
}

/// Frontmost on-screen normal window of a pid, in Quartz global coordinates.
/// Uses the window server list so it works even when the app exposes no AX tree.
private func frontmostWindowBounds(pid: pid_t) -> CGRect? {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        return nil
    }
    for info in infoList {
        guard let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t, ownerPID == pid,
              let layer = info[kCGWindowLayer as String] as? Int, layer == 0,
              let boundsDict = info[kCGWindowBounds as String] as? [String: CGFloat],
              let rect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
        return rect
    }
    return nil
}

private func displayContaining(_ rect: CGRect) -> CGDirectDisplayID {
    let center = CGPoint(x: rect.midX, y: rect.midY)
    var count: UInt32 = 0
    CGGetDisplaysWithPoint(center, 0, nil, &count)
    guard count > 0 else { return CGMainDisplayID() }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetDisplaysWithPoint(center, count, &ids, &count)
    return ids.first ?? CGMainDisplayID()
}
