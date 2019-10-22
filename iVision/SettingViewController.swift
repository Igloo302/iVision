//
//  SettingViewController.swift
//  iVision
//
//  Created by banma-1182 on 2019/10/22.
//  Copyright © 2019 Apple. All rights reserved.
//

import UIKit

class SettingViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func close(){
        dismiss(animated:  true, completion: nil)
    }
}
