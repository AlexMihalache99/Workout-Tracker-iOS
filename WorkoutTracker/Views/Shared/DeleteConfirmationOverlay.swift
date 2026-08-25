//
//  DeleteConfirmationOverlay.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 23/07/2026.
//

import SwiftUI

struct DeleteConfirmationOverlay: View {
    let title: String
    let message: String
    var confirmLabel: String = "Delete"
    var onDelete: () -> Void
    var onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }

            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(PlateColor.deadlift)
                        .padding(.top, 24)

                    Text(title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(message)
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 2)
                        .padding(.bottom, 20)
                }

                Rectangle()
                    .fill(AppTheme.textSecondary.opacity(0.2))
                    .frame(height: 1)

                HStack(spacing: 0) {
                    Button {
                        onCancel()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }

                    Rectangle()
                        .fill(AppTheme.textSecondary.opacity(0.2))
                        .frame(width: 1)

                    Button {
                        onDelete()
                    } label: {
                        Text(confirmLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(PlateColor.deadlift)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
            .fixedSize(horizontal: false, vertical: true)
            .background(AppTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: 300)
            .shadow(color: .black.opacity(0.4), radius: 20, y: 8)
        }
        .transition(.opacity.combined(with: .scale(scale: 1.05)))
    }
}

