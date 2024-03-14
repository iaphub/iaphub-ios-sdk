//
//  IHReceipt.swift
//  Iaphub
//
//  Created by iaphub on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation
import StoreKit

@objc public class IHReceipt: NSObject {

   // Product id
   public var token: String
   // Product sku
   public var sku: String
   // Receipt context
   public var context: String
   // Payment processor
   public var paymentProcessor: String
   // Receipt is finished
   public var isFinished: Bool
   // Receipt process date
   public var processDate: Date?


   init(token: String, sku: String, context: String, paymentProcessor: String) {
      self.token = token
      self.sku = sku
      self.context = context
      self.paymentProcessor = paymentProcessor
      self.isFinished = false
   }

   public func getDictionary() -> [String: Any] {
      return [
         "token": self.token,
         "sku": self.sku,
         "context": self.context,
         "paymentProcessor": self.paymentProcessor
      ]
   }
}
