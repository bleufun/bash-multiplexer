#!/bin/bash

# autor Paweł Lipka
# skrypt na licencji GNU GENERAL PUBLIC LICENSE v3

# napisz plik konfiguracyjny
function create_config_file() {
    mkdir $SCRIPT_CONFIG_DIR
    touch $FULL_CONFIG_DIR
    echo "#!/bin/bash" > $FULL_CONFIG_DIR
    echo "TMP_DIR=\"/tmp/.$SCRIPT_NAME\"" >> $FULL_CONFIG_DIR
    echo "PROMPT=\"\e[1;32m[~# $(hostname)]: \e[0;m\"" >> $FULL_CONFIG_DIR
    echo "MAX_VIRTUAL_TABS=8" >> $FULL_CONFIG_DIR

}

# pobierz minimalny element z tablicy
# używane gdy niszczymy aktywną zakładkę, automatycznie przenosi użytkownika do najniższej
function get_min_tab() {
    active_processes=("$TMP_DIR/process/*")
    # posortuj tablicę; wyświetla tablicę i przekierowywuje do sorta, potem do readarray
    readarray -t sorted < <(for a in ${active_processes[@]}; do echo $a; done | sort)
    # wyświetl pierwszy element i zakończ
    for a in "${sorted[@]}"; do
        echo "$a" | rev | cut -d/ -f1; break;
    done

}

# zniszcz zakładkę
function kill_tab() {
    if [[ -e "$TMP_DIR/process/$1" ]];then
        if [[ $(is_tab_alive $1) == 1 ]]; then
            pid=$(cat "$TMP_DIR/process/$1/pid")
            #kill $pid &> /dev/null
            #echo "$TMP_DIR/process/$1"
            rm -R "$TMP_DIR/process/$1"
        else
            echo "kill tab error"
            #exit 1
        fi
    fi

    # sprawdź czy folder jest pusty
    # ls -A ignoruje ./ i ../
    # -z sprawdza czy długość stringa wynosi zero
    # wyrażenie sprawdzi czy ls -A zwraca zero (brak plików w folderze) i bezpiecznie
    # wyłączy program
    if [[ -z $(ls -A "$TMP_DIR/process/") ]]; then
        safe_quit
    fi

}

# usuń folder tymczasowy
function clean_tmp_dir() {
    rm -R "$TMP_DIR"

}

# usuń wszystkie tymczasowe pliki, usuń podprocesy i wyjdź z programu
function safe_quit() {
    # pobierz wszystkie procesy
    active_processes=("$TMP_DIR/process/*")

    for i in "${active_processes[@]}"; do
        cd $i
        pid=$(cat "pid")
        cd ./
        # zabij proces
        kill "$pid"

        # bezpiecznie usuń pozostałe pliki
        rm -R $i
    done

    # bezpiecznie usuń katalog
    clean_tmp_dir
    clear
    echo "Wyjście z programu..."
    exit

}

# sprawdź czy zakładka istnieje i zwróc wartość
function is_tab_alive() {
    process_dir="$TMP_DIR/process/$1"
    if [[ -e "$process_dir" ]]; then
        if [[ -e "$process_dir/in.pipe" ]] && [[ -e "$process_dir/buffer_output" ]] && [[ -e "$process_dir/pid" ]]; then
            pid=$(cat "$process_dir/pid")
            if ps -p $pid > /dev/null; then
                echo "1"
            else
                echo "0"
            fi
        else
            echo "0"
        fi
    else
        echo "0"
    fi

}

# przywróc wyjście z zakładki
# używane podczas przełączania zakładek
function restore_output() {
    screen_height=$(tput lines)
    cat "$TMP_DIR/process/$1/output" | tail -n $screen_height
}

function create_tab() {
    tab_number=$1
    if [[ $tab_number == "" ]]; then
        tab_number="0"
    fi

    process_dir="$TMP_DIR/process/$tab_number"

    if [[ -e "$process_dir" ]]; then
        do_nothing
    else
        mkdir $process_dir
        mkfifo "$process_dir/in.pipe"
        touch "$process_dir/buffer_output"
    fi

    #echo $(is_tab_alive $tab_number)
    if [[ $(is_tab_alive $tab_number) == 1 ]]; then
        do_nothing
    else
        #bash --rcfile "" < "$process_dir/in.pipe" > "$process_dir/buffer_output" &
        bash --rcfile "" < "$process_dir/in.pipe" | tee "$process_dir/output" > "$process_dir/buffer_output" &
        pid=$!

        # zachowaj otwartego pipe'a po wysłaniu komendy przez echo
        exec 3> "$process_dir/in.pipe"
        echo $pid > "$process_dir/pid"
        #echo $pid
        #kill -9 $pid
    fi
    echo "0" > "$process_dir/busy.flag"
}

# sprawdź czy zakładka, do której zamierzamy się przenieść istnieje
function can_switch_to_tab() {
    local active_processes=("$TMP_DIR/process/*")

    if [[ -e "$TMP_DIR/process/$1" ]]; then
        if [[ $(is_tab_alive $1) == 1 ]]; then
            echo "1"
        else
            echo "0"
        fi
    else
        echo "0"
    fi
}

# zainicjuj foldery cache
function initialize() {
    # jeśli główny folder już istnieje
    if [[ -e "$TMP_DIR" ]]; then
        do_nothing
    else
        # utwórz foldery
        mkdir $TMP_DIR
        mkdir "$TMP_DIR/process"
    fi
}

# wyświetla zgromadzone w buforze tekstowym zakładki wyjście
# oraz czyści bufor po wyświetleniu
# argumenty [numer docelowej zakładki] [zawartość bufora]
function read_output_from_temp() {
    # domyślna zakładka, z której pobieramy wyjście
    default_tab="0"

    if [[ $1 != "" ]]; then
        default_tab=$1
    fi

    temp_output=$2
    # jeśli bufor jest niepusty, wyświetl jego zawartość i wyczyść
    if [[ $temp_output != "" ]]; then
        # wyświetl na ekranie
        cat "$TMP_DIR/process/$1/buffer_output"

        # wyczyść bufor
        >"$TMP_DIR/process/$1/buffer_output"
    fi
}

# pobiera draw_prompt i flagę zajęcia podprocesu
function draw_prompt() {
    echo -e -n "$PROMPT" > /dev/stdout
    # TODO problem z poprawnym wyświelaniem prompta w przełączonej zakładce
    #echo -n "$PROMPT" >> "$TMP_DIR/process/$1/output"
}

function read_loop() {
    local active_processes=("$TMP_DIR/process/*")

    if [[ ${#active_processes[@]} == 0 ]]; then
        do_nothing
        local current_tab=0
    else
        local current_tab=0
        #local current_tab=${active_processes[0]}
    fi
    local current_tab_dir="$TMP_DIR/process/$current_tab"
    local flag_dir="$TMP_DIR/process/$current_tab/busy.flag"
    local should_draw_prompt=1

    # wyświetl piewszy prompt
    #echo -e -n "$PROMPT"
    draw_prompt $current_tab

    # główna pętla
    while true; do
        pid=$(cat "$TMP_DIR/process/$current_tab/pid")
        if [[ $(is_tab_alive $current_tab) == 1 ]]; then
            do_nothing
        else
            do_nothing
            # przełącz na inną zakładkę
        fi

        temp_output=$(cat "$TMP_DIR/process/$current_tab/buffer_output")
        read_output_from_temp $current_tab $temp_output
        # wyświelt prompt
        if [[ $temp_output != "" ]]; then
            flag=$(cat $flag_dir)
            if [[ $should_draw_prompt == "1" ]] && [[ $flag == "0" ]]; then
                #echo -e -n "$PROMPT"
                draw_prompt $current_tab
                should_draw_prompt=0
                #return 0
            fi
        fi
        #should_draw_prompt=$(draw_prompt $should_draw_prompt $flag)

        # sprawdź wejście co 0.1 sekundy
        read -t 0.1 line
        # sprawdź kod błedu. Przy wciśnięciu enter read wyrzuca 0, przy braku akcji 142
        local enter_pressed=$?

        if [[ $enter_pressed != 142 ]]; then
            if [[ $line != "" ]]; then
                case $line in
                    ":help")
                        echo -e $HELP
                        draw_prompt $current_tab
                        ;;
                    ":switch")
                        # przełącz na zakładkę
                        active_processes=("$TMP_DIR/process/*")
                        echo -e "Obecna zakładka to \e[1;33m$current_tab\e[0;m"
                        echo -e "\e[1;31mNumery aktywnych procesów\e[0;m"
                        for i in ${active_processes[@]}; do
                            echo $i | rev | cut -d/ -f1
                        done
                        echo -e "\e[1;31mWybierz proces: \e[0;m"
                        #echo -n -e "Wybierz proces:\n[@] "
                        read line
                        if [[ $(can_switch_to_tab $line) == "1" ]]; then
                            clear
                            current_tab=$line
                            local current_tab_dir="$TMP_DIR/process/$current_tab"
                            local flag_dir="$TMP_DIR/process/$current_tab/busy.flag"
                            restore_output $current_tab
                            #cat "$TMP_DIR/process/$current_tab/output" | tail -n1
                            draw_prompt $current_tab
                            #echo -e -n "$PROMPT"
                        fi
                        do_nothing
                        ;;
                    ":new")
                        # stwórz nową zakładkę
                        let a=$MAX_VIRTUAL_TABS-1
                        echo "Podaj numer zakładki do utworzenia [0..$a]"
                        read line
                        if [ 0 -le $line ] && [ $MAX_VIRTUAL_TABS -gt $line ]; then
                            if [[ $(is_tab_alive $line) == 1 ]]; then
                                echo "zakładka już istnieje"
                                draw_prompt $current_tab
                            else
                                clear
                                echo "utworzono zakładkę"
                                draw_prompt $current_tab
                                create_tab $line
                                current_tab=$line
                                local current_tab_dir="$TMP_DIR/process/$current_tab"
                                local flag_dir="$TMP_DIR/process/$current_tab/busy.flag"
                            fi
                        fi
                        ;;
                    ":kill")
                        # zniszcz obecną i przełącz na nową zakładkę
                        kill_tab $current_tab
                        local new_tab=$(get_min_tab)
                        current_tab=$new_tab
                        local current_tab_dir="$TMP_DIR/process/$current_tab"
                        local flag_dir="$TMP_DIR/process/$current_tab/busy.flag"
                        #clear
                        #echo -e -n "$PROMPT"
                        draw_prompt $current_tab
                        # zniszcz obecną zakładkę
                        ;;
                    ":quit")
                        # wyjdź z programu
                        safe_quit
                        ;;
                    *)
                        flag=$(cat "$flag_dir")
                        if [[ $flag == "0" ]]; then
                            should_draw_prompt=1
                            input="echo \"1\" > $flag_dir; $line; echo \"0\" > $flag_dir"
                        else
                            input="$line"
                        fi
                        echo $input > "$current_tab_dir/in.pipe"
                        ;;
                esac
            elif [[ $enter_pressed == 0 ]]; then
                # wyświel prompt jeśli wciśnięto enter
                #echo -n -e "$PROMPT"
                draw_prompt $current_tab
                should_draw_prompt=1
            fi
        fi

        #read_output_from_temp $current_tab
    done
}
