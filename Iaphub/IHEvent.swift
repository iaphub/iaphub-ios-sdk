//
//  IHEvent.swift
//  Iaphub
//
//  Created by iaphub on 12/12/22.
//  Copyright © 2022 iaphub. All rights reserved.
//

import Foundation

class IHEvent: IHParsable {

   // Event type
   var type: String
   // Event tags
   var tags: [String]
   // Event tags
   var transaction: IHReceiptTransaction
   
   required init(_ data: Dictionary<String, Any>) throws {
      // Checking mandatory properties
      guard let type = data["type"] as? String, let tags = data["tags"] as? [String], let transaction = data["transaction"] as? Dictionary<String, Any> else {
         throw IHError(IHErrors.unexpected, IHUnexpectedErrors.product_parsing_failed, message: "in Event class", params: data);
      }
      self.type = type
      self.tags = tags
      self.transaction = try IHReceiptTransaction(transaction)
   }
   
   func getDictionary() -> [String: Any] {
      return [
         "type": self.type,
         "tags": self.tags,
         "transaction": self.transaction.getDictionary()
      ]
   }

}

