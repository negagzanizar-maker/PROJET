import { render, screen, waitFor } from '@testing-library/react'
import userEvent from '@testing-library/user-event'
import { expect, it, vi } from 'vitest'
import PlaylistEditor from './PlaylistEditor'
import type { ContentItem, Playlist, PostJson } from './types'

it('saves ordered multiple items as a recoverable draft before publication', async () => {
  const contents = ['First', 'Second'].map((title, index) => ({
    id: `content-${index}`, title, mediaKind: 'png', lifecycleState: 'approved', concurrencyToken: '',
    latestVersion: { id: `version-${index}`, byteLength: 10, detectedMimeType: 'image/png', originalDisplayFileName: title, scanState: 'clean', rejectionCode: null },
  })) satisfies ContentItem[]
  const created = { id: 'draft', name: 'Lobby', description: null, latestVersion: { id: 'draft-version', publicationState: 'draft', itemCount: 2 } } satisfies Playlist
  const post = vi.fn().mockResolvedValue(created)
  const onCreated = vi.fn()
  render(<PlaylistEditor contents={contents} tenantId="tenant" post={post as PostJson} onCreated={onCreated} />)
  const user = userEvent.setup()
  await user.type(screen.getByLabelText('Nom'), 'Lobby')
  await user.selectOptions(screen.getByLabelText('Contenu'), 'version-0')
  await user.click(screen.getByRole('button', { name: 'Ajouter un élément' }))
  await user.selectOptions(screen.getAllByLabelText('Contenu')[1], 'version-1')
  await user.click(screen.getAllByRole('button', { name: 'Monter' })[1])
  await user.click(screen.getByRole('button', { name: 'Enregistrer le brouillon' }))
  await waitFor(() => expect(onCreated).toHaveBeenCalledWith(created))
  expect(post).toHaveBeenCalledTimes(1)
  expect(post.mock.calls[0][1].items.map((item: { contentVersionId: string }) => item.contentVersionId)).toEqual(['version-1', 'version-0'])
})
