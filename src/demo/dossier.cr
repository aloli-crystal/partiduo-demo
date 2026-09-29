# SPDX-License-Identifier: AGPL-3.0-or-later

module PartiduoDemo
  # Utilisateur d'un dossier de démonstration : adresse, identité, profil
  # (`ADMIN` ou `ACCOUNTANT`) et rôle (`member` ou `accountant`).
  record Person, email : String, first_name : String, last_name : String, profile : String = "ADMIN",
    role : String = "member"

  # Dossier fictif : société, modules et extensions, utilisateurs, puis
  # chargement des données par le contrat `Partiduo::Api` et celui des
  # extensions (jamais par SQL). Chaque dossier a sa base et son hôte
  # `<code>.partiduo.localhost`.
  abstract class Dossier
    include Support

    # Mots de passe des utilisateurs, par adresse (fournis par
    # `scripts/demo`, jamais écrits dans le code).
    getter passwords : Hash(String, String)

    def initialize(@passwords : Hash(String, String))
    end

    abstract def code : String
    abstract def settings : Core::SettingsInput
    # Modules du cœur (`accounting`, `invoicing`, `micro`…).
    abstract def modules : Array(String)
    # Extensions activées dès la création.
    abstract def extensions : Array(String)
    abstract def people : Array(Person)
    # Données du dossier (référentiel, opérations, extensions).
    abstract def load : Nil
    # Ce qu'on peut essayer dans le dossier (affiché au démarrage).
    abstract def tour : Array(String)

    # Valeur de `PARTIDUO_MODULES` pour ce dossier.
    def active_codes : String
      (modules + extensions).join(",")
    end

    def host(domain : String = "partiduo.localhost") : String
      "#{code}.#{domain}"
    end

    def siren : String
      settings.siren.to_s.delete(' ')
    end

    # Crée la société et le jeu de données initial (plan comptable, taux,
    # journaux, catégories, profils), les utilisateurs, puis charge les
    # données.
    def provision_and_load : Nil
      say "Société « #{settings.company_name} » (#{active_codes})"
      input = Core::ProvisionInput.new(settings: settings, modules: modules, extensions: extensions)
      ok(Core.provision(system, input), "provisionnement")
      extensions.each { |extension| ok(Api::Modules.activate(system, extension.upcase), "activation de #{extension}") }
      profiles = Auth.ensure_default_profiles(system)
      people.each do |person|
        profile = profiles.find! { |item| item.code == person.profile }
        password = passwords[person.email]? || raise LoadError.new("mot de passe absent pour #{person.email}")
        created = ok(Auth.create_user(system, Auth::UserInput.new(email: person.email, first_name: person.first_name,
          last_name: person.last_name, role: person.role, profile_id: profile.id, password: password)),
          "utilisateur #{person.email}")
        # Invitation à créer une clé d'accès déjà vue : la démonstration
        # ouvre directement le tableau de bord.
        Auth.dismiss_passkey_prompt(Api::Actor.user(created.user.id, [] of String, level: 1))
      end
      load
    end

    # Acteur du premier utilisateur (gérant) avec toutes les permissions
    # déclarées : les opérations lui sont attribuées.
    def actor : Api::Actor
      @actor ||= begin
        user = Auth.user_by_email(system, people.first.email) || raise LoadError.new("utilisateur absent")
        permissions = Api::Modules.permissions(system).map(&.name)
        Api::Actor.user(user.id, permissions, level: 3)
      end
    end

    @actor : Api::Actor? = nil
    @agenda : Agenda? = nil
    @real_today : Time? = nil

    # Jour réel du chargement, lu avant tout déplacement de l'horloge.
    def real_today : Time
      @real_today ||= today
    end

    # Année en cours ; l'exercice complet est l'année précédente.
    def year : Int32
      real_today.year
    end

    # Opérations datées du dossier, exécutées jusqu'au jour réel.
    def agenda : Agenda
      @agenda ||= Agenda.new(real_today)
    end

    # --- Référentiel -------------------------------------------------------------

    def category(code : String) : Int64
      (Cards.category_by_code(system, code) || raise LoadError.new("catégorie #{code} absente")).id
    end

    def rate(code : String) : Int64
      (Vat.rate_by_code(system, code) || raise LoadError.new("taux de TVA #{code} absent")).id
    end

    def card(code : String) : Cards::CardView
      Cards.card_by_code(system, code) || raise LoadError.new("fiche #{code} absente")
    end

    def address(line1 : String, postcode : String, city : String) : Cards::AddressInput
      Cards::AddressInput.new(line1: line1, postcode: postcode, city: city, country_code: "FR")
    end

    # Compte du plan (créé sous `parent` s'il n'existe pas).
    def account(number : String, label : String, parent : String) : Nil
      Acc.account(system, number)
    rescue Api::NotFound
      ok(Acc.create_account(system, Acc::AccountInput.new(number: number, label: label, parent: parent)), "compte #{number}")
    end

    def fiscal_year(year : Int32) : Core::FiscalYearView
      Core.fiscal_years(system).find(&.year.==(year)) ||
        ok(Core.create_fiscal_year(system, Core::FiscalYearInput.new(year: year, start_year: year)), "exercice #{year}")
    end
  end
end

module PartiduoDemo
  # Agenda d'un chargement : chaque opération est datée ; elles s'exécutent
  # dans l'ordre chronologique, l'horloge du dossier placée à leur jour, et
  # peuvent en programmer d'autres (le règlement d'une facture à son
  # échéance). Une opération postérieure au jour réel n'a pas encore eu lieu :
  # elle n'est pas exécutée.
  class Agenda
    include Support

    record Event, day : Time, sequence : Int32, action : Proc(Nil)

    getter last_day : Time
    @events = [] of Event
    @sequence = 0

    def initialize(@last_day : Time)
    end

    def at(day : Time, &action : -> Nil) : Nil
      @sequence += 1
      @events << Event.new(day, @sequence, action)
    end

    def run : Int32
      count = 0
      until @events.empty?
        index = (0...@events.size).min_by { |position| {@events[position].day, @events[position].sequence} }
        event = @events.delete_at(index)
        next if event.day > @last_day
        on(event.day) { event.action.call }
        count += 1
      end
      count
    end
  end
end
