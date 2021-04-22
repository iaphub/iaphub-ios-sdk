//
//  IAP.swift
//  Example
//
//  Created by Work on 8/30/20.
//

import Foundation
import StoreKit
import Iaphub

class IAP: ObservableObject {
   @Published var productsForSale = [IHProduct]()
   @Published var activeProducts = [IHProduct]()
   @Published var alertOpen = false
   @Published var alertMessage = ""
   @Published var skuProcessing = ""

   static let shared = IAP()

   init() {
      // Trigger refresh of products when app goes to foreground
      NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] (_) in
         self?.refreshProducts()
      }
   }
   
   func refreshProducts() {
      self.getProductsForSale()
      self.getActiveProducts()
   }

   func getProductsForSale() {
      Iaphub.getProductsForSale({ (err, products) in
         if let err = err {
            print("--> getProductsForSale error: ", err.message)
         }
         else {
            self.productsForSale = products!
         }
      })
   }
   
   func getActiveProducts() {
      Iaphub.getActiveProducts({ (err, products) in
         if let err = err {
            print("-> getActiveProducts error: ", err.message)
         }
         else {
            self.activeProducts = products!
         }
      })
   }
   
   func openAlert(_ message: String) {
      self.alertOpen = true
      self.alertMessage = message
   }
   
   func closeAlert() {
      self.alertOpen = false
      self.alertMessage = ""
   }
   
   func buy(_ sku: String?) {
      guard let sku = sku else {
         return
      }
      self.skuProcessing = sku
      Iaphub.buy(sku: sku, { (err, transaction) in
         print("--> buy error: ", err?.message)
         print("--> buy transaction: ", transaction)
         self.skuProcessing = ""
         // Check error
         if let err = err {
            // Purchase popup cancelled by the user
            if (err.code == "user_cancelled") {
               return
            }
            // The billing is unavailable (An iPhone can be restricted from accessing the Apple App Store)
            else if (err.code == "billing_unavailable") {
               return self.openAlert("In-app purchase not allowed")
            }
            // Couldn't buy product because it has been bought in the past but hasn't been consumed (restore needed)
            else if (err.code == "product_already_owned") {
               return self.openAlert("Product already owned, please restore your purchases in order to fix that issue")
            }
            // The payment has been deferred (awaiting approval from parental control)
            else if (err.code == "deferred_payment") {
               return self.openAlert("Your purchase is awaiting approval from the parental control")
            }
            /*
             * The remote server couldn't be reached properly
             * The user will have to restore its purchases in order to validate the transaction
             * An automatic restore should be triggered on every relaunch of your app since the transaction hasn't been 'finished'
             */
            else if (err.code == "network_error") {
               return self.openAlert("Please try to restore your purchases later (Button in the settings) or contact the support (support@myapp.com)")
            }
            /*
             * The receipt has been processed on IAPHUB but something went wrong
             * It is probably because of an issue with the configuration of your app or a call to the Itunes/GooglePlay API that failed
             * IAPHUB will send you an email notification when a receipt fails, by checking the receipt on the dashboard you'll find a detailed report of the error
             * After fixing the issue (if there's any), just click on the 'New report' button in order to process the receipt again
             * If it is an error contacting the Itunes/GooglePlay API, IAPHUB will retry to process the receipt automatically as well
             */
            else if (err.code == "receipt_validation_failed") {
               return self.openAlert("We're having trouble validating your transaction, give us some time we'll retry to validate your transaction ASAP!")
            }
            /*
             * The receipt has been processed on IAPHUB but is invalid
             * It could be a fraud attempt, using apps such as Freedom or Lucky Patcher on an Android rooted device
             */
            else if (err.code == "receipt_invalid") {
               return self.openAlert("We were not able to process your purchase, if you've been charged please contact the support (support@myapp.com)")
            }
            // Any other error
            return self.openAlert("We were not able to process your purchase, please try again later or contact the support (support@myapp.com)")
         }
         /*
          * The purchase has been successful but we need to check that the webhook to our server was successful as well (if you implemented webhooks)
          * If the webhook request failed, IAPHUB will send you an alert and retry again in 1 minute, 10 minutes, 1 hour and 24 hours.
          * You can retry the webhook directly from the dashboard as well
          */
         if (transaction?.webhookStatus == "failed") {
            self.openAlert("Your purchase was successful but we need some more time to validate it, should arrive soon! Otherwise contact the support (support@myapp.com)")
         }
         // Everything was successful! Yay!
         else {
            self.openAlert("Your purchase has been processed successfully!")
         }
         // Refresh products
         self.refreshProducts()
      })
   }
   
   func restore() {
      Iaphub.restore({ (err) in
         if (err != nil) {
            self.openAlert("Restore failed, please retry later or contact the support (support@myapp.com)")
         }
         else {
            self.openAlert("Restore successful!")
         }
      })
   }
}
