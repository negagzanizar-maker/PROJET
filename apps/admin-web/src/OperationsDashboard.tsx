import { useCallback, useEffect, useState, type FormEvent } from 'react'
import type { Session } from './App'

type PostJson = <T>(path: string, body: unknown) => Promise<T>
type Device = {
  id: string
  displayName: string
  state: string
  health: string
  hostname: string | null
  serialNumber: string | null
  licenseState: string | null
  licenseExpiresAtUtc: string | null
}
type License = {
  id: string
  deviceId: string
  controlState: string
  effectiveState: string
  validFromUtc: string
  expiresAtUtc: string
  concurrencyToken: string
}
type DeviceGroup = {
  id: string
  name: string
  description: string | null
  deviceIds: string[]
  concurrencyToken: string
}
type ContentVersion = {
  id: string
  byteLength: number
  detectedMimeType: string
  originalDisplayFileName: string
  scanState: string
  rejectionCode: string | null
}
type ContentItem = {
  id: string
  title: string
  mediaKind: string
  lifecycleState: string
  concurrencyToken: string
  latestVersion: ContentVersion | null
}
type PlaylistVersion = {
  id: string
  publicationState: string
  itemCount: number
}
type Playlist = {
  id: string
  name: string
  description: string | null
  latestVersion: PlaylistVersion | null
}
type EnrollmentCode = {
  enrollmentCode: string
  expiresAtUtc: string
}
type Invitation = {
  email: string
  token: string
  expiresAtUtc: string
}
type Member = {
  membershipId: string
  userId: string
  displayName: string
  email: string
  role: string
  state: string
  mfaEnabled: boolean
  concurrencyToken: string
}
type AuditEvent = {
  id: string
  action: string
  targetType: string
  outcome: string
  reasonCode: string | null
  occurredAtUtc: string
}

async function readApiProblem(response: Response): Promise<string> {
  try {
    const problem = (await response.json()) as { title?: string }
    return problem.title ?? 'La requête n’a pas pu être traitée.'
  } catch {
    return 'La requête n’a pas pu être traitée.'
  }
}

function OperationsDashboard({ session, post }: { session: Session; post: PostJson }) {
  const tenantId = session.tenantId as string
  const canManageContent = session.tenantRole === 'TenantAdmin' || session.tenantRole === 'ContentManager'
  const canAdminister = session.tenantRole === 'TenantAdmin'
  const [devices, setDevices] = useState<Device[]>([])
  const [licenses, setLicenses] = useState<License[]>([])
  const [contents, setContents] = useState<ContentItem[]>([])
  const [playlists, setPlaylists] = useState<Playlist[]>([])
  const [deviceGroups, setDeviceGroups] = useState<DeviceGroup[]>([])
  const [members, setMembers] = useState<Member[]>([])
  const [auditEvents, setAuditEvents] = useState<AuditEvent[]>([])
  const [error, setError] = useState<string | null>(null)
  const [notice, setNotice] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [oneTimeSecret, setOneTimeSecret] = useState<{ label: string; value: string; expiresAtUtc: string } | null>(null)

  const load = useCallback(async () => {
    const paths = ['devices', 'licenses', 'contents', 'playlists', 'device-groups']
    const responses = await Promise.all(paths.map((path) => fetch(
      `/api/v1/tenants/${tenantId}/${path}`,
      { credentials: 'same-origin', headers: { Accept: 'application/json' } },
    )))
    const failed = responses.find((response) => !response.ok)
    if (failed) throw new Error(await readApiProblem(failed))
    const [nextDevices, nextLicenses, nextContents, nextPlaylists, nextDeviceGroups] = await Promise.all(
      responses.map((response) => response.json()),
    )
    setDevices(nextDevices as Device[])
    setLicenses(nextLicenses as License[])
    setContents(nextContents as ContentItem[])
    setPlaylists(nextPlaylists as Playlist[])
    setDeviceGroups(nextDeviceGroups as DeviceGroup[])
    if (canAdminister) {
      const [membersResponse, auditResponse] = await Promise.all([
        fetch(`/api/v1/tenants/${tenantId}/members`, { credentials: 'same-origin', headers: { Accept: 'application/json' } }),
        fetch(`/api/v1/tenants/${tenantId}/audit-events`, { credentials: 'same-origin', headers: { Accept: 'application/json' } }),
      ])
      if (!membersResponse.ok) throw new Error(await readApiProblem(membersResponse))
      if (!auditResponse.ok) throw new Error(await readApiProblem(auditResponse))
      setMembers((await membersResponse.json()) as Member[])
      setAuditEvents((await auditResponse.json()) as AuditEvent[])
    }
    setError(null)
  }, [canAdminister, tenantId])

  useEffect(() => {
    void load().catch((reason: unknown) => setError(
      reason instanceof Error ? reason.message : 'Données indisponibles.',
    ))
  }, [load])

  const mutate = async (operation: () => Promise<void>, success: string) => {
    setBusy(true)
    setError(null)
    setNotice(null)
    try {
      await operation()
      setNotice(success)
      await load()
    } catch (reason: unknown) {
      setError(reason instanceof Error ? reason.message : 'Opération impossible.')
    } finally {
      setBusy(false)
    }
  }

  const upload = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const form = event.currentTarget
    const body = new FormData(form)
    await mutate(async () => {
      const response = await fetch(`/api/v1/tenants/${tenantId}/contents`, {
        method: 'POST',
        credentials: 'same-origin',
        headers: { Accept: 'application/json', 'X-CSRF-TOKEN': session.csrfToken },
        body,
      })
      if (!response.ok) throw new Error(await readApiProblem(response))
      form.reset()
    }, 'Fichier contrôlé et enregistré. Approuvez-le avant publication.')
  }

  const put = async <T,>(path: string, body: unknown): Promise<T> => {
    const response = await fetch(path, {
      method: 'PUT',
      credentials: 'same-origin',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'X-CSRF-TOKEN': session.csrfToken,
      },
      body: JSON.stringify(body),
    })
    if (!response.ok) throw new Error(await readApiProblem(response))
    return (await response.json()) as T
  }

  const activeDevices = devices.filter((device) => device.state === 'active')
  const approvedContents = contents.filter((content) => content.lifecycleState === 'approved' && content.latestVersion)
  const publishedPlaylists = playlists.filter((playlist) => playlist.latestVersion?.publicationState === 'published')

  return (
    <>
      <section className="status-section" id="section-0" aria-labelledby="status-title">
        <div className="section-heading">
          <div><p className="eyebrow">Vue réelle</p><h2 id="status-title">État du parc</h2></div>
          <button className="text-button" onClick={() => void load()} type="button">Actualiser</button>
        </div>
        {error && <p className="form-error" role="alert">{error}</p>}
        {notice && <p className="form-notice" role="status">{notice}</p>}
        <div className="metric-grid">
          <article><strong>{devices.length}</strong><span>appareils</span></article>
          <article><strong>{activeDevices.length}</strong><span>actifs</span></article>
          <article><strong>{devices.filter((device) => device.licenseState === 'active').length}</strong><span>licenciés</span></article>
          <article><strong>{approvedContents.length}</strong><span>contenus approuvés</span></article>
        </div>
      </section>

      <section className="data-section" id="section-1" aria-labelledby="devices-title">
        <div className="section-heading"><div><p className="eyebrow">Inventaire</p><h2 id="devices-title">Appareils Raspberry Pi</h2></div><p>Données réelles déclarées par l’agent.</p></div>
        <div className="table-wrap"><table><thead><tr><th>Appareil</th><th>État</th><th>Santé</th><th>Série</th><th>Licence</th><th>Expiration</th></tr></thead><tbody>
          {devices.map((device) => <tr key={device.id}><td><strong>{device.displayName}</strong><small>{device.hostname ?? 'En attente d’enrôlement'}</small></td><td><Badge value={device.state} /></td><td><Badge value={device.health} /></td><td><code>{device.serialNumber ?? '—'}</code></td><td><Badge value={device.licenseState ?? 'aucune'} /></td><td>{formatDate(device.licenseExpiresAtUtc)}</td></tr>)}
        </tbody></table>{devices.length === 0 && <p className="empty-state">Aucun appareil dans ce tenant.</p>}</div>
      </section>

      <section className="data-section" id="section-2" aria-labelledby="licenses-title">
        <div className="section-heading"><div><p className="eyebrow">Autorisation</p><h2 id="licenses-title">Licences</h2></div><p>L’expiration est appliquée côté serveur et dans le bail hors ligne signé.</p></div>
        <div className="table-wrap"><table><thead><tr><th>Appareil</th><th>Contrôle</th><th>État effectif</th><th>Début</th><th>Expiration</th></tr></thead><tbody>
          {licenses.map((license) => <tr key={license.id}><td>{deviceName(devices, license.deviceId)}</td><td><Badge value={license.controlState} /></td><td><Badge value={license.effectiveState} /></td><td>{formatDate(license.validFromUtc)}</td><td>{formatDate(license.expiresAtUtc)}</td></tr>)}
        </tbody></table>{licenses.length === 0 && <p className="empty-state">Aucune licence.</p>}</div>
        {canAdminister && <form className="inline-form" onSubmit={(event) => {
          event.preventDefault()
          const form = event.currentTarget
          const values = new FormData(form)
          void mutate(async () => {
            await post(`/api/v1/tenants/${tenantId}/licenses`, {
              deviceId: String(values.get('deviceId')),
              validFromUtc: new Date().toISOString(),
              expiresAtUtc: new Date(String(values.get('expiresAt'))).toISOString(),
              reason: 'Création depuis le tableau de bord',
            })
            form.reset()
          }, 'Licence créée.')
        }}><label>Appareil<select name="deviceId" required><option value="">Sélectionner</option>{activeDevices.map((device) => <option key={device.id} value={device.id}>{device.displayName}</option>)}</select></label><label>Expiration<input name="expiresAt" type="datetime-local" required /></label><button className="primary-button" disabled={busy} type="submit">Créer la licence</button></form>}
        {canAdminister && licenses.some((license) => license.controlState === 'enabled' && license.effectiveState === 'active') && <form className="inline-form" onSubmit={(event) => {
          event.preventDefault()
          const form = event.currentTarget
          const values = new FormData(form)
          const source = licenses.find((license) => license.id === values.get('licenseId'))
          if (!source) return
          void mutate(async () => {
            await post(`/api/v1/tenants/${tenantId}/licenses/${source.id}/transfer`, {
              destinationDeviceId: String(values.get('destinationDeviceId')),
              concurrencyToken: source.concurrencyToken,
              reason: 'Remplacement d’écran depuis le tableau de bord',
            })
            form.reset()
          }, 'Transfert engagé après expiration du dernier bail source.')
        }}><label>Licence source<select name="licenseId" required><option value="">Sélectionner</option>{licenses.filter((license) => license.controlState === 'enabled' && license.effectiveState === 'active').map((license) => <option key={license.id} value={license.id}>{deviceName(devices, license.deviceId)}</option>)}</select></label><label>Appareil de remplacement<select name="destinationDeviceId" required><option value="">Sélectionner</option>{activeDevices.map((device) => <option key={device.id} value={device.id}>{device.displayName}</option>)}</select></label><button className="primary-button" disabled={busy} type="submit">Transférer la licence</button></form>}
      </section>

      <section className="data-section" id="section-3" aria-labelledby="contents-title">
        <div className="section-heading"><div><p className="eyebrow">Médiathèque privée</p><h2 id="contents-title">Contenus</h2></div><p>JPEG, PNG, WebP, MP4 ou texte UTF-8. Aucun fichier n’est public.</p></div>
        {canManageContent && <form className="inline-form" onSubmit={(event) => void upload(event)}><label>Titre<input name="Title" maxLength={200} required /></label><label>Format<select name="MediaKind" required><option value="Png">PNG</option><option value="Jpeg">JPEG</option><option value="WebP">WebP</option><option value="Mp4">MP4</option><option value="PlainText">Texte</option></select></label><label>Fichier<input name="File" type="file" required /></label><button className="primary-button" disabled={busy} type="submit">Téléverser et analyser</button></form>}
        <div className="card-list">{contents.map((content) => <article key={content.id}><div><strong>{content.title}</strong><small>{content.latestVersion?.originalDisplayFileName ?? 'Sans version'} · {content.mediaKind}</small></div><Badge value={content.lifecycleState} />{canManageContent && content.lifecycleState === 'draft' && content.latestVersion?.scanState === 'clean' && <button className="text-button" disabled={busy} onClick={() => void mutate(async () => { await post(`/api/v1/tenants/${tenantId}/contents/${content.id}/versions/${content.latestVersion?.id}/approve`, { concurrencyToken: content.concurrencyToken }) }, 'Contenu approuvé.') } type="button">Approuver</button>}</article>)}</div>
      </section>

      <section className="data-section" id="section-4" aria-labelledby="playlists-title">
        <div className="section-heading"><div><p className="eyebrow">Publication immuable</p><h2 id="playlists-title">Playlists et affectations</h2></div><p>L’empreinte du manifeste est liée au bail signé puis vérifiée par le Raspberry Pi.</p></div>
        {canManageContent && <div className="workflow-grid">
          <form className="stack-form" onSubmit={(event) => {
            event.preventDefault(); const form = event.currentTarget; const values = new FormData(form)
            void mutate(async () => { const created = await post<Playlist>(`/api/v1/tenants/${tenantId}/playlists`, { name: String(values.get('name')), description: null, items: [{ contentVersionId: String(values.get('contentVersionId')), durationMilliseconds: Number(values.get('duration')), loopVideo: false }] }); await post(`/api/v1/tenants/${tenantId}/playlists/${created.id}/versions/${created.latestVersion?.id}/publish`, {}); form.reset() }, 'Playlist publiée.')
          }}><h3>Créer une playlist</h3><label>Nom<input name="name" maxLength={200} required /></label><label>Contenu<select name="contentVersionId" required><option value="">Sélectionner</option>{approvedContents.map((content) => <option key={content.id} value={content.latestVersion?.id}>{content.title}</option>)}</select></label><label>Durée (ms)<input name="duration" type="number" min={1000} max={86400000} defaultValue={10000} required /></label><button className="primary-button" disabled={busy || approvedContents.length === 0} type="submit">Créer et publier</button></form>
          <form className="stack-form" onSubmit={(event) => {
            event.preventDefault(); const form = event.currentTarget; const values = new FormData(form)
            void mutate(async () => { await post(`/api/v1/tenants/${tenantId}/devices/${String(values.get('deviceId'))}/assignments`, { playlistVersionId: String(values.get('playlistVersionId')), priority: Number(values.get('priority')), startsAtUtc: optionalUtc(values.get('startsAt')), endsAtUtc: optionalUtc(values.get('endsAt')), presentationTimeZone: 'UTC' }); form.reset() }, 'Playlist affectée à l’écran.')
          }}><h3>Affecter à un écran</h3><label>Playlist<select name="playlistVersionId" required><option value="">Sélectionner</option>{publishedPlaylists.map((playlist) => <option key={playlist.id} value={playlist.latestVersion?.id}>{playlist.name}</option>)}</select></label><label>Appareil<select name="deviceId" required><option value="">Sélectionner</option>{activeDevices.map((device) => <option key={device.id} value={device.id}>{device.displayName}</option>)}</select></label><label>Priorité<input name="priority" type="number" min={-1000} max={1000} defaultValue={0} required /></label><label>Début UTC (facultatif)<input name="startsAt" type="datetime-local" /></label><label>Fin UTC exclusive (facultative)<input name="endsAt" type="datetime-local" /></label><button className="primary-button" disabled={busy || publishedPlaylists.length === 0 || activeDevices.length === 0} type="submit">Publier sur l’écran</button></form>
        </div>}
        <div className="card-list">{playlists.map((playlist) => <article key={playlist.id}><div><strong>{playlist.name}</strong><small>{playlist.latestVersion?.itemCount ?? 0} élément(s)</small></div><Badge value={playlist.latestVersion?.publicationState ?? 'vide'} /></article>)}</div>
      </section>

      <section className="data-section" id="section-5" aria-labelledby="groups-title">
        <div className="section-heading"><div><p className="eyebrow">Ciblage déterministe</p><h2 id="groups-title">Groupes et horaires</h2></div><p>Une affectation directe reste prioritaire sur un groupe. À cible égale, la priorité numérique la plus haute gagne.</p></div>
        <div className="card-list">{deviceGroups.map((group) => <article key={group.id}><div><strong>{group.name}</strong><small>{group.deviceIds.length} appareil(s) · {group.description ?? 'Sans description'}</small></div></article>)}</div>
        {(canAdminister || canManageContent) && <div className="workflow-grid">
          {canAdminister && <form className="stack-form" onSubmit={(event) => {
            event.preventDefault(); const form = event.currentTarget; const values = new FormData(form)
            void mutate(async () => { await post(`/api/v1/tenants/${tenantId}/device-groups`, { name: String(values.get('name')), description: String(values.get('description')) || null }); form.reset() }, 'Groupe créé.')
          }}><h3>Créer un groupe</h3><label>Nom<input name="name" maxLength={160} required /></label><label>Description<input name="description" maxLength={2000} /></label><button className="primary-button" disabled={busy} type="submit">Créer</button></form>}
          {canAdminister && <form className="stack-form" onSubmit={(event) => {
            event.preventDefault(); const form = event.currentTarget; const values = new FormData(form); const group = deviceGroups.find((item) => item.id === values.get('groupId')); const select = form.elements.namedItem('deviceIds') as HTMLSelectElement | null
            if (!group || !select) return
            const deviceIds = Array.from(select.selectedOptions, (option) => option.value)
            void mutate(async () => { await put(`/api/v1/tenants/${tenantId}/device-groups/${group.id}/members`, { deviceIds, concurrencyToken: group.concurrencyToken }); form.reset() }, 'Membres du groupe remplacés.')
          }}><h3>Définir les membres</h3><label>Groupe<select name="groupId" required><option value="">Sélectionner</option>{deviceGroups.map((group) => <option key={group.id} value={group.id}>{group.name}</option>)}</select></label><label>Appareils<select name="deviceIds" multiple required size={Math.min(Math.max(devices.length, 2), 8)}>{devices.filter((device) => device.state !== 'retired' && device.state !== 'quarantined').map((device) => <option key={device.id} value={device.id}>{device.displayName}</option>)}</select></label><button className="primary-button" disabled={busy || deviceGroups.length === 0} type="submit">Remplacer les membres</button></form>}
          {canManageContent && <form className="stack-form" onSubmit={(event) => {
            event.preventDefault(); const form = event.currentTarget; const values = new FormData(form)
            void mutate(async () => { await post(`/api/v1/tenants/${tenantId}/device-groups/${String(values.get('groupId'))}/assignments`, { playlistVersionId: String(values.get('playlistVersionId')), priority: Number(values.get('priority')), startsAtUtc: optionalUtc(values.get('startsAt')), endsAtUtc: optionalUtc(values.get('endsAt')), presentationTimeZone: 'UTC' }); form.reset() }, 'Playlist planifiée pour le groupe.')
          }}><h3>Planifier un groupe</h3><label>Groupe<select name="groupId" required><option value="">Sélectionner</option>{deviceGroups.map((group) => <option key={group.id} value={group.id}>{group.name}</option>)}</select></label><label>Playlist<select name="playlistVersionId" required><option value="">Sélectionner</option>{publishedPlaylists.map((playlist) => <option key={playlist.id} value={playlist.latestVersion?.id}>{playlist.name}</option>)}</select></label><label>Priorité<input name="priority" type="number" min={-1000} max={1000} defaultValue={0} required /></label><label>Début UTC (facultatif)<input name="startsAt" type="datetime-local" /></label><label>Fin UTC exclusive (facultative)<input name="endsAt" type="datetime-local" /></label><button className="primary-button" disabled={busy || deviceGroups.length === 0 || publishedPlaylists.length === 0} type="submit">Publier le planning</button></form>}
        </div>}
      </section>

      {canAdminister && <section className="data-section" id="section-6" aria-labelledby="users-title"><div className="section-heading"><div><p className="eyebrow">Accès sur invitation</p><h2 id="users-title">Utilisateurs</h2></div><p>Les changements de rôle et transferts exigent une preuve MFA datant de moins de dix minutes.</p></div><form className="inline-form" onSubmit={(event) => { event.preventDefault(); const form = event.currentTarget; const values = new FormData(form); void mutate(async () => { await post('/api/v1/auth/mfa/step-up', { code: String(values.get('code')) }); form.reset() }, 'Preuve MFA renouvelée pour dix minutes.') }}><label>Code TOTP actuel<input name="code" inputMode="numeric" pattern="[0-9]{6}" minLength={6} maxLength={6} autoComplete="one-time-code" required /></label><button className="primary-button" disabled={busy} type="submit">Renouveler la preuve MFA</button></form><form className="inline-form" onSubmit={(event) => { event.preventDefault(); const form = event.currentTarget; const values = new FormData(form); void mutate(async () => { const invitation = await post<Invitation>(`/api/v1/tenants/${tenantId}/invitations`, { email: String(values.get('email')), role: String(values.get('role')) }); setOneTimeSecret({ label: `Invitation pour ${invitation.email}`, value: `${window.location.origin}/accept-invitation?token=${encodeURIComponent(invitation.token)}`, expiresAtUtc: invitation.expiresAtUtc }); form.reset() }, 'Invitation créée.') }}><label>E-mail<input name="email" type="email" required /></label><label>Rôle<select name="role"><option value="viewer">Lecture</option><option value="contentManager">Gestionnaire de contenu</option><option value="tenantAdmin">Administrateur tenant</option></select></label><button className="primary-button" disabled={busy} type="submit">Créer l’invitation</button></form><div className="card-list">{members.map((member) => <article key={member.membershipId}><div><strong>{member.displayName}</strong><small>{member.email} · MFA {member.mfaEnabled ? 'active' : 'non activée'}</small></div><Badge value={member.state} /><select aria-label={`Rôle de ${member.displayName}`} disabled={busy || member.userId === session.userId || member.state !== 'active'} value={member.role} onChange={(event) => { const role = event.currentTarget.value; void mutate(async () => { await post(`/api/v1/tenants/${tenantId}/members/${member.membershipId}/role`, { role, concurrencyToken: member.concurrencyToken, reason: 'Modification depuis le tableau de bord' }) }, 'Rôle modifié et sessions révoquées.') }}><option value="tenantAdmin">Administrateur</option><option value="contentManager">Gestionnaire</option><option value="viewer">Lecture</option></select>{member.userId !== session.userId && member.state !== 'removed' && <button className="text-button" disabled={busy} onClick={() => void mutate(async () => { const action = member.state === 'active' ? 'suspend' : 'reactivate'; await post(`/api/v1/tenants/${tenantId}/members/${member.membershipId}/${action}`, { concurrencyToken: member.concurrencyToken, reason: 'Modification depuis le tableau de bord' }) }, member.state === 'active' ? 'Accès suspendu.' : 'Accès réactivé.')} type="button">{member.state === 'active' ? 'Suspendre' : 'Réactiver'}</button>}</article>)}</div></section>}

      {canAdminister && <section className="data-section" id="section-7" aria-labelledby="audit-title"><div className="section-heading"><div><p className="eyebrow">Traçabilité</p><h2 id="audit-title">Journal d’audit</h2></div><p>Les détails sensibles ne sont pas exposés dans cette vue.</p></div><div className="table-wrap"><table><thead><tr><th>Date</th><th>Action</th><th>Cible</th><th>Résultat</th><th>Motif</th></tr></thead><tbody>{auditEvents.map((event) => <tr key={event.id}><td>{formatDate(event.occurredAtUtc)}</td><td><code>{event.action}</code></td><td>{event.targetType}</td><td><Badge value={event.outcome} /></td><td>{event.reasonCode ?? '—'}</td></tr>)}</tbody></table>{auditEvents.length === 0 && <p className="empty-state">Aucun événement d’audit.</p>}</div></section>}

      {canAdminister && <section className="data-section action-panel" aria-labelledby="enroll-title"><div><p className="eyebrow">Enrôlement à usage unique</p><h2 id="enroll-title">Ajouter un écran</h2><p>Le secret expire après quinze minutes.</p></div><form onSubmit={(event) => { event.preventDefault(); const form = event.currentTarget; const values = new FormData(form); void mutate(async () => { const created = await post<EnrollmentCode>(`/api/v1/tenants/${tenantId}/enrollment-codes`, { displayName: String(values.get('displayName')), expectedSerialNumber: String(values.get('serial')) || null, expiresInMinutes: 15 }); setOneTimeSecret({ label: 'Code d’enrôlement', value: created.enrollmentCode, expiresAtUtc: created.expiresAtUtc }); form.reset() }, 'Code créé.') }}><label>Nom de l’écran<input name="displayName" maxLength={160} required /></label><label>Série attendue<input name="serial" maxLength={32} /></label><button className="primary-button" disabled={busy} type="submit">Créer le code</button></form></section>}
      {oneTimeSecret && <div className="one-time-secret" role="status"><strong>{oneTimeSecret.label} — à copier maintenant</strong><code>{oneTimeSecret.value}</code><span>Expire le {formatDate(oneTimeSecret.expiresAtUtc)}</span></div>}
    </>
  )
}

function Badge({ value }: { value: string }) {
  return <span className={`state-badge state-${value.toLowerCase()}`}>{value}</span>
}

function formatDate(value: string | null) {
  return value ? new Date(value).toLocaleString('fr-FR') : '—'
}

function deviceName(devices: Device[], deviceId: string) {
  return devices.find((device) => device.id === deviceId)?.displayName ?? deviceId
}

function optionalUtc(value: FormDataEntryValue | null) {
  const text = typeof value === 'string' ? value.trim() : ''
  return text ? new Date(text).toISOString() : null
}

export default OperationsDashboard
