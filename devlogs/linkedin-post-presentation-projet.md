# Post LinkedIn — présentation du projet Wyrdane (version technique)

*(brouillon — à relire avant publication, ajuster le ton/longueur selon préférence)*

---

Je développe depuis plusieurs mois, seul, un jeu de cartes à collectionner compétitif : **Wyrdane**. Mon premier projet logiciel de cette ampleur — je partage ici l'architecture plutôt que le simple pitch produit.

**Le produit**

TCG dark fantasy 1v1 : deux joueurs réduisent le héros adverse à 0 HP sur un plateau à deux rangées (Avant/Arrière). 317 cartes, 4 races (Mort-Vivant, Humain, Démon, Abomination), chacune avec ses mots-clés propres.

**Architecture**

- **Client** : Godot 4 / GDScript. Moteur d'effets/triggers entièrement *data-driven* : chaque carte est une ressource déclarant ses effets, exécutés par un `EffectManager` central — aucune logique codée en dur par carte, ce qui a permis de scaler à 317 cartes sans dupliquer de logique métier.
- **Système de ressources par race** : chaque race a son propre pool de mana (plutôt qu'un pool générique unique), alimenté par des cartes-ressource dédiées. Impact direct sur la structure de coût des cartes et le deckbuilding.
- **Backend** séparé (Node/Express) : auth Steamworks, collection, monnaie, boutique — toute la progression est autoritaire côté serveur, jamais mise en cache localement.
- **Site web compagnon** : deck builder en ligne, collection, contenu (FR/EN) partagé avec le client via un flux JSON.
- **Infra** : VPS OVH, Docker Compose + Nginx, CI/CD GitHub Actions sur push.

**Multijoueur : la partie la plus formatrice**

1v1 pair-à-pair via Steamworks, sans serveur d'autorité (chaque client rejoue les actions du pair distant, RNG partagée pour le déterminisme). Deux problèmes concrets : le NAT traversal (connexions P2P peu fiables au départ, migration vers une méthode Steamworks plus robuste + fenêtre de grâce de reconnexion), et une faille de sécurité protocolaire — les commandes reçues du pair n'étaient pas vérifiées comme lui appartenant, un client modifié pouvait usurper des actions. Corrigée avec des vérifications de propriété explicites.

**Qualité**

Une centaine de tests automatisés (GUT) sur le moteur d'effets, les coûts, les auras. Deux systèmes restent trop couplés à la scène pour être testés en isolation — identifié, pas ignoré.

Le plus formateur n'a pas été le gameplay, mais tout ce qui l'entoure : synchro réseau déterministe, sécurisation d'un protocole P2P, cohérence multi-services, mise en prod continue.

Une sortie Steam est prévue à terme. Je continuerai à partager l'avancée ici. En attendant :
🌐 https://wyrdane.com
💬 https://discord.gg/g3JcgreDRA

#gamedev #godotengine #gdscript #indiedev #architecturelogicielle

---

*(Suggestion : ajouter 2-3 captures d'écran ou un court GIF du plateau de jeu — un post avec visuel a bien plus de portée qu'un post texte seul.)*
