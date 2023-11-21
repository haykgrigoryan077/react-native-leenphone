import React, { useEffect, useState } from 'react'

import {
  initialise,
  unregister,
  login,
  call,
  sendDtmf,
  hangup,
  useCall,
  useAudioDevices,
  setAudioDevice,
  toggleMute,
  AudioDevices,
  TransportType,
} from 'react-native-leenphone'
import { StyleSheet, View, Button, TextInput } from 'react-native'

type CallState =
  | 'initial'
  | 'requested'
  | 'ringing'
  | 'in-progress'
  | 'released'

interface LoginProps {
  setLoggedIn: (authState: boolean) => void
}

function Login(props: LoginProps) {
  const [domain, setDomain] = React.useState('')
  const [password, setPassword] = React.useState('')
  const [username, setUsername] = React.useState('')
  const { setLoggedIn } = props

  useEffect(() => {
    initialise().then()
    return () => {
      unregister().then()
    }
  }, [])

  function handleLogin() {
    login(username, password, domain, TransportType.Tcp)
      .then(() => setLoggedIn(true))
      .catch((e) => {
        console.log(e)
        setLoggedIn(false)
      })
  }

  return (
    <View>
      <TextInput
        autoCapitalize="none"
        onChangeText={setDomain}
        placeholder="SIP Domain"
        style={styles.input}
        textContentType="URL"
        value={domain}
      />
      <TextInput
        autoCapitalize="none"
        onChangeText={setUsername}
        placeholder="Username"
        style={styles.input}
        textContentType="username"
        value={username}
      />
      <TextInput
        autoCapitalize="none"
        autoCorrect={false}
        onChangeText={setPassword}
        placeholder="Password"
        secureTextEntry
        style={styles.input}
        textContentType="password"
        value={password}
      />
      <Button
        onPress={handleLogin}
        title="Login"
        disabled={!(domain && username && password)}
      />
    </View>
  )
}

function PhoneCall() {
  const [micEnabled, toggleMicEnabled] = useState(true)
  const [callState, setCallState] = React.useState<CallState>('initial')
  const [remoteUri, setRemoteUri] = React.useState('')
  const [dtmf, setDtmf] = React.useState('')
  const [audioDevices, _setAudioDevice] = React.useState<AudioDevices | null>(
    null
  )

  const canCall = remoteUri && callState === 'initial'
  const canHangUp = ['ringing', 'in-progress'].includes(callState)

  useAudioDevices((devices) => {
    console.log(devices)
    _setAudioDevice(devices)
  })

  useCall({
    onCallRequested: () => setCallState('requested'),
    onCallRinging: () => setCallState('ringing'),
    onCallConnected: () => setCallState('in-progress'),
    onCallReleased: () => {
      setCallState('released')
      setTimeout(() => setCallState('initial'), 200)
    },
  })

  function outboundCall() {
    call(remoteUri).then()
  }

  return (
    <View>
      <TextInput
        autoCapitalize="none"
        onChangeText={setRemoteUri}
        placeholder="Remote SIP URI"
        style={styles.input}
        textContentType="emailAddress"
        value={remoteUri}
      />
      <TextInput
        autoCapitalize="none"
        onChangeText={setDtmf}
        placeholder="CallerID"
        style={styles.input}
        textContentType="telephoneNumber"
        value={dtmf}
      />
      <View style={styles.callButtonContainer}>
        <View style={styles.callButton}>
          <Button
            onPress={outboundCall}
            title="Call with remote uri"
            disabled={!canCall}
          />
        </View>
        <View style={styles.callButton}>
          <Button
            onPress={() => {
              sendDtmf(dtmf).then()
            }}
            title="Call with dtmf"
            disabled={!canCall}
          />
        </View>
        <View style={styles.callButton}>
          <Button onPress={hangup} title="Hang up" disabled={!canHangUp} />
        </View>
      </View>
      <View style={styles.audioButtonContainer}>
        <View style={styles.audioButton}>
          <Button
            onPress={() => setAudioDevice('bluetooth')}
            title="Bluetooth"
            disabled={!audioDevices?.options.bluetooth}
          />
        </View>
        <View style={styles.audioButton}>
          <Button
            onPress={() => setAudioDevice('loudspeaker')}
            title="Loudspeaker"
            disabled={!audioDevices?.options.loudspeaker}
          />
        </View>
        <View style={styles.audioButton}>
          <Button
            onPress={() => setAudioDevice('phone')}
            title="Phone"
            disabled={!audioDevices?.options.phone}
          />
        </View>
        <View style={styles.audioButton}>
          <Button
            onPress={() => {
              toggleMute().then(() => {
                toggleMicEnabled(!micEnabled)
              })
            }}
            title={micEnabled ? 'Mute' : 'Unmute'}
          />
        </View>
      </View>
    </View>
  )
}

export default function SIPDemo() {
  const [loggedIn, setLoggedIn] = React.useState<boolean>(false)

  return (
    <View style={styles.container}>
      {!loggedIn && <Login setLoggedIn={setLoggedIn} />}
      {loggedIn && <PhoneCall />}
    </View>
  )
}

const styles = StyleSheet.create({
  audioButton: {
    margin: 3,
  },
  audioButtonContainer: {
    marginLeft: 'auto',
    marginRight: 'auto',
  },
  callButton: {
    width: 100,
    height: 60,
    margin: 20,
  },
  callButtonContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
  },
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'space-around',
    paddingVertical: 100,
  },
  input: {
    borderRadius: 6,
    borderWidth: 1,
    margin: 6,
    marginLeft: 'auto',
    marginRight: 'auto',
    width: 300,
    padding: 12,
  },
})
