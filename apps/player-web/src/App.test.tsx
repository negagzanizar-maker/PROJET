import { act, render, screen } from '@testing-library/react'
import { afterEach, describe, expect, it, vi } from 'vitest'
import App from './App'

afterEach(() => {
  vi.useRealTimers()
  vi.unstubAllGlobals()
})

describe('fail-closed player presentation', () => {
  it('shows the exact unlicensed message by default', () => {
    render(<App />)

    expect(screen.getByRole('heading', { name: 'Not licensed' })).toBeInTheDocument()
    expect(screen.queryByText('No content assigned')).not.toBeInTheDocument()
  })

  it('distinguishes a valid licence with no assigned content', () => {
    render(<App presentation={{ kind: 'noContent', deviceName: 'Lobby display' }} />)

    expect(screen.getByRole('heading', { name: 'No content assigned' })).toBeInTheDocument()
    expect(screen.queryByText('Not licensed')).not.toBeInTheDocument()
  })

  it('renders an approved cached image without exposing a filesystem path', () => {
    render(<App presentation={{
      kind: 'ready',
      manifest: {
        desiredStateId: '11111111-1111-1111-1111-111111111111',
        version: 3,
        assets: [{
          contentVersionId: '22222222-2222-2222-2222-222222222222',
          position: 0,
          mediaKind: 'png',
          durationMilliseconds: 5000,
          loopVideo: false,
          url: '/player/v1/assets/22222222-2222-2222-2222-222222222222',
        }],
      },
    }} />)

    const image = document.querySelector('img')
    expect(image).not.toBeNull()
    expect(image).toHaveAttribute(
      'src',
      '/player/v1/assets/22222222-2222-2222-2222-222222222222',
    )
  })

  it('stops an active presentation at the lease expiry without waiting for a heartbeat', async () => {
    vi.useFakeTimers()
    const fetchMock = vi.fn()
      .mockResolvedValueOnce(new Response(JSON.stringify({
        status: 'ready',
        message: 'Playing',
        authorizationExpiresAtUtc: new Date(Date.now() + 1_000).toISOString(),
        authorizationRemainingMilliseconds: 1_000,
      }), { status: 200 }))
      .mockResolvedValueOnce(new Response(JSON.stringify({
        desiredStateId: '11111111-1111-1111-1111-111111111111',
        version: 3,
        assets: [{
          contentVersionId: '22222222-2222-2222-2222-222222222222',
          position: 0,
          mediaKind: 'png',
          durationMilliseconds: 5_000,
          loopVideo: false,
          url: '/player/v1/assets/22222222-2222-2222-2222-222222222222',
        }],
      }), { status: 200 }))
    vi.stubGlobal('fetch', fetchMock)

    render(<App />)
    await act(async () => Promise.resolve())
    await act(async () => Promise.resolve())
    expect(document.querySelector('img')).not.toBeNull()

    act(() => vi.advanceTimersByTime(1_000))

    expect(screen.getByRole('heading', { name: 'Not licensed' })).toBeInTheDocument()
  })
})
