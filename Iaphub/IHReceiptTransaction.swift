//
//  IHReceiptTransaction.swift
//  Iaphub
//
//  Created by iaphub on 10/5/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation

@objc public class IHReceiptTransaction: IHActiveProduct {
   
   // Transaction webhook status
   @objc public var webhookStatus: String?
   // User id
   @objc public var user: String?
   
   required init(_ data: Dictionary<String, Any>) throws {
      try super.init(data)
      self.webhookStatus = data["webhookStatus"] as? String
      self.user = data["user"] as? String
   }
   
   override public func getDictionary() -> [String: Any] {
      var data = super.getDictionary()
      let extraData = [
         "webhookStatus": self.webhookStatus as Any,
         "user": self.user as Any
      ]

      data.merge(extraData) { (current, _) in current }
      return data
   }
}
