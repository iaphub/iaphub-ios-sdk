//
//  IHProductPricing.swift
//  Iaphub
//
//  Created by iaphub on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation

class IHProductPricing: IHParsable {
   // Product id
   public var id: String
   // Product price
   public var price: Double
   // Product currency
   public var currency: String
   // Product intro price
   public var introPrice: Double?

   required init(_ data: Dictionary<String, Any>) throws {
      guard let id = data["id"] as? String, let price = data["price"] as? Double, let currency = data["currency"] as? String else {
         throw IHError(IHErrors.unexpected, IHUnexpectedErrors.pricing_parsing_failed, params: data);
      }
      self.id = id
      self.price = price
      self.currency = currency
      // Add intro price if defined
      if let introPrice = data["introPrice"] as? Double {
         self.introPrice = introPrice
      }
   }
   
   init(id: String, price: Double, currency: String, introPrice: Double? = nil) {
      self.id = id
      self.price = price
      self.currency = currency
      self.introPrice = introPrice
   }
   
   func getDictionary() -> [String: Any] {
      var dic = [
         "id": self.id as Any,
         "price": self.price as Any,
         "currency": self.currency as Any
      ]
      // Add only intro price if defined
      if (self.introPrice != nil) {
         dic["introPrice"] = self.introPrice as Any
      }
      return dic
   }
}
