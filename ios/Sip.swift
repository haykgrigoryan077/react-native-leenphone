import linphonesw
import React

@objc(Sip)
class Sip: RCTEventEmitter {
    private var mCore: Core!
    private var mRegistrationDelegate : CoreDelegate!

    private var bluetoothMic: AudioDevice?
    private var bluetoothSpeaker: AudioDevice?
    private var earpiece: AudioDevice?
    private var loudMic: AudioDevice?
    private var loudSpeaker: AudioDevice?
    private var microphone: AudioDevice?

    var isCallIncoming : Bool = false
    var isCallRunning : Bool = false

    /*------------ Callkit tutorial related variables ---------------*/
    let incomingCallName = "Incoming call example"
    var mCall : Call?
    var mProviderDelegate : CallKitProviderDelegate!
    var mCallAlreadyStopped : Bool = false;

    func stopCall() {
        // Use the flag to prevent this function from running more than once per call
        if (mCallAlreadyStopped) { return }
    
        // Report to CallKit that the call is over
        if (self.isCallRunning) {
            self.mProviderDelegate.stopCall()
        }
    
        // Mark as stopped to avoid race conditions and redundant calls
        mCallAlreadyStopped = true
        // Also reset your other state variables
        isCallRunning = false
        isCallIncoming = false
        mCall = nil
    }

    @objc func delete() {
        // To completely remove an Account
        if let account = mCore.defaultAccount {
            mCore.removeAccount(account: account)

            // To remove all accounts use
            mCore.clearAccounts()

            // Same for auth info
            mCore.clearAllAuthInfo()
        }}

    @objc func sendEvent( eventName: String, body: NSDictionary? = nil ) {
        self.sendEvent(withName:eventName, body:body);
    }

    @objc(initialise:withRejecter:)
    func initialise(resolve:RCTPromiseResolveBlock,reject:RCTPromiseRejectBlock) {
        do {
            LoggingService.Instance.logLevel = LogLevel.Debug

            try? mCore = Factory.Instance.createCore(configPath: "", factoryConfigPath: "", systemContext: nil)
            
            // FIX: Assign empty string "" instead of nil to prevent type error.
            mCore.remoteRingbackTone = ""
            
            mProviderDelegate = CallKitProviderDelegate(context: self)
            mCore.callkitEnabled = true
            mCore.pushNotificationEnabled = true
            try? mCore.start()

            // Create a Core listener to listen for the callback we need
            // In this case, we want to know about the account registration status
            mRegistrationDelegate = CoreDelegateStub(
                onCallStateChanged: {(
                  core: Core,
                  call: Call,
                  state: Call.State?,
                  message: String
                ) in
                  switch (state) {
                  case .IncomingReceived:
                      if (!self.isCallIncoming) {
                          self.mCall = call
                          self.isCallIncoming = true
                          self.mCallAlreadyStopped = false // Reset flag for new call
                          self.mProviderDelegate.incomingCall()
                      }
                      self.sendEvent(eventName: "IncomingReceived")

                   case .OutgoingInit:
                      self.mCallAlreadyStopped = false // Reset flag for new call
                      self.sendEvent(eventName: "ConnectionRequested")
                case .OutgoingProgress:
                      self.sendEvent(eventName: "CallRequested")
                  case .OutgoingRinging:
                      self.sendEvent(eventName: "CallRinging")
                case .Connected:
                      self.isCallIncoming = false
                      self.isCallRunning = true
                      self.sendEvent(eventName: "CallConnected")
                case .StreamsRunning:
                      self.sendEvent(eventName: "CallStreamsRunning")
                case .Paused:
                      self.sendEvent(eventName: "CallPaused")
                case .PausedByRemote:
                      self.sendEvent(eventName: "CallPausedByRemote")
                  case .Updating:
                      self.sendEvent(eventName: "CallUpdating")
                  case .UpdatedByRemote:
                      self.sendEvent(eventName: "CallUpdatedByRemote")
                  case .Released:
                      self.sendEvent(eventName: "CallReleased")
                      self.stopCall()
                  case .Error:
                      self.sendEvent(eventName: "CallError")
                      self.stopCall()
                  case .End:
                      self.sendEvent(eventName: "CallEnd")
                      self.stopCall()
                  case .PushIncomingReceived:
                      if (!self.isCallIncoming) {
                          self.mCall = call
                          self.isCallIncoming = true
                          self.mCallAlreadyStopped = false // Reset flag for new call
                          self.mProviderDelegate.incomingCall()
                      }
                      self.sendEvent(eventName: "CallPushIncomingReceived")
                default:
                      NSLog("")
                  }
                },
                onAudioDevicesListUpdated: { (core: Core) in
                    self.sendEvent(eventName: "AudioDevicesChanged")
                },
                onAccountRegistrationStateChanged: {(
                    core: Core,
                    account: Account,
                    state: RegistrationState,
                    message: String
                ) in
                    let coreMap: NSDictionary = [
                        "accountCreatorUrl": core.accountCreatorUrl,
                        "adaptiveRateAlgorithm": core.adaptiveRateAlgorithm,
                        "httpProxyHost": core.httpProxyHost,
                        "identity": core.identity,
                        "stunServer": core.stunServer,
                        "mediaDevice": core.mediaDevice,
                        "primaryContact": core.primaryContact,
                        "remoteRingbackTone": core.remoteRingbackTone,
                        "provisioningUri": core.provisioningUri,
                        "rootCa": core.rootCa,
                        "tlsCert": core.tlsCert,
                        "tlsCertPath": core.tlsCertPath,
                        "tlsKey": core.tlsKey,
                        "tlsKeyPath": core.tlsKeyPath,
                    ]

                    let accountMap: NSDictionary = [
                        "contactAddressDomain": account.contactAddress?.domain as Any,
                        "contactAddressUsername": account.contactAddress?.username as Any,
                        "contactAddressDisplayName": account.contactAddress?.displayName as Any,
                        "contactAddressPassword": account.contactAddress?.password as Any,
                    ]

                    let body: NSDictionary = ["core": coreMap, "account": accountMap, "state": String(describing:state), "message": message]
                    self.sendEvent(eventName: "AccountRegistrationStateChanged", body:body )

                })
            mCore.addDelegate(delegate: mRegistrationDelegate)
            resolve(true)
        }}

    @objc(login:withPassword:withDomain:withTransport:withResolver:withRejecter:)
    func login(username: String, password: String, domain: String, transport: Int ,resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        do {
            var _transport = TransportType.Tcp
            if (transport == 0) { _transport = TransportType.Udp }
            if (transport == 2) { _transport = TransportType.Tls }
            if (transport == 3) { _transport = TransportType.Dtls }

            let authInfo = try Factory.Instance.createAuthInfo(username: username, userid: "", passwd: password, ha1: "", realm: "", domain: domain)
            let accountParams = try mCore.createAccountParams()
            let identity = try Factory.Instance.createAddress(addr: String("sip:" + username + "@" + domain))
            try! accountParams.setIdentityaddress(newValue: identity)

            let address = try Factory.Instance.createAddress(addr: String("sip:" + domain))
            try address.setTransport(newValue: _transport)
            try accountParams.setServeraddress(newValue: address)

            accountParams.registerEnabled = true
            accountParams.pushNotificationAllowed = true
            accountParams.pushNotificationConfig?.provider = "apns.dev"
            
            let account = try mCore.createAccount(params: accountParams)
            
            mCore.addAuthInfo(info: authInfo)
            try mCore.addAccount(account: account)
            
            mCore.defaultAccount = account

            resolve(nil)
        } catch { 
            NSLog(error.localizedDescription)
            reject("Login error", "Could not log in", error)
        }
    }

    @objc(bluetoothAudio:withRejecter:)
    func bluetoothAudio(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        if let mic = self.bluetoothMic {
            mCore.inputAudioDevice = mic
        }
        if let speaker = self.bluetoothSpeaker {
            mCore.outputAudioDevice = speaker
        }
        resolve(true)
    }

    @objc
    override func supportedEvents() -> [String]! {
        return ["ConnectionRequested", "CallRequested", "CallRinging", "CallConnected", "CallStreamsRunning", "CallPaused", "CallPausedByRemote", "CallUpdating", "CallUpdatedByRemote", "CallReleased", "CallError", "AudioDevicesChanged",
                "CallEnd", "CallPushIncomingReceived", "AccountRegistrationStateChanged", "IncomingReceived"]
    }

    @objc(unregister:withRejecter:)
    func unregister(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock)
    {
        if let account = mCore.defaultAccount {
            let params = account.params
            let clonedParams = params?.clone()
            clonedParams?.registerEnabled = false
            account.params = clonedParams
            mCore.removeAccount(account: account)
            mCore.clearAllAuthInfo()
        }
    }

    @objc(hangUp:withRejecter:)
    func hangUp(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        NSLog("Trying to hang up")
        do {
            if (mCore.callsNb == 0) { return }
            self.mCall = (mCore.currentCall != nil) ? mCore.currentCall : mCore.calls[0]
            if let call = self.mCall {
                try call.terminate()
            } else {
                reject("No call", "No call to terminate", nil)
            }
        } catch {
            NSLog(error.localizedDescription)
            reject("Call termination failed", "Call termination failed", error)
        }
    }

    @objc(loudAudio:withRejecter:)
    func loudAudio(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        if let mic = loudMic {
            mCore.inputAudioDevice = mic
        } else if let mic = self.microphone {
            mCore.inputAudioDevice = mic
        }
        if let speaker = loudSpeaker {
            mCore.outputAudioDevice = speaker
        }
        resolve(true)
    }

    @objc(micEnabled:withRejecter:)
    func micEnabled(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        resolve(mCore.micEnabled)
    }

    @objc(outgoingCall:withResolver:withRejecter:)
    func outgoingCall(recipient: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        do {
            let remoteAddress = try Factory.Instance.createAddress(addr: recipient)
            let params = try mCore.createCallParams(call: nil)
            params.mediaEncryption = MediaEncryption.None
            let _ = mCore.inviteAddressWithParams(addr: remoteAddress, params: params)
            resolve(nil)
        } catch { 
            NSLog(error.localizedDescription)
            reject("Outgoing call failure", "Something has gone wrong", error)
        }
    }

    @objc(phoneAudio:withRejecter:)
    func phoneAudio(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        if let mic = microphone {
            mCore.inputAudioDevice = mic
        }
        if let speaker = earpiece {
            mCore.outputAudioDevice = speaker
        }
        resolve(true)
    }

    @objc(scanAudioDevices:withRejecter:)
    func scanAudioDevices(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        microphone = nil
        earpiece = nil
        loudSpeaker = nil
        loudMic = nil
        bluetoothSpeaker = nil
        bluetoothMic = nil

        for audioDevice in mCore.audioDevices {
            switch (audioDevice.type) {
            case .Microphone:
                microphone = audioDevice
            case .Earpiece:
                earpiece = audioDevice
            case .Speaker:
                if (audioDevice.hasCapability(capability: AudioDeviceCapabilities.CapabilityPlay)) {
                    loudSpeaker = audioDevice
                } else {
                    loudMic = audioDevice
                }
            case .Bluetooth:
                if (audioDevice.hasCapability(capability: AudioDeviceCapabilities.CapabilityPlay)) {
                    bluetoothSpeaker = audioDevice
                } else {
                    bluetoothMic = audioDevice
                }
            default:
                NSLog("Audio device not recognised.")
            }
        }

        let options: NSDictionary = [
            "phone": earpiece != nil && microphone != nil,
            "bluetooth": bluetoothMic != nil || bluetoothSpeaker != nil,
            "loudspeaker": loudSpeaker != nil
        ]

        var current = "phone"
        if (mCore.outputAudioDevice?.type == .Bluetooth || mCore.inputAudioDevice?.type == .Bluetooth) {
            current = "bluetooth"
        } else if (mCore.outputAudioDevice?.type == .Speaker) {
            current = "loudspeaker"
        }

        let result: NSDictionary = [
            "current": current,
            "options": options
        ]
        resolve(result)
    }

    @objc(sendDtmf:withResolver:withRejecter:)
    func sendDtmf(dtmf: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        do {
            try mCore.currentCall?.sendDtmf(dtmf: dtmf.utf8CString[0])
            resolve(true) } catch {
                reject("DTMF not recognised", "DTMF not recognised", error)
            }
    }

    @objc(toggleMute:withRejecter:)
    func toggleMute(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        mCore.micEnabled = !mCore.micEnabled
        resolve(mCore.micEnabled)
    }

    @objc func configureAudioSession() {
        mCore.configureAudioSession()
    }

    @objc(activateAudioSession:)
    func activateAudioSession(actived: Bool) {
        mCore.activateAudioSession(actived: actived)
    }

    @objc(holdCall:withRejecter:)
    func holdCall(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard let call = mCore.currentCall ?? mCore.calls.first else {
            reject("no_call", "There is no active call to put on hold.", nil)
            return
        }
        
        do {
            try call.pause()
            resolve(true)
        } catch {
            NSLog("Failed to hold call: \(error.localizedDescription)")
            reject("hold_error", "Could not put the call on hold.", error)
        }
    }

    @objc(resumeCall:withRejecter:)
    func resumeCall(resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard let call = mCore.calls.first(where: { $0.state == .Paused }) else {
            reject("no_paused_call", "There is no paused call to resume.", nil)
            return
        }
        
        do {
            try call.resume()
            resolve(true)
        } catch {
            NSLog("Failed to resume call: \(error.localizedDescription)")
            reject("resume_error", "Could not resume the call.", error)
        }
    }

    @objc(transferCall:withResolver:withRejecter:)
    func transferCall(uri: String, resolve: RCTPromiseResolveBlock, reject: RCTPromiseRejectBlock) {
        guard let call = mCore.currentCall ?? mCore.calls.first else {
            reject("no_call", "There is no active call to transfer.", nil)
            return
        }
        
        do {
            try call.transfer(referTo: uri)
            resolve(true)
        } catch {
            NSLog("Failed to transfer call: \(error.localizedDescription)")
            reject("transfer_error", "Could not transfer the call.", error)
        }
    }
}