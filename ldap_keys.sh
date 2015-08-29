#!/bin/bash

LDAP_BASE='dc=cat,dc=pdx,dc=edu'
LDAP_URI='ldap://openldap.cat.pdx.edu'
KEY_CLASS=sshPublicKey
USERNAME=$USER

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
	  [-h|--help|help]           : this help

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


main ()
{
	while getopts "la:A:d:D:f:u:t:-:h" ARG
	do
		case $ARG in
			h)	# Print the usage help message and exit
				print_usage
				exit 0
				;;
			-)	# Print the usage help message and exit
				case ${OPTARG} in
					help) 	
						print_usage
						exit 0
						;;
					list) 	
						list
						;;
					list-user=*) 	
						USERNAME=${OPTARG#*=}
						list
						;;
				esac
				;;
			l)	# lists the keys 
				list
				;;
			a)	#Adds a specified key to ldap
				echo "add one key"
				;;
			A)	# Print the usage help message and exit
				print_usage
				;;
			d)	# Print the usage help message and exit
				print_usage
				;;
			D)	# Print the usage help message and exit
				print_usage
				;;
			f)	# Print the usage help message and exit
				print_usage
				;;
			t)	
				print_usage
				;;
		esac
	done
	
}

main $@
exit 0
