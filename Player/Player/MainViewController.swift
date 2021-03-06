//
//  ViewController.swift
//
//  Created by hanqing.mao on 2018/7/18.
//  Copyright © 2018年 hanqing.mao. All rights reserved.
//

import UIKit
import AVFoundation
import SVProgressHUD
class MainViewController: UIViewController {


    @IBOutlet weak var currentIndex: UILabel!
    
    @IBOutlet weak var nextItem: UIButton!
    @IBOutlet weak var pre: UIButton!
    @IBOutlet weak var play: UIButton!
    @IBOutlet weak var seekTime: UITextField!
    @IBOutlet weak var totalTime: UILabel!
    @IBOutlet weak var currentTime: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.play.isEnabled = false
        SVProgressHUD.setDefaultStyle(.dark)
        SVProgressHUD.show()
        PlayManager.default.cyclePlay = true
        PlayManager.default.isBackgroundPlay = true

        let urls = [
            PlayerAsset(url: "http://sc1.111ttt.cn:8282/2017/1/11m/11/304112002347.m4a?#.mp3", name: "追光者", subname: "岑宁儿"),
            PlayerAsset(url: "http://sc1.111ttt.cn/2016/1/06/01/199012102390.mp3", name: "小楼一夜听春雨", subname: "任然"),
            PlayerAsset(url: "http://sc1.111ttt.cn:8282/2017/1/05m/09/298092040183.m4a?#.mp3", name: "凉城", subname: "任然"),
            PlayerAsset(url: "http://sc1.111ttt.cn:8282/2018/1/03m/13/396131202421.m4a?#.mp3", name: "佛系少女", subname: "冯提莫")]
        PlayManager.prepare(urls,
                            playerResult:{[weak self](player,result) in
            
            switch result{
            case.failure(let error):
                print(error)
                SVProgressHUD.dismiss()
            case .playing(let current,let total):
                self?.currentTime.text = "\(current)"
                self?.totalTime.text = "\(total)"
            case .playResourceExist(let exist):
                if !exist{
                    SVProgressHUD.show()
                }
            case .playItemIndex(let index):
                self?.currentIndex.text = "\(index)"
                self?.pre.isEnabled = index == 0 ? false :true
                self?.nextItem.isEnabled = index == urls.count - 1 ?  false : true 
            case .playerStateChange(let state):
                print("======\n \(state) \n")
                switch state{
                case .play,.replay:
                    self?.setSelected(true)
                case .readyToPlay:
                    self?.play.isEnabled = true
                    SVProgressHUD.dismiss()
                case .wait:
                    self?.resetUI()
                default:
                    self?.setSelected(false)
                }
            case .prepareToPlay(_):
                print("prepareToPlay")
            case .readyToPlay(_):
                  print("readyToPlay")
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
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.view.endEditing(true)
    }
    func showToast(_ string:String){
        SVProgressHUD.showInfo(withStatus:string)
        SVProgressHUD.dismiss(withDelay: 1.5)
    }
    func resetUI(){
        self.currentTime.text = "0"
        self.totalTime.text = "0"
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
    
        PlayManager.previousTrack()
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
    @IBAction func cleanCache(_ sender: Any) {
        PlayManager.cleanCache()
    }
 
}

