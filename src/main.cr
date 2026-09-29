# SPDX-License-Identifier: AGPL-3.0-or-later

# Instance de démonstration d'un dossier fictif : charge le dossier dans sa
# base (vide ou réinitialisée) par le contrat `Partiduo::Api`, puis le sert
# en local, services externes simulés. Lancé par `scripts/demo`, un
# processus par dossier :
#
# ```
# DATABASE_URL='postgres:///partiduo_demo_atelier?host=/tmp' \
# DEMO_PASSWORDS='gerante@…=…,comptable@…=…' \
#   bin/partiduo-demo --dossier=atelier --port=8300 --stop-file=demo.stop
# ```
#
# La base doit avoir « demo » dans son nom. `--reset` vide son schéma et
# recharge le dossier ; sans `--reset`, un dossier déjà chargé est servi tel
# quel. Ctrl-C, ou la création du fichier `--stop-file`, arrête le serveur.
require "option_parser"

dossier_code = "atelier"
host = "127.0.0.1"
port = 8300
stop_file = ""
ready_file = ""
reset = false
load_only = false
OptionParser.parse do |parser|
  parser.banner = "Usage : partiduo-demo --dossier=atelier|micro|liberal [--port=8300] [--reset] [--load-only] [--stop-file=CHEMIN]"
  parser.on("--dossier=CODE", "dossier fictif : atelier, micro ou liberal") { |value| dossier_code = value }
  parser.on("--port=PORT", "port local du serveur") { |value| port = value.to_i }
  parser.on("--host=ADRESSE", "adresse d'écoute (défaut 127.0.0.1)") { |value| host = value }
  parser.on("--stop-file=CHEMIN", "fichier dont la création arrête le serveur") { |value| stop_file = value }
  parser.on("--ready-file=CHEMIN", "fichier écrit quand le serveur est prêt") { |value| ready_file = value }
  parser.on("--reset", "vide la base et recharge le dossier") { reset = true }
  parser.on("--load-only", "charge le dossier sans le servir") { load_only = true }
  parser.on("-h", "--help", "cette aide") do
    puts parser
    exit 0
  end
end

# Réglages lus au chargement des réglages de Marten, avant les `require`.
ENV["MARTEN_ENV"] ||= "development"
ENV.delete("PARTIDUO_CHORUSPRO_TRANSPORT")
ENV.delete("PARTIDUO_SMTP_URL")

require "./partiduo-demo"
require "../config/settings/base"
require "../config/settings/**"
require "./cli"
require "./demo"

dossier = PartiduoDemo.dossier(dossier_code, PartiduoDemo.passwords_from_env)
ENV["PARTIDUO_MODULES"] = dossier.active_codes
ENV["PARTIDUO_DOMAIN"] ||= "partiduo.localhost"

Marten.configure(&.log_level=(::Log::Severity::Warn))
Marten.setup
PartiduoDemo::Simulators.install(dossier.siren)

database = Marten.settings.databases.first.name.to_s
abort "Base refusée : « #{database} » ne contient pas « demo » (voir DATABASE_URL)." unless database.includes?("demo")

loaded = begin
  PartiduoDemo::Loader.prepare(dossier, reset)
rescue ex : PartiduoDemo::LoadError
  abort "== #{dossier.code} : chargement interrompu — #{ex.message}"
end
exit 0 if load_only

Marten.settings.host = host
Marten.settings.port = port
Marten::Server.setup
address = "http://#{dossier.host}:#{port}/"
puts "== #{dossier.settings.company_name} : #{address}#{loaded ? "" : " (dossier repris tel quel)"}"
dossier.tour.each { |line| puts "   · #{line}" }

File.write(ready_file, "#{address}\n") unless ready_file.empty?
unless stop_file.empty?
  spawn do
    until File.exists?(stop_file)
      sleep 1.second
    end
    puts "== Arrêt demandé (#{stop_file}) : #{dossier.code}."
    Marten::Server.stop
    exit 0
  end
end
Marten::Server.start
