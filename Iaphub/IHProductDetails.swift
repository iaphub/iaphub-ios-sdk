//
//  IHProductDetails.swift
//  Iaphub
//
//  Created by iaphub on 8/14/22.
//  Copyright © 2022 iaphub. All rights reserved.
//

import Foundation

public class IHProductDetails: NSObject, IHParsable {

   // Product sku
   @objc public var sku: String
   // Product title
   @objc public var localizedTitle: String?
   // Product description
   @objc public var localizedDescription: String?
   // Product price
   @objc public var price: Double = 0
   // Product currency
   @objc public var currency: String?
   // Product localized price
   @objc public var localizedPrice: String?
   // Duration of the subscription cycle specified in the ISO 8601 format
   @objc public var subscriptionDuration: String?
   // Subscription intro phases
   @objc public var subscriptionIntroPhases: [IHSubscriptionIntroPhase]?

   
   required init(_ data: Dictionary<String, Any>) throws {
      // Checking mandatory properties
      guard let sku = data["sku"] as? String else {
         throw IHError(IHErrors.unexpected, IHUnexpectedErrors.product_parsing_failed, message: "in ProductDetails class", params: data);
      }
      // Assign properties
      self.sku = sku;
      self.localizedTitle = data["localizedTitle"] as? String
      self.localizedDescription = data["localizedDescription"] as? String
      self.price = data["price"] as? Double ?? 0
      self.currency = data["currency"] as? String
      self.localizedPrice = data["localizedPrice"] as? String
      self.subscriptionDuration = data["subscriptionDuration"] as? String
      self.subscriptionIntroPhases = data["subscriptionIntroPhases"] != nil ? IHUtil.parseItems(data: data["subscriptionIntroPhases"], type: IHSubscriptionIntroPhase.self, allowNull: true, failure: { err, item in
         IHError(IHErrors.unexpected, IHUnexpectedErrors.product_parsing_failed, message: "error in subscriptionIntroPhase, err: \(err.localizedDescription)", params: ["item": item as Any])
      }) : nil
   }
   
   public func getDictionary() -> [String: Any] {
      return [
         "sku": self.sku,
         "localizedTitle": self.localizedTitle as Any,
         "localizedDescription": self.localizedDescription as Any,
         "price": self.price as Any,
         "currency": self.currency as Any,
         "localizedPrice": self.localizedPrice as Any,
         "subscriptionDuration": self.subscriptionDuration as Any,
         "subscriptionIntroPhases": self.subscriptionIntroPhases?.map({(item) in item.getDictionary()}) as Any
      ]
   }
   
   public func setDetails(_ details: IHProductDetails) {
      self.localizedTitle = details.localizedTitle
      self.localizedDescription = details.localizedDescription
      self.price = details.price
      self.currency = details.currency
      self.localizedPrice = details.localizedPrice
      self.subscriptionDuration = details.subscriptionDuration
      self.subscriptionIntroPhases = details.subscriptionIntroPhases
   }

}
