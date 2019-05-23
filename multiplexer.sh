#!/bin/bash

# skrypt na licencji GNU GENERAL PUBLIC LICENSE v3

: '
przykład wieloliniowego komentarza
'

VERSION="0.1"

HELP="Manadżer terminali wirtualnych pozwalający tworzyć
\nproste środowiska, w których można wykonywać polecenia powłoki BASH.
\n[Argumenty programu -h -v -t]
\n -h - wyświetl pomoc
\n -v - wyświetl wersję
\n -t [n] - zmień limit terminali
\n\nPodstawowymi komendami obsługi są
\n :help - wyświetl pomoc
\n :switch - przełącz na wybraną zakładkę
\n :new - utwórz nową zakładkę
\n :kill - zamknij bieżącą zakładkę
\n :quit - wyjdź z programu
\n\n@2016
"
#podstawowe stałe używane podczas pracy programu niezdefiniowane w konfiguracji
SCRIPT_NAME="virtman"
SCRIPT_DIR="."
SCRIPT_CONFIG_DIR="$HOME/.$SCRIPT_NAME"
CONFIG_FILE_NAME="config.sh"
FULL_CONFIG_DIR="$SCRIPT_CONFIG_DIR/$CONFIG_FILE_NAME"

# pusta funkcja
function do_nothing() {
    :
}

# inicjalizacja skryptu

# załaduj plik z kodem źródłowym
function load_source_file() {
    if [[ -e $SCRIPT_DIR/$1 ]]; then
        source "$SCRIPT_DIR/$1"
    else
        echo "Błąd podczas ładowania $1"
        exit 1
    fi

}

# sprawdź czy plik konfiguracyjny już istnieje
function load_config_file() {
    if [[ -e "$1" ]]; then
        source $1
        #echo "config loaded"
    else
        # stwórz nowy plik konfiguracyjny
        create_config_file
        source $1
        echo "config created"
    fi
}

# wczytaj pliki źródłowe i konfiguracyjne
load_source_file "core.sh"
load_config_file $FULL_CONFIG_DIR

# zainicjuj obsługę przerwań
trap "safe_quit; exit" SIGINT

# obsłuż argumenty programu
while getopts ":h :v :t: :p:" opt; do
    case $opt in
        h)
            echo -e $HELP
            exit
            ;;
        v)
            echo "Manadżer terminali wirtualnych wersja $VERSION"
            echo "skrypt na licencji GNU GENERAL PUBLIC LICENSE v3"
            exit
            ;;
        t)
            MAX_VIRTUAL_TABS=$OPTARG
            ;;
        p)
            echo $OPTARG
            PROMPT=$OPTARG
            ;;
        \?)
            do_nothing
            ;;
    esac
done

if [[ -z $PROMPT ]]; then
    echo "Błąd: pusty prompt"
    exit
fi

# sprawdź czy maksymalna liczba terminali nie jest mniejsza od 1
if [[ $MAX_VIRTUAL_TABS -lt 1 ]]; then
    echo "Bład: zbyt mała podana liczba terminali"
    exit
fi

# zainicjuj
initialize
create_tab 0

get_min_tab

# wyczyść ekran i zacznij wczytywanie wejścia
clear
read_loop
