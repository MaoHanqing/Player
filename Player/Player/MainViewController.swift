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

    @IBOutlet weak var play: UIButton!
    @IBOutlet weak var seekTime: UITextField!
    @IBOutlet weak var totalTime: UILabel!
    @IBOutlet weak var currentTime: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.play.isEnabled = false
        PlayManager.prepare("http://sc1.111ttt.cn/2016/1/06/01/199012102390.mp3", playerResult:{[weak self](player,result) in
            
            switch result{
            case .readyToPlay( _):
                self?.play.isEnabled = true
            case.failure(let error):
                print(error)
            case .finish():
                self?.play.isSelected = false
            case .playing(let current,let total):
                self?.currentTime.text = "\(current)"
                self?.totalTime.text = "\(total)"
            }
        })
        
    }
      override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        PlayManager.stop()
    }
    deinit{
       
        print("player dismiss")
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func play(_ sender: UIButton) {
        switch PlayManager.default.state {
        case .pause:
            PlayManager.play()
             sender.isSelected = false
        case .stop:
            PlayManager.replay()
            sender.isSelected = false
        case .play:
            PlayManager.pause()
            sender.isSelected = true
        default:
            break
        }
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
        PlayManager.seek(Double(self.seekTime.text ?? "30")!)
    }
    @IBAction func seekTo(_ sender: Any) {
        
        PlayManager.seek(to: CMTime(seconds: (Double(self.seekTime.text ?? "0")! ), preferredTimescale: 1))
        
    }
    @IBAction func replay(_ sender: Any) {
        PlayManager.replay()
    }
}

