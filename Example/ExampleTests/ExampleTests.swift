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
   var enableStorekitV2: Bool = true // Update this variable to switch StoreKit V1/V2
   
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
            apiKey: "Usaw9viZNrnYdNSwPIFFo7iUxyjK23K3",
            allowAnonymousPurchase: true,
            enableStorekitV2: self.enableStorekitV2
         )
         iaphubStarted = true
      }
   }
   
   func test000_billingVersion() async throws {
      XCTAssertEqual(Iaphub.shared.storekit?.version, self.enableStorekitV2 ? 2 : 1)
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
      var userFetched = false
      
      Iaphub.shared.user?.api?.network.mock = {(type, route, params) in
         if (type == "GET" && route.contains("/user")) {
            userFetched = true
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
         }
         return nil
      }
      try await Iaphub.login(userId: "42")
      XCTAssertEqual(Iaphub.shared.user?.id, "42")
      XCTAssertEqual(loginTriggered, false)
   }
   
   func test04_logout() async throws {
      Iaphub.logout()
   }

   func test05_buy() async throws {
      var receiptParams: Dictionary<String, Any> = [:]
      
      Iaphub.shared.user?.api?.network.mock = {(type, route, params) in
         if (route.contains("/receipt")) {
            receiptParams = params
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
         else if (route.contains("/intent")) {
            return [
               "id": "3a517bdd0613c16f11e7faz4"
            ]
         }
         return nil
      }

      let transaction = try await Iaphub.buy(sku: "consumable")
      
      XCTAssertEqual(self.delegate.errorCount, 0)
      XCTAssertEqual(self.delegate.userUpdateCount, 0)
      XCTAssertEqual(self.delegate.processReceiptCount, 1)
      
      XCTAssertEqual(receiptParams["context"] as? String, "purchase")
      XCTAssertEqual(receiptParams["purchaseIntent"] as? String, "3a517bdd0613c16f11e7faz4")
      XCTAssertEqual((receiptParams["pricings"] as? [[String: Any]])?.first?["sku"] as? String, "consumable")
      
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
   
   func test06_loginWithServer() async throws {
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
      
      Iaphub.logout()
      loginTriggered = false
      try await Iaphub.login(userId: "43")
      XCTAssertEqual(Iaphub.shared.user?.id, "43")
      XCTAssertEqual(loginTriggered, false)
   }
   
   func test07_buy_user_conflict() async throws {
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

   func test08_detectUserUpdate() async throws {
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

   func test09_restore() async throws {
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
      // StoreKit V2 doesn't return a receipt if no transactions found during restore
      if (Iaphub.shared.storekit?.version == 1) {
         XCTAssertEqual(self.delegate.processReceiptCount, 1)
      }
   }
   
   func test10_setTags() async throws {
      // Add tag
      try await Iaphub.setUserTags(tags: ["group": "1"])
      XCTAssertEqual(self.delegate.errorCount, 0)
      // Delete tag
      try await Iaphub.setUserTags(tags: ["group": ""])
      XCTAssertEqual(self.delegate.errorCount, 0)
   }
   
   func test11_setDeviceParams() async throws {
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
   
   func test12_getActiveProducts() async throws {
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
   
   func test13_concurrentFetch() throws {
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
   
   func test14_consumeDeferredPurchase() async throws {
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
   
   func test15_getDeferredPurchaseEvent() async throws {
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
