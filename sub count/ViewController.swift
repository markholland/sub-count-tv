//
//  ViewController.swift
//  sub count
//
//  Created by mark holland on 09/10/2015.
//  Copyright © 2015 mark holland. All rights reserved.
//

import UIKit
import Foundation

class ViewController: UIViewController,NSURLConnectionDataDelegate,NSURLConnectionDelegate,UITextFieldDelegate {
    
    @IBOutlet weak var resultField: UILabel!
    @IBOutlet weak var userField: UITextField!
    
    let APIKEY : NSString = "YOUR_API_KEY"
    
    let KEY_CHANNEL_NAME    = "channelName"
    let KEY_CHANNEL_ID      = "channelID"
    let KEY_USERNAME        = "username"
    let KEY_COUNT           = "count"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        userField.delegate = self
        
        let tapRecognizer = UITapGestureRecognizer(target: self, action: "handleTap:")
        tapRecognizer.allowedPressTypes = [NSNumber(integer: UIPressType.PlayPause.rawValue)];
        self.view.addGestureRecognizer(tapRecognizer)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("loadDataAndRefreshCount"), name: UIApplicationDidBecomeActiveNotification, object: nil)
        
        loadDataAndRefreshCount()
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        print("viewDidAppear")
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        print("viewWillAppear")
    }
    
    func handleTap(sender: UITapGestureRecognizer) {
        print("handleTap called.")
        if sender.state == .Ended {
            self.resultField.text = "..."
            loadDataAndRefreshCount()
        }
    }
    
    func loadDataAndRefreshCount() -> Void {
        
        if let channelName = loadStringValue(KEY_CHANNEL_NAME) {
            self.userField.text = channelName
            
            // Attempt to load saved ChannelID or username and then load count
            if let channelID = loadStringValue(KEY_CHANNEL_ID) {
                print("ChannelID: ",channelID)
                // self.sendChannelIDToWatch(channelID)
                loadCount(channelID)
            } else if let user = loadStringValue(KEY_USERNAME) {
                print("username: ",user)
                loadCountWithUser(user, validQuery: "")
            } else {
                print("No ChannelID or username available")
            }
        } else { // No saved channel name means neither channelID nor username saved either
            print("No Channel Name available")
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func buttonPressed(sender: AnyObject) {
        
        if let dirty : String = userField.text {
            let user = dirty.stringByReplacingOccurrencesOfString(" ", withString: "", options: NSStringCompareOptions.LiteralSearch, range: nil)
            if dirty.characters.count == 0 {
                return
            } else {
                let validQuery = buildQuery(dirty)
                self.resultField.text = "..."
                if userInputHasChanged(dirty) {
                    //print(dirty, terminator: "")
                    print(user, terminator: "")
                    if saveStringValue(user, key: KEY_USERNAME) {
                        print("Input saved succesfully")
                    } else {
                        print("Error saving input")
                    }
                    // We first consider the input as a username, if it fails we use the input as a valid query.
                    loadCountWithUser(user, validQuery: validQuery)
                } else if let channelID = loadStringValue(KEY_CHANNEL_ID) {
                    loadCount(channelID)
                }
            }
        }
    }
    
    // Used to prepare the query such that the API call will
    // ask for results that match the exact user input
    func buildQuery(dirty:String) -> String {
        
        let itemArray = dirty.componentsSeparatedByString(" ")
        var clean = "%22"
        
        for item in itemArray {
            clean += item + "+"
        }
        
        clean += "%22"
        
        return clean
        
    }
    
    func userInputHasChanged(inputText : String) -> Bool {
        
        print("userInputHasChanged Called")
        
        if let channelName = loadStringValue(KEY_CHANNEL_NAME) {
            if inputText != channelName {
                return true
            }
        } else { // No saved channel name so first launch
            return true
        }
        
        return false
    }
    
    @IBAction func viewTapped(sender : AnyObject) {
        userField.resignFirstResponder()
        buttonPressed(userField)
    }
    
    func getItemsFromData(data : NSData) -> AnyObject? {
        
        guard let json: NSDictionary! = (try! NSJSONSerialization.JSONObjectWithData(data, options:NSJSONReadingOptions.MutableContainers)) as! NSDictionary else {
            print("No Valid JSON in data")
            return nil
        }
        
        guard let items = json["items"] else {
            print("No items data")
            return nil
        }
        
        return items
    }
    
    func getChannelIDfromJson(items : AnyObject) -> String? {
        
        //print(items)
        
        guard let snippet : NSDictionary = items[0]["snippet"] as? NSDictionary else {
            print("No snippet dictionary found in JSON")
            return nil
        }
        
        if let channelID : String = snippet.valueForKey("channelId") as? String  {
            return channelID
        } else if let id : String = items[0].valueForKey("id") as? String  {
            return id
        }
        
        print("No channelID found in JSON")
        
        return nil
        
    }
    
    func getChannelNamefromJson(items : AnyObject) -> String? {
        
        guard let snippet : NSDictionary = items[0]["snippet"] as? NSDictionary else {
            print("No snippet dictionary found in JSON")
            return nil
        }
        
        guard let channelName : String = snippet.valueForKey("title") as? String else {
            print("NO channelName found in JSON")
            return nil
        }
        
        return channelName
    }
    
    func getCountfromJson(items : AnyObject) -> String? {
        
        //print(items)
        
        guard let statistics : NSDictionary = items[0]["statistics"] as? NSDictionary else {
            print("No statistics dictionary found in JSON")
            return nil
        }
        
        guard let count : String = statistics.valueForKey("subscriberCount") as? String else {
            print("No count found in JSON")
            return nil
        }
        
        return count
    }
    
    func updateUI(channelName : String, count : String) -> Void {
        
        dispatch_async(dispatch_get_main_queue()){
            self.resultField.font = UIFont(name: self.resultField.font.fontName, size: 140)
            let countInt = Int(count)
            let numberFormatter = NSNumberFormatter()
            numberFormatter.numberStyle = NSNumberFormatterStyle.DecimalStyle
            let countFormatted = numberFormatter.stringFromNumber(countInt!)!
            self.resultField.text = "\(countFormatted)"
            self.userField.text = "\(channelName)"
        }
        
    }
    
    func showError(){
        let showAlert = UIAlertController(title: "Oops, I didn't find anything for that YouTube channel or username.", message: "Let me know @subcountapp", preferredStyle: UIAlertControllerStyle.Alert)
        
        showAlert.addAction(UIAlertAction(title: "Close", style: .Default, handler: { (action: UIAlertAction!) in
            // println("Handle Ok logic here")
            self.userField.becomeFirstResponder()
        }))
        
        dispatch_async(dispatch_get_main_queue()){
            self.presentViewController(showAlert, animated: true, completion: nil)
            self.resultField.font = UIFont(name: self.resultField.font.fontName, size: 140)
            self.resultField.text = ""
        }
    }
    
    func loadCountWithUser(user : NSString, validQuery: NSString) {
        print("loadcountWithUser")
        
        let url = "https://www.googleapis.com/youtube/v3/channels?part=statistics%2C+snippet&forUsername=\(user)&key=\(APIKEY)"
        
        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.URL = NSURL(string: url)
        request.HTTPMethod = "GET"
        
        let mySession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        
        let dataTask = mySession.dataTaskWithRequest(request, completionHandler: { (data, response, error) in
            
            if let error = error {
                //print(error)
                dispatch_async(dispatch_get_main_queue()){
                    self.resultField.font = UIFont(name: self.resultField.font.fontName, size: 140)
                    self.resultField.text = "No Internet"
                }
            } else {
                if let items = self.getItemsFromData(data!) {
                    if items.count > 0 {
                        
                        if let count : String = self.getCountfromJson(items) {
                            if let channelID : String = self.getChannelIDfromJson(items) {
                                if let channelName : String = self.getChannelNamefromJson(items) {
                                    self.saveStringValue(count, key: self.KEY_COUNT)
                                    self.saveStringValue(channelID, key: self.KEY_CHANNEL_ID)
                                    self.saveStringValue(channelName, key: self.KEY_CHANNEL_NAME)
                                    
                                    self.updateUI(channelName, count: count)
                                }
                            }
                        }
                    } else {
                        self.loadChannelID(validQuery)
                    }
                    
                } else {
                    print("Parse error")
                }
            }
        })
        dataTask.resume()
        
    }
    
    func loadChannelID(user : NSString){
        print("loadChannelID")
        
        let url = "https://www.googleapis.com/youtube/v3/search?part=snippet&maxResults=1&q=\(user)&key=\(APIKEY)"
        
        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.URL = NSURL(string: url)
        request.HTTPMethod = "GET"
        
        let mySession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        
        let dataTask = mySession.dataTaskWithRequest(request, completionHandler: { (data, response, error) in
            
            if let error = error {
                //print(error)
                dispatch_async(dispatch_get_main_queue()){
                    self.resultField.font = UIFont(name: self.resultField.font.fontName, size: 140)
                    self.resultField.text = "No Internet"
                }
            } else {
                if let items = self.getItemsFromData(data!) {
                    if items.count > 0 {
                        if let channelID = self.getChannelIDfromJson(items) {
                            if let channelName : String = self.getChannelNamefromJson(items) {
                                
                                self.saveStringValue(channelID, key: self.KEY_CHANNEL_ID)
                                self.saveStringValue(channelName, key: self.KEY_CHANNEL_NAME)
                                
                                // Got the channelID now load the count
                                self.loadCount(channelID)
                            }
                        }
                    } else {
                        self.showError()
                        
                    }
                    
                } else {
                    print("error")
                    
                    self.showError()
                }
            }
        })
        dataTask.resume()
        
        
    }
    
    
    func loadCount(channelID : NSString) {
        print("loadCount")
        
        let url = "https://www.googleapis.com/youtube/v3/channels?part=statistics&id=\(channelID)&key=\(APIKEY)"
        
        let request : NSMutableURLRequest = NSMutableURLRequest()
        request.URL = NSURL(string: url)
        request.HTTPMethod = "GET"
        
        let mySession = NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration())
        
        let dataTask = mySession.dataTaskWithRequest(request, completionHandler: { (data, response, error) in
            
            if let error = error {
                //print(error)
                dispatch_async(dispatch_get_main_queue()){
                    self.resultField.font = UIFont(name: self.resultField.font.fontName, size: 140)
                    self.resultField.text = "No Internet"
                }
            } else {
                if let items = self.getItemsFromData(data!) {
                    if items.count > 0 {
                        if let count = self.getCountfromJson(items) {
                            if let channelName = self.loadStringValue(self.KEY_CHANNEL_NAME) {
                                self.saveStringValue(count, key: self.KEY_COUNT)
                                self.saveStringValue(channelName, key: self.KEY_CHANNEL_NAME)
                            
                                self.updateUI(channelName, count: count)
                            }
                        }
                    }
                    
                } else {
                    print("Parse Error")
                }
            }
        })
        dataTask.resume()
    }
    
    func textFieldShouldReturn(userField: UITextField) -> Bool // called when 'return' key pressed. return NO to ignore.
    {
        userField.resignFirstResponder()
        buttonPressed(userField)
        return true;
    }
    
    func loadStringValue(key : String) -> String? {
        
        guard let value = NSUserDefaults.standardUserDefaults().stringForKey(key) else {
            return nil
        }
        
        return value
    }
    
    func saveStringValue(value : String, key : String) -> Bool {
        
        guard let defaults = NSUserDefaults(suiteName: "group.com.partiallogic.subcount") else {
            return false
        }
        
        defaults.setObject(value, forKey: key)
        NSUserDefaults.standardUserDefaults().setObject(value, forKey: key)
        
        return true
        
    }
    
}



extension String {
    
    subscript (i: Int) -> Character {
        return self[self.startIndex.advancedBy(i)]
    }
    
    subscript (i: Int) -> String {
        return String(self[i] as Character)
    }
    
    subscript (r: Range<Int>) -> String {
        return substringWithRange(Range(start: startIndex.advancedBy(r.startIndex), end: startIndex.advancedBy(r.endIndex)))
    }
}


