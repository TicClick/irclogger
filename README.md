# redeye

redeye is a fork of [whitequark's irclogger](https://github.com/whitequark/irclogger) tailored to `irc.ppy.sh`. refer to the original repository for README and technical details.

## setup

```sh
git clone https://github.com/TicClick/redeye
./setup.sh -u osu_username -p osu_password -d your.domain
```

## update

```sh
docker exec -it containerid /bin/bash
git pull
bundle install --deployment
sudo -iu irclog
service irclogger-logger restart && service irclogger-viewer restart
```
