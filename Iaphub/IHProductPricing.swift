//
//  IHProductPricing.swift
//  Iaphub
//
//  Created by iaphub on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation

@objc public class IHProductPricing: NSObject {
   // Product id
   public var id: String?
   // Product sku
   public var sku: String
   // Product price
   public var price: Double
   // Product currency
   public var currency: String
   // Product intro price
   public var introPrice: Double?
   
   init(id: String?, sku: String, price: Double, currency: String, introPrice: Double? = nil) {
      self.id = id
      self.sku = sku
      self.price = price
      self.currency = currency
      self.introPrice = introPrice
   }

   func getDictionary() -> [String: Any] {
      var dic = [
         "sku": self.sku as Any,
         "price": self.price as Any,
         "currency": self.currency as Any
      ]
      // Add id if defined
      if (self.id != nil) {
         dic["id"] = self.id as Any
      }
      // Add only intro price if defined
      if (self.introPrice != nil) {
         dic["introPrice"] = self.introPrice as Any
      }
      return dic
   }
}
