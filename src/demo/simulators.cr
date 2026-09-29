# SPDX-License-Identifier: AGPL-3.0-or-later

# Services externes simulés (doubles des specs de chaque extension, dans ce
# processus) : aucun appel réseau ne part d'une instance de démonstration.
#
# * plateforme agréée XP Z12-013 simulée d'EINV, qui accuse d'elle-même
#   chaque flux déposé ;
# * TELEDEC simulé, qui accuse réception à la première relève ;
# * Chorus Pro simulé, avec la structure publique fictive du dossier ;
# * URSSAF simulée (micro-entrepreneur) ;
# * courriel : messages gardés en mémoire, jamais envoyés.
require "../../lib/partiduo-einvoicing/spec/support/platform"
require "../../lib/partiduo-teledec/spec/support/simulated_teledec"
require "../../lib/partiduo-choruspro/spec/support/simulated_chorus_pro"
require "../../lib/partiduo-urssaf/spec/support/simulated_urssaf"

module PartiduoDemo
  module Simulators
    # Adresses de la plateforme simulée (hôte réservé `pa.test`, jamais
    # résolu : le transport simulé répond à la place du réseau).
    PLATFORM_VALUES = {
      "flow_url"        => "https://pa.test/afnor-flow",
      "directory_url"   => "https://pa.test/afnor-directory",
      "token_url"       => "https://pa.test/oauth2/token",
      "client_id"       => Einvoicing::SpecSupport::SimulatedPlatform::CLIENT_ID,
      "client_secret"   => Einvoicing::SpecSupport::SimulatedPlatform::CLIENT_SECRET,
      "organization_id" => "",
      "environment"     => "sandbox",
    }

    # Structure publique fictive du dossier (SIRET à clé de Luhn valide) :
    # ni engagement ni service exigés.
    PUBLIC_SIRET = "21370999100011"
    PUBLIC_NAME  = "Commune de Val-de-Brenne"

    # Plateforme XP Z12-013 simulée qui contrôle d'elle-même chaque flux
    # déposé : accusé `Ok` (« Déposée ») à la lecture suivante des flux.
    class AutoAckPlatform < Einvoicing::SpecSupport::SimulatedPlatform
      def exec(request : Request) : Response
        if request.url.includes?("/flows/search")
          flows.each { |flow| acknowledge(flow, "Ok") if flow.direction == "Out" && flow.ack == "Pending" }
        end
        super
      end
    end

    # TELEDEC simulé qui accuse réception de chaque dépôt à la première
    # relève de son état, comme la DGFiP après quelques minutes.
    class AutoAckTeledec < Teledec::SimulatedTeledec
      def status(credentials : Teledec::Credentials, remote_id : String, reference : String = "") : Teledec::RemoteStatus
        deposit = deposits[remote_id]?
        acknowledge(remote_id) if deposit && deposit.report.nil?
        super
      end
    end

    class_getter platform = AutoAckPlatform.new
    class_getter mail = Partiduo::Invoicing::Mail::MemoryTransport.new

    # Branche les doubles ; à appeler avant tout chargement et avant de
    # servir l'instance. `siren` : celui du dossier (URSSAF simulée).
    def self.install(siren : String = "") : Nil
      @@platform.page_size = 50
      Einvoicing::Http.transport = @@platform
      Partiduo::Invoicing::Mail.transport = @@mail
      Teledec::Transports.current = AutoAckTeledec.new
      chorus = Choruspro::SimulatedChorusPro.new
      chorus.structures[PUBLIC_SIRET] = Choruspro::Structure.new(PUBLIC_SIRET, PUBLIC_NAME, false, false, [] of String)
      Choruspro::Transports.current = chorus
      Urssaf::Transports.current = Urssaf::SimulatedUrssaf.new(siren.presence || "732829320")
    end

    def self.chorus : Choruspro::SimulatedChorusPro
      Choruspro::Transports.current.as(Choruspro::SimulatedChorusPro)
    end
  end
end
