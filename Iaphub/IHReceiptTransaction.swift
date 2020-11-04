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
   
   required init(_ data: Dictionary<String, Any>) throws {
      try super.init(data)
      self.webhookStatus = data["webhookStatus"] as? String
   }
}
