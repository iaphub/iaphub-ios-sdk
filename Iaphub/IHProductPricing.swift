//
//  IHProductPricing.swift
//  Iaphub
//
//  Created by iaphub on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation

class IHProductPricing {
   // Product id
   public var id: String
   // Product price
   public var price: Decimal = 0
   // Product currency
   public var currency: String
   
   // Convert the object to a dictionary
   var dictionary: [String: Any] {
     return [
      "id": id,
      "price": price,
      "currency": currency
     ]
   }
   
   init(id: String, price: Decimal, currency: String) {
      self.id = id
      self.price = price
      self.currency = currency
   }
   
}
