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
   public var price: Decimal = 0
   // Product currency
   public var currency: String

   required init(_ data: Dictionary<String, Any>) throws {
      guard let id = data["id"] as? String, let price = data["price"] as? Double, let currency = data["currency"] as? String else {
         throw IHError(IHErrors.unexpected, IHUnexpectedErrors.pricing_parsing_failed, params: data);
      }
      self.id = id
      self.price = Decimal(price)
      self.currency = currency
   }
   
   init(id: String, price: Decimal, currency: String) {
      self.id = id
      self.price = price
      self.currency = currency
   }
   
   func getDictionary() -> [String: Any] {
      return [
         "id": self.id as Any,
         "price": self.price as Any,
         "currency": self.currency as Any
      ]
   }
}
