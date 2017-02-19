## downloadFrom.sh    
Parses a HTML page for a specified file type and downloads those files

## Usage
```
./downloadFrom.sh [options]
-u, --url  		the URL source
-t --type 		the type of files to download
					Options: 
						img - image files
						href - pages that are linked
-j, --threads 	sets the number of threads to use 
-o, --out 		the directory which files will be downloaded to
-s, --silent  	makes the script run with no output

Examples:
./downloadFrom.sh -j 4 -o ~/Pictures -t img -u http://i.imgur.com
./downloadFrom.sh --silent --threads 4 --out ~/Pictures --type href --url http://i.imgur.com
```
