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
      self.purchaseDate = data["purchaseDate"] as? Date
      self.platform = data["platform"] as? String
      self.expirationDate = data["expirationDate"] as? Date
      self.isSubscriptionRenewable = (data["isSubscriptionRenewable"] as? Bool) ?? false
      self.isSubscriptionRetryPeriod = (data["isSubscriptionRetryPeriod"] as? Bool) ?? false
      self.subscriptionRenewalProduct = data["subscriptionRenewalProduct"] as? String
      self.subscriptionRenewalProductSku = data["subscriptionRenewalProductSku"] as? String
      self.subscriptionState = data["subscriptionState"] as? String
   }

}
