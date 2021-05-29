//
//  Iaphub.swift
//  Iaphub
//
//  Created by iaphub on 8/7/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation

@objc public class Iaphub : NSObject {
   
   static let shared = Iaphub()

   var iap: IHIAP
   var user: IHUser

   var appId: String = ""
   var apiKey: String = ""
   var environment: String = "production"

   var sdk: String = "ios"
   var sdkVersion: String = "1.0.0"
   var isStarted = false

   override private init() {
      self.iap = IHIAP()
      self.user = IHUser(Iaphub.getUserId() ?? Iaphub.getAnonymousUserId())
      super.init()
   }

   /**
    Start IAPHUB
    
    - parameter appId: The app id is available on the settings page of your app
    - parameter apiKey: The (client) api key is available on the settings page of your app
    - parameter environment: App environment ("production" by default)
    - parameter onReceiptProcessed: Event triggered after IAPHUB processed a receipt
    - parameter sdk:Parent sdk using the IAPHUB IOS SDK ('react_native', 'flutter', 'cordova')
    - parameter sdkVersion:Parent sdk version
    */
   @objc public class func start(appId: String, apiKey: String, onReceiptProcessed: ((IHError?, IHReceipt?) -> Void)? = nil, environment: String = "production", sdk: String = "", sdkVersion: String = "") {
      // Setup configuration
      shared.appId = appId
      shared.apiKey = apiKey
      shared.environment = environment
      if (sdk != "") {
         shared.sdk += "/" + sdk;
      }
      if (sdkVersion != "") {
         shared.sdkVersion += "/" + sdkVersion;
      }
      // Configure user
      shared.user.configure(sdk: shared)
      // Start IAP
      shared.iap.start({ (receipt, finish) in
         // When receiving a receipt, post it
         shared.user.postReceipt(receipt, { (err, receiptResponse) in
            var error = err
            var shouldFinishReceipt = false
            var transaction: IHReceiptTransaction? = nil

            // Check receipt response
            if error == nil, let receiptResponse = receiptResponse {
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
                  error = IHError(IHErrors.unknown, message: "Receipt validation failed")
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
                     let oldTransaction = receiptResponse.oldTransactions?.first(where: { $0.sku == receipt.sku && $0.expirationDate != nil && $0.expirationDate! > Date()})
                     if (oldTransaction != nil) {
                        error = IHError(IHErrors.product_already_purchased)
                     }
                     // Otherwise it means the product sku wasn't in the receipt
                     else {
                        error = IHError(IHErrors.transaction_not_found)
                     }
                  }
               }
            }
            // Finish receipt
            finish(error, shouldFinishReceipt, transaction)
            // Call onReceiptProcessed if defined
            if let onReceiptProcessed = onReceiptProcessed {
               onReceiptProcessed(error, receipt)
            }
         })
      })
      // Mark as started
      shared.isStarted = true
   }
   
   /**
    Stop IAPHUB
    */
   @objc public class func stop() {
      shared.iap.stop();
   }

   /**
    Set user id
    */
   @objc public class func setUserId(_ userId: String) {
      // Check that the id isn't the same
      if (shared.user.id == userId) {
         return
      }
      // Do not update user id if it is an empty string
      if (userId == "") {
         return
      }
      // Otherwise update the id
      shared.user = IHUser(userId)
      shared.saveUserId(userId)
   }
   
   /**
    Set user tags
    */
   @objc public class func setUserTags(_ tags: Dictionary<String, String>, _ completion: @escaping (IHError?) -> Void) {
      // Check the sdk is started
      guard shared.isStarted == true else {
         return completion(IHError(IHErrors.unknown, message: "sdk not started"))
      }
      // Set tags
      shared.user.setTags(tags, completion)
   }
   
   /**
    Buy product
    */
   @objc public class func buy(sku: String, crossPlatformConflict: Bool = true, _ completion: @escaping (IHError?, IHReceiptTransaction?) -> Void) {
      // Check the sdk is started
      guard shared.isStarted == true else {
         return completion(IHError(IHErrors.unknown, message: "sdk not started"), nil)
      }
      // Refresh user
      shared.user.refresh({ (err, fetched) in
         // Check if there is an error
         guard err == nil else {
            return completion(err, nil)
         }
         // Check cross platform conflicts
         let conflictedSubscription = shared.user.activeProducts.first(where: {$0.type.contains("subscription") && $0.platform != "ios"})
         if (crossPlatformConflict && conflictedSubscription != nil) {
            return completion(IHError(IHErrors.cross_platform_conflict, message: "platform: \(conflictedSubscription?.platform ?? "")"), nil)
         }
         // Launch purchase
         shared.iap.buy(sku, { (err, response) in
            // Check error
            guard err == nil else {
               return completion(err, nil)
            }
            // Check response
            guard let response = response else {
               return completion(IHError(IHErrors.unknown, message: "no response"), nil)
            }
            // Cast response to receipt transaction
            let receiptTransaction = response as? IHReceiptTransaction
            // Check the cast is a success
            guard receiptTransaction != nil else {
               return completion(IHError(IHErrors.unknown, message: "no receipt found"), nil)
            }
            // Look for the product of the receipt transaction
            var product = shared.user.productsForSale.first(where: {$0.sku == receiptTransaction?.sku})
            // If not found look in the active products
            if (product == nil) {
               product = shared.user.activeProducts.first(where: {$0.sku == receiptTransaction?.sku})
            }
            // Assign the skProduct of the transaction
            if (product?.skProduct != nil) {
               receiptTransaction?.setSKProduct(product!.skProduct!)
            }
            // Call completion
            completion(nil, receiptTransaction)
         })
      })
   }
   
   /**
    Restore
    */
   @objc public class func restore(_ completion: @escaping (IHError?) -> Void) {
      // Check the sdk is started
      guard shared.isStarted == true else {
         return completion(IHError(IHErrors.unknown, message: "sdk not started"))
      }
      // Launch restore
      shared.iap.restore(completion)
   }

   /**
    Get active products
    */
   @objc public class func getActiveProducts(includeSubscriptionStates: [String] = [], _ completion: @escaping (IHError?, [IHProduct]?) -> Void) {
      // Check the sdk is started
      guard shared.isStarted == true else {
         return completion(IHError(IHErrors.unknown, message: "sdk not started"), nil)
      }
      // Refresh user
      shared.user.refresh({ (err, fetched) in
         // Check if there is an error
         guard err == nil else {
            return completion(err, nil)
         }
         // If the user has not been fetched, look if there is active subscriptions
         if (fetched == false) {
            let subscriptions = shared.user.activeProducts.filter { (product) in
               return product.type == "renewable_subscription"
            }
            // If we have active renewable subscriptions, refresh every minute
            if (subscriptions.count > 0) {
               shared.user.refresh(interval: 60, { (err, fetched) in
                  completion(err, shared.user.getActiveProducts(includeSubscriptionStates: includeSubscriptionStates))
               })
            }
            // Otherwise return the products
            else {
               completion(nil, shared.user.getActiveProducts(includeSubscriptionStates: includeSubscriptionStates))
            }
         }
         // Otherwise return the products
         else {
            completion(nil, shared.user.getActiveProducts(includeSubscriptionStates: includeSubscriptionStates))
         }
      })
   }
   
   /**
    Get products for sale
    */
   @objc public class func getProductsForSale(_ completion: @escaping (IHError?, [IHProduct]?) -> Void) {
      // Check the sdk is started
      guard shared.isStarted == true else {
         return completion(IHError(IHErrors.unknown, message: "sdk not started"), nil)
      }
      // Refresh user
      shared.user.refresh({ (err, fetched) in
         // Check if there is an error
         guard err == nil else {
            return completion(err, nil)
         }
         // Otherwise return the products
         completion(nil, shared.user.productsForSale)
      })
   }
   
   /***************************** PRIVATE ******************************/
   
   /**
    Save user id
    */
   private func saveUserId(_ userId: String) {
      let defaults = UserDefaults.standard
      let key = "iaphub_user_id"
      
      defaults.set(userId, forKey: key)
   }
   
   /**
    Get user id
    */
   static func getUserId() -> String? {
      let defaults = UserDefaults.standard
      let key = "iaphub_user_id"
      let userId = defaults.string(forKey: key)

      return userId
   }
   
   /**
    Get anonymous user id
    */
   static func getAnonymousUserId() -> String {
      let defaults = UserDefaults.standard
      let key = "iaphub_anonymous_user_id"
      
      // Check if the user id is in cache
      if let userId = defaults.string(forKey: key)
      {
         return userId
      }
      // Otherwise generate user id
      let anonymousPrefix = "a_"
      let userId = anonymousPrefix + UUID().uuidString.lowercased()
      // And save user id in cache
      defaults.set(userId, forKey: key)
      
      return userId
   }
    
}
