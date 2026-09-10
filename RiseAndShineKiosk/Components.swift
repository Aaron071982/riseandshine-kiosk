import SwiftUI

struct SunriseMark: View {
    var size: CGFloat = 160
    var longPress: (() -> Void)? = nil

    var body: some View {
        Image("SunriseMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 1.1) {
                longPress?()
            }
            .accessibilityLabel("Rise and Shine")
    }
}

struct InitialsAvatar: View {
    let initials: String
    var size: CGFloat = 52

    var body: some View {
        Text(initials)
            .font(RSFont.display(size * 0.36, weight: .semibold))
            .foregroundStyle(Color.sunriseDeep)
            .frame(width: size, height: size)
            .background(Color.sunriseTint)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.hairline, lineWidth: 1))
    }
}

struct StatusPill: View {
    let signedIn: Bool

    var body: some View {
        Text(signedIn ? "In" : "Out")
            .font(RSFont.body(14, weight: .semibold))
            .foregroundStyle(signedIn ? Color.successGreen : Color.mutedText)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(signedIn ? Color.successGreen.opacity(0.12) : Color.hairline)
            .clipShape(Capsule())
    }
}

struct FormsPill: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count == 1 ? "1 form due" : "\(count) forms due")
                .font(RSFont.body(13, weight: .semibold))
                .foregroundStyle(Color.sunriseDeep)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.sunriseTint)
                .clipShape(Capsule())
        }
    }
}

struct KioskButton: View {
    var title: String
    var icon: String? = nil
    var kind: Kind = .primary
    var enabled: Bool = true
    var loading: Bool = false
    var action: () -> Void

    enum Kind { case primary, secondary, success }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if loading {
                    ProgressView().tint(foreground)
                } else {
                    if let icon {
                        Image(systemName: icon)
                            .font(.system(size: 20, weight: .semibold))
                    }
                    Text(title)
                        .font(RSFont.display(22, weight: .semibold))
                }
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 64)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!enabled || loading)
        .opacity(enabled ? 1 : 0.45)
    }

    private var foreground: Color {
        switch kind {
        case .primary, .success: return .white
        case .secondary: return .espresso
        }
    }

    private var background: Color {
        switch kind {
        case .primary: return .sunrise
        case .secondary: return .sunriseTint
        case .success: return .successGreen
        }
    }
}

struct KioskCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(24)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 1)
            )
            .shadow(color: Color.espresso.opacity(0.05), radius: 18, y: 8)
    }
}

struct BackChip: View {
    var title: String = "Back"
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(RSFont.body(16, weight: .semibold))
            }
            .foregroundStyle(Color.espresso)
            .padding(.horizontal, 16)
            .frame(height: 48)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.hairline, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct KioskBackground: View {
    var body: some View {
        Color.canvasBg
            .ignoresSafeArea()
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.sunriseTint.opacity(0.7))
                    .frame(width: 520, height: 520)
                    .blur(radius: 40)
                    .offset(x: 180, y: -220)
            }
            .overlay(alignment: .bottomLeading) {
                Circle()
                    .fill(Color.sunrise.opacity(0.08))
                    .frame(width: 380, height: 380)
                    .blur(radius: 30)
                    .offset(x: -140, y: 160)
            }
    }
}

struct LiveClock: View {
    var compact: Bool = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if compact {
                Text(TimeFormatting.timeOnly.string(from: context.date))
                    .font(RSFont.body(15, weight: .medium))
                    .foregroundStyle(Color.mutedText)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(TimeFormatting.clock.string(from: context.date))
                        .font(RSFont.display(28, weight: .semibold))
                        .foregroundStyle(Color.espresso)
                    Text(TimeFormatting.meridiem.string(from: context.date))
                        .font(RSFont.body(14, weight: .semibold))
                        .foregroundStyle(Color.mutedText)
                }
            }
        }
    }
}
