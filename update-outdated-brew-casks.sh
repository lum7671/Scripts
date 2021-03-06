# Upgrade / Update outdated casks installed. 
# --------------------------------------------------------------------------------
# Looks for outdated casks and installs the the latest version.
# User data (like application preferences) is intact.
# --------------------------------------------------------------------------------
	brew cask reinstall `brew cask outdated`


# List installed outdated casks
# More info: https://github.com/caskroom/homebrew-cask/issues/29301
# --------------------------------------------------------------------------------

# List installed brew casks using the versions flag
	brew cask list --versions

# List outdated brew casks using the greedy flag (i use this one)
	brew cask outdated --greedy

# List outdated brew casks using the greedy flag and pipe to show only latest versions
	brew cask outdated --greedy | grep -v '(latest)'

# List outdated brew casks
	brew cask outdated

# List outdated brew casks using the verbose flag
	brew cask outdated --verbose

