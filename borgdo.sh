#!/usr/bin/env bash

# MAKE HEAD {{{
function MAKE_HEAD(){
  len=${#1}
  cols=$((($(tput cols)-$len-2)/2))
  printf "\n"
  for (( i=0;i<$(tput cols);i++ ))
  do
    printf "-"
  done
  printf "\n"
  for (( i=0; i<$cols;i++ ))
  do
    printf "-"
  done
  printf " $1 "
  for (( i=0; i<$cols;i++ ))
  do
    printf "-"
  done
  for (( i=0;i<$(tput cols);i++ ))
  do
    printf "-"
  done
  printf "\n"
}
# }}}
# CHECK FOR BORG {{{
function CHECK_FOR_BORG() {
  if [[ $(dpkg -l | grep borg) == "" ]]; then
    MAKE_HEAD "BORG INSTALLER"
    printf "\n\033[0;31mBorg is not installed on your system!\033[0m\n"
    while true; do
      read -p "Do you want to install it? [y/n]> " yn
      case $yn in
        [Yy]* )
          apt-get install borgbackup borgbackup-doc
          printf "\n\033[0;32mBorg is now installed on your system!\033[0m"
          break;;
        [Nn]* )
          printf "\n\033[0;31mBorg is not installed. Don't forget to install it later! with \"apt-get install borgbackup borgbackup-doc\"\033[0m\n"
          break;;
      esac
    done
  fi
}
#}}}
# CREATE SETTINGS {{{
function CREATE_SETTINGS() {
  if [ ! -d /etc/borgrc/config ]; then
    mkdir -p /etc/borgrc/config
    chmod 664 /etc/borgrc/config
    CREATE_SETTINGS
  else
    #HEADER
    MAKE_HEAD "CREATE  NEW SETTINGS"
    printf "\n"
    #Header end
    #Name Settings
    read -p "How to you want to name your Settings? [name]> " settingsname
    #Name Settings end
    #BORG_REPO
    MAKE_HEAD "BORG REPOSITORY SETTINGS"
    printf "\n"
    read -p "On which server you want to store your Backups [FQDN or IP]> " server
    printf "\nMake sure the remote user already exists\n"
    read -p "What user to use on the remote host to manage your Backups? [USER]> " user
    read -p "Which user you want to make the backups with [LOCALHOST-USER]> " backupuser
    read -p "What Port to use to connect via ssh [PORT]> " port
    read -p "How to name the Backup? [backupname]> " backupname
    if [[ $user == "root" ]]; then
      repopath="/root/$backupname"
    else
      repopath="/home/$user/$backupname"
    fi
    echo "#DO NOT DELETE! CONFIG FILE FOR BORG (automaticly generated by borgdo.sh)" > "/etc/borgrc/config/$settingsname"
    echo "export BORG_REPO='ssh://$user@$server:$port$repopath'" >> "/etc/borgrc/config/$settingsname"
    echo "export BORG_BACKUPNAME='$backupname'" >> "/etc/borgrc/config/$settingsname"
    printf "\n\nYou have created BORG_REPO=ssh://$user@$server:$port$repopath\n"
    #Repo settings end
    #password settings
    MAKE_HEAD "PASSWORD  SETTINGS"
    printf "\nTo create and access a Borg Repository we need to define a Password\n"
    password_check=0
    while [ $password_check -eq 0 ]; do
      read -s -p "Writing your password. Won't be shown on the commandline [PASSWORD]> " repo_password
      printf "\n"
      read -s -p "Insert your password again!> " password_again
      if [[ $repo_password == $password_again ]]; then
        password_check=1
      fi
    printf "\n"
    done
    echo "export BORG_NEW_PASSPHRASE='$repo_password'" >> "/etc/borgrc/config/$settingsname"
    echo "export BORG_PASSPHRASE='$repo_password'" >> "/etc/borgrc/config/$settingsname"
    printf "\n\033[0;32mYour Password has been set\033[0m"
    #password settings end
    #ssh settings
    MAKE_HEAD "SSH SETTINGS"
    printf "\n"
    while true; do
      read -p "Do You want to use a ssh_key file or create a new one? [y/n/c]> " ync
      case $ync in
        [Yy]* )
          read -p "Where is the keyfile located [/root/.ssh/rsa_id_key]> " ssh_key
          echo "export BORG_RSH='ssh -i $ssh_key -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p $port'" >> "/etc/borgrc/config/$settingsname"
          printf "\n\nYou've created BORG_RSH=ssh -i $ssh_key"
          break;;
        [Nn]* )
          printf "\n\n\033[0;31mNo ssh_key_auth is used"
          printf "\nLater you have to use \"echo \"export BORG_RSH='ssh -i /path/to/key -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -p port'\"\" to get everything working!\033[0m"
          break;;
        [Cc]* )
          printf "\n\nCreating an ssh-key for you and copying it to the remote host!\n\n!!\033[1;33mDo not enter a passphrase!!\033[0m\n\n"
          if [[ $backupuser == "root" ]]; then
            if [ ! -d /root/.ssh ]; then
              mkdir /root/.ssh
            fi
            ssh-keygen -f "/root/.ssh/borg_id_rsa" -t rsa -b 4096 -C "borg_ssh_key for $backupuser"
            scp -P $port /root/.ssh/borg_id_rsa.pub $user@$server:/tmp/borg_id_rsa.pub
            echo "export BORG_RSH='ssh -i /root/.ssh/borg_id_rsa'" >> "/etc/borgrc/config/$settingsname"
            printf "\nYou've created BORG_RSH=ssh -i /root/.ssh/borg_id_rsa and will be copied it to the backupserver"
          else
            if [ ! -d /home/$backupuser/.ssh ]; then
              mkdir /home/$backupuser/.ssh
            fi
            ssh-keygen -f "/home/$backupuser/.ssh/borg_id_rsa" -t rsa -b 4096 -C "borg_ssh_key for $backupuser"
            chown $backupuser:$backupuser /home/$backupuser/.ssh/*
            scp -P $port /home/$backupuser/.ssh/borg_id_rsa.pub $user@$server:/tmp/borg_id_rsa.pub
            echo "export BORG_RSH='ssh -i /home/$backupuser/.ssh/borg_id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $port'" >> "/etc/borgrc/config/$settingsname"
            printf "\nYou've created \"BORG_RSH=ssh -i /home/$backupuser/.ssh/borg_id_rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p $port\" and will be copied it to the backupserver"
          fi
          if [[ $user == "root" ]];then
            ssh -p $port root@$server "cat /tmp/borg_id_rsa.pub >> /root/.ssh/authorized_keys"
          else
            ssh -p $port root@$server "cat /tmp/borg_id_rsa.pub >> /home/$user/.ssh/authorized_keys"
          fi
          break;;
      esac
    done
    #ssh settings end
    clear
    #borg install remote host
    if [[ $(ssh -p $port $user@$server 'dpkg -l | grep borg') == "" ]]; then
      MAKE_HEAD "BORG INSTALLER"
      printf "\n"
      printf "\033[0;31mBorg is not installed on the remote backupmachine!\033[0m\n"
      while true; do
        read -p "Do you want to install it now? [y/n]> " ynborg
        case $ynborg in
          [Yy]* )
            ssh -p $port root@$server 'apt-get install borgbackup borgbackup-doc'
            printf "\nBorg is now installed on the remote host!\n"
            break;;
          [Nn]* )
            printf "\n\033[1;33mDo not forget to install it later!\033[0m"
            printf "\nPackages to install: borgbackup borgbackup-doc\n"
            break;;
        esac
      done
    fi
    #borg install remote host
    #Backupsettings
    MAKE_HEAD "WHAT DIRECTORY TO BACKUP"
    printf "\nWhat directory do you want to backup?\nGive an absolute path\n"
    while [[ $backupdir == "" ]]; do
      read -p "Insert your path [/home/example]> " backupdir
      if [[ $backupdir =~ ^/.*/$ ]]; then
        backupdir="${backupdir::-1}"
      fi
      if [[ $backupdir =~ ^[^\/].*$ ]];then
        backupdir=""
      fi
    done
    echo "export BORG_BACKUP_DIR='$backupdir'" >> "/etc/borgrc/config/$settingsname"
    printf "\nYou've created BORG_BACKUP_DIR=\"$backupdir\""
    #backupsettings end
    #encryption settings
    MAKE_HEAD "ENCRYPTION  SETTINGS"
    printf "\n"
    while true; do
      printf "\nWhat encryption do you want to use for your automatic Backups"
      printf "\n1) None"
      printf "\n2) repokey (passphrase)"
      printf "\n3) keyfile (passphrase and key)\n"
      read -p "Select [1/2/3]> " enc
      case $enc in
        "1" )
          echo "export BORG_ENCRYPTION='none'" >> "/etc/borgrc/config/$settingsname"
          printf "\nYou've created BORG_ENCRYPTION=\"none\""
          break;;
        "2" )
          echo "export BORG_ENCRYPTION='repokey'" >> "/etc/borgrc/config/$settingsname"
          printf "\nYou've created BORG_ENCRYPTION=\"repokey\""
          break;;
        "3" )
          echo "export BORG_ENCRYPTION='keyfile'" >> "/etc/borgrc/config/$settingsname"
          printf "\nYou've created BORG_ENCRYPTION=\"keyfile\""
          break;;
      esac
    done
    #encryption settings end
    #compression settings
    MAKE_HEAD "COMPRESSION SETTINGS"
    printf "\n"
    while true; do
      printf "\nWhich compression do you want to use for your automated Backups?"
      printf "\n1) none (default)"
      printf "\n2) lz4 (fast speed, low compression)"
      printf "\n3) zlib (medium speed, medium compression)"
      printf "\n4) lzma (slow speed, high compression)"
      printf "\n\n"
      read -p "Typ in a number[1-4]> " compression
      case $compression in
        "1" )
          echo "export BORG_COMPRESSION='none'" >> "/etc/borgrc/config/$settingsname"
          printf "\nTaking default"
          break;;
        "2" )
          read -p "What level (1 - 9) of compression do you want to use [default:6]?> " level
          if [ $level -lt 10 ] && [ $level -gt 0 ]; then
            echo "export BORG_COMPRESSION='lz4,$level'" >> "/etc/borgrc/config/$settingsname"
            printf "\nYou've created BORG_COMPRESSION=\"lz4,$level\""
          else
            printf "\nTaking default value"
            echo "export BORG_COMPRESSION='lz4,6'" >> "/etc/borgrc/config/$settingsname"
            printf "\nYou've created BORG_COMPRESSION=\"lz4,6\""
          fi
          break;;
        "3" )
          read -p "What level (1 - 9) of compression do you want to use [default:6]?> " level
          if [ $level -lt 10 ] && [ $level -gt 0 ]; then
            echo "export BORG_COMPRESSION='zlib,$level'" >> "/etc/borgrc/config/$settingsname"
            printf "\nYou've created BORG_COMPRESSION=\"zlib,$level\""
          else
            printf "\nTaking default value"
            echo "export BORG_COMPRESSION='zlib,6'" >> "/etc/borgrc/config/$settingsname"
            printf "\nYou've created BORG_COMPRESSION=\"zlib,6\""
          fi
          break;;
        "4" )
          read -p "What level (1 - 9) of compression do you want to use [default:6]?> " level
          if [ $level -lt 10 ] && [ $level -gt 0 ]; then
            echo "export BORG_COMPRESSION='lzma,$level'" >> "/etc/borgrc/config/$settingsname"
            printf "\nYou've created BORG_COMPRESSION=\"lzma,$level\""
          else
            printf "\nTaking default value"
            echo "export BORG_COMPRESSION='lzma,6'" >> "/etc/borgrc/config/$settingsname"
            printf "\nYou've created BORG_COMPRESSION=\"lzma,6\""
          fi
          break;;
      esac
    done
    printf "\n"
    #compression settings end
    clear
    #localdirectory settings
    MAKE_HEAD "LOCAL DIRECTORY SETTINGS"
    printf "\nDefault Dir settings on localhost are [/home/user/.config/].\n\033[0;31mDO NOT\033[0m change if you do not really know what you do!\n"
    while true; do
      read -p "Do you want to change this settings| Press \033[0;32m[ENTER]\033[0m for default? [y/n]> " yn
      case $yn in
        "" )
          printf "\nSettings left on default"
          break;;
        [Yy]* )
          read -p "What should be the base borg dir where everything is stored? [default: ~/.]> " base_dir
          read -p "Where to store the config files (relativ to base_dir)? [default: .config/borg]> " config_dir
          read -p "Where to store the cache files (relativ to base_dir)? [default: .cache/borg]> " cache_dir
          read -p "Where to store the security data (relativ to base_dir)? [default: .config/borg/security]> " security_dir
          read -p "Where to store the repo keys (relativ to base_dir)? [default: .config/borg/keys]> " keys_dir
          echo "#Directory settings" >> "/etc/borgrc/config/$settingsname"
          echo "export BORG_BASE_DIR='$base_dir'" >> "/etc/borgrc/config/$settingsname"
          echo "export BORG_CONFIG_DIR='$base_dir/$config_dir'" >> "/etc/borgrc/config/$settingsname"
          echo "export BORG_CACHE_DIR='$base_dir/$cache_dir'" >> "/etc/borgrc/config/$settingsname"
          echo "export BORG_SECURITY_DIR='$base_dir/$security_dir'" >> "/etc/borgrc/config/$settingsname"
          echo "export BORG_KEYS_DIR='$base_dir/$keys_dir'" >> "/etc/borgrc/config/$settingsname"
          printf "\nCreating your directories"
          mkdir -p "$base_dir"
          mkdir -p "$base_dir/$config_dir"
          mkdir -p "$base_dir/$cache_dir"
          mkdir -p "$base_dir/$security_dir"
          mkdir -p "$base_dir/$keys_dir"
          chmod 700 -R "$base_dir"
          printf "\nThe directories have been created!"
          break;;
        [Nn]* )
          printf "\nSettings left on default"
          break;;
      esac
    done
    #tmpdir settings
    MAKE_HEAD "TEMPDIR SETTINGS"
    printf "\nSetting the TMP file dir. Needs a lot of space\nIf You dont want to set a new tmpdir hit enter\n\033[0;31mDO NOT\033[0m change if you do not really know what you do!\n"
    read -p "Give a Path \033[0;32m[ENTER]\033[0m or [/home/borg/tmp]> " tmpdir
    if [[ $tmpdir != "" ]];then
      if [ ! -d $tmpdir ]; then
        mkdir -p $tmpdir
      fi
      echo "export TMPDIR='$tmpdir'" >> "/etc/borgrc/config/$settingsname"
      printf "\nTMPDIR is set to $tmpdir"
    else
      printf "\nDefault TMP DIR is used"
    fi
    #tempdir settings end
    printf "\n\n"
    for (( i=0;i<$(tput cols);i++ ))
    do
      printf "-"
    done
    #localdirectory end
    clear
    printf "\n"
    MAKE_HEAD "\033[0;32mAll Settings have been made\033[0m"
    printf "\n\n"
    chmod 600 "/etc/borgrc/config/$settingsname"
    chown $backupuser:$backupuser "/etc/borgrc/config/$settingsname"
    source "/etc/borgrc/config/$settingsname"
    if [[ $backupuser != "root" ]];then
      if [[ ! -d /home/$backupuser/borgrc ]];then
        mkdir /home/$backupuser/borgrc
      fi
      chown $backupuser:$backupuser /home/$backupuser/borgrc
      cp /etc/borgrc/config/$settingsname /home/$backupuser/borgrc/$settingsname
    fi
    while true; do
      read -p "Do you already want to create this Repository? [y/n]> " ynb
      case $ynb in
        [Yy]* )
          if [[ $backupuser != "root" ]];then
            su -c "cd ~ ; source borgrc/$settingsname ; borg init --encryption=$BORG_ENCRYPTION $user@$server:$backupname" $backupuser
          else
            borg init --encryption=$BORG_ENCRYPTION $user@$server:$backupname
          fi
          break;;
        [Nn]* )
          printf "\nLogin as the user you want to do the Backups with and use:\n"
          printf "\n\"source \"/\$HOME/borgrc/$settingsname\" && borg init --encryption=$BORG_ENCRYPTION $user@$server:$backupname\""
          break;;
      esac
    done
  fi
}
#}}}
# CHOOSE SETTINGS {{{
function CHOOSE_SETTINGS() {
  clear
  MAKE_HEAD "CHOOSE YOUR SETTINGS"
  printf "\n\nPlease Select a Setting you want to use!\nThe follwing settings are stored:\033[1;33m"
  ls -l /etc/borgrc/config | awk -F' ' '{ print $9 }'
  printf "\033[0m"
  read -p "Which of this settings you want to use?> " sourcerc
  source /etc/borgrc/config/$sourcerc
  printf "\n\n\033[0;32mYou took $sourcerc and can go on!\033[0m"
  currentsource=$sourcerc
  currentuser="$(ls -l /etc/borgrc/config/$sourcerc | awk -F' ' '{ print $3 }')"
}
#}}}
# CREATE ARCHIVE {{{
function CREATE_ARCHIVE() {
  clear
  MAKE_HEAD "MANUALLY BACKUP CREATION"
  printf "\n"
  while true; do
    read -p "Do you want to do a manuall Backup? [y/n]> " yn
    case $yn in
      [Yy]* )
        read -p "Do you want to print the progress? [y/n]> " progress
        if [[ $progress == "y" ]]; then
          backup="-p"
        else
          printf "\nNo progress output"
        fi
        read -p "Should I give you stats about your archive at the end?[y/n]> " stats
        if [[ $stats == "y" ]]; then
          backup="$backup -s"
        else
          printf "\nNo stats output at the end"
        fi
        while true; do
          printf "\n\nWhich compression do you want to use?"
          printf "\n1) none (default)"
          printf "\n2) lz4 (fast speed, low compression)"
          printf "\n3) zlib (medium speed, medium compression)"
          printf "\n4) lzma (slow speed, high compression)"
          printf "\n\n"
          read -p "Typ in a number[1-4]> " compression
          case $compression in
            "1" )
              printf "\nTaking default"
              break;;
            "2" )
              read -p "What level (1 - 9) of compression do you want to use? [default:6]> " level
              if [ $level -lt 10 ] && [ $level -gt 0 ]; then
                backup="$backup -C lz4,$level"
              else
                printf "\nTaking default value"
                backup="$backup -C lz4,6"
              fi
              break;;
            "3" )
              read -p "What level (1 - 9) of compression do you want to use? [default:6]> " level
              if [ $level -lt 10 ] && [ $level -gt 0 ]; then
                backup="$backup -C zlib,$level"
              else
                printf "\nTaking default value"
                backup="$backup -C zlib,6"
              fi
              break;;
            "4" )
              read -p "What level (1 - 9) of compression do you want to use? [default:6]?" level
              if [ $level -lt 10 ] && [ $level -gt 0 ]; then
                backup="$backup -C lzma,$level"
              else
                printf "\nTaking default value"
                backup="$backup -C lzma,6"
              fi
              break;;
          esac
        done
        printf "\n"
        printf "\nName the backup"
        read -p "Default backupname would be [manuall-{Date}]. Typ in a name or press [ENTER] for default> " name
        printf "\nStarting backup now"
        if [[ $currentuser != "root" ]]; then
          if [[ $name == "" ]]; then
            su -c "cd ~ ; source borgrc/$currentsource ; borg create $backup ::manuall-{now:%d.%m.%Y} $BORG_BACKUP_DIR" $currentuser
          else
            su -c "cd ~ ; source borgrc/$currentsource ; borg create $backup ::$name $BORG_BACKUP_DIR" $currentuser
          fi
        else
          if [[ $name == "" ]]; then
            source /etc/borgrc/config/$currentsource && borg create $backup ::manuall-{now:%d.%m.%Y} $BORG_BACKUP_DIR
          else
            source /etc/borgrc/config/$currentsource && borg create $backup ::$name $BORG_BACKUP_DIR
          fi
        fi
        break;;
      [Nn]* )
        printf "\nOk, no backup. Going back into menu"
        break;;
    esac
  done
}
#}}}
# CREATE AUTOMATION {{{
function CREATE_AUTOMAGIE() {
  clear
  MAKE_HEAD "BACKUPAUTOMATION"
  printf "\n"
  if [ ! -d /etc/borgrc/cronbackup ]; then
    mkdir -p /etc/borgrc/cronbackup
    chmod 664 /etc/borgrc/cronbackup
    CREATE_AUTOMAGIE
  else
    while true; do
      read -p "Do you want to automate your backups, or change the automation settings? [y/n]> " yn
      case $yn in
        [Nn]* )
          printf "\nOK, going back into the menu"
          break;;
        [Yy]* )
          read -p "Which user should make the automatic backups? [username]> " backupuser
          printf "\n\nPlease select a setting you want to use!\nThe follwing settings are stored at the moment:"
          ls -l /etc/borgrc/config | awk -F' ' '{ print $9 }'
          printf "\n"
          read -p "Which of this settings you want to use?> " sourcerc
          source /etc/borgrc/config/$sourcerc
          if [[ $(crontab -l -u $backupuser) != "no crontab for $backupuser" ]];then
            crontab -l -u $backupuser > ~/.crontab.tmp
          else
            touch ~/.crontab.tmp
          fi
          if [[ $(crontab -l -u $backupuser | grep borg) != "" ]]; then
            printf "\nYour current crontab settings for borg are:"
            printf "\nMinute | Hour | Day of Month | Month | Day of week (Timesettings)"
            cat  ~/.crontab.tmp | grep borg
            printf "\n\033[1;33mNow you can create new ones - the old settings will be deleted\033[0m"
            sed -i /^.*borg.*$/d ~/.crontab.tmp
          fi
          printf "\nDaily backups"
          printf "\nNow you have to choose the time to create the backups\n"
          read -p "Hour [0-23]> " hour
          read -p "Minute [0-59]> " minute
          echo "#!/usr/bin/env bash" > /etc/borgrc/cronbackup/$sourcerc.cron.sh
          chmod +x /etc/borgrc/cronbackup/$sourcerc.cron.sh
          if [[ $backupuser != "root" ]];then
            chown $backupuser:$backupuser /etc/borgrc/cronbackup/$sourcerc.cron.sh
            echo "source /home/$backupuser/borgrc/$sourcerc" >> /etc/borgrc/cronbackup/$sourcerc.cron.sh
          else
            echo "source /etc/borgrc/config/$sourcerc" >> /etc/borgrc/cronbackup/$sourcerc.cron.sh
          fi
          echo "borg create -C $BORG_COMPRESSION ::$BORG_BACKUPNAME-{now:\%d.\%m.\%Y} $BORG_BACKUP_DIR" >> /etc/borgrc/cronbackup/$sourcerc.cron.sh
          if [[ $backupuser != "root" ]];then
            echo "$minute $hour * * * /home/$backupuser/borgrc/$sourcerc.cron.sh" >> ~/.crontab.tmp
          else
            echo "$minute $hour * * * /etc/borgrc/cronbackup/$sourcerc.cron.sh" >> ~/.crontab.tmp
          fi
          printf "\nDo you want to create a Backuprotation\n"
          read -p "for example: keep 1 week of backups and then 4 end of week and an end of month? [y/n]> " ok
          if [[ $ok == "y" || $ok == "Y" ]]; then
            read -p "How many daily backups you want to keep? [0 or more]> " prune_daily
            read -p "How many weekly backups you want to keep? [0 or more]> " prune_weekly
            read -p "How many monthly backups you want to keep? [-1 for ever] or [0 or more]> " prune_monthly
            if [[ $prune_monthly != "-1" ]]; then
              read -p "How many yearly backups to keep? [0 or more]> " prune_yearly
              echo "borg prune --keep-daily=$prune_daily --keep-weekly=$prune_weekly --keep-monthly=$prune_monthly --keep-yearly=$prune_yearly ::" >> /etc/borgrc/cronbackup/$sourcerc.cron.sh
            else
              echo "borg prune --keep-daily=$prune_daily --keep-weekly=$prune_weekly --keep-monthly=$prune_monthly ::" >> /etc/borgrc/cronbackup/$sourcerc.cron.sh
            fi
          else
            printf "\nYou have manually keep track of your backuphistory"
          fi
          if [[ $backupuser != "root" ]];then
            cp /etc/borgrc/cronbackup/$sourcerc.cron.sh /home/$backupuser/borgrc/$sourcerc.cron.sh
          fi
          crontab -u $backupuser ~/.crontab.tmp
          rm -f ~/.crontab.tmp
          printf "\n\n\033[0;32mNew Crontab is installed.\033[0m"
          printf "\nCheck the new settings: "
          printf "\nMinute | Hour | Day of Month | ... | command\n"
          echo "$(crontab -l -u $backupuser | grep borg)"
          echo "Befehle der Datei:"
          cat /etc/borgrc/cronbackup/$sourcerc.cron.sh
          break;;
      esac
    done
  fi
}
#}}}
# LIST ARCHIVES {{{
function LIST_ARCHIVES() {
  MAKE_HEAD "YOUR STORED BACKUPS"
  printf "\n"
  if [[ $currentuser != "root" ]]; then
    su -c "cd ~ && source borgrc/$currentsource && borg list ::" $currentuser
  else
    borg list ::
  fi
}
#}}}
# CHECK REPO {{{
function CHECK_REPO() {
  clear
  MAKE_HEAD "CHECK YOUR REPOS CONSISTENCY"
  printf "\n"
  if [[ $currentuser != "root" ]];then
    su -c "cd ~ && source borgrc/$currentsource && borg check -v --repository-only ::" $currentuser
  else
    borg check -v --repository-only ::
  fi
}
#}}}
# DELETE ARCHIVE {{{
function DELETE_ARCHIVE() {
  clear
  MAKE_HEAD "DELETE  A BACKUP"
  LIST_ARCHIVES
  printf "\n"
  read -p "Type the name of an archive to delete it> " archive
  if [[ $currentuser != "root" ]];then
    su -c "cd ~ && source borgrc/$currentsource && borg delete ::$archive" $currentuser
  else
    borg delete ::$archive
  fi
}
#}}}
# INFO ARCHIVE {{{
function INFO_ARCHIVE() {
  clear
  MAKE_HEAD "MORE ARCHIVE INFOS"
  LIST_ARCHIVES
  printf "\n"
  read -p "Type the name of an archive to see more informations> " archive
  if [[ $currentuser != "root" ]]; then
    su -c "cd ~ && source borgrc/$currentsource && borg info ::$archive" $currentuser
  else
    borg info ::$archive
  fi
}
#}}}
# EXPORTKEY {{{
function EXPORT_KEY() {
  clear
  MAKE_HEAD "EXPORT REPO KEY  INTO A FILE"
  printf "\n"
  read -p "Where to store the key [~/.borgrepokey]> " key_path
  if [[ $currentuser != "root" ]]; then
    su -c "cd ~ && source borgrc/$currentsource && borg key export :: $keypath" $currentuser
  else
    borg key export :: $keypath
  fi
}
#}}}
# DUMP_MYSQL {{{
function DUMP_MYSQL() {
  clear
  MAKE_HEAD "CREATE A MYSQLBACKUP"
  printf "\n"
  read -p "Which user should make the automatic Backups? [username]> " backupuser
  if [[ $(crontab -l -u $backupuser| grep borg) == "" ]]; then
    printf "\n\n\033[0;31mFirst you have to create the automatic backups!\nChoose number 1 in the mainmenu!\033[0m"
    sleep 7
  else
    printf "\nIf you want to create a mysql database dump and back it up, follow this steps\n"
    printf "\nFirst of all test if you need a user and a password to connect to the database.\nTest it on the user you want to make the backups with.\nOpen a terminal and try \"mysqldump -h localhost \$yourdatabase > /tmp/mysqltestdump\"\n"
    while true; do
      read -p "Does this create a dump? [y/n]> " ynuser
      case $ynuser in
        [Nn]* )
          printf "\nOK, please provide me with the username and the password!\n\n"
          read -p "Write the database user to make the Dump with [name]> " dbuser
          read -s -p "Give me the password for the user [name]> " dbpassword
          ;;
        [Yy]* )
          printf "\n\n"
          read -p "Now i only have to know the name of your database [name]> " dbname
          break;;
      esac
    done
    printf "\n\nPlease Select a Setting you want to use the Dumo with!\nThe follwing settings are stored at the moment:"
    ls -l /etc/borgrc/config | awk -F' ' '{ print $9 }'
    printf "\n"
    read -p "Which of this settings you want to use?> " sourcerc
    source /etc/borgrc/config/$sourcerc
    crontab -l -u $backupuser > ~/.crontab.tmp
    if [[ $(crontab -l -u $backupuser| grep mysqldump) != "" ]];then
      sed -i /^.*mysqldump.*$/d ~/.crontab.tmp
    fi
    min="$(cat ~/.crontab.tmp | grep "$sourcerc" | awk -F' ' '{ print $1 }')"
    hour="$(cat ~/.crontab.tmp | grep "$sourcerc" | awk -F' ' '{ print $2 }')"
    if [ $min -eq 0 ] || [ $min -gt 0 ] && [ $min -lt 5 ]; then
      min=$((min+60-5))
      hour=$((hour-1))
    else
      min=$((min-5))
    fi
    if [[ $dbuser == "" ]]; then
      echo "$min $hour * * * mysqldump -h localhost $dbname > $BORG_BACKUP_DIR/mysqldump" >> ~/.crontab.tmp
    else
      echo "$min $hour * * * mysqldump -u $dbuser -p$dbpassword -h localhost $dbname > $BORG_BACKUP_DIR/mysqldump" >> ~/.crontab.tmp
    fi
    crontab -u $backupuser ~/.crontab.tmp
    rm -f ~/.crontab.tmp
    printf "\n\nA new crontab has been installed. Please check if the settings are correct.\nThe Mysqldump should be done 5 min before the Backup!\n\nNew Crontab:\n"
    echo "$(crontab -l -u $backupuser | grep mysqldump)"
    echo "$(crontab -l -u $backupuser | grep borg)"
  fi
}
#}}}
# CHANGE BORGRC {{{
function CHANGE_BORGRC() {
  clear
  MAKE_HEAD "CHANGE  SETTINGS"
  printf "\nThe following settings have been made:\n"
  count=0;
  while read line
  do
    printf "%s\n" "$count) $line"
    count=$((count+1))
  done < /etc/borgrc/config/$currentsource
  printf "\n\nWhat to change?\n"
  read -p "Insert the number or q for quit!> " changesettings
  if [[ $changesettings != "q" ]];then
    stringr=$(sed -n "$changesettings{p;q}" "/etc/borgrc/config/$currentsource")
    if [[ $stringr != "" ]]; then
      printf "\nInsert a new setting for "
      echo $stringr | awk -F'=' '{ print $1 }'
      printf "\n"
      read -p "New Setting> " newsetting
      echo "$stringr='$newsetting'" >> /etc/borgrc/config/$currentsource
      sed "$((changesettings))d" /etc/borgrc/config/$currentsource > /etc/borgrc/config/$currentsource
      if [[ $currentuser != "root" ]]; then
        cp /etc/borgrc/config/$currentsource /home/$currentuser/borgrc/$currentsource
      fi
    else
      printf "\n\033[0;31mThis was a wrong number. Please try again!\033[0m"
    fi
  fi
}
#}}}
# MENU {{{
function MENU(){
  clear
  menu0=("Select a Settingsfile" "Create a Settingsfile" [11]="Exit")
  menu1=("Select a Settingsfile" "Create a Settingsfile" "Change a Settingsfile" "Create Backupautomation" "Create Mysqldump automation" "List all Backups" "List Backupinfo" "Create Backup" "Delete Backup" "check Repo consistency" "export Security Key" "Exit")
  MAKE_HEAD "BORG  BACKUP MANAGER"
  CHECK_FOR_BORG
  while :
  do
    while true; do
      MAKE_HEAD "MENU"
      printf "\n"
      if [[ $currentsource != "" ]];then
        printf "\033[0;32mYour current Settings are from $currentsource with user $currentuser\033[0m\n\nWhat do you want to do?\n"
        for index in ${!menu1[*]}
        do
          printf "%2d) %s\n" $((index+1)) "${menu1[$index]}"
        done
      else
        printf "\033[0;31mYou do not use a source at the moment, select one first!\033[0m\n\nWhat do you want to do?\n"
        for index in ${!menu0[*]}
        do
          printf "%2d) %s\n" $((index+1)) "${menu0[$index]}"
        done
      fi
      printf "\n"
      read -p "Choose a Task to do [1-${#menu1[*]}]> " option
      case $option in
        "1" )
          CHOOSE_SETTINGS
          break;;
        "2" )
          CREATE_SETTINGS
          break;;
        "3" )
          CHANGE_BORGRC
          break;;
        "4" )
          CREATE_AUTOMAGIE
          break;;
        "5" )
          DUMP_MYSQL
          break;;
        "6" )
          LIST_ARCHIVES
          break;;
        "7" )
          INFO_ARCHIVE
          break;;
        "8" )
          CREATE_ARCHIVE
          break;;
        "9" )
          DELETE_ARCHIVE
          break;;
        "10" )
          CHECK_REPO
          break;;
        "11" )
          EXPORT_KEY
          break;;
        "12" )
          echo "cya"
          exit 0
          break;;
      esac
    done
  done
}
#}}}
MENU
