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
   // Iaphub user id
   var iaphubId: String? = nil
   // Products for sale of the user
   var productsForSale: [IHProduct] = []
   // Active products of the user
   var activeProducts: [IHActiveProduct] = []
   // Paywall id
   var paywallId: String? = nil
   // Filtered products for sale
   var filteredProductsForSale: [IHProduct] = []
   // Latest user fetch date
   var fetchDate: Date? = nil
   // ETag
   var etag: String? = nil
   // Foreground refresh interval
   var foregroundRefreshInterval: Double? = nil

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
   // Indicates the user is logging in
   var isLoggingIn: Bool = false
   // Indicates if the filtered products are currently being updated
   var isUpdatingFilteredProducts: Bool = false
   // Indicates the user is initialized
   var isInitialized: Bool = false
   // If the login with the server is enabled
   var isServerLoginEnabled: Bool = false
   // Indicates if the user data has been fetched from the server
   var isServerDataFetched: Bool = false
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
   // Purchase intent
   var purchaseIntent: String? = nil
   // Update queue
   var updateQueue = DispatchQueue(label: "com.iaphub.updateQueue")


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
    Get payment processor
    */
   func getPaymentProcessor() -> String? {
      guard let storekit = self.sdk.storekit else {
         return nil
      }
      if (storekit.version == 1) {
         return "app_store_v1"
      }
      else if (storekit.version == 2) {
         return "app_store_v2"
      }
      return nil
   }
   
   /**
    Create purchase intent
    */
   func createPurchaseIntent(sku: String, _ completion: @escaping (IHError?) -> Void) {
      guard let api = self.api else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.api_not_found, message: "create purchase intent failed"))
      }
      // Check if not already processing
      if (self.purchaseIntent != nil) {
         return completion(IHError(IHErrors.buy_processing))
      }
      // Create purchase intent
      var params: [String: Any] = ["sku": sku, "paymentProcessor": self.getPaymentProcessor() as Any]
      if let paywallId = self.paywallId {
         params["paywallId"] = paywallId
      }
      api.createPurchaseIntent(params, { (err, response) in
         // Check if there is an error
         guard err == nil else {
            return completion(err)
         }
         // Update current purchase intent id
         self.purchaseIntent = response?.data?["id"] as? String
         // Call completion
         completion(nil)
      })
   }
   
   /**
    Confirm purchase intent
    */
   func confirmPurchaseIntent(_ err: IHError?, _ transaction: IHReceiptTransaction?, _ completion: @escaping (IHError?, IHReceiptTransaction?) -> Void) {
      guard let api = self.api else {
         return completion(err, transaction)
      }
      var params: [String: Any] = [:]

      if let err = err {
         params["errorCode"] = err.code
         if (err.subcode != nil) {
            params["errorSubCode"] = err.subcode
         }
      }
      // This error shouldn't happen
      else if (transaction == nil) {
         params["errorCode"] = "transaction_missing"
      }
      
      guard let purchaseIntent = self.purchaseIntent else {
         return completion(err, transaction)
      }
      self.purchaseIntent = nil
      api.confirmPurchaseIntent(purchaseIntent, params, { (_, _) in
         completion(err, transaction)
      })
   }
   
   /**
    Buy product
    */
   func buy(sku: String, crossPlatformConflict: Bool = true, _ completion: @escaping (IHError?, IHReceiptTransaction?) -> Void) {
      // Check the sdk is started
      guard let storekit = self.sdk.storekit else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.start_missing), nil)
      }
      // Create purchase intent
      self.createPurchaseIntent(sku: sku) { err in
         // Check if there is an error
         guard err == nil else {
            return self.confirmPurchaseIntent(err, nil, completion)
         }
         // Refresh user
         self.refresh(context: IHUserFetchContext(source: .buy), { (err, isFetched, isUpdated) in
            // Check if there is an error
            guard err == nil else {
               return self.confirmPurchaseIntent(err, nil, completion)
            }
            // Get product
            storekit.getProductDetails(sku) { err, product in
               // Check if there is an error
               guard let product = product else {
                  return self.confirmPurchaseIntent(err, nil, completion)
               }
               // Try to get the product from the products for sale
               let productForSale = self.productsForSale.first(where: {$0.sku == sku})
               // Detect if the product has a subscription period (it means it is a subscription)
               let hasSubscriptionPeriod = product.subscriptionDuration != nil
               // Check if the product is a subscription by looking the type or the subscriptionPeriod property as a fallback
               if (productForSale?.type.contains("subscription") == true || hasSubscriptionPeriod == true) {
                  // Check cross platform conflicts
                  let conflictedSubscription = self.activeProducts.first(where: {$0.type.contains("subscription") && $0.platform != "ios"})
                  if (crossPlatformConflict && conflictedSubscription != nil) {
                     return self.confirmPurchaseIntent(
                        IHError(IHErrors.cross_platform_conflict, message: "platform: \(conflictedSubscription?.platform ?? "")"),
                        nil,
                        completion
                     )
                  }
                  // Check if the product is already going to be replaced on next renewal date
                  let replacedProduct = self.activeProducts.first(where: {$0.subscriptionRenewalProductSku == sku && $0.subscriptionState == "active"})
                  if (replacedProduct != nil) {
                     return self.confirmPurchaseIntent(
                        IHError(IHErrors.product_change_next_renewal, params: ["sku": sku]),
                        nil,
                        completion
                     )
                  }
               }
               // Launch purchase
               storekit.buy(sku) { err, transaction in
                  self.confirmPurchaseIntent(err, transaction, completion)
               }
            }
         })
      }
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
         dictionnary["paywallId"] = self.paywallId
         dictionnary["fetchDate"] = IHUtil.dateToIsoString(self.fetchDate)
         dictionnary["etag"] = self.etag
         dictionnary["isServerLoginEnabled"] = self.isServerLoginEnabled
         dictionnary["filteredProductsForSale"] = self.filteredProductsForSale.map({(product) in product.getDictionary()})
         dictionnary["cacheVersion"] = IHConfig.cacheVersion
         dictionnary["foregroundRefreshInterval"] = self.foregroundRefreshInterval
      }
      return dictionnary
   }
   
   /**
    Get cache data
   */
   func getCacheData() {
      let prefix = self.isAnonymous() ? "iaphub_user_a" : "iaphub_user"
      let key = "\(prefix)_\(self.sdk.appId)"
      // Attempt to retrieve the cache from the keychain
      var str = IHUtil.getFromKeychain(key)
      // If the cache is not found in the keychain, try to retrieve it from local storage
      if (str == nil) {
         str = IHUtil.getFromLocalstorage(key)
      }

      if let str = str, let data = str.data(using: .utf8)
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
               self.filteredProductsForSale = IHUtil.parseItems(data: json["filteredProductsForSale"] ?? [], type: IHProduct.self, failure: { err, item in
                  IHError(IHErrors.unexpected, IHUnexpectedErrors.get_cache_data_item_parsing_failed, message: "issue on filtered product for sale, \(err.localizedDescription)", params: ["item": item as Any])
               })
               self.activeProducts = IHUtil.parseItems(data: json["activeProducts"], type: IHActiveProduct.self, failure: { err, item in
                  IHError(IHErrors.unexpected, IHUnexpectedErrors.get_cache_data_item_parsing_failed, message: "issue on active product, \(err.localizedDescription)", params: ["item": item as Any])
               })
               self.isServerLoginEnabled = json["isServerLoginEnabled"] as? Bool ?? false
               self.paywallId = json["paywallId"] as? String
               self.etag = json["etag"] as? String
               self.foregroundRefreshInterval = json["foregroundRefreshInterval"] as? Double
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
      let key = "\(prefix)_\(self.sdk.appId)"
      
      // Try to save to keychain first
      let keychainErr = IHUtil.saveToKeychain(key: key, value: str)
      // If keychain save failed, fallback to localStorage
      if (keychainErr != nil) {
         _ = IHUtil.deleteFromKeychain(key: key)
         IHUtil.saveToLocalstorage(key: key, value: str)
      }
   }
   
   /**
    Enable server login
   */
   func enableServerLogin() {
      self.isServerLoginEnabled = true
      self.saveCacheData()
   }
   
   /**
    Disable server login
   */
   func disableServerLogin() {
      self.isServerLoginEnabled = false
      self.saveCacheData()
   }

   /**
    Return if it is an anonymous user
   */
   func isAnonymous() -> Bool {
      return self.id.hasPrefix(IHConfig.anonymousUserPrefix)
   }

   /**
    Fetch user
   */
   func fetch(context: IHUserFetchContext, _ completion: @escaping (IHError?, Bool) -> Void) {
      self.updateQueue.async {
         // Check if the user id is valid
         if (self.isAnonymous() == false && IHUser.isValidId(self.id) == false) {
            return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.user_id_invalid, message: "fetch failed, (user id: \(self.id))", params: ["userId": self.id]), false)
         }
         // Add completion to the requests
         self.fetchRequests.append(completion)
         // Stop here if the user is currently being fetched
         if (self.isFetching) {
            return
         }
         self.isFetching = true
         // Method to complete fetch request
         func completeFetchRequest(err: IHError?, isUpdated: Bool) {
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
            let isInitialized = self.isInitialized
            if (self.fetchDate != nil && isInitialized == false) {
               self.isInitialized = true
            }
            // Call requests with the error
            var requestIsUpdated = isUpdated
            fetchRequests.forEach({ (request) in
               request(err, requestIsUpdated)
               // Only mark as updated for the first request
               if (requestIsUpdated && isInitialized == true) {
                  requestIsUpdated = false
                  self.onUserUpdate?()
               }
            })
         }
         // If fetching for the first time, try getting data from cache
         if (self.fetchDate == nil) {
            self.getCacheData()
         }
         // Fetch API
         self.fetchAPI(context: context, completeFetchRequest)
      }
   }
   
   /**
    Fetch user from API
   */
   func fetchAPI(context: IHUserFetchContext, _ completion: @escaping (IHError?, Bool) -> Void) {
      var context = context
      
      // Get api
      guard let api = self.api else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.api_not_found, message: "fetch failed"), false)
      }
      // Add last fetch context
      if let fetchDate = self.fetchDate {
         let timeSinceLastFetch = Date().timeIntervalSince(fetchDate)
         
         if timeSinceLastFetch < 10 {
            context.properties.append(.last_fetch_under_ten_seconds)
         }
         else if timeSinceLastFetch < 60 {
            context.properties.append(.last_fetch_under_one_minute)
         }
         else if timeSinceLastFetch < 3600 {
            context.properties.append(.last_fetch_under_one_hour)
         }
         else if timeSinceLastFetch < 86400 {
            context.properties.append(.last_fetch_under_one_day)
         }
      }
      // Add property to context if initialization detected
      if (!self.isServerDataFetched) {
         context.properties.append(.initialization)
      }
      // Add property to context if active product detected
      if (!self.activeProducts.isEmpty) {
         // Check for active and expired subscriptions
         let subscriptions = self.activeProducts.filter({ $0.type.contains("subscription") && $0.expirationDate != nil })
         // Add active subscription property if any subscription is active
         if subscriptions.contains(where: { $0.expirationDate! > Date() }) {
            context.properties.append(.with_active_subscription)
         }
         // Add expired subscription property if any subscription is expired
         if subscriptions.contains(where: { $0.expirationDate! <= Date() }) {
            context.properties.append(.with_expired_subscription)
         }
         // Add active non consumable property if any non consumable is active
         if self.activeProducts.contains(where: { $0.type == "non_consumable" }) {
            context.properties.append(.with_active_non_consumable)
         }
      }
      // Save products dictionnary
      let productsDictionnary = self.getDictionnary(productsOnly: true)
      // Get data from API
      api.getUser(context: context, { (err, response) in
         // Update user using API data
         self.updateFromApiData(err: err, response: response) { updateErr in
            // Check if the user has been updated
            let newProductsDictionnary = self.getDictionnary(productsOnly: true)
            var isUpdated = false
            if (NSDictionary(dictionary: newProductsDictionnary).isEqual(to: productsDictionnary) == false) {
               isUpdated = true
            }
            // Call completion
            completion(updateErr, isUpdated)
         }
      })
   }
   
   /**
    Update user using API data
   */
   private func updateFromApiData(err: IHError?, response: IHNetworkResponse?, _ completion: @escaping (IHError?) -> Void) {
      var data = response?.data

      // If there is no error
      if (err == nil) {
         // Update isServerDataFetched
         self.isServerDataFetched = true
         // Update ETag
         if let etag = response?.getHeader("ETag") {
            self.etag = etag
         }
         // Update foreground refresh interval
         if let foregroundRefreshInterval = response?.getHeader("X-Foreground-Refresh-Interval") {
            self.foregroundRefreshInterval = Double(foregroundRefreshInterval)
         }
      }
      // Handle errors or 304 not modified
      if (err != nil || response?.hasNotModifiedStatusCode() == true) {
         // Clear products if the platform is disabled
         if let err = err, err.code == "server_error" && err.subcode == "platform_disabled" {
            self.isServerDataFetched = true
            data = ["productsForSale": [], "activeProducts": []]
         }
         // Otherwise return an error
         else {
            // Update all products details
            self.updateAllProductsDetails {
               completion(err)
            }
            return
         }
      }
      guard let data = data else {
         return completion(err)
      }
      // Update data
      self.update(data, {(err) in
         // Check error
         if (err != nil) {
            return completion(err)
         }
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
         // Update paywall id
         self.paywallId = data["paywallId"] as? String
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
      // Call completion on empty array
      if (productSkus.isEmpty) {
         return completion()
      }
      // Check the sdk is started
      guard let storekit = self.sdk.storekit else {
         return completion()
      }
      // Get products details
      storekit.getProductsDetails(productSkus, { (err, productsDetails) in
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
               // Set product details
               product.setDetails(productDetail)
               // StoreKit V1 does not detect the intro phase eligibility automatically
               // We have to do it manually with the 'subscriptionPeriodType' property from the API
               if let subscriptionPeriodType = product.data["subscriptionPeriodType"] as? String, storekit.version == 1 {
                  product.filterIntroPhases(subscriptionPeriodType)
               }
            }
         })
         // Call completion
         completion()
      })
   }
   
   /**
    Update all products details
   */
   func updateAllProductsDetails(_ completion: @escaping () -> Void) {
      let products = self.productsForSale + self.activeProducts + self.filteredProductsForSale

      // Update products details
      self.updateProductsDetails(products) {
         // Detect recovered products
         let recoveredProducts = self.filteredProductsForSale.filter({product in product.details != nil})
         
         if (!recoveredProducts.isEmpty) {
            // Add to list of products for sale
            self.productsForSale = self.productsForSale + recoveredProducts
            // Update filtered products for sale
            self.filteredProductsForSale = self.filteredProductsForSale.filter({product in product.details == nil})
         }
         // Call completion
         completion()
      }
   }
   
   /**
    Update filtered products
   */
   func updateFilteredProducts(_ completion: @escaping (Bool) -> Void) {
      self.updateQueue.async {
         // Check if the filtered products are currently being updated and return completion if true
         if (self.isUpdatingFilteredProducts) {
            return completion(false)
         }
         // Update property
         self.isUpdatingFilteredProducts = true
         // Update products details
         self.updateProductsDetails(self.filteredProductsForSale) {
            // Detect recovered products
            let recoveredProducts = self.filteredProductsForSale.filter({product in product.details != nil})
            
            if (!recoveredProducts.isEmpty) {
               // Add to list of products for sale
               self.productsForSale = self.productsForSale + recoveredProducts
               // Update filtered products for sale
               self.filteredProductsForSale = self.filteredProductsForSale.filter({product in product.details == nil})
               // Call completion
               completion(true)
            }
            // Call completion
            else {
               completion(false)
            }
            // Update property
            self.isUpdatingFilteredProducts = false
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
   func refresh(context: IHUserFetchContext, interval: Double, force: Bool = false, _ completion: ((IHError?, Bool, Bool) -> Void)? = nil) {
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
      // Update products details if we have filtered products
      if (!shouldFetch && !self.filteredProductsForSale.isEmpty) {
         self.updateFilteredProducts { isUpdated in
            // Trigger onUserUpdate on update
            if (isUpdated) {
               self.onUserUpdate?()
            }
            // Call completion
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
      self.fetch(context: context, { (err, isUpdated) in
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
    Refresh user with a dynamic interval
   */
   func refresh(context: IHUserFetchContext, _ completion: ((IHError?, Bool, Bool) -> Void)? = nil) {
      var interval: Double = 86400 // 24 hours by default
      
      // If this is an on foreground refresh, use the foreground refresh interval if defined
      if context.properties.contains(.on_foreground), let foregroundRefreshInterval = self.foregroundRefreshInterval {
         interval = foregroundRefreshInterval
      }
      // Refresh user
      self.refresh(context: context, interval: interval, { (err, isFetched, isUpdated) in
         // Check if there is an error
         guard err == nil else {
            completion?(err, isFetched, isUpdated)
            return
         }
         // If the user has not been fetched and the interval is over 60s, check for active subscriptions
         if (isFetched == false && interval > 60) {
            let subscriptions = self.activeProducts.filter { (product) in
               return product.type == "renewable_subscription" || product.type == "subscription";
            }
            // If there are active subscriptions, refresh every minute
            if (subscriptions.count > 0) {
               self.refresh(context: context, interval: 60, completion)
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
      self.refresh(context: IHUserFetchContext(source: .products), { (err, _, _) in
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
      self.refresh(context: IHUserFetchContext(source: .products), interval: 60 * 60 * 24, { (err, _, _) in
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
      self.filteredProductsForSale = []
      self.activeProducts = []
      self.fetchDate = nil
      self.receiptPostDate = nil
      self.updateDate = nil
      self.needsFetch = false
      self.isInitialized = false
      self.isServerLoginEnabled = false
      self.isServerDataFetched = false
      self.etag = nil
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
      // Check that login is not already processing
      if (self.isLoggingIn == true) {
         return completion(IHError(IHErrors.user_login_processing))
      }
      self.isLoggingIn = true
      // Detect if we should call the API to update the id
      let shouldCallApi = self.isAnonymous() && self.isServerLoginEnabled
      let currentUserId = self.id
      // Disable server login
      if (self.isServerLoginEnabled) {
         self.disableServerLogin()
      }
      // Update id
      self.id = userId
      // Reset user
      self.reset()
      // Call API if necessary
      if (shouldCallApi) {
         guard let api = self.api else {
            self.isLoggingIn = false
            return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.api_not_found, message: "login failed"))
         }
         api.login(currentUserId: currentUserId, newUserId: userId, { (_) in
            self.isLoggingIn = false
            // Ignore error and call completion (if the login couldn't be called for any reason and the purchases were not transferred the user can still do a restore)
            completion(nil)
         })
      }
      // Otherwise call completion
      else {
         self.isLoggingIn = false
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
   func loadReceiptPricings(_ receipt: IHReceipt, _ completion: @escaping () -> Void) {
      // Check the sdk is started
      guard let storekit = self.sdk.storekit else {
         return completion()
      }
      // Get receipt sku + skus of same group
      let allProducts = self.productsForSale + self.activeProducts
      var skus = Set<String>()
      // Look if we can find the product
      let receiptProduct = allProducts.first(where: {$0.sku == receipt.sku})
      // If we can, also add the products from the same group
      if let receiptProduct = receiptProduct {
         let productsSameGroup = allProducts.filter({ item in item.group != nil && item.group == receiptProduct.group && item.sku != receiptProduct.sku}).prefix(20)
         skus = Set([receiptProduct.sku] + productsSameGroup.compactMap({ item in item.sku}))
      }
      // Otherwise only use the sku from the receipt
      else {
         skus = Set([receipt.sku])
      }
      // Get product details of the skus
      storekit.getProductsDetails(skus) { err, productsDetails in
         // Add pricings of the skus on the receipt
         receipt.pricings = (productsDetails ?? []).compactMap { (productDetails: IHProductDetails) -> IHProductPricing? in
            let product = allProducts.first(where: {$0.sku == productDetails.sku})
            
            if let currency = productDetails.currency, let price = productDetails.price {
               return IHProductPricing(
                  id: product?.id,
                  sku: productDetails.sku,
                  price: price.doubleValue,
                  currency: currency,
                  introPrice: productDetails.subscriptionIntroPhases?.first?.price
               )
            }
            return nil
         }
         // Call completion
         completion()
      }
   }
   
   /**
    Post receipt
   */
   func postReceipt(_ receipt: IHReceipt, _ completion: @escaping (IHError?, IHReceiptResponse?) -> Void) {
      guard let api = self.api else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.api_not_found, message: "post receipt failed"), nil)
      }
      // Add purchase intent
      if (receipt.context == "purchase") {
         receipt.purchaseIntent = self.purchaseIntent
      }
      // Get product details of the skus
      self.loadReceiptPricings(receipt) {
         // Post receipt
         api.postReceipt(receipt.getDictionary()) { (err, response) in
            // Check for error
            guard err == nil, let data = response?.data else {
               return completion(err ?? IHError(IHErrors.unexpected, IHUnexpectedErrors.post_receipt_data_missing), nil)
            }
            // Update receipt post date
            self.receiptPostDate = Date()
            // Update updateDate
            self.updateDate = Date()
            // Create receipt response
            let receiptResponse = IHReceiptResponse(data)
            // If it is an anonymous user, enable the server login if a new transaction is detected
            if self.isAnonymous() && receiptResponse.status == "success" && receiptResponse.newTransactions?.isEmpty == false {
               self.enableServerLogin()
            }
            // Parse and return receipt response
            completion(nil, receiptResponse)
         }
      }
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
      // Check the sdk is started
      guard let storekit = self.sdk.storekit else {
         return completion(IHError(IHErrors.unexpected, IHUnexpectedErrors.start_missing), nil)
      }
      // Reinitialize restoredDeferredPurchases array
      self.restoredDeferredPurchases = []
      // Mark as restoring
      self.isRestoring = true
      // Save old active products
      let oldActiveProducts = self.activeProducts
      // Launch restore
      storekit.restore({ (err) in
         // Update updateDate
         self.updateDate = Date()
         // Refresh user
         self.refresh(context: IHUserFetchContext(source: .restore), interval: 0, force: true, { _, _, _ in
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
