//
//  RestTimeBar.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 20/08/2026.
//

import SwiftUI
import Foundation
import Combine
import UserNotifications
import UIKit

struct RestTimerBar: View {
    @ObservedObject var manager: RestTimerManager

    private var progress: Double {
        guard manager.totalSeconds > 0 else { return 0 }
        return Double(manager.remainingSeconds) / Double(manager.totalSeconds)
    }

    private var timeLabel: String {
        String(format: "%d:%02d", manager.remainingSeconds / 60, manager.remainingSeconds % 60)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().stroke(AppTheme.textSecondary.opacity(0.25), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(AppTheme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: progress)
                    Text(timeLabel)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .frame(width: 42, height: 42)

                Text("Resting")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Spacer()

                Button {
                    manager.addTime(30)
                } label: {
                    Text("+30s")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(AppTheme.background)
                        .clipShape(Capsule())
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Button {
                    manager.skip()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
        .padding(12)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
