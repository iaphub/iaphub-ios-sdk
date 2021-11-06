//
//  IHUser.swift
//  Iaphub
//
//  Created by iaphub on 8/27/20.
//  Copyright © 2020 iaphub. All rights reserved.
//

import Foundation

@objc public class IHUser: NSObject {

   // User id
   @objc public var id: String
   // Products for sale of the user
   @objc public var productsForSale: [IHProduct] = []
   // Active products of the user
   @objc public var activeProducts: [IHActiveProduct] = []
   // Pricings
   var pricings: [IHProductPricing] = []
   // Latest user fetch date
   var fetchDate: Date? = nil

   // SDK
   var sdk: Iaphub
   // API
   var api: IHAPI?
   // Fetch requests
   var fetchRequests: [((IHError?, Bool) -> Void)] = []
   // Indicates if the user is currently being fetched
   var isFetching: Bool = false
   // Indicates the user is posting tags
   var isPostingTags: Bool = false
   // Indicates the user is initialized
   var isInitialized: Bool = false
   // Indicates if the user needs to be fetched
   var needsFetch: Bool = false
   // Latest receipt post date
   var receiptPostDate: Date? = nil

   init(id: String?, sdk: Iaphub) {
      // If id defined use it
      if let userId = id {
         self.id = userId
      }
      // Otherwise generate anonymous id
      else {
         self.id = IHUser.getAnonymousId()
      }
      self.sdk = sdk
      super.init()
      self.api = IHAPI(user: self)
   }

   /**
    Get anonymous id
    */
   static func getAnonymousId() -> String {
      let key = "iaphub_anonymous_user_id"
      if let id = IHUtil.getFromKeychain(key) {
         return id
      }
      let id = IHConfig.anonymousUserPrefix + UUID().uuidString.lowercased()
      let result = IHUtil.saveToKeychain(key: key, value: id)
      
      if (result == false) {
         IHError(IHErrors.unexpected, message: "Saving anonymous id to keychain failed")
      }
      return id
   }
   
   /**
    Return if the user id is valid
    */
   static func isValidId(_ userId: String) -> Bool {
      // Check id length
      if (userId.count == 0 || userId.count > 100) {
         return false
      }
      // Check if id has valid format
      if (userId.range(of: #"^[a-zA-Z0-9-_]*$"#, options: .regularExpression) == nil) {
         return false
      }
      // Check for forbidden user ids
      if (["null", "none", "nil", "(null)"].contains(userId)) {
         return false
      }
      
      return true
   }

   /**
    Get dictionnary
   */
   func getDictionnary(productsOnly: Bool = false) -> [String: Any] {
      var dictionnary: [String: Any] = [
         "productsForSale": self.productsForSale.map({(product) in product.getDictionary()}),
         "activeProducts": self.activeProducts.map({(product) in product.getDictionary()})
      ]
      
      if (productsOnly == false) {
         dictionnary["id"] = self.id
         dictionnary["fetchDate"] = IHUtil.dateToIsoString(self.fetchDate)
         dictionnary["pricings"] = self.pricings.map({(pricing) in pricing.getDictionary()})
      }
      return dictionnary
   }
   
   /**
    Get cache data
   */
   func getCacheData() {
      let prefix = self.isAnonymous() ? "iaphub_user_a" : "iaphub_user"

      if let str = IHUtil.getFromKeychain("\(prefix)_\(self.sdk.appId)"), let data = str.data(using: .utf8)
      {
         do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
               return
            }
            if let id = json["id"] as? String, id == self.id {
               self.fetchDate = IHUtil.dateFromIsoString(json["fetchDate"] as? String)
               self.productsForSale = IHUtil.parseItems(data: json["productsForSale"], type: IHProduct.self)
               self.activeProducts = IHUtil.parseItems(data: json["activeProducts"], type: IHActiveProduct.self)
               self.pricings = IHUtil.parseItems(data: json["pricings"], type: IHProductPricing.self)
            }
         }
         catch {
            IHError(IHErrors.unexpected, message: "Get user cache data failed, \(error)")
         }
      }
   }
   
   /**
    Save cache data
   */
   func saveCacheData() {
      let json = self.getDictionnary()
      var data: Data? = nil

      if (JSONSerialization.isValidJSONObject(json) == false) {
         IHError(IHErrors.unexpected, message: "cannot save cache date, not a valid json object")
         return
      }
      
      do {
         data = try JSONSerialization.data(withJSONObject: json)
      }
      catch {
         IHError(IHErrors.unexpected, message: "cannot save cache date, json serialization failed")
         return
      }
      
      let str = String(data: data!, encoding: String.Encoding.utf8)
      let prefix = self.isAnonymous() ? "iaphub_user_a" : "iaphub_user"
      let result = IHUtil.saveToKeychain(key: "\(prefix)_\(self.sdk.appId)", value: str)
      
      if (result == false) {
         IHError(IHErrors.unexpected, message: "save to keychain failed")
      }
   }

   /**
    Return if it is an anonymous user
   */
   public func isAnonymous() -> Bool {
      return self.id.hasPrefix(IHConfig.anonymousUserPrefix)
   }

   /**
    Fetch user
   */
   public func fetch(_ completion: @escaping (IHError?, Bool) -> Void) {
      var isUpdated = false

      // Otherwise fetch user
      guard let api = self.api else {
         return completion(IHError(IHErrors.unexpected, message: "api not found"), isUpdated)
      }
      // Check if the user id is valid
      if (self.isAnonymous() == false && IHUser.isValidId(self.id) == false) {
         return completion(IHError(IHErrors.unexpected, message: "user id '\(self.id)' invalid"), isUpdated)
      }
      // Add completion to the requests
      self.fetchRequests.append(completion)
      // Stop here if the user is currently being fetched
      if (self.isFetching) {
         return
      }
      self.isFetching = true
      // Method to complete fetch request
      func completeFetchRequest(err: IHError?) {
         let fetchRequests = self.fetchRequests
         
         // Clean requests
         self.fetchRequests = []
         // Update properties
         self.isFetching = false
         // If there is no error
         if (err == nil) {
            // Update fetch date
            self.fetchDate = Date()
            // Save data
            self.saveCacheData()
         }
         // If we have a fetchDate mark the user as initialized
         if (self.fetchDate != nil && self.isInitialized == false) {
            self.isInitialized = true
         }
         // Call requests with the error
         fetchRequests.forEach({ (request) in
            request(err, isUpdated)
            // Only mark as updated for the first request
            if (isUpdated == true) {
               isUpdated = false
            }
         })
      }
      // If fetching for the first time, try getting data from cache
      if (self.fetchDate == nil) {
         self.getCacheData()
      }
      // Get data from API
      api.getUser({ (err, data) in
         guard let data = data else {
            return completeFetchRequest(err: err)
         }
         // Save products dictionnary
         let productsDictionnary = self.getDictionnary(productsOnly: true)
         // Update data
         self.update(data, {(err) in
            // Check error
            if (err != nil) {
               return completeFetchRequest(err: err)
            }
            // Check if the user has been updated
            let newProductsDictionnary = self.getDictionnary(productsOnly: true)
            if (self.isInitialized == true && NSDictionary(dictionary: newProductsDictionnary).isEqual(to: productsDictionnary) == false) {
               isUpdated = true
            }
            // Update pricing
            self.updatePricings() { (err) in
               // No need to throw an error if the pricing update fails, the system can work without it
               completeFetchRequest(err: nil)
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
      guard let api = self.api else {
         return completion(IHError(IHErrors.unexpected, message: "api not found"))
      }
      api.postPricing(["products": pricings.map({ (pricing) in pricing.getDictionary()})], {(err) in
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
    Update user with data
   */
   func update(_ data: [String: Any], _ completion: @escaping (IHError?) -> Void) {
      let productsForSale = IHUtil.parseItems(data: data["productsForSale"], type: IHProduct.self)
      let activeProducts = IHUtil.parseItems(data: data["activeProducts"], type: IHActiveProduct.self)
      let products = productsForSale + activeProducts
      let productSkus = Set(products.map({ (product) in product.sku}))

      self.sdk.storekit.getProducts(productSkus, { (err, products) in
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
         // Filter products for sale with no skProduct
         self.productsForSale = productsForSale.filter({ (product) in
            if (product.skProduct == nil) {
               IHError(IHErrors.unexpected, message: "Itunes did not return the product '\(product.sku)', the product has been filtered, if the sku is valid your Itunes account or sandbox environment is probably not configured properly (https://iaphub.com/docs/set-up-ios/configure-sandbox-testing)")
            }
            return product.skProduct != nil
         })
         // No need to filter active products
         self.activeProducts = activeProducts
         // Mark needsFetch as false
         self.needsFetch = false
         // Call completion
         completion(nil)
      })
   }
   
   /**
    Refresh user
   */
   func refresh(interval: Double, force: Bool = false, _ completion: @escaping (IHError?, Bool, Bool) -> Void) {
      // Check if we need to fetch the user
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
         self.fetch({ (err, isUpdated) in
            // Check if there is an error
            if (err != nil) {
               // Return an error if the user has never been fetched
               if (self.fetchDate == nil) {
                  completion(err, false, false)
               }
               // Otherwise check if there is an expired subscription in the active products
               else {
                  let expiredSubscription = self.activeProducts.first(where: { $0.expirationDate != nil && $0.expirationDate! < Date()})
                  // If we have an expired subscription, return an error
                  if (expiredSubscription != nil) {
                     completion(err, false, false)
                  }
                  // Otherwise return no error
                  else {
                     completion(nil, false, false)
                  }
               }
            }
            // Otherwise it's a success
            else {
               completion(nil, true, isUpdated)
            }
         })
      }
      // Otherwise no need to fetch the user
      else {
         completion(nil, false, false)
      }
   }
   
   /**
    Refresh user with a shorter interval if the user has an active subscription (otherwise every 24 hours by default)
   */
   func refresh(_ completion: @escaping (IHError?, Bool, Bool) -> Void) {
      // Refresh user
      self.refresh(interval: 60 * 60 * 24, { (err, isFetched, isUpdated) in
         // Check if there is an error
         guard err == nil else {
            return completion(err, isFetched, isUpdated)
         }
         // If the user has not been fetched, look if there is active subscriptions
         if (isFetched == false) {
            let subscriptions = self.activeProducts.filter { (product) in
               return product.type == "renewable_subscription" || product.type == "subscription";
            }
            // If we have active renewable subscriptions, refresh every minute
            if (subscriptions.count > 0) {
               self.refresh(interval: 60, completion)
            }
            // Otherwise call the completion
            else {
               completion(nil, isFetched, isUpdated)
            }
         }
         // Otherwise call the completion
         else {
            completion(nil, isFetched, isUpdated)
         }
      })
   }
   
   /**
    Get active products
   */
   func getActiveProducts(includeSubscriptionStates: [String] = []) -> [IHActiveProduct] {
      let subscriptionStates = ["active", "grace_period"] + includeSubscriptionStates
      let activeProducts = self.activeProducts.filter({ (activeProduct) -> Bool in
         // Return product if it has no subscription state
         guard let subscriptionState = activeProduct.subscriptionState else {
            return true
         }
         // Otherwise return product only if the state is in the list
         return subscriptionStates.contains(subscriptionState)
      })
      
      return activeProducts
   }
   
   /**
    Set tags
   */
   func setTags(_ tags: Dictionary<String, String>, _ completion: @escaping (IHError?) -> Void) {
      guard let api = self.api else {
         return completion(IHError(IHErrors.unexpected, message: "api not found"))
      }
      if (self.isPostingTags == true) {
         return completion(IHError(IHErrors.user_tags_processing))
      }
      self.isPostingTags = true
      api.postTags(tags, { (err) in
         self.isPostingTags = false
         // Check for error
         guard err == nil else {
            return completion(err)
         }
         // Reset cache
         self.resetCache()
         // Call completion
         completion(nil)
      })
   }
   
   /**
    Reset user
   */
   func reset() {
      self.productsForSale = []
      self.activeProducts = []
      self.pricings = []
      self.fetchDate = nil
      self.receiptPostDate = nil
      self.needsFetch = false
      self.isInitialized = false
   }

   /**
    Login
   */
   func login(_ userId: String, _ completion: @escaping (IHError?) -> Void) {
      // Check that id is valid
      if (!IHUser.isValidId(userId)) {
         return completion(IHError(IHErrors.unexpected, message: "user id invalid"))
      }
      // Check that the id isn't the same
      if (self.id == userId) {
         return completion(nil)
      }
      // Detect if we should call the API to update the id
      let shouldCallApi = self.isAnonymous() && self.fetchDate != nil
      // Update id
      self.id = userId
      // Reset user
      self.reset()
      // Call API if necessary
      if (shouldCallApi) {
         guard let api = self.api else {
            return completion(IHError(IHErrors.unexpected, message: "api not found"))
         }
         api.login(userId, { (err) in
            // Check for error
            guard err == nil else {
               // Ignore error if user not found or already authenticated
               if (["user_not_found", "user_authenticated"].contains(err?.code)) {
                  return completion(nil)
               }
               return completion(err)
            }
            // Call completion
            completion(nil)
         })
      }
      // Otherwise call completion
      else {
         completion(nil)
      }
   }
   
   /**
    Logout
   */
   func logout() {
      // Cannot logout an anonymous user
      if (self.isAnonymous()) {
         return
      }
      // Update user id
      self.id = IHUser.getAnonymousId()
      // Reset user
      self.reset()
   }
   
   /**
    Post receipt
   */
   func postReceipt(_ receipt: IHReceipt, _ completion: @escaping (IHError?, IHReceiptResponse?) -> Void) {
      guard let api = self.api else {
         return completion(IHError(IHErrors.unexpected, message: "api not found"), nil)
      }
      api.postReceipt(receipt.getDictionary(), { (err, data) in
         // Check for error
         guard err == nil, let data = data else {
            return completion(err ?? IHError(IHErrors.unexpected, message: "post receipt did not return any data"), nil)
         }
         // Update receipt post date
         self.receiptPostDate = Date()
         // Parse and return receipt response
         completion(nil, IHReceiptResponse(data))
      })
   }

   /**
    Reset cache
   */
   func resetCache() {
      self.needsFetch = true;
   }
   
}
