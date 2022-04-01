//
//  IHActiveProduct.swift
//  Iaphub
//
//  Created by iaphub on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation
import StoreKit

@objc public class IHActiveProduct: IHProduct {

   // Purchase id
   @objc public var purchase: String?
   // Purchase date
   @objc public var purchaseDate: Date?
   
   // Subscription platform
   @objc public var platform: String?
   // Subscription expiration date
   @objc public var expirationDate: Date?
   // If the subscription will auto renew
   @objc public var isSubscriptionRenewable: Bool = false
   // Subscription product of the next renewal (only defined if different than the current product)
   @objc public var subscriptionRenewalProduct: String?
   // SubscriptionRenewalProduct sku
   @objc public var subscriptionRenewalProductSku: String?
   // Subscription state
   @objc public var subscriptionState: String?

   
   required init(_ data: Dictionary<String, Any>) throws {
      try super.init(data)
      self.purchase = data["purchase"] as? String
      self.purchaseDate = IHUtil.dateFromIsoString(data["purchaseDate"], failure: { err in
         IHError(
            IHErrors.unexpected,
            IHUnexpectedErrors.date_parsing_failed,
            message: "issue on active product purchase date, \(err.localizedDescription)",
            params: ["purchaseDate": data["purchaseDate"] as Any, "purchase": self.purchase as Any]
         )
      })
      self.platform = data["platform"] as? String
      self.expirationDate = IHUtil.dateFromIsoString(data["expirationDate"], failure: { err in
         IHError(
            IHErrors.unexpected,
            IHUnexpectedErrors.date_parsing_failed,
            message: "issue on active product expiration date, \(err.localizedDescription)",
            params: ["expirationDate": data["expirationDate"] as Any, "purchase": self.purchase as Any]
         )
      })
      self.isSubscriptionRenewable = (data["isSubscriptionRenewable"] as? Bool) ?? false
      self.subscriptionRenewalProduct = data["subscriptionRenewalProduct"] as? String
      self.subscriptionRenewalProductSku = data["subscriptionRenewalProductSku"] as? String
      self.subscriptionState = data["subscriptionState"] as? String
   }
   
   override public func getDictionary() -> [String: Any] {
      var data = super.getDictionary()
      let extraData = [
         "purchase": self.purchase as Any,
         "purchaseDate": IHUtil.dateToIsoString(self.purchaseDate) as Any,
         "platform": self.platform as Any,
         "expirationDate": IHUtil.dateToIsoString(self.expirationDate) as Any,
         "isSubscriptionRenewable": self.isSubscriptionRenewable as Any,
         "subscriptionRenewalProduct": self.subscriptionRenewalProduct as Any,
         "subscriptionRenewalProductSku": self.subscriptionRenewalProductSku as Any,
         "subscriptionState": self.subscriptionState as Any
      ]

      data.merge(extraData) { (current, _) in current }
      return data
   }

}
