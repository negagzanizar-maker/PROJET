import { useCallback, useEffect, useState } from 'react'
import './App.css'

interface PlayerManifestAsset {
  contentVersionId: string
  position: number
  mediaKind: 'plainText' | 'jpeg' | 'png' | 'webP' | 'mp4'
  durationMilliseconds: number | null
  loopVideo: boolean
  url: string
}

export interface PlayerManifest {
  desiredStateId: string
  version: number
  assets: PlayerManifestAsset[]
}

export type PlayerPresentation =
  | { kind: 'notLicensed' }
  | { kind: 'noContent'; deviceName?: string }
  | { kind: 'synchronizing'; progress?: number }
  | { kind: 'ready'; manifest: PlayerManifest; authorizationRemainingMilliseconds?: number }

interface PlayerStateResponse {
  status: 'notLicensed' | 'noContent' | 'synchronizing' | 'ready'
  message: string
  deviceId?: string | null
  desiredStateVersion?: number | null
  authorizationExpiresAtUtc?: string | null
  authorizationRemainingMilliseconds?: number | null
}

const safeDefault: PlayerPresentation = { kind: 'notLicensed' }

export interface AppProps {
  presentation?: PlayerPresentation
}

async function loadPresentation(): Promise<PlayerPresentation> {
  const response = await fetch('/player/v1/state', {
    cache: 'no-store',
    credentials: 'same-origin',
  })
  if (!response.ok) throw new Error('player-state-unavailable')
  const state = (await response.json()) as PlayerStateResponse
  if (state.status === 'noContent') return { kind: 'noContent' }
  if (state.status === 'synchronizing') return { kind: 'synchronizing' }
  if (state.status !== 'ready') return safeDefault

  const manifestResponse = await fetch('/player/v1/manifest', {
    cache: 'no-store',
    credentials: 'same-origin',
  })
  if (!manifestResponse.ok) throw new Error('player-manifest-unavailable')
  const manifest = (await manifestResponse.json()) as PlayerManifest
  if (!Array.isArray(manifest.assets) || manifest.assets.length === 0) {
    throw new Error('player-manifest-invalid')
  }

  if (!state.authorizationExpiresAtUtc ||
      !state.authorizationRemainingMilliseconds ||
      state.authorizationRemainingMilliseconds <= 0) {
    return safeDefault
  }

  return {
    kind: 'ready',
    manifest,
    authorizationRemainingMilliseconds: state.authorizationRemainingMilliseconds,
  }
}

function PlainTextAsset({ url }: { url: string }) {
  const [text, setText] = useState('')

  useEffect(() => {
    const abort = new AbortController()
    fetch(url, { cache: 'no-store', credentials: 'same-origin', signal: abort.signal })
      .then((response) => {
        if (!response.ok) throw new Error('text-asset-unavailable')
        return response.text()
      })
      .then(setText)
      .catch(() => setText(''))
    return () => abort.abort()
  }, [url])

  return <pre className="text-content">{text}</pre>
}

function PlaylistPlayer({ manifest }: { manifest: PlayerManifest }) {
  const [position, setPosition] = useState(0)
  const [cycle, setCycle] = useState(0)
  const assets = [...manifest.assets].sort((left, right) => left.position - right.position)
  const asset = assets[position % assets.length]
  const advance = useCallback(() => {
    setPosition((current) => (current + 1) % assets.length)
    setCycle((current) => current + 1)
  }, [assets.length])

  useEffect(() => {
    setPosition(0)
    setCycle(0)
  }, [manifest.desiredStateId, manifest.version])

  useEffect(() => {
    if (!asset.durationMilliseconds) return
    const timeout = window.setTimeout(advance, asset.durationMilliseconds)
    return () => window.clearTimeout(timeout)
  }, [advance, asset.contentVersionId, asset.durationMilliseconds, cycle])

  let media
  if (asset.mediaKind === 'plainText') {
    media = <PlainTextAsset url={asset.url} />
  } else if (asset.mediaKind === 'mp4') {
    media = (
      <video
        key={`${asset.contentVersionId}-${cycle}`}
        className="visual-content"
        src={asset.url}
        autoPlay
        muted
        playsInline
        loop={asset.loopVideo}
        onEnded={asset.loopVideo ? undefined : advance}
      />
    )
  } else {
    media = <img className="visual-content" src={asset.url} alt="" />
  }

  return <main className="playback-screen">{media}</main>
}

function App({ presentation }: AppProps) {
  const [agentPresentation, setAgentPresentation] = useState<PlayerPresentation>(safeDefault)

  useEffect(() => {
    if (presentation) return

    let active = true
    const load = async () => {
      try {
        const next = await loadPresentation()
        if (active) setAgentPresentation(next)
      } catch {
        if (active) setAgentPresentation(safeDefault)
      }
    }

    void load()
    const poll = window.setInterval(() => void load(), 5_000)
    return () => {
      active = false
      window.clearInterval(poll)
    }
  }, [presentation])

  const current = presentation ?? agentPresentation
  const activeAuthorizationRemaining = presentation === undefined && agentPresentation.kind === 'ready'
    ? agentPresentation.authorizationRemainingMilliseconds
    : undefined

  useEffect(() => {
    if (!activeAuthorizationRemaining) return

    const expiryTimer = window.setTimeout(
      () => setAgentPresentation(safeDefault),
      activeAuthorizationRemaining,
    )
    return () => window.clearTimeout(expiryTimer)
  }, [activeAuthorizationRemaining])

  if (current.kind === 'ready') {
    return <PlaylistPlayer manifest={current.manifest} />
  }

  if (current.kind === 'noContent') {
    return (
      <main className="player-screen neutral" aria-live="polite">
        <div className="state-mark" aria-hidden="true">—</div>
        <h1>No content assigned</h1>
        {current.deviceName && <p>{current.deviceName}</p>}
      </main>
    )
  }

  if (current.kind === 'synchronizing') {
    const progress = Math.max(0, Math.min(100, current.progress ?? 0))
    return (
      <main className="player-screen neutral" aria-live="polite">
        <div className="sync-ring" aria-hidden="true" />
        <h1>Synchronizing</h1>
        <p>{progress}%</p>
      </main>
    )
  }

  return (
    <main className="player-screen denied" aria-live="assertive">
      <div className="state-mark" aria-hidden="true">×</div>
      <h1>Not licensed</h1>
    </main>
  )
}

export default App
