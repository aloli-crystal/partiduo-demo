# SPDX-License-Identifier: AGPL-3.0-or-later

module PartiduoDemo
  # Dossier « liberal » : Camille Rivière, masseur-kinésithérapeute
  # (profession libérale fictive) à Blois, bénéfices non commerciaux
  # (déclaration 2035), non assujettie à la TVA. Livre-journal des recettes
  # et dépenses ventilées par rubrique (part privée du véhicule),
  # immobilisations amorties, 2035 de l'exercice complet transmise au
  # TELEDEC simulé, écritures générées en Comptabilité.
  class LiberalDossier < Dossier
    def code : String
      "liberal"
    end

    def settings : Core::SettingsInput
      Core::SettingsInput.new(company_name: "Camille Rivière, masseur-kinésithérapeute", legal_form: "EI",
        siren: "903 728 160", street: "avenue de la Loire", street_number: "18", postcode: "41000", city: "Blois",
        country_code: "FR", phone: "02 54 00 00 00", email: "cabinet@riviere-kine.test", tax_regime: "fr",
        default_locale: "fr", domain: host)
    end

    def modules : Array(String)
      %w[liberal accounting]
    end

    def extensions : Array(String)
      %w[teledec document]
    end

    def people : Array(Person)
      [Person.new("camille@liberal.demo.test", "Camille", "Rivière")]
    end

    def tour : Array(String)
      [
        "Tableau de bord simplifié de la profession libérale",
        "Recettes et dépenses ventilées par rubrique de la 2035 (part privée du véhicule), livre-journal",
        "Immobilisations et amortissements (table de massage, ordinateur), 2035-A et 2035-B, édition PDF",
        "TELEDEC simulé (/ext/TELEDEC/) : liasse BNC de l'exercice précédent transmise et accusée",
        "Paramètres de la profession libérale : interface du dossier, « Recettes et dépenses » ou « Comptabilité », pour tous ses utilisateurs",
      ]
    end

    def load : Nil
      if Api::Liberal.natures(system).empty?
        Api::Liberal.load_defaults(system)
      end
      ok(Api::Liberal.update_settings(actor, Api::Liberal::SettingsInput.new(profession: "Masseur-kinésithérapeute",
        activity_started_on: Time.utc(2019, 9, 1), default_nature_id: nature("receipts"))), "paramètres de la profession libérale")
      [year - 1, year].each do |current|
        fiscal_year(current)
        (1..12).each { |month| month_events(current, month) }
      end
      assets
      say "Recettes, dépenses et immobilisations jusqu'au #{real_today.to_s("%d/%m/%Y")}"
      say "#{agenda.run} opérations datées exécutées"
      teledec
    end

    private def nature(heading : String) : Int64
      (Api::Liberal.natures(system).find { |item| item.heading == heading && item.enabled } ||
        raise LoadError.new("rubrique #{heading} absente")).id
    end

    private def receipt(amount : String, label : String, method : String = "transfer", party : String = "") : Nil
      ok(Api::Liberal.record_receipt(actor, Api::Liberal::LineInput.new(date: today, nature_id: nature("receipts"),
        amount: d(amount), method: method, party_name: party, label: label)), "recette #{label}")
    end

    private def expense(heading : String, amount : String, label : String, party : String = "", private_part : String = "0",
                        method : String = "transfer") : Nil
      ok(Api::Liberal.record_expense(actor, Api::Liberal::LineInput.new(date: today, nature_id: nature(heading),
        amount: d(amount), method: method, party_name: party, label: label, nondeductible_amount: d(private_part))),
        "dépense #{label}")
    end

    private def month_events(current : Int32, month : Int32) : Nil
      index = (current - (year - 1)) * 12 + month - 1
      at = ->(day : Int32) { date(current, month, day) }
      busy = month == 8 ? 0.5 : 1.0
      {7, 14, 21, 28}.each_with_index do |day, week|
        agenda.at(at.call(day)) do
          amount = (1180 + (index * 37 + week * 53) % 260) * busy
          receipt(amount.round(2).to_s, "Honoraires de la semaine (tiers payant et patients)")
        end
      end
      agenda.at(at.call(10)) { receipt((240 + index % 4 * 30).to_s, "Séances à domicile", "cheque") }
      agenda.at(at.call(2)) { expense("rent", "680", "Loyer du cabinet", "SCI du Mail") }
      agenda.at(at.call(12)) do
        expense("vehicle", (110 + index % 5 * 9).to_s, "Carburant et entretien du véhicule", "Garage du Mail", "33", "card")
      end
      agenda.at(at.call(15)) { expense("utilities", "58.40", "Électricité du cabinet", "Énergies Val de Loire") }
      agenda.at(at.call(18)) { expense("office", (32 + index % 3 * 11).to_s, "Téléphone, internet et petites fournitures", "Télécom Blésois") }
      agenda.at(at.call(25)) { expense("purchases", (45 + index % 4 * 12).to_s, "Huiles de massage et consommables", "Kiné Fournitures") }
      agenda.at(at.call(28)) { expense("withdrawal", "2400", "Prélèvement personnel") }
      if month.in?(2, 5, 8, 11)
        agenda.at(at.call(5)) { expense("personal_social_mandatory", "1840", "Cotisations URSSAF et caisse de retraite", "Urssaf") }
      end
      agenda.at(at.call(9)) { expense("insurance", "436", "Responsabilité civile professionnelle", "Mutuelle des soignants") } if month == 1
      agenda.at(at.call(9)) { expense("professional_dues", "320", "Cotisation ordinale") } if month == 3
      agenda.at(at.call(20)) { expense("fees", "390", "Adhésion à l'association de gestion agréée", "AGA du Loir-et-Cher") } if month == 4
    end

    private def assets : Nil
      agenda.at(date(year - 1, 4, 1)) do
        ok(Api::Liberal.record_asset(actor, Api::Liberal::AssetInput.new(label: "Table de massage électrique", category: "equipment",
          acquired_on: today, amount: d("3000"), duration_years: 3, method: "transfer", party_name: "Kiné Équipement")),
          "table de massage")
      end
      agenda.at(date(year, 2, 10)) do
        ok(Api::Liberal.record_asset(actor, Api::Liberal::AssetInput.new(label: "Ordinateur portable", category: "office",
          acquired_on: today, amount: d("1140"), duration_years: 3, method: "card", party_name: "Informatique Blésoise")),
          "ordinateur")
      end
    end

    # 2035 de l'exercice complet, transmise au TELEDEC simulé.
    private def teledec : Nil
      previous = fiscal_year(year - 1)
      ok(Teledec::Api.update_settings(actor, Teledec::Api::SettingsInput.new("bnc", "none")), "paramètres TELEDEC")
      ok(Teledec::Api.save_credentials(actor, Teledec::Api::CredentialsInput.new(Teledec::SimulatedTeledec::LOGIN,
        Teledec::SimulatedTeledec::API_KEY, "sandbox", "cabinet@riviere-kine.test", "90372816000016")),
        "identifiants TELEDEC simulés")
      filing = ok(Teledec::Api.prepare(actor, Teledec::Api::PrepareInput.new("liasse", fiscal_year_id: previous.id)), "liasse BNC")
      ok(Teledec::Api.check(actor, filing.id), "contrôle de la liasse")
      ok(Teledec::Api.transmit(actor, filing.id), "transmission au TELEDEC simulé")
      ok(Teledec::Api.refresh(actor, filing.id), "accusé de la liasse")
    end
  end
end
