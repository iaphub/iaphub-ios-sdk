//
//  Product.swift
//  Example
//
//  Created by Work on 8/30/20.
//

import SwiftUI
import Iaphub

struct ProductView: View {
   @ObservedObject var iap: IAP = .shared
   var product: IHProduct

   var body: some View {
      HStack {
         Text(product.localizedTitle ?? product.sku).font(.headline)
         Text(product.localizedDescription ?? "")
         Text(product.localizedPrice ?? "")
         Spacer()
         if (iap.skuProcessing == product.sku) {
            ProgressView()
         }
      }
      .padding(8)
   }
}

/*
struct ProductView_Previews: PreviewProvider {
    static var previews: some View {
        ProductView()
    }
}
*/
