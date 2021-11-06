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
   
   static let shared = IaphubTestsDelegate()
   
   var buyRequests: [String] = []
   var userUpdateCount = 0
   var processReceiptCount = 0
   var errorCount = 0
   
   func didReceiveBuyRequest(sku: String) {
      self.buyRequests.append(sku)
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

@available(iOS 14.0, *)
class IaphubTests: XCTestCase {
   
   var delegate: IaphubTestsDelegate!
   var testSession: SKTestSession!
   
   override func setUpWithError() throws {
      self.testSession = try SKTestSession(configurationFileNamed: "Configuration")
      self.testSession.disableDialogs = true
      self.testSession.clearTransactions()
      self.delegate = IaphubTestsDelegate.shared
      Iaphub.delegate = self.delegate
      Iaphub.start(
         appId: "61718bfd9bf07f0c7d2357d1",
         apiKey: "Usaw9viZNrnYdNSwPIFFo7iUxyjK23K3"
      )
   }

   func test1_getProductsForSale() async throws {
      IHUtil.deleteFromKeychain(key: "iaphub_user_a_61718bfd9bf07f0c7d2357d1")
      IHUtil.deleteFromKeychain(key: "iaphub_user_61718bfd9bf07f0c7d2357d1")
      
      let products = try await Iaphub.getProductsForSale()
      XCTAssertEqual(self.delegate.userUpdateCount, 0)
      XCTAssertEqual(products.count, 1)
      XCTAssertEqual(products[0].sku, "consumable")
      XCTAssertEqual(products[0].type, "consumable")
      XCTAssertEqual(products[0].localizedTitle, "Consumable")
      XCTAssertEqual(products[0].localizedDescription, "This is a consumable")
      XCTAssertEqual(products[0].localizedPrice, "$1.99")
      XCTAssertEqual(products[0].price, 1.99)
      XCTAssertEqual(products[0].currency, "USD")
   }

   func test2_login() async throws {
      try await Iaphub.login(userId: "42")
      XCTAssertEqual(Iaphub.shared.user?.id, "42")
   }

   func test3_buy() async throws {
      
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

   func test4_detectUserUpdate() async throws {
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
                     "isSubscriptionRetryPeriod": false,
                     "isSubscriptionGracePeriod": false,
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

   func test5_restore() async throws {
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
      XCTAssertEqual(self.delegate.processReceiptCount, 2)
   }
   
   func test6_setTags() async throws {
      // Add tag
      try await Iaphub.setUserTags(tags: ["group": "1"])
      XCTAssertEqual(self.delegate.errorCount, 0)
      // Delete tag
      try await Iaphub.setUserTags(tags: ["group": ""])
      XCTAssertEqual(self.delegate.errorCount, 0)
   }
   
   func test7_setDeviceParams() async throws {
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
   
   func test8_getActiveProducts() async throws {
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
                     "subscriptionState": "retry_period",
                     "subscriptionPeriodType": "normal",
                     "isSubscriptionRenewable": true,
                     "isSubscriptionRetryPeriod": true,
                     "isSubscriptionGracePeriod": false,
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
                     "expirationDate": "2023-05-22T01:34:40.462Z",
                     "subscriptionState": "grace_period",
                     "subscriptionPeriodType": "normal",
                     "isSubscriptionRenewable": true,
                     "isSubscriptionRetryPeriod": false,
                     "isSubscriptionGracePeriod": true,
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
      XCTAssertEqual(activeProducts.count, 1)
      XCTAssertEqual(activeProducts[0].sku, "unknown_subscription")
      XCTAssertEqual(activeProducts[0].localizedTitle, nil)
      
      let allActiveProducts = try await Iaphub.getActiveProducts(includeSubscriptionStates: ["retry_period", "paused"])
      XCTAssertEqual(allActiveProducts.count, 2)
      XCTAssertEqual(allActiveProducts[0].localizedTitle, "Renewable subscription")
      XCTAssertEqual(allActiveProducts[1].localizedTitle, nil)
   }
   
   func test9_concurrentFetch() throws {
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

}
