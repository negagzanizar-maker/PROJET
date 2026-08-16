# État d’avancement du projet Display Control

**Date de référence :** 16 août 2026

**Statut :** application et kit de test terrain Raspberry Pi fonctionnels et vérifiés sur le poste de développement ; validation physique sur Raspberry Pi encore nécessaire.

## 1. Objet du projet

La plateforme permet à plusieurs clients isolés les uns des autres de gérer leurs utilisateurs, leurs Raspberry Pi, leurs licences et les contenus affichés sur les écrans connectés. Chaque Raspberry Pi communique avec le serveur par Internet : il remonte son identité et son état, reçoit une décision de licence signée, synchronise son contenu puis l’affiche localement. Un appareil non licencié, suspendu ou dont la preuve hors ligne a expiré affiche un état sûr « non licencié » au lieu du contenu.

Le dépôt contient trois produits principaux :

- une application d’administration React/TypeScript ;
- une API et les services métier ASP.NET Core/C# ;
- un agent C# et un lecteur React destinés au Raspberry Pi.

## 2. Résumé de ce qui est livré

| Domaine | État | Résultat actuel |
| --- | --- | --- |
| Architecture et spécifications | Réalisé | Monorepo, architecture, modèle de données, menace, décisions, 265 exigences et traçabilité |
| Administration multi-client | Réalisé localement | Création et cycle de vie des clients, utilisateurs et rôles isolés par tenant |
| Authentification humaine | Réalisé localement | Invitations, mot de passe, TOTP, récupération, sessions révocables, CSRF et limitation de débit |
| Enrôlement des Raspberry Pi | Réalisé localement | Jeton à usage unique, liaison au numéro de série, clé ECDSA, CSR et certificat client |
| Inventaire des appareils | Réalisé localement | Nom, série, interfaces, adresses MAC/IP, OS, versions et espace disque |
| Licences | Réalisé localement | Création, renouvellement, suspension, révocation, transfert et preuve hors ligne ES256 |
| Contenus et playlists | Réalisé localement | Import contrôlé, quarantaine, approbation, versions immuables et affectations planifiées |
| Affichage sur écran | Réalisé localement | Vidéo, image et texte ; états non licencié, aucun contenu, synchronisation et erreur |
| Notifications e-mail | Code réalisé | Worker SMTP sécurisé présent ; validation avec un vrai SMTP encore nécessaire |
| Kit de test Raspberry Pi | Réalisé sur poste | Archive autonome Linux ARM64, installateur, HTTPS LAN, prise en charge Wayland/X11 et guide de test pas à pas |
| Vérification automatisée | Réalisé localement | 84 tests .NET, 7 tests React et 5 tests Playwright/axe réussis, aucun échec |
| Validation Raspberry Pi physique | À faire | Essais écran, accélération vidéo, redémarrage, coupure réseau, horloge et endurance |
| Mise en production | À faire | Infrastructure, secrets, supervision, sauvegarde, restauration et tests de charge |
| Rapport final français | Préparé, non finalisé | Plan et journal disponibles ; DOCX/PDF final, captures et métadonnées restent à produire |

## 3. Travaux réalisés et méthode employée

### 3.1 Cadrage et architecture

- Le besoin a été transformé en exigences fonctionnelles, techniques et de sécurité, critères d’acceptation, cas d’utilisation et matrice de traçabilité.
- L’application suit un monolithe modulaire afin de garder un déploiement simple tout en séparant clairement domaine, application, infrastructure et API.
- Six décisions d’architecture documentent notamment la séparation des identités humaines et machines, l’isolation PostgreSQL, les licences hors ligne bornées et l’affectation des contenus.
- Le modèle est conçu pour fonctionner entre réseaux différents : les Raspberry Pi initient des connexions HTTPS sortantes vers l’API publique ; aucune découverte sur le réseau local n’est requise.

### 3.2 Isolation multi-client et administration plateforme

- Chaque donnée métier porte l’identifiant du client et les relations utilisent des clés étrangères garantissant la cohérence dans le même tenant.
- PostgreSQL applique la Row-Level Security forcée sur 25 tables. Les migrations définissent 28 politiques, dont les accès très limités du catalogue plateforme et du worker de notifications.
- L’administrateur plateforme peut lister et créer des clients, inviter leur premier administrateur, modifier leurs informations, les suspendre, les réactiver ou les archiver.
- La suspension d’un client révoque les sessions humaines actives et bloque également les appareils via les contrôles serveur.
- Le tableau de bord React permet d’exécuter ces opérations et affiche les liens d’invitation à usage unique lorsqu’ils sont créés.

### 3.3 Authentification, autorisation et sécurité des comptes

- Il n’existe pas d’inscription publique : un compte rejoint un client uniquement au moyen d’une invitation à durée limitée.
- La politique de mot de passe, le verrouillage après échecs, la limitation de débit et des réponses neutres réduisent les risques de brute force et d’énumération de comptes.
- Le second facteur TOTP inclut une protection contre le rejeu et dix codes de récupération à usage unique.
- Les sessions sont stockées côté serveur, révocables et transportées dans des cookies sécurisés préfixés `__Host-`. Les requêtes mutantes utilisent une protection CSRF.
- À chaque requête, le serveur revérifie que le client et l’adhésion sont actifs et que le rôle en base correspond encore à celui de la session.
- Les actions sensibles exigent une authentification multifacteur récente de moins de dix minutes : changement de rôle, révocation de certificat, transfert de licence, régénération des codes de récupération et déconnexion globale.
- L’amorçage du tout premier administrateur plateforme est une opération unique protégée par le condensat SHA-256 d’un secret, limitée en débit et désactivée logiquement dès qu’un administrateur existe.
- Les écrans React couvrent la connexion, l’acceptation d’invitation, l’oubli et la réinitialisation du mot de passe. Une réinitialisation révoque les anciennes sessions.

### 3.4 Identité et inventaire des Raspberry Pi

- L’enrôlement utilise un jeton à usage unique lié au numéro de série attendu.
- Le Raspberry Pi génère localement une clé privée ECDSA P-256 et une CSR ; la clé privée ne quitte pas l’appareil.
- L’API émet un certificat client lié au client et à l’appareil. Les battements de cœur et synchronisations utilisent ensuite le mTLS.
- La rotation et la révocation des certificats sont prises en charge. Une réponse perdue pendant l’enrôlement ou la rotation peut être rejouée avec la même clé, mais une clé différente est rejetée.
- L’inventaire remonté comprend le nom d’hôte, le numéro de série, les interfaces, adresses MAC et IP locales, le système, les versions de l’agent/lecteur et l’espace disque.
- La liste des appareils expose directement le nom choisi, le nom système réel, le numéro de série ainsi que toutes les adresses IP et MAC avec leur interface (`wlan0`, `eth0`, etc.). Ces valeurs sont actualisées à chaque battement de cœur.
- Un test Kestrel HTTPS réel vérifie qu’un certificat enrôlé est accepté et qu’un certificat absent ou non approuvé est refusé.

### 3.5 Licences et fonctionnement hors ligne

- Le cycle de vie d’une licence comprend création, renouvellement, suspension, réactivation, révocation et transfert, avec historique et audit.
- Le serveur produit un bail hors ligne signé en ES256 et lié au client, à l’appareil, au certificat, à la licence, à l’état désiré et au manifeste de contenu.
- La durée du bail est au maximum de 24 heures et ne dépasse jamais la date d’expiration de la licence ni la fin de la planification.
- Le lecteur vérifie localement la signature, l’identité de l’appareil et le temps de confiance. Au redémarrage ou après expiration hors ligne, il échoue de manière sûre et n’affiche plus le contenu licencié.

### 3.6 Contenus, playlists et planification

- Les fichiers importés sont contrôlés par taille, type déclaré et signature réelle du fichier.
- Le flux prévoit un antivirus ClamAV en mode bloquant, une quarantaine, une approbation et un stockage privé immuable.
- Les playlists sont publiées en versions immuables afin qu’un appareil reçoive un manifeste stable et vérifiable.
- Les appareils peuvent appartenir à des groupes. Les affectations directes ou de groupe utilisent des intervalles UTC `[début, fin)`, un fuseau IANA, une priorité et une détection des chevauchements.
- Une affectation directe est prioritaire sur celle d’un groupe ; deux résultats de même priorité restant ambigus sont refusés au lieu d’être choisis arbitrairement.

### 3.7 Agent et lecteur Raspberry Pi

- L’agent C# conserve de manière atomique son identité, sa clé, son certificat et son état de synchronisation afin de résister à un arrêt brutal.
- Il envoie les battements de cœur, récupère le bail signé et télécharge les ressources manquantes.
- Les téléchargements interrompus reprennent avec HTTP Range. La longueur, `Content-Range` et le SHA-256 sont vérifiés avant une promotion atomique dans le cache.
- Le lecteur React local affiche les vidéos, images et textes, ainsi que des écrans explicites pour les états non licencié, sans contenu, en synchronisation et en erreur.
- Les unités systemd séparent l’agent et le kiosque sous des comptes différents. Chromium conserve son bac à sable ; le script d’installation vérifie le condensat de l’artefact.

### 3.8 Notifications d’identité

- Un worker SMTP optionnel délivre les invitations et réinitialisations de mot de passe depuis une file PostgreSQL.
- Les contenus sensibles de la file sont protégés avec ASP.NET Core Data Protection.
- Le worker exige une base/identité PostgreSQL séparée, une URL publique HTTPS et SMTP avec TLS.
- Son rôle SQL ne peut que lire et mettre à jour la table de notifications au moyen de politiques RLS dédiées.
- Le traitement verrouille un message avec `SKIP LOCKED`, applique une temporisation progressive après erreur et n’enregistre qu’un code d’erreur sûr.
- Le code est présent et testé, mais l’envoi réel contre un fournisseur SMTP de recette n’a pas encore été validé.

### 3.9 Documentation et rapport

- Les documents existants couvrent la charte, les décisions ouvertes, la feuille de route, les exigences, la traçabilité, l’architecture, les contrats API, le modèle de données, le modèle de menace, la stratégie de test et l’exploitation.
- Un plan de rapport et un journal de réalisation en français ont été préparés.
- Le document d’exemple `IntelliHire_rapport_corrige.docx` a été étudié uniquement comme référence de structure et de présentation : page de garde, remerciements, résumés, acronymes, listes, chapitres, conclusion et bibliographie. Son contenu n’a pas été traité comme une instruction du projet.

## 4. Vérifications exécutées

Vérifications locales effectuées le 15 août 2026 :

| Commande | Résultat |
| --- | --- |
| `dotnet test DisplayControl.slnx --no-restore` | 84/84 tests réussis : 44 domaine, 10 agent, 30 intégration |
| `npm test` | 7/7 tests réussis : 4 administration, 3 lecteur |
| `npm run test:e2e` | 5/5 scénarios Chrome réussis ; zéro violation axe WCAG A/AA sur les vues couvertes |
| Compilation .NET | Réussie sans avertissement lors de la dernière vérification complète |
| Dérive du modèle EF Core | Aucune dérive lors de la dernière vérification |
| Audits NuGet et npm | Aucune vulnérabilité connue lors de la dernière vérification complète |
| Tests mTLS Kestrel | Certificat valide = accepté ; absent ou non approuvé = refusé |

Playwright `1.61.1` et `@axe-core/playwright` `4.12.1` sont ajoutés comme dépendances de test. Le téléchargement du Chromium géré est resté bloqué dans l’environnement local ; la suite a donc utilisé Google Chrome `151.0.7922.76` installé sur Windows et ses cinq scénarios passent. La CI est configurée pour installer explicitement le Chromium géré. Les réponses API de cette suite rapide sont interceptées de manière déterministe : elle prouve le comportement du navigateur et des vues couvertes, pas encore le parcours complet contre un backend de recette réel.

### 4.1 Mise à jour du 16 août 2026 — préparation du test terrain

- La compilation Release de la solution complète, y compris l’utilitaire de préparation, réussit avec zéro avertissement et zéro erreur.
- Les 84 tests .NET réussissent de nouveau avec Docker actif : 44 domaine, 10 agent et 30 intégration, dont PostgreSQL 18 et l’isolation RLS réelle.
- Les 7 tests React, les deux builds Vite, le lint et le typage TypeScript réussissent.
- Les 5 scénarios Playwright/axe réussissent dans Chrome.
- Une publication .NET autonome `linux-arm64` a été produite avec le lecteur React embarqué. L’archive générée est contrôlée par SHA-256 et reste hors Git comme artefact de livraison local.
- `scripts/New-FieldTestEnvironment.ps1` prépare PostgreSQL, ClamAV, les migrations, les clés de développement et un serveur HTTPS valable sur l’adresse IP du réseau local.
- L’installateur Pi accepte la CA publique du test LAN et peut attacher Chromium à l’utilisateur graphique Raspberry Pi OS sous Wayland ou X11.
- Le déroulement complet du lendemain est documenté dans `docs/05-operations/FIELD_TEST_TOMORROW.md`.

## 5. Parcours fonctionnel actuellement possible

Le parcours logiciel prévu et couvert localement est le suivant :

1. amorcer une seule fois le premier administrateur plateforme ;
2. activer le MFA et créer un client ;
3. inviter l’administrateur du client, puis accepter l’invitation ;
4. créer un jeton d’enrôlement pour un Raspberry Pi attendu ;
5. enrôler l’appareil et recevoir son certificat mTLS ;
6. remonter son inventaire et ses battements de cœur ;
7. créer ou attribuer une licence ;
8. importer, analyser et approuver les contenus ;
9. publier une playlist et l’affecter à l’appareil ou à un groupe ;
10. compiler l’état désiré, émettre un bail signé et synchroniser l’appareil ;
11. afficher le contenu si la licence est valable, sinon afficher l’état non licencié.

## 6. Ce qui reste nécessaire

### Priorité P0 — prouver le fonctionnement réel

- Installer l’agent et le lecteur sur au moins un Raspberry Pi 4/5 connecté à un écran.
- Vérifier la récupération réelle du numéro de série, des interfaces, des MAC et IP sur Raspberry Pi OS.
- Tester vidéo, image et texte en mode kiosque, y compris l’accélération matérielle et les différentes résolutions d’écran.
- Tester redémarrage, coupure électrique, coupure Internet, réseau lent, dérive de l’horloge et expiration de licence hors ligne.
- Tester le remplissage du disque et terminer la collecte automatique du cache sous pression disque.
- Exécuter un test d’endurance prolongé.
- Valider l’envoi des invitations et réinitialisations avec un véritable serveur SMTP de recette.

### Priorité P0 — environnement de recette et production

- Préparer DNS, certificat TLS public, proxy/ingress, PostgreSQL, stockage objet privé, ClamAV et comptes de service séparés.
- Placer les secrets, clés de signature, certificats CA, mots de passe et clés Data Protection dans un gestionnaire de secrets ; ne rien conserver dans le dépôt.
- Appliquer et valider en recette `deploy/postgres/schema.idempotent.sql`, maintenant régénéré après les dernières migrations plateforme/notifications.
- Appliquer les migrations avec le rôle propriétaire, puis exécuter l’application avec le rôle runtime restreint et le worker avec son rôle dédié.
- Mettre en place journaux centralisés, métriques, alertes, sauvegardes, test de restauration et procédure de reprise après sinistre.
- Configurer une livraison continue avec approbation, artefacts signés et retour arrière contrôlé.

### Priorité P1 — qualité, sécurité et exploitation

- Étendre les cinq scénarios Playwright/axe initiaux aux parcours complets contre l’API et PostgreSQL de recette.
- Réaliser les tests manuels d’accessibilité clavier/lecteur d’écran et corriger les écarts WCAG.
- Ajouter des tests de charge et d’endurance pour connexions, battements de cœur, synchronisations et compilation des états désirés.
- Effectuer une revue ASVS, des tests de fichiers malveillants et un test d’intrusion indépendant avant production.
- Ajouter une stratégie de rétention, une file d’échec définitif et la supervision des notifications SMTP.
- Généraliser `Idempotency-Key` aux autres commandes humaines critiques et verrouiller la publication concurrente si plusieurs instances serveur sont utilisées.
- Finaliser la collecte du cache, les seuils d’espace disque et la télémétrie associée.
- Finaliser le mécanisme de mise à jour signée de l’agent Raspberry Pi et son retour arrière.
- Rafraîchir les fichiers de preuves de test après les dernières fonctions plateforme/notifications et exécuter les mêmes contrôles dans la CI distante.

### Livrables documentaires finaux

- Générer les contrats OpenAPI finaux, le diagramme de données et les manuels administrateur/exploitation.
- Capturer les écrans réels de l’administration et du Raspberry Pi pour le rapport.
- Rédiger le rapport complet en français, puis produire les versions DOCX et PDF.
- Fournir les métadonnées manquantes : nom officiel du projet, étudiant, établissement/entreprise, encadrants, dates, logos, date limite et niveau de confidentialité.
- Relire le rapport, vérifier chaque affirmation contre le code et joindre les preuves de test et de déploiement.

## 7. Ordre de reprise recommandé

1. Appliquer et valider le script SQL de déploiement dans un environnement de recette propre.
2. Monter un environnement de recette avec TLS, base, stockage, antivirus, secrets et SMTP.
3. Déployer un Raspberry Pi physique et exécuter les scénarios de panne/hors ligne.
4. Étendre Playwright/axe au backend réel, puis exécuter la charge, l’endurance et la revue de sécurité.
5. Mettre en place supervision, sauvegarde/restauration et mises à jour signées.
6. Produire les captures, le rapport français final, puis le dossier de livraison.

## 8. Repères dans le dépôt

- `apps/admin-web` : interface d’administration React.
- `apps/player-web` : lecteur local React.
- `src/DisplayControl.Api` : API ASP.NET Core et worker de notifications.
- `src/DisplayControl.DeviceAgent` : agent C# du Raspberry Pi.
- `src/DisplayControl.Domain` : règles métier.
- `src/DisplayControl.Infrastructure` : PostgreSQL, identité, stockage et migrations.
- `tests` : tests domaine, agent et intégration.
- `deploy` : modèles de déploiement PostgreSQL et Raspberry Pi.
- `scripts` : scripts de développement, sécurité, installation et amorçage.
- `docs` : exigences, architecture, tests, exploitation et préparation du rapport.

## 9. Conclusion honnête

Le cœur du produit est maintenant implémenté et cohérent : administration multi-client, sécurité humaine, identité machine mTLS, licences, contenus, planification, synchronisation hors ligne et affichage. Les tests automatisés locaux passent. En revanche, le projet ne doit pas encore être qualifié de « prêt pour la production » : cette affirmation nécessite les essais sur matériel réel, l’environnement de recette, les contrôles opérationnels et de sécurité, puis les preuves finales et le rapport.
