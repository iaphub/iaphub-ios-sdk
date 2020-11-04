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

## How can I be notified of updates?

Watch for new releases by clicking on the watch button in the topbar right next to the star button (select "Releases only")<br/>
Also if you can star the repo it means the world to us 🙏

## Installation

Implementing In-app purchases in your app should be a piece of cake!<br/>

1. Create an account on [IAPHUB](https://www.iaphub.com)

2. Add Iaphub to your Podfile `pod 'Iaphub', '~> 1.0.0'`

3. Run `pod install`

4. Follow the instructions below

## Start
Import `Iaphub` and execute the start method in `application(_:didFinishLaunchingWithOptions:)`<br/>

```swift
import Iaphub

class AppDelegate: UIResponder, UIApplicationDelegate {
   func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
      Iaphub.start(
        // The app id is available on the settings page of your app
        appId: "5e4890f6c61fc971cf46db4d",
        // The (client) api key is available on the settings page of your app
        apiKey: "SDp7aY220RtzZrsvRpp4BGFm6qZqNkNf",
        // App environment (production by default, other environments must be created on the IAPHUB dashboard)
        environment: "production"
      )
      return true
  } 
}
```

## Set user id
Call the `setUserId` method to authenticate an user.<br/>
If no user id is provided IAPHUB will generate an anonymous user id by default (prefixed with 'a_')

⚠ You should provide an id that is non-guessable and isn't public. (Email not allowed)
```swift
  Iaphub.setUserId("1e5494930c48ed07aa275fd2");
```

## Set user tags
Call the `setUserTags` method to update the user tags.<br/>
Tags are a powerful tool that allows you to offer to your users different products depending on custom properties.<br/>

⚠ This method will throw an error if the tag name hasn't been created on the IAPHUB dashboard

```swift
  Iaphub.setUserTags({gender: 'male'}, { (err: IHError?) in
    // On a success the err should be nil
  });
```

## Get products for sale
Call the ``getProductsForSale`` method to get the user's products for sale<br/>
You should use this method when displaying the page with the list of your products for sale.

⚠ If the request fails because of a network issue, the method returns the latest request in cache (if available, otherwise an error is thrown).

```swift
Iaphub.getProductsForSale({ (err: IHError?, products: [IHProduct]?) in
  print(products);
  [
    {
      id: "5e5198930c48ed07aa275fd9",
      type: "renewable_subscription",
      sku: "membership2_tier10",
      group: "3e5198930c48ed07aa275fd8",
      groupName: "subscription_group_1",
      localizedTitle: "Membership",
      localizedDescription: "Become a member of the community",
      localizedPrice: "$9.99",
      price: 9.99,
      currency: "USD",
      subscriptionPeriodType: "normal",
      subscriptionDuration: "P1M"
    },
    {
      id: "5e5198930c48ed07aa275fd9",
      type: "consumable",
      sku: "pack10_tier15",
      localizedTitle: "Pack 10",
      localizedDescription: "Pack of 10 coins",
      localizedPrice: "$14.99",
      price: 14.99,
      currency: "USD"
    }
  ]
})
```

## Get active products
If you're relying on IAPHUB on the client side (instead of using your server with webhooks) to detect if the user has active products (renewable subscriptions or non-consumables), you should use the `getActiveProducts` method when the app is brought to the foreground.<br/>

⚠ If the request fails because of a network issue, the method returns the latest request in cache (if available, otherwise an error is thrown).

```swift
// Add observer to be notified when the app goes to foreground
NotificationCenter.default.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { [weak self] (_) in
  // Get active products
  Iaphub.getActiveProducts({ (err: IHError?, products: [IHActiveProduct]?) in
    print(products);
    [{
      id: "5e5198930c48ed07aa275fd9",
      type: "renewable_subscription",
      sku: "membership1_tier5",
      purchase: "5e5198930c48ed07aa275fe8",
      purchaseDate: "2020-03-11T00:42:28.000Z",
      expirationDate: "2021-03-11T00:42:28.000Z",
      isSubscriptionRenewable: true,
      isSubscriptionRetryPeriod: false,
      group: "3e5198930c48ed07aa275fd8",
      groupName: "subscription_group_1",
      localizedTitle: "Membership",
      localizedDescription: "Become a member of the community",
      localizedPrice: "$4.99",
      price: 4.99,
      currency: "USD",
      subscriptionDuration: "P1M",
      subscriptionPeriodType: "intro",
      subscriptionIntroPrice: "$1.99",
      subscriptionIntroPriceAmount: 1.99,
      subscriptionIntroPayment: "as_you_go",
      subscriptionIntroDuration: "P1M",
      subscriptionIntroCycles: 3
    }]
  })
}
```

#### Check subscription status

When retrieving a subscription from the active products, you should also check if it is in a retry period using the `isSubscriptionRetryPeriod` and `isSubscriptionGracePeriod` properties.<br/>
- On a **retry period with a grace period** the user should still have access to the features offered by the subscription and you should display a message asking for the user to update its payment informations.
- On a **retry period with no grace period** you should restrict the access to the features offered by your subscription and display a message asking for the user to update its payment informations.

More informations on the [IAPHUB documentation](https://iaphub.com/docs/getting-started/manage-subscription-states#subscription-renewal-retry).

## Buy a product
Call the ``buy`` method to buy a product<br/><br/>
ℹ️ The method needs the product sku that you would get from one of the products of `getProductsForSale()`.<br/>
ℹ️ The method will process a purchase as a subscription replace if you currently have an active subscription and you buy a subscription of the same group (product group created on IAPHUB).<br/>

```swift
Iaphub.buy(sku, { (err: IHError?, transaction: IHReceiptTransaction?) in
  // Check error
  if let err = err {
    // Purchase popup cancelled by the user
    if (err.code == "user_cancelled") {
        return
    }
    // The billing is unavailable (An iPhone can be restricted from accessing the Apple App Store)
    else if (err.code == "billing_unavailable") {
        return self.openAlert("In-app purchase not allowed")
    }
    // Couldn't buy product because it has been bought in the past but hasn't been consumed (restore needed)
    else if (err.code == "product_already_owned") {
        return self.openAlert("Product already owned, please restore your purchases in order to fix that issue")
    }
    // The payment has been deferred (awaiting approval from parental control)
    else if (err.code == "deferred_payment") {
        return self.openAlert("Your purchase is awaiting approval from the parental control")
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
    else if (err.code == "receipt_validation_failed") {
        return self.openAlert("We're having trouble validating your transaction, give us some time we'll retry to validate your transaction ASAP!")
    }
    /*
      * The receipt has been processed on IAPHUB but is invalid
      * It could be a fraud attempt, using apps such as Freedom or Lucky Patcher on an Android rooted device
      */
    else if (err.code == "receipt_invalid") {
        return self.openAlert("We were not able to process your purchase, if you've been charged please contact the support (support@myapp.com)")
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
ℹ️ You should display a restore button somewhere in your app (usually on the settings page).<br/>
ℹ️ If you logged in using the `device id`, an user using a new device will have to restore its purchases since the `device id` will be different.

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

## Documentation

### IHProduct
| Prop  | Type | Description |
| :------------ |:---------------:| :-----|
| id | `String` | Product id (From IAPHUB) |
| type | `String` | Product type (Possible values: 'consumable', 'non_consumable', 'subscription', 'renewable_subscription') |
| sku | `String` | Product sku (Ex: "membership_tier1") |
| price | `Decimal = 0` | Price amount (Ex: 12.99) |
| currency | `String?` | Price currency code (Ex: "USD") |
| localizedPrice | `String?` | Localized price (Ex: "$12.99") |
| localizedTitle | `String?` | Product title (Ex: "Membership") |
| localizedDescription | `String?` | Product description (Ex: "Join the community with a membership") |
| group | `String?` | ⚠ Only available if the product as a group<br>Group id (From IAPHUB) |
| groupName | `String?` | ⚠ Only available if the product as a group<br>Name of the product group created on IAPHUB (Ex: "premium") |
| subscriptionPeriodType | `String?` | ⚠ Only available for a subscription<br>Subscription period type (Possible values: 'normal', 'trial', 'intro')<br>If the subscription is active it is the current period otherwise it is the period if the user purchase the subscription |
| subscriptionDuration | `String?` | ⚠ Only available for a subscription<br> Duration of the subscription cycle specified in the ISO 8601 format (Possible values: 'P1W', 'P1M', 'P3M', 'P6M', 'P1Y') |
| subscriptionIntroPrice | `Decimal` | ⚠ Only available for a subscription with an introductory price<br>Introductory price amount (Ex: 2.99) |
| subscriptionIntroLocalizedPrice | `String?` | ⚠ Only available for a subscription with an introductory price<br>Localized introductory price (Ex: "$2.99") |
| subscriptionIntroPayment | `String?` | ⚠ Only available for a subscription with an introductory price<br>Payment type of the introductory offer (Possible values: 'as_you_go', 'upfront') |
| subscriptionIntroDuration | `String?` | ⚠ Only available for a subscription with an introductory price<br>Duration of an introductory cycle specified in the ISO 8601 format (Possible values: 'P1W', 'P1M', 'P3M', 'P6M', 'P1Y') |
| subscriptionIntroCycles | `Int = 0` | ⚠ Only available for a subscription with an introductory price<br>Number of cycles in the introductory offer |
| subscriptionTrialDuration | `String?` | ⚠ Only available for a subscription with a trial<br>Duration of the trial specified in the ISO 8601 format |

### IHActiveProduct (inherit from IHProduct)
| Prop  | Type | Description |
| :------------ |:---------------:| :-----|
| purchase | `String?` | Purchase id (From IAPHUB) |
| purchaseDate | `String?` | Purchase date |
| expirationDate | `Date?` | Subscription expiration date |
| isSubscriptionRenewable | `Bool = false` | True if the auto-renewal is enabled |
| isSubscriptionRetryPeriod | `Bool = false` | True if the subscription is currently in a retry period |
| isSubscriptionGracePeriod | `Bool = false` | True if the subscription is currently in a grace period |

### IHError
| Prop  | Type | Description |
| :------------ |:---------------:| :-----|
| message | `String` | Error message |
| code | `String` | Error code |

## Full example

You should check out the [Example app](https://github.com/iaphub/react-native-iaphub/tree/master/Example).
<br/>
