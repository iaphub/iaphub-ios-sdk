//
//  IHUserFetchContext.swift
//  Iaphub
//
//  Created by iaphub on 1/8/25.
//  Copyright © 2025 iaphub. All rights reserved.
//

enum IHUserFetchContextSource: String {
   case products = "products" // When fetching the products
   case receipt = "receipt" // When posting a receipt
   case buy = "buy" // When a buy occurs
   case restore = "restore" // When a restore occurs
}

enum IHUserFetchContextProperty: String {
   case with_active_subscription = "was" // The user has an active subscription
   case with_expired_subscription = "wes" // The user has an expired subscription
   case with_active_non_consumable = "wanc" // The user has an active non consumable
   case on_foreground = "ofg" // Occured when the app went to foreground
}

public struct IHUserFetchContext {
   var source: IHUserFetchContextSource
   var properties: [IHUserFetchContextProperty]
   
   init(source: IHUserFetchContextSource, properties: [IHUserFetchContextProperty] = []) {
      self.source = source
      self.properties = properties
   }
   
   func getValue() -> String {
      let components = [source.rawValue] + properties.map { $0.rawValue }
      return components.joined(separator: "/")
   }
}
