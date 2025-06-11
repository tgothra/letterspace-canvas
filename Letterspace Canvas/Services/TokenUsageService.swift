import Foundation
import Combine
import CloudKit

class TokenUsageService: ObservableObject {
    static let shared = TokenUsageService()
    
    // CloudKit configuration
    private let container = CKContainer.default()
    private let recordType = "TokenUsage"
    private let recordID = CKRecord.ID(recordName: "UserTokenUsage")
    
    // Base free limit - back to 1M as requested
    private let baseTokenLimit = 1_000_000
    // Price for additional 1M tokens
    private let additionalTokensPrice = "$5"
    // Size of token package
    private let additionalTokensAmount = 1_000_000
    
    @Published private(set) var currentUsage: Int = 0
    @Published private(set) var additionalTokensPurchased: Int = 0
    @Published private(set) var resetDate: Date = Date()
    @Published private(set) var isCloudKitAvailable: Bool = false
    @Published private(set) var lastSyncDate: Date? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkCloudKitAccountStatus()
        loadUsageData()
        checkForMonthlyReset()
        setupCloudKitSubscriptions()
    }
    
    // MARK: - CloudKit Account Management
    
    private func checkCloudKitAccountStatus() {
        container.accountStatus { [weak self] accountStatus, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ CloudKit account error: \(error.localizedDescription)")
                    self?.isCloudKitAvailable = false
                    return
                }
                
                switch accountStatus {
                case .available:
                    print("☁️ CloudKit account available")
                    self?.isCloudKitAvailable = true
                case .noAccount:
                    print("⚠️ No iCloud account")
                    self?.isCloudKitAvailable = false
                case .restricted:
                    print("⚠️ iCloud account restricted")
                    self?.isCloudKitAvailable = false
                case .couldNotDetermine:
                    print("⚠️ Could not determine iCloud account status")
                    self?.isCloudKitAvailable = false
                case .temporarilyUnavailable:
                    print("⚠️ iCloud temporarily unavailable")
                    self?.isCloudKitAvailable = false
                @unknown default:
                    print("⚠️ Unknown iCloud account status")
                    self?.isCloudKitAvailable = false
                }
            }
        }
    }
    
    // MARK: - Token Usage Management
    
    func loadUsageData() {
        if isCloudKitAvailable {
            loadFromCloudKit()
        } else {
            loadFromUserDefaults() // Fallback to local storage
        }
    }
    
    private func loadFromCloudKit() {
        let privateDatabase = container.privateCloudDatabase
        
        privateDatabase.fetch(withRecordID: recordID) { [weak self] record, error in
            DispatchQueue.main.async {
                if let error = error {
                    if let ckError = error as? CKError, ckError.code == .unknownItem {
                        print("☁️ No existing token usage record, creating new one")
                        self?.createInitialCloudKitRecord()
                    } else {
                        print("❌ Failed to load token usage from CloudKit: \(error.localizedDescription)")
                        self?.loadFromUserDefaults() // Fallback
                    }
                    return
                }
                
                guard let record = record else {
                    print("❌ No record returned from CloudKit")
                    self?.loadFromUserDefaults()
                    return
                }
                
                // Load data from CloudKit record
                self?.currentUsage = record["currentUsage"] as? Int ?? 0
                self?.additionalTokensPurchased = record["additionalTokensPurchased"] as? Int ?? 0
                self?.resetDate = record["resetDate"] as? Date ?? self?.calculateNextResetDate() ?? Date()
                self?.lastSyncDate = Date()
                
                print("☁️ Loaded token usage from CloudKit: \(self?.currentUsage ?? 0) tokens used")
                self?.objectWillChange.send()
            }
        }
    }
    
    private func loadFromUserDefaults() {
        print("📱 Loading token usage from local storage")
        currentUsage = UserDefaults.standard.integer(forKey: "com.letterspace.geminiTokenUsage")
        additionalTokensPurchased = UserDefaults.standard.integer(forKey: "com.letterspace.additionalTokens")
        
        if let savedDate = UserDefaults.standard.object(forKey: "com.letterspace.tokenResetDate") as? Date {
            resetDate = savedDate
        } else {
            resetDate = calculateNextResetDate()
            saveToUserDefaults()
        }
    }
    
    private func createInitialCloudKitRecord() {
        let record = CKRecord(recordType: recordType, recordID: recordID)
        record["currentUsage"] = currentUsage
        record["additionalTokensPurchased"] = additionalTokensPurchased
        record["resetDate"] = resetDate
        
        saveToCloudKit(record: record)
    }
    
    private func calculateNextResetDate() -> Date {
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month], from: Date())
            components.month = (components.month ?? 1) + 1
            components.day = 1
        return calendar.date(from: components) ?? Date()
    }
    
    func checkForMonthlyReset() {
        let now = Date()
        if now >= resetDate {
            // Reset usage and set new reset date
            currentUsage = 0
            resetDate = calculateNextResetDate()
            
            print("🔄 Monthly token usage reset")
            saveUsageData()
        }
    }
    
    var totalTokenLimit: Int {
        baseTokenLimit + (additionalTokensPurchased * additionalTokensAmount)
    }
    
    func canUseTokens(_ tokenCount: Int) -> Bool {
        checkForMonthlyReset()
        return currentUsage + tokenCount <= totalTokenLimit
    }
    
    func recordTokenUsage(_ tokenCount: Int) {
        checkForMonthlyReset()
        currentUsage += tokenCount
        saveUsageData()
        objectWillChange.send()
    }
    
    func recordEmbeddingUsage(_ tokenCount: Int) {
        checkForMonthlyReset()
        currentUsage += tokenCount
        saveUsageData()
        print("Recorded EMBEDDING usage: \(tokenCount) tokens. New total: \(currentUsage)")
        objectWillChange.send()
    }
    
    func recordQueryEmbeddingUsage(_ tokenCount: Int) {
        checkForMonthlyReset()
        currentUsage += tokenCount
        saveUsageData()
        print("Recorded QUERY embedding usage: \(tokenCount) tokens. New total: \(currentUsage)")
        objectWillChange.send()
    }
    
    func purchaseAdditionalTokens() {
        // In a real app, this would handle StoreKit payment processing
        // For now, just increment the additional tokens
        additionalTokensPurchased += 1
        saveUsageData()
        print("💳 Purchased additional 1M tokens. Total purchased: \(additionalTokensPurchased)")
        objectWillChange.send()
    }
    
    func remainingTokens() -> Int {
        return max(0, totalTokenLimit - currentUsage)
    }
    
    func usagePercentage() -> Double {
        return Double(currentUsage) / Double(totalTokenLimit)
    }
    
    func additionalTokenPrice() -> String {
        return additionalTokensPrice
    }
    
    // MARK: - Storage Helpers
    
    private func saveUsageData() {
        if isCloudKitAvailable {
            saveToCloudKit()
        } else {
            saveToUserDefaults()
        }
    }
    
    private func saveToCloudKit(record: CKRecord? = nil) {
        let privateDatabase = container.privateCloudDatabase
        
        if let existingRecord = record {
            // Use provided record (for initial creation)
            privateDatabase.save(existingRecord) { [weak self] savedRecord, error in
                DispatchQueue.main.async {
                    if let error = error {
                        print("❌ Failed to save initial token usage to CloudKit: \(error.localizedDescription)")
                        self?.saveToUserDefaults() // Fallback
                    } else {
                        print("☁️ Created initial token usage record in CloudKit")
                        self?.lastSyncDate = Date()
                    }
                }
            }
        } else {
            // Fetch existing record and update it
            privateDatabase.fetch(withRecordID: recordID) { [weak self] fetchedRecord, error in
                if let error = error {
                    print("❌ Failed to fetch record for update: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self?.saveToUserDefaults() // Fallback
                    }
                    return
                }
                
                guard let record = fetchedRecord else {
                    print("❌ No record to update")
                    return
                }
                
                // Update record with current values
                record["currentUsage"] = self?.currentUsage
                record["additionalTokensPurchased"] = self?.additionalTokensPurchased
                record["resetDate"] = self?.resetDate
                
                // Save updated record
                privateDatabase.save(record) { savedRecord, saveError in
                    DispatchQueue.main.async {
                        if let saveError = saveError {
                            print("❌ Failed to update token usage in CloudKit: \(saveError.localizedDescription)")
                            self?.saveToUserDefaults() // Fallback
                        } else {
                            print("☁️ Updated token usage in CloudKit")
                            self?.lastSyncDate = Date()
                        }
                    }
                }
            }
        }
    }
    
    private func saveToUserDefaults() {
        UserDefaults.standard.set(currentUsage, forKey: "com.letterspace.geminiTokenUsage")
        UserDefaults.standard.set(additionalTokensPurchased, forKey: "com.letterspace.additionalTokens")
        UserDefaults.standard.set(resetDate, forKey: "com.letterspace.tokenResetDate")
        print("📱 Saved token usage to local storage")
    }
    
    // MARK: - CloudKit Subscriptions (for real-time sync)
    
    private func setupCloudKitSubscriptions() {
        guard isCloudKitAvailable else { return }
        
        // Create subscription for token usage changes
        let subscription = CKQuerySubscription(
            recordType: recordType,
            predicate: NSPredicate(format: "recordID == %@", recordID),
            options: [.firesOnRecordUpdate]
        )
        
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
        
        let privateDatabase = container.privateCloudDatabase
        privateDatabase.save(subscription) { savedSubscription, error in
            if let error = error {
                print("❌ Failed to create CloudKit subscription: \(error.localizedDescription)")
            } else {
                print("☁️ Created CloudKit subscription for token usage sync")
            }
        }
    }
    
    // MARK: - Manual Sync
    
    func forceSyncFromCloud() {
        guard isCloudKitAvailable else {
            print("⚠️ CloudKit not available for sync")
            return
        }
        
        loadFromCloudKit()
    }
} 