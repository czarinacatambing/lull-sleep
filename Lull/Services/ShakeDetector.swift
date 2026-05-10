import SwiftUI
import UIKit

private class ShakeViewController: UIViewController {
    var onShake: (() -> Void)?
    private var lastShake: Date?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else { return }
        let now = Date()
        if let last = lastShake, now.timeIntervalSince(last) < 3 { return }
        lastShake = now
        onShake?()
    }
}

private struct ShakeViewControllerRepresentable: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeViewController {
        let vc = ShakeViewController()
        vc.onShake = onShake
        return vc
    }

    func updateUIViewController(_ uiViewController: ShakeViewController, context: Context) {
        uiViewController.onShake = onShake
    }
}

extension View {
    func onShake(_ action: @escaping () -> Void) -> some View {
        background(
            ShakeViewControllerRepresentable(onShake: action)
                .frame(width: 0, height: 0)
        )
    }
}
