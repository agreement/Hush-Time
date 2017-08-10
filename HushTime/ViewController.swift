//
//  ViewController.swift
//  HushTime
//
//  Created by Keegan Rush on 2017/06/21.
//  Copyright © 2017 TheCodedSelf. All rights reserved.
//

import Cocoa

private struct Keys {
    static let selectedApps = "selectedApps"
    static let selectedTime = "selectedTime"
}

private enum State {
    case running
    case notRunning
}

struct SelectedApps {
    
    var apps: [String] {
        get {
            return NSOrderedSet(array: unorderedApps).array as? [String] ?? unorderedApps
        }
        set {
            unorderedApps = newValue.sorted()
        }
    }
    
    private var unorderedApps = [String]()
}

class ViewController: NSViewController {

    @IBOutlet weak var tableHeaderView: NSTableHeaderView!
    @IBOutlet private weak var selectedAppsHeaderLabel: NSTextField!
    @IBOutlet private weak var emptyStateLabel: NSTextField!
    @IBOutlet private weak var timeSelector: TimeSelector!
    @IBOutlet private weak var remainingTimeLabel: NSTextField!
    @IBOutlet private weak var selectedAppsSourceList: NSOutlineView!
    @IBOutlet weak var startButton: NSButton!
    private var shouldPresentNotificationOnFinish = true
    
    fileprivate var selectedApps = SelectedApps() {
        didSet {
            selectedAppsSourceList.reloadData()
            startButton.isEnabled = !selectedApps.apps.isEmpty
            if selectedApps.apps.isEmpty { showEmptyState() }
            else { hideEmptyState() }
        }
    }
    
    private var state: State = .notRunning {
        didSet {
            configureViewForCurrentState()
        }
    }
    
    private var remainingTime = Measurement(value: 25, unit: UnitDuration.minutes) {
        didSet {
            configureViewForRemainingSeconds()
        }
    }
    
    private var hushTimeBlock: HushTimeBlock?
    /*
     - Add a title to the selected apps (like the empty state title)
     - little tomato icon to start pomodoro
     - little ding sound rather than default notification
     - get an icon
     - Icons next to selected apps
     - Pretty the UI
     
 */
    
    override func viewWillAppear() {
        super.viewWillAppear()
        configureViewForCurrentState()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        firstTimeSetup()
    }
    
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    private func firstTimeSetup() {
        
        selectedAppsSourceList.headerView = tableHeaderView
        selectedAppsSourceList.dataSource = self
        selectedAppsSourceList.delegate = self
        selectedAppsSourceList.reloadData()
        
        if let selectedApps = UserDefaults.standard.stringArray(forKey: Keys.selectedApps) {
            self.selectedApps.apps = selectedApps
        }
        let time = UserDefaults.standard.double(forKey: Keys.selectedTime)
        remainingTime = Measurement(value: time, unit: UnitDuration.seconds)
        timeSelector.populate(with: remainingTime)
        
    }

    @IBAction func startHushTime(_ sender: NSButton) {
        persistValues()
        startHushTimeBlock()
        shouldPresentNotificationOnFinish = true
    }
    
    private func persistValues() {
        
        remainingTime = timeSelector.value
        UserDefaults.standard.set(
            timeSelector.value.converted(to: .seconds).value,
            forKey: Keys.selectedTime)
        UserDefaults.standard.set(selectedApps.apps, forKey: Keys.selectedApps)
    }
    
    private func startHushTimeBlock() {

        state = .running
        
        ProcessInfo.processInfo.disableAutomaticTermination("A timer is running")
        
        hushTimeBlock = HushTimeBlock(appNames: selectedApps.apps,
                                      time: timeSelector.value,
                                      fireOnUpdate: { [weak self] in
                                        self?.remainingTime = $0
        })
        
        hushTimeBlock?.start()
    }

    @IBAction func stopHushTime(_ sender: NSButton) {
        
        shouldPresentNotificationOnFinish = false
        ProcessInfo.processInfo.enableAutomaticTermination("The timer is complete")
        hushTimeBlock?.finish()
        state = .notRunning
    }
    
    @IBAction func addAppClicked(_ sender: Any) {
        AppNamesPicker().pickAppNames{ self.selectedApps.apps += $0 }
    }
    
    @IBAction func removeAppClicked(_ sender: Any) {
        
        selectedApps.apps = selectedApps.apps.filter {
            !self.selectedAppsSourceList.isRowSelected(self.selectedApps.apps.index(of: $0) ?? -1)
        }
        selectedAppsSourceList.deselectAll(self)
    }

    private func configureViewForCurrentState() {
        
        let isRunning = state == .running
        remainingTimeLabel.isHidden = !isRunning
        timeSelector.isHidden = isRunning
        selectedAppsSourceList.allowsMultipleSelection = true
    }
    
    private func configureViewForRemainingSeconds() {
        
        guard remainingTime.value > 0 else {
            handleFinish()
            return
        }
        
        let hours = Int(remainingTime.converted(to: .hours).value)
        let minutes = Int(remainingTime.converted(to: .minutes).value
            .truncatingRemainder(dividingBy: 60))
        let seconds = Int(remainingTime.converted(to: .seconds).value
            .truncatingRemainder(dividingBy: 60))

        func leftPadded(_ integer: Int) -> String {
            let string = "\(integer)"
            let isOnlySingleDigit = string.characters.count < 2
            return isOnlySingleDigit ? "0\(string)" : string
        }
        
        remainingTimeLabel.stringValue =
        "\(leftPadded(hours)):\(leftPadded(minutes)):\(leftPadded(seconds))"
    }
    
    private func handleFinish() {
        state = .notRunning
        if shouldPresentNotificationOnFinish {
            showNotification(text: "Time block finished")
        }
    }
    
    private func showNotification(text: String) {
        let notification = NSUserNotification()
        notification.informativeText = text
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    private func hideEmptyState() {
        emptyStateLabel.isHidden = true
        selectedAppsHeaderLabel.stringValue = "Selected Apps"
    }
    
    private func showEmptyState() {
        emptyStateLabel.isHidden = false
        selectedAppsHeaderLabel.stringValue = "No Apps Selected"
    }
}

extension ViewController: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, shouldEdit tableColumn: NSTableColumn?, item: Any) -> Bool {
        return false
    }
}
extension ViewController: NSOutlineViewDataSource {
    
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        return selectedApps.apps.count
    }
    
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        return selectedApps.apps[index]
    }
    
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
    
    func outlineView(_ outlineView: NSOutlineView, objectValueFor tableColumn: NSTableColumn?, byItem item: Any?) -> Any? {
        return item
    }
    
}
