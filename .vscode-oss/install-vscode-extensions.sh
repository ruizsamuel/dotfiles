#!/bin/bash

# Visual Studio Code :: Package list
pkglist=(
formulahendry.terminal
ms-python.python
)

for i in ${pkglist[@]}; do
  code --install-extension $i
done
