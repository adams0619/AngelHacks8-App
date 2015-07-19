//
//  FirstStartViewController.swift
//  AngelHacksCaitlyn
//
//  Created by Caitlyn Chen on 7/19/15.
//  Copyright (c) 2015 Caitlyn Chen. All rights reserved.
//

import UIKit

class FirstStartViewController: UIViewController {

    @IBOutlet weak var button: CustomButton!
    @IBAction func tapped(sender: AnyObject) {
        
        button.enabled = false
    }
    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        username.attributedPlaceholder = NSAttributedString(string:"Username",
            attributes:[NSForegroundColorAttributeName: UIColor.whiteColor()])
        password.attributedPlaceholder = NSAttributedString(string:"Password",
            attributes:[NSForegroundColorAttributeName: UIColor.whiteColor()])

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
//
//    @IBAction func unwindToVC(segue:UIStoryboardSegue) {
//        if(segue.identifier == "unwind"){
//            
//            
//        }
//        
//    }
}
