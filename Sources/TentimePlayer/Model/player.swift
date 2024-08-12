//
//  Player.swift
//  PlayerSample
//
//  Created by Qamar Al Amassi on 11/09/2023.
//

import AVFoundation
import CoreGraphics
import AVKit
import Combine
import GoogleInteractiveMediaAds

public enum PipModeStatus: Int {
    case start = 1
    case end = 2
    case restoreUserInterface  = 3
    case stop = 4
   
}

open class TenTimePlayer: NSObject, ObservableObject {
    
    // Create a shared instance as a singleton
    public static let shared = TenTimePlayer()
    internal var player: AVPlayer? = AVPlayer(playerItem: nil)
    private var playerLayer: AVPlayerLayer?
    var playerItem: AVPlayerItem?
    
    var isSeeking = false
    
    var playerData : PlayerData?
    
    public var isCurrentlyPlaying: Bool = true

    var supposedCurrentTime: CMTime?

    var nowPlayable: NowPlayable? = TenTimeNowPlayable()
    
    var timeObserverToken: Any?

    var supportedCommand: [NowPlayableCommand]  = []
    
    var queueItem: [PlayerData] = []
    
    var currentQueueIndex = -1
    
    @Published public var isPlay: Bool = false
    
    @Published public var isLoading: Bool = false
    
    @Published public var didUpdateTime: (String, String, Double, Double)?
    
    @Published public var isPipModeEnabled: Bool = false
    
    @Published public var shouldShowUpNextContent: Bool = false
    
    @Published public var shouldHideUpNextContent: Bool = false

    @Published public var didFinishPlaying: Bool = false
    
    @Published public var pipModeStatus: PipModeStatus?
    
    @Published public var progressValue: Double = 0.0

    @Published public var durationTimeFormatted: String = ""
    
    @Published public var durationSeconds: Double = 0.0

    @Published public var currentTimeFormatted: String = ""

    var remainingTime: Double = 0
    
    var isLoadingVideo: Bool = true
    
    //Ads varibales
    var contentPlayhead: IMAAVPlayerContentPlayhead?
    
     let adTagURLString = "https://pubads.g.doubleclick.net/gampad/ads?iu=/21775744923/external/single_ad_samples&sz=640x480&cust_params=sample_ct%3Dlinear&ciu_szs=300x250%2C728x90&gdfp_req=1&output=vast&unviewed_position_start=1&env=vp&impl=s&correlator="

    var adsLoader: IMAAdsLoader!
    
    var adsManager: IMAAdsManager!
    
    var isAdPlayback = false


    //PIP mode variable
    @objc dynamic var pictureInPictureController: AVPictureInPictureController?
    
    var pictureInPictureProxy: IMAPictureInPictureProxy?

    
    var playerViewControllerKVOContext = 0
    
    public  var isPipModeStarted: Bool = false
    
    //up next content
    var isCanceledUpNextContent: Bool? = nil 
    
    public var showUpNextBefore: Double = 30
    
    public var showUpNextContent: Bool = false

    
    var currentIndex = 0

    public var isMuted: Bool = false {
        didSet {
            player?.isMuted = isMuted
        }
    }
    
    var currentTime: CMTime?
    
    var pipCompletionHandler: ((Bool) -> Void)?

    var nowPlayableDynamicMetadata: NowPlayableDynamicMetadata? {
        didSet {
            nowPlayable?.handleNowPlayablePlaybackChange(playing: isCurrentlyPlaying, metadata: nowPlayableDynamicMetadata)
        }
    }
    
    var nowPlayableStaticMetadata: NowPlayableStaticMetadata? {
        didSet {
            nowPlayable?.handleNowPlayableItemChange(metadata: nowPlayableStaticMetadata)
        }
    }

    private var drmManager: DRMManager

    override init() {
        self.drmManager = DRMManager()
        super.init()
        self.setupCommands(supportedCommand: [.play,.pause,.skipBackward,.skipForward, .changePlaybackPosition])
        self.observePlayCurrentTime()
        guard let player = player else {return}
        contentPlayhead = IMAAVPlayerContentPlayhead(avPlayer: player)
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        setUpAdsLoader()
//        player?.addObserver(self,
//                            forKeyPath: #keyPath(AVPlayer.timeControlStatus),
//                            options: [.new, .old],
//                            context: nil)
//  player?.addObserver(self,
//                             forKeyPath: #keyPath(AVPlayer.rate),
//                             options: [.new, .old],
//                             context: nil)
       
    }
    
   
  
    
    @objc func playerDidFinishPlaying(_ noti: Notification) {
        if let p = noti.object as? AVPlayerItem, p == player?.currentItem {
            pause()
//            didFinishPlaying = true
            
//            if let _ = appDelegate.window?.rootViewController?.topmostViewController() as? PlayerViewController, isAudioSessionUsingAirplayOutputRoute() {
//                return
//            }
//                currentlyPlayingURL = nil
        }
    }

    func observePlayCurrentTime() {
        guard timeObserverToken == nil, !isSeeking else { return }
        let interval = CMTimeMake(value: 1, timescale: 2)
        
        timeObserverToken =  player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] (time) in
            guard let self =  self else {return}
            didUpdateTime = (time.toDisplayString(),
                          self.player?.currentItem?.duration.toDisplayString() ?? "00:00",
                             time.seconds,
                             self.player?.currentItem?.duration.seconds ?? 0.0
                             
            )
            
            
            guard let player = self.player , let playerItem = player.currentItem else {return}
          
            self.currentTime = time
            
            let duration = Float(playerItem.duration.seconds)
            
            self.progressValue = Double((currentTime?.seconds ?? 0) /  Double(duration))

            self.currentTimeFormatted = time.toDisplayString()
            self.durationTimeFormatted =   self.player?.currentItem?.duration.toDisplayString() ?? "00:00"

            let cTime = CMTimeGetSeconds(self.player?.currentTime() ?? CMTime())
            self.nowPlayableDynamicMetadata = NowPlayableDynamicMetadata(rate: player.rate,
                                                                         position: cTime,
                                                                         duration: Float(playerItem.duration.seconds),
                                                                         currentLanguageOptions: [],
                                                                         availableLanguageOptionGroups: [],
                                                                         isLiveStream: false)
            if showUpNextContent {
                handleUpNext(currentTime: currentTime?.seconds ?? 0, duration: Double(duration))
            }
            self.supposedCurrentTime = time
        }
    }
    
    func getPlayer() -> AVPlayer {
        guard let player = player else {return AVPlayer()}
        return player
    }
    
    private func cleanUpObservers() {
        //remove player periodic observer
        if let timeObserverToken = timeObserverToken {
            player?.removeTimeObserver(timeObserverToken)
            self.timeObserverToken = nil
        }
        pictureInPictureController?.removeObserver(self,
                                                   forKeyPath:        #keyPath(AVPictureInPictureController.isPictureInPicturePossible),
                                                   context: &playerViewControllerKVOContext)
//        NotificationCenter.default.removeObserver(self,
//                                                  name:  AVAudioSession.interruptionNotification,
//                                                  object: audioSession)
//        
//        
//        NotificationCenter.default.removeObserver(self,
//                                                  name: .AVPlayerItemDidPlayToEndTime,
//                                                  object: player?.currentItem)
    }
    
    open override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == #keyPath(AVPictureInPictureController.isPictureInPicturePossible) {
            guard let newValue = change?[NSKeyValueChangeKey.newKey] as? NSNumber else {return}
            let isPictureInPicturePossible: Bool = newValue.boolValue
            //update enable status of pip mode
            print("isPictureInPicturePossible ", isPictureInPicturePossible)
            isPipModeEnabled = isPictureInPicturePossible
        }
     }
    
    
   public func endPlayer() {
        player?.pause()
        nowPlayable?.removeNotificationCenter(commands: supportedCommand )
        player?.replaceCurrentItem(with: nil)
        print("end player step")
//        player = nil
//        currentlyPlayingURL = nil
//        cleanUpObservers()
    }
 
 
    public func configureDRM(licenseURL: URL, certificate: Data) {
           drmManager.configureDRM(licenseURL: licenseURL, certificate: certificate)
    }

    deinit {
        cleanUpObservers()
    }

}


extension CMTime{
    func toDisplayString() -> String{
        if CMTimeGetSeconds(self).isNaN {
            return ""
        }
        
        let totalSeconds = Int(CMTimeGetSeconds(self))
        let seconds = totalSeconds % 60
        let minutes = totalSeconds % (60 * 60) / 60
        let hours = totalSeconds / 60 / 60
        if hours == 0 {
            let timeFormatString = String(format: "%02d:%02d", minutes, seconds)
            return timeFormatString
        } else {
            let timeFormatString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            return timeFormatString
        }
    }
}
