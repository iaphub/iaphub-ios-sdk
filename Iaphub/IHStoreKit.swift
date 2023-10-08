//
//  IHStoreKit.swift
//  Iaphub
//
//  Created by iaphub on 9/14/23.
//  Copyright © 2023 iaphub. All rights reserved.
//

import Foundation

protocol IHStoreKit {
   
   /**
    StoreKit version
    */
   var version: Int { get }
   
   /**
    Start IAP
    */
   func start(
      onReceipt: @escaping (IHReceipt, @escaping ((IHError?, Bool, IHReceiptTransaction?) -> Void)) -> Void,
      onBuyRequest: @escaping (String) -> Void
   )
   
   /**
    Stop IAP
    */
   func stop()
   
   /**
    Pause IAP
    */
   func pause()

   /**
    Resume IAP
    */
   func resume()

   /**
    Get products details
    */
   func getProductsDetails(_ skus: Set<String>, _ completion: @escaping (IHError?, [IHProductDetails]?) -> Void)
   
   /**
    Get product details
    */
   func getProductDetails(_ sku: String, _ completion: @escaping (IHError?, IHProductDetails?) -> Void)
   
   /**
    Buy product
    */
   func buy(_ sku: String, _ completion: @escaping (IHError?, IHReceiptTransaction?) -> Void)

   /**
    Restore transactions
    */
   func restore(_ completion: @escaping (IHError?) -> Void)
   
   /**
    Show manage subscriptions
    */
   func showManageSubscriptions(_ completion: @escaping (IHError?) -> Void)
   
   /**
    Present code redemption sheet
    */
   func presentCodeRedemptionSheet(_ completion: @escaping (IHError?) -> Void)
   
}
