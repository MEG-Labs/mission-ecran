# Mission Écran

App web installable (PWA) pour Android : les enfants font leurs tâches après l'école et prennent une photo comme preuve, puis demandent leur temps d'écran. Le parent reçoit une notification push, regarde les photos et approuve (ou demande de refaire une tâche), puis accorde le temps dans Google Family Link.

## Confidentialité

Ce dépôt est public mais ne contient **aucune donnée personnelle**.

- **Données privées** : prénoms, tâches, photos, historique, courriels autorisés et sujet ntfy restent dans Supabase.
- **Accès** : sans connexion, l'app et l'API ne montrent rien. Chaque appareil se connecte une fois.
  - **Appareil familial** (tablette des enfants) : voit les tâches, envoie des photos, fait une demande. Ne peut pas approuver ni voir les photos.
  - **Parent** : tout.
- **Notification** : envoyée par Supabase (pas par le navigateur), avec un message générique sans prénom.

## Essayer tout de suite (mode démo)

Laisse `config.js` vide, puis lance un serveur local :

```
python -m http.server 8000
```

Ouvre ensuite http://localhost:8000. En mode démo, tout reste dans le navigateur, avec des données fictives.

## Mise en service (≈ 30 minutes)

### 1. Supabase (base de données + photos, gratuit)

1. Crée un compte sur https://supabase.com et un projet (région : Canada Central).
2. Dans **SQL Editor → New query**, colle `schema.sql` tel quel, puis clique sur **Run**.
3. Dans **Authentication → Users → Add user**, crée deux comptes :
   - **ton compte parent** (ton courriel) ;
   - **un compte appareil familial**, par exemple un alias `famille@…`. Ce courriel ne reçoit rien ; il sert d'identifiant.
4. Dans **Authentication → Sign In / Providers**, désactive **Allow new users to sign up**.
5. Dans **Project Settings → API**, copie l'URL et la clé `anon public` dans `config.js` (crayon ✏️ sur GitHub).

### 2. Réglages privés (dans Supabase seulement, jamais dans le dépôt)

Dans **SQL Editor → New query**, remplace les valeurs et exécute :

```sql
insert into public.members (email, role) values
  ('ton.courriel@exemple.com', 'parent'),
  ('famille@exemple.com',      'appareil');

insert into public.private_settings (key, value) values
  ('ntfy_topic', 'un-nom-long-et-secret-ici'),
  ('app_url',    'https://meg-labs.github.io/mission-ecran/#/parent');
```

Pour ajouter l'autre parent plus tard, ajoute une ligne `'parent'` dans `members` et crée son compte dans Authentication.

**Ne sauvegarde pas cette requête dans un fichier du dépôt.**

### 3. Notifications push (ntfy, gratuit)

1. Installe **ntfy** sur ton téléphone Android (Play Store).
2. Touche **+ → Subscribe to topic** et entre exactement le même nom que `ntfy_topic` à l'étape 2.

### 4. Hébergement (GitHub Pages)

1. Dans le dépôt, va dans **Settings → Pages**.
2. Choisis **Deploy from a branch**, puis **main / (root)**, et clique sur **Save**.
3. L'app sera à https://meg-labs.github.io/mission-ecran/.

### 5. Installer sur les appareils

**Tablette ou téléphone des enfants**
1. Ouvre l'URL dans Chrome et connecte-toi avec le **compte appareil familial**. La connexion reste active.
2. Menu ⋮ → **Ajouter à l'écran d'accueil**.
3. Dans Family Link, ajoute l'app aux apps **toujours autorisées**.

**Ton téléphone**
1. Ouvre la même URL et connecte-toi avec ton **compte parent**.
2. Ajoute l'app à l'écran d'accueil. La notif ntfy ouvre directement l'espace parent.

## Utilisation au quotidien

- **Enfants** : prénom, avatar, minutes par défaut.
- **Tâches** : récurrentes (jours de la semaine) ou ponctuelles (une seule date). Le bouton Pause suspend une tâche sans la supprimer.
- **Demandes** : photos du jour, choix des minutes, Approuver / Refuser, ou « À refaire » sur une photo précise.
- **Historique** : 14 derniers jours et total de minutes par enfant.

Après l'approbation, le bouton **Ouvrir Family Link** lance l'app pour accorder le temps.

## Fichiers

| Fichier | Rôle |
|---|---|
| `index.html` | Toute l'app (écran enfant + espace parent) |
| `config.js` | URL et clé publique Supabase |
| `schema.sql` | Tables, règles de sécurité, bucket photos, notification |
| `manifest.webmanifest`, `sw.js`, `icons/` | Installation sur l'écran d'accueil |
