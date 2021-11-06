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
   // If the subscription is in a retry period
   @objc public var isSubscriptionRetryPeriod: Bool = false
   // If the subscription is in a grace period
   @objc public var isSubscriptionGracePeriod: Bool = false
   // Subscription product of the next renewal (only defined if different than the current product)
   @objc public var subscriptionRenewalProduct: String?
   // SubscriptionRenewalProduct sku
   @objc public var subscriptionRenewalProductSku: String?
   // Subscription state
   @objc public var subscriptionState: String?

   
   required init(_ data: Dictionary<String, Any>) throws {
      try super.init(data)
      self.purchase = data["purchase"] as? String
      self.purchaseDate = IHUtil.dateFromIsoString(data["purchaseDate"] as? String)
      self.platform = data["platform"] as? String
      self.expirationDate = IHUtil.dateFromIsoString(data["expirationDate"] as? String)
      self.isSubscriptionRenewable = (data["isSubscriptionRenewable"] as? Bool) ?? false
      self.isSubscriptionRetryPeriod = (data["isSubscriptionRetryPeriod"] as? Bool) ?? false
      self.isSubscriptionGracePeriod = (data["isSubscriptionGracePeriod"] as? Bool) ?? false
      self.subscriptionRenewalProduct = data["subscriptionRenewalProduct"] as? String
      self.subscriptionRenewalProductSku = data["subscriptionRenewalProductSku"] as? String
      self.subscriptionState = data["subscriptionState"] as? String
   }
   
   override func getDictionary() -> [String: Any] {
      var data = super.getDictionary()
      let extraData = [
         "purchase": self.purchase as Any,
         "purchaseDate": IHUtil.dateToIsoString(self.purchaseDate) as Any,
         "platform": self.platform as Any,
         "expirationDate": IHUtil.dateToIsoString(self.expirationDate) as Any,
         "isSubscriptionRenewable": self.isSubscriptionRenewable as Any,
         "isSubscriptionRetryPeriod": self.isSubscriptionRetryPeriod as Any,
         "isSubscriptionGracePeriod": self.isSubscriptionGracePeriod as Any,
         "subscriptionRenewalProduct": self.subscriptionRenewalProduct as Any,
         "subscriptionRenewalProductSku": self.subscriptionRenewalProductSku as Any,
         "subscriptionState": self.subscriptionState as Any
      ]

      data.merge(extraData) { (current, _) in current }
      return data
   }

}
