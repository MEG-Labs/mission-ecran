# Mission Écran

App web installable (PWA) pour Android : les enfants font leurs tâches après l'école, prennent une photo comme preuve, puis demandent leur temps d'écran. Le parent reçoit une notification push, regarde les photos, approuve (ou demande de refaire une tâche), puis accorde le temps dans Google Family Link.

## Essayer tout de suite (mode démo)

Laisse `config.js` tel quel et ouvre `index.html` via un petit serveur local :

```
python -m http.server 8000
```

puis http://localhost:8000. En mode démo, tout reste dans le navigateur de l'appareil (pas de notif, pas de partage entre téléphones).

## Mise en service (≈ 30 minutes)

### 1. Supabase (base de données + photos, gratuit)
1. Crée un compte sur https://supabase.com et un nouveau projet (région : Canada Central).
2. **SQL Editor → New query** : colle `schema.sql`, remplace `ton.courriel@exemple.com` par ton courriel (ajoute l'autre parent au besoin), puis **Run**.
3. **Authentication → Users → Add user** : crée ton compte parent (même courriel, avec un mot de passe).
4. **Authentication → Sign In / Providers** : désactive « Allow new users to sign up » (seuls les comptes que tu crées pourront se connecter).
5. **Project Settings → API** : copie l'URL du projet et la clé `anon public` dans `config.js`.

### 2. Notifications push (ntfy, gratuit)
1. Installe **ntfy** sur ton téléphone Android (Play Store).
2. Choisis un nom de sujet long et impossible à deviner, ex. `mission-ecran-7f3k9q2xw8`.
3. Dans l'app ntfy : **+ → Subscribe to topic** avec ce nom.
4. Mets le même nom dans `NTFY_TOPIC` de `config.js`.

Le nom du sujet sert de mot de passe pour les notifs : ne le partage pas.

### 3. Hébergement (GitHub Pages, gratuit)
1. Crée un dépôt GitHub (ex. `MEG-Labs/mission-ecran`) et pousse le contenu de ce dossier.
2. **Settings → Pages → Deploy from a branch → main / root**.
3. L'app sera à `https://<compte>.github.io/mission-ecran/` (HTTPS requis pour la caméra et l'installation).

### 4. Installer sur les appareils
- **Tablette/téléphone des enfants** : ouvre l'URL dans Chrome → menu ⋮ → **Ajouter à l'écran d'accueil**. Chaque enfant choisit son avatar ; l'appareil s'en souvient (bouton « Changer » pour passer à un autre enfant).
- **Ton téléphone** : même URL → **🔒 Espace parent** → connexion. Ajoute-la aussi à l'écran d'accueil ; la notif ntfy ouvre directement cette page.
- Dans Family Link, ajoute l'app Mission Écran (Chrome) aux apps **toujours autorisées** pour que les enfants y aient accès même quand leur temps est écoulé.

## Utilisation au quotidien
- **Onglet Enfants** : prénom, avatar, minutes par défaut.
- **Onglet Tâches** : tâches récurrentes (jours de la semaine) ou ponctuelles (une seule date). Bouton Pause pour suspendre une tâche sans la supprimer.
- **Onglet Demandes** : photos du jour par enfant, choix des minutes, Approuver / Refuser, ou « À refaire » sur une photo précise (l'enfant voit ta note et la tâche revient à faire).
- **Onglet Historique** : 14 derniers jours et total de minutes accordées par enfant.

Après l'approbation, le bouton **Ouvrir Family Link** lance l'app pour accorder le temps.

## Sécurité, en bref
- Les appareils des enfants n'ont que la clé publique : ils peuvent lire leurs tâches, envoyer des photos et créer une demande, mais **ne peuvent pas s'approuver eux-mêmes** ni modifier les tâches (règles RLS dans `schema.sql`).
- Les photos sont dans un bucket privé, visibles seulement par les parents connectés (liens temporaires d'une heure).
- Limite assumée : quelqu'un qui connaîtrait l'URL pourrait créer une fausse demande ou téléverser une image. Pour une app familiale, c'est acceptable ; dis-le-moi si tu veux ajouter un code PIN par enfant.

## Fichiers
| Fichier | Rôle |
|---|---|
| `index.html` | Toute l'app (écran enfant + espace parent) |
| `config.js` | Clés Supabase et sujet ntfy |
| `schema.sql` | Tables, règles de sécurité, bucket photos |
| `manifest.webmanifest`, `sw.js`, `icons/` | Installation sur l'écran d'accueil |
