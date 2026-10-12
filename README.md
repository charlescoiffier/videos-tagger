# Video Tag

Application macOS pour trier une grande quantité de vidéos grâce à leurs planches de captures : on les passe une par une, on coche des **tags** au clavier, et Video Tag pose des **étiquettes Finder** colorées sur les fichiers.

Fonctionne avec n'importe quel dossier de vidéos (sous-dossiers compris).

## Construire et lancer

Prérequis : macOS 14+, Swift 6 (Command Line Tools), `ffmpeg` pour générer les planches (`brew install ffmpeg`).

```bash
scripts/make-app.sh                      # construit ~/Applications/Video Tag.app
open "$HOME/Applications/Video Tag.app"
scripts/t.sh                             # tests
```

Au premier lancement, choisissez le dossier à analyser. Video Tag y crée `videos.json` (la base), `config.json` (les tags) et un dossier `screen/` (les planches).

## Utilisation

- **Mettre à jour la base** : ajoute les nouvelles vidéos du dossier. Titre, date, auteur, tags et revues déjà saisis ne sont jamais modifiés.
- **Générer les planches manquantes** : utilise le script [planche-contact](https://github.com/charlescoiffier/planche-contact) (copie dans `vendor/`) pour créer `screen/<nom de la vidéo>.jpg`.
- **Tags** : créez-les dans les réglages. Chaque tag a un nom, une touche du clavier (n'importe laquelle), une étiquette Finder facultative (7 couleurs, une par tag).
- **Verrou** : le cadenas à côté des tags (écran principal) empêche de cocher ou décocher les tags, au clic comme au clavier.
- **Clavier** : la touche d'un tag le coche / décoche sur la vidéo affichée ; ← → ↑ ↓ naviguent ; Espace ouvre l'aperçu macOS ; pincer zoome sur la planche.
- **Informations** : le bouton « Modifier les informations » ouvre une fenêtre pour le titre, la date (`AAAA-MM-JJ`) et l'auteur.
- **Filtres** : panneau de droite (recherche, dossier, revue, tags oui / non).

## Remplir automatiquement titre, date, auteur et tags

L'application ne lit pas les noms de fichiers. Un script externe optionnel, à lancer à la main, peut le faire : il lit les noms de fichiers d'après une expression régulière que vous choisissez et coche les tags dont le motif de recherche correspond au titre. Ce motif est le champ facultatif `match` d'un tag dans `config.json` (expression régulière, casse ignorée) ; l'interface ne le modifie pas. L'application recharge `videos.json` quand elle revient au premier plan.

## Données

- `videos.json` (version 2) : `path`, `screen`, `title`, `date`, `author`, `tags`, `reviewed` pour chaque vidéo.
- `config.json` : la liste des tags.
- Un fichier illisible ou d'un format inattendu n'est jamais écrasé : l'application refuse de l'ouvrir et n'écrit rien.

## Structure

- `Sources/VideoTagCore` : logique (modèle, scan, filtres, étiquettes Finder), testée.
- `Sources/VideoTag` : interface SwiftUI.
- `vendor/planche-contact.sh` : script de planches.
