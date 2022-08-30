<a href="https://www.iaphub.com" title="IAPHUB">
  <img width=882px src="https://www.iaphub.com/img/github/github-ios-ad.png" alt="IAPHUB">
</a>
<br/>
<br/>
Implementing and developping all the tools to manage your In-App purchases properly can be very complex and time consuming.
You should spend this precious time building your app!
<br/>
<br/>

[IAPHUB](https://www.iaphub.com) has all the features you need to increase your sales 🚀

|   | Features |
| --- | --- |
📜 | Receipt validation - Send the receipt, we'll take care of the rest.
📨 | Webhooks - Receive webhooks directly to your server to be notified of any event such as a purchase or a subscription cancellation.    
📊 | Realtime Analytics - Out of the box insights of on all your sales, subscriptions, customers and everything you need to improve your revenues.
🧪 | A/B Testing - Test different pricings and get analytics of which one performs the best.
🌎 | Product Segmentation - Offer different product or pricings to your customers depending on defined criterias such as the country.
👤 | Customer Management - Access easily the details of a customer, everything you need to know such as the past transactions and the active subscriptions on one page.

## Installation

Implementing In-app purchases in your app should be a piece of cake!<br/>

1. Create an account on [IAPHUB](https://www.iaphub.com).

2. Add Iaphub to your Podfile `pod 'Iaphub', '~> 3.0.1'`.

3. Run `pod install`.

4. Make sure the **In-App purchases capability** of your ios project is enabled on XCode

5. Read our complete guide to [set up your app](https://www.iaphub.com/docs/getting-started/set-up-app/).

<br>

⚠ If you're migrating from v2.X.X to v3.X.X, read [this](https://github.com/iaphub/iaphub-ios-sdk/tree/master/guides/migrate-v2-to-v3.md).

## Start
Import `Iaphub` and execute the start method in `application(_:didFinishLaunchingWithOptions:)`<br/>

```swift
import Iaphub

class AppDelegate: UIResponder, UIApplicationDelegate {
   func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
      Iaphub.delegate = self
      Iaphub.start(
        // The app id is available on the settings page of your app
        appId: "5e4890f6c61fc971cf46db4d",
        
        // The (client) api key is available on the settings page of your app
        apiKey: "SDp7aY220RtzZrsvRpp4BGFm6qZqNkNf",
        
        // The user id, if you do not specify one an anonymous id will be generated (id prefixed with 'a:')
        // You can provide it if the user is already logged in on app start
        userId: "42",

        // If you want to allow purchases when the user has an anonymous user id
        // If you're listenning to IAPHUB webhooks your implementation must support users with anonymous user ids
        // This option is disabled by default, when disabled the buy method will return an error when the user isn't logged in
        allowAnonymousPurchase: true
      )
      return true
  }
}
```

## Delegate
IAPHUB is exposing different events, you can listen to them by using the `IaphubDelegate`.<br/>
They are all optional but `didReceiveUserUpdate` is highly recommended in order to know when to refresh the state of your products.

```swift
extension AppDelegate: IaphubDelegate {
    
  func didReceiveUserUpdate() {
    // Called when the user has already been fetch and is updated
    // It means the products for sale or active products are different from the one you previously loaded using getProductsForSale/getActiveProducts
    // You should refresh your view with the new state of your products

    // When using the login/logout method, the user is reset, meaning this event won't be called until the user has been loaded first using the getProductsForSale/getActiveProducts methods
  }

  func didReceiveError(err: IHError) {
    // Called when IAPHUB has detected an error
    // It can be interesting to log unexpected errors
    if (err.code == "unexpected") {
      print("Unexpected error: \(err.localizedDescription)")
    }
  }

  func didReceiveBuyRequest(sku: String) {
    // Called when a purchase intent is made from outside the app (from a promoted In-App purchase for example), IAPHUB is allowing all of them by default
    // If you want to allow/disallow a purchase intent (to wait until the user is logged in for example) you can implement this method
    // You'll have to call the buy method whenever you're ready
    // Also note you'll have a callback to know when the transaction is done (you woudn't otherwise)
    Iaphub.buy(sku: sku, { (err, transaction) in
        
    })
  }

  func didProcessReceipt(_ err: IHError?, _ receipt: IHReceipt?) {
    // Called after a receipt has been processed
  }

}
```

## Login
Call the `login` method to authenticate an user.<br/>

⚠ You should provide an id that is non-guessable and isn't public. (Email not allowed)<br/>

⚠ The user will be reset, `didReceiveUserUpdate` will only be called until after the user has been loaded first (using getProductsForSale/getActiveProducts).<br/>

```swift
Iaphub.login(userId: "3e4890f6c72fc971cf46db5d", { (err: IHError?) in
  // On a success the err should be nil
});
```

## Logout
Call the `logout` method to log the user out.<br/>
The user will switch back to his anonymous user id (prefixed with 'a:').<br/>

⚠ The user will be reset, `didReceiveUserUpdate` will only be called until after the user has been loaded first (using getProductsForSale/getActiveProducts).<br/>

```swift
Iaphub.logout();
```

## Set user tags
Call the `setUserTags` method to update the user tags.<br/>
User tags will appear on the user page of the IAPHUB dashboard.<br/>
When using IAPHUB's [smart listings](https://www.iaphub.com/docs/resources/smart-listing), you'll be able to return different products depending on the user tags.<br/>

⚠ This method will throw an error if the tag name hasn't been created on the IAPHUB dashboard

```swift
// To set a tag
Iaphub.setUserTags(tags: ["gender": "male"], { (err: IHError?) in
  // On a success err should be nil
});

// To remove a tag pass a empty string
Iaphub.setUserTags(tags: ["gender": ""], { (err: IHError?) in
  // On a success err should be nil
});
```

A few details:
  - A tag must be created on the IAPHUB dashboard (otherwise the method will throw an error)
  - When creating a tag on the IAPHUB dashboard you must check the option to allow editing the tag from the client (otherwise you'll only be able to edit the tag using the [IAPHUB API](https://www.iaphub.com/docs/api/post-user) from your server)
  - A tag key is limited to 32 characters
  - A tag value is limited to 64 characters

## Set device params
Call the `setDeviceParams` method to set parameters for the device<br/>
When using IAPHUB's [smart listings](https://www.iaphub.com/docs/resources/smart-listing), you'll be able to return different products depending on the device params.

```swift
// For instance you can provide the app version on app launch
// Useful to return a product only supported in a new version
Iaphub.setDeviceParams(params: ["appVersion": "2.0.0"])
// To clear the device params
Iaphub.setDeviceParams(params: [:])
```

A few details:
  - The params are not saved on the device, they won't persist if the app is restarted
  - The params are not saved on IAPHUB, they are just provided to the API when fetching the products for sale
  - A param key limited to 32 characters and must be a valid key (``^[a-zA-Z_]*$``)
  - A param value limited to 32 characters
  - You can provide up to 5 params

## Get products for sale
Call the ``getProductsForSale`` method to get the user's products for sale<br/>
You should use this method when displaying the page with the list of your products for sale.

⚠ If the request fails because of a network issue, the method returns the latest request in cache (if available, otherwise an error is thrown).

⚠ If a product is returned by the [API](https://www.iaphub.com/docs/api/get-user/) but the sku cannot be loaded, it'll be filtered from the list and an 'unexpected' error will be returned in the `didReceiveError` method.

```swift
Iaphub.getProductsForSale({ (err: IHError?, products: [IHProduct]?) in
  // On a success err should be nil
})
```

## Get active products
If you're relying on IAPHUB on the client side (instead of using your server with webhooks) to detect if the user has active products (auto-renewable subscriptions, non-renewing subscriptions or non-consumables), you should use the `getActiveProducts` method.<br/>

⚠ If the request fails because of a network issue, the method returns the latest request in cache (if available with no expired subscription, otherwise an error is thrown).

⚠ If an active product is returned by the API but the sku cannot be loaded, the product will be returned but only with the properties coming from the [API](https://www.iaphub.com/docs/api/get-user/) (The price, title, description.... properties won't be returned).

#### Subscription state

Value | Description |
| :------------ |:---------------
| active | The subscription is active
| grace_period | The subscription is in the grace period, the user should still access the features offered by your subscription
| retry_period | The subscription is in the retry period, you must restrict the access to the features offered by your subscription and display a message asking for the user to update its payment informations.
| paused | The subscription is paused (Android only) and will automatically resume at a later date (`autoResumeDate` property), you must restrict the access to the features offered by your subscription.

By default only subscriptions with an `active` or `grace_period` state are returned by the `getActiveProducts` method because you must restrict the access to the features offered by your subscription on a `retry_period` or `paused` state.<br/>
<br/>
If you're looking to display a message when a user has a subscription on a `retry_period` or `paused` state, you can use the `includeSubscriptionStates` option.
```swift
  Iaphub.getActiveProducts(includeSubscriptionStates: ["retry_period", "paused"], { (err: IHError?, products: [IHActiveProduct]?) in
    // On a success err should be nil
  })
```

## Buy a product
Call the ``buy`` method to buy a product<br/><br/>
ℹ️ The method needs the product sku that you would get from one of the products of `getProductsForSale`.<br/>

```swift
Iaphub.buy(sku: sku, { (err: IHError?, transaction: IHReceiptTransaction?) in
  // Check error
  if let err = err {
    // Do not do anything if purchase cancelled or product already purchased
    if (err.code == "user_cancelled" || err.code == "product_already_purchased") {
      return
    }
    // The billing is unavailable (An iPhone can be restricted from accessing the Apple App Store)
    else if (err.code == "billing_unavailable") {
        return self.openAlert("In-app purchase not allowed")
    }
    // The product has already been bought but it's owned by a different user, restore needed to transfer it to this user
    else if (err.code == "product_owned_different_user") {
      return self.openAlert("You already purchased this product but it is currently used by a different account, restore your purchases to transfer it to this account")
    }
    // The payment has been deferred (transaction pending, its final status is pending external action)
    else if (err.code == "deferred_payment") {
        return self.openAlert("Purchase awaiting approval, your purchase has been processed but is awaiting approval")
    }
    /*
     * The remote server couldn't be reached properly
     * The user will have to restore its purchases in order to validate the transaction
     * An automatic restore should be triggered on every relaunch of your app since the transaction hasn't been 'finished'
     */
    else if (err.code == "network_error") {
        return self.openAlert("Please try to restore your purchases later (Button in the settings) or contact the support (support@myapp.com)")
    }
    /*
     * The receipt has been processed on IAPHUB but something went wrong
     * It is probably because of an issue with the configuration of your app or a call to the Itunes/GooglePlay API that failed
     * IAPHUB will send you an email notification when a receipt fails, by checking the receipt on the dashboard you'll find a detailed report of the error
     * After fixing the issue (if there's any), just click on the 'New report' button in order to process the receipt again
     * If it is an error contacting the Itunes/GooglePlay API, IAPHUB will retry to process the receipt automatically as well
     */
    else if (err.code == "receipt_failed") {
        return self.openAlert("We're having trouble validating your transaction, give us some time we'll retry to validate your transaction ASAP!")
    }
    /*
     * The receipt has been processed on IAPHUB but is invalid
     * It could be a fraud attempt, using apps such as Freedom or Lucky Patcher on an Android rooted device
     */
    else if (err.code == "receipt_invalid") {
        return self.openAlert("We were not able to process your purchase, if you've been charged please contact the support (support@myapp.com)")
    }
    /*
     * The user has already an active subscription on a different platform (android or ios)
     * This security has been implemented to prevent a user from ending up with two subscriptions of different platforms
     * You can disable the security by providing the 'crossPlatformConflict' parameter to the buy method (Iaphub.buy(sku: sku, crossPlatformConflict: false))
    */
    else if (err.code == "cross_platform_conflict") {
      Alert.alert(
        `Seems like you already have a subscription on a different platform`,
        `You have to use the same platform to change your subscription or wait for your current subscription to expire`
      );
    }
    // Any other error
    return self.openAlert("We were not able to process your purchase, please try again later or contact the support (support@myapp.com)")
  }
  /*
  * The purchase has been successful but we need to check that the webhook to our server was successful as well (if you implemented webhooks)
  * If the webhook request failed, IAPHUB will send you an alert and retry again in 1 minute, 10 minutes, 1 hour and 24 hours.
  * You can retry the webhook directly from the dashboard as well
  */
  if (transaction?.webhookStatus == "failed") {
    self.openAlert("Your purchase was successful but we need some more time to validate it, should arrive soon! Otherwise contact the support (support@myapp.com)")
  }
  // Everything was successful! Yay!
  else {
    self.openAlert("Your purchase has been processed successfully!")
  }
})
```

## Restore user purchases
Call the ``restore`` method to restore the user purchases<br/><br/>
ℹ️ You must display a button somewhere in your app in order to allow the user to restore its purchases.<br/>

```swift
Iaphub.restore({ (err: IHError?) in
  if (err != nil) {
    self.openAlert("Restore failed")
  }
  else {
    self.openAlert("Restore successful")
  }
})
```

## Show manage subscriptions
Call the ``showManageSubscriptions`` to display the App Store manage subscriptions page.<br/><br/>
ℹ️ The user will be redirected to the App Store App on iOS < 15.0, otherwise a modal will appear.<br/>

```swift
Iaphub.showManageSubscriptions({ (err: IHError?) in
  if (err != nil) {
    self.openAlert("Couldn't redirect to the app store, please check your subscriptions directly from the App Store App")
  }
})
```

## Properties

### IHProduct
| Prop  | Type | Description |
| :------------ |:---------------:| :-----|
| id | `String` | Product id (From IAPHUB) |
| type | `String` | Product type (Possible values: 'consumable', 'non_consumable', 'subscription', 'renewable_subscription') |
| sku | `String` | Product sku (Ex: "membership_tier1") |
| price | `Double = 0` | Price amount (Ex: 12.99) |
| currency | `String?` | Price currency code (Ex: "USD") |
| localizedPrice | `String?` | Localized price (Ex: "$12.99") |
| localizedTitle | `String?` | Product title (Ex: "Membership") |
| localizedDescription | `String?` | Product description (Ex: "Join the community with a membership") |
| group | `String?` | ⚠ Only available if the product as a group<br>Group id (From IAPHUB) |
| groupName | `String?` | ⚠ Only available if the product as a group<br>Name of the product group created on IAPHUB (Ex: "premium") |
| subscriptionDuration | `String?` | ⚠ Only available for a subscription<br> Duration of the subscription cycle specified in the ISO 8601 format (Possible values: 'P1W', 'P1M', 'P3M', 'P6M', 'P1Y') |
| subscriptionIntroPhases | `[IHSubscriptionIntroPhase]?` | ⚠ Only available for a subscription<br> Ordered list of the subscription intro phases (intro price, free trial) |

### IHSubscriptionIntroPhase
| Prop  | Type | Description |
| :------------ |:---------------:| :-----|
| type | `String` | Introductory type (Possible values: 'trial', 'intro')  |
| price | `Double` | Introductory price amount (Ex: 2.99) |
| currency | `String` | Introductory price currency code (Ex: "USD") |
| localizedPrice | `String` | Localized introductory price (Ex: "$2.99") |
| cycleCount | `String` | Number of cycles in the introductory offer |
| cycleDuration | `String` | Duration of a introductory cycle specified in the ISO 8601 format (Possible values: 'P1W', 'P1M', 'P3M', 'P6M', 'P1Y') |

### IHActiveProduct (inherit from IHProduct)
| Prop  | Type | Description |
| :------------ |:---------------:| :-----|
| purchase | `String?` | Purchase id (From IAPHUB) |
| purchaseDate | `Date?` | Purchase date |
| platform | `String?` | Platform of the purchase (Possible values: 'ios', 'android') |
| expirationDate | `Date?` | Subscription expiration date |
| isSubscriptionRenewable | `Bool = false` | True if the auto-renewal is enabled |
| isFamilyShare | `Bool = false` | True if the subscription is shared by a family member (iOS subscriptions only) |
| subscriptionRenewalProduct | `String?` | Subscription product id of the next renewal (only defined if different than the current product) |
| subscriptionRenewalProductSku | `String?` | Subscription product sku of the next renewal |
| subscriptionState | `String?` | State of the subscription<br>(Possible values: 'active', 'grace_period', 'retry_period', 'paused') |
| subscriptionPeriodType | `String?` | Current phase type of the subscription<br>(Possible values: 'normal', 'trial', 'intro') |

### IHReceiptTransaction (inherit from IHActiveProduct)
| Prop  | Type | Description |
| :------------ |:---------------:| :-----|
| webhookStatus | `String?` | Webhook status (Possible values: 'success', 'failed', 'disabled') |

### IHError (inherit from LocalizedError)
| Prop  | Type | Description |
| :------------ |:---------------:| :-----|
| message | `String` | Error message |
| code | `String` | Error code |

## Full example

You should check out the [Example app](https://github.com/iaphub/iaphub-ios-sdk/tree/master/Example).
<br/>
