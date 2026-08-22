import SwiftUI

private let pinLength = 4

private struct PinDots: View {
    let enteredCount: Int

    var body: some View {
        HStack(spacing: 16) {
            ForEach(0..<pinLength, id: \.self) { index in
                Circle()
                    .fill(index < enteredCount ? Color.white : Color.white.opacity(0.25))
                    .frame(width: 14, height: 14)
            }
        }
    }
}

private struct KeypadButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.title)
                .foregroundColor(.white)
                .frame(width: 64, height: 64)
        }
    }
}

private struct PinKeypad: View {
    let onDigit: (String) -> Void
    let onBackspace: () -> Void

    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 24) {
                    ForEach(row, id: \.self) { digit in
                        KeypadButton(label: digit) { onDigit(digit) }
                    }
                }
            }
            HStack(spacing: 24) {
                Color.clear.frame(width: 64, height: 64)
                KeypadButton(label: "0") { onDigit("0") }
                Button(action: onBackspace) {
                    Image(systemName: "delete.left")
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                }
            }
        }
    }
}

/// Blank full-screen PIN prompt. Used both as the real app lock (no `onCancel` - must be
/// unlocked with the correct PIN) and to confirm identity before disabling PIN lock from
/// settings (with `onCancel`). Mirrors AppLockScreen in PinLockScreens.kt.
struct AppLockScreen: View {
    let expectedHash: String
    let onUnlocked: () -> Void
    var onCancel: (() -> Void)?

    @State private var entered = ""
    @State private var showError = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                Text(showError ? "Code incorrect" : "Entre ton code")
                    .foregroundColor(showError ? .red : .white)
                PinDots(enteredCount: entered.count)
                PinKeypad(
                    onDigit: { digit in
                        if entered.count < pinLength { entered.append(digit) }
                    },
                    onBackspace: {
                        if !entered.isEmpty { entered.removeLast() }
                    }
                )
                if let onCancel {
                    Button("Annuler", action: onCancel)
                        .foregroundColor(.white)
                }
            }
        }
        .onChange(of: entered) { _, newValue in
            guard newValue.count == pinLength else { return }
            if PinHashing.hash(newValue) == expectedHash {
                onUnlocked()
            } else {
                showError = true
                Task {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    entered = ""
                    showError = false
                }
            }
        }
    }
}

/// First-time PIN setup: enter, then re-enter to confirm before it's saved. Mirrors
/// PinSetupScreen in PinLockScreens.kt.
struct PinSetupScreen: View {
    let onPinConfirmed: (String) -> Void
    let onCancel: () -> Void

    @State private var firstEntry: String?
    @State private var entered = ""
    @State private var showMismatch = false

    private var statusText: String {
        if showMismatch { return "Les codes ne correspondent pas, réessaie" }
        return firstEntry == nil ? "Choisis un code à 4 chiffres" : "Confirme ton code"
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 32) {
                Text(statusText)
                    .foregroundColor(showMismatch ? .red : .white)
                    .padding(.horizontal, 32)
                    .multilineTextAlignment(.center)
                PinDots(enteredCount: entered.count)
                PinKeypad(
                    onDigit: { digit in
                        if entered.count < pinLength { entered.append(digit) }
                    },
                    onBackspace: {
                        if !entered.isEmpty { entered.removeLast() }
                    }
                )
                Button("Annuler", action: onCancel)
                    .foregroundColor(.white)
            }
        }
        .onChange(of: entered) { _, newValue in
            guard newValue.count == pinLength else { return }
            if let first = firstEntry {
                if newValue == first {
                    onPinConfirmed(PinHashing.hash(newValue))
                } else {
                    showMismatch = true
                    Task {
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        showMismatch = false
                        firstEntry = nil
                        entered = ""
                    }
                }
            } else {
                firstEntry = newValue
                entered = ""
            }
        }
    }
}
