//
//  ReminderManager.swift
//  Psorcast
//
//  Copyright © 2019 Sage Bionetworks. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
//
// 1.  Redistributions of source code must retain the above copyright notice, this
// list of conditions and the following disclaimer.
//
// 2.  Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation and/or
// other materials provided with the distribution.
//
// 3.  Neither the name of the copyright holder(s) nor the names of any contributors
// may be used to endorse or promote products derived from this software without
// specific prior written permission. No license is granted to the trademarks of
// the copyright holders even if such marks are included in this software.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
// IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
// ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE
// FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
// DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
// SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
// CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
// OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

import Foundation
import UserNotifications
import BridgeApp
import BridgeAppUI
import SwiftUI

let TaskReminderNotificationCategory = "TaskReminder"
let LastCallTaskReminderNotificationCategory = "LastCallTaskReminder"

open class ReminderManager : NSObject, UNUserNotificationCenterDelegate {
    public static var shared = ReminderManager()
    
    public static let reminderStepId = "reminder"
    
    fileprivate var timeFormatterPrivate: DateFormatter?
    open var timeFormatter: DateFormatter {
        if let timeFormatterUnwrapped = timeFormatterPrivate {
            return timeFormatterUnwrapped
        }
        let timeFormatterUnwrapped = DateFormatter()
        timeFormatterUnwrapped.locale = Locale(identifier: "en_US_POSIX")
        timeFormatterUnwrapped.dateFormat = "h:mm a"
        timeFormatterUnwrapped.amSymbol = "AM"
        timeFormatterUnwrapped.pmSymbol = "PM"
        timeFormatterPrivate = timeFormatterUnwrapped
        return timeFormatterUnwrapped
    }
    
    open func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     willPresent notification: UNNotification,
                                     withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // Play sound and show alert to the user
        completionHandler([.alert, .sound])
    }
    
    open func userNotificationCenter(_ center: UNUserNotificationCenter,
                                     didReceive response: UNNotificationResponse,
                                     withCompletionHandler completionHandler: @escaping () -> Void) {
        
        debugPrint("Received notification with identifier \(response.notification.request.identifier)")
        
        if let tabVc = (AppDelegate.shared as? AppDelegate)?.rootViewController?.children.first(where: { $0 is UITabBarController }) as? UITabBarController {
            // Make sure the measure tab is selected instead of being on reminders tab
            tabVc.selectedIndex = 0
        }
        
        completionHandler()
    }
    
    public func setupNotifications() {
        let categories = self.notificationCategories()
        UNUserNotificationCenter.current().setNotificationCategories(categories)
    }
    
    public func cancelAllNotifications() {
        debugPrint("Cancelling all notifications")
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UIApplication.shared.applicationIconBadgeNumber = 0
    }
    
    public func cancelNotification(categoryId: String) {
        debugPrint("Cancelling notification for reminder category \(categoryId)")
        UNUserNotificationCenter.current().getPendingNotificationRequests { (requests) in
            let requestIds: [String] = requests.compactMap {
                guard $0.content.categoryIdentifier == categoryId else { return nil }
                return $0.identifier
            }
           
            if requestIds.count > 0 {
               debugPrint("Cancelling notifications with ids \(requestIds)")
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: requestIds)
            } else {
                debugPrint("No existing notifications found to cancel")
            }
        }
    }
    
    open func notificationCategories() -> Set<UNNotificationCategory> {
        let defaultCategory = UNNotificationCategory(identifier: TaskReminderNotificationCategory,
                                              actions: [],
                                              intentIdentifiers: [], options: [])
        
        let lastCallCategory = UNNotificationCategory(identifier: LastCallTaskReminderNotificationCategory,
                                                      actions: [],
                                                      intentIdentifiers: [], options: [])
        
        return [defaultCategory, lastCallCategory]
    }
    
    public func updateWeeklyNotifications() {
        // Cancel any existing notifications
        self.cancelNotification(categoryId: TaskReminderNotificationCategory)
        self.cancelNotification(categoryId: LastCallTaskReminderNotificationCategory)
        
        // We have the do not remind answer, which means this reminder
        // type was saved during this task
        if (ReminderType.weekly.doNotRemindSetting() ?? false) {
            return  // User does not want notifications
        }
        
        guard BridgeSDK.authManager.isAuthenticated() else { return }
        
        // use dispatch async to allow the method to return and put updating reminders on the next run loop
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .denied:
                break   // Do nothing. We don't want to pester the user with message.
                case .notDetermined:
                    // The user has not given authorization, but the app has a record of previously requested.
                    // we still don't want to message the user about it
                    self.askForAuthorizationAndRescheduleNotifications()
                    break
                case .authorized, .provisional:
                    // We are authorized, proceed to scheduling notifications
                    self.scheduleWeeklyNotificationsAfterPermission()
                    break
                case .ephemeral:
                    // Not applicable to our app
                    break
                @unknown default:
                    // Do nothing.
                    break
                }
            }
        }
    }
    
    fileprivate func scheduleWeeklyNotificationsAfterPermission() {
        // Update weekly reminder notifications
        let type = ReminderType.weekly
        if !(type.doNotRemindSetting() ?? false),
            let time = type.timeSetting() {
            
            if let day = type.daySetting() {
                if let weekly = self.weeklyDateComponents(with: time, on: day) {
                    self.scheduleReminderNotification(for: type, dateComponents: weekly, identifier: type.rawValue)
                    
                    // Set last call notications if applicable
                    self.scheduleLastCallNotifications(reminderTimeComponents: weekly)
                }
            } else if let daily = self.dailyDateComponents(with: time) {
                self.scheduleReminderNotification(for: type, dateComponents: daily, identifier: type.rawValue)
            }
        }
    }
    
    func scheduleLastCallNotifications(reminderTimeComponents: DateComponents) {
        guard let lastCallDate = MasterScheduleManager.shared.currentBaseStudyCompletionRange()?.upperBound.addingNumberOfDays(-1) else {
            return
        }
        
        var lastCallDateComponents = Calendar.current.dateComponents([.hour, .minute, .day, .month, .weekOfYear, .year], from: lastCallDate)
        lastCallDateComponents.setValue(reminderTimeComponents.hour, for: .hour)
        lastCallDateComponents.setValue(reminderTimeComponents.minute, for: .minute)
        
        // If the user has not completed all of their activies this week, schedule
        // the last call notification
        if (!MasterScheduleManager.shared.areAllActivitiesCompletedThisWeek()) {
            self.scheduleLastCallReminderNotification(identifier: "WeeklyLastCall1", lastCallDateComponents: lastCallDateComponents)
        } else {
            debugPrint("Not scheduling this weeks last call reminder notification. User has already completed their activities")
        }
        
        // Always schedule next week's last call notification, just in case they don't open
        // their app for over a week.
        let nextWeeksLastCallDate = lastCallDate.addingNumberOfDays(7)
        var nextWeeksLastCallDateComponents = Calendar.current.dateComponents([.hour, .minute, .day, .month, .weekOfYear, .year], from: nextWeeksLastCallDate)
        nextWeeksLastCallDateComponents.setValue(reminderTimeComponents.hour, for: .hour)
        nextWeeksLastCallDateComponents.setValue(reminderTimeComponents.minute, for: .minute)
        self.scheduleLastCallReminderNotification(identifier: "WeeklyLastCall2", lastCallDateComponents: nextWeeksLastCallDateComponents)
    }
    
    func scheduleLastCallReminderNotification(identifier: String, lastCallDateComponents: DateComponents) {
        debugPrint("Scheduling \(identifier) last call reminder notification at time \(lastCallDateComponents.hour ?? 0):\(lastCallDateComponents.minute ?? 0) on  \(lastCallDateComponents.month ?? -1)/\(lastCallDateComponents.day ?? -1)/\(lastCallDateComponents.year ?? -1)")
        
        // Set up the notification
        let content = UNMutableNotificationContent()
        content.body = Localization.localizedString("LAST_CALL_NOTIFICATION_TITLE")
        content.sound = UNNotificationSound.default
        content.badge = NSNumber(integerLiteral: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.categoryIdentifier = LastCallTaskReminderNotificationCategory
        content.threadIdentifier = identifier
        
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: lastCallDateComponents, repeats: false)
        
        // Create the request.
        let request =  UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        self.scheduleNotificationRequest(request: request)
    }
    
    func scheduleReminderNotification(for type: ReminderType, dateComponents: DateComponents, identifier: String) {
        debugPrint("Scheduling notification reminder type \(type) at time \(dateComponents.hour ?? 0):\(dateComponents.minute ?? 0) on weekday \(dateComponents.weekday ?? -1)")
        
        // Set up the notification
        let content = UNMutableNotificationContent()
        content.body = type.notificationTitle()
        content.sound = UNNotificationSound.default
        content.badge = NSNumber(integerLiteral: UIApplication.shared.applicationIconBadgeNumber + 1)
        content.categoryIdentifier = TaskReminderNotificationCategory
        content.threadIdentifier = identifier
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create the request.
        let request =  UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // use dispatch async to allow the method to return and put updating reminders on the next run loop
        self.scheduleNotificationRequest(request: request)
    }
    
    func scheduleNotificationRequest(request: UNNotificationRequest) {
        // use dispatch async to allow the method to return and put updating reminders on the next run loop
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            DispatchQueue.main.async {
                switch settings.authorizationStatus {
                case .denied:
                break   // Do nothing. We don't want to pester the user with message.
                case .notDetermined:
                    // The user has not given authorization, but the app has a record of previously requested.
                    // we still don't want to message the user about it
                    break
                case .authorized, .provisional:
                    debugPrint("Notification authorized, adding request \(request)")
                    UNUserNotificationCenter.current().add(request) { error in
                        if (error != nil) {
                            debugPrint("Error scheduling notification \(request.identifier) \(String(describing: error?.localizedDescription))")
                        }
                    }
                    break
                case .ephemeral:
                    // Not applicable to our app
                    break
                @unknown default:
                    // Do nothing.
                    break
                }
            }
        }
    }
    
    func askForAuthorizationAndRescheduleNotifications() {
        // Request permission to display alerts and play sounds.
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        { (granted, error) in
            DispatchQueue.main.async {
                if (granted) {
                    self.updateWeeklyNotifications()
                }
            }
        }
    }
    
    func dailyDateComponents(with timeStr: String) -> DateComponents? {
        guard let date = timeFormatter.date(from: timeStr) else { return nil }
        return Calendar.current.dateComponents([.hour, .minute], from: date)
    }
    
    func weeklyDateComponents(with timeStr: String, on weekday: RSDWeekday) -> DateComponents? {
        guard let date = timeFormatter.date(from: timeStr) else { return nil }
        var dateComponents = Calendar.current.dateComponents([.hour, .minute], from: date)
        dateComponents.weekday = weekday.rawValue
        return dateComponents
    }
    
    open func hasReminderBeenScheduled(type: ReminderType) -> Bool {
        return type.hasBeenScheduled()
    }
    
    open func doNotRemindSetting(for type: ReminderType) -> Bool? {
        return type.doNotRemindSetting()
    }
    
    open func timeSetting(for type: ReminderType) -> String? {
        return type.timeSetting()
    }
    
    open func daySetting(for type: ReminderType) -> RSDWeekday? {
        return type.daySetting()
    }
}

public enum ReminderType: String, CaseIterable, Decodable {
    case weekly = "weekly"
    
    fileprivate func hasBeenScheduled() -> Bool {
        switch self {
        case .weekly:
            return HistoryDataManager.shared.haveWeeklyRemindersBeenSet
        }
    }
    
    fileprivate func doNotRemindSetting() -> Bool? {
        switch self {
        case .weekly:
            return HistoryDataManager.shared.reminderItem?.reminderDoNotRemindMe
        }
    }
    
    fileprivate func timeSetting() -> String? {
        switch self {
        case .weekly:
            return HistoryDataManager.shared.reminderItem?.reminderTime
        }
    }
    
    fileprivate func daySetting() -> RSDWeekday? {
        switch self {
        case .weekly:
            return HistoryDataManager.shared.reminderItem?.reminderWeekday
        }
    }
    
    func doNotRemindIdentifier() -> String {
        return "\(self.rawValue)\(ReminderStepObject.doNotRemindResultIdentifier)"
    }
    
    func timeRemindIdentifier() -> String {
        return "\(self.rawValue)\(ReminderStepObject.timeResultIdentifier)"
    }
    
    func dayRemindIdentifier() -> String {
        return "\(self.rawValue)\(ReminderStepObject.dayResultIdentifier)"
    }
    
    func setHasBeenScheduled() {
        UserDefaults.standard.set(true, forKey: "\(self.rawValue)\(ReminderStepObject.doNotRemindResultIdentifier)")
    }
    
    func notificationTitle() -> String {
        switch self {
        case .weekly:
            return Localization.localizedString("REMINDER_NOTIFICATION_TITLE")
        }
    }
    
    func defaultTime() -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        switch self {
        case .weekly: return formatter.string(from: Date())
        }
    }
    
    func defaultDay() -> String? {
        switch self {
        case .weekly: return RSDWeekday(date: Date()).text
        }
    }
    
    func imageTheme() -> RSDImageThemeElement? {
        return RSDFetchableImageThemeElementObject(imageName: "ReminderHeader")
    }
    
    func createReminderTaskViewController(defaultTime: String?, defaultDay: RSDWeekday?, doNotRemind: Bool?) -> RSDTaskViewController {
        let reminderStep = self.createReminderStep(defaultTime: defaultTime, defaultDay: defaultDay, doNotRemind: doNotRemind)
        var navigator = RSDConditionalStepNavigatorObject(with: [reminderStep])
        navigator.progressMarkers = []
        let task = RSDTaskObject(identifier: RSDIdentifier.remindersTask.rawValue, stepNavigator: navigator)
        return RSDTaskViewController(task: task)
    }
    
    func createReminderStep(defaultTime: String?, defaultDay: RSDWeekday?, doNotRemind: Bool?) -> ReminderStepObject {
        let reminderStep = ReminderStepObject(identifier: ReminderManager.reminderStepId)
        reminderStep.reminderType = self
        if let time = defaultTime {
            reminderStep.defaultTime = time
        } else {
            reminderStep.defaultTime = self.defaultTime()
        }
        if let day = defaultDay {
            reminderStep.defaultDayOfWeek = day.text
        } else {
            reminderStep.defaultDayOfWeek = self.defaultDay()
        }
        if let noReminder = doNotRemind {
            reminderStep.defaultDoNotRemind = noReminder
        } else {
            reminderStep.defaultDoNotRemind = false
        }
        reminderStep.hideDayOfWeek = false
        
        reminderStep.doNotRemindMeTitle = Localization.localizedString("NO_REMINDERS_PLEASE")
        reminderStep.title = self.stepTitle()
        reminderStep.text = self.stepText()
        reminderStep.detail = Localization.localizedString("SET_WEEKLY_REMINDER")
        
        reminderStep.imageTheme = self.imageTheme()
        reminderStep.shouldHideActions = [.navigation(.skip)]
        
        reminderStep.actions = [.navigation(.goForward) : RSDUIActionObject(buttonTitle: Localization.localizedString("SAVE_REMINDER_BUTTON"))]
        return reminderStep
    }
    
    func createReminderTaskViewController() -> RSDTaskViewController {
        let reminderStep = self.createReminderStep()
        var navigator = RSDConditionalStepNavigatorObject(with: [reminderStep])
        navigator.progressMarkers = []
        let task = RSDTaskObject(identifier: RSDIdentifier.remindersTask.rawValue, stepNavigator: navigator)
        return RSDTaskViewController(task: task)
    }
    
    func createReminderStep() -> ReminderStepObject {
        let reminderStep = ReminderStepObject(identifier: ReminderManager.reminderStepId)
        reminderStep.reminderType = self
        reminderStep.defaultTime = self.defaultTime()
        reminderStep.defaultDayOfWeek = self.defaultDay()
        reminderStep.hideDayOfWeek = false
        
        reminderStep.doNotRemindMeTitle = Localization.localizedString("NO_REMINDERS_PLEASE")
        reminderStep.title = self.stepTitle()
        reminderStep.text = self.stepText()
        reminderStep.detail = Localization.localizedString("SET_WEEKLY_REMINDER")
        
        reminderStep.imageTheme = self.imageTheme()
        reminderStep.shouldHideActions = [.navigation(.skip)]
        
        reminderStep.actions = [.navigation(.goForward) : RSDUIActionObject(buttonTitle: Localization.localizedString("SAVE_REMINDER_BUTTON"))]
        return reminderStep
    }
    
    func stepTitle() -> String? {
        switch self {
        case .weekly:
            return Localization.localizedString("REMINDER_WEEKLY_TITLE")
        }
    }
    
    fileprivate func stepText() -> String? {
        switch self {
        case .weekly:
            return Localization.localizedString("REMINDER_WEEKLY_TEXT")
        }
    }
}

