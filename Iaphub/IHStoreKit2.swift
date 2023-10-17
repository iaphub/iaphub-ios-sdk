//
//  IHStoreKit2.swift
//  Iaphub
//
//  Created by iaphub on 8/30/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation
import StoreKit

@available(iOS 15.0, *)
class IHQueueItemData {
   // Transaction
   public var transaction: Transaction
   // Product sku
   public var context: String
   
   init(transaction: Transaction, context: String) {
      self.transaction = transaction
      self.context = context
   }
}

@available(iOS 15.0, *)
class IHStoreKit2: NSObject, IHStoreKit, SKPaymentTransactionObserver {
   
   
   var version: Int = 2
   var onReceipt: ((IHReceipt, @escaping ((IHError?, Bool, IHReceiptTransaction?) -> Void)) -> Void)? = nil
   var onBuyRequest: ((String) -> Void)? = nil
   var buyRequest: (product: Product, completion: (IHError?, IHReceiptTransaction?) -> Void)? = nil
   var isObserving = false
   var isRestoring = false
   var transactionQueue: IHQueue? = nil
   var updates: Task<Void, Never>? = nil
   var lastReceipt: IHReceipt? = nil

   /**
    Start IAP
    */
   public func start(
      onReceipt: @escaping (IHReceipt, @escaping ((IHError?, Bool, IHReceiptTransaction?) -> Void)) -> Void,
      onBuyRequest: @escaping (String) -> Void
   ) {
      // Create purchased transaction queue
      self.transactionQueue = IHQueue({ (item, completion) in
         guard let data = (item.data as? IHQueueItemData) else {
            return completion()
         }
         self.processTransaction(data, item.date, completion)
      })
      // Save listeners
      self.onReceipt = onReceipt
      self.onBuyRequest = onBuyRequest
      // Add observers
      if (self.isObserving == false) {
         self.isObserving = true
         // Listen to StoreKit queue
         SKPaymentQueue.default().add(self)
         // Create updates task
         self.updates = self.createUpdatesTask()
      }
   }
   
   /**
    Stop IAP
    */
   public func stop() {
      if (self.isObserving == false) {
         return
      }
      self.isObserving = false
      SKPaymentQueue.default().remove(self)
      self.updates?.cancel()
   }
   
   /**
    Pause IAP
    */
   public func pause() {
      
   }
   
   /**
    Resume IAP
    */
   public func resume() {
      
   }
   
   /**
    Get products details
    */
   public func getProductsDetails(_ skus: Set<String>, _ completion: @escaping (IHError?, [IHProductDetails]?) -> Void) {
      // Get products
      self.getProducts(skus) { err, products in
         // Check error
         guard err == nil, let products = products else {
            return completion(err ?? IHError(IHErrors.unexpected), nil)
         }
         // Convert products to productDetails
         Task {
            let productDetails = await products
               .asyncMap { product -> IHProductDetails? in
                  do {
                     var data: Dictionary<String, Any> = [:]

                     data["sku"] = product.id
                     data["localizedTitle"] = product.displayName
                     data["localizedDescription"] = product.description
                     data["price"] = round(Double(truncating: product.price as NSNumber) * 100) / 100
                     data["currency"] = product.priceFormatStyle.currencyCode
                     data["localizedPrice"] = product.displayPrice
                     // Subscription infos
                     if let subscription = product.subscription {
                        data["subscriptionDuration"] = self.convertToISO8601(subscription.subscriptionPeriod)
                        // Subscription intro offer
                        if let introOfffer = subscription.introductoryOffer {
                           let isEligibleForIntroOffer = await subscription.isEligibleForIntroOffer
                           // Add only if eligible for intro offer
                           if (isEligibleForIntroOffer) {
                              data["subscriptionIntroPhases"] = [[
                                 "type": (introOfffer.paymentMode == Product.SubscriptionOffer.PaymentMode.freeTrial) ? "free_trial" : "intro",
                                 "price": round(Double(truncating: introOfffer.price as NSNumber) * 100) / 100,
                                 "currency": product.priceFormatStyle.currencyCode,
                                 "localizedPrice": introOfffer.displayPrice,
                                 "cycleDuration": self.convertToISO8601(introOfffer.period),
                                 "cycleCount": introOfffer.periodCount,
                                 "payment": (introOfffer.paymentMode == Product.SubscriptionOffer.PaymentMode.payUpFront) ? "upfront" : "as_you_go"
                              ]]
                           }
                        }
                     }
                     
                     return try IHProductDetails(data)
                  }
                  catch {
                     return nil
                  }
               }
               .compactMap { $0 }
            // Call completion
            completion(nil, productDetails)
         }
      }
   }
   
   /**
    Get product details
    */
   public func getProductDetails(_ sku: String, _ completion: @escaping (IHError?, IHProductDetails?) -> Void) {
      self.getProductsDetails([sku]) { err, productsDetails in
         // Search for product
         let productDetails = productsDetails?.first {item in item.sku == sku}
         if (productDetails == nil) {
            return completion(IHError(IHErrors.product_not_available, params: ["sku": sku]), nil)
         }
         // Return product
         completion(nil, productDetails)
      }
   }
   
   /**
    Buy product
    */
   public func buy(_ sku: String, _ completion: @escaping (IHError?, IHReceiptTransaction?) -> Void) {
      // Return an error if the user is not allowed to make payments
      if (self.canMakePayments() == false) {
         return completion(IHError(IHErrors.billing_unavailable), nil)
      }
      // Return an error if a buy request is currently processing
      if (self.buyRequest != nil) {
         return completion(IHError(IHErrors.buy_processing), nil)
      }
      // Get product
      self.getProduct(sku) { productErr, product in
         // Check error
         guard productErr == nil, let product = product else {
            return completion(productErr ?? IHError(IHErrors.unexpected), nil)
         }
         // Add buy request
         self.buyRequest = (product: product, completion: completion)
         // Purchase product
         self.purchase(product) { purchaseErr, result in
            // Check error
            guard purchaseErr == nil, let result = result else {
               return completion(purchaseErr ?? IHError(IHErrors.unexpected), nil)
            }
            // Parse result
            switch result {
               case .success(let verificationResult):
                  switch verificationResult {
                     case .verified(let transaction):
                        self.transactionQueue?.add(IHQueueItemData(transaction: transaction, context: "purchase"))
                        break
                     case .unverified(let transaction, _):
                        // Successful purchase but verification failed (could be a jailbroken phone)
                        self.processBuyRequest(transaction, IHError(IHErrors.unexpected, IHUnexpectedErrors.storekit_purchase_verification_failed), nil)
                        break
                  }
                  break
               case .pending:
                  self.processBuyRequest(IHError(IHErrors.deferred_payment))
                  break
               case .userCancelled:
                  self.processBuyRequest(IHError(IHErrors.user_cancelled))
                  break
               @unknown default:
                  self.processBuyRequest(IHError(IHErrors.unexpected, IHUnexpectedErrors.storekit))
                  break
            }
         }
      }
   }

   /**
    Restore transactions
    */
   public func restore(_ completion: @escaping (IHError?) -> Void) {
      // Return an error if a buy request is currently processing
      if (self.buyRequest != nil) {
         return completion(IHError(IHErrors.buy_processing))
      }
      // Return an error if a restore request is currently processing
      if (self.isRestoring) {
         return completion(IHError(IHErrors.restore_processing))
      }
      // Mark restoring as true
      self.isRestoring = true
      
      Task {
         // Pause transaction queue
         self.transactionQueue?.pause()
         // Look for unfinished transactions
         for await verificationResult in Transaction.unfinished {
            // Ignore unverified transaction
            guard case .verified(let transaction) = verificationResult else {
               return
            }
            // Add to transaction queue
            self.transactionQueue?.add(IHQueueItemData(transaction: transaction, context: "restore"))
         }
         // Look for current entitlements
         for await verificationResult in Transaction.currentEntitlements {
            // Ignore unverified transaction
            guard case .verified(let transaction) = verificationResult else {
               return
            }
            // Add to transaction queue
            self.transactionQueue?.add(IHQueueItemData(transaction: transaction, context: "restore"))
         }
         // Resume transaction queue
         self.transactionQueue?.resume({ () in
            // Mark restoring as false
            self.isRestoring = false
            // Call completion
            completion(nil)
         })
      }
   }
   
   /**
    Check if the user can make a payment
    */
   public func canMakePayments() -> Bool {
      return SKPaymentQueue.canMakePayments()
   }
   
   /**
    Present code redemption sheet
    */
   public func presentCodeRedemptionSheet(_ completion: @escaping (IHError?) -> Void) {
      SKPaymentQueue.default().presentCodeRedemptionSheet()
      completion(nil)
   }
   
   /**
    Show manage subscriptions
    */
   public func showManageSubscriptions(_ completion: @escaping (IHError?) -> Void) {
      if let currentWindowScene = IHUtil.getCurrentWindowScene() {
         // Do not wait the callback that is called when the modal is dismissed
         _ = Task.init {
            do {
               try await AppStore.showManageSubscriptions(in: currentWindowScene)
            }
            catch {
               
            }
         }
         // Call completion
         completion(nil)
      }
      // Fallback to 'StoreKit v1' subscriptions page of the App Store
      else {
         if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            // canOpenURL & open must be executed on the main thread
            DispatchQueue.main.async {
               if UIApplication.shared.canOpenURL(url) {
                  UIApplication.shared.open(url, options: [:])
                  return completion(nil)
               }
               // If it fails return an error
               completion(IHError(IHErrors.manage_subscriptions_unavailable))
            }
         }
         else {
            completion(IHError(IHErrors.manage_subscriptions_unavailable))
         }
      }
   }
   
   /***************************** PRIVATE ******************************/
   
   /**
    Create updates task
    */
   func createUpdatesTask() -> Task<Void, Never> {
      Task(priority: .background) {
         for await verificationResult in Transaction.updates {
            // Ignore unverified transactions
            guard case .verified(let transaction) = verificationResult else {
               return
            }
            // Add transaction to queue
            self.transactionQueue?.add(IHQueueItemData(transaction: transaction, context: "refresh"))
         }
      }
   }
   
   /**
    Convert SubscriptionPeriod duration to ISO8601 format
    */
   func convertToISO8601(_ subscriptionPeriod: Product.SubscriptionPeriod) -> String {
      if (subscriptionPeriod.unit == Product.SubscriptionPeriod.Unit.year) {
         return "P\(subscriptionPeriod.value)Y"
      }
      else if (subscriptionPeriod.unit == Product.SubscriptionPeriod.Unit.month) {
         return "P\(subscriptionPeriod.value)M"
      }
      else if (subscriptionPeriod.unit == Product.SubscriptionPeriod.Unit.week) {
         return "P\(subscriptionPeriod.value)W"
      }
      else if (subscriptionPeriod.unit == Product.SubscriptionPeriod.Unit.day) {
         return "P\(subscriptionPeriod.value)D"
      }
      return "";
   }
   
   /**
    Purchase product
    */
   private func purchase(_ product: Product, _ completion: @escaping (IHError?, Product.PurchaseResult?) -> Void) {
      Task {
         do {
            let result = try await product.purchase()
            completion(nil , result)
         }
         catch {
            if let pError = error as? Product.PurchaseError {
               var err = IHErrors.unexpected
               var suberr: IHErrorProtocol? = nil
               var message: String? = nil
               
               switch pError {
                  case .productUnavailable:
                     err = IHErrors.product_not_available
                     break
                  case .purchaseNotAllowed:
                     err = IHErrors.billing_unavailable
                     break
                  default:
                     err = IHErrors.unexpected
                     suberr = IHUnexpectedErrors.storekit
                     if #available(iOS 15.4, *) {
                        message = pError.errorDescription
                     }
                     else {
                        message = pError.localizedDescription
                     }
                     break
               }
               completion(IHError(err, suberr, message: message), nil)
            }
            else {
               completion(IHError(error), nil)
            }
         }
      }
   }
   
   /**
    Get  product
    */
   private func getProduct(_ sku: String, _ completion: @escaping (IHError?, Product?) -> Void) {
      self.getProducts([sku], { (err, products) in
         guard let products = products else {
            return completion(err, nil)
         }
         if (products.count == 0) {
            return completion(IHError(IHErrors.product_not_available, params: ["sku": sku]), nil)
         }
         completion(nil, products[0])
      })
   }
   
   /**
    Get  products
    */
   private func getProducts(_ skus: Set<String>, _ completion: @escaping (IHError?, [Product]?) -> Void) {
      // Check for testing
      if (Iaphub.shared.testing.billingUnavailable == true) {
         return completion(IHError(IHErrors.billing_unavailable), nil)
      }
      
      Task {
         do {
            let products = try await Product.products(for: skus)
            completion(nil , products)
         }
         catch {
            completion(IHError(error), nil)
         }
      }
   }
   
   /**
    Process  transaction
    */
   private func processTransaction(_ data: IHQueueItemData, _ date: Date, _ completion: @escaping () -> Void) {
      // Create receipt
      let receipt = IHReceipt(token: String(data.transaction.originalID), sku: data.transaction.productID, context: data.context)
      // Prevent unnecessary receipts processing
      if (data.context != "purchase" &&
         (self.lastReceipt != nil) &&
         (self.lastReceipt?.token == receipt.token) &&
         (self.lastReceipt?.processDate != nil && Date(timeIntervalSince1970: self.lastReceipt!.processDate!.timeIntervalSince1970 + 0.5) > date)
      ) {
         // Finish transaction if the last receipt finished successfully
         if (self.lastReceipt?.isFinished == true) {
            self.finishTransaction(data.transaction)
         }
         // Call completion
         return completion()
      }
      // Update last receipt
      self.lastReceipt = receipt
      // Call receipt listener
      self.onReceipt?(receipt, { (err, shouldFinish, response) in
         // Finish transaction
         if (shouldFinish) {
            self.finishTransaction(data.transaction)
         }
         // Update receipt properties
         receipt.isFinished = shouldFinish
         receipt.processDate = Date()
         // Process buy request
         self.processBuyRequest(data.transaction, err, response)
         // Call completion
         completion()
      })
   }
   
   /**
    Finish transaction
    */
   private func finishTransaction(_ transaction: Transaction) {
      Task {
         await transaction.finish()
      }
   }
   
   /**
    Process buy request
    */
   private func processBuyRequest(_ transaction: Transaction, _ err: IHError?, _ receiptTransaction: IHReceiptTransaction?) {
      // Check if the product identifier match
      if (self.buyRequest?.product.id == transaction.productID) {
         guard let buyRequest = self.buyRequest else {
            return
         }
         // Remove request
         self.buyRequest = nil
         // Get product details
         self.getProductDetails(transaction.productID) { _, details in
            if let details = details {
               receiptTransaction?.setDetails(details)
            }
            // Call request callback
            buyRequest.completion(err, receiptTransaction)
         }
      }
   }
   
   /**
    Process buy request
    */
   private func processBuyRequest(_ err: IHError?) {
      guard let buyRequest = self.buyRequest else {
         return
      }
      // Remove request
      self.buyRequest = nil
      // Call request callback
      buyRequest.completion(err, nil)
   }
   
   /***************************** SKPaymentTransactionObserver ******************************/
   
   /**
    Triggered when one or more transactions have been updated.
    */
   func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
      
   }
   
   /**
    Triggered when a user initiated an in-app purchase from the App Store.
    */
   func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {
      // Trigged onBuyRequest event if defined
      self.onBuyRequest?(payment.productIdentifier)
      // Return false to prevent purchase from starting automatically
      return false
   }
   
}
