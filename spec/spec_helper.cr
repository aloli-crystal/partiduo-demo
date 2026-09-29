# SPDX-License-Identifier: AGPL-3.0-or-later

ENV["MARTEN_ENV"] = "test"
# Base des specs : son nom contient « test » (specs du cœur) et « demo »
# (seules les bases de démonstration sont chargées).
ENV["DATABASE_URL"] ||= "postgres:///partiduo_test_demo?host=/tmp"
ENV["PARTIDUO_MEDIA_ROOT"] ||= File.join(Dir.tempdir, "partiduo-demo-spec-media-#{Process.pid}")
ENV.delete("PARTIDUO_CHORUSPRO_TRANSPORT")
ENV.delete("PARTIDUO_SMTP_URL")

require "spec"
require "../src/partiduo-demo"
require "../config/settings/base"
require "../config/settings/**"
require "../src/cli"
require "../src/demo"

# Dossier « atelier » chargé une fois pour toutes les specs, au jour réel
# (les télédéclarations simulées exigent un horodatage du jour) :
# l'exercice complet est l'année précédente, dont les montants ne dépendent
# que du scénario.
module DemoSpec
  @@atelier : PartiduoDemo::Atelier? = nil

  def self.atelier : PartiduoDemo::Atelier
    @@atelier ||= load_atelier
  end

  private def self.load_atelier : PartiduoDemo::Atelier
    passwords = %w[gerante@atelier.demo.test comptable@atelier.demo.test commercial@atelier.demo.test].to_h do |email|
      {email, "Spec-#{Random::Secure.hex(6)}-Az9"}
    end
    dossier = PartiduoDemo::Atelier.new(passwords)
    ENV["PARTIDUO_MODULES"] = dossier.active_codes
    ENV["DEMO_STATE_DIR"] = File.join(Dir.tempdir, "partiduo-demo-spec-state-#{Process.pid}")
    Marten.configure(&.log_level=(::Log::Severity::Warn))
    Marten.setup
    PartiduoDemo::Simulators.install(dossier.siren)
    PartiduoDemo::Loader.prepare(dossier, true)
    dossier
  end
end
