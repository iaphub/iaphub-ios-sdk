//
//  IHProducts.swift
//  Iaphub
//
//  Created by iaphub on 12/12/22.
//  Copyright © 2022 iaphub. All rights reserved.
//

import Foundation

@objc public class IHProducts: NSObject {

   // Active products
   public var activeProducts: [IHActiveProduct]
   // Products for sale
   public var productsForSale: [IHProduct]

   init(activeProducts: [IHActiveProduct], productsForSale: [IHProduct]) {
      self.activeProducts = activeProducts
      self.productsForSale = productsForSale
   }

}
