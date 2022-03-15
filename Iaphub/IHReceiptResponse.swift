//
//  IHReceiptResponse.swift
//  Iaphub
//
//  Created by iaphub on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation

class IHReceiptResponse {

   // Status
   public var status: String?
   // New transactions
   public var newTransactions: [IHReceiptTransaction]?
   // Old transactions
   public var oldTransactions: [IHReceiptTransaction]?

   init(_ data: Dictionary<String, Any>) {
      self.status = data["status"] as? String
      self.newTransactions = IHUtil.parseItems(data: data["newTransactions"], type: IHReceiptTransaction.self, failure: { err, _ in
         IHError(IHErrors.unexpected, IHUnexpectedErrors.receipt_transation_parsing_failed, message: "new transaction, err: \(err.localizedDescription)")
      })
      self.oldTransactions = IHUtil.parseItems(data: data["oldTransactions"], type: IHReceiptTransaction.self, failure: { err, _ in
         IHError(IHErrors.unexpected, IHUnexpectedErrors.receipt_transation_parsing_failed, message: "old transaction, err: \(err.localizedDescription)")
      })
   }

}
