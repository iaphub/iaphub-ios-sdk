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
      self.newTransactions = IHUtil.parseItems(data: data["newTransactions"], type: IHReceiptTransaction.self, allowNull: true, failure: { err, item in
         IHError(IHErrors.unexpected, IHUnexpectedErrors.receipt_transation_parsing_failed, message: "new transaction, err: \(err.localizedDescription)", params: ["item": item as Any])
      })
      self.oldTransactions = IHUtil.parseItems(data: data["oldTransactions"], type: IHReceiptTransaction.self, allowNull: true, failure: { err, item in
         IHError(IHErrors.unexpected, IHUnexpectedErrors.receipt_transation_parsing_failed, message: "old transaction, err: \(err.localizedDescription)", params: ["item": item as Any])
      })
   }
   
   public func findTransactionBySku(sku: String, filter: String?, useSubscriptionRenewalProductSku: Bool = false) -> IHReceiptTransaction? {
      var transactions: [IHReceiptTransaction] = []
      
      if (filter == "new" || filter == nil) {
         if let newTransactions = self.newTransactions {
            transactions.append(contentsOf: newTransactions)
         }
      }
      if (filter == "old" || filter == nil) {
         if let oldTransactions = self.oldTransactions {
            transactions.append(contentsOf: oldTransactions)
         }
      }
      
      return transactions.first { transaction in
         if (useSubscriptionRenewalProductSku) {
            return transaction.subscriptionRenewalProductSku == sku
         }
         return transaction.sku == sku
      }
   }

}
