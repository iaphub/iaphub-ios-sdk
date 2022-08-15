//
//  IHSubscriptionIntroPhase.swift
//  Iaphub
//
//  Created by iaphub on 8/14/22.
//  Copyright © 2022 iaphub. All rights reserved.
//

import Foundation

public class IHSubscriptionIntroPhase: NSObject, IHParsable {

   // Phase type (Possible values: 'trial', 'intro')
   public var type: String
   // Phase price
   public var price: Double
   // Phase currency
   public var currency: String
   // Phase localized price
   public var localizedPrice: String
   // Phase duration cycle specified in the ISO 8601 format
   public var cycleDuration: String
   // Phase cycle count
   public var cycleCount: Int
   // Phase payment type (Possible values: 'as_you_go', 'upfront')
   public var payment: String
   
   required init(_ data: Dictionary<String, Any>) throws {
      // Checking mandatory properties
      guard let type = data["type"] as? String,
            let price = data["price"] as? Double,
            let currency = data["currency"] as? String,
            let localizedPrice = data["localizedPrice"] as? String,
            let cycleDuration = data["cycleDuration"] as? String,
            let cycleCount = data["cycleCount"] as? Int,
            let payment = data["payment"] as? String else {
               throw IHError(IHErrors.unexpected, IHUnexpectedErrors.product_parsing_failed, message: "in SubscriptionIntroPhase class", params: data);
      }
      // Assign properties
      self.type = type
      self.price = price
      self.currency = currency
      self.localizedPrice = localizedPrice
      self.cycleDuration = cycleDuration
      self.cycleCount = cycleCount
      self.payment = payment
   }
   
   public func getDictionary() -> [String: Any] {
      return [
         "type": self.type,
         "price": self.price,
         "currency": self.currency,
         "localizedPrice": self.localizedPrice,
         "cycleDuration": self.cycleDuration,
         "cycleCount": self.cycleCount,
         "payment": self.payment
      ]
   }
   
}
