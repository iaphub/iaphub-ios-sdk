//
//  IHIAP.swift
//  Iaphub
//
//  Created by iaphub on 8/30/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation
import StoreKit

class IHIAP: NSObject, SKProductsRequestDelegate, SKPaymentTransactionObserver {
   
   var products: [SKProduct] = []
   var getProductsRequests: [(request: SKProductsRequest, completion: (IHError?, [SKProduct]?) -> Void)] = []
   var buyRequests: [(payment: SKPayment, completion: (IHError?, Any?) -> Void)] = []
   var restoreRequest: ((IHError?) -> Void)? = nil
   var receiptListener: ((IHReceipt, @escaping ((IHError?, Bool, Any?) -> Void)) -> Void)? = nil
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
   public func start(_ receiptListener: @escaping (IHReceipt, @escaping ((IHError?, Bool, Any?) -> Void)) -> Void) {
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
      // Save receipt listener
      self.receiptListener = receiptListener
      // Add observers
      if (self.isObserving == false) {
         self.isObserving = true
         // Listen to StoreKit queue
         SKPaymentQueue.default().add(self)
         // Pause IAP when the app goes to background
         NotificationCenter.default.addObserver(self, selector: #selector(self.pause), name: UIApplication.willResignActiveNotification, object: nil)
         // Resume IAP when the app does to foreground
         NotificationCenter.default.addObserver(self, selector: #selector(self.resume), name: UIApplication.didBecomeActiveNotification, object: nil)
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
      NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
      NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
   }
   
   /**
    Buy product
    */
   public func buy(_ sku: String, _ completion: @escaping (IHError?, Any?) -> Void) {
      let product = self.products.first(where: {$0.productIdentifier == sku})
      
      // Return an error if the product doesn't exist
      if (product == nil) {
         return completion(IHError(IHErrors.product_not_available), nil)
      }
      // Return an error if the user is not allowed to make payments
      if (self.canMakePayments() == false) {
         return completion(IHError(IHErrors.billing_unavailable), nil)
      }
      // Otherwise process the purchase
      let payment = SKPayment(product: product!)
      // Add buy request
      self.buyRequests.append((payment: payment, completion: completion))
      // Add payment to queue
      SKPaymentQueue.default().add(payment)
   }

   /**
    Restore completed transactions
    */
   public func restore(_ completion: @escaping (IHError?) -> Void) {
      self.restoreRequest = completion;
      SKPaymentQueue.default().restoreCompletedTransactions()
   }
   
   /**
    Get products
    */
   public func getProducts(_ skus: Set<String>, _ completion: @escaping (IHError?, [SKProduct]?) -> Void) {
      let request = SKProductsRequest(productIdentifiers: skus)

      self.getProductsRequests.append((request: request, completion: completion))
      request.delegate = self
      request.start()
   }
   
   /**
    Check if the user can make a payment
    */
   public func canMakePayments() -> Bool {
      return SKPaymentQueue.canMakePayments()
   }
   
   /***************************** PRIVATE ******************************/
   
   /**
    Pause
    */
   @objc private func pause() {
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
   @objc private func resume() {
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
   private func processBuyRequest(_ transaction: SKPaymentTransaction, _ err: IHError?, _ response: Any?) {
      // Find buy request
      let buyRequest = self.buyRequests.first(where: { $0.payment.productIdentifier == transaction.payment.productIdentifier })
      // Remove request
      self.buyRequests.removeAll(where: { $0.payment ==  buyRequest?.payment})
      // Call request callback back to the main thread
      DispatchQueue.main.async {
         buyRequest?.completion(err, response)
      }
   }
   
   /**
    Process purchased transaction
    */
   private func processPurchasedTransaction(_ transaction: SKPaymentTransaction, _ date: Date, _ completion: @escaping () -> Void) {
      // Get receipt token
      let receiptToken = self.getReceiptToken()
      // Check receipt token is not nil
      guard let token = receiptToken else {
         return
      }
      // Detect receipt context
      var context = "refresh"
      let buyRequest = self.buyRequests.first(where: { $0.payment.productIdentifier == transaction.payment.productIdentifier })
      if (buyRequest != nil) {
         context = "purchase"
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
      self.receiptListener?(receipt, { (err, shouldFinish, response) in
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
      var err = IHError(IHErrors.unknown)
      // Check if it is a deferred transaction error
      if (transaction.transactionState == SKPaymentTransactionState.deferred) {
         err = IHError(IHErrors.deferred_payment)
      }
      // Otherwise check SKError
      else {
         if let skError = transaction.error as? SKError {
            err = IHError(skError);
         }
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
      let item = self.getProductsRequests.first(where: {$0.request == request})
      // Remove request
      self.getProductsRequests.removeAll(where: { $0.request ==  item?.request})
      // Call request callback back to the main thread
      if (item != nil) {
         DispatchQueue.main.async {
            item?.completion(IHError(error), nil)
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
    Triggered when the restore failed
    */
   func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
      guard let restoreRequest = self.restoreRequest else {
         return;
      }
      // Call request callback back to the main thread
      DispatchQueue.main.async {
         restoreRequest(IHError(error));
      }
   }
   
   /**
    Triggered when the restore is completed
    */
   func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
      guard let restoreRequest = self.restoreRequest else {
         return;
      }
      // Get receipt token
      let receiptToken = self.getReceiptToken()
      // Check receipt token is not nil
      guard let token = receiptToken else {
         return restoreRequest(IHError(IHErrors.unknown, message: "receipt not found"))
      }
      // Create receipt object
      let receipt = IHReceipt(token: token, sku: "", context: "restore")
      // Call receipt listener
      self.receiptListener?(receipt, { (err, shouldFinish, response) in
         // Call request callback back to the main thread
         DispatchQueue.main.async {
            restoreRequest(err);
         }
      })
   }
   
}
