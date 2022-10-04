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
   // Platform of the purchase
   @objc public var platform: String?

   // Subscription expiration date
   @objc public var expirationDate: Date?
   // Returns if the subscription will auto renew
   @objc public var isSubscriptionRenewable: Bool = false
   // If the subscription is shared by a family member (iOS subscriptions only)
   @objc public var isFamilyShare: Bool = false
   // Subscription product of the next renewal (only defined if different than the current product)
   @objc public var subscriptionRenewalProduct: String?
   // SubscriptionRenewalProduct sku
   @objc public var subscriptionRenewalProductSku: String?
   // Subscription state
   @objc public var subscriptionState: String?
   // Subscription period type ("normal", "trial", "intro")
   @objc public var subscriptionPeriodType: String?

   
   required init(_ data: Dictionary<String, Any>) throws {
      var data = data
      // The sku could be empty if the active product comes from a different platform, update it to an empty string to avoid an error
      if (data["sku"] as? String == nil) {
         data["sku"] = ""
      }
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
      // The following properties are for subscritions only
      self.expirationDate = IHUtil.dateFromIsoString(data["expirationDate"], allowNull: !self.type.contains("subscription"), failure: { err in
         IHError(
            IHErrors.unexpected,
            IHUnexpectedErrors.date_parsing_failed,
            message: "issue on active product expiration date, \(err.localizedDescription)",
            params: ["expirationDate": data["expirationDate"] as Any, "purchase": self.purchase as Any]
         )
      })
      self.isSubscriptionRenewable = (data["isSubscriptionRenewable"] as? Bool) ?? false
      self.isFamilyShare = (data["isFamilyShare"] as? Bool) ?? false
      self.subscriptionRenewalProduct = data["subscriptionRenewalProduct"] as? String
      self.subscriptionRenewalProductSku = data["subscriptionRenewalProductSku"] as? String
      self.subscriptionState = data["subscriptionState"] as? String
      if (self.type.contains("subscription") && self.subscriptionState == nil) {
         IHError(
            IHErrors.unexpected,
            IHUnexpectedErrors.property_missing,
            message: "subscriptionState not found",
            params: ["purchase": self.purchase as Any]
         )
      }
      // Set subscription period type and filter intro phases
      self.subscriptionPeriodType = data["subscriptionPeriodType"] as? String
   }
   
   override public func getDictionary() -> [String: Any] {
      var data = super.getDictionary()
      let extraData = [
         "purchase": self.purchase as Any,
         "purchaseDate": IHUtil.dateToIsoString(self.purchaseDate) as Any,
         "platform": self.platform as Any,
         "expirationDate": IHUtil.dateToIsoString(self.expirationDate) as Any,
         "isSubscriptionRenewable": self.isSubscriptionRenewable as Any,
         "isFamilyShare": self.isFamilyShare as Any,
         "subscriptionRenewalProduct": self.subscriptionRenewalProduct as Any,
         "subscriptionRenewalProductSku": self.subscriptionRenewalProductSku as Any,
         "subscriptionState": self.subscriptionState as Any,
         "subscriptionPeriodType": self.subscriptionPeriodType as Any
      ]

      data.merge(extraData) { (current, _) in current }
      return data
   }

}
