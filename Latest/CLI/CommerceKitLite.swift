import Foundation

// MARK: - Private Framework Protocols

@objc protocol CKPurchaseControllerProtocol: NSObjectProtocol {
    static func shared() -> CKPurchaseControllerProtocol
    func perform(_ purchase: AnyObject, withOptions options: Int, completionHandler: @escaping (AnyObject?, AnyObject?, Error?, AnyObject?) -> Void)
}

@objc protocol CKDownloadQueueProtocol: NSObjectProtocol {
    static func shared() -> CKDownloadQueueProtocol
    func add(_ observer: AnyObject) -> AnyObject
    func remove(_ observerIdentifier: AnyObject)
    func removeDownload(withItemIdentifier identifier: UInt64)
}

@objc protocol SSDownloadMetadataProtocol: NSObjectProtocol {
    var kind: String? { get set }
    var itemIdentifier: UInt64 { get set }
}

@objc protocol SSDownloadProtocol: NSObjectProtocol {
    var metadata: AnyObject { get }
    var status: AnyObject? { get }
    func cancel(withStoreClient client: AnyObject)
}

// MARK: - Dynamic CommerceKit Loader

class CommerceKitLite {
    static let shared = CommerceKitLite()
    
    private(set) var purchaseControllerClass: AnyClass?
    private(set) var downloadQueueClass: AnyClass?
    private(set) var purchaseClass: AnyClass?
    private(set) var downloadMetadataClass: AnyClass?
    private(set) var storeAccountClass: AnyClass?
    private(set) var serviceProxyClass: AnyClass?
    
    init() {
        loadFrameworks()
    }
    
    private func loadFrameworks() {
        let commerceKitPath = "/System/Library/PrivateFrameworks/CommerceKit.framework/CommerceKit"
        let storeFoundationPath = "/System/Library/PrivateFrameworks/StoreFoundation.framework/StoreFoundation"
        
        dlopen(commerceKitPath, RTLD_NOW)
        dlopen(storeFoundationPath, RTLD_NOW)
        
        purchaseControllerClass = NSClassFromString("CKPurchaseController")
        downloadQueueClass = NSClassFromString("CKDownloadQueue")
        purchaseClass = NSClassFromString("SSPurchase")
        downloadMetadataClass = NSClassFromString("SSDownloadMetadata")
        storeAccountClass = NSClassFromString("ISStoreAccount")
        serviceProxyClass = NSClassFromString("ISServiceProxy")
    }
    
    var isAvailable: Bool {
        return purchaseControllerClass != nil && downloadQueueClass != nil
    }
}
