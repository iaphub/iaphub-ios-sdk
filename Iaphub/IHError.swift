//
//  IHError.swift
//  Iaphub
//
//  Created by iaphub on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation
import StoreKit

@objc public class IHError: NSObject, LocalizedError {
   
   @objc public let message: String
   @objc public let code: String
   
   public var errorDescription: String? {
      get {
         return "\(self.message) (code: \(self.code))"
      }
   }

   init(message: String, code: String = "unknown", delegate: Bool = true) {
      self.message = message
      self.code = code
      super.init()
      if (delegate == true) {
         self.triggerDelegate()
      }
   }
   
   init(_ error: IHErrors, message: String = "", delegate: Bool = true) {
      if (message != "") {
         self.message = error.message + ", " + message;
      } else {
         self.message = error.message;
      }
      self.code = error.code
      super.init()
      if (delegate == true) {
         self.triggerDelegate()
      }
   }
   
   init(_ error: SKError, delegate: Bool = true) {
      switch error.code {
         case .paymentCancelled:
            self.message = IHErrors.user_cancelled.message;
            self.code = IHErrors.user_cancelled.code;
            break
         case .storeProductNotAvailable:
            self.message = IHErrors.product_not_available.message;
            self.code = IHErrors.product_not_available.code;
            break
         case .cloudServiceNetworkConnectionFailed:
            self.message = IHErrors.network_error.message;
            self.code = IHErrors.network_error.code;
            break
         default:
         self.message = "An unexpected error has happened, StoreKit error: " + error.localizedDescription;
            self.code = IHErrors.unexpected.code;
            break
      }
      super.init()
      if (delegate == true) {
         self.triggerDelegate()
      }
   }

   convenience init(_ error: Error?) {
      if let error = error {
         if let skError = error as? SKError {
            self.init(skError)
            return
         }
         else {
            self.init(IHErrors.unexpected, message: error.localizedDescription)
         }
      }
      else {
         self.init(IHErrors.unexpected)
      }
   }
   
   func triggerDelegate() {
      Iaphub.delegate?.didReceiveError?(err: self)
   }
}

public enum IHErrors : String {

   case unexpected = "An unexpected error has happened"
   case network_error = "The remote server couldn't be reached properly"
   case billing_unavailable = "The billing is unavailable (An iPhone can be restricted from accessing the Apple App Store)"
   case anonymous_purchase_not_allowed = "Anonymous purchase are not allowed, identify user using the login method or enable the anonymous purchase option"
   case user_cancelled = "The purchase has been cancelled by the user"
   case deferred_payment = "The payment has been deferred (awaiting approval from parental control)"
   case product_not_available = "The requested product isn't available for purchase"
   case receipt_failed = "Receipt validation failed, receipt processing will be automatically retried if possible"
   case receipt_invalid = "Receipt is invalid"
   case receipt_stale = "Receipt is stale, no purchases still valid were found"
   case cross_platform_conflict = "Cross platform conflict detected, an active subscription from another platform has been detected"
   case product_already_purchased = "Product already purchased, it is already an active product of the user"
   case transaction_not_found = "Transaction not found, the product sku wasn't in the receipt, the purchase failed"
   case user_conflict = "The transaction is successful but it belongs to a different user, a restore might be needed"
   case code_redemption_unavailable = "Presenting the code redemption is not available (only available on iOS 14+)"
   case user_tags_processing = "The user is currently posting tags, please wait concurrent requests not allowed"
   case restore_processing = "A restore is currently processing"
   case buy_processing = "A purchase is currently processing"

   var code: String {
      get { return String(describing: self) }
   }
   var message: String {
      get { return self.rawValue }
   }
}
