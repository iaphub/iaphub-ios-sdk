//
//  IHReceipt.swift
//  Iaphub
//
//  Created by iaphub on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation
import StoreKit

@objc public class IHReceipt: NSObject {

   // Product id
   public var token: String
   // Product sku
   public var sku: String
   // If the receipt comes from a restore
   public var isRestore: Bool
   
   // Convert the object to a dictionary
   var dictionary: [String: Any] {
     return [
      "token": token,
      "sku": sku,
      "isRestore": isRestore
     ]
   }

   init(token: String, sku: String, isRestore: Bool) {
      self.token = token
      self.sku = sku
      self.isRestore = isRestore
   }

}
