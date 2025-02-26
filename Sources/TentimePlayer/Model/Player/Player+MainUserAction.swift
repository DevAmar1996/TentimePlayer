//
//  TenTimePlayer.swift
//
//
//  Created by Qamar Al Amassi on 12/08/2024.
//

import AVFoundation
import UIKit

extension TenTimePlayer {
    @discardableResult
    public func play() -> TenTimePlayer {
        playbackManager.play()
        isCurrentlyPlaying = playbackManager.playbackStatus == .play
        playbackStatus = playbackManager.playbackStatus
        return self
    }

    @discardableResult
    public func pause() -> TenTimePlayer {
        playbackManager.pause()
        isCurrentlyPlaying = playbackManager.playbackStatus == .play
        playbackStatus = playbackManager.playbackStatus
        return self
    }

    @discardableResult
    public func forcePause() -> TenTimePlayer {
        playbackManager.forceStop()
        isCurrentlyPlaying = playbackManager.playbackStatus == .play
        playbackStatus = playbackManager.playbackStatus
        return self
    }


    @discardableResult
    public func mute() -> TenTimePlayer {
        isMuted = true
        playbackManager.mute()
        return self
    }

    @discardableResult
    public func unmute() -> TenTimePlayer {
        isMuted = false
        playbackManager.unmute()
        return self
    }

    @discardableResult
    public func toggleMute() -> TenTimePlayer {
        isMuted.toggle()
        if isMuted {
            playbackManager.mute()
        } else {
            playbackManager.unmute()
        }
        return self
    }

    @discardableResult
    public func togglePlayPause() -> TenTimePlayer {
        playbackManager.togglePlayPause()
        isCurrentlyPlaying = playbackManager.playbackStatus == .play
        return self
    }

    @discardableResult
    public func loadMediContent(_ playerData: PlayerData,
                                autoPlay: Bool = false,
                                mute: Bool = false) -> TenTimePlayer {
        self.playerData = playerData
        loaderManager?.loadMedia(from: playerData) {[weak self] (result: Result<PlayerItemManager?,Error>) in
            guard let self = self else {return}
            switch result {
            case .success(let playerItem):
                DispatchQueue.main.async {
                    self.observeRquiredItem()
                    self.playbackStatus = autoPlay ? .play : .pause
                    self.playerItemManager = playerItem
                    self.playerItemManager?.delegate = self
                    mute ? self.playbackManager.mute() : self.playbackManager.unmute()
                    autoPlay ? self.playbackManager.play() : self.playbackManager.pause()
                    self.player.seek(second: playerData.elapsedTime)
                    self.resetPlayerItemValues()
                    self.notificationCenterManager.updateNowPlayableDynamicMetadata(isCurrentlyPlaying: autoPlay)
                    self.mediaPrepared = true
                    self.isCurrentlyPlaying = autoPlay
                }
            case .failure(let failure):
                //add handling error
                print("issue founded here ", failure)
            }
        }
        return self
    }

    @discardableResult
    public func showNotificationCenter(with commands: [NowPlayableCommand] = [.play, .pause, .seekForward, .skipForward]) -> TenTimePlayer  {
        handleNotificationCenter(supporterdCommand: commands)
        return self
    }

    @discardableResult
    public func removeNotificationCenter() -> TenTimePlayer {
        notificationCenterManager.removeNotificationCenter()
        return self
    }

    fileprivate func skipingHandle(_ delta: Int64) {
        let wasPlay = playbackManager.playbackStatus == .play
        if wasPlay {
            playbackManager.forceStop()
        }
        seekManager.seekToCurrentTime(delta: delta)
        self.handleProgresSeeking(finished: true)
    
    }

    @discardableResult
    public func skipForward(_ delta: Int64 = 10) -> TenTimePlayer {
        skipingHandle(delta)
        return self
    }

    @discardableResult
    public func skipBackrward(_ delta: Int64 = -10) -> TenTimePlayer {
        skipingHandle(delta)
        return self
    }

    @discardableResult
    public func seekByProgress(_ value: Float64) -> TenTimePlayer {
        let wasPlay = isCurrentlyPlaying
        if wasPlay {
            playbackManager.forceStop()
        }
        seekManager.seek(to: value,
                         completion: {[weak self] finished in
            self?.handleProgresSeeking(finished: finished)
        })
        return self
    }

    @discardableResult
    public func seekToEnd() -> TenTimePlayer {
        seekManager.seekToEnd()
        updatePlayerState(for: player.currentItem?.duration ?? .zero)
        return self
    }

    @discardableResult
    public func seekToBegin() -> TenTimePlayer {
        let zeroTime = CMTimeMake(value: 0, timescale: 1)
        seekManager.seekToBeginning()
        updatePlayerState(for: zeroTime)
        didFinishPlaying = false
        return self
    }

    @discardableResult
    public func attachPlayer(to view: UIView,
                             enablePipMode: Bool = false) -> TenTimePlayer {
        playerLayer?.removeFromSuperlayer()
        playerLayer = AVPlayerLayer(player: getPlayer())
        playerLayer?.frame = view.frame
        playerLayer?.zPosition = 100
        playerLayer?.videoGravity = .resizeAspectFill
        view.layer.addSublayer(playerLayer!)
        if enablePipMode {
            pipModeManager?.setupPipMode(playerLayer: playerLayer!)
        }
        return self
    }

    @discardableResult
    public func updateLayerBounds(to frame: CGRect) -> TenTimePlayer {
        playerLayer?.frame = frame
        return self
    }
    public func attachedToParent() -> Bool {
        playerLayer?.superlayer != nil
    }
    
    @discardableResult
    public func startPipMode() -> TenTimePlayer {
        pipModeManager?.startPipMode()
        return self
    }

    @discardableResult
    public func increaseSpeed(to rate: Float) -> TenTimePlayer {
//        let currentRate = player.rate
//        let newRate = currentRate + value
        player.rate = rate
        print("Player speed increased to ", rate)
        return self
    }

    public func currentPlayingContentID() -> String? {
//        let currentRate = player.rate
//        let newRate = currentRate + value
        return playerData?.identifier
    }

    public func playStatus() -> PlaybackStatus {
        return playbackStatus
    }
}
