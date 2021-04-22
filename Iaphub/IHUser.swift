//
//  IHUser.swift
//  Iaphub
//
//  Created by iaphub on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation

class IHUser {

   // User id
   var id: String
   // Products for sale of the user
   var productsForSale: [IHProduct] = []
   // Active products of the user
   var activeProducts: [IHActiveProduct] = []

   // Pricings
   var pricings: [IHProductPricing] = []
   // Latest user fetch date
   var fetchDate: Date? = nil
   // Fetch requests
   var fetchRequests: [((IHError?) -> Void)] = []
   // Indicates if the user is currently being fetched
   var isFetching: Bool = false
   // Indicates if the user needs to be fetched
   var needsFetch: Bool = false
   // Latest receipt post date
   var receiptPostDate: Date? = nil
   // API
   var api: IHAPI
   // SDK
   var sdk: Iaphub?

   init(_ id: String) {
      self.id = id
      self.api = IHAPI()
   }

   /**
    Configure
   */
   public func configure(sdk: Iaphub) {
      self.sdk = sdk
      self.api.configure(user: self)
   }

   /**
    Fetch user
   */
   public func fetch(_ completion: @escaping (IHError?) -> Void) {
      // Add completion to the requests
      self.fetchRequests.append(completion)
      // Stop here if the user is currently being fetched
      if (self.isFetching) {
         return
      }
      // Otherwise fetch user
      self.isFetching = true
      self.api.getUser({ (err, data) in
         guard let data = data else {
            // Call requests with the error
            self.isFetching = false
            self.fetchRequests.forEach({ (request) in
               request(err)
            })
            self.fetchRequests = []
            return
         }
         // Update data
         self.update(data, {(err) in
            // Check error
            if (err != nil) {
               return completion(err)
            }
            // Update pricing
            self.updatePricings() { (err) in
               // No need to throw an error if the pricing update fails, a log should be enough
               if (err != nil) {
                  print("Error: Updating pricings failed (\(err!.code))");
               }
               // Update fetch date
               self.fetchDate = Date()
               // Call requests
               self.isFetching = false
               self.fetchRequests.forEach({ (request) in
                  request(nil)
               })
               self.fetchRequests = []
            }
         })
      })
   }

   /**
    Update pricings
   */
   private func updatePricings(_ completion: @escaping (IHError?) -> Void) {
      // Convert the products to an array of product pricings
      let products = self.productsForSale + self.activeProducts
      let pricings = products
      .map({ (product) -> IHProductPricing? in
         if (product.price != 0 && product.currency != nil) {
            return IHProductPricing(id: product.id, price: product.price, currency: product.currency!)
         }
         return nil;
      })
      .compactMap ({ $0 })
      // Compare latest pricing with the previous one
      let samePricings = pricings.filter { (newPricing) -> Bool in
         // Look if we already have the pricing in memory
         let itemFound = self.pricings.first { (oldPricing) -> Bool in
            if (oldPricing.id == newPricing.id && oldPricing.price == newPricing.price && oldPricing.currency == newPricing.currency) {
               return true;
            }
            return false;
         }
         
         return itemFound != nil ? true : false;
      }
      // No need to send a request if the array of pricings is empty
      if (pricings.count == 0) {
         return completion(nil)
      }
      // No need to send a request if the pricing is the same
      if (samePricings.count == pricings.count) {
         return completion(nil)
      }
      // Post pricing
      self.api.postPricing(["products": pricings.map({ (pricing) in pricing.dictionary})], {(err) in
         // Check error
         guard err == nil else {
            return completion(err)
         }
         // Update pricings
         self.pricings = pricings
         // Call completion
         completion(nil)
      })
   }
   
   /**
    Parse products
   */
   private func parseProducts<T: IHProduct>(data: Any?, type: T.Type) -> [T] {
      let productsDictionary = (data as? [Dictionary<String, Any>]) ?? [Dictionary<String, Any>]()
      var products = [T]()

      for item in productsDictionary {
         do {
            let product = try type.init(item)
            products.append(product)
         } catch {
            // If the product cannot be parsed, ignore it
            print("Error: Product parsing failed, product ignored");
         }
      }
      return products
   }
   
   /**
    Update user with data
   */
   private func update(_ data: [String: Any], _ completion: @escaping (IHError?) -> Void) {
      let productsForSale = self.parseProducts(data: data["productsForSale"], type: IHProduct.self)
      let activeProducts = self.parseProducts(data: data["activeProducts"], type: IHActiveProduct.self)
      let products = productsForSale + activeProducts
      let productSkus = Set(products.map({ (product) in product.sku}))

      guard let sdk = self.sdk else {
         return completion(IHError(IHErrors.unknown, message: "user not configured"))
      }
      sdk.iap.getProducts(productSkus, { (err, products) in
         // Check for error
         guard err == nil else {
            return completion(err)
         }
         // Otherwise assign data to the product
         products?.forEach({ (skProduct) in
            // Try to find the product in the products for sale
            var product = productsForSale.first(where: {$0.sku == skProduct.productIdentifier})
            // Otherwise try to find the product in the active products
            if (product == nil) {
               product = activeProducts.first(where: {$0.sku == skProduct.productIdentifier})
            }
            // If the product has been found set skProduct
            product?.setSKProduct(skProduct)
         })
         // Assign new products and filter products with no skProduct
         self.productsForSale = productsForSale.filter({ (product) in
            if (product.skProduct == nil) {
               print("Product sku '\(product.sku)' not returned by StoreKit, product ignored")
            }
            return product.skProduct != nil
         })
         self.activeProducts = activeProducts.filter({ (product) in
            if (product.skProduct == nil) {
               print("Product sku '\(product.sku)' not returned by StoreKit, product ignored")
            }
            return product.skProduct != nil
         })
         // Mark needsFetch as false
         self.needsFetch = false
         // Call completion
         completion(nil)
      })
   }
   
   /**
    Refresh user
   */
   public func refresh(interval: Double = 60 * 60 * 24, force: Bool = false, _ completion: @escaping (IHError?, Bool) -> Void) {
      if (
            // Refresh forced
            force ||
            // User hasn't been fetched yet
            self.fetchDate == nil ||
            // User marked as outdated
            self.needsFetch == true ||
            // User hasn't been refreshed since the interval
            (Date(timeIntervalSince1970: self.fetchDate!.timeIntervalSince1970 + interval) < Date()) ||
            // Receit post date more recent than the user fetch date
            (self.receiptPostDate != nil && self.receiptPostDate! > self.fetchDate!)
      ) {
         self.fetch({ (err) in
            // Return an error only if the user has never been fetched
            if (err != nil && self.fetchDate == nil) {
               completion(err, false)
            } else {
               completion(nil, err == nil ? true : false)
            }
         })
      } else {
         completion(nil, false)
      }
   }
   
   /**
    Set tags
   */
   public func setTags(_ tags: Dictionary<String, String>, _ completion: @escaping (IHError?) -> Void) {
      self.api.setUserTag(tags, { (err) in
         // Check for error
         guard err == nil else {
            return completion(err)
         }
         // Mark as outdated
         self.needsFetch = true
         // Call completion
         completion(nil)
      })
   }
   
   /**
    Post receipt
   */
   public func postReceipt(_ receipt: IHReceipt, _ completion: @escaping (IHError?, IHReceiptResponse?) -> Void) {
      self.api.postReceipt(receipt.dictionary, { (err, data) in
         // Check for error
         guard err == nil, let data = data else {
            return completion(err ?? IHError(IHErrors.unknown), nil)
         }
         // Update receipt post date
         self.receiptPostDate = Date()
         // Parse and return receipt response
         completion(nil, IHReceiptResponse(data))
      })
   }
   
}
