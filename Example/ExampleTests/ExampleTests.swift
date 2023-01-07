//
//  ExampleTests.swift
//  ExampleTests
//
//  Created by Work on 10/20/21.
//

import XCTest
import StoreKitTest
@testable import Iaphub

class IaphubTestsDelegate: NSObject, IaphubDelegate {
   
   var buyRequests: [String] = []
   var deferredPurchases: [IHReceiptTransaction] = []
   var userUpdateCount = 0
   var processReceiptCount = 0
   var errorCount = 0
   
   func didReceiveBuyRequest(sku: String) {
      self.buyRequests.append(sku)
   }

   func didReceiveDeferredPurchase(transaction: IHReceiptTransaction) {
      self.deferredPurchases.append(transaction)
   }
    
   func didReceiveUserUpdate() {
      self.userUpdateCount += 1
   }

   func didProcessReceipt(err: IHError?, receipt: IHReceipt?) {
      self.processReceiptCount += 1
   }
   
   func didReceiveError(err: IHError) {
      self.errorCount += 1
      print("---> Error: \(err.localizedDescription)")
   }
   
}

var iaphubStarted = false

@available(iOS 14.0, *)
class IaphubTests: XCTestCase {
   
   var delegate: IaphubTestsDelegate!
   var testSession: SKTestSession!
   
   override func setUpWithError() throws {
      self.testSession = try SKTestSession(configurationFileNamed: "Configuration")
      self.testSession.disableDialogs = true
      self.testSession.clearTransactions()
      self.delegate = IaphubTestsDelegate()
      Iaphub.delegate = self.delegate
      Iaphub.shared.testing.logs = false
      Iaphub.shared.testing.billingUnavailable = false
      if (iaphubStarted == false) {
         // Delete cache
         _ = IHUtil.deleteFromKeychain(key: "iaphub_user_a_61718bfd9bf07f0c7d2357d1")
         _ = IHUtil.deleteFromKeychain(key: "iaphub_user_61718bfd9bf07f0c7d2357d1")
         // Start IAPHUB
         Iaphub.start(
            appId: "61718bfd9bf07f0c7d2357d1",
            apiKey: "Usaw9viZNrnYdNSwPIFFo7iUxyjK23K3"
         )
         iaphubStarted = true
      }
   }

   func test00_billingUnavailable() async throws {
      Iaphub.shared.testing.billingUnavailable = true
      let products = try await Iaphub.getProductsForSale()
      XCTAssertEqual(products.count, 0)
      let status = Iaphub.getBillingStatus()
      XCTAssertEqual(status.filteredProductIds, ["consumable"])
      XCTAssertEqual(status.error?.code, "billing_unavailable")
   }
   
   func test01_getProductsForSale() async throws {
      var pricePosted = false
      var userFetched = false
      
      Iaphub.shared.user?.api?.network.mock = {(type, route, params) in
         if (type == "GET" && route.contains("/user")) {
            userFetched = true
         }
         else if (route.contains("/pricing")) {
            let products = params["products"] as? [Dictionary<String, Any>]
            
            if let products = products {
               if (products[0]["price"] as? Double == 1.99 && products[0]["currency"] as? String == "USD") {
                  pricePosted = true
               }
            }
         }
         return nil
      }
      
      let products = try await Iaphub.getProductsForSale()
      let status = Iaphub.getBillingStatus()

      XCTAssertEqual(status.filteredProductIds.count, 0)
      XCTAssertEqual(status.error, nil)
      
      XCTAssertEqual(self.delegate.userUpdateCount, 1)
      XCTAssertEqual(products.count, 1)
      XCTAssertEqual(products[0].sku, "consumable")
      XCTAssertEqual(products[0].type, "consumable")
      XCTAssertEqual(products[0].localizedTitle, "Consumable")
      XCTAssertEqual(products[0].localizedDescription, "This is a consumable")
      XCTAssertEqual(products[0].localizedPrice, "$1.99")
      XCTAssertEqual(products[0].price, 1.99)
      XCTAssertEqual(products[0].currency, "USD")
      XCTAssertEqual(pricePosted, true)
      XCTAssertEqual(userFetched, false)
   }
   
   func test02_getUserId() async throws {
      let userId = Iaphub.getUserId()
      
      XCTAssertEqual(userId?.split(separator: ":")[0], "a")
   }

   func test03_login() async throws {
      var loginTriggered = false
      // Mock login request
      Iaphub.shared.user?.api?.network.mock = {(type, route, params) in
         if (route.contains("/login")) {
            loginTriggered = true
            XCTAssertEqual(params["userId"] as? String, "42")
            XCTAssertEqual(route.contains("a:"), true)
         }
         return nil
      }
      try await Iaphub.login(userId: "42")
      XCTAssertEqual(Iaphub.shared.user?.id, "42")
      XCTAssertEqual(loginTriggered, true)
   }

   func test04_buy() async throws {
      
      XCTAssertEqual(Iaphub.shared.storekit.purchasedTransactionQueue?.waiting.count, 0)
      Iaphub.shared.user?.api?.network.mock = {(type, route, params) in
         if (route.contains("/receipt")) {
            return [
               "status": "success",
               "oldTransactions": [],
               "newTransactions": [
                  [
                     "id": "5e517bdd0613c16f11e7fae0",
                     "type": "consumable",
                     "sku": "consumable",
                     "purchase": "2e517bdd0613c16f11e7faz2",
                     "purchaseDate": "2020-05-22T01:34:40.462Z",
                     "webhookStatus": "success"
                  ]
               ]
            ]
         }
         return nil
      }

      let transaction = try await Iaphub.buy(sku: "consumable")
      XCTAssertEqual(Iaphub.shared.storekit.purchasedTransactionQueue?.waiting.count, 0)
      XCTAssertEqual(self.delegate.errorCount, 0)
      XCTAssertEqual(self.delegate.userUpdateCount, 0)
      XCTAssertEqual(self.delegate.processReceiptCount, 1)
      XCTAssertEqual(transaction.sku, "consumable")
      XCTAssertEqual(transaction.type, "consumable")
      XCTAssertEqual(transaction.localizedTitle, "Consumable")
      XCTAssertEqual(transaction.localizedDescription, "This is a consumable")
      XCTAssertEqual(transaction.localizedPrice, "$1.99")
      XCTAssertEqual(transaction.price, 1.99)
      XCTAssertEqual(transaction.currency, "USD")
      XCTAssertEqual(transaction.purchase, "2e517bdd0613c16f11e7faz2")
      XCTAssertEqual(transaction.webhookStatus, "success")
      XCTAssertEqual(transaction.purchaseDate?.timeIntervalSince1970, 1590111280.462)
   }
   
   func test05_buy_user_conflict() async throws {
      
      XCTAssertEqual(Iaphub.shared.storekit.purchasedTransactionQueue?.waiting.count, 0)
      Iaphub.shared.user?.api?.network.mock = {(type, route, params) in
         if (type == "GET" && route.contains("/user")) {
            return [
               "id": "61781dff9bf07f0c7d32c8b6",
               "productsForSale": [
                  [
                     "id": "61781dff9bf07f0c7d32c9a7",
                     "sku": "renewable_subscription",
                     "type": "renewable_subscription",
                     "subscriptionPeriodType": "normal"
                  ]
               ],
               "activeProducts": []
            ]
         }
         else if (route.contains("/receipt")) {
            return [
               "status": "success",
               "oldTransactions": [],
               "newTransactions": [
                  [
                     "id": "5e517bdd0613c16f11e7fae0",
                     "type": "renewable_subscription",
                     "sku": "renewable_subscription",
                     "user": "61781dff9bf07f0c7d32c8b5",
                     "purchase": "2e517bdd0613c16f11e7fbt1",
                     "purchaseDate": "2021-05-22T01:34:40.462Z",
                     "expirationDate": "2025-05-22T01:34:40.462Z",
                     "subscriptionState": "active",
                     "subscriptionPeriodType": "normal",
                     "isSubscriptionRenewable": true,
                     "isSubscriptionPaused": false,
                     "webhookStatus": "success"
                  ]
               ]
            ]
         }
         return nil
      }

      var err: IHError? = nil
      do {
         let _ = try await Iaphub.buy(sku: "renewable_subscription")
      }
      catch {
         err = error as? IHError
      }
      
      XCTAssertEqual(err?.code, "user_conflict")
      XCTAssertEqual(self.delegate.errorCount, 1)
   }

   func test06_detectUserUpdate() async throws {
      Iaphub.shared.user?.api?.network.mock = {(type, route, params) in
         if (type == "GET" && route.contains("/user")) {
            return [
               "productsForSale": [],
               "activeProducts": [
                  [
                     "id": "61781dff9bf07f0c7d32c9a7",
                     "sku": "renewable_subscription",
                     "type": "renewable_subscription",
                     "purchase": "2e517bdd0613c16f11e7faz3",
                     "purchaseDate": "2021-05-22T01:34:40.462Z",
                     "platform": "ios",
                     "isFamilyShare": false,
                     "expirationDate": "2023-05-22T01:34:40.462Z",
                     "subscriptionState": "active",
                     "subscriptionPeriodType": "normal",
                     "isSubscriptionRenewable": true,
                     "isSubscriptionPaused": false
                  ]
               ]
            ]
         }
         return nil
      }
      // Force refresh
      Iaphub.shared.user?.fetchDate = Date(timeIntervalSince1970: Date().timeIntervalSince1970 - 60 * 60 * 25)
      
      let activeProducts = try await Iaphub.getActiveProducts()
      let productsForSale = try await Iaphub.getProductsForSale()
      XCTAssertEqual(activeProducts.count, 1)
      XCTAssertEqual(productsForSale.count, 0)
      XCTAssertEqual(self.delegate.errorCount, 0)
      XCTAssertEqual(self.delegate.userUpdateCount, 1)
      XCTAssertEqual(activeProducts[0].subscriptionState, "active")
      XCTAssertEqual(activeProducts[0].localizedPrice, "$9.99")
      XCTAssertEqual(activeProducts[0].expirationDate?.timeIntervalSince1970, 1684719280.462)
   }

   func test07_restore() async throws {
      Iaphub.shared.user?.api?.network.mock = {(type, route, params) in
         if (route.contains("/receipt")) {
            return [
               "status": "success",
               "oldTransactions": [],
               "newTransactions": [
                  [
                     "id": "5e517bdd0613c16f11e7fae0",
                     "type": "consumable",
                     "sku": "consumable",
                     "purchase": "2e517bdd0613c16f11e7faz2",
                     "purchaseDate": "2020-05-22T01:34:40.462Z",
                     "webhookStatus": "success"
                  ]
               ]
            ]
         }
         return nil
      }

      try await Iaphub.restore()
      XCTAssertEqual(self.delegate.errorCount, 0)
      XCTAssertEqual(self.delegate.processReceiptCount, 1)
   }
   
   func test08_setTags() async throws {
      // Add tag
      try await Iaphub.setUserTags(tags: ["group": "1"])
      XCTAssertEqual(self.delegate.errorCount, 0)
      // Delete tag
      try await Iaphub.setUserTags(tags: ["group": ""])
      XCTAssertEqual(self.delegate.errorCount, 0)
   }
   
   func test09_setDeviceParams() async throws {
      Iaphub.setDeviceParams(params: ["appVersion": "2.0.0"])
      XCTAssertEqual(Iaphub.shared.deviceParams.count, 1)
      XCTAssertEqual(Iaphub.shared.user?.needsFetch, true)
      let productsForSale = try await Iaphub.getProductsForSale()
      
      XCTAssertEqual(self.delegate.errorCount, 0)
      XCTAssertEqual(productsForSale.count, 1)
      XCTAssertEqual(productsForSale[0].sku, "renewable_subscription")
      
      Iaphub.setDeviceParams(params: [:])
      XCTAssertEqual(Iaphub.shared.deviceParams.count, 0)
      XCTAssertEqual(Iaphub.shared.user?.needsFetch, true)
   }
   
   func test10_getActiveProducts() async throws {
      Iaphub.shared.user?.api?.network.mock = {(type, route, params) in
         if (type == "GET" && route.contains("/user")) {
            return [
               "productsForSale": [],
               "activeProducts": [
                  [
                     "id": "61781dff9bf07f0c7d32c9a7",
                     "sku": "renewable_subscription",
                     "type": "renewable_subscription",
                     "purchase": "2e517bdd0613c16f11e7faz3",
                     "purchaseDate": "2021-05-22T01:34:40.462Z",
                     "platform": "ios",
                     "isFamilyShare": false,
                     "isPromo": false,
                     "originalPurchase": "2e517bdd0613c16f11e7fab2",
                     "expirationDate": "2023-05-22T01:34:40.462Z",
                     "subscriptionState": "retry_period",
                     "subscriptionPeriodType": "normal",
                     "isSubscriptionRenewable": true,
                     "isSubscriptionPaused": false
                  ],
                  [
                     "id": "61781dff9bf07f0c7d32c9a8",
                     "sku": "unknown_subscription",
                     "type": "renewable_subscription",
                     "purchase": "2e517bdd0613c16f11e7faz4",
                     "purchaseDate": "2021-05-22T01:34:40.462Z",
                     "platform": "ios",
                     "isFamilyShare": false,
                     "isPromo": false,
                     "originalPurchase": "2e517bdd0613c16f21e5fab1",
                     "expirationDate": "2023-05-22T01:34:40.462Z",
                     "subscriptionState": "grace_period",
                     "subscriptionPeriodType": "normal",
                     "isSubscriptionRenewable": true,
                     "isSubscriptionPaused": false
                  ],
                  [
                     "id": "21781dff9bf02f0c6d32c5a8",
                     "type": "renewable_subscription",
                     "purchase": "6e517bdd0313c56f11e7faz9",
                     "purchaseDate": "2021-04-22T01:34:40.462Z",
                     "platform": "android",
                     "isFamilyShare": false,
                     "isPromo": true,
                     "promoCode": "SPRING",
                     "originalPurchase": "6e517bdd0313c56f11e7faz9",
                     "expirationDate": "2023-05-22T01:34:40.462Z",
                     "subscriptionState": "active",
                     "subscriptionPeriodType": "normal",
                     "isSubscriptionRenewable": true,
                     "isSubscriptionPaused": false
                  ]
               ]
            ]
         }
         return nil
      }
      // Force refresh
      Iaphub.shared.user?.fetchDate = Date(timeIntervalSince1970: Date().timeIntervalSince1970 - 60 * 60 * 25)
      
      let activeProducts = try await Iaphub.getActiveProducts()
      XCTAssertEqual(activeProducts.count, 2)
      XCTAssertEqual(activeProducts[0].sku, "unknown_subscription")
      XCTAssertEqual(activeProducts[0].localizedTitle, nil)
      XCTAssertEqual(activeProducts[0].originalPurchase, "2e517bdd0613c16f21e5fab1")
      XCTAssertEqual(activeProducts[1].sku, "")
      XCTAssertEqual(activeProducts[1].localizedTitle, nil)
      XCTAssertEqual(activeProducts[1].isPromo, true)
      XCTAssertEqual(activeProducts[1].promoCode, "SPRING")
      
      let allActiveProducts = try await Iaphub.getActiveProducts(includeSubscriptionStates: ["retry_period", "paused"])
      XCTAssertEqual(allActiveProducts.count, 3)
      XCTAssertEqual(allActiveProducts[0].localizedTitle, "Renewable subscription")
      XCTAssertEqual(allActiveProducts[1].localizedTitle, nil)
   }
   
   func test11_concurrentFetch() throws {
      IHUtil.deleteFromKeychain(key: "iaphub_user_a_61718bfd9bf07f0c7d2357d1")
      IHUtil.deleteFromKeychain(key: "iaphub_user_61718bfd9bf07f0c7d2357d1")
      
      var count = 0
      let expectation = self.expectation(description: "Concurrent fetch")
      
      func callback(err: IHError?, products: [IHProduct]?) {
         if (err == nil) {
            count += 1
         }
         if (count == 6) {
            expectation.fulfill()
         }
      }
      
      Iaphub.getProductsForSale(callback)
      Iaphub.getProductsForSale(callback)
      Iaphub.getActiveProducts(callback)
      Iaphub.getProductsForSale(callback)
      Iaphub.getProductsForSale(callback)
      Iaphub.getProductsForSale(callback)
      waitForExpectations(timeout: 5, handler: nil)
      XCTAssertEqual(count, 6)
   }
   
   func test12_consumeDeferredPurchase() async throws {
      var requestCount = 0
      
      // The deferred purchase events should be consumed by default
      Iaphub.shared.user?.api?.network.mock = {(type, route, params) in
         if (type == "GET" && route.contains("/user")) {
            requestCount += 1
            XCTAssertEqual(params["deferredPurchase"] as? String, nil)
            return [
               "productsForSale": [],
               "activeProducts": []
            ]
         }
         return nil
      }
      Iaphub.shared.user?.fetchDate = Date(timeIntervalSince1970: Date().timeIntervalSince1970 - 60 * 60 * 25)
      try await Iaphub.getActiveProducts()
      XCTAssertEqual(requestCount, 1)
      
      // And should be disabled if the option is specified
      Iaphub.start(appId: "61718bfd9bf07f0c7d2357d1", apiKey: "Usaw9viZNrnYdNSwPIFFo7iUxyjK23K3", enableDeferredPurchaseListener: false)
      Iaphub.shared.user?.api?.network.mock = {(type, route, params) in
         if (type == "GET" && route.contains("/user")) {
            requestCount += 1
            XCTAssertEqual(params["deferredPurchase"] as? String, "false")
            return [
               "productsForSale": [],
               "activeProducts": []
            ]
         }
         return nil
      }
      try await Iaphub.getActiveProducts()
      XCTAssertEqual(requestCount, 2)
   }
   
   func test13_getDeferredPurchaseEvent() async throws {
      Iaphub.shared.user?.api?.network.mock = {(type, route, params) in
         if (type == "GET" && route.contains("/user")) {
            return [
               "productsForSale": [],
               "activeProducts": [],
               "events": [
                  [
                     "type": "purchase",
                     "tags": ["deferred"],
                     "transaction": [
                        "id": "21781dff9bf02f0c6d32c5a7",
                        "type": "consumable",
                        "purchase": "6e517bdd0313c56f11e7faz8",
                        "purchaseDate": "2022-06-22T01:34:40.462Z",
                        "platform": "ios",
                        "isFamilyShare": false,
                        "user": "21781dff9bf02f0c6d32c4b2",
                        "webhookStatus": "success"
                     ]
                  ]
               ]
            ]
         }
         return nil
      }
      // Force refresh
      Iaphub.shared.user?.fetchDate = Date(timeIntervalSince1970: Date().timeIntervalSince1970 - 60 * 60 * 25)
      
      try await Iaphub.getActiveProducts()

      XCTAssertEqual(self.delegate.deferredPurchases.count, 1)
      XCTAssertEqual(self.delegate.deferredPurchases[0].id, "21781dff9bf02f0c6d32c5a7")
   }

}
