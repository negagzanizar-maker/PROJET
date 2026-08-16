# Plan du rapport de stage en français

## 1. Statut et référence

Le rapport sera rédigé progressivement, puis généré en formats DOCX modifiable et PDF final. Le fichier de référence `IntelliHire_rapport_corrige.docx` a été analysé en lecture seule : 38 pages, environ 10 137 mots, trois chapitres techniques, neuf tableaux et quatorze médias intégrés.

Le nouveau rapport conservera ses qualités académiques — résumé bilingue, besoins, conception, réalisation et captures commentées — sans reproduire ses faiblesses : numérotation incohérente, absence d'un chapitre de validation, affirmations de sécurité sans preuves et confusion entre travail réalisé et perspectives.

## 2. Métadonnées à ne pas inventer

Les valeurs suivantes resteront marquées `[À compléter]` jusqu'à leur communication :

- nom officiel du projet ;
- nom complet de l'étudiant ;
- établissement, filière et année universitaire ;
- organisme d'accueil et logo autorisé ;
- encadrants académique et professionnel ;
- dates du stage et date de soutenance/remise ;
- consignes officielles de mise en page ; et
- éventuelles contraintes de confidentialité.

## 3. Structure cible

### Pages liminaires

1. Page de garde
2. Remerciements
3. Résumé et mots-clés
4. Abstract and keywords
5. Table des matières automatique
6. Liste automatique des figures
7. Liste automatique des tableaux
8. Liste des acronymes

### Introduction générale

- contexte de l'affichage numérique et de la gestion distante ;
- problématique de contrôle, de licence et d'isolation des clients ;
- objectifs fonctionnels et techniques ;
- périmètre et exclusions ;
- méthode suivie ; et
- organisation du rapport.

### Chapitre 1 — Contexte et conduite du projet

- présentation de l'organisme d'accueil ;
- contexte du stage et problème métier ;
- valeur attendue de la solution ;
- objectifs, périmètre et contraintes ;
- démarche itérative et jalons ;
- diagramme de Gantt fondé sur les dates réelles ; et
- risques projet et décisions importantes.

### Chapitre 2 — Analyse des besoins et spécifications

- identification des acteurs et matrice des rôles ;
- cas d'utilisation ;
- besoins fonctionnels et non fonctionnels ;
- exigences de sécurité ;
- règles de gestion ;
- cycles de vie du tenant, de l'utilisateur, du Pi, du certificat, de la licence, du contenu et du déploiement ; et
- critères d'acceptation et traçabilité.

### Chapitre 3 — Conception, architecture et sécurité

- architecture globale, conteneurs et déploiement ;
- frontières de confiance et flux principaux ;
- modèle de domaine, MCD/MLD et RLS PostgreSQL ;
- conception des API ;
- authentification humaine, MFA, sessions, CSRF et autorisations ;
- enrôlement du Pi, mTLS et cycle des certificats ;
- bail de licence signé, fonctionnement hors ligne et temps de confiance ;
- chaîne de traitement sécurisé du contenu ; et
- modèle de menaces, mesures et risques résiduels.

### Chapitre 4 — Réalisation et déploiement

- choix technologiques justifiés ;
- organisation du monorepo et qualité du code ;
- backend ASP.NET Core et PostgreSQL ;
- interface React d'administration ;
- agent C# du Raspberry Pi ;
- lecteur React en mode kiosque ;
- synchronisation, cache atomique et affichage ;
- déploiement, observabilité, sauvegarde et reprise ; et
- captures d'écran sélectionnées, introduites et interprétées.

### Chapitre 5 — Validation, sécurité et résultats

- stratégie, environnements et données de test ;
- résultats unitaires, composants, intégration et E2E ;
- preuves d'isolation des tenants et d'autorisation ;
- tests d'authentification, MFA, session et CSRF ;
- tests de licence, hors ligne, horloge et certificats ;
- tests de contenus malveillants, synchronisation et cache ;
- évaluation OWASP ASVS 5.0 niveau 2 ;
- résilience, charge, déploiement et restauration ;
- tests physiques sur Pi 4/5 et endurance ;
- défauts corrigés, limites connues et synthèse de traçabilité.

### Conclusion générale et perspectives

- bilan fondé exclusivement sur les exigences vérifiées ;
- apports techniques et méthodologiques ;
- limites réelles, notamment l'accès physique/root et la révocation hors ligne ; et
- perspectives clairement séparées du travail réalisé.

### Références et annexes

- sources primaires : documentation officielle, normes, RFC et OWASP ;
- extraits utiles de traçabilité/ASVS ;
- synthèses détaillées de tests ;
- procédures de déploiement et validation matérielle ; et
- extraits d'API lisibles, sans remplissage ni dump de code source.

## 4. Règles de rédaction

- Employer un français académique cohérent et définir chaque acronyme à sa première utilisation.
- Employer le présent pour les faits d'architecture et le passé uniquement pour un travail réellement achevé.
- Étiqueter explicitement un élément planifié, partiel, bloqué ou futur.
- Introduire et interpréter chaque figure dans le texte.
- Utiliser les styles Word de titres et une numérotation multiniveau automatique.
- Utiliser des légendes et renvois automatiques : `Figure n — Titre` et `Tableau n — Titre`.
- Ajouter `Source : Élaboration personnelle` aux schémas originaux et citer toute source externe.
- Actualiser la table des matières, les listes et les renvois avant chaque export formel.
- Masquer emails, tokens, certificats, numéros de série, adresses IP et données client réelles.
- Ne jamais utiliser une capture d'écran comme preuve d'isolation, d'autorisation ou de sécurité.
- Associer toute valeur numérique ou affirmation de résultat à un test, un commit, un environnement et une preuve datée.
- Publier les nombres exacts de tests réussis, échoués et ignorés ; ne jamais les estimer manuellement.
- Distinguer clairement démonstration locale, validation de préproduction et état de production.

## 5. Preuves prévues

| Élément du rapport | Source autoritaire |
|---|---|
| Besoins et règles | `docs/01-requirements` approuvé |
| Architecture et diagrammes | ADR et `docs/02-architecture` correspondant au code |
| Modèle de données | migrations vérifiées et ERD généré/revu |
| API | OpenAPI de la version vérifiée |
| Captures | version de staging identifiée et données synthétiques expurgées |
| Résultats de tests | bundle de preuves immuable de la version |
| Sécurité | matrice ASVS, modèle de menaces et résultats reproductibles |
| Performance | exécution de charge documentée, pas une impression visuelle |
| Tests Raspberry Pi | fiches matérielles signées/datées, versions et photos/captures expurgées |

## 6. Flux de mise à jour

À chaque objectif du projet :

1. mettre à jour les décisions et exigences concernées ;
2. conserver les éléments de conception et difficultés réelles ;
3. lier les tests et résultats au tableau de traçabilité ;
4. préparer le texte factuel et les figures du chapitre associé ; et
5. ne passer les formulations du futur au passé qu'après vérification.

Le rapport final est contrôlé contre le même commit/release que les manuels, l'OpenAPI, l'ERD et les résultats de tests.
