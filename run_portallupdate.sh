#!/usr/bin/env zsh

sudo port selfupdate
sudo port upgrade outdated
sudo port uninstall inactive
sudo port uninstall leaves
