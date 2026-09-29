# SPDX-License-Identifier: AGPL-3.0-or-later

module PartiduoDemo
  # Dossiers disponibles, par code (sous-domaine).
  DOSSIERS = %w[atelier micro liberal]

  def self.dossier(code : String, passwords : Hash(String, String)) : Dossier
    case code
    when "atelier" then Atelier.new(passwords)
    when "micro"   then MicroDossier.new(passwords)
    when "liberal" then LiberalDossier.new(passwords)
    else                abort "Dossier inconnu : « #{code} » (#{DOSSIERS.join(", ")})."
    end
  end

  # Mots de passe des utilisateurs passés par `scripts/demo` :
  # `DEMO_PASSWORDS='adresse=mot de passe,adresse=mot de passe'`.
  def self.passwords_from_env : Hash(String, String)
    ENV["DEMO_PASSWORDS"]?.to_s.split(',').each_with_object({} of String => String) do |pair, passwords|
      email, separator, password = pair.partition('=')
      passwords[email.strip] = password unless separator.empty?
    end
  end

  # Prépare la base d'un dossier : schéma vidé si demandé, migrations, puis
  # chargement si la base est vierge.
  module Loader
    extend self

    # Vrai si le dossier vient d'être chargé, faux s'il était déjà là.
    def prepare(dossier : Dossier, reset : Bool) : Bool
      connection = Marten::DB::Connection.default
      name = Marten.settings.databases.first.name.to_s
      raise LoadError.new("base « #{name} » refusée : son nom doit contenir « demo »") unless name.includes?("demo")
      marker = marker_path(name)
      if reset
        puts "== #{dossier.code} : base #{name} vidée"
        connection.open do |db|
          db.exec("DROP SCHEMA public CASCADE")
          db.exec("CREATE SCHEMA public")
        end
        File.delete?(marker)
      end
      Marten::DB::Management::Migrations::Runner.new(connection).execute
      Partiduo::Modules::State.reset_table_cache
      if Partiduo::Api::Core.provisioned?(Partiduo::Api::Actor.system)
        unless File.exists?(marker)
          raise LoadError.new("le chargement précédent de #{name} n'est pas allé au bout : relancez avec --reset")
        end
        return false
      end
      started = Time.instant
      puts "== #{dossier.code} : chargement du dossier fictif dans #{name}"
      dossier.provision_and_load
      Dir.mkdir_p(File.dirname(marker))
      File.write(marker, "#{Time.utc.to_rfc3339}\n")
      puts "== #{dossier.code} : dossier chargé en #{(Time.instant - started).total_seconds.round(1)} s"
      true
    end

    # Témoin d'un chargement complet (hors de la base : un chargement
    # interrompu ne le laisse pas).
    def marker_path(database : String) : String
      File.join(ENV["DEMO_STATE_DIR"]? || File.join(Dir.current, "tmp", "demo"), "#{database}.loaded")
    end
  end
end
