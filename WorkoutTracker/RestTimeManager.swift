//
//  RestTimeManager.swift
//  WorkoutTracker
//
//  Created by Alexandru Mihalache on 20/08/2026.
//

import Foundation
import Combine
import UserNotifications
import UIKit

@MainActor
final class RestTimerManager: ObservableObject {
    @Published var isActive = false
    @Published var remainingSeconds: Int = 0
    @Published var totalSeconds: Int = 90

    private var endDate: Date?
    private var timer: Timer?
    private let notificationID = "restTimerComplete"

    func start(duration: Int) {
        cancel()
        totalSeconds = duration
        remainingSeconds = duration
        endDate = Date().addingTimeInterval(TimeInterval(duration))
        isActive = true
        scheduleNotification(after: duration)
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
    }

    func addTime(_ seconds: Int) {
        guard let currentEnd = endDate else { return }
        let newEnd = currentEnd.addingTimeInterval(TimeInterval(seconds))
        endDate = newEnd
        totalSeconds += seconds
        remainingSeconds = max(0, Int(newEnd.timeIntervalSinceNow.rounded()))
        rescheduleNotification()
    }

    func skip() {
        cancel()
    }

    func cancel() {
        timer?.invalidate()
        timer = nil
        isActive = false
        endDate = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
    }

    private func tick() {
        guard let endDate else { return }
        let remaining = Int(endDate.timeIntervalSinceNow.rounded())
        if remaining <= 0 {
            remainingSeconds = 0
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            cancel()
        } else {
            remainingSeconds = remaining
        }
    }

    private func scheduleNotification(after seconds: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Let's get to work you beautiful"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func rescheduleNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
        guard let endDate else { return }
        let remaining = max(1, endDate.timeIntervalSinceNow)
        let content = UNMutableNotificationContent()
        content.title = "Rest complete"
        content.body = "Let's get to work you beatiful"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: remaining, repeats: false)
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
}
