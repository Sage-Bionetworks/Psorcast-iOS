//
//  ReminderStepViewController.swift
//  Psorcast
//
//  Copyright © 2018-2019 Sage Bionetworks. All rights reserved.
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

import UIKit
import MotorControl
import BridgeApp
import UserNotifications

class ReminderStepObject : RSDUIStepObject, RSDStepViewControllerVendor {
    
    private enum CodingKeys: String, CodingKey, CaseIterable {
        case hideDayOfWeek, defaultTime, defaultDayOfWeek, defaultDoNotRemind, doNotRemindMeTitle, reminderType
    }
    
    public static func timeResultId(for type: ReminderType) -> String {
        return "\(type.rawValue)\(timeResultIdentifier)"
    }
    public static let timeResultIdentifier = "Time"
    public static func dayResultId(for type: ReminderType) -> String {
        return "\(type.rawValue)\(dayResultIdentifier)"
    }
    public static let dayResultIdentifier = "Day"
    public static let dayOfWeekResultIdentifier = "DayOfWeek"
    public static func doNotRemindMeResultId(for type: ReminderType) -> String {
        return "\(type.rawValue)\(doNotRemindResultIdentifier)"
    }
    public static let doNotRemindResultIdentifier = "DoNotRemind"
    
    /// If true, only the time of day field will show
    public var hideDayOfWeek: Bool?
    /// The default value of the time picker
    public var defaultTime: String?
    /// The default value of the do not remind
    public var defaultDoNotRemind: Bool?
    /// The default value of the day of week picker
    public var defaultDayOfWeek: String?
    /// The title of the do not remind me checkbox
    public var doNotRemindMeTitle: String?
    
    /// The type of reminder to schedule
    public var reminderType: ReminderType = .weekly
    
    override open class func defaultType() -> RSDStepType {
        return .reminder
    }
    
    open func instantiateViewController(with parent: RSDPathComponent?) -> (UIViewController & RSDStepController)? {
        return ReminderStepViewController(step: self, parent: parent)
    }

    override open func decode(from decoder: Decoder, for deviceType: RSDDeviceType?) throws {
        try super.decode(from: decoder, for: deviceType)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        if container.contains(.hideDayOfWeek) {
            self.hideDayOfWeek = try container.decode(Bool.self, forKey: .hideDayOfWeek)
        }
        if container.contains(.defaultTime) {
            self.defaultTime = try container.decode(String.self, forKey: .defaultTime)
        }
        if container.contains(.defaultDayOfWeek) {
            self.defaultDayOfWeek = try container.decode(String.self, forKey: .defaultDayOfWeek)
        }
        if container.contains(.defaultDoNotRemind) {
            self.defaultDoNotRemind = try container.decode(Bool.self, forKey: .defaultDoNotRemind)
        }
        if container.contains(.doNotRemindMeTitle) {
            self.doNotRemindMeTitle = try container.decode(String.self, forKey: .doNotRemindMeTitle)
        }
        
        self.reminderType = try container.decode(ReminderType.self, forKey: .reminderType)
    }
    
    override open func copyInto(_ copy: RSDUIStepObject) {
        super.copyInto(copy)
        
        guard let copy = copy as? ReminderStepObject else {
            debugPrint("Invalid copy sub-class type")
            return
        }
        
        copy.hideDayOfWeek = self.hideDayOfWeek
        copy.defaultTime = self.defaultTime
        copy.defaultDayOfWeek = self.defaultDayOfWeek
        copy.defaultDoNotRemind = self.defaultDoNotRemind
        copy.doNotRemindMeTitle = self.doNotRemindMeTitle
        copy.reminderType = self.reminderType
    }
}

class ReminderStepViewController: RSDStepViewController, UIScrollViewDelegate, UIPickerViewDataSource, UIPickerViewDelegate {
    
    /// Scroll view holding all the content but the footer view
    @IBOutlet public var scrollView: UIScrollView!
    
    /// Reminder time button to open up time picker
    @IBOutlet public var reminderTimeButton: UIButton!
    /// Day of week button to open up the picker
    @IBOutlet public var dayOfWeekButton: UIButton!
    /// The checkbox button to not remind the user
    @IBOutlet public var doNotRemindMeButton: UIButton!
    
    /// THe heights of the day of week which can be hidden by the step
    @IBOutlet public var dayOfWeekHeight: NSLayoutConstraint!
    @IBOutlet public var dayOfWeekRuleViewHeight: NSLayoutConstraint!
    
    /// Reminder manager for this step view controller
    var reminderManager: ReminderManager {
        return ReminderManager.shared
    }
    
    /// Time picker that shows when user taps reminder time button
    let timePicker = UIDatePicker()
    var timePickerFormatter: DateFormatter {
        return self.reminderManager.timeFormatter
    }
    
    /// The day of week picker that shows when user taps day of week button
    let dayOfWeekPicker = UIPickerView()
    
    /// The top and bottom rule dividers
    @IBOutlet var ruleViews: Array<UIView>?
    
    /// The textfield that shows picker as keyboard
    /// we must have one, but don't want it to display to the user
    @IBOutlet public var hiddenPickerTextfield: UITextField!
    
    var reminderStep: ReminderStepObject? {
        return self.step as? ReminderStepObject
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        // Looks for single taps to dismiss keyboard
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(dismissKeyboard))
        view.addGestureRecognizer(tap)
        
        self.initPickers()
        self.initDoNotRemindMeButton()
        self.updateDesignSystem()
        self.refreshUI()
    }
    
    override open func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        self.refreshFooterShadow()
    }
    
    func initDoNotRemindMeButton() {
        self.doNotRemindMeButton.isSelected = self.reminderStep?.defaultDoNotRemind ?? false
    }
    
    func initPickers() {
        self.doNotRemindMeButton.isSelected = false
        
        self.timePicker.isHidden = true
        self.timePicker.datePickerMode = .time
        self.timePicker.addTarget(self, action: #selector(self.timeChanged), for: .valueChanged)
        
        if let defaultTime = self.reminderStep?.defaultTime {
            self.timePicker.date = self.time(from: defaultTime)
            self.reminderTimeButton.setTitle(defaultTime, for: .normal)
        } else {
            self.timePicker.date = self.time(from: "9:00 AM")
            self.reminderTimeButton.setTitle("9:00 AM", for: .normal)
        }
        
        self.dayOfWeekPicker.isHidden = true
        self.dayOfWeekPicker.dataSource = self
        self.dayOfWeekPicker.delegate = self
                
        if self.reminderStep?.hideDayOfWeek ?? false {
            self.dayOfWeekButton.setTitle(nil, for: .normal)
        } else if let defaultDay = self.reminderStep?.defaultDayOfWeek,
            let weekday = self.weekday(from: defaultDay) {
            self.dayOfWeekPicker.selectRow(weekday.rawValue - 1, inComponent: 0, animated: false)
            self.dayOfWeekButton.setTitle(weekday.text, for: .normal)
        } else {
            self.dayOfWeekPicker.selectRow(RSDWeekday.saturday.rawValue - 1, inComponent: 0, animated: false)
            self.dayOfWeekButton.setTitle(RSDWeekday.saturday.text, for: .normal)
        }
    }
    
    func time(from str: String) -> Date {
        return timePickerFormatter.date(from: str) ?? Date()
    }
    
    func updateDesignSystem() {
        let design = AppDelegate.designSystem
        let background = design.colorRules.backgroundLight
        
        self.reminderTimeButton.titleLabel?.font = design.fontRules.font(for: .small)
        self.reminderTimeButton.setTitleColor(design.colorRules.textColor(on: background, for: .small), for: .normal)
        
        self.dayOfWeekButton.titleLabel?.font = design.fontRules.font(for: .small)
        self.dayOfWeekButton.setTitleColor( design.colorRules.textColor(on: background, for: .small), for: .normal)
        
        self.doNotRemindMeButton.titleLabel?.font = design.fontRules.font(for: .small)
        self.doNotRemindMeButton.setTitleColor( design.colorRules.textColor(on: background, for: .small), for: .normal)
        
        self.ruleViews?.forEach { $0.backgroundColor = design.colorRules.palette?.grayScale.mapping(forShade: .lightGray).light.color }
    }
    
    func refreshUI() {
        self.doNotRemindMeButton?.setTitle(self.reminderStep?.doNotRemindMeTitle, for: .normal)
        
        if self.reminderStep?.hideDayOfWeek ?? false {
            self.dayOfWeekHeight.constant = 0
            self.dayOfWeekRuleViewHeight.constant = 0
        }
        
        self.refreshFooterShadow()
    }
    
    func refreshFooterShadow() {
        guard let footerY = self.navigationFooter?.frame.height else { return }
        let isContentScrollable = self.scrollView.contentSize.height > footerY
        
        if !isContentScrollable {
            self.navigationFooter?.shouldShowShadow = false
            return
        }
        
        self.navigationFooter?.shouldShowShadow = !self.scrollView.isAtBottom
    }
    
    override open func setupHeader(_ header: RSDStepNavigationView) {
        super.setupHeader(header)
        let design = AppDelegate.designSystem
        let background = design.colorRules.backgroundLight
        self.navigationHeader?.backgroundColor = background.color
        self.navigationHeader?.detailLabel?.font = design.fontRules.font(for: .smallHeader)
        self.navigationHeader?.detailLabel?.textColor = design.colorRules.textColor(on: background, for: .smallHeader)
    }
    
    @IBAction func reminderTimeTapped() {
        self.toggleTimePicker()
    }
    
    func toggleTimePicker() {
        if !self.dayOfWeekPicker.isHidden {
            hideDayPicker()
        }
        
        if self.timePicker.isHidden {
            self.showTimePicker()
        } else {
            self.hideTimePicker()
        }
    }
    
    func hideTimePicker() {
        self.timePicker.isHidden = true
        self.hiddenPickerTextfield.resignFirstResponder()
    }
    
    func showTimePicker() {
        self.hiddenPickerTextfield.inputView = self.timePicker
        self.timePicker.isHidden = false
        self.hiddenPickerTextfield.becomeFirstResponder()
    }
    
    @IBAction func dayOfWeekTapped() {
        toggleDayPicker()
    }
    
    func toggleDayPicker() {
        if !self.timePicker.isHidden {
            hideTimePicker()
        }
        
        if self.dayOfWeekPicker.isHidden {
            self.showDayPicker()
        } else {
            self.hideDayPicker()
        }
    }
    
    func hideDayPicker() {
        self.dayOfWeekPicker.isHidden = true
        self.hiddenPickerTextfield.resignFirstResponder()
    }
    
    func showDayPicker() {
        self.hiddenPickerTextfield.inputView = self.dayOfWeekPicker
        self.dayOfWeekPicker.isHidden = false
        self.hiddenPickerTextfield.becomeFirstResponder()
    }
    
    @IBAction func doNotRemindMeTapped() {
        self.dismissKeyboard()
        self.doNotRemindMeButton.isSelected = !self.doNotRemindMeButton.isSelected
    }
    
    /// UIScrollViewDelegate
    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        self.refreshFooterShadow()
    }
    
    @objc func timeChanged(sender: UIDatePicker) {
        let timeStr = timePickerFormatter.string(from: sender.date)
        self.reminderTimeButton.setTitle(timeStr, for: .normal)
    }
    
    //Calls this function when the tap is recognized.
    @objc func dismissKeyboard() {
        self.timePicker.isHidden = true
        self.dayOfWeekPicker.isHidden = true
        //Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
        self.view.frame.origin.y = 0
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            self.view.frame.origin.y -= keyboardSize.height
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        self.view.frame.origin.y = 0
    }
    
    override open func goForward() {
        
        if self.doNotRemindMeButton.isSelected {
            // No need to request persmission if we are not reminding the user
            self.saveResultAndGoForward()
            return
        }
        
        self.navigationFooter?.nextButton?.isEnabled = false
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .authorized {
                    // Already authorized, let user proceed
                    self.navigationFooter?.nextButton?.isEnabled = true
                    self.saveResultAndGoForward()
                    return
                }
                
                // Request permission to display alerts and play sounds.
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                { (granted, error) in
                    DispatchQueue.main.async {
                        // Enable or disable features based on authorization.
                        self.navigationFooter?.nextButton?.isEnabled = true
                        if granted {
                            self.saveResultAndGoForward()
                        } else {
                            let title = Localization.localizedString("NOT_AUTHORIZED")
                            let message = Localization.localizedString("REMINDER_PERMISSION_ERROR")
                            
                            var actions = [UIAlertAction]()
                            if let url = URL(string:UIApplication.openSettingsURLString),
                                UIApplication.shared.canOpenURL(url) {
                                let settingsAction = UIAlertAction(title: Localization.localizedString("GOTO_SETTINGS"), style: .default) { (_) in
                                    self.doNotRemindMeButton.isSelected = true
                                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                                }
                                actions.append(settingsAction)
                            }
                            
                            let okAction = UIAlertAction(title: Localization.buttonOK(), style: .default) { (_) in
                                // no-op other than dismiss
                                self.doNotRemindMeButton.isSelected = true
                            }
                            actions.append(okAction)
                            self.presentAlertWithActions(title: title, message: message, preferredStyle: .alert, actions: actions)
                        }
                    }
                }
            }
        }
    }
    
    func saveResultAndGoForward() {
        guard let reminderType = self.reminderStep?.reminderType else {
            debugPrint("Must have a reminder type")
            return
        }
        
        if !(self.reminderStep?.hideDayOfWeek ?? false),
            let dayStr = self.dayOfWeekButton.title(for: .normal),
            let weekday = self.weekday(from: dayStr) {
            
            let dayResult = self.createDayResult(day: weekday, for: reminderType)
            self.stepViewModel.parentTaskPath?.taskResult.stepHistory.append(dayResult)
            
            // Day of week is only used for Synapse upload
            let dayOfWeekResult = self.createDayOfWeekResult(day: weekday, for: reminderType)
            self.stepViewModel.parentTaskPath?.taskResult.stepHistory.append(dayOfWeekResult)
        }
        
        if let timeStr = self.reminderTimeButton.title(for: .normal) {
            let timeResult = self.createTimeReseult(timeStr: timeStr, for: reminderType)
            self.stepViewModel.parentTaskPath?.taskResult.stepHistory.append(timeResult)
        }
        
        let doNotRemindResult = self.createDoNotRemindResult(doNotRemind: self.doNotRemindMeButton.isSelected, for: reminderType)
        self.stepViewModel.parentTaskPath?.taskResult.stepHistory.append(doNotRemindResult)
        
        super.goForward()
    }
    
    func createTimeReseult(timeStr: String, for type: ReminderType) -> RSDAnswerResult {
        return RSDAnswerResultObject(identifier: ReminderStepObject.timeResultId(for: type), answerType: .string, value: timeStr)
    }
    
    func createDoNotRemindResult(doNotRemind: Bool, for type: ReminderType) -> RSDAnswerResult {
        return RSDAnswerResultObject(identifier: ReminderStepObject.doNotRemindMeResultId(for: type), answerType: .boolean, value: doNotRemind)
    }
    
    func createDayResult(day: RSDWeekday, for type: ReminderType) -> RSDAnswerResult {
        return RSDAnswerResultObject(identifier: ReminderStepObject.dayResultId(for: type), answerType: .integer, value: day.rawValue)
    }
    
    func createDayOfWeekResult(day: RSDWeekday, for type: ReminderType) -> RSDAnswerResult {
        return RSDAnswerResultObject(identifier: "\(type.rawValue)\(ReminderStepObject.dayOfWeekResultIdentifier)", answerType: .string, value: day.text)
    }
    
    func weekday(from weekdayTitle: String) -> RSDWeekday? {
        return RSDWeekday.all.first(where: { $0.text == weekdayTitle })
    }
    
    /// UIPickerViewDataSource
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return RSDWeekday.all.count
    }
    
    /// UIPickerViewDelegate
    
    public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return RSDWeekday(rawValue: row + 1)?.text
    }
    
    public func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if let weekday = RSDWeekday(rawValue: row + 1) {
            self.dayOfWeekButton.setTitle(weekday.text, for: .normal)
        }
    }
}

extension UIScrollView {
    var isAtBottom: Bool {
        return contentOffset.y >= verticalOffsetForBottom
    }
    
    var verticalOffsetForTop: CGFloat {
        let topInset = contentInset.top
        return -topInset
    }
    
    var verticalOffsetForBottom: CGFloat {
        let scrollViewHeight = bounds.height
        let scrollContentSizeHeight = contentSize.height
        let bottomInset = contentInset.bottom
        let scrollViewBottomOffset = scrollContentSizeHeight + bottomInset - scrollViewHeight
        return scrollViewBottomOffset
    }
}
