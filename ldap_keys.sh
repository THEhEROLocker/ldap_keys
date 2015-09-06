#!/bin/bash

trap ctrl_c SIGHUP SIGINT SIGTERM

LDAP_BASE='dc=cat,dc=pdx,dc=edu'
LDAP_URI='ldap://openldap.cat.pdx.edu'
KEY_CLASS=sshPublicKey
USERNAME=$USER
FILE=""		#The file which holds the key / keys
PID=$$
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
			  "$0 [-u] [-t] list"
			  "$0 [--user] [--type] list"
			Searches for and displays all keys of the selected key type in the selected user's LDAP entry in ~/.ssh/authorized_keys format
			(see "$0 help -t" for information on key type selection)
			(see "$0 help -u" for information on user selection)
			EndOfDocument
			;;
		add) cat <<-EndOfDocument
			Usage:
			  "$0 [-u] [-t] [-f] add"
			  "$0 [--user] [--type] [--file] add"
			Adds one new key to the specified user's entry, with the selected type. Prompts interactively if no file is specified, otherwise tries to use the contents of the specified file as a key. 
			Format checking is performed on the key to ensure that it is valid.
			(see "$0 help -t" for information on key type selection)
			(see "$0 help -u" for information on user selection)
			(see "$0 help -f" for information on file selection)
			EndOfDocument
			;;
		add-all) cat <<-EndOfDocument
			Usage:
			  "$0 [-u] [-t] [-f] -A"
			  "$0 [--user] [--type] [--file] add-all"
			Attempts to add each line in the selected file as a separate key, with the selected key type  If no file is specified on the command line, defaults to ~/.ssh/authorized_keys
			Format checking is performed on each line to ensure that it is a valid key. If no valid keys are found, an error is printed and no modifications are made to the ldap server.
			(see "$0 help -t" for information on key type selection)
			(see "$0 help -u" for information on user selection)
			(see "$0 help -f" for information on file selection)
			EndOfDocument
			;;
		delete) cat <<-EndOfDocument
			Usage:
			  "$0 [-u] [-t] [-f] -d"
			  "$0 [--user] [--type] [--file] delete"
			(see "$0 help -t" for information on key type selection)
			(see "$0 help -u" for information on user selection)
			(see "$0 help -f" for information on file selection)
			EndOfDocument
			;;
		delete-all) cat <<-EndOfDocument
			Usage:
			  "$0 [-u] [-t] [-f] -D"
			  "$0 [--user] [--type] [--file] delete-all"
			(see "$0 help -t" for information on key type selection)
			(see "$0 help -u" for information on user selection)
			(see "$0 help -f" for information on file selection)
			EndOfDocument
			;;
		-f | --file) cat <<-EndOfDocument
			Usage:
			  "$0 -f <filename> <-l|-a|-A|-d|-D>"
			  "$0 --file <filename> <--list|--add|--addall|--delete|--deleteall>"
			EndOfDocument
			;;
		-u | --user) cat <<-EndOfDocument
			Usage:
			  "$0 -u <username> <-l|-a|-A|-d|-D>"
			  "$0 --user <username> <--list|--add|--addall|--delete|--deleteall>"
			Specify the username used when communicating with the ldap server. Defaults to your account name. Must be an NCECS LDAP user.
			The specified username will be used for both authentication, and as the target username to search or alter.
			EndOfDocument
			;;
		-t | --key-type) cat <<-EndOfDocument
			Usage:
			  "$0 -t <key type> <-l|-a|-A|-d|-D>"
			  "$0 --key-type <key type> <--list|--add|--addall|--delete|--deleteall>"
			Specify the key class to search, add, or modify to your LDAP entry. Default: sshPublicKey
			Valid key classes:
			(null string) : key for general cat bastions (reaver, serenity, destiny)
			DroogMinusOne : key for droog-1 root bastion (kaylee)
			Droog         : key for droog root bastion (miranda)
			ClawMinusOne  : key for claw-1 root bastions (aiur, caerbannog)
			Claw          : key for claw root bastions (nightshade, twilight)
			There is also a sshPublicKeyIRC type, but it is unknown if this is used by anything.
			Please observe string casing with your types, or LDAP may be unhappy
			EndOfDocument
			;;
		*) echo "No detailed help on $1"; help;
			;;
	esac
}

print_usage () {
	cat <<-EOF
	"This script will help you manage your ssh keys in LDAP. You must run it from a CAT box.
	  (i.e. scissors, chicken, voltron)

	Usage:
	  $(basename $0) [-t <key type>] [-f <file>] [-u user] <list|add|add-all|delete|delete-all>

	Options:
	  list                       : list keys
	  add                        : add a key interactively (or from first line of file if specified)
	  add-all                    : add all keys in a file (default $HOME/.ssh/authorized_keys)
	  delete                     : delete key by index
	  delete-all                 : delete all keys from ldap
	  [-u|--user <username>]     : modify a different user than yourself
	  [-t|--key-type <key type>] : class of key to modify
	  [-f|--file <filename>]     : add key from file
	  [-h|--helphelp|help]           : this help

	Note: options and commands are parsed sequentially. "ldapkeys -t sshPublicKeyDroog add" will behave different from "ldapkeys add -t Droog". The second example will add a key of type sshPublicKey rather than sshPublicKeyDroog
	EOF

	return
}


list () 
{
	if [ -z $USERNAME ] || [ -z $KEY_CLASS ]; then
		option_help list
		exit 10
	fi
	check=`ldapsearch -xLLL -H $LDAP_URI -b uid=$USERNAME,ou=People,dc=cat,dc=pdx,dc=edu $KEY_CLASS | wc -l`

	if [ $check -le 2 ]; then
		>&2 echo No Keys Found
		exit 0
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

	if [ -r $FILE ]; then
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

delete ()
{
	reply=0
	list
	NO_OF_KEYS=`list | sed '/^$/d' | wc -l`
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
    help
fi

while [ $# -gt 0 ]; do
    case "$1" in
		-u) 
			USERNAME=${2}
			shift
			shift;;
		-t | --key-class=*) 
			if [ $1 =~ '^--key-class=' ]; then
				KEY_CLASS=${1#*=}
			else
				KEY_CLASS=$2; 
				shift
			fi
			shift;;
		-l | list | --list | --list-user=*) 
			if [[ $1 =~ '^--list-user=' ]]; then
				USERNAME=${1#*=}
			fi
			Array="$ARRAY list"
			shift
			;;
		-A | addall) 
			Array="$ARRAY add";;
		-D | deleteall) 
			Array="$ARRAY deleteall"
			;;
		-f) 
			FILE="$2"; 
			shift; add;;
		-h | help | --help) 
			if [ "$2" ]; then
                option_help "$2"
				shift
            else
                help
            fi
            shift;;
    esac
done

run $Array

}

main $@
rm $TEMPFILE
exit 0
