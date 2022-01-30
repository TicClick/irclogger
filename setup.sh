#!/usr/bin/env bash
set -e -u -o pipefail

# must be run from the application directory

function main() {
  declare domain=''
  declare osu_username=''
  declare osu_password=''

  while getopts 'u:p:d:h' flag; do
    case "$flag" in
      u) osu_username="$OPTARG" ;;
      p) osu_password="$OPTARG" ;;
      d) domain="$OPTARG" ;;
      h) prompt_help; exit 0 ;;
      - | ? | :) echo "run with -h instead"; exit 2 ;;
    esac
  done
  shift $(( OPTIND - 1 ))
  if [ -z $domain ] || [ -z $osu_username ] || [ -z $osu_password ] ; then
    echo "run with -h instead" && exit 2
  fi

  ( install_docker && build_container "$domain" "$osu_username" "$osu_password" ) || exit 2

  cat << EOF > run.sh
#!/usr/bin/env bash

docker run -d -p 80:80 --hostname $domain irclog $@
EOF
  chmod +x ./run.sh

  echo "all done. helpful stuff:"
  echo "    run: ./run.sh"
  echo "  debug: docker exec -it containerid /bin/bash"
  echo "  patch: docker cp /path/to/file containerid:/path/to/file"
  echo "   peek: docker stats / docker top containerid aufx / docker ps"
}

function install_docker() {
  # https://docs.docker.com/engine/install/ubuntu/
  sudo apt-get update
  sudo apt-get install ca-certificates curl gnupg lsb-release
  [ -e /usr/share/keyrings/docker-archive-keyring.gpg ] || \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

  sudo apt-get update
  sudo apt-get install docker-ce docker-ce-cli containerd.io
}

function build_container() {
  sudo docker buildx build . -t irclog \
    --build-arg CONTAINER_ROOT="/var/www/irclog" \
    --build-arg DOMAIN="$1" \
    --build-arg OSU_USERNAME="$2" \
    --build-arg OSU_PASSWORD="$3"
}

function prompt_help() {
  echo "available options:"
  echo "  -u USERNAME   IRC username"
  echo "  -p PASSWORD   IRC password"
  echo "  -u DOMAIN     domain where the logger is run"
}

main "$@"
