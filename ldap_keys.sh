#!/bin/bash

trap ctrl_c SIGHUP SIGINT SIGTERM

LDAP_BASE='dc=cat,dc=pdx,dc=edu'
LDAP_URI='ldap://openldap.cat.pdx.edu'
KEY_CLASS=sshPublicKey
USERNAME=$USER
PID=$$
FILE=""
TEMPFILE=`tempfile`

ctrl_c() {
	rm -f $TEMPFILE
	echo ""
	echo "fuck you for hitting CTRL-C"
	exit 10;
}

option_help () {
	case "$1" in
		list) cat <<-EndOfDocument
			Usage:
			  "$(basename $0) [-u] [-t] list"
			  "$(basename $0) [--user] [--type] list"
			Searches for and displays all keys of the selected key type in the selected user's LDAP entry
			(see "$(basename $0) help -t" for information on key type selection)
			(see "$(basename $0) help -u" for information on user selection)
			EndOfDocument
			;;
		add) cat <<-EndOfDocument
			Usage:
			  "$(basename $0) [-u] [-t] [-f] add"
			  "$(basename $0) [--user] [--type] [--file] add"
			Adds one new key to the specified user's entry, with the selected type. Prompts interactively if no file is specified, otherwise tries to use the contents of the specified file as a key. 
			Format checking is performed on the key to ensure that it is valid.
			(see "$(basename $0) help -t" for information on key type selection)
			(see "$(basename $0) help -u" for information on user selection)
			(see "$(basename $0) help -f" for information on file selection)
			EndOfDocument
			;;
		add-all) cat <<-EndOfDocument
			Usage:
			  "$(basename $0) [-u] [-t] [-f] -A"
			  "$(basename $0) [--user] [--type] [--file] add-all"
			Attempts to add each line in the selected file as a separate key, with the selected key type  If no file is specified on the command line, defaults to ~/.ssh/authorized_keys
			Format checking is performed on each line to ensure that it is a valid key. If no valid keys are found, an error is printed and no modifications are made to the ldap server.
			(see "$(basename $0) help -t" for information on key type selection)
			(see "$(basename $0) help -u" for information on user selection)
			(see "$(basename $0) help -f" for information on file selection)
			EndOfDocument
			;;
		delete) cat <<-EndOfDocument
			Usage:
			  "$(basename $0) [-u] [-t] [-f] -d"
			  "$(basename $0) [--user] [--type] [--file] delete"
			(see "$(basename $0) help -t" for information on key type selection)
			(see "$(basename $0) help -u" for information on user selection)
			(see "$(basename $0) help -f" for information on file selection)
			EndOfDocument
			;;
		delete-all) cat <<-EndOfDocument
			Usage:
			  "$(basename $0) [-u] [-t] [-f] -D"
			  "$(basename $0) [--user] [--type] [--file] delete-all"
			(see "$(basename $0) help -t" for information on key type selection)
			(see "$(basename $0) help -u" for information on user selection)
			(see "$(basename $0) help -f" for information on file selection)
			EndOfDocument
			;;
		-u | --user) cat <<-EndOfDocument
			Usage:
			  "$(basename $0) -u <username> <-l|-a|-A|-d|-D>"
			  "$(basename $0) --user <username> <--list|--add|--addall|--delete|--deleteall>"
			Specify the username used when communicating with the ldap server. Defaults to your account name ( $USER ). Must be an MCECS LDAP user.
			The specified username will be used for both authentication, and as the target username to search or alter.
			EndOfDocument
			;;
		-t | --key-type) cat <<-EndOfDocument
			Usage:
			  "$(basename $0) -t <key type> <-l|-a|-A|-d|-D>"
			  "$(basename $0) --key-type <key type> <--list|--add|--addall|--delete|--deleteall>"
			Specify the key class to search, add, or modify to your LDAP entry. Default: sshPublicKey
			Valid key classes:
			< default >   : key for general cat bastions (reaver, serenity, destiny)
			DroogMinusOne : key for droog-1 root bastion (kaylee)
			Droog         : key for droog root bastion (miranda)
			ClawMinusOne  : key for claw-1 root bastions (aiur, caerbannog)
			Claw          : key for claw root bastions (nightshade, twilight)
			There is also a sshPublicKeyIRC type, but it is unknown if this is used by anything.
			EndOfDocument
			;;
	esac
}

print_usage () {
	cat <<-EOF
	"This script will help you manage your ssh keys in LDAP. You must run it from a CAT box.
	  (i.e. scissors, ada, chandra, adelie)

	Usage:
	  $(basename $0) [-t <key type>] [-f <file>] [-u user] <list|add|add-all|delete|delete-all>

	Options:
	  list | -l | --list-user=<USERNAME>  : list keys
	  add  | -a <path to key>             : add a key interactively (or for path to file if specified)
	  add-all | -A <path to keys>         : add all keys in a file (default $HOME/.ssh/authorized_keys)
	  delete | -d                         : interactive delete
	  delete-all | -D                     : delete all keys from ldap
	  -u | --user <username>              : modify a different user than yourself
	  -t | --key-type <key type>          : class of key to modify
	  -h |- -help | help                  : this help

	Note : Order of arguments is taken care of
			$(basename $0) -u rohane -l is same as $(basename $0) -l -u rohane
	EOF

	return
}


list () 
{
	if [ -z $USERNAME ] || [ -z $KEY_CLASS ]; then
		option_help list
		exit 10
	fi
	check=$(ldapsearch -xLLL -H $LDAP_URI -b uid=$USERNAME,ou=People,dc=cat,dc=pdx,dc=edu $KEY_CLASS | wc -l)

	if [ $check -le 2 ]; then
		>&2 echo No Keys Found
		return
	fi

	ldapsearch -xLLL -H $LDAP_URI -b uid=$USERNAME,ou=People,dc=cat,dc=pdx,dc=edu $KEY_CLASS | \
	awk '
		BEGIN {
			i=0;j=1; 
			printf "\n%d ", j;++j;
		}
		{ 
			gsub(/[\f\n\r\t]/, "", $0);
			gsub(/^ /,"",$0);
			if( $0 ~ /^'$KEY_CLASS'/ && i>1) {
				printf "\n\n%d ",j; 
				++j;
			}
			if( $0 !~ /^dn:/)
				printf $0; 
			i++; 
		} 
		END { 
			printf "\n" 
		}'
}

add () # also addall ??
{
	reply=""

	if [ -r $KEYS ]; then
		KEYS=$(cat $FILE )
	else
		echo -n "Paste the key here: "
		read KEYS
	fi

	echo "$KEYS" | \
	awk '
		{
			if ( $0 !~ /^\s*$/ && $0 != "" && $0 !~ /[\n\r]/ )
			{
				printf "dn: uid='$USER',ou=People,dc=cat,dc=pdx,dc=edu\n"
				printf "changetype: modify\n"
				printf "add: '$KEY_CLASS'\n"
				printf "'$KEY_CLASS': %s\n", $0
				printf "\n"
			}
			else
			{
				system(">&2 echo BAD KEY");
				system("rm -f '$TEMPFILE'");
				system("kill -9 '$PID'");
			}
		}
	' >> $TEMPFILE

		cat $TEMPFILE | less

	while [[ ($reply != 'Y') && ($reply != 'n') ]]; do
		echo -n "Add all the listed key/keys into ldap ? (Y/n) : "
		read reply
	done

	if [ $reply == 'Y' ]; then
		#ldapmodify -c -D uid=$USER,ou=People,$LDAP_BASE -W -ZZ -H $LDAP_URI -f $TEMPFILE
		echo "in the if"
	fi

return
}

deleteall () 
{

	reply=""
	while [[ ($reply != 'Y') && ($reply != 'n') ]]; do
		echo -n 'Delete all the keys in Ldap[Y/n]: '
		read reply
	done

	if [[ ($answer == 'Y') ]]; then
		echo "dn: uid=$USERNAME,ou=People,$LDAP_BASE" >> $TEMPFILE
		echo "changetype: modify" >> $TEMPFILE
		echo "delete: $KEY_CLASS" >> $TEMPFILE

		#ldapmodify -c -D uid=$USER,ou=People,$LDAP_BASE -W -ZZ -H $LDAP_URI -f $TEMPFILE
	fi
    return

}

delete ()
{
	reply=0
	list
	NO_OF_KEYS=$(list | sed '/^$/d' | wc -l)
	echo ""

	until [ $reply -ge 1 ] && [ $reply -le $NO_OF_KEYS ]; do
		echo -n "Index for the the key that is going to be deleted: "
		read reply
	done

	echo ""

	while [[ ($reply != 'Y') && ($reply != 'n') ]]; do
		echo -n "Are you sure you want to delete this key ? (Y/n) : "
		read reply
	done

	if [[ ($reply != 'Y') ]]; then
		exit 20
	fi

	list | \
	awk '
	BEGIN {
		printf "dn: uid='$USER',ou=People,dc=cat,dc=pdx,dc=edu\n"
		printf "changetype: modify\n"
		printf "delete: '$KEY_CLASS'\n"
	}
	{
		if($1 == '$reply')
		{
			gsub(/^[0-9]+ /,"",$0);
			print $0
		}
	}' >> $TEMPFILE

	#ldapmodify -c -D uid=$USER,ou=People,$LDAP_BASE -W -ZZ -H $LDAP_URI -f $TEMPFILE
}

key_type_check()
{
	if [ $KEY_CLASS != "sshPublicKeyDroogMinusOne" ] && [ $KEY_CLASS != "sshPublicKeyDroog" ] && [ $KEY_CLASS != "sshPublicKeyClawMinusOne" ] && [ $KEY_CLASS != "sshPublicKeyClaw" ] && [ $KEY_CLASS != "sshPublicKey" ] && [ $KEY_CLASS != "sshPublicKeyIRC" ]; then
		>&2 echo Invalid Key Type
		option_help -t
		return 100
	fi
	return 0

}

run()
{
    while [ ! -z "$1" ];
    do
		$1
		shift
    done
}

main ()
{

	Array=""

	if [ $# == 0 ]; then
		print_usage
	fi

	while [ $# -gt 0 ]; do
		case "$1" in
			-u) 
				USERNAME=${2}
				shift;;
			-t ) 
				KEY_CLASS="$KEY_CLASS${2}"
				shift
				key_type_check
				if [ $? -eq 100 ]; then
					rm $TEMPFILE
					exit 10
				fi
				;;
			-l | list | --list | --list-user=*) 
				if [[ $1 =~ '^--list-user=' ]]; then
					USERNAME=${1#*=}
				fi
				Array="$ARRAY list"
				;;
			-A | addall) 
				FILE='/u/'$USER'/.ssh/authorized_keys'
				Array="$ARRAY add"
				;;
			-a | add | --add) 
				FILE=${2}
				Array="$ARRAY add"
				shift
				;;
			-d |delete |--delete) 
				Array="$ARRAY delete"
				;;
			-D | deleteall) 
				Array="$ARRAY deleteall"
				;;
			-h | help | --help) 
				if [ ! -z "$2" ]; then
					option_help "$2"
					shift
				else
					print_usage
				fi
				;;
	esac
	shift
	done

	run $Array
}

main $@
rm $TEMPFILE
exit 0
