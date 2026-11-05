# Pare-feu SMTP sortant

Les conteneurs du serveur **ne peuvent pas envoyer d'e-mails vers l'extérieur** : les
ports SMTP (25, 465, 587, 2525) leur sont refusés. Seuls les conteneurs du réseau Docker
`smtp-out` y ont droit, et seules les **instances de prod** le rejoignent (leur
`compose.prod.yaml`).

Résultat :

- une **démo** ne peut jamais écrire à un vrai prospect, même si quelqu'un saisit un vrai
  serveur SMTP dans son administration : ses e-mails restent dans son Mailpit ;
- une **prod** envoie normalement, sans rien à configurer de plus : son overlay la branche
  sur `smtp-out` dès son premier déploiement ;
- un **nouveau type d'instance**, ou une instance mal configurée, est bloqué par défaut.

## Comment ça marche

| Élément | Rôle |
|---|---|
| réseau `smtp-out` (`10.25.0.0/24`) | créé par `make firewall@install`, rejoint par l'app et le cron de chaque prod, qui en font leur sortie vers Internet (`gw_priority`) |
| règles de la chaîne `DOCKER-USER` (iptables) | SMTP autorisé depuis `smtp-out`, refusé (connexion coupée aussitôt) depuis tout autre conteneur |
| service systemd `srv-firewall` | réapplique les règles à chaque démarrage de Docker : elles ne survivent ni à un redémarrage du serveur, ni à un redémarrage de Docker |

Seul le trafic **sortant des conteneurs** est concerné : Mailpit, joint en interne sur le
port 1025, et la réception d'e-mails par un serveur qui publierait le port 25 ne le sont
pas. En IPv6, aucun conteneur n'a droit au SMTP.

## Commandes

| Commande | Rôle |
|---|---|
| `make firewall@install` | une fois par serveur : crée `smtp-out`, installe et démarre `srv-firewall` (demande `sudo`) ; relançable sans risque |
| `make firewall@status` | état du service, règles en place, conteneurs autorisés à envoyer |
| `make firewall@test` | vérifie depuis deux conteneurs jetables : refusé hors `smtp-out`, joignable depuis `smtp-out` (ouvre la connexion, n'envoie rien) |

Pour retirer le pare-feu (dépannage) : `sudo systemctl stop srv-firewall`. Il revient au
prochain démarrage de Docker ; pour le supprimer pour de bon,
`sudo systemctl disable --now srv-firewall`.

## Vérifier que tout va bien

```bash
make firewall@status   # le service est-il actif ? les règles srv-smtp sont-elles là ?
make firewall@test     # démo refusée, prod joignable ?
```

Après un redémarrage du serveur, `make firewall@status` doit montrer les mêmes règles.
