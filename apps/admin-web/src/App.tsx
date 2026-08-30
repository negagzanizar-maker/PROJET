import { useCallback, useEffect, useState, type FormEvent } from 'react'
import './App.css'
import './Dashboard.css'
import OperationsDashboard from './OperationsDashboard'
import PlatformDashboard from './PlatformDashboard'

export type Session = {
  authenticated: boolean
  authenticationStage: string | null
  csrfToken: string
  userId: string | null
  email: string | null
  displayName: string | null
  tenantId: string | null
  tenantRole: string | null
  mfaSatisfied: boolean
}

type Problem = { title?: string }
type TotpEnrollment = { secret: string; otpAuthUri: string }
type MfaCompletion = { status: string; recoveryCodes: string[] | null }

const tenantNavigation = [
  'Vue d’ensemble',
  'Appareils',
  'Licences',
  'Contenus',
  'Playlists',
  'Groupes & horaires',
  'Utilisateurs',
  'Journal d’audit',
]

const platformNavigation = ['Vue d’ensemble', 'Créer un client', 'Clients', 'Preuve MFA']

async function readProblem(response: Response): Promise<string> {
  try {
    const problem = (await response.json()) as Problem
    return problem.title ?? 'La requête n’a pas pu être traitée.'
  } catch {
    return 'La requête n’a pas pu être traitée.'
  }
}

function App() {
  const [session, setSession] = useState<Session | null>(null)
  const [loadingError, setLoadingError] = useState<string | null>(null)
  const [actionError, setActionError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const [enrollment, setEnrollment] = useState<TotpEnrollment | null>(null)
  const [recoveryCodes, setRecoveryCodes] = useState<string[] | null>(null)
  const [authMode, setAuthMode] = useState<'sign-in' | 'forgot'>('sign-in')
  const [authNotice, setAuthNotice] = useState<string | null>(null)

  const loadSession = useCallback(async () => {
    const response = await fetch('/api/v1/session', {
      credentials: 'same-origin',
      headers: { Accept: 'application/json' },
    })
    if (!response.ok) throw new Error(await readProblem(response))
    setSession((await response.json()) as Session)
    setLoadingError(null)
  }, [])

  useEffect(() => {
    void loadSession().catch((error: unknown) => setLoadingError(
      error instanceof Error ? error.message : 'API indisponible.',
    ))
  }, [loadSession])

  const post = async <T,>(path: string, body: unknown): Promise<T> => {
    if (!session?.csrfToken) throw new Error('Jeton de sécurité indisponible. Rechargez la page.')
    const response = await fetch(path, {
      method: 'POST',
      credentials: 'same-origin',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        'X-CSRF-TOKEN': session.csrfToken,
      },
      body: JSON.stringify(body),
    })
    if (!response.ok) throw new Error(await readProblem(response))
    if (response.status === 204) return undefined as T
    return (await response.json()) as T
  }

  const runAction = async (action: () => Promise<void>) => {
    setBusy(true)
    setActionError(null)
    try {
      await action()
    } catch (error: unknown) {
      setActionError(error instanceof Error ? error.message : 'Une erreur est survenue.')
    } finally {
      setBusy(false)
    }
  }

  if (!session) {
    return (
      <main className="centered-page" aria-busy={!loadingError}>
        <div className="loading-card">
          <span className="brand-mark" aria-hidden="true">D</span>
          <h1>{loadingError ? 'Connexion à l’API impossible' : 'Initialisation sécurisée…'}</h1>
          <p>{loadingError ?? 'Création du contexte de session et du jeton CSRF.'}</p>
          {loadingError && <button onClick={() => void loadSession()} type="button">Réessayer</button>}
        </div>
      </main>
    )
  }

  if (recoveryCodes) {
    return (
      <main className="centered-page">
        <section className="auth-card wide" aria-labelledby="recovery-title">
          <p className="eyebrow">MFA activée</p>
          <h1 id="recovery-title">Codes de récupération</h1>
          <p>Enregistrez-les maintenant dans un endroit sûr. Ils ne seront plus affichés.</p>
          <ul className="recovery-grid" aria-label="Codes de récupération à usage unique">
            {recoveryCodes.map((code) => <li key={code}><code>{code}</code></li>)}
          </ul>
          <button className="primary-button" onClick={() => setRecoveryCodes(null)} type="button">
            J’ai enregistré les codes
          </button>
        </section>
      </main>
    )
  }

  if (!session.authenticated) {
    const fragmentUrl = new URL(window.location.hash.startsWith('#/') ? window.location.hash.slice(1) : '/', window.location.origin)
    const invitationToken = fragmentUrl.pathname === '/accept-invitation' ? fragmentUrl.searchParams.get('token') : null
    const resetToken = fragmentUrl.pathname === '/reset-password' ? fragmentUrl.searchParams.get('token') : null
    const resetEmail = fragmentUrl.pathname === '/reset-password' ? fragmentUrl.searchParams.get('email') : null

    if (invitationToken) {
      return <InvitationAcceptanceForm busy={busy} error={actionError} onSubmit={(displayName, password) => runAction(async () => {
        await post('/api/v1/invitations/accept', { token: invitationToken, displayName, password })
        window.history.replaceState(null, '', '/')
        setAuthNotice('Invitation acceptée. Connectez-vous avec le compte que vous venez de créer.')
      })} />
    }

    if (resetToken && resetEmail) {
      return <PasswordResetForm busy={busy} error={actionError} email={resetEmail} onSubmit={(password) => runAction(async () => {
        await post('/api/v1/auth/reset-password', { email: resetEmail, token: resetToken, newPassword: password })
        window.history.replaceState(null, '', '/')
        setAuthNotice('Mot de passe modifié. Toutes les anciennes sessions ont été révoquées.')
      })} />
    }

    return (
      <main className="auth-layout">
        <section className="auth-intro" aria-labelledby="product-title">
          <Brand />
          <div>
            <p className="eyebrow">Affichage distant sécurisé</p>
            <h1 id="product-title">Pilotez vos écrans Raspberry Pi, sans mélanger vos clients.</h1>
            <p>Les comptes sont créés uniquement sur invitation. Les sessions restent dans des cookies HttpOnly et les administrateurs utilisent un second facteur.</p>
          </div>
          <p className="trust-line">Isolation PostgreSQL RLS · contenu privé · licence à expiration</p>
        </section>
        {authMode === 'forgot'
          ? <ForgotPasswordForm busy={busy} error={actionError} onCancel={() => setAuthMode('sign-in')} onSubmit={(email) => runAction(async () => {
            await post('/api/v1/auth/forgot-password', { email })
            setAuthMode('sign-in')
            setAuthNotice('Si ce compte est éligible, un message de récupération a été mis en file d’attente.')
          })} />
          : <SignInForm busy={busy} error={actionError} notice={authNotice} onForgot={() => {
            setActionError(null)
            setAuthNotice(null)
            setAuthMode('forgot')
          }} onSubmit={(email, password) => runAction(async () => {
            await post('/api/v1/auth/sign-in', { email, password })
            await loadSession()
          })} />}
      </main>
    )
  }

  if (session.authenticationStage === 'mfa_enrollment') {
    return (
      <main className="centered-page">
        <section className="auth-card wide" aria-labelledby="mfa-enroll-title">
          <p className="eyebrow">Protection administrateur</p>
          <h1 id="mfa-enroll-title">Activer l’authentification à deux facteurs</h1>
          {!enrollment ? (
            <>
              <p>Une application d’authentification TOTP est obligatoire pour ce rôle.</p>
              <button className="primary-button" disabled={busy} onClick={() => void runAction(async () => setEnrollment(
                await post<TotpEnrollment>('/api/v1/auth/mfa/totp/enroll', {}),
              ))} type="button">Générer le secret TOTP</button>
            </>
          ) : (
            <>
              <p>Ajoutez cette clé dans votre application, puis saisissez le code à six chiffres.</p>
              <div className="secret-box"><span>Clé manuelle</span><code>{enrollment.secret}</code></div>
              <a className="secondary-link" href={enrollment.otpAuthUri}>Ouvrir l’application d’authentification</a>
              <MfaCodeForm busy={busy} error={actionError} label="Confirmer et activer" onSubmit={(code) => runAction(async () => {
                const result = await post<MfaCompletion>('/api/v1/auth/mfa/totp/confirm', { code })
                setRecoveryCodes(result.recoveryCodes)
                await loadSession()
              })} />
            </>
          )}
          {actionError && !enrollment && <p className="form-error" role="alert">{actionError}</p>}
        </section>
      </main>
    )
  }

  if (session.authenticationStage === 'mfa_pending') {
    return (
      <main className="centered-page">
        <section className="auth-card" aria-labelledby="mfa-title">
          <p className="eyebrow">Deuxième facteur</p>
          <h1 id="mfa-title">Vérifiez votre identité</h1>
          <p>Saisissez le code actuel de votre application d’authentification.</p>
          <MfaCodeForm busy={busy} error={actionError} label="Vérifier" onSubmit={(code) => runAction(async () => {
            await post('/api/v1/auth/mfa/totp', { code })
            await loadSession()
          })} />
        </section>
      </main>
    )
  }

  return (
    <div className="app-shell">
      <aside className="sidebar">
        <Brand />
        <nav aria-label="Navigation principale">
          <p className="nav-label">{session.tenantId ? 'Espace client' : 'Plateforme'}</p>
          <ul>{(session.tenantId ? tenantNavigation : platformNavigation).map((label, index) => <li key={label}><a className={index === 0 ? 'active' : undefined} href={session.tenantId ? `#section-${index}` : ['#platform-overview', '#platform-create', '#platform-tenants', '#platform-step-up'][index]}><span className="nav-dot" aria-hidden="true" />{label}</a></li>)}</ul>
        </nav>
        <div className="security-note"><span aria-hidden="true">●</span><div><strong>Isolation active</strong><p>Tenant imposé par la session et PostgreSQL.</p></div></div>
      </aside>
      <main id="main-content" className="main-content">
        <header className="topbar">
          <div><p className="eyebrow">{session.tenantId ? 'Espace client' : 'Administration plateforme'}</p><h1>Centre de contrôle</h1></div>
          <button className="text-button" disabled={busy} onClick={() => void runAction(async () => {
            await post('/api/v1/auth/sign-out', {})
            setEnrollment(null)
            await loadSession()
          })} type="button">Se déconnecter</button>
        </header>
        <section className="welcome" aria-labelledby="welcome-title">
          <div><p className="eyebrow">Session vérifiée</p><h2 id="welcome-title">Bonjour {session.displayName ?? session.email ?? 'administrateur'}.</h2><p>Les données ci-dessous proviennent directement de l’API du tenant lié à votre session.</p></div>
          <div className="signal" aria-label="État de sécurité : session active"><span aria-hidden="true" />{session.mfaSatisfied ? 'MFA vérifiée' : 'Session active'}</div>
        </section>
        {session.tenantId
          ? <OperationsDashboard session={session} post={post} />
          : <PlatformDashboard session={session} post={post} />}
      </main>
    </div>
  )
}

function Brand() {
  return <a className="brand" href="#main-content" aria-label="Display Control — accueil"><span className="brand-mark" aria-hidden="true">D</span><span><strong>Display Control</strong><small>Administration sécurisée</small></span></a>
}

function SignInForm({ busy, error, notice, onForgot, onSubmit }: { busy: boolean; error: string | null; notice: string | null; onForgot: () => void; onSubmit: (email: string, password: string) => Promise<void> }) {
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const values = new FormData(event.currentTarget)
    void onSubmit(String(values.get('email') ?? ''), String(values.get('password') ?? ''))
  }
  return <section className="auth-panel"><form id="sign-in-form" className="auth-card" onSubmit={submit}><p className="eyebrow">Accès privé</p><h2>Se connecter</h2><p>Utilisez l’adresse associée à votre invitation.</p>{notice && <p className="form-notice" role="status">{notice}</p>}<label>Adresse e-mail<input autoComplete="username" disabled={busy} maxLength={320} name="email" required type="email" /></label><label>Mot de passe<input autoComplete="current-password" disabled={busy} maxLength={1024} name="password" required type="password" /></label>{error && <p className="form-error" role="alert">{error}</p>}<button className="primary-button" disabled={busy} type="submit">{busy ? 'Vérification…' : 'Se connecter'}</button><button className="text-button" disabled={busy} onClick={onForgot} type="button">Mot de passe oublié</button></form></section>
}

function ForgotPasswordForm({ busy, error, onCancel, onSubmit }: { busy: boolean; error: string | null; onCancel: () => void; onSubmit: (email: string) => Promise<void> }) {
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const values = new FormData(event.currentTarget)
    void onSubmit(String(values.get('email') ?? ''))
  }
  return <section className="auth-panel"><form className="auth-card" onSubmit={submit}><p className="eyebrow">Récupération</p><h2>Mot de passe oublié</h2><p>La réponse reste identique, qu’un compte existe ou non.</p><label>Adresse e-mail<input autoComplete="email" disabled={busy} maxLength={320} name="email" required type="email" /></label>{error && <p className="form-error" role="alert">{error}</p>}<button className="primary-button" disabled={busy} type="submit">Demander la récupération</button><button className="text-button" disabled={busy} onClick={onCancel} type="button">Retour à la connexion</button></form></section>
}

function InvitationAcceptanceForm({ busy, error, onSubmit }: { busy: boolean; error: string | null; onSubmit: (displayName: string, password: string) => Promise<void> }) {
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const values = new FormData(event.currentTarget)
    void onSubmit(String(values.get('displayName') ?? ''), String(values.get('password') ?? ''))
  }
  return <main className="centered-page"><section className="auth-card wide"><Brand /><p className="eyebrow">Invitation à usage unique</p><h1>Créer votre compte</h1><p>Le lien expire après 24 heures et ne peut être utilisé qu’une fois.</p><form className="mfa-form" onSubmit={submit}><label>Nom affiché<input autoComplete="name" disabled={busy} maxLength={160} name="displayName" required /></label><label>Mot de passe<input autoComplete="new-password" disabled={busy} maxLength={1024} minLength={15} name="password" required type="password" /></label>{error && <p className="form-error" role="alert">{error}</p>}<button className="primary-button" disabled={busy} type="submit">Créer le compte</button></form></section></main>
}

function PasswordResetForm({ busy, email, error, onSubmit }: { busy: boolean; email: string; error: string | null; onSubmit: (password: string) => Promise<void> }) {
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const values = new FormData(event.currentTarget)
    void onSubmit(String(values.get('password') ?? ''))
  }
  return <main className="centered-page"><section className="auth-card wide"><Brand /><p className="eyebrow">Récupération sécurisée</p><h1>Choisir un nouveau mot de passe</h1><p>Compte : {email}</p><form className="mfa-form" onSubmit={submit}><label>Nouveau mot de passe<input autoComplete="new-password" disabled={busy} maxLength={1024} minLength={15} name="password" required type="password" /></label>{error && <p className="form-error" role="alert">{error}</p>}<button className="primary-button" disabled={busy} type="submit">Modifier le mot de passe</button></form></section></main>
}

function MfaCodeForm({ busy, error, label, onSubmit }: { busy: boolean; error: string | null; label: string; onSubmit: (code: string) => Promise<void> }) {
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault()
    const values = new FormData(event.currentTarget)
    void onSubmit(String(values.get('code') ?? ''))
  }
  return <form className="mfa-form" onSubmit={submit}><label>Code à six chiffres<input autoComplete="one-time-code" disabled={busy} inputMode="numeric" maxLength={6} minLength={6} name="code" pattern="[0-9]{6}" required /></label>{error && <p className="form-error" role="alert">{error}</p>}<button className="primary-button" disabled={busy} type="submit">{busy ? 'Vérification…' : label}</button></form>
}

export default App
