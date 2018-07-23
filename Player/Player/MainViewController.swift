//
//  ViewController.swift
//  dddd
//
//  Created by hanqing.mao on 2018/7/18.
//  Copyright © 2018年 hanqing.mao. All rights reserved.
//

import UIKit
import AVFoundation
class MainViewController: UIViewController {

    @IBOutlet weak var seekTime: UITextField!
    @IBOutlet weak var totalTime: UILabel!
    @IBOutlet weak var currentTime: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        PlayManager.preparePlayer("http://sc1.111ttt.cn/2016/1/06/01/199012102390.mp3",periodicTime:{ (current, totoal) in
            self.currentTime.text = "\(current)"
            self.totalTime.text = "\(totoal)"
        }) { (item) in
            
        }
        
    }
      override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        PlayManager.invalidatePlayer()
    }
    deinit{
       
        print("player dismiss")
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func play(_ sender: UIButton) {
        
        sender.isSelected = !sender.isSelected
        if sender.isSelected {
            PlayManager.play()
            return
        }
        
        PlayManager.pause()
        
    }
    @IBAction func pre(_ sender: UIButton) {
        
    }
    
    @IBAction func next(_ sender: UIButton) {
    }
    @IBAction func seek(_ sender: Any) {
        PlayManager.seek(Double(self.seekTime.text ?? "30")!) { (complete) in
               print(" == \(complete)")
        }
    }
    @IBAction func seekTo(_ sender: Any) {
        
        PlayManager.seek(to: CMTime(seconds: (Double(self.seekTime.text ?? "0")! ), preferredTimescale: 1)) { (complete) in
            print("TO == \(complete)")
        }
    }
    @IBAction func replay(_ sender: Any) {
        PlayManager.replay()
    }
}

