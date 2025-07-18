//
//  ProviderDelegate.swift
//  CallTutorial
//
//  Created by QuentinArguillere on 05/08/2020.
//  Copyright © 2020 BelledonneCommunications. All rights reserved.
//

import Foundation
import CallKit
import linphonesw
import AVFoundation


class CallKitProviderDelegate : NSObject
{
    private let provider: CXProvider
    let mCallController = CXCallController()
    weak var tutorialContext : Sip!    
    var incomingCallUUID : UUID!
    
    init(context: Sip)
    {
        tutorialContext = context
        let providerConfiguration = CXProviderConfiguration(localizedName: Bundle.main.infoDictionary!["CFBundleName"] as! String)
        providerConfiguration.supportsVideo = true
        providerConfiguration.supportedHandleTypes = [.generic]
        
        providerConfiguration.maximumCallsPerCallGroup = 1
        providerConfiguration.maximumCallGroups = 1
        
        provider = CXProvider(configuration: providerConfiguration)
        super.init()
        provider.setDelegate(self, queue: nil) // The CXProvider delegate will trigger CallKit related callbacks
        
    }
    
    func incomingCall()
    {
        incomingCallUUID = UUID()
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type:.generic, value: tutorialContext.incomingCallName)
        
        provider.reportNewIncomingCall(with: incomingCallUUID, update: update, completion: { error in }) // Report to CallKit a call is incoming
    }
    
    func stopCall()
    {
    // Safely unwrap the UUID. If it's nil (for an outgoing call), do nothing.
    guard let uuid = incomingCallUUID else { return }
    
    let endCallAction = CXEndCallAction(call: uuid)
    let transaction = CXTransaction(action: endCallAction)
    
    mCallController.request(transaction, completion: { error in }) // Report to CallKit a call must end
    }
    
}


// In this extension, we implement the action we want to be done when CallKit is notified of something.
// This can happen through the CallKit GUI in the app, or directly in the code (see, incomingCall(), stopCall() functions above)
extension CallKitProviderDelegate: CXProviderDelegate {
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
    // 1. Check if call is already being stopped.
    if (tutorialContext.mCallAlreadyStopped) {
        action.fulfill()
        return
    }

    guard let call = tutorialContext.mCall, (call.state != .End && call.state != .Released) else {
        action.fulfill()
        return // No call or call already ended.
    }

    // 2. Set the flag to "claim" the termination action.
    tutorialContext.mCallAlreadyStopped = true

    do {
        try call.terminate()
    } catch {
        NSLog("Failed to terminate call from CallKit: \(error.localizedDescription)")
        tutorialContext.mCallAlreadyStopped = false // Reset flag on failure
    }
    
    action.fulfill()
}
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        do {
            // The audio stream is going to start shortly: the AVAudioSession must be configured now.
            // It is worth to note that an application does not have permission to configure the
            // AVAudioSession outside of this delegate action while it is running in background,
            // which is usually the case in an incoming call scenario.
            tutorialContext.configureAudioSession();
            try tutorialContext.mCall?.accept()
            tutorialContext.isCallRunning = true
        } catch {
            print(error)
        }
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
        guard let call = tutorialContext.mCall else {
            action.fail()
            return
        }

        do {
            // Check if the action is to place the call on hold or to remove it from hold
            if action.isOnHold {
                try call.pause()
            } else {
                try call.resume()
            }
            // IMPORTANT: You must fulfill the action to tell CallKit it was successful.
            action.fulfill()
        } catch {
            NSLog("Failed to set hold state: \(error.localizedDescription)")
            action.fail()
        }
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        // This tutorial is not doing outgoing calls. If it had to do so,
        // configureAudioSession() shall be called from here, just before launching the
        // call.
        // tutorialContext.mCore.configureAudioSession();
        // tutorialContext.mCore.invite("sip:bob@example.net");
        // action.fulfill();
    }
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {}
    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {}
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {}
    func providerDidReset(_ provider: CXProvider) {}
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        // The linphone Core must be notified that CallKit has activated the AVAudioSession
        // in order to start streaming audio.
        tutorialContext.activateAudioSession(actived: true)
    }
    
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        // The linphone Core must be notified that CallKit has deactivated the AVAudioSession.
        tutorialContext.activateAudioSession(actived: false)
    }
}
