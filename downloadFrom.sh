#!/bin/bash
# Description: Downloads various file types from a given URL

##	httpParsing analyzes $URL and returns a newline seperated list of links that match
##	the type of file specified 
function httpParsing() {
	URL="$1"
	TYPE="$2"

	function getResponse() {
		# Set the HTTP response to a variable
		declare -i respcode
		respcode=$(curl -s -o /dev/null -w "%{http_code}" $URL)
		if ((respcode>=200)) && ((respcode<300)); then # If the response code is 200-299 
			RESPONSE=$(curl -s "$URL") 
		else 
			echo "ERR: Server returned a $respcode"
		fi
	}
	function parseResponseForImg() {
		# Returns links to IMG files on URL
		LINKS=$(echo -e "$RESPONSE" | pup -p 'img json{}' | jq -r ".[].src")
	}
	function parseResponseForHrefs() {
		# Returns links on URL
		LINKS=$(echo -e "$RESPONSE" | pup -p 'a json{}' | jq -r '.[].href')
	}
	function parseResponseForExt() {
		# Returns links that match a specific file extension
		LINKS=$(echo -e "$RESPONSE" | pup -p "a,img json{}" | jq -r '.[] | .href // .src' | grep -i "$TYPE$")
	}
	function escapeUrl() {
		# expects url and returns escaped url. Useful when you need to use $URL in sed
		echo "$1" | sed 's/\//\\\//g' 
				# s/ \/ / \\\/ /g
				# s/ escaped / replace escaped \ escaped / 
	}
	function cleanLinks() {
		# Cleans up links and formats them properly
		escaped_url=$(escapeUrl "$URL")
		protocol=$(echo "$URL" | grep -ioP "htt(ps|p)")
		protocol_relative_links=$(echo -e "$LINKS" | grep -iE "^//([a-z]|[0-9])") # //link.com
		rebuilt_protocol_relative_links=$(echo -e "$protocol_relative_links" | sed "s/^\/\//$protocol:\/\//g" ) # replace // with $protocl://
		already_built_links=$(echo -e "$LINKS" | grep -iE "htt(p|ps)://") # https://stuff.com
		links_that_build_on_domain=$(echo -e "$LINKS" | grep -iE "^/([a-z]|[0-9])") # /stuff/things.html
		if [ "$links_that_build_on_domain" ]; then 
			rebuilt_links_that_build_on_domain=$(echo -e "$links_that_build_on_domain" | sed "s/^/$escaped_url/g")
		fi
		linklist=$(echo -e "$rebuilt_links_that_build_on_domain\n$rebuilt_protocol_relative_links\n$already_built_links")
		linklist=$(echo -e "$linklist" | awk '!a[$0]++' | grep -v "^$" ) # Removes duplicates from the list and emptylines 
		LINKS="$linklist"
	}
	function parse() {
		case "$TYPE" in # using shell expansion to dynamically set the command we'll execute based on our TYPE
			img|IMG) parseType=${parseType=parseResponseForImg} ;; 
			href|HREF) parseType=${parseType=parseResponseForHrefs} ;; 
			.*) parseType=${parseType=parseResponseForExt} ;; # .ext 
			*) echo "ERR: No valid type found" && exit 1 ;;
		esac 
		getResponse && $parseType && cleanLinks # Puts $RESPONSE in our env, parses based on our $TYPE, then cleans up and sets the LINKS env variable

	}
}

## downloadFiles downloads a list files using multithreading
function downloadFiles() {
	function getLinkList() {
		# outputs the link list
		if [ "$LINKS" ]; then 
			echo -e "$LINKS" # If we have our ENV variable then use that
		elif [ "$1" ]; then 
			echo -e "$1" # otherwise use the first argument
		else
			while read -t0.5 pipe; do
				out="$pipe" # otherwise try to use stdin 
			done
			if [ "$out" ]; then 
				echo -e "$out"
			else
				echo "No valid files found." # if no link list found display an error
			fi
		fi 
	}
	function getThreads() {
		# outputs the THREADS env variable or outputs the default (1)
		if [ "$THREADS" ]; then 
			echo "$THREADS" 
		else
			echo "1"
		fi
	}
	function getOutDirectory() {
		# outputs the OUTDIR env variable or outputs the default (current dir)
		if [ "$OUTDIR" ]; then
			echo "$OUTDIR"
		else
			echo "."
		fi
	}
	function getUrl() {
		# Makes the GET request and logs the request
		echo "GET $1" >> .downloadFrom.log
		wget -q --directory-prefix=$(getOutDirectory) "$1" 2> .downloadFrom.log.err 
	}
	function exportEnv() {
		export -f getUrl
		export -f getThreads
		export -f getOutDirectory
		export OUTDIR
	}
	function downloadStart() {
		exportEnv # since we call a function in parallel we need to export part of the env
		if [ -z "$QUIET" ]; then bar="--bar"; fi # If no QUIET env variable then display a progress bar
		getLinkList | parallel $bar -j$(getThreads) getUrl {}  # gets our linklist then creates the wget jobs based on our threads, tells wget to output to the OUTDIR, and puts any errors in the logfile.
	}
}

function downloadFrom() {
	function helpThem() {
cat <<help
$0 [options]
-u, --url  		the URL source
-t --type 		the type of files to download
					Options: 
						img - image files
						href - pages that are linked
						.ext - search for specific file extension
-j, --threads 	sets the number of threads to use 
-o, --out 		the directory which files will be downloaded to
-s, --silent  	makes the script run with no output

Examples:
$0 -j 4 -o ~/Pictures -t img -u http://imgur.com
$0 --silent --threads 4 --out ~/Pictures --type .jpg --url http://imgur.com


help
exit 1
	}
	function argParse() {
		if [ -z "$1" ]; then helpThem; fi
		while [[ $# -gt 1 ]]; do
			key="$1"
			case $key in
				-u|--url)
					URL="$2"
					shift # past argument
				;;
				-t|--type)
					TYPE="$2"
					shift # past argument
				;;
				-j|--threads)
					THREADS="$2"
					shift
				;;
				-o|--out)
					OUTDIR="$2"
					shift
				;;
				-s|--silent)
					QUIET="YES"
				;;
				*)
					helpThem
				# unknown option
				;;
			esac
			shift # past argument or value
		done			
	}

	function appStart() {
		argParse "$@" # parse the arguments and set vars
		httpParsing "$URL" "$TYPE" && parse  # Puts the httpParsing functions in our env, sets the httpParsing variables, and then parses the output
		downloadFiles && downloadStart # Puts the downloadFiles
	}
}

downloadFrom && appStart "$@"