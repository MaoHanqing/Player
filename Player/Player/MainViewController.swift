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
        PlayManager.prepare(["http://sc1.111ttt.cn:8282/2017/1/11m/11/304112002347.m4a?#.mp3","http://sc1.111ttt.cn/2016/1/06/01/199012102390.mp3","http://sc1.111ttt.cn:8282/2017/1/05m/09/298092040183.m4a?#.mp3","http://sc1.111ttt.cn:8282/2018/1/03m/13/396131202421.m4a?#.mp3"], playerResult:{[weak self](player,result) in
            
            switch result{
            case .readyToPlay:
                self?.play.isEnabled = true
            case.failure(let error):
                print(error)
            case .playing(let current,let total):
                self?.currentTime.text = "\(current)"
                self?.totalTime.text = "\(total)"
//                print("index === \(PlayManager.default.currentPlayItemIndex)")
            case .topOfPlayList:
                print("已经是第一首了")
            case .trailOfPlayList:
                print("最后一首了")
            case .playerStateChange(let state):
                print("======\n \(state) \n")
                switch state{
                case .play,.replay:
                    self?.setSelected(true)
                case .readyToPlay,.wait:
                    break
                default:
                    self?.setSelected(false)
                }
            default:
                break
            }
          
        
        })
       
    }
    func  setSelected(_ selected:Bool)  {
        guard  selected != self.play.isSelected else {
            return
        }
        self.play.isSelected = selected
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
        sender.isSelected = !sender.isSelected
        if sender.isSelected {
            PlayManager.play()
            return
        }
        
        PlayManager.pause()
        
    }
    @IBAction func pre(_ sender: UIButton) {
        PlayManager.last()
    }
    
    @IBAction func next(_ sender: UIButton) {
        PlayManager.next()
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

