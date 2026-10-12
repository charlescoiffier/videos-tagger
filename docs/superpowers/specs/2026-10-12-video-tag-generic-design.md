# Video Tag — version générique (spec)

## Objectif
Faire de Video Tag un outil adapté à **n'importe quel dossier de vidéos** : l'application ne connaît plus aucune convention de nommage. Un script externe, lancé à la main, remplit les informations générales (titre, date, auteur) et coche les tags d'après les noms de fichiers.

## Vocabulaire
- **Tag** : une case oui / non que l'utilisateur coche sur une vidéo. Un tag a un nom, une touche de clavier facultative, un motif de recherche facultatif (utilisé uniquement par le script externe) et une étiquette Finder facultative.
- **Étiquette Finder** : l'étiquette colorée du Finder, nom + une des 7 couleurs. Deux tags ne peuvent pas avoir la même couleur.
- **Infos générales** : titre, date, auteur d'une vidéo.

## Données
### `videos.json` (version 2) — dans le dossier analysé
```json
{
  "version": 2,
  "videos": [
    {
      "path": "vacances/plage-1.mp4",
      "screen": "screen/plage-1.jpg",
      "title": "plage-1",
      "date": "2025-03-03",
      "author": "Marie",
      "tags": { "mer": true },
      "reviewed": true
    }
  ]
}
```
- `path` (chemin relatif au dossier analysé, tel que trouvé sur le disque) identifie la vidéo ; les comparaisons se font sur sa forme Unicode NFC. Le dossier d'une vidéo = son dossier parent relatif (vide à la racine).
- `title` : par défaut le nom du fichier sans extension, **numéros compris**. `date` et `author` sont facultatifs.
- `tags` : `{clé: true}` ; une clé absente = non renseigné. La valeur `false` reste lisible mais n'est jamais écrite par l'application.

### `config.json` — dans le dossier analysé
```json
{
  "tags": [
    { "key": "mer", "label": "Mer", "shortcut": "m",
      "match": "plage|mer",
      "finder": { "name": "Mer", "color": "blue" } }
  ]
}
```
- `shortcut` : un caractère, toute touche imprimable (hors espace, réservé à l'aperçu macOS) ; deux tags ne peuvent pas partager une touche.
- `match` : expression régulière (insensible à la casse), recherchée dans le titre par le script externe. Absente = tag purement manuel.
- `finder` : facultatif ; couleurs uniques entre tags.
- Aucun tag par défaut.

## Application
### Scan (« Mettre à jour la base »)
- Parcourt récursivement le dossier choisi et liste tous les fichiers vidéo (extensions : mp4 mov mkv avi m4v wmv flv webm mpg mpeg mts m2ts ts, casse ignorée). Ignore le dossier `screen/` de la racine, les éléments cachés et les fichiers `._*`.
- Aucune lecture du nom de fichier. Une nouvelle vidéo reçoit `title` = nom sans extension, pas de date, pas d'auteur, aucun tag.
- Fusion : une vidéo déjà connue garde titre, date, auteur, tags et « revue ; seule la planche est rafraîchie. Une vidéo disparue du disque reste dans la base (signalée).
- Crée `screen/` à la racine s'il manque (jamais le dossier racine).
- Planche d'une vidéo : `screen/<nom de la vidéo sans extension>.jpg` (appariement insensible à la forme Unicode). Deux vidéos de même nom dans des dossiers différents partagent donc la même planche.
- Le dossier analysé se choisit dans l'application ; il n'y a plus de dossier par défaut : au premier lancement, l'application demande de choisir un dossier.
- Quand `videos.json` est modifié par un autre programme (le script externe), l'application le recharge au retour au premier plan ; elle n'écrase jamais ces modifications avec sa copie en mémoire.

### Infos générales
- Nouveau bouton d'action (icône + infobulle) qui ouvre une fenêtre modale : Titre (obligatoire), Date (facultative, format `AAAA-MM-JJ` vérifié), Auteur (facultatif). Enregistrer écrit immédiatement dans `videos.json` ; Annuler ne change rien.
- L'en-tête de la vidéo affiche titre, auteur, date .

### Tags
- « Paramètres » est remplacé par « Tags » dans toute l'interface (réglages, infobulles, panneau de filtres, messages).
- Réglages des tags : fenêtre dédiée (nom, touche, étiquette Finder + couleur, réorganisation, suppression). Le motif de recherche (`match`) n'est pas modifiable dans l'interface : il se règle dans `config.json`.
- Panneau de droite. Le reste (recherche, dossier, revue, oui / non) est inchangé. La recherche texte porte sur titre, auteur et chemin.
- Liste de gauche : les tags cochés.

### Nettoyage du code et des textes
- Le module de cœur s'appelle `VideoTagCore` (tests : `VideoTagCoreTests`).
- Documentation : un `README.md` pour l'application.

## Script externe optionnel
L'application ne lit jamais les noms de fichiers. Un script externe, hors de ce dépôt et lancé à la main, peut compléter `videos.json` : il extrait titre, date et auteur du nom de fichier avec une expression régulière choisie par l'utilisateur, et coche les tags dont le champ `match` correspond au titre. Il ne remplace pas une information déjà saisie, ne retire jamais un tag et ne touche jamais à « revue ». L'application recharge `videos.json` quand elle revient au premier plan.

## Tests
- Cœur Swift : lecture/écriture de la base v2, scan générique (extensions, récursivité, éléments ignorés, titre par défaut, fusion, vidéos disparues, normalisation Unicode, `screen/`), filtres, sélection après filtre, validation des tags (clés, touches, couleurs), étiquettes Finder, validation des infos générales (titre, date), commande du script de planches.
- Interface : vérification manuelle (checklist dans le plan).

## Hors périmètre
Édition en masse des infos générales, lecture des métadonnées vidéo, détection automatique du format de nom, gestion des « parties ».
