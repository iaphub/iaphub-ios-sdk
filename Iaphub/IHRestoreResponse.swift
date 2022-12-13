//
//  IHRestoreResponse.swift
//  Iaphub
//
//  Created by iaphub on 12/12/22.
//  Copyright © 2022 iaphub. All rights reserved.
//

import Foundation

@objc public class IHRestoreResponse: NSObject {

   // New purchases
   public var newPurchases: [IHReceiptTransaction]
   // Extisting active products transferred to the user
   public var transferredActiveProducts: [IHActiveProduct]

   init(newPurchases: [IHReceiptTransaction], transferredActiveProducts: [IHActiveProduct]) {
      self.newPurchases = newPurchases
      self.transferredActiveProducts = transferredActiveProducts
   }
   
   public func getDictionary() -> [String: Any] {
      return [
         "newPurchases": self.newPurchases.map({(item) in item.getDictionary()}) as Any,
         "transferredActiveProducts": self.transferredActiveProducts.map({(item) in item.getDictionary()}) as Any
      ]
   }

}
