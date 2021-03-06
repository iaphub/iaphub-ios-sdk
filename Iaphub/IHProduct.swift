//
//  IHProduct.swift
//  Iaphub
//
//  Created by Work on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation
import StoreKit

extension NSDecimalNumber {
    
    func getLocalizedPrice(locale: Locale) -> String? {
        let formatter = NumberFormatter()

        formatter.numberStyle = .currency
        formatter.locale = locale
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2

        return formatter.string(from: self)
    }
    
}

@objc public class IHProduct: NSObject {

   // Product id
   @objc public var id: String
   // Product type
   @objc public var type: String
   // Product sku
   @objc public var sku: String

   // Product price
   @objc public var price: Decimal = 0
   // Product currency
   @objc public var currency: String?
   // Product localized price
   @objc public var localizedPrice: String?
   // Product title
   @objc public var localizedTitle: String?
   // Product description
   @objc public var localizedDescription: String?
   
   // Group
   @objc public var group: String?
   // Group name
   @objc public var groupName: String?
   
   // Subscription period type ("normal", "trial", "intro")
   @objc public var subscriptionPeriodType: String?
   // Duration of the subscription cycle specified in the ISO 8601 format
   @objc public var subscriptionDuration: String?
   
   // Localized introductory price
   @objc public var subscriptionIntroPrice: Decimal = 0
   // Introductory price amount
   @objc public var subscriptionIntroLocalizedPrice: String?
   // Payment type of the introductory offer
   @objc public var subscriptionIntroPayment: String? // ("as_you_go", "upfront")
   // Duration of an introductory cycle specified in the ISO 8601 format
   @objc public var subscriptionIntroDuration: String?
   // Number of cycles in the introductory offer
   @objc public var subscriptionIntroCycles: Int = 0
   
   // Duration of the trial specified in the ISO 8601 format
   @objc public var subscriptionTrialDuration: String?
   
   // SK Product
   @objc public var skProduct: SKProduct?

   
   required init(_ data: Dictionary<String, Any>) throws {
      // Checking mandatory properties
      guard let id = data["id"] as? String, let type = data["type"] as? String, let sku = data["sku"] as? String else {
         throw IHError(IHErrors.unknown, message: "product parsing failed");
      }
      // Assign properties
      self.id = id;
      self.type = type;
      self.sku = sku;
      self.group = data["group"] as? String
      self.groupName = data["groupName"] as? String
      self.subscriptionPeriodType = data["subscriptionPeriodType"] as? String
   }
   
   func setSKProduct(_ skProduct: SKProduct) {
      self.skProduct = skProduct
      self.localizedTitle = skProduct.localizedTitle
      self.localizedDescription = skProduct.localizedDescription
      self.price = skProduct.price.decimalValue
      // Get currency (Only available on IOS 10+)
      if #available(iOS 10, *) {
         self.currency = skProduct.priceLocale.currencyCode
      }
      self.localizedPrice = skProduct.price.getLocalizedPrice(locale: skProduct.priceLocale)
      // Get subscription duration (Only available on IOS 11.2+)
      if #available(iOS 11.2, *), let subscriptionPeriod = skProduct.subscriptionPeriod {
         self.subscriptionDuration = self.convertToISO8601(subscriptionPeriod.numberOfUnits, subscriptionPeriod.unit)
      }
      // Get informations if there is an intro period (Only available on IOS 11.2+)
      if #available(iOS 11.2, *), let introductoryPrice = skProduct.introductoryPrice {
         // Detect free trial
         if (introductoryPrice.paymentMode == SKProductDiscount.PaymentMode.freeTrial) {
            self.subscriptionTrialDuration = self.convertToISO8601(introductoryPrice.subscriptionPeriod.numberOfUnits, introductoryPrice.subscriptionPeriod.unit)
         }
         // Otherwise it is an intro payment
         else {
            self.subscriptionIntroPrice = introductoryPrice.price.decimalValue
            self.subscriptionIntroLocalizedPrice = introductoryPrice.price.getLocalizedPrice(locale: skProduct.priceLocale)
            self.subscriptionIntroDuration = self.convertToISO8601(introductoryPrice.subscriptionPeriod.numberOfUnits, introductoryPrice.subscriptionPeriod.unit)
            self.subscriptionIntroCycles = introductoryPrice.numberOfPeriods
            // Detect 'As You Go' payment
            if (introductoryPrice.paymentMode == SKProductDiscount.PaymentMode.payAsYouGo) {
               self.subscriptionIntroPayment = "as_you_go"
            }
            // Detect 'Upfront' payment
            if (introductoryPrice.paymentMode == SKProductDiscount.PaymentMode.payUpFront) {
               self.subscriptionIntroPayment = "upfront"
            }
         }
      }
   }
   
   @available(iOS 11.2, *)
   func convertToISO8601(_ numberOfUnits: Int, _ unit: SKProduct.PeriodUnit) -> String? {
      if (unit == SKProduct.PeriodUnit.year) {
         return "P\(numberOfUnits)Y"
      }
      else if (unit == SKProduct.PeriodUnit.month) {
         return "P\(numberOfUnits)M"
      }
      else if (unit == SKProduct.PeriodUnit.week) {
         return "P\(numberOfUnits)W"
      }
      else if (unit == SKProduct.PeriodUnit.day) {
         return "P\(numberOfUnits)D"
      }
      return nil;
   }

}
