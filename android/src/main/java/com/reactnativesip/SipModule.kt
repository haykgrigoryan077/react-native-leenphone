package com.reactnativesip

import android.util.Log
import com.facebook.react.bridge.*

import com.facebook.react.modules.core.DeviceEventManagerModule
import org.linphone.core.*

import android.content.Context
import android.media.AudioManager

import android.os.Handler
import android.os.Looper
import org.linphone.core.LogCollectionState


class SipModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
  private val context = reactContext.applicationContext
  private val packageManager = context.packageManager
  private val reactContext = reactContext

  private var bluetoothMic: AudioDevice? = null
  private var bluetoothSpeaker: AudioDevice? = null
  private var earpiece: AudioDevice? = null
  private var loudMic: AudioDevice? = null
  private var loudSpeaker: AudioDevice? = null
  private var microphone: AudioDevice? = null

  private lateinit var core: Core

  companion object {
    const val TAG = "SipModule"
  }

  override fun getName(): String {
    return "Sip"
  }

  private fun delete() {
    // To completely remove an Account
    val account = core.defaultAccount
    account ?: return
    core.removeAccount(account)

    // To remove all accounts use
    core.clearAccounts()

    // Same for auth info
    core.clearAllAuthInfo()
  }

  private fun sendEvent(eventName: String, body: Any? = null) {
    reactContext.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
    .emit(eventName, body)
  }


  @ReactMethod
  fun addListener(eventName: String) {
    Log.d(TAG, "Added listener: $eventName")
  }

@ReactMethod
fun answer(promise: Promise) {
    core.calls.find { it.state == Call.State.IncomingReceived }?.let { call ->
        try {
            // CRITICAL: Configure call params before accepting
            val params = core.createCallParams(call)
            params?.let { p ->
                p.mediaEncryption = MediaEncryption.None
                p.isVideoEnabled = false
                p.isAudioEnabled = true
                
                // Force audio codecs that work well with Asterisk
                val audioPayloadTypes = core.audioPayloadTypes
                audioPayloadTypes.find { it.mimeType == "PCMU" }?.let { pcmu ->
                    p.setAudioPayloadTypes(listOf(pcmu))
                }
            }
            
            // Accept with explicit params
            call.acceptWithParams(params)
            
            // Set audio devices immediately after accept
            Handler(Looper.getMainLooper()).postDelayed({
                core.inputAudioDevice = microphone ?: core.audioDevices.firstOrNull()
                core.outputAudioDevice = earpiece ?: loudSpeaker ?: core.audioDevices.firstOrNull()
            }, 100)
            
            promise.resolve(null)
        } catch (e: Exception) {
            promise.reject("AnswerError", e.message)
        }
    } ?: promise.reject("NoCall", "No incoming call to answer")
}

  @ReactMethod
  fun bluetoothAudio(promise: Promise) {
    if (bluetoothMic != null) {
      core.inputAudioDevice = bluetoothMic
    }

    if (bluetoothSpeaker != null) {
      core.outputAudioDevice = bluetoothSpeaker
    }

    promise.resolve(true)
  }

  @ReactMethod
  fun hangUp(promise: Promise) {
    Log.i(TAG, "Trying to hang up")
    if (core.callsNb == 0) return

    // If the call state isn't paused, we can get it using core.currentCall
    val call = if (core.currentCall != null) core.currentCall else core.calls[0]
    if (call != null) {
      // Terminating a call is quite simple
      call.terminate()
      promise.resolve(null)
    } else {
      promise.reject("No call", "No call to terminate")
    }
  }

  @ReactMethod
  fun initialise(promise: Promise) {
    val factory = Factory.instance()

    factory.enableLogCollection(LogCollectionState.Enabled)

    factory.setDebugMode(true, "Connected to linphone")

    core = factory.createCore(null, null, context)
    core.start()

    Log.d(TAG, "[initialise] SIP core started")

    val coreListener = object : CoreListenerStub() {
      override fun onAudioDevicesListUpdated(core: Core) {
        sendEvent("AudioDevicesChanged")
      }

      override fun onCallStateChanged(
        core: Core,
        call: Call,
        state: Call.State?,
        message: String
      ) {
        Log.d(TAG, "[onCallStateChanged] state: $state, message: $message")
        when (state) {
          Call.State.IncomingReceived -> {
            val map = Arguments.createMap()
            map.putString("from", call.remoteAddress?.asStringUriOnly())
            sendEvent("CallPushIncomingReceived", map)
          }
          Call.State.OutgoingInit -> sendEvent("ConnectionRequested")
          Call.State.OutgoingProgress -> sendEvent("CallRequested")
          Call.State.OutgoingRinging -> sendEvent("CallRinging")
          Call.State.Connected -> sendEvent("CallConnected")
          Call.State.StreamsRunning -> sendEvent("CallStreamsRunning")
          Call.State.Paused -> sendEvent("CallPaused")
          Call.State.PausedByRemote -> sendEvent("CallPausedByRemote")
          Call.State.Updating -> sendEvent("CallUpdating")
          Call.State.UpdatedByRemote -> sendEvent("CallUpdatedByRemote")
          Call.State.Released -> sendEvent("CallReleased")
          Call.State.Error -> sendEvent("CallError")
          Call.State.End -> sendEvent("CallEnd")
          Call.State.PushIncomingReceived -> sendEvent("CallPushIncomingReceived", null)
          else -> {}
        }
      }

      override fun onAccountRegistrationStateChanged(
        core: Core,
        account: Account,
        state: RegistrationState?,
        message: String
      ) {
        Log.d(TAG, "[onAccountRegistrationStateChanged] state: $state, message: $message")

        val map = Arguments.createMap()

        val coreMap = Arguments.createMap()
        coreMap.putString("accountCreatorUrl", core.accountCreatorUrl)
        coreMap.putString("adaptiveRateAlgorithm", core.adaptiveRateAlgorithm)
        coreMap.putString("httpProxyHost", core.httpProxyHost)
        coreMap.putString("identity", core.identity)
        coreMap.putString("stunServer", core.stunServer)
        coreMap.putString("mediaDevice", core.mediaDevice)
        coreMap.putString("primaryContact", core.primaryContact)
        coreMap.putString("remoteRingbackTone", core.remoteRingbackTone)
        coreMap.putString("provisioningUri", core.provisioningUri)
        coreMap.putString("rootCa", core.rootCa)
        coreMap.putString("tlsCert", core.tlsCert)
        coreMap.putString("tlsCertPath", core.tlsCertPath)
        coreMap.putString("tlsKey", core.tlsKey)
        coreMap.putString("tlsKeyPath", core.tlsKeyPath)
        map.putMap("core", coreMap)

        val accountMap = Arguments.createMap()
        accountMap.putString("contactAddressDomain", account.contactAddress?.domain)
        accountMap.putString("contactAddressUsername", account.contactAddress?.username)
        accountMap.putString("contactAddressDisplayName", account.contactAddress?.displayName)
        accountMap.putString("contactAddressPassword", account.contactAddress?.password)
        map.putMap("account", accountMap)

        map.putString("state", state.toString())
        map.putString("message", message)

        sendEvent("AccountRegistrationStateChanged", map)
      }
    }

    core.addListener(coreListener)
    promise.resolve(null)
  }


  @ReactMethod
  fun login(username: String, password: String, domain: String, transportType: Int, promise: Promise) {
    var _transportType = TransportType.Tcp
    if (transportType == 0) { _transportType = TransportType.Udp }
    if (transportType == 2) { _transportType = TransportType.Tls }
    if (transportType == 3) { _transportType = TransportType.Dtls }

    val authInfo =
      Factory.instance().createAuthInfo(username, null, password, null, null, domain, null)

    val accountParams = core.createAccountParams()

    val identity = Factory.instance().createAddress("sip:$username@$domain")
    accountParams.identityAddress = identity

    val address = Factory.instance().createAddress("sip:$domain")
    address?.transport = _transportType
    accountParams.serverAddress = address
    accountParams.isRegisterEnabled = true

    val account = core.createAccount(accountParams)

    core.addAuthInfo(authInfo)
    core.addAccount(account)

    core.defaultAccount = account

    account.addListener { _, state, message ->
      when (state) {
        RegistrationState.Ok -> {
          promise.resolve(true)
        }
        RegistrationState.Cleared -> {
          promise.resolve(false)
        }
        RegistrationState.Failed -> {
          promise.reject("Authentication error", message)
        }
        else -> {

        }
      }
    }
  }

  @ReactMethod
  fun loudAudio(promise: Promise) {
    if (loudMic != null) {
      core.inputAudioDevice = loudMic
    } else if (microphone != null) {
      core.inputAudioDevice = microphone
    }

    if (loudSpeaker != null) {
      core.outputAudioDevice = loudSpeaker
    }

    promise.resolve(true)
  }

  @ReactMethod
  fun micEnabled(promise: Promise) {
    promise.resolve(core.isMicEnabled)
  }

  @ReactMethod
  fun outgoingCall(recipient: String, promise: Promise) {
    val remoteAddress = Factory.instance().createAddress(recipient)
    if (remoteAddress == null) {
      promise.reject("Invalid SIP URI", "Invalid SIP URI")
    } else {
      val params = core.createCallParams(null)
      params ?: return

      params.mediaEncryption = MediaEncryption.None
      core.inviteAddressWithParams(remoteAddress, params)
      promise.resolve(null)
    }

  }

  @ReactMethod
  fun phoneAudio(promise: Promise) {
    if (microphone != null) {
      core.inputAudioDevice = microphone
    }

    if (earpiece != null) {
      core.outputAudioDevice = earpiece
    }

    promise.resolve(true)
  }

  @ReactMethod
  fun removeListeners(count: Int) {
    Log.d(TAG, "Removed $count listener(s)")
  }

  @ReactMethod
  fun scanAudioDevices(promise: Promise) {
    microphone = null
    earpiece = null
    loudSpeaker = null
    loudMic = null
    bluetoothSpeaker = null
    bluetoothMic = null

    for (audioDevice in core.audioDevices) {
      when (audioDevice.type) {
        AudioDevice.Type.Microphone -> microphone = audioDevice
        AudioDevice.Type.Earpiece -> earpiece = audioDevice
        AudioDevice.Type.Speaker -> if (audioDevice.hasCapability(AudioDevice.Capabilities.CapabilityPlay)) {
          loudSpeaker = audioDevice
        } else {
          loudMic = audioDevice
        }
        AudioDevice.Type.Bluetooth -> if (audioDevice.hasCapability(AudioDevice.Capabilities.CapabilityPlay)) {
          bluetoothSpeaker = audioDevice
        } else {
          bluetoothMic = audioDevice
        }
        else -> {
        }
      }
    }

    val options = Arguments.createMap()
    options.putBoolean("phone", earpiece != null && microphone != null)
    options.putBoolean("bluetooth", bluetoothMic != null || bluetoothSpeaker != null)
    options.putBoolean("loudspeaker", loudSpeaker != null)

    var current = "phone"
    if (core.outputAudioDevice?.type == AudioDevice.Type.Bluetooth || core.inputAudioDevice?.type == AudioDevice.Type.Bluetooth) {
      current = "bluetooth"
    } else if (core.outputAudioDevice?.type == AudioDevice.Type.Speaker) {
      current = "loudspeaker"
    }

    val result = Arguments.createMap()
    result.putString("current", current)
    result.putMap("options", options)
    promise.resolve(result)
  }

  @ReactMethod
  fun sendDtmf(dtmf: String, promise: Promise) {
    core.currentCall?.sendDtmf(dtmf.single())
    promise.resolve(true)
  }

  @ReactMethod
  fun toggleMute(promise: Promise) {
    val micEnabled = core.isMicEnabled
    core.isMicEnabled = !micEnabled
    promise.resolve(!micEnabled)
  }

  @ReactMethod
  fun unregister(promise: Promise) {
    Log.d(TAG, "[unregister] Called")

    if (!::core.isInitialized) {
      Log.e(TAG, "[unregister] Core is not initialized")
      promise.reject("CoreError", "SIP Core not initialized")
      return
    }

    val account = core.defaultAccount
    if (account == null) {
      Log.e(TAG, "[unregister] No default account found")
      promise.reject("AccountError", "No SIP account to unregister")
      return
    }

    Log.d(TAG, "[unregister] Disabling registration")
    val params = account.params.clone()
    params.isRegisterEnabled = false
    account.params = params

    Log.d(TAG, "[unregister] Calling refreshRegisters()")
    core.refreshRegisters()

    Log.d(TAG, "[unregister] Scheduling account removal after delay")
    Handler(Looper.getMainLooper()).postDelayed({
      Log.d(TAG, "[unregister] Removing account and clearing auth info")
      core.removeAccount(account)
      core.clearAllAuthInfo()
      promise.resolve(true)
    }, 1000)
  }


   @ReactMethod
  fun holdCall(promise: Promise) {
    val call = core.currentCall ?: core.calls.firstOrNull()
    if (call == null) {
      promise.reject("NoCall", "No active call to hold")
      return
    }
    val result = call.pause()
    if (result == 0) {
      promise.resolve(true)
    } else {
      promise.reject("HoldError", "Failed to hold call (error code $result)")
    }
  }

  @ReactMethod
  fun resumeCall(promise: Promise) {
    val call = core.currentCall ?: core.calls.firstOrNull()
    if (call == null) {
      promise.reject("NoCall", "No paused call to resume")
      return
    }
    val result = call.resume()
    if (result == 0) {
      promise.resolve(true)
    } else {
      promise.reject("ResumeError", "Failed to resume call (error code $result)")
    }
  }

@ReactMethod
  fun transferCall(targetUri: String, promise: Promise) {
    val call = core.currentCall ?: core.calls.firstOrNull()
    if (call == null) {
      promise.reject("NoCall", "No active call to transfer")
      return
    }

    try {
      val result = call.transfer(targetUri)
      if (result == 0) promise.resolve(true)
      else promise.reject("TransferError", "Failed to transfer call (code $result)")
    } catch (e: Throwable) {
      promise.reject("TransferError", e.message ?: "Unknown error")
    }
  }

  @ReactMethod
fun configureAudioSession(promise: Promise) {
  try {
    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
    audioManager.isSpeakerphoneOn = false
    promise.resolve(true)
  } catch (e: Exception) {
    promise.reject("AudioSessionError", e.message)
  }
}

@ReactMethod
fun activateAudioSession(active: Boolean, promise: Promise) {
  try {
    val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
    if (active) {
      audioManager.mode = AudioManager.MODE_IN_COMMUNICATION
      audioManager.isMicrophoneMute = false
    } else {
      audioManager.mode = AudioManager.MODE_NORMAL
    }
    promise.resolve(true)
  } catch (e: Exception) {
    promise.reject("ActivateAudioError", e.message)
  }
}

@ReactMethod
fun muteCallAudio(muted: Boolean, promise: Promise) {
  try {
    val call = core.currentCall ?: core.calls.firstOrNull()
    if (call == null) {
      promise.reject("NoCall", "No active call to mute")
      return
    }
    
    // Use Linphone's built-in call audio control
    call.speakerVolumeGain = if (muted) 0.0f else 1.0f
    promise.resolve(true)
  } catch (e: Exception) {
    promise.reject("MuteAudioError", e.message)
  }
}

@ReactMethod 
fun setCallOutputVolume(volume: Float, promise: Promise) {
  try {
    val call = core.currentCall ?: core.calls.firstOrNull()
    if (call == null) {
      promise.reject("NoCall", "No active call")
      return
    }
    
    // volume: 0.0f = silent, 1.0f = normal, can go higher for amplification
    call.speakerVolumeGain = volume
    promise.resolve(true)
  } catch (e: Exception) {
    promise.reject("VolumeError", e.message)
  }
}

  @ReactMethod
  fun shutdown(promise: Promise) {
    Log.d(TAG, "[shutdown] Called")
    if (::core.isInitialized) {
      core.stop()
      Log.d(TAG, "[shutdown] SIP core stopped")
    }
    promise.resolve(true)
  }

}