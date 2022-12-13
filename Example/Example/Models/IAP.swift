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
      self.refreshProducts()
   }
   
   func refreshProducts() {
      Iaphub.getProducts { err, productsForSale, activeProducts in
         if (productsForSale != nil) {
            self.productsForSale = productsForSale!
         }
         if (activeProducts != nil) {
            self.activeProducts = activeProducts!
         }
         if (err != nil) {
            print("-> refresh products error: \(err?.localizedDescription)")
         }
      }
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
         self.skuProcessing = ""
         // Check error
         if let err = err {
            // Do not do anything if purchase cancelled or product already purchased
            if (err.code == "user_cancelled" || err.code == "product_already_purchased") {
               return
            }
            // The billing is unavailable (An iPhone can be restricted from accessing the Apple App Store)
            else if (err.code == "billing_unavailable") {
               return self.openAlert("In-app purchase not allowed")
            }
            else if (err.code == "product_change_next_renewal") {
               return self.openAlert("The product will be changed on the next renewal date")
            }
            // The product has already been bought but it's owned by a different user, restore needed to transfer it to this user
            else if (err.code == "product_owned_different_user") {
               return self.openAlert("You already purchased this product but it is currently used by a different account, restore your purchases to transfer it to this account")
            }
            // The payment has been deferred (transaction pending, its final status is pending external action)
            else if (err.code == "deferred_payment") {
               return self.openAlert("Purchase awaiting approval, your purchase has been processed but is awaiting approval")
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
            else if (err.code == "receipt_failed") {
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
      })
   }
   
   func restore() {
      Iaphub.restore({ (err, response) in
         if (err != nil) {
            self.openAlert("Restore failed, please retry later or contact the support (support@myapp.com)")
         }
         else {
            self.openAlert("Restore successful!")
         }
      })
   }
   
   func showManageSubscriptions() {
      Iaphub.showManageSubscriptions({ (err) in
         if (err != nil) {
            self.openAlert("Couldn't redirect to the app store, please check your subscriptions directly from the App Store app")
         }
      })
   }
}
