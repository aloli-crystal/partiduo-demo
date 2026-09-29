# SPDX-License-Identifier: AGPL-3.0-or-later

# Ligne de commande Marten de la distribution de démonstration :
# `crystal run manage.cr -- <commande>` (`migrate`, `provision`…), ou
# `bin/partiduo-demo-manage` après `shards build`.
require "./src/partiduo-demo"
require "./config/settings/base"
require "./config/settings/**"
require "./src/cli"

Marten.setup
Marten::CLI.run
