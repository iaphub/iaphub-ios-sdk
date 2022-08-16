## Migrate iaphub-ios-sdk 2.X.X to 3.X.X

The version 3 of iaphub-ios-sdk has a new API to detect a free trial or an introductory price.<br/><br/>
We changed it in order to have a common API with the Android SDK.

To update the library, update Iaphub in your podfile
```
pod 'Iaphub', '~> 3.0.1'
```

The only major change is that the following properties are removed:
- subscriptionIntroPrice
- subscriptionIntroLocalizedPrice
- subscriptionIntroPayment
- subscriptionIntroDuration
- subscriptionIntroCycles
- subscriptionTrialDuration

Instead you'll have a property `subscriptionIntroPhases` that is an ordered list containing the intro phases the user is eligible to.<br/><br/>
The list will never contain more than one intro phase since it isn't possible (at least for now).<br/><br/>

So for instance, if you have an introductory price of $4.99 for 3 months, the `subscriptionIntroPhases` property will contain the following:

```js
[
  {
    type: "intro",
    price: 4.99,
    currency: "USD",
    localizedPrice: "$4.99",
    cycleDuration: "P1M",
    cycleCount: 3,
    payment: "as_you_go"
  }
]
```

### Need help?

If you have any questions you can of course contact us at `support@iaphub.com`.