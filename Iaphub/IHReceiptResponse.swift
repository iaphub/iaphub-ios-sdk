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
      self.newTransactions = self.parseTransactions(data["newTransactions"])
      self.oldTransactions = self.parseTransactions(data["oldTransactions"])
   }
   
   /**
    Parse transactions
   */
   private func parseTransactions(_ data: Any?) -> [IHReceiptTransaction] {
      let transactionsDictionary = (data as? [Dictionary<String, Any>]) ?? [Dictionary<String, Any>]()
      var transactions = [IHReceiptTransaction]()

      for item in transactionsDictionary {
         do {
            let transaction = try IHReceiptTransaction(item)
            transactions.append(transaction)
         } catch {
            // If the product cannot be parsed, ignore it
         }
      }
      return transactions
   }

}
