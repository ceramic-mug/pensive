import Foundation
import Combine

class UbiquitousStore: ObservableObject {
    static let shared = UbiquitousStore()
    private let store = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        NotificationCenter.default.publisher(for: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .sink { [weak self] notification in
                self?.handleExternalChange(notification)
            }
            .store(in: &cancellables)
        
        store.synchronize()
    }
    
    func set(_ value: Any?, forKey key: String) {
        // Prevent infinite loop by checking if the value is already set in the cloud store
        let cloudValue = store.object(forKey: key)
        if let cloudValue = cloudValue, let newValue = value, "\(cloudValue)" == "\(newValue)" {
            return
        }
        
        store.set(value, forKey: key)
        store.synchronize()
        
        // Ensure local UserDefaults is in sync (this will trigger @AppStorage)
        let localValue = UserDefaults.standard.object(forKey: key)
        if let localValue = localValue, let newValue = value, "\(localValue)" == "\(newValue)" {
            return
        }
        UserDefaults.standard.set(value, forKey: key)
    }
    
    func updateFromCloud(keys: [String]) {
        for key in keys {
            if let value = store.object(forKey: key) {
                UserDefaults.standard.set(value, forKey: key)
            }
        }
    }
    
    private func handleExternalChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else { return }
        
        if reason == NSUbiquitousKeyValueStoreServerChange || reason == NSUbiquitousKeyValueStoreInitialSyncChange {
            if let changedKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
                for key in changedKeys {
                    if let value = store.object(forKey: key) {
                        UserDefaults.standard.set(value, forKey: key)
                    }
                }
            }
        }
    }
}
