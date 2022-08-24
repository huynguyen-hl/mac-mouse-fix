//
// --------------------------------------------------------------------------
// LicenseConfig.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under MIT
// --------------------------------------------------------------------------
//

/// This class abstracts away licensing params like the trialDuration or the price, so we can change it easily and optimize these parameters.

// "https://noahnuebling.gumroad.com/l/mmfinapp" "https://noahnuebling.gumroad.com/l/mmfinapp?wanted=true"

import Cocoa
import CocoaLumberjackSwift

@objc class LicenseConfig: NSObject {
    
    /// Constants
    
    static var licenseConfigAddress: String {
        "\(kMFWebsiteAddress)/licenseinfo/config.json"
    }
    
    /// Async init
    
    @objc static func get(onComplete: @escaping (LicenseConfig) -> ()) {
        
        
        /// Create garbage instance
        
        let instance = LicenseConfig()
        
        /// Download licenseConfig.json
        
        let request = URLRequest(url: URL(string: licenseConfigAddress)!, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 10.0)
        
        let task = URLSession.shared.downloadTask(with: request) { url, urlResponse, error in
            
            /// Try to extract instance from downloaded data
            if let url = url {
                do {
                    try fillInstanceAndCacheFromJSON(instance, url)
                    instance.freshness = kMFValueFreshnessFresh
                    onComplete(instance)
                    return
                } catch { }
            }
            
            /// Log
            DDLogInfo("Failed to get LicenseConfig from internet, using cache instead...")
            
            /// Downloading failed, use cache instead
            onComplete(getCached())
        }
        
        task.resume()
    }
    
    /// Cached init
    
    @objc static func getCached() -> LicenseConfig {
        
        /// Get garbage
        
        let instance = LicenseConfig()
        
        /// Fill from cache

        do {
            try fillInstanceFromDict(instance, LicenseConfig.configCache)
            instance.freshness = kMFValueFreshnessCached
        } catch {
            DDLogError("Failed to fill LicenseConfig instance from cache with error \(error). Falling back to hardcoded.")
        }
        
        /// Fallback to hardcoded if no cache
        
        if !instance.isFilled {
            instance.maxActivations = 100
            instance.trialDays = 14
            instance.price = 199
            instance.payLink = "https://noahnuebling.gumroad.com/l/mmfinapp"
            instance.quickPayLink = "https://noahnuebling.gumroad.com/l/mmfinapp?wanted=true"
            instance.isFilled = true
            instance.freshness = kMFValueFreshnessFallback
        }
        
        /// Return
        return instance
    }
    
    /// Garbage Init
    
    override private init() {
        
        /// Don't use this directly! Use the static `get()` funcs instead
        /// Init to garbage
        maxActivations = -1
        trialDays = -1
        price = 99999999
        payLink = ""
        quickPayLink = ""
        freshness = kMFValueFreshnessNone
        isFilled = false
    }
    
    /// Static vars / convenience
    ///     Note: See `Trial.swift` for notes on UserDefaults.
    
    fileprivate static var configCache: [String: Any]? {
        
        /// Cache for the JSON config file we download from the website
        ///     Don't think there's a good reason we store this in userDefaults instead of config.plist. (There is a decent reason in Trial.swift)
        ///     -> TODO: Move this to config.
        
        set {
            Locator.defaults().setValue(newValue, forKey: "License-config")
        }
        get {
            Locator.defaults().value(forKey: "License-config") as? [String: Any]
        }
    }
    
    /// Base vars
    
    /// Define max activations
    ///     I want people to activate MMF on as many of their machines  as they'd like.
    ///     This is just so you can't just share one email address + license key combination on some forum and have everyone use that forever. This is probably totally unnecessary.
    @objc var maxActivations: Int
    @objc var trialDays: Int
    @objc var price: Int
    @objc var payLink: String
    @objc var quickPayLink: String
    @objc var freshness: MFValueFreshness
    
    fileprivate var isFilled: Bool
    
    /// Derived vars
    
    @objc var formattedPrice: String {
        /// We're selling in $ because you can't include tax in price on Gumroad, and with $ ppl expect that more.
        "$\(Double(price)/100.0)"
    }
    
    /// Helper funcs

    private static func fillInstanceAndCacheFromJSON(_ instance: LicenseConfig, _ configURL: URL) throws {
        
        /// Extract dict from json url
        
        var config: [String: Any]? = nil
        let data = try Data(contentsOf: configURL)
        config = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        /// Fill instance from dict
        try fillInstanceFromDict(instance, config)
        
        /// Store dict in cache
        ///     If we successfully filled instance
        LicenseConfig.configCache = config
    }
    
    private static func fillInstanceFromDict(_ instance: LicenseConfig, _ config: [String: Any]?) throws {
        
        /// Get values from dict
        
        guard let maxActivations = config?["maxActivations"] as? Int,
              let trialDays = config?["trialDays"] as? Int,
              let price = config?["price"] as? Int,
              let payLink = config?["payLink"] as? String,
              let quickPayLink = config?["quickPayLink"] as? String
        else {
            throw NSError(domain: MFLicenseConfigErrorDomain, code: Int(kMFLicenseConfigErrorCodeInvalidDict), userInfo: config)
        }
        
        /// Fill instance from dict values
        
        instance.maxActivations = maxActivations
        instance.trialDays = trialDays
        instance.price = price
        instance.payLink = payLink
        instance.quickPayLink = quickPayLink
        instance.isFilled = true
    }
}