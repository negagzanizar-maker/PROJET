import { render, screen } from '@testing-library/react'
import { describe, expect, it } from 'vitest'
import App from './App'

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
})
