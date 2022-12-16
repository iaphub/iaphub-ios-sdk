//
//  Iaphub.swift
//  Iaphub
//
//  Created by iaphub on 8/7/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation
import UIKit

@objc public protocol IaphubDelegate: AnyObject {
    
   @objc optional func didReceiveBuyRequest(sku: String)
   @objc optional func didReceiveDeferredPurchase(transaction: IHReceiptTransaction)
   @objc optional func didReceiveUserUpdate()
   @objc optional func didProcessReceipt(err: IHError?, receipt: IHReceipt?)
   @objc optional func didReceiveError(err: IHError)
}

@objc public class Iaphub : NSObject {
   
   static let shared = Iaphub()

   var storekit: IHStoreKit
   var user: IHUser? = nil

   var appId: String = ""
   var apiKey: String = ""
   var environment: String = "production"
   var allowAnonymousPurchase: Bool = false

   var sdk: String = IHConfig.sdk
   var sdkVersion: String = IHConfig.sdkVersion
   var osVersion: String = UIDevice.current.systemVersion
   var isStarted = false
   var isRestoring = false
   var deviceParams: Dictionary<String, String> = [:]
   var logs = true
   
   @objc public static weak var delegate: IaphubDelegate?

   override private init() {
      self.storekit = IHStoreKit()
      super.init()
   }

   /**
    Start IAPHUB
    
    - parameter appId: The app id is available on the settings page of your app
    - parameter apiKey: The (client) api key is available on the settings page of your app
    - parameter userId: The id of the user
    - parameter allowAnonymousPurchase: If purchase without being logged in are allowed
    - parameter enableDeferredPurchaseListener: If enabled the didReceiveDeferredPurchase event will be triggered (true by default)
    - parameter environment: App environment ("production" by default)
    - parameter sdk:Parent sdk using the IAPHUB IOS SDK ('react_native', 'flutter', 'cordova')
    - parameter sdkVersion:Parent sdk version
    */
   @objc public class func start(
      appId: String,
      apiKey: String,
      userId: String? = nil,
      allowAnonymousPurchase: Bool = false,
      enableDeferredPurchaseListener: Bool = true,
      environment: String = "production",
      sdk: String = "",
      sdkVersion: String = "")
   {
      let oldAppId = shared.appId
      // Setup configuration
      shared.appId = appId
      shared.apiKey = apiKey
      shared.allowAnonymousPurchase = allowAnonymousPurchase
      shared.environment = environment
      if (sdk != "") {
         shared.sdk = IHConfig.sdk + "/" + sdk;
      }
      if (sdkVersion != "") {
         shared.sdkVersion = IHConfig.sdkVersion + "/" + sdkVersion;
      }
      // Initialize user
      if (shared.user == nil || (oldAppId != appId) || (shared.user?.id != userId) || (shared.user?.enableDeferredPurchaseListener != enableDeferredPurchaseListener)) {
         shared.user = IHUser(
            id: userId,
            sdk: shared,
            enableDeferredPurchaseListener: enableDeferredPurchaseListener,
            onUserUpdate: shared.onUserUpdate,
            onDeferredPurchase: shared.onDeferredPurchase
         )
      }
      // Otherwise reset user cache
      else {
         shared.user?.resetCache()
      }
      // If it isn't been started yet
      if (shared.isStarted == false) {
         // Start storekit
         shared.startStoreKit()
         // Register observers to detect app going to background/foreground
         NotificationCenter.default.addObserver(shared, selector: #selector(shared.onAppBackground), name: UIApplication.willResignActiveNotification, object: nil)
         NotificationCenter.default.addObserver(shared, selector: #selector(shared.onAppForeground), name: UIApplication.didBecomeActiveNotification, object: nil)
      }
      // Mark as started
      shared.isStarted = true
   }
   
   /**
    Stop IAPHUB
    */
   @objc public class func stop() {
      // Only if not already stopped
      if (shared.isStarted == true) {
         // Stop storekit
         shared.storekit.stop();
         // Remove observers
         NotificationCenter.default.removeObserver(shared, name: UIApplication.willResignActiveNotification, object: nil)
         NotificationCenter.default.removeObserver(shared, name: UIApplication.didBecomeActiveNotification, object: nil)
         // Mark as unstarted
         shared.isStarted = false
      }
   }

   /**
    Log in
    */
   @objc public class func login(userId: String, _ completion: @escaping (IHError?) -> Void) {
      guard let user = shared.user else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.start_missing, message: "login failed"))
      }
      // Log in user
      user.login(userId, completion);
   }
   
   /**
    Get user id
    */
   @objc public class func getUserId() -> String? {
      return shared.user?.id
   }

   /**
    Log out
    */
   @objc public class func logout() {
      guard let user = shared.user else {
         return
      }
      // Log out user
      user.logout()
   }
   
   /**
    Set device params
    */
   @objc public class func setDeviceParams(params: Dictionary<String, String>) {
      if (NSDictionary(dictionary: shared.deviceParams).isEqual(to: params) == false) {
         shared.deviceParams = params
         if let user = shared.user {
            user.resetCache()
         }
      }
   }
   
   /**
    Set user tags
    */
   @objc public class func setUserTags(tags: Dictionary<String, String>, _ completion: @escaping (IHError?) -> Void) {
      // Check the sdk is started
      guard let user = shared.user else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.start_missing, message: "setUserTags failed"))
      }
      // Set tags
      user.setTags(tags, completion)
   }
   
   /**
    Buy product
    */
   @objc public class func buy(sku: String, crossPlatformConflict: Bool = true, _ completion: @escaping (IHError?, IHReceiptTransaction?) -> Void) {
      // Check the sdk is started
      guard let user = shared.user else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.start_missing, message: "buy failed"), nil)
      }
      // Check if anonymous purchases are allowed
      if (user.isAnonymous() && shared.allowAnonymousPurchase == false) {
         return completion(IHError(IHErrors.anonymous_purchase_not_allowed), nil)
      }
      // Buy product
      user.buy(sku: sku, crossPlatformConflict: crossPlatformConflict, completion)
   }
   
   /**
    Restore
    */
   @objc public class func restore(_ completion: @escaping (IHError?, IHRestoreResponse?) -> Void) {
      // Check the sdk is started
      guard let user = shared.user else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.start_missing, message: "restore failed"), nil)
      }
      // Check if restore currently processing
      if (shared.isRestoring) {
         return completion(IHError(IHErrors.restore_processing), nil)
      }
      // Launch restore
      shared.isRestoring = true
      user.restore({ (err, response) in
         shared.isRestoring = false
         completion(err, response)
      })
   }

   /**
    Get active products
    */
   @objc public class func getActiveProducts(includeSubscriptionStates: [String] = [], _ completion: @escaping (IHError?, [IHActiveProduct]?) -> Void) {
      // Check the sdk is started
      guard let user = shared.user else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.start_missing, message: "getActiveProducts failed"), nil)
      }
      // Return active products
      user.getActiveProducts(includeSubscriptionStates: includeSubscriptionStates, completion)
   }

   /**
    Get products for sale
    */
   @objc public class func getProductsForSale(_ completion: @escaping (IHError?, [IHProduct]?) -> Void) {
      // Check the sdk is started
      guard let user = shared.user else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.start_missing, message: "getProductsForSale failed"), nil)
      }
      // Return products for sale
      user.getProductsForSale(completion)
   }
   
   /**
    Get products (active and for sale)
    */
   @objc public class func getProducts(includeSubscriptionStates: [String] = [], _ completion: @escaping (IHError?, IHProducts?) -> Void) {
      // Check the sdk is started
      guard let user = shared.user else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.start_missing, message: "getProducts failed"), nil)
      }
      // Return products
      user.getProducts(includeSubscriptionStates: includeSubscriptionStates, completion)
   }
   
   /**
    Show manage subscriptions
    */
   @objc public class func showManageSubscriptions(_ completion: @escaping (IHError?) -> Void) {
      // Call StoreKit method
      shared.storekit.showManageSubscriptions(completion)
   }

   /**
    Present code redemption
    */
   @objc public class func presentCodeRedemptionSheet(_ completion: @escaping (IHError?) -> Void) {
      // Check the sdk is started
      guard let user = shared.user else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.start_missing, message: "presentCodeRedemptionSheet failed"))
      }
      // Check if anonymous purchases are allowed
      if (user.isAnonymous() && shared.allowAnonymousPurchase == false) {
         return completion(IHError(IHErrors.anonymous_purchase_not_allowed))
      }
      // Present code redemption
      shared.storekit.presentCodeRedemptionSheet(completion)
   }
   
   /***************************** PRIVATE ******************************/
   
   /**
    Triggered when a user update is detected
   */
   private func onUserUpdate() {
      Self.delegate?.didReceiveUserUpdate?()
   }
   
   /**
    Triggered when a deferred purchase is detected
   */
   private func onDeferredPurchase(transaction: IHReceiptTransaction) {
      Self.delegate?.didReceiveDeferredPurchase?(transaction: transaction)
   }
   
   /**
   Triggerred when the app is going to the background
    */
   @objc private func onAppBackground() {
      // Pause storekit
      self.storekit.pause();
   }
   
   /**
   Triggerred when the app is going to the foreground
    */
   @objc private func onAppForeground() {
      // Resume storekit
      self.storekit.resume();
      // Refresh user (only if it has already been fetched)
      if let user = self.user, user.fetchDate != nil {
         user.refresh()
      }
   }
   
   /**
    Start storekit
    */
   private func startStoreKit() {
      // Start storekit
      self.storekit.start(
         // Event triggered when a new receipt is available
         onReceipt: { (receipt, finish) in
            var error: IHError? = nil
            var shouldFinishReceipt = false
            var transaction: IHReceiptTransaction? = nil
            // Method to finish the processing
            func callFinish() {
               // Finish receipt
               finish(error, shouldFinishReceipt, transaction)
               // Trigger didProcessReceipt event
               Self.delegate?.didProcessReceipt?(err: error, receipt: receipt)
            }
            // Check the sdk is started
            guard let user = self.user else {
               error = IHError(IHErrors.unexpected, IHUnexpectedErrors.start_missing, message: "onReceipt failed")
               callFinish()
               return
            }
            // When receiving a receipt, post it
            user.postReceipt(receipt, { (err, receiptResponse) in
               // Update error
               error = err
               // Check receipt response
               if error == nil, let receiptResponse = receiptResponse {
                  // Refresh user in case the user id has been updated or any events has been posted
                  user.refresh({ (_, _, _) in
                     // Finish receipt if it is a success
                     if (receiptResponse.status == "success") {
                        shouldFinishReceipt = true
                     }
                     // Check if the receipt is invalid
                     else if (receiptResponse.status == "invalid") {
                        error = IHError(IHErrors.receipt_invalid, params: ["context": receipt.context], silent: receipt.context != "purchase")
                     }
                     // Check if the receipt is failed
                     else if (receiptResponse.status == "failed") {
                        error = IHError(IHErrors.receipt_failed, params: ["context": receipt.context])
                     }
                     // Check if the receipt is stale
                     else if (receiptResponse.status == "stale") {
                        error = IHError(IHErrors.receipt_stale, params: ["context": receipt.context], silent: receipt.context != "purchase")
                     }
                     // Check if the receipt is deferred (not needed on iOS but still implemented it in case)
                     else if (receiptResponse.status == "deferred") {
                        error = IHError(IHErrors.deferred_payment, params: ["context": receipt.context], silent: true)
                     }
                     // Check if the receipt is processing
                     else if (receiptResponse.status == "processing") {
                        error = IHError(IHErrors.receipt_processing, params: ["context": receipt.context], silent: receipt.context != "purchase")
                     }
                     // Check any other status
                     else {
                        error = IHError(IHErrors.unexpected, IHUnexpectedErrors.receipt_validation_response_invalid, message: "status: \(receiptResponse.status ?? "nil")", params: ["context": receipt.context])
                     }
                     // If there is no error, try to find the transaction
                     if (error == nil) {
                        // Look first in the new transactions
                        transaction = receiptResponse.findTransactionBySku(sku: receipt.sku, filter: "new")
                        // If the transaction hasn't been found
                        if (transaction == nil) {
                           // If it is purchase, look for a product change
                           if (receipt.context == "purchase") {
                              transaction = receiptResponse.findTransactionBySku(sku: receipt.sku, filter: "new", useSubscriptionRenewalProductSku: true)
                           }
                           // Otherwise look in the old transactions
                           else {
                              transaction = receiptResponse.findTransactionBySku(sku: receipt.sku, filter: "old")
                           }
                        }
                        // If it is a purchase, check for errors
                        if (receipt.context == "purchase") {
                           // If we didn't find any transaction, we have an error
                           if (transaction == nil) {
                              // Check if it is because of a subscription already active
                              let oldTransaction = receiptResponse.findTransactionBySku(sku: receipt.sku, filter: "old")
                              if ((oldTransaction?.type == "non_consumable") || (oldTransaction?.subscriptionState != nil && oldTransaction?.subscriptionState != "expired")) {
                                 // Check if the transaction belongs to a different user
                                 if (oldTransaction?.user != nil && user.iaphubId != nil && oldTransaction?.user != user.iaphubId) {
                                    error = IHError(IHErrors.user_conflict, params: ["loggedUser": user.iaphubId as Any, "transactionUser": oldTransaction?.user as Any])
                                 }
                                 else {
                                    error = IHError(IHErrors.product_already_purchased, params: ["sku": receipt.sku])
                                 }
                              }
                              // Check for other errors
                              else {
                                 // Check it could be because the subscription is already changing on next renewal date
                                 let oldTransactionWithRenewalSku = receiptResponse.findTransactionBySku(sku: receipt.sku, filter: "old", useSubscriptionRenewalProductSku: true)
                                 if (oldTransactionWithRenewalSku != nil) {
                                    error = IHError(IHErrors.product_change_next_renewal, params: ["sku": receipt.sku])
                                 }
                                 // Otherwise it means the product sku wasn't in the receipt
                                 else {
                                    error = IHError(IHErrors.transaction_not_found, params: ["sku": receipt.sku])
                                 }
                              }
                           }
                           // If we have a transaction check that it belongs to the same user
                           else if (transaction?.user != nil && user.iaphubId != nil && transaction?.user != user.iaphubId) {
                              error = IHError(IHErrors.user_conflict, params: ["loggedUser": user.iaphubId as Any, "transactionUser": transaction?.user as Any])
                           }
                        }
                     }
                     // Call finish
                     callFinish()
                  })
               }
               // Call finish if the receipt failed
               else {
                  callFinish()
               }
            })
         },
         // Event triggered when the purchase of a product is requested
         onBuyRequest: { (sku) in
            // Call didReceiveBuyRequest event if defined
            if (Self.delegate?.didReceiveBuyRequest != nil) {
               Self.delegate?.didReceiveBuyRequest?(sku: sku)
            }
            // Otherwise call buy method directly
            else {
               Self.buy(sku: sku, { (err, transaction) in
                  // Nothing to do here
               })
            }
         }
      )
   }

}

@available(iOS 15.0.0, *)
extension Iaphub {
   
   /**
    Async/await login
    */
   public class func login(userId: String) async throws {
      return try await withCheckedThrowingContinuation { continuation in
         Iaphub.login(userId: userId, { (err) in
            if (err != nil) {
               continuation.resume(throwing: err! as Error)
            }
            else {
               continuation.resume()
            }
         })
      }
   }
   
   /**
    Async/await set user tags
    */
   public class func setUserTags(tags: Dictionary<String, String>) async throws {
      return try await withCheckedThrowingContinuation { continuation in
         Iaphub.setUserTags(tags: tags, { (err) in
            if (err != nil) {
               continuation.resume(throwing: err! as Error)
            }
            else {
               continuation.resume()
            }
         })
      }
   }
   
   /**
    Async/await get products for sale
    */
   public class func getProductsForSale() async throws -> [IHProduct] {
      return try await withCheckedThrowingContinuation { continuation in
         Iaphub.getProductsForSale({ (err, products) in
            if let products = products, err == nil {
               continuation.resume(returning: products)
            }
            else {
               continuation.resume(throwing: err! as Error)
            }
         })
      }
   }
   
   /**
    Async/await get active products
    */
   public class func getActiveProducts(includeSubscriptionStates: [String] = []) async throws -> [IHActiveProduct] {
      return try await withCheckedThrowingContinuation { continuation in
         Iaphub.getActiveProducts(includeSubscriptionStates: includeSubscriptionStates, { (err, products) in
            if let products = products, err == nil {
               continuation.resume(returning: products)
            }
            else {
               continuation.resume(throwing: err! as Error)
            }
         })
      }
   }
   
   /**
    Async/await get products
    */
   public class func getProducts(includeSubscriptionStates: [String] = []) async throws -> IHProducts {
      return try await withCheckedThrowingContinuation { continuation in
         Iaphub.getProducts(includeSubscriptionStates: includeSubscriptionStates, { (err, products) in
            if let products = products, err == nil {
               continuation.resume(returning: products)
            }
            else {
               continuation.resume(throwing: err! as Error)
            }
         })
      }
   }
   
   /**
    Async/await get products for sale
    */
   public class func buy(sku: String, crossPlatformConflict: Bool = true) async throws -> IHReceiptTransaction {
      return try await withCheckedThrowingContinuation { continuation in
         Iaphub.buy(sku: sku, crossPlatformConflict: crossPlatformConflict, { (err, transaction) in
            if let transaction = transaction, err == nil {
               continuation.resume(returning: transaction)
            }
            else {
               continuation.resume(throwing: err! as Error)
            }
         })
      }
   }
   
   /**
    Async/await restore
    */
   public class func restore() async throws -> IHRestoreResponse {
      return try await withCheckedThrowingContinuation { continuation in
         Iaphub.restore({ (err, response) in
            if let response = response, err == nil {
               continuation.resume(returning: response)
            }
            else {
               continuation.resume(throwing: err! as Error)
            }
         })
      }
   }
   
   /**
    Async/await showManageSubscriptions
    */
   public class func showManageSubscriptions() async throws {
      return try await withCheckedThrowingContinuation { continuation in
         Iaphub.showManageSubscriptions({ (err) in
            if (err != nil) {
               continuation.resume(throwing: err! as Error)
            }
            else {
               continuation.resume()
            }
         })
      }
   }
   
}
