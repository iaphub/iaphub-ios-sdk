//
//  Store.swift
//  Example
//
//  Created by Work on 8/30/20.
//

import SwiftUI

struct StoreView: View {
   @ObservedObject var iap: IAP = .shared

   var body: some View {
      NavigationView {
         List {
            Section(header: Text("Products for sale")) {
               ForEach(iap.productsForSale, id: \.self) { (product) in
                  Button(action: {
                     iap.buy(product.sku)
                  }, label: {
                     ProductView(product: product)
                  })
               }
            }
            Section(header: Text("Active products")) {
               ForEach(iap.activeProducts, id: \.self) { (product) in
                  Button(action: {
                     iap.buy(product.sku)
                  }, label: {
                     ProductView(product: product)
                  })
               }
            }
         }
         .navigationBarTitle("Products")
      }
      .alert(isPresented: $iap.alertOpen) { () -> Alert in
         let button = Alert.Button.default(Text("OK")) {
            iap.closeAlert()
         }
         return Alert(title: Text(iap.alertMessage), dismissButton: button)
      }
      HStack {
         Button(action: {
            iap.restore()
         }) {
            Text("Restore In-app purchases")
         }
         Divider()
         Button(action: {
            iap.showManageSubscriptions()
         }) {
            Text("Manage subscriptions")
         }
      }
      .frame(width: nil, height: 50, alignment: .bottom)
   }
}

/*
struct StoreView_Previews: PreviewProvider {
    static var previews: some View {
        StoreView()
    }
}
*/
