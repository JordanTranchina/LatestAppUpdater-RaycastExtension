import Foundation

/// A CLI-compatible version of MacAppStoreUpdateOperation that uses dynamic CommerceKit loading.
class CLIMASUpdateOperation: NSObject {
    
    private let bundleIdentifier: String
    private let itemIdentifier: UInt64
    private let progressHandler: (UpdateOperation.ProgressState) -> Void
    
    private var observerIdentifier: AnyObject?
    
    init(bundleIdentifier: String, itemIdentifier: UInt64, progressHandler: @escaping (UpdateOperation.ProgressState) -> Void) {
        self.bundleIdentifier = bundleIdentifier
        self.itemIdentifier = itemIdentifier
        self.progressHandler = progressHandler
        super.init()
    }
    
    func start() {
        guard CommerceKitLite.shared.isAvailable else {
            progressHandler(.error(LatestError.updateInfoUnavailable))
            return
        }
        
        progressHandler(.initializing)
        
        // Construct purchase
        guard let SSPurchase = CommerceKitLite.shared.purchaseClass as? NSObject.Type else {
            progressHandler(.error(LatestError.updateInfoUnavailable))
            return
        }
        
        let purchase = SSPurchase.init()
        
        // Setup purchase buy parameters (simplified version for CLI)
        // In the real app, this is more complex, but we'll try to trigger a redownload.
        let parameters = [
            "productType": "C",
            "price": 0,
            "salableAdamId": itemIdentifier,
            "pg": "default",
            "appExtVrsId": 0,
            "pricingParameters": "STDRDL"
        ] as [String : Any]
        
        let buyParams = parameters.map { "\($0.key)=\($0.value)" }.joined(separator: "&")
        purchase.setValue(buyParams, forKey: "buyParameters")
        
        if let SSDownloadMetadata = CommerceKitLite.shared.downloadMetadataClass as? NSObject.Type {
            let metadata = SSDownloadMetadata.init()
            metadata.setValue("software", forKey: "kind")
            metadata.setValue(itemIdentifier, forKey: "itemIdentifier")
            purchase.setValue(metadata, forKey: "downloadMetadata")
        }
        
        purchase.setValue(itemIdentifier, forKey: "itemIdentifier")
        
        // Perform purchase
        guard let controllerClass = CommerceKitLite.shared.purchaseControllerClass as? CKPurchaseControllerProtocol.Type else {
            progressHandler(.error(LatestError.updateInfoUnavailable))
            return
        }
        
        controllerClass.shared().perform(purchase, withOptions: 0) { [weak self] _, _, error, response in
            guard let self = self else { return }
            
            if let error = error {
                self.progressHandler(.error(error))
                return
            }
            
            // Check for downloads in response
            // Response is of type SSPurchaseResponse, we check its 'downloads' property
            if let response = response as? NSObject,
               let downloads = response.value(forKey: "downloads") as? [AnyObject],
               !downloads.isEmpty {
                
                // Add observer to queue
                if let queueClass = CommerceKitLite.shared.downloadQueueClass as? CKDownloadQueueProtocol.Type {
                    self.observerIdentifier = queueClass.shared().add(self)
                }
            } else {
                self.progressHandler(.error(LatestError.updateInfoUnavailable))
            }
        }
    }
}

// MARK: - Dynamic Selectors for Download Progress
extension CLIMASUpdateOperation {
    
    // We use @objc and match the signature that CommerceKit expects for its observers
    @objc func downloadQueue(_ queue: AnyObject, statusChangedFor download: AnyObject) {
        guard let download = download as? NSObject else { return }
        
        // Extract metadata item identifier
        guard let metadata = download.value(forKey: "metadata") as? NSObject,
              let downloadId = metadata.value(forKey: "itemIdentifier") as? UInt64,
              downloadId == self.itemIdentifier else {
            return
        }
        
        guard let status = download.value(forKey: "status") as? NSObject else { return }
        
        // Check for failure/cancellation
        let isFailed = (status.value(forKey: "isFailed") as? Bool) ?? false
        let isCancelled = (status.value(forKey: "isCancelled") as? Bool) ?? false
        
        if isFailed || isCancelled {
            let error = status.value(forKey: "error") as? Error
            progressHandler(.error(error ?? LatestError.updateInfoUnavailable))
            return
        }
        
        // Extract progress
        if let activePhase = status.value(forKey: "activePhase") as? NSObject {
            let phaseType = (activePhase.value(forKey: "phaseType") as? Int) ?? -1
            let progress = (activePhase.value(forKey: "progressValue") as? Int64) ?? 0
            let total = (activePhase.value(forKey: "totalProgressValue") as? Int64) ?? 1
            
            switch phaseType {
            case 0: // Downloading
                progressHandler(.downloading(loadedSize: progress, totalSize: total))
            case 1: // Extracting
                progressHandler(.extracting(progress: Double(progress) / Double(total)))
            default:
                progressHandler(.installing)
            }
        }
    }
    
    @objc func downloadQueue(_ queue: AnyObject, changedWithRemoval download: AnyObject) {
        guard let download = download as? NSObject else { return }
        
        // Extract metadata item identifier
        guard let metadata = download.value(forKey: "metadata") as? NSObject,
              let downloadId = metadata.value(forKey: "itemIdentifier") as? UInt64,
              downloadId == self.itemIdentifier else {
            return
        }
        
        progressHandler(.none) // Finished
    }
}
