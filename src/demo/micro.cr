# SPDX-License-Identifier: AGPL-3.0-or-later

module PartiduoDemo
  # Dossier « micro » : Cycles Perrot, micro-entrepreneur (entreprise
  # individuelle fictive) de réparation et de vente de vélos à Angers, en
  # franchise en base de TVA (art. 293 B du CGI), déclaration URSSAF
  # trimestrielle. Livre des recettes (factures encaissées, ventes au
  # comptoir), registre des achats, déclarations et télépaiements à
  # l'URSSAF simulée, justificatifs photographiés.
  class MicroDossier < Dossier
    def code : String
      "micro"
    end

    def settings : Core::SettingsInput
      Core::SettingsInput.new(company_name: "Cycles Perrot", legal_form: "EI", siren: "918 452 079",
        street: "rue des Rayons", street_number: "23", postcode: "49000", city: "Angers", country_code: "FR",
        phone: "02 41 00 00 00", email: "contact@cycles-perrot.test", tax_regime: "fr", default_locale: "fr", domain: host)
    end

    def modules : Array(String)
      %w[micro invoicing]
    end

    def extensions : Array(String)
      %w[urssaf document]
    end

    def people : Array(Person)
      [Person.new("nicolas@micro.demo.test", "Nicolas", "Perrot")]
    end

    def tour : Array(String)
      [
        "Tableau de bord simplifié de la micro-entreprise : recettes de l'année, seuils, prochaine déclaration",
        "Facture en quelques champs (mention « TVA non applicable, art. 293 B du CGI »), encaissement → recette au livre",
        "Livre des recettes, registre des achats, 2042-C-PRO, seuils de chiffre d'affaires",
        "URSSAF simulée (/ext/URSSAF/) : mandat, déclarations trimestrielles et télépaiements",
      ]
    end

    ITEMS = [
      {"REVISION", "Révision complète d'un vélo", "C62", "70", "SERVICE"},
      {"CREVAISON", "Réparation de crevaison", "C62", "20", "SERVICE"},
      {"MO", "Main-d'œuvre atelier (heure)", "HUR", "40", "SERVICE"},
      {"CHAMBRE", "Chambre à air", "C62", "10", "SALE"},
      {"PNEU", "Pneu route 700 × 28", "C62", "30", "SALE"},
      {"ANTIVOL", "Antivol en U", "C62", "40", "SALE"},
    ]

    CUSTOMERS = [
      {"CLI-DUPRE", "Laure Dupré", "individual", "", "laure.dupre@exemple.test", "4 rue Plantagenêt"},
      {"CLI-NGUYEN", "Minh Nguyen", "individual", "", "minh.nguyen@exemple.test", "18 boulevard Foch"},
      {"CLI-LEGRAND", "Bastien Legrand", "individual", "", "", "7 place du Ralliement"},
      {"CLI-LOCALOIRE", "Loire Vélo Location SARL", "business", "852630144", "atelier@loire-velo-location.test", "Quai Ligny"},
    ]

    @unpaid = [] of Time

    def load : Nil
      if Api::Micro.natures(system).empty?
        Api::Micro.load_defaults(system)
      end
      ok(Api::Micro.update_settings(actor, Api::Micro::SettingsInput.new(periodicity: "quarterly",
        activity_started_on: Time.utc(2021, 3, 1), default_nature_id: nature("SERVICE"))), "paramètres de la micro-entreprise")
      current = Inv.settings(system)
      ok(Inv.update_settings(system, current.to_input.copy_with(iban: "FR7630006000011234567890189", bic: "AGRIFRPP",
        sender_email: "contact@cycles-perrot.test", sender_name: "Cycles Perrot", payment_terms_days: 15)), "paramètres de la Facturation")
      franchise = rate("FRANC")
      ITEMS.each do |(item_code, name, unit, price, nature_code)|
        item = ok(Cards.create_card(system, Cards::CardInput.new(category_id: category("SALE"), name: name, code: item_code,
          unit_code: unit, sale_price: d(price), vat_rate_id: franchise)), "article #{item_code}")
        ok(Api::Micro.set_item_nature(actor, item.id, nature(nature_code)), "nature de #{item_code}")
      end
      CUSTOMERS.each do |(customer_code, name, nature_code, siren_number, email, street)|
        ok(Cards.create_card(system, Cards::CardInput.new(category_id: category("CUSTOMER"), name: name, code: customer_code,
          customer_nature: nature_code, siren: siren_number.presence, email: email.presence,
          address: address(street, "49000", "Angers"))), "client #{customer_code}")
      end
      ok(Cards.create_card(system, Cards::CardInput.new(category_id: category("SUPPLIER"), name: "Distribution Cycles Ouest SAS",
        code: "FOU-DCO", siren: "895317428", email: "commandes@dco.test", address: address("ZI du Bois de Bouchet", "44800",
        "Saint-Herblain"))), "fournisseur")

      urssaf
      [year - 1, year].each do |current_year|
        (1..12).each { |month| month_events(current_year, month) }
        (1..4).each { |quarter| declare(current_year, quarter) }
      end
      say "Recettes, achats et déclarations jusqu'au #{real_today.to_s("%d/%m/%Y")}"
      say "#{agenda.run} opérations datées exécutées"
      unless @unpaid.empty?
        say "Télépaiement URSSAF non enregistré (anomalie connue, doc/ETAT.adoc) : " \
            "#{@unpaid.map(&.to_s("%m/%Y")).join(", ")}"
      end
      pending_receipts
    end

    private def nature(nature_code : String) : Int64
      (Api::Micro.natures(system).find { |item| item.code == nature_code } ||
        raise LoadError.new("nature #{nature_code} absente")).id
    end

    private def purchase_nature(category : String) : Int64
      (Api::Micro.natures(system, "purchase").find { |item| item.category == category } ||
        Api::Micro.natures(system, "purchase").first? || raise LoadError.new("nature d'achat absente")).id
    end

    # URSSAF simulée : identifiants, mandat de déclaration et mandat SEPA,
    # signés en début d'exercice.
    private def urssaf : Nil
      ok(Urssaf::Api.save_credentials(actor, Urssaf::Api::CredentialsInput.new(Urssaf::SimulatedUrssaf::CLIENT_ID,
        Urssaf::SimulatedUrssaf::CLIENT_SECRET)), "identifiants URSSAF simulés")
      on(date(year - 1, 1, 5)) do
        ok(Urssaf::Api.sign_mandate(actor, Urssaf::Api::MandateInput.new(today, true)), "mandat URSSAF")
        ok(Urssaf::Api.notify_mandate(actor), "notification du mandat")
        ok(Urssaf::Api.register_sepa_mandate(actor, Urssaf::Api::SepaMandateInput.new("FR7630006000011234567890189",
          "AGRIFRPP", "Nicolas Perrot", today, true)), "mandat de prélèvement SEPA")
      end
    end

    private def month_events(current : Int32, month : Int32) : Nil
      index = (current - (year - 1)) * 12 + month - 1
      {5, 12, 19, 26}.each_with_index do |day, week|
        agenda.at(date(current, month, day)) do
          # Montants ronds : voir doc/ETAT.adoc (reste dû URSSAF au centime).
          amount = d((15 + (index * 7 + week * 23) % 11) * 10)
          ok(Api::Micro.record_receipt(actor, Api::Micro::ReceiptInput.new(date: today, nature_id: nature("SALE"), amount: amount,
            method: week.even? ? "card" : "cash", party_name: "Clients au comptoir", label: "Ventes d'accessoires de la semaine")),
            "ventes au comptoir")
        end
      end
      agenda.at(date(current, month, 9)) do
        invoice(CUSTOMERS[index % 3][0], [{"REVISION", 1}, {"PNEU", 2}, {"CHAMBRE", 2}], 0)
      end
      agenda.at(date(current, month, 21)) do
        invoice(CUSTOMERS[(index + 1) % 3][0], [{"CREVAISON", 1}, {"MO", 1 + index % 2}], 3)
      end
      agenda.at(date(current, month, 15)) do
        invoice("CLI-LOCALOIRE", [{"REVISION", 4 + index % 3}, {"MO", 2}, {"CHAMBRE", 6}], 30)
      end
      agenda.at(date(current, month, 4)) do
        amount = d(320 + index % 5 * 45)
        ok(Api::Micro.record_purchase(actor, Api::Micro::PurchaseInput.new(date: today, nature_id: purchase_nature("goods"),
          amount: amount, method: "transfer", card_id: card("FOU-DCO").id, party_name: "Distribution Cycles Ouest SAS",
          label: "Pièces et accessoires", reference: "DCO-#{today.to_s("%y%m")}-#{400 + index}",
          attachment_id: scanned(amount))), "achat de pièces")
      end
      agenda.at(date(current, month, 7)) do
        ok(Api::Micro.record_purchase(actor, Api::Micro::PurchaseInput.new(date: today, nature_id: purchase_nature("other"),
          amount: d("450"), method: "transfer", party_name: "M. et Mme Chevalier (bailleurs)", label: "Loyer de la boutique")),
          "loyer")
      end
    end

    # Facture en franchise de TVA, encaissée `days` jours plus tard
    # (règlement saisi : la recette entre au livre).
    private def invoice(customer_code : String, lines : Array({String, Int32}), days : Int32) : Nil
      customer = card(customer_code)
      draft = ok(Inv.create_document(actor, Inv::DocumentInput.new(kind: "invoice", customer_card_id: customer.id,
        lines: lines.map { |(item_code, quantity)| Inv::LineInput.new(item_card_id: card(item_code).id, quantity: d(quantity)) },
        operation_category: "mixed")), "facture pour #{customer_code}")
      issued = ok(Inv.issue(actor, draft.id, Inv::IssueInput.new(today)), "émission de la facture")
      agenda.at(today + days.days) do
        ok(Inv.record_payment(actor, Inv::PaymentInput.new(issued.id, issued.totals.total_gross, today,
          days.zero? ? "card" : "transfer")), "règlement de #{issued.number}")
      end
    end

    # Déclaration trimestrielle à l'URSSAF simulée le 20 du mois suivant le
    # trimestre, puis télépaiement.
    private def declare(current : Int32, quarter : Int32) : Nil
      starts_on = date(current, quarter * 3 - 2, 1)
      agenda.at(starts_on + 3.months + 19.days) do
        ok(Urssaf::Api.declare(actor, starts_on), "déclaration URSSAF du #{starts_on.to_s("%m/%Y")}")
        begin
          ok(Urssaf::Api.pay(actor, starts_on), "télépaiement URSSAF du #{starts_on.to_s("%m/%Y")}")
        rescue Marten::DB::Errors::InvalidRecord
          # Reste dû à plus de deux décimales refusé par partiduo-urssaf
          # (doc/ETAT.adoc, « Anomalies relevées ») : trimestre laissé à payer.
          @unpaid << starts_on
        end
      end
    end

    # Facture du fournisseur (copie numérisée), jointe à l'achat.
    private def scanned(amount : BigDecimal) : Int64
      image = Receipt.invoice("DISTRIBUTION CYCLES OUEST", "ZI DU BOIS DE BOUCHET 44800 SAINT-HERBLAIN",
        "DCO-#{today.to_s("%y%m%d")}", today, [{"PIECES ET ACCESSOIRES", money(amount)}], money((amount / d("1.2")).round(2)),
        money(amount - (amount / d("1.2")).round(2)), money(amount), {46_u8, 125_u8, 50_u8})
      ok(Core.store_attachment(actor, Core::AttachmentInput.new("facture-dco-#{today.to_s("%Y%m%d")}.png", "image/png",
        IO::Memory.new(image))), "copie de facture").id
    end

    # Deux tickets photographiés restent à traiter (boîte « Justificatifs à
    # traiter »).
    private def pending_receipts : Nil
      [{"QUINCAILLERIE DU CENTRE", "Graisse et dégraissant", "18.40"}, {"LIBRAIRIE DU RALLIEMENT", "Carnet de reçus", "6.90"}].each do |(shop, label, amount)|
        value = d(amount)
        image = Receipt.ticket(shop, "ANGERS", [{label, money(value)}], money(value), "0,00", today, "CARTE", {150_u8, 60_u8, 90_u8})
        ok(Document::Api.capture(actor, Document::Api::CaptureInput.new("ticket-#{shop.downcase.gsub(' ', '-')}.png", image,
          "photo", Document::Api::DetailsInput.new(supplier_name: shop, amount: value, date: today, kind: "ticket"))),
          "justificatif à traiter")
      end
    end
  end
end
