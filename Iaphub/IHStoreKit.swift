//
//  IHStoreKit.swift
//  Iaphub
//
//  Created by iaphub on 8/30/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation
import StoreKit

class IHStoreKit: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
   
   var products: [SKProduct] = []
   var getProductsRequests: [(request: SKProductsRequest, skus: Set<String>, completion: (IHError?, [SKProduct]?) -> Void)] = []
   var buyRequest: (payment: SKPayment, completion: (IHError?, IHReceiptTransaction?) -> Void)? = nil
   var restoreRequest: ((IHError?) -> Void)? = nil
   var onReceipt: ((IHReceipt, @escaping ((IHError?, Bool, IHReceiptTransaction?) -> Void)) -> Void)? = nil
   var onBuyRequest: ((String) -> Void)? = nil
   var purchasedTransactionQueue: IHQueue? = nil
   var failedTransactionQueue: IHQueue? = nil
   var resumeQueuesTimer: Timer? = nil
   var resumeQueuesImmediately: Bool = false
   var lastReceipt: IHReceipt? = nil
   var isObserving = false
   var isPaused = false

   /**
    Start IAP
    */
   public func start(
      onReceipt: @escaping (IHReceipt, @escaping ((IHError?, Bool, IHReceiptTransaction?) -> Void)) -> Void,
      onBuyRequest: @escaping (String) -> Void
   ) {
      // Create purchased transaction queue
      self.purchasedTransactionQueue = IHQueue({ (item, completion) in
         guard let transaction = (item.data as? SKPaymentTransaction) else {
            return completion()
         }
         self.processPurchasedTransaction(transaction, item.date, completion)
      })
      // Create failed transaction queue
      self.failedTransactionQueue = IHQueue({ (item, completion) in
         guard let transaction = (item.data as? SKPaymentTransaction) else {
            return completion()
         }
         self.processFailedTransaction(transaction, completion)
      })
      // Save listeners
      self.onReceipt = onReceipt
      self.onBuyRequest = onBuyRequest
      // Add observers
      if (self.isObserving == false) {
         self.isObserving = true
         // Listen to StoreKit queue
         SKPaymentQueue.default().add(self)
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
   }
   
   /**
    Get product
    */
   public func getProduct(_ sku: String, _ completion: @escaping (IHError?, SKProduct?) -> Void) {
      let product = self.products.first(where: {$0.productIdentifier == sku})
      
      if (product != nil) {
         return completion(nil, product)
      }
      self.getProducts([sku], { (err, products) in
         guard let products = products else {
            return completion(err, nil)
         }
         if (products.count == 0) {
            return completion(IHError(IHErrors.product_not_available), nil)
         }
         completion(nil, products[0])
      })
   }
   
   /**
    Get products
    */
   public func getProducts(_ skus: Set<String>, _ completion: @escaping (IHError?, [SKProduct]?) -> Void) {
      let request = SKProductsRequest(productIdentifiers: skus)

      self.getProductsRequests.append((request: request, skus: skus, completion: completion))
      request.delegate = self
      request.start()
   }
   
   /**
    Buy product
    */
   public func buy(_ product: SKProduct, _ completion: @escaping (IHError?, IHReceiptTransaction?) -> Void) {
      // Return an error if the user is not allowed to make payments
      if (self.canMakePayments() == false) {
         return completion(IHError(IHErrors.billing_unavailable), nil)
      }
      // Return an error if a buy request is currently processing
      if (self.buyRequest != nil) {
         return completion(IHError(IHErrors.buy_processing), nil)
      }
      // Otherwise process the purchase
      let payment = SKPayment(product: product)
      // Add buy request
      self.buyRequest = (payment: payment, completion: completion)
      // Add payment to queue
      SKPaymentQueue.default().add(payment)
   }

   /**
    Restore completed transactions
    */
   public func restore(_ completion: @escaping (IHError?) -> Void) {
      if (self.restoreRequest != nil) {
         return completion(IHError(IHErrors.restore_processing))
      }
      self.restoreRequest = completion;
      SKPaymentQueue.default().restoreCompletedTransactions()
   }
   
   /**
    Check if the user can make a payment
    */
   public func canMakePayments() -> Bool {
      return SKPaymentQueue.canMakePayments()
   }

   /**
    Pause
    */
   public func pause() {
      if (self.isPaused == true) {
         return
      }
      // Update app state
      self.isPaused = true
      // Pause queues
      self.pauseQueues()
   }
   
   /**
    Resume
    */
   public func resume() {
      if (self.isPaused == false) {
         return
      }
      // Update app state
      self.isPaused = false
      // Resume queues immediately if defined
      if (self.resumeQueuesImmediately) {
         self.resumeQueues()
         self.resumeQueuesImmediately = false
      }
      // Otherwise resume queues automatically in 10 seconds
      else {
         // Invalidate resume queues timer
         self.resumeQueuesTimer?.invalidate()
         // Fore queues resume after 30 seconds
         self.resumeQueuesTimer = Timer.scheduledTimer(timeInterval: 30, target: self, selector: #selector(self.resumeQueues), userInfo: nil, repeats: false)
      }
   }
   
   /**
    Stop IAP
    */
   public func presentCodeRedemptionSheet(_ completion: @escaping (IHError?) -> Void) {
      if #available(iOS 14.0, *) {
         SKPaymentQueue.default().presentCodeRedemptionSheet()
         completion(nil)
      } else {
         return completion(IHError(IHErrors.code_redemption_unavailable))
      }
   }
   
   /***************************** PRIVATE ******************************/
   
   /**
    Resume queues
    */
   @objc private func resumeQueues() {
      // Invalidate resume queues timer
      self.resumeQueuesTimer?.invalidate()
      // Resume purchased transaction queue first
      self.purchasedTransactionQueue?.resume({ () in
         // And then failed transaction queue
         self.failedTransactionQueue?.resume()
      })
   }
   
   /**
    Process queues or mark as ready for process when the app is in foreground
    */
   private func resumeQueuesASAP() {
      if (self.isPaused == true) {
         self.resumeQueuesImmediately = true
      }
      else {
         self.resumeQueues()
      }
   }
   
   /**
    Pause queues
    */
   private func pauseQueues() {
      // Pause queues
      self.purchasedTransactionQueue?.pause()
      self.failedTransactionQueue?.pause()
      // Invalidate resume queues timer
      self.resumeQueuesTimer?.invalidate()
   }
   
   /**
    Finish transaction
    */
   private func finishTransaction(_ transaction: SKPaymentTransaction) {
      SKPaymentQueue.default().finishTransaction(transaction)
   }
   
   /**
    Get receipt token
    */
   private func getReceiptToken() -> String? {
      // Get receipt url
      guard let receiptURL = Bundle.main.appStoreReceiptURL else {
         return nil
      }
      // Check receipt url
      guard FileManager.default.fileExists(atPath: receiptURL.path) else {
         return nil
      }
      // Get receipt data
      var data: Data?
      do {
         data = try Data(contentsOf: receiptURL, options: .alwaysMapped)
      } catch {
         data = nil
      }
      // Get token from data
      guard let token = data?.base64EncodedString(options: []) else {
         return nil
      }
     
     return token
   }
   
   /**
    Process buy request
    */
   private func processBuyRequest(_ transaction: SKPaymentTransaction, _ err: IHError?, _ response: IHReceiptTransaction?) {
      // Check if the product identifier match
      if (self.buyRequest?.payment.productIdentifier == transaction.payment.productIdentifier) {
         guard let buyRequest = self.buyRequest else {
            return
         }
         // Remove request
         self.buyRequest = nil
         // Call request callback back to the main thread
         DispatchQueue.main.async {
            buyRequest.completion(err, response)
         }
      }
   }
   
   /**
    Process purchased transaction
    */
   private func processPurchasedTransaction(_ transaction: SKPaymentTransaction, _ date: Date, _ completion: @escaping () -> Void) {
      // Detect receipt context
      var context = "refresh"
      if (self.buyRequest?.payment.productIdentifier == transaction.payment.productIdentifier) {
         context = "purchase"
      }
      // Get receipt token
      let receiptToken = self.getReceiptToken()
      // Check receipt token is not nil
      guard let token = receiptToken else {
         self.processBuyRequest(transaction, IHError(IHErrors.unexpected, IHUnexpectedErrors.get_receipt_token_failed, message: "from purchased transaction"), nil)
         return completion()
      }
      // Create receipt
      let receipt = IHReceipt(token: token, sku: transaction.payment.productIdentifier, context: context)
      // Prevent unnecessary receipts processing
      if (context == "refresh" &&
         (self.lastReceipt != nil) &&
         (self.lastReceipt?.token == receipt.token) &&
         (self.lastReceipt?.processDate != nil && Date(timeIntervalSince1970: self.lastReceipt!.processDate!.timeIntervalSince1970 + 0.5) > date)
      ) {
         // Finish transaction if the last receipt finished successfully
         if (self.lastReceipt?.isFinished == true) {
            self.finishTransaction(transaction)
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
            self.finishTransaction(transaction)
         }
         // Update receipt properties
         receipt.isFinished = shouldFinish
         receipt.processDate = Date()
         // Process buy request
         self.processBuyRequest(transaction, err, response)
         // Call completion
         completion()
      })
   }

   
   /**
    Process failed transaction
    */
   private func processFailedTransaction(_ transaction: SKPaymentTransaction, _ completion: @escaping () -> Void) {
      var err: IHError? = nil

      // Check if it is a deferred transaction error
      if (transaction.transactionState == SKPaymentTransactionState.deferred) {
         err = IHError(IHErrors.deferred_payment)
      }
      // Otherwise check SKError
      else {
         err = IHError(transaction.error);
      }
      // Process buy request
      self.processBuyRequest(transaction, err, nil)
      // Call completion
      completion()
   }
   
   /**
    Add purchased transaction to queue
    */
   private func addPurchasedTransactionToQueue(_ transaction: SKPaymentTransaction) {
      // Add purchased transaction to queue
      self.purchasedTransactionQueue?.add(transaction)
      // Resume queues ASAP
      self.resumeQueuesASAP()
   }
   
   /**
    Add failed transaction to queue
    */
   private func addFailedTransactionToQueue(_ transaction: SKPaymentTransaction) {
      // We can directly finish the transaction (except for a deferred transaction, not needed)
      if (transaction.transactionState != SKPaymentTransactionState.deferred) {
         self.finishTransaction(transaction)
      }
      // Add failed transaction to queue
      self.failedTransactionQueue?.add(transaction)
      // Resume queues queues ASAP if it isn't an unknown error (error trigerred during an interrupted purchase) or a deferred purchase
      if let skError = transaction.error as? SKError {
         if (skError.code != SKError.unknown) {
            self.resumeQueuesASAP()
         }
      }
      else if (transaction.transactionState != SKPaymentTransactionState.deferred) {
         self.resumeQueuesASAP()
      }
   }
   
   /***************************** SKProductsRequestDelegate ******************************/
   
   /**
    Triggered when a request fails
    */
   func request(_ request: SKRequest, didFailWithError error: Error) {
      // Look for request
      guard let item = self.getProductsRequests.first(where: {$0.request == request}) else {
         return;
      }
      // Remove request
      self.getProductsRequests.removeAll(where: { $0.request ==  item.request})
      // Try to get the products from the cache
      let cachedProducts = self.products.filter { (product) in item.skus.contains(product.productIdentifier) == true }
      // Return cached products instead of error if we found all the skus in cache
      if (cachedProducts.count == item.skus.count) {
         DispatchQueue.main.async {
            item.completion(nil, cachedProducts)
         }
      }
      // Otherwise return error
      else {
         DispatchQueue.main.async {
            if let skError = error as? SKError {
               item.completion(IHError(skError), nil)
            }
            else {
               item.completion(IHError(error), nil)
            }
         }
      }
   }
   
   /**
    Triggered when the response of a SKProductsRequest is available
    */
   func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
      // Iterate through products
      for product in response.products {
         // Remove product from list if already saved
         self.products.removeAll(where: {$0.productIdentifier == product.productIdentifier})
         // Add new product
         self.products.append(product)
      }
      // Look for request
      let item = self.getProductsRequests.first(where: {$0.request == request})
      // Remove request
      self.getProductsRequests.removeAll(where: { $0.request ==  item?.request})
      // Call request callback back to the main thread
      if (item != nil) {
         DispatchQueue.main.async {
            item?.completion(nil, response.products)
         }
      }
   }
   
   /***************************** SKPaymentTransactionObserver ******************************/
   
   /**
    Triggered when one or more transactions have been updated.
    */
   func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
      transactions.forEach({ (transaction) in
         switch transaction.transactionState {
            case .purchasing:
               // Transaction started, no need to do anything here
               break
            case .purchased:
               self.addPurchasedTransactionToQueue(transaction)
               break
            case .failed:
               // Add failed transaction to queue
               self.addFailedTransactionToQueue(transaction)
               break
            case .deferred:
               // Add failed transaction to queue, the transaction has been deferred (awaiting approval from parental control)
               self.addFailedTransactionToQueue(transaction)
               break
            case .restored:
               // The transaction has already been purchased and is restored
               self.finishTransaction(transaction)
               break
            @unknown default:
               break
         }
      })
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
   
   /**
    Triggered when the restore failed
    */
   func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
      guard let restoreRequest = self.restoreRequest else {
         return;
      }
      self.restoreRequest = nil
      // Call request callback back to the main thread
      DispatchQueue.main.async {
         if let skError = error as? SKError {
            restoreRequest(IHError(skError));
         }
         else {
            restoreRequest(IHError(error));
         }
      }
   }
   
   /**
    Triggered when the restore is completed
    */
   func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
      guard let restoreRequest = self.restoreRequest else {
         return;
      }
      self.restoreRequest = nil
      // Get receipt token
      let receiptToken = self.getReceiptToken()
      // Check receipt token is not nil
      guard let token = receiptToken else {
         return restoreRequest(IHError(IHErrors.unexpected, IHUnexpectedErrors.get_receipt_token_failed, message: "from restored transaction"))
      }
      // Create receipt object
      let receipt = IHReceipt(token: token, sku: "", context: "restore")
      // Call receipt listener
      self.onReceipt?(receipt, { (err, shouldFinish, response) in
         // Call request callback back to the main thread
         DispatchQueue.main.async {
            restoreRequest(err);
         }
      })
   }
   
}
