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
   var isObserving = false

   /**
    Start IAP
    */
   public func start(_ receiptListener: @escaping (IHReceipt, @escaping ((IHError?, Bool, Any?) -> Void)) -> Void) {
      // Save listener
      self.receiptListener = receiptListener
      // Start observing iap
      self.startObserving()
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
    Start observing  receipts
    */
   private func startObserving() {
      if (self.isObserving == true) {
         return
      }
      self.isObserving = true
      SKPaymentQueue.default().add(self)
      // Stop observating iap when the app is about to terminate
      NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] (_) in
         self?.stopObserving()
      }
   }
   
   /**
    Stop observing  receipts
    */
   private func stopObserving() {
      if (self.isObserving == false) {
         return
      }
      self.isObserving = false
      SKPaymentQueue.default().remove(self)
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
   private func processPurchasedTransaction(_ transaction: SKPaymentTransaction) {
      // Get receipt token
      let receiptToken = self.getReceiptToken()
      // Check receipt token is not nil
      guard let token = receiptToken else {
         return
      }
      // Create receipt object
      let receipt = IHReceipt(token: token, sku: transaction.payment.productIdentifier, isRestore: false)
      // Call receipt listener
      self.receiptListener?(receipt, { (err, shouldFinish, response) in
         // Finish transaction
         if (shouldFinish) {
            self.finishTransaction(transaction)
         }
         // Process buy request
         self.processBuyRequest(transaction, err, response)
      })
   }
   
   /**
    Process failed transaction
    */
   private func processFailedTransaction(_ transaction: SKPaymentTransaction) {
      /// Create deferred transaction error
      var err = IHError(IHErrors.unknown)
      // Get SKError
      if let skError = transaction.error as? SKError {
         err = IHError(skError);
      }
      // Process buy request
      self.processBuyRequest(transaction, err, nil)
      // Finish transaction
      self.finishTransaction(transaction)
   }
   
   /**
    Process deferred transaction
    */
   private func processDeferredTransaction(_ transaction: SKPaymentTransaction) {
      // Create deferred transaction error
      let err = IHError(IHErrors.deferred_payment)
      // Process buy request
      self.processBuyRequest(transaction, err, nil)
      // There is no need to finish a deferred transaction
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
               // Transaction purchased
               self.processPurchasedTransaction(transaction)
               break
            case .failed:
               // The transaction purchase has failed
               self.processFailedTransaction(transaction)
               break
            case .deferred:
               // The transaction has been deferred (awaiting approval from parental control)
               self.processDeferredTransaction(transaction)
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
      let receipt = IHReceipt(token: token, sku: "", isRestore: true)
      // Call receipt listener
      self.receiptListener?(receipt, { (err, shouldFinish, response) in
         // Call request callback back to the main thread
         DispatchQueue.main.async {
            restoreRequest(err);
         }
      })
   }
   
}
