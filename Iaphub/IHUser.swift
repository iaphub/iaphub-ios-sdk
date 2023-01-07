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
   // Iaphub user id
   @objc public var iaphubId: String? = nil
   // Products for sale of the user
   @objc public var productsForSale: [IHProduct] = []
   // Active products of the user
   @objc public var activeProducts: [IHActiveProduct] = []
   // Filtered products for sale
   var filteredProductsForSale: [IHProduct] = []
   // Pricings
   var pricings: [IHProductPricing] = []
   // Latest user fetch date
   var fetchDate: Date? = nil

   // SDK
   var sdk: Iaphub
   // API
   var api: IHAPI?
   // Event triggered when the user is updated
   var onUserUpdate: (() -> Void)?
   // Event triggered on a deferred purchase
   var onDeferredPurchase: ((IHReceiptTransaction) -> Void)? = nil
   // Restored deferred purchases (recorded during restore instead of calling onDeferredPurchase event)
   var restoredDeferredPurchases: [IHReceiptTransaction] = []
   // Fetch requests
   var fetchRequests: [((IHError?, Bool) -> Void)] = []
   // Indicates if the user is currently being fetched
   var isFetching: Bool = false
   // Indicates the user is posting tags
   var isPostingTags: Bool = false
   // Indicates the user is restoring purchases
   var isRestoring: Bool = false
   // Indicates the user is initialized
   var isInitialized: Bool = false
   // Indicates if the user needs to be fetched
   var needsFetch: Bool = false
   // Latest receipt post date
   var receiptPostDate: Date? = nil
   // Latest date an update has been made
   var updateDate: Date? = nil
   // If the deferred purchase events should be consumed
   var enableDeferredPurchaseListener: Bool = true
   // Last error returned when fetching the products details
   var productsDetailsError: IHError? = nil


   init(id: String?, sdk: Iaphub, enableDeferredPurchaseListener: Bool = true, onUserUpdate: (() -> Void)?, onDeferredPurchase: ((IHReceiptTransaction) -> Void)?) {
      var hasAnonymousIdSaveFailed = false
      var anonymousIdSaveKeychainError: OSStatus? = nil
      
      // If id defined use it
      if let userId = id {
         self.id = userId
      }
      // Otherwise generate anonymous id
      else {
         self.id = IHUser.getAnonymousId(onSaveFailure: { keychainErr in
            hasAnonymousIdSaveFailed = true
            anonymousIdSaveKeychainError = keychainErr
         })
      }
      self.sdk = sdk
      self.enableDeferredPurchaseListener = enableDeferredPurchaseListener
      self.onUserUpdate = onUserUpdate
      self.onDeferredPurchase = onDeferredPurchase
      super.init()
      self.api = IHAPI(user: self)
      // Handle anonymous id save failure
      if (hasAnonymousIdSaveFailed) {
         self.onAnonymousIdSaveFailure(["keychainErr": anonymousIdSaveKeychainError, "method": "init"])
      }
   }

   /**
    Get anonymous id
    */
   static func getAnonymousId(onSaveFailure: ((OSStatus?) -> Void)? = nil) -> String {
      let key = "iaphub_anonymous_user_id"
      // Search for id in keychain
      if let id = IHUtil.getFromKeychain(key) {
         return id
      }
      // Search for id in localstorage
      if let id = IHUtil.getFromLocalstorage(key) {
         return id
      }
      // Otherwise generate new anonymous id
      let id = IHConfig.anonymousUserPrefix + UUID().uuidString.lowercased()
      // Save it in keychain and localstorage
      let keychainErr = IHUtil.saveToKeychain(key: key, value: id)
      IHUtil.saveToLocalstorage(key: key, value: id)
      // Try to get the values from keychain and localstorage
      let keychainId = IHUtil.getFromKeychain(key)
      let localstorageId = IHUtil.getFromLocalstorage(key)
      // If they are both missing, trigger failure callback
      if (keychainId == nil && localstorageId == nil) {
         onSaveFailure?(keychainErr)
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
    Triggered when the anonymous id save failed
    */
   func onAnonymousIdSaveFailure(_ params: [String: Any?]) {
      IHError(IHErrors.unexpected, IHUnexpectedErrors.save_cache_anonymous_id_failed, params: params as Dictionary<String, Any>)
   }
   
   /**
    Buy product
    */
   func buy(sku: String, crossPlatformConflict: Bool = true, _ completion: @escaping (IHError?, IHReceiptTransaction?) -> Void) {
      // Refresh user
      self.refresh({ (err, isFetched, isUpdated) in
         // Check if there is an error
         guard err == nil else {
            return completion(err, nil)
         }
         // Get product
         self.sdk.storekit.getSkProduct(sku) { err, product in
            // Check if there is an error
            guard let product = product else {
               return completion(err, nil)
            }
            // Try to get the product from the products for sale
            let productForSale = self.productsForSale.first(where: {$0.sku == sku})
            // Detect if the product has a subscription period (it means it is a subscription)
            var hasSubscriptionPeriod = false
            if #available(iOS 11.2, *) {
               hasSubscriptionPeriod = (product.subscriptionPeriod != nil) ? true : false
            }
            // Check if the product is a subscription by looking the type or the subscriptionPeriod property as a fallback
            if (productForSale?.type.contains("subscription") == true || hasSubscriptionPeriod == true) {
               // Check cross platform conflicts
               let conflictedSubscription = self.activeProducts.first(where: {$0.type.contains("subscription") && $0.platform != "ios"})
               if (crossPlatformConflict && conflictedSubscription != nil) {
                  return completion(IHError(IHErrors.cross_platform_conflict, message: "platform: \(conflictedSubscription?.platform ?? "")"), nil)
               }
               // Check if the product is already going to be replaced on next renewal date
               let replacedProduct = self.activeProducts.first(where: {$0.subscriptionRenewalProductSku == sku && $0.subscriptionState == "active"})
               if (replacedProduct != nil) {
                  return completion(IHError(IHErrors.product_change_next_renewal, params: ["sku": sku]), nil)
               }
            }
            // Launch purchase
            self.sdk.storekit.buy(product, completion)
         }
      })
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
         dictionnary["cacheVersion"] = IHConfig.cacheVersion
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
            if let id = json["id"] as? String, id == self.id,  let cacheVersion = json["cacheVersion"] as? String, cacheVersion == IHConfig.cacheVersion {
               self.fetchDate = IHUtil.dateFromIsoString(json["fetchDate"], failure: { err in
                  IHError(IHErrors.unexpected, IHUnexpectedErrors.date_parsing_failed, message: "issue on fetch date, \(err.localizedDescription)", params: ["fetchDate": json["fetchDate"] as Any])
               })
               self.productsForSale = IHUtil.parseItems(data: json["productsForSale"], type: IHProduct.self, failure: { err, item in
                  IHError(IHErrors.unexpected, IHUnexpectedErrors.get_cache_data_item_parsing_failed, message: "issue on product for sale, \(err.localizedDescription)", params: ["item": item as Any])
               })
               self.activeProducts = IHUtil.parseItems(data: json["activeProducts"], type: IHActiveProduct.self, failure: { err, item in
                  IHError(IHErrors.unexpected, IHUnexpectedErrors.get_cache_data_item_parsing_failed, message: "issue on active product, \(err.localizedDescription)", params: ["item": item as Any])
               })
               self.pricings = IHUtil.parseItems(data: json["pricings"], type: IHProductPricing.self, failure: { err, item in
                  IHError(IHErrors.unexpected, IHUnexpectedErrors.get_cache_data_item_parsing_failed, message: "issue on pricing, \(err.localizedDescription)", params: ["item": item as Any])
               })
            }
         }
         catch {
            IHError(IHErrors.unexpected, IHUnexpectedErrors.get_cache_data_json_parsing_failed, message: error.localizedDescription)
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
         IHError(IHErrors.unexpected, IHUnexpectedErrors.save_cache_data_json_invalid)
         return
      }
      
      do {
         data = try JSONSerialization.data(withJSONObject: json)
      }
      catch {
         IHError(IHErrors.unexpected, IHUnexpectedErrors.save_cache_json_serialization_failed)
         return
      }
      
      let str = String(data: data!, encoding: String.Encoding.utf8)
      let prefix = self.isAnonymous() ? "iaphub_user_a" : "iaphub_user"
      _ = IHUtil.saveToKeychain(key: "\(prefix)_\(self.sdk.appId)", value: str)
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
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.api_not_found, message: "fetch failed"), isUpdated)
      }
      // Check if the user id is valid
      if (self.isAnonymous() == false && IHUser.isValidId(self.id) == false) {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.user_id_invalid, message: "fetch failed, (user id: \(self.id))", params: ["userId": self.id]), isUpdated)
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
               self.onUserUpdate?()
            }
         })
      }
      // If fetching for the first time, try getting data from cache
      if (self.fetchDate == nil) {
         self.getCacheData()
      }
      // Get data from API
      api.getUser({ (err, data) in
         var data = data
         if (err != nil) {
            // Clear products if the platform is disabled
            if let err = err, err.code == "server_error" && err.subcode == "platform_disabled" {
               data = ["productsForSale": [], "activeProducts": []]
            }
            // Otherwise return an error
            else {
               return completeFetchRequest(err: err)
            }
         }
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
         if let currency = product.currency, product.price != 0 {
            return IHProductPricing(id: product.id, price: product.price, currency: currency, introPrice: product.subscriptionIntroPhases?.first?.price)
         }
         return nil;
      })
      .compactMap ({ $0 })
      // Compare latest pricing with the previous one
      let samePricings = pricings.filter { (newPricing) -> Bool in
         // Look if we already have the pricing in memory
         let itemFound = self.pricings.first { (oldPricing) -> Bool in
            if (oldPricing.id == newPricing.id &&
                oldPricing.price == newPricing.price &&
                oldPricing.currency == newPricing.currency &&
                oldPricing.introPrice == newPricing.introPrice) {
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
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.api_not_found))
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
      let productsForSale = IHUtil.parseItems(data: data["productsForSale"], type: IHProduct.self) { err, item in
         IHError(IHErrors.unexpected, IHUnexpectedErrors.update_item_parsing_failed, message: "product for sale, " + err.localizedDescription, params: ["item": item as Any])
      }
      let activeProducts = IHUtil.parseItems(data: data["activeProducts"], type: IHActiveProduct.self) { err, item in
         IHError(IHErrors.unexpected, IHUnexpectedErrors.update_item_parsing_failed, message: "active product, " + err.localizedDescription, params: ["item": item as Any])
      }
      let events = IHUtil.parseItems(data: data["events"], type: IHEvent.self, allowNull: true) { err, item in
         IHError(IHErrors.unexpected, IHUnexpectedErrors.update_item_parsing_failed, message: "event, " + err.localizedDescription, params: ["item": item as Any])
      }

      
      let eventTransactions = events.map({ (event) in event.transaction})
      let products: [IHProduct] = productsForSale + activeProducts + eventTransactions

      self.updateProductsDetails(products, {
         let oldFilteredProducts = self.filteredProductsForSale
         
         // Filter products for sale
         self.productsForSale = productsForSale.filter({ product in product.details != nil})
         self.filteredProductsForSale = productsForSale.filter({ product in product.details == nil})
         // Check filtered products
         self.filteredProductsForSale.forEach { product in
            let oldFilteredProduct = oldFilteredProducts.first(where: {item in item.sku == product.sku})
            // Trigger log only if it is a new filtered product
            if (oldFilteredProduct == nil) {
               IHError(IHErrors.unexpected, IHUnexpectedErrors.product_missing_from_store, message: "(sku: \(product.sku)", params: ["sku": product.sku])
            }
         }
         // No need to filter active products
         self.activeProducts = activeProducts
         // Update iaphub id
         self.iaphubId = data["id"] as? String
         // Mark needsFetch as false
         self.needsFetch = false
         // Process events
         self.processEvents(events)
         // Call completion
         completion(nil)
      })
   }
   
   /**
    Update products details
   */
   func updateProductsDetails(_ products: [IHProduct], _ completion: @escaping () -> Void) {
      // Extract sku and filter empty sku (could happen with an active product from another platform)
      let productSkus = Set(
         // Extract product sku
         products.map({ (product) in product.sku})
         // Filter empty sku (could happen with an active product from another platform)
         .filter({(sku) in sku != ""})
      )
      
      // Get products details
      self.sdk.storekit.getProductsDetails(productSkus, { (err, productsDetails) in
         // Note: We're not calling with completion handler with the error of getProductsDetails
         // We need to complete the update even though an error such as 'billing_unavailable' is returned
         // When there is an error getProductsDetails can still return products details (they might be in cache)
         // So instead we're saving the error
         self.productsDetailsError = err
         // Assign details to the products
         productsDetails?.forEach({ productDetail in
            products
            .filter { (product) in product.sku == productDetail.sku}
            .forEach { product in
               product.setDetails(productDetail)
            }
         })
         // Call completion
         completion()
      })
   }
   
   /**
    Update filtered products
   */
   func updateFilteredProducts(_ completion: @escaping (Bool) -> Void) {
      // Update products details
      self.updateProductsDetails(self.filteredProductsForSale) {
         // Detect recovered products
         let recoveredProducts = self.filteredProductsForSale.filter({product in product.details != nil})
         // Add to list of products for sale
         self.productsForSale = self.productsForSale + recoveredProducts
         // Update filtered products for sale
         self.filteredProductsForSale = self.filteredProductsForSale.filter({product in product.details == nil})
         // If we recovered products
         if (!recoveredProducts.isEmpty) {
            // Trigger onUserUpdate
            self.onUserUpdate?()
            // Update pricings
            self.updatePricings { _ in
               // Call completion
               completion(true)
            }
         }
         // Otherwise just call the completion
         else {
            completion(false)
         }
      }
   }
   
   /**
    Process events
   */
   func processEvents(_ events: [IHEvent]) {
      events.forEach { event in
         if (event.type == "purchase" && event.tags.contains("deferred")) {
            if (self.isRestoring) {
               self.restoredDeferredPurchases.append(event.transaction)
            }
            else {
               self.onDeferredPurchase?(event.transaction)
            }
         }
      }
   }
   
   /**
    Refresh user
   */
   func refresh(interval: Double, force: Bool = false, _ completion: ((IHError?, Bool, Bool) -> Void)? = nil) {
      var shouldFetch = false
      
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
         shouldFetch = true
      }
      // Update products details if we had an error or filtered products
      if (!shouldFetch && (self.productsDetailsError != nil || !self.filteredProductsForSale.isEmpty)) {
         self.updateFilteredProducts { isUpdated in
            completion?(nil, false, isUpdated)
         }
         return
      }
      // Otherwise no need to fetch the user
      if (!shouldFetch) {
         completion?(nil, false, false)
         return
      }
      // Otherwise fetch user
      self.fetch({ (err, isUpdated) in
         // Check if there is an error
         if (err != nil) {
            // Return an error if the user has never been fetched
            if (self.fetchDate == nil) {
               completion?(err, false, false)
            }
            // Otherwise check if there is an expired subscription in the active products
            else {
               let expiredSubscription = self.activeProducts.first(where: { $0.expirationDate != nil && $0.expirationDate! < Date()})
               // If we have an expired subscription, return an error
               if (expiredSubscription != nil) {
                  completion?(err, false, false)
               }
               // Otherwise return no error
               else {
                  completion?(nil, false, false)
               }
            }
         }
         // Otherwise it's a success
         else {
            completion?(nil, true, isUpdated)
         }
      })
   }
   
   /**
    Refresh user with a shorter interval if the user has an active subscription (otherwise every 24 hours by default)
   */
   func refresh(_ completion: ((IHError?, Bool, Bool) -> Void)? = nil) {
      // Refresh user
      self.refresh(interval: 60 * 60 * 24, { (err, isFetched, isUpdated) in
         // Check if there is an error
         guard err == nil else {
            completion?(err, isFetched, isUpdated)
            return
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
               completion?(nil, isFetched, isUpdated)
            }
         }
         // Otherwise call the completion
         else {
            completion?(nil, isFetched, isUpdated)
         }
      })
   }
   
   /**
    Get active products
   */
   func getActiveProducts(includeSubscriptionStates: [String] = [], _ completion: @escaping (IHError?, [IHActiveProduct]?) -> Void) {
      // Refresh user
      self.refresh({ (err, _, _) in
         // Check if there is an error
         guard err == nil else {
            return completion(err, nil)
         }
         // Get active products
         let subscriptionStates = ["active", "grace_period"] + includeSubscriptionStates
         let activeProducts = self.activeProducts.filter({ (activeProduct) -> Bool in
            // Return product if it has no subscription state
            guard let subscriptionState = activeProduct.subscriptionState else {
               return true
            }
            // Otherwise return product only if the state is in the list
            return subscriptionStates.contains(subscriptionState)
         })
         // Return active products
         completion(err, activeProducts)
      })
   }
   
   /**
    Get products for sale
    */
   func getProductsForSale(_ completion: @escaping (IHError?, [IHProduct]?) -> Void) {
      // Refresh user with an interval of 24 hours
      self.refresh(interval: 60 * 60 * 24, { (err, _, _) in
         // Check if there is an error
         guard err == nil else {
            return completion(err, nil)
         }
         // Otherwise return the products
         completion(nil, self.productsForSale)
      })
   }
   
   /**
    Get products (active and for sale)
    */
   func getProducts(includeSubscriptionStates: [String] = [], _ completion: @escaping (IHError?, IHProducts?) -> Void) {
      // Get active products
      self.getActiveProducts(includeSubscriptionStates: includeSubscriptionStates) { err, activeProducts in
         // Check if there is an error
         guard err == nil, let activeProducts = activeProducts else {
            return completion(err, nil)
         }
         // Otherwise return the products
         completion(nil, IHProducts(activeProducts: activeProducts, productsForSale: self.productsForSale))
      }
   }
   
   /**
    Get billing status
    */
   func getBillingStatus() -> IHBillingStatus {
      let filteredProductIds = self.filteredProductsForSale.map { $0.sku }
      
      return IHBillingStatus(error: self.productsDetailsError, filteredProductIds: filteredProductIds)
   }

   /**
    Set tags
   */
   func setTags(_ tags: Dictionary<String, String>, _ completion: @escaping (IHError?) -> Void) {
      guard let api = self.api else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.api_not_found, message: "set tags failed"))
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
         // Update updateDate
         self.updateDate = Date()
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
      self.updateDate = nil
      self.needsFetch = false
      self.isInitialized = false
   }

   /**
    Login
   */
   func login(_ userId: String, _ completion: @escaping (IHError?) -> Void) {
      // Check that id is valid
      if (!IHUser.isValidId(userId)) {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.user_id_invalid, message: "login failed", params: ["userId": userId]))
      }
      // Check that the id isn't the same
      if (self.id == userId) {
         return completion(nil)
      }
      // Detect if we should call the API to update the id
      let shouldCallApi = self.isAnonymous()
      let currentUserId = self.id
      // Update id
      self.id = userId
      // Reset user
      self.reset()
      // Call API if necessary
      if (shouldCallApi) {
         guard let api = self.api else {
            return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.api_not_found, message: "login failed"))
         }
         api.login(currentUserId: currentUserId, newUserId: userId, { (_) in
            // Ignore error and call completion (if the login couldn't be called for any reason and the purchases were not transferred the user can still do a restore)
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
      self.id = IHUser.getAnonymousId(onSaveFailure: { keychainErr in
         self.onAnonymousIdSaveFailure(["keychainErr": keychainErr, "method": "logout"])
      })
      // Reset user
      self.reset()
   }
   
   /**
    Post receipt
   */
   func postReceipt(_ receipt: IHReceipt, _ completion: @escaping (IHError?, IHReceiptResponse?) -> Void) {
      guard let api = self.api else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.api_not_found, message: "post receipt failed"), nil)
      }
      api.postReceipt(receipt.getDictionary(), { (err, data) in
         // Check for error
         guard err == nil, let data = data else {
            return completion(err ?? IHError(IHErrors.unexpected, IHUnexpectedErrors.post_receipt_data_missing), nil)
         }
         // Update receipt post date
         self.receiptPostDate = Date()
         // Update updateDate
         self.updateDate = Date()
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
   
   /**
    Restore
   */
   func restore(_ completion: @escaping (IHError?, IHRestoreResponse?) -> Void) {
      // Reinitialize restoredDeferredPurchases array
      self.restoredDeferredPurchases = []
      // Mark as restoring
      self.isRestoring = true
      // Save old active products
      let oldActiveProducts = self.activeProducts
      // Launch restore
      self.sdk.storekit.restore({ (err) in
         // Update updateDate
         self.updateDate = Date()
         // Refresh user
         self.refresh(interval: 0, force: true, { _, _, _ in
            let newPurchases = self.restoredDeferredPurchases
            let transferredActiveProducts = self.activeProducts.filter { newActiveProduct in
               let isInOldActiveProducts = (oldActiveProducts.first { oldActiveProduct in oldActiveProduct.sku == newActiveProduct.sku}) != nil
               let isInNewPurchases = (newPurchases.first { newPurchase in newPurchase.sku == newActiveProduct.sku}) != nil
               
               return !isInOldActiveProducts && !isInNewPurchases
            }
            // Call completion
            if (err == nil || (newPurchases.count > 0 || transferredActiveProducts.count > 0)) {
               completion(nil, IHRestoreResponse(newPurchases: newPurchases, transferredActiveProducts: transferredActiveProducts))
            }
            else {
               completion(err, nil)
            }
            // Mark restoring is done
            self.isRestoring = false
         })
      })
   }
   
   /**
    Send log
   */
   func sendLog(_ options: Dictionary<String, Any>) {
      var params = [
         "data": [
            "body": [
               "message": ["body": options["message"]]
            ],
            "level": (options["level"] ?? "error"),
            "environment": Iaphub.shared.environment,
            "platform": IHConfig.sdk,
            "framework": Iaphub.shared.sdk,
            "code_version": IHConfig.sdkVersion,
            "person": ["id": Iaphub.shared.appId],
            "context": "\(Iaphub.shared.appId)/\(Iaphub.shared.user?.id ?? "")",
            "custom": [
               "osVersion": Iaphub.shared.osVersion,
               "sdkVersion": Iaphub.shared.sdkVersion,
               "userIsInitialized": self.isInitialized,
               "userHasProducts": (!self.productsForSale.isEmpty || !self.activeProducts.isEmpty)
            ]
         ]
      ]
      // Add params
      if let custom = options["params"] as? Dictionary<String, Any>, let originalCustom = params["data"]?["custom"] as? Dictionary<String, Any>  {
         params["data"]?["custom"] = custom.merging(originalCustom) { (_, new) in new }
      }
      // Add fingerprint
      if let fingerprint = options["fingerprint"] as? String {
         params["data"]?["fingerprint"] = fingerprint
      }
      // Send request
      Iaphub.shared.user?.api?.postLog(params, { err in
         // No need to do anything if there is an error
      })
   }
   
}
