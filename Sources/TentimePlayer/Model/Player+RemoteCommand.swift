//
//  Player+RemoterCommand.swift
//  PlayerSample
//
//  Created by Qamar Al Amassi on 18/09/2023.
//

import AVFoundation
import MediaPlayer


extension TenTimePlayer {
    
    func reinstallCommandsMetadeta() {
        addNotificationCenterCommands()
        guard let playerData = playerData else {
            return
        }
        updatePlayableStaticMetdata(playerData)
    }
    
    
    fileprivate func addNotificationCenterCommands() {
        nowPlayable?.handleNowPlayableConfiguration(commands: supportedCommand, disabledCommands: []) {[weak self] command, event in
            guard let self = self else {return .commandFailed}
            switch command {
            case .play:
                self.play()
//                self.delegate?.didPlayFromRemoteControl()
            case .pause:
                self.pause()
//                self.delegate?.didPauseFromRemoteControl()
            case .skipForward:
                DispatchQueue.main.async {
                    self.seekToCurrentTime(delta: 10)
                }
            case .skipBackward:
                DispatchQueue.main.async {
                    self.seekToCurrentTime(delta: -10)
                }
            case .changePlaybackPosition:
                guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
                self.player?.seek(to: CMTime(seconds: event.positionTime, preferredTimescale: 1))
            default:
                ()
            }
            return .success
        }
    }
    
    func setupCommands(isAudio: Bool = false) {
        if !isAudio {
            supportedCommand = [
                .togglePausePlay,
                .play,
                .pause,
                .seekForward,.seekBackward]
        }else {
            supportedCommand = [
                .togglePausePlay,
                .play,
                .pause,
                .nextTrack,
                .previousTrack]
        }
        
//        let extraCommands: [NowPlayableCommand] = [
//            .skipBackward,
//            .skipForward,
//            .changePlaybackPosition]
        
//        if !isLiveStreaming {
//            supportedCommand.append(contentsOf: extraCommands)
//        }
        
        nowPlayable?.handleNowPlayableSessionStart()
        addNotificationCenterCommands()
    }

    internal func updatePlayableStaticMetdata(_ playerData: PlayerData) {
        setupCommands(isAudio: playerData.isAudio   )
        nowPlayableStaticMetadata = NowPlayableStaticMetadata(assetURL: playerData.moviePath,
                                                              mediaType: .video,
                                                              isLiveStream: false,
                                                              title: playerData.movieName,
                                                              artist: nil,
                                                              artwork: playerData.thumbImage,
                                                              albumArtist: nil,
                                                              albumTitle: nil)
    }
    
    
 
    
    
}
