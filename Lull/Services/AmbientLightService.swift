import Foundation
import AVFoundation
import Darwin

// Reads the current ambient light level using the back camera's auto-exposure values.
// Returns a 4-bucket lightsLevel (0=Bright, 1=Half-dim, 2=Warm dim, 3=Mostly dark)
// and a confidence rating so the UI knows whether to trust or confirm the reading.
@MainActor
final class AmbientLightService: ObservableObject {

    enum Confidence { case high, lowConfidence, fallback }

    struct Reading {
        var lightsLevel: Int       // 0–3
        var confidence: Confidence
    }

    @Published private(set) var isReading = false
    @Published private(set) var confidence: Confidence = .fallback

    func read() async -> Reading {
        isReading = true
        defer { isReading = false }

        let status = AVCaptureDevice.authorizationStatus(for: .video)

        if status == .denied || status == .restricted {
            return Reading(lightsLevel: 2, confidence: .fallback)
        }

        if status == .notDetermined {
            let granted = await withCheckedContinuation { cont in
                AVCaptureDevice.requestAccess(for: .video) { cont.resume(returning: $0) }
            }
            if !granted { return Reading(lightsLevel: 2, confidence: .fallback) }
        }

        let result = await Task.detached(priority: .userInitiated) {
            AmbientLightService.captureEV()
        }.value

        confidence = result.confidence
        return result
    }

    // Spins up a capture session on a background thread, waits for AE to settle,
    // then reads ISO + exposure duration to derive a darkness proxy.
    private nonisolated static func captureEV() -> Reading {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device)
        else {
            return Reading(lightsLevel: 2, confidence: .fallback)
        }

        let session = AVCaptureSession()
        session.sessionPreset = .low
        guard session.canAddInput(input) else { return Reading(lightsLevel: 2, confidence: .fallback) }
        session.addInput(input)
        session.startRunning()

        // Allow AE to settle
        Thread.sleep(forTimeInterval: 0.5)

        let iso = Double(device.iso)
        let duration = CMTimeGetSeconds(device.exposureDuration)

        session.stopRunning()

        guard duration > 0, iso > 0 else { return Reading(lightsLevel: 2, confidence: .fallback) }

        // Lens-blocked detection: camera compensating at near-maximum in both dimensions
        let maxISO = Double(device.activeFormat.maxISO)
        if iso >= maxISO * 0.95 && duration >= 0.4 {
            return Reading(lightsLevel: 3, confidence: .lowConfidence)
        }

        // Darkness proxy: log2(iso * duration) — higher = darker scene.
        // TODO: calibrate thresholds once sensor+self-report pairs accumulate.
        let darkness = log2(iso * duration)
        let lightsLevel: Int
        switch darkness {
        case ..<2.5:  lightsLevel = 0  // Bright
        case ..<4.5:  lightsLevel = 1  // Half-dim
        case ..<6.5:  lightsLevel = 2  // Warm dim
        default:      lightsLevel = 3  // Mostly dark
        }

        return Reading(lightsLevel: lightsLevel, confidence: .high)
    }
}
