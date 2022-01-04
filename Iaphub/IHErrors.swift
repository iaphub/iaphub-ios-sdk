//
//  IHErrors.swift
//  Iaphub
//
//  Created by iaphub on 3/6/22.
//  Copyright © 2022 iaphub. All rights reserved.
//

import Foundation

protocol IHErrorProtocol {
   
   var code: String { get }
   var message: String { get }
   
}

public enum IHErrors : String, IHErrorProtocol {

   case unexpected = "An unexpected error has happened"
   case network_error = "The remote server request failed"
   case server_error = "The remote server returned an error"
   case billing_unavailable = "The billing is unavailable"
   case anonymous_purchase_not_allowed = "Anonymous purchase are not allowed, identify user using the login method or enable the anonymous purchase option"
   case user_cancelled = "The purchase has been cancelled by the user"
   case deferred_payment = "The payment has been deferred (transaction pending, its final status is pending external action)"
   case product_not_available = "The requested product isn't available for purchase"
   case receipt_failed = "Receipt validation failed, receipt processing will be automatically retried if possible"
   case cross_platform_conflict = "Cross platform conflict detected, an active subscription from another platform has been detected"
   case product_already_purchased = "Product already purchased, it is already an active product of the user"
   case product_change_next_renewal = "The product will be changed on the next renewal date"
   case transaction_not_found = "Transaction not found, the product sku wasn't in the receipt, the purchase failed"
   case user_conflict = "The transaction is successful but it belongs to a different user, a restore might be needed"
   case code_redemption_unavailable = "Presenting the code redemption is not available (only available on iOS 14+)"
   case manage_subscriptions_unavailable = "Manage subscriptions unavailable"
   case user_tags_processing = "The user is currently posting tags, please wait concurrent requests not allowed"
   case restore_processing = "A restore is currently processing"
   case buy_processing = "A purchase is currently processing"

   var code: String {
      get { return String(describing: self) }
   }
   var message: String {
      get { return self.rawValue }
   }
}

enum IHReceiptErrors : String, IHErrorProtocol {

   case receipt_failed = "receipt processing failed"
   case receipt_invalid = "receipt invalid"
   case receipt_stale = "receipt stale, no purchases still valid were found"
   case receipt_expired = "receipt expired"
   case receipt_processing = "receipt currently processing"

   var code: String {
      get { return String(describing: self) }
   }
   var message: String {
      get { return self.rawValue }
   }
}

enum IHNetworkErrors : String, IHErrorProtocol {

   case url_invalid = "url invalid"
   case url_params_invalid = "url params invalid"
   case request_failed = "request failed"
   case storekit_request_failed = "a request by storekit failed"
   case response_invalid = "response invalid"
   case response_empty = "response empty"
   case response_parsing_failed = "response parsing failed"
   case unknown_exception = "unknown exception"

   var code: String {
      get { return String(describing: self) }
   }
   var message: String {
      get { return self.rawValue }
   }
}

enum IHUnexpectedErrors : String, IHErrorProtocol {

   case storekit = "an unexpected storekit error has happened"
   case start_missing = "iaphub not started"
   case receipt_validation_response_invalid = "receipt validation failed, response invalid"
   case product_parsing_failed = "product parsing from data failed"
   case pricing_parsing_failed = "pricing parsing from data failed"
   case receipt_transation_parsing_failed = "receipt transaction parsing from data failed, transaction ignored"
   case get_cache_data_json_parsing_failed = "get cache data json parsing failed"
   case get_cache_data_item_parsing_failed = "error parsing item of cache data"
   case save_cache_data_json_invalid = "cannot save cache date, not a valid json object"
   case save_cache_json_serialization_failed = "cannot save cache date, json serialization failed"
   case save_cache_anonymous_id_failed = "the anonymous id couldn't be saved to keychain or localstorage"
   case api_not_found = "api not found"
   case user_id_invalid = "user id invalid"
   case update_item_parsing_failed = "error parsing item of api in order to update user"
   case product_missing_from_store = "itunes did not return the product, the product has been filtered (https://www.iaphub.com/docs/troubleshooting/product-not-returned)"
   case get_receipt_token_failed = "cannot get receipt token"
   case post_receipt_data_missing = "post receipt data missing"
   case date_parsing_failed = "the parsing of a date failed"
   case property_missing = "a property is missing"
   case restore_timeout = "restore timeout"

   var code: String {
      get { return String(describing: self) }
   }
   var message: String {
      get { return self.rawValue }
   }
}
