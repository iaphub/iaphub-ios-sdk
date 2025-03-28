//
//  IHProduct.swift
//  Iaphub
//
//  Created by iaphub on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation
import StoreKit

@objc public class IHProduct: IHProductDetails {

   // Product id
   @objc public var id: String
   // Product type
   @objc public var type: String
   // Group
   @objc public var group: String?
   // Group name
   @objc public var groupName: String?
   // Metadata
   @objc public var metadata: [String: String]
   // Alias
   @objc public var alias: String?

   // Details source
   @objc public var details: IHProductDetails?

   
   required init(_ data: Dictionary<String, Any>) throws {
      // Checking mandatory properties
      guard let id = data["id"] as? String, let type = data["type"] as? String else {
         throw IHError(IHErrors.unexpected, IHUnexpectedErrors.product_parsing_failed, message: "in Product class", params: data);
      }
      // Assign properties
      self.id = id;
      self.type = type;
      self.group = data["group"] as? String
      self.groupName = data["groupName"] as? String
      self.metadata = data["metadata"] as? [String: String] ?? [:]
      self.alias = data["alias"] as? String
      // Call super init
      try super.init(data)
   }
   
   func filterIntroPhases(_ subscriptionPeriodType: String) {
      var isValid = false

      self.subscriptionIntroPhases = self.subscriptionIntroPhases?.filter({ introPhase in
         if (!isValid && introPhase.type == subscriptionPeriodType) {
            isValid = true
         }
         return isValid
      })
   }
   
   public override func getDictionary() -> [String: Any] {
      var data = super.getDictionary()
      
      let extraData = [
         "id": self.id as Any,
         "type": self.type as Any,
         "group": self.group as Any,
         "groupName": self.groupName as Any,
         "metadata": self.metadata as Any,
         "alias": self.alias as Any
      ]
      
      data.merge(extraData) { (current, _) in current }
      return data
   }
   
   public override func setDetails(_ details: IHProductDetails) {
      super.setDetails(details)
      self.details = details
   }

}
