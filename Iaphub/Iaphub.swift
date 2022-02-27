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
   var isStarted = false
   var isRestoring = false
   var deviceParams: Dictionary<String, String> = [:]
   
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
    - parameter environment: App environment ("production" by default)
    - parameter sdk:Parent sdk using the IAPHUB IOS SDK ('react_native', 'flutter', 'cordova')
    - parameter sdkVersion:Parent sdk version
    */
   @objc public class func start(
      appId: String,
      apiKey: String,
      userId: String? = nil,
      allowAnonymousPurchase: Bool = false,
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
      if (shared.user == nil || (oldAppId != appId) || (userId != nil && shared.user?.id != userId)) {
         shared.user = IHUser(id: userId, sdk: shared)
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
         return completion(IHError(IHErrors.unexpected, message: "IAPHUB not started"))
      }
      // Log in user
      user.login(userId, completion);
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
         return completion(IHError(IHErrors.unexpected, message: "IAPHUB not started"))
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
         return completion(IHError(IHErrors.unexpected, message: "IAPHUB not started"), nil)
      }
      // Check if anonymous purchases are allowed
      if (user.isAnonymous() && shared.allowAnonymousPurchase == false) {
         return completion(IHError(IHErrors.anonymous_purchase_not_allowed), nil)
      }
      // Refresh user
      shared.refreshUser({ (err, isFetched, isUpdated) in
         // Check if there is an error
         guard err == nil else {
            return completion(err, nil)
         }
         // Check cross platform conflicts
         let conflictedSubscription = user.activeProducts.first(where: {$0.type.contains("subscription") && $0.platform != "ios"})
         if (crossPlatformConflict && conflictedSubscription != nil) {
            return completion(IHError(IHErrors.cross_platform_conflict, message: "platform: \(conflictedSubscription?.platform ?? "")"), nil)
         }
         // Launch purchase
         shared.storekit.buy(sku, { (err, response) in
            // Check error
            guard err == nil else {
               return completion(err, nil)
            }
            // Return receipt transaction
            shared.getReceiptTransaction(response, completion)
         })
      })
   }
   
   /**
    Restore
    */
   @objc public class func restore(_ completion: @escaping (IHError?) -> Void) {
      // Check the sdk is started
      guard shared.isStarted == true else {
         return completion(IHError(IHErrors.unexpected, message: "IAPHUB not started"))
      }
      // Launch restore
      shared.storekit.restore(completion)
   }

   /**
    Get active products
    */
   @objc public class func getActiveProducts(includeSubscriptionStates: [String] = [], _ completion: @escaping (IHError?, [IHActiveProduct]?) -> Void) {
      // Check the sdk is started
      guard let user = shared.user else {
         return completion(IHError(IHErrors.unexpected, message: "IAPHUB not started"), nil)
      }
      // Refresh user
      shared.refreshUser({ (err, isFetched, isUpdated) in
         // Check if there is an error
         guard err == nil else {
            return completion(err, nil)
         }
         // Return active products
         completion(err, user.getActiveProducts(includeSubscriptionStates: includeSubscriptionStates))
      })
   }

   /**
    Get products for sale
    */
   @objc public class func getProductsForSale(_ completion: @escaping (IHError?, [IHProduct]?) -> Void) {
      // Check the sdk is started
      guard let user = shared.user else {
         return completion(IHError(IHErrors.unexpected, message: "IAPHUB not started"), nil)
      }
      // Refresh user with an interval of 24 hours
      shared.refreshUser(interval: 60 * 60 * 24, { (err, isFetched, isUpdated) in
         // Check if there is an error
         guard err == nil else {
            return completion(err, nil)
         }
         // Otherwise return the products
         completion(nil, user.productsForSale)
      })
   }
   
   /**
    Get products (active and for sale)
    */
   @objc public class func getProducts(includeSubscriptionStates: [String] = [], _ completion: @escaping (IHError?, [IHProduct]?, [IHActiveProduct]?) -> Void) {
      // Check the sdk is started
      guard let user = shared.user else {
         return completion(IHError(IHErrors.unexpected, message: "IAPHUB not started"), nil, nil)
      }
      // Get active products
      self.getActiveProducts(includeSubscriptionStates: includeSubscriptionStates) { err, activeProducts in
         // Check if there is an error
         if (err != nil) {
            return completion(err, nil, nil)
         }
         // Otherwise return the products
         completion(nil, user.productsForSale, user.getActiveProducts(includeSubscriptionStates: includeSubscriptionStates))
      }
   }
   
   /**
    Present code redemption
    */
   @objc public class func presentCodeRedemptionSheet(_ completion: @escaping (IHError?) -> Void) {
      // Check the sdk is started
      guard let user = shared.user else {
         return completion(IHError(IHErrors.unexpected, message: "IAPHUB not started"))
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
      if (self.user?.fetchDate != nil) {
         self.refreshUser()
      }
   }

   /**
    Refresh user
    */
   private func refreshUser(interval: Double = 0, force: Bool = false, _ completion: ((IHError?, Bool, Bool) -> Void)? = nil) {
      // Check the sdk is started
      guard let user = self.user else {
         completion?(IHError(IHErrors.unexpected, message: "IAPHUB not started"), false, false)
         return
      }
      // Refresh callback function
      func callback(err: IHError?, isFetched: Bool, isUpdated: Bool) {
         // Trigger didReceiveUserUpdate event if the user has been updated
         if (isUpdated) {
            Self.delegate?.didReceiveUserUpdate?()
         }
         // Call completion if defined
         completion?(err, isFetched, isUpdated)
      }
      // Fetch directly, cache disabled
      if (force == true) {
         user.refresh(interval: 0, force: true, callback)
      }
      // Refresh user with interval
      else if (interval > 0) {
         user.refresh(interval: interval, callback)
      }
      // Otherwise refresh with no interval
      else {
         user.refresh(callback)
      }
   }

   /**
    Get receipt transaction
    */
   private func getReceiptTransaction(_ response: Any?, _ completion: @escaping (IHError?, IHReceiptTransaction?) -> Void) {
      // Check response
      guard let response = response else {
         return completion(IHError(IHErrors.unexpected, message: "no response"), nil)
      }
      // Check the cast is a success
      guard let receiptTransaction = response as? IHReceiptTransaction else {
         return completion(IHError(IHErrors.unexpected, message: "receipt transaction found"), nil)
      }
      // Look for the product of the receipt transaction
      self.storekit.getProduct(receiptTransaction.sku, {(err, skProduct) in
         // Assign the skProduct of the transaction
         if (skProduct != nil) {
            receiptTransaction.setSKProduct(skProduct!)
         }
         // Call completion
         completion(nil, receiptTransaction)
      })
   }
   
   /**
    Start storekit
    */
   private func startStoreKit() {
      // Start storekit
      self.storekit.start(
         // Event triggered when a new receipt is available
         onReceipt: { (receipt, finish) in
            // Check the sdk is started
            guard let user = self.user else {
               return
            }
            // When receiving a receipt, post it
            user.postReceipt(receipt, { (err, receiptResponse) in
               var error = err
               var shouldFinishReceipt = false
               var transaction: IHReceiptTransaction? = nil

               func callFinish() {
                  // Finish receipt
                  finish(error, shouldFinishReceipt, transaction)
                  // Trigger didProcessReceipt event
                  Self.delegate?.didProcessReceipt?(err: error, receipt: receipt)
               }
               // Check receipt response
               if error == nil, let receiptResponse = receiptResponse {
                  // Refresh user in case the user id has been updated
                  user.refresh({ (_, _, _) in
                     // Finish receipt
                     shouldFinishReceipt = true
                     // Check if the receipt is invalid
                     if (receiptResponse.status == "invalid") {
                        error = IHError(IHErrors.receipt_invalid)
                     }
                     // Check if the receipt is failed
                     else if (receiptResponse.status == "failed") {
                        error = IHError(IHErrors.receipt_failed)
                     }
                     // Check if the receipt is stale
                     else if (receiptResponse.status == "stale") {
                        error = IHError(IHErrors.receipt_stale)
                     }
                     // Check any other status different than success
                     else if (receiptResponse.status != "success") {
                        error = IHError(IHErrors.unexpected, message: "Receipt validation failed")
                        shouldFinishReceipt = false
                     }
                     // Get transaction if we're in a purchase context
                     if (error == nil && receipt.context == "purchase") {
                        // Get the new transaction from the response
                        transaction = receiptResponse.newTransactions?.first(where: { $0.sku == receipt.sku})
                        // If transaction not found, look if it is a product change
                        if (transaction == nil) {
                           transaction = receiptResponse.newTransactions?.first(where: { $0.subscriptionRenewalProductSku == receipt.sku})
                        }
                        // Otherwise we have an error
                        if (transaction == nil) {
                           // Check if it is because of a subscription already active
                           let oldTransaction = receiptResponse.oldTransactions?.first(where: { $0.sku == receipt.sku})
                           if ((oldTransaction?.type == "non_consumable") || (oldTransaction?.subscriptionState != nil && oldTransaction?.subscriptionState != "expired")) {
                              // Check if the transaction belongs to a different user
                              if (oldTransaction?.user != nil && user.iaphubId != nil && oldTransaction?.user != user.iaphubId) {
                                 error = IHError(IHErrors.user_conflict)
                              }
                              else {
                                 error = IHError(IHErrors.product_already_purchased)
                              }
                           }
                           // Otherwise it means the product sku wasn't in the receipt
                           else {
                              error = IHError(IHErrors.transaction_not_found)
                           }
                        }
                        // If we have a transaction check that it belongs to the same user
                        else if (transaction?.user != nil && user.iaphubId != nil && transaction?.user != user.iaphubId) {
                           error = IHError(IHErrors.user_conflict)
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
            if let products = products {
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
            if let products = products {
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
            if let transaction = transaction {
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
   public class func restore() async throws {
      return try await withCheckedThrowingContinuation { continuation in
         Iaphub.restore({ (err) in
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
