#!/usr/bin/env zsh -l


REQUIREMENTS_TXT=/tmp/my001_requirements.txt
PYTHON_BIN=$HOME/.virtualenvs/myenv/bin/python3
PIP_BIN=$HOME/.virtualenvs/myenv/bin/pip3
export VIRTUALENVWRAPPER_PYTHON=$PYTHON_BIN
source $HOME/.virtualenvs/myenv/bin/virtualenvwrapper.sh # 각종 PATH 등을 설정해줌.
workon myenv

$PIP_BIN freeze --local > $REQUIREMENTS_TXT
deactivate
rmvirtualenv myenv

mkvirtualenv -p /usr/local/bin/python3 myenv
$PIP_BIN install virtualenvwrapper
workon myenv
$PIP_BIN install -r $REQUIREMENTS_TXT
$PIP_BIN install pipupgrade
pipupgrade -s
pipupgrade -lyui
