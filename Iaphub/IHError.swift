//
//  IHError.swift
//  Iaphub
//
//  Created by iaphub on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation
import StoreKit

@objc public class IHError: NSObject, Error {
   
   @objc public let message: String
   @objc public let code: String

   init(message: String, code: String = "unknown") {
      self.message = message
      self.code = code
   }
   
   init(_ error: IHErrors, message: String = "") {
      if (message != "") {
         self.message = error.message + ", " + message;
      } else {
         self.message = error.message;
      }
      self.code = error.code
   }
   
   init(_ error: SKError) {
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
            self.message = "An unexpected error has happened, StoreKit error: " + String(describing: error.code);
            self.code = IHErrors.unknown.code;
            break
      }
   }

   convenience init(_ error: Error) {
      if let skError = error as? SKError {
         self.init(IHError(skError))
      } else {
         self.init(IHErrors.unknown, message: "error: " + error.localizedDescription)
      }
   }
}

public enum IHErrors : String {

   case unknown = "An unexpected error has happened"
   case network_error = "The remote server couldn't be reached properly"
   case billing_unavailable = "The billing is unavailable (An iPhone can be restricted from accessing the Apple App Store)"
   case user_cancelled = "The purchase has been cancelled by the user"
   case deferred_payment = "The payment has been deferred (awaiting approval from parental control)"
   case product_already_owned = "Couldn't buy product because it has been bought in the past but hasn't been consumed (restore needed)"
   case product_not_available = "The requested product isn't available for purchase"
   case receipt_failed = "Receipt validation failed, receipt processing will be automatically retried if possible"
   case receipt_invalid = "Receipt is invalid"
   case receipt_stale = "Receipt is stale, no purchases still valid were found"
   case cross_platform_conflict = "Cross platform conflict detected, an active subscription from another platform has been detected"
   case product_already_purchased = "Product already purchased, if not returned in the active products it may be owned by a different user (restore needed)"
   case transaction_not_found = "Transaction not found, the product sku wasn't in the receipt, the purchase failed"

   var code: String {
      get { return String(describing: self) }
   }
   var message: String {
      get { return self.rawValue }
   }
}
