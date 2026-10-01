# SPDX-License-Identifier: AGPL-3.0-or-later

module PartiduoDemo
  # Dossier « atelier » : Menuiserie Lambert & Fils, SARL de menuiserie et
  # d'agencement à Tours (entreprise fictive), au régime réel, TVA
  # mensuelle (CA3). Un exercice complet (l'année précédente, douze
  # déclarations de TVA, liasse et DAS2 télétransmises au TELEDEC simulé)
  # et l'exercice en cours jusqu'au jour réel : ventes (devis, acomptes,
  # factures, avoirs, relances), achats, banque rapprochée, paie en
  # opérations diverses, analytique, stock, justificatifs photographiés,
  # CRM, modèles de factures, facturation électronique par une plateforme
  # agréée simulée et Chorus Pro simulé.
  class Atelier < Dossier
    def code : String
      "atelier"
    end

    def settings : Core::SettingsInput
      Core::SettingsInput.new(company_name: "Menuiserie Lambert & Fils", legal_form: "SARL", share_capital: d("20000"),
        rcs: "RCS Tours 847 315 629", siren: "847 315 629", vat_number: "FR13847315629", street: "rue des Charpentiers",
        street_number: "14", postcode: "37100", city: "Tours", country_code: "FR", phone: "02 47 00 00 00",
        email: "contact@menuiserie-lambert.test", tax_regime: "fr", default_locale: "fr", domain: host)
    end

    def modules : Array(String)
      %w[accounting invoicing analytic stock followup]
    end

    def extensions : Array(String)
      %w[document einv teledec crm modeles choruspro]
    end

    def people : Array(Person)
      [Person.new("gerante@atelier.demo.test", "Sophie", "Lambert"),
       Person.new("comptable@atelier.demo.test", "Marc", "Delorme", "ACCOUNTANT", "accountant"),
       Person.new("commercial@atelier.demo.test", "Julien", "Lambert")]
    end

    def tour : Array(String)
      [
        "Tableau de bord : chiffre d'affaires, trésorerie, « À traiter » (relances, justificatifs, factures reçues)",
        "Devis et factures (menu Facturation) : devis accepté → facture d'acompte → facture finale, avoirs, relances",
        "Bons à facturer (menu Facturation) : Décoration Val de Loire, client livré plusieurs fois par mois et facturé " \
        "en fin de mois (facture récapitulative, retour d'une étagère déduit) ; encours maximum HT sur sa fiche",
        "Paiement rejeté : un chèque impayé (« À traiter », facture de nouveau due, frais refacturés, relance proposée)",
        "Comptabilité : journaux, balance, grand livre, lettrage, rapprochement bancaire, TVA (CA3 mensuelles closes)",
        "Analytique (activités), stock (dépôt de l'atelier), justificatifs à traiter (tickets photographiés)",
        "Extensions : CRM (/ext/CRM/pipeline), modèles de factures (/ext/MODELES/), EINV (/ext/EINV/), " \
        "TELEDEC (/ext/TELEDEC/), Chorus Pro (/ext/CHORUSPRO/)",
      ]
    end

    # --- Référentiel ----------------------------------------------------------------

    # Articles vendus : code, désignation, unité, prix HT, compte, suivi en
    # stock, poste analytique.
    SALE_ITEMS = [
      {"ETAG", "Étagère murale en chêne massif", "C62", "145", "701", true, "MOBILIER"},
      {"TABLE", "Table basse en noyer", "C62", "690", "701", true, "MOBILIER"},
      {"BIBLIO", "Bibliothèque sur mesure (module)", "C62", "1180", "701", true, "MOBILIER"},
      {"AGENC", "Agencement sur mesure (mètre linéaire)", "MTR", "420", "706", false, "AGENCEMENT"},
      {"POSE", "Pose et installation (heure)", "HUR", "52", "706", false, "POSE"},
      {"CONCEPT", "Conception et plans (forfait)", "C62", "350", "706", false, "AGENCEMENT"},
    ]

    # Matières achetées : code, désignation, unité, prix d'achat HT.
    MATERIALS = [
      {"PL-CHENE", "Plateau chêne 27 mm", "MTK", "68"},
      {"PL-NOYER", "Plateau noyer 27 mm", "MTK", "95"},
      {"QUINC", "Quincaillerie (lot)", "C62", "38"},
    ]

    record Party, code : String, name : String, nature : String, siren : String, email : String, line1 : String,
      postcode : String, city : String

    # Client livré plusieurs fois par mois, facturé en fin de mois (facture
    # récapitulative, art. 289-I-3 du CGI) avec un encours maximum HT.
    MONTHLY_CUSTOMER = Party.new("CLI-DECOVAL", "Décoration Val de Loire SARL", "business", "518400007",
      "achats@deco-valdeloire.test", "18 avenue de Grammont", "37000", "Tours")
    MONTHLY_CREDIT_LIMIT = "4200"

    CUSTOMERS = [
      Party.new("CLI-MOREAU", "Claire Moreau", "individual", "", "claire.moreau@exemple.test", "8 allée des Tilleuls", "37000", "Tours"),
      Party.new("CLI-GIRARD", "Thomas Girard", "individual", "", "thomas.girard@exemple.test", "21 rue du Commerce", "37300", "Joué-lès-Tours"),
      Party.new("CLI-BERNARD", "Émilie et Paul Bernard", "individual", "", "famille.bernard@exemple.test", "3 impasse des Vignes", "37540", "Saint-Cyr-sur-Loire"),
      Party.new("CLI-MARINIERS", "Hôtel des Mariniers SAS", "business", "812649036", "compta@hotel-mariniers.test", "2 quai des Mariniers", "37000", "Tours"),
      Party.new("CLI-PAINDORE", "Boulangerie Au Pain Doré SARL", "business", "795301480", "contact@paindore.test", "45 rue Nationale", "37400", "Amboise"),
      Party.new("CLI-AUBERT", "Cabinet Aubert Architectes SELARL", "business", "882136575", "agence@aubert-architectes.test", "10 place Plumereau", "37000", "Tours"),
      Party.new("CLI-GUINGUETTE", "Restaurant La Guinguette SAS", "business", "829471036", "gerance@la-guinguette.test", "1 chemin de Loire", "37210", "Vouvray"),
    ]

    SUPPLIERS = [
      Party.new("FOU-SCIERIE", "Scierie du Val de Loir SAS", "business", "831904768", "factures@scierie-valdeloir.test", "ZA des Grands Champs", "72500", "Château-du-Loir"),
      Party.new("FOU-QUINC", "Quincaillerie Rousseau SARL", "business", "876543216", "ventes@quincaillerie-rousseau.test", "17 rue de la Fonderie", "37100", "Tours"),
      Party.new("FOU-SCI", "SCI Les Charpentiers", "business", "804172591", "gestion@sci-charpentiers.test", "14 rue des Charpentiers", "37100", "Tours"),
      Party.new("FOU-ENERGIE", "Énergies Centre Loire", "business", "", "clients@energies-centre-loire.test", "5 boulevard Heurteloup", "37000", "Tours"),
      Party.new("FOU-TELECOM", "Télécom Touraine", "business", "", "service@telecom-touraine.test", "30 avenue de Grammont", "37000", "Tours"),
      Party.new("FOU-ASSUR", "Mutuelle des Artisans du Centre", "business", "", "contrats@mutuelle-artisans.test", "12 rue Édouard-Vaillant", "45000", "Orléans"),
      Party.new("FOU-EXPERT", "Delorme & Associés, experts-comptables", "business", "", "cabinet@delorme-associes.test", "6 rue de Bordeaux", "37000", "Tours"),
      Party.new("FOU-GARNIER", "GARNIER Hélène", "individual", "", "helene.garnier@exemple.test", "9 rue Colbert", "37000", "Tours"),
      Party.new("FOU-STATION", "Station-service du Cher", "business", "", "", "Route de Savonnières", "37510", "Ballan-Miré"),
    ]

    # Comptes du plan à créer : numéro, libellé, parent.
    ACCOUNTS = [
      {"110", "Report à nouveau (solde créditeur)", "1"},
      {"164", "Emprunts auprès des établissements de crédit", "16"},
      {"2154", "Matériel industriel", "21"},
      {"311", "Stocks de matières premières", "31"},
      {"28154", "Amortissements du matériel industriel", "281"},
      {"431", "Sécurité sociale", "43"},
      {"601", "Achats de matières premières", "60"},
      {"6061", "Fournitures non stockables (eau, énergie, carburant)", "60"},
      {"6063", "Fournitures d'entretien et de petit équipement", "60"},
      {"6132", "Locations immobilières", "61"},
      {"616", "Primes d'assurance", "61"},
      {"6226", "Honoraires", "62"},
      {"6256", "Missions et réceptions", "62"},
      {"626", "Frais postaux et de télécommunications", "62"},
      {"627", "Services bancaires et assimilés", "62"},
      {"661", "Charges d'intérêts", "66"},
    ]

    ANALYTIC_POSTS = {"AGENCEMENT" => "Agencement sur mesure", "MOBILIER" => "Mobilier fabriqué à l'atelier",
                      "POSE" => "Pose et installation", "STRUCTURE" => "Frais de structure"}

    # --- Chargement -----------------------------------------------------------------------

    @posts = {} of String => Int64
    @repository_id = 0_i64
    @bank_id = 0_i64
    @misc_id = 0_i64
    @purchase_id = 0_i64
    @quote_sequence = 0
    @scierie_sequence = 0

    def load : Nil
      real_today
      reference
      [year - 1, year].each do |current|
        fiscal_year(current)
        (1..12).each { |month| month_events(current, month) }
      end
      say "Ouverture de l'exercice #{year - 1} et opérations au jour le jour jusqu'au #{real_today.to_s("%d/%m/%Y")}"
      opening(year - 1)
      count = agenda.run
      say "#{count} opérations datées exécutées"
      after_today
    end

    private def reference : Nil
      say "Référentiel : plan comptable, fiches, articles, analytique, stock, paramètres"
      ACCOUNTS.each { |(number, label, parent)| account(number, label, parent) }
      @bank_id = Acc.ledgers(system, Acc::LedgerKind::Financial).first.id
      @misc_id = Acc.ledgers(system, Acc::LedgerKind::Misc).first.id
      purchase = Acc.ledgers(system, Acc::LedgerKind::Purchase).first
      @purchase_id = purchase.id
      ok(Acc.update_ledger(system, purchase.id, Acc::LedgerInput.new(name: purchase.name, kind: purchase.kind,
        code: purchase.code, description: purchase.description, enabled: true, default_account: "601",
        receipt_prefix: purchase.receipt_prefix, receipt_padding: purchase.receipt_padding)), "journal d'achats")

      current = Inv.settings(system)
      ok(Inv.update_settings(system, current.to_input.copy_with(vat_on_debits: true, iban: "FR7630006000011234567890189",
        bic: "AGRIFRPP", sender_email: "facturation@menuiserie-lambert.test", sender_name: "Menuiserie Lambert & Fils",
        late_penalty_rate: d("12.5"), default_operation_category: "mixed")), "paramètres de la Facturation")

      CUSTOMERS.each do |party|
        public_party = party.nature == "public"
        ok(Cards.create_card(system, Cards::CardInput.new(category_id: category("CUSTOMER"), name: party.name, code: party.code,
          siren: party.siren.presence, customer_nature: party.nature, email: party.email,
          vat_number: party.siren.empty? || public_party ? nil : vat_number(party.siren),
          address: address(party.line1, party.postcode, party.city))), "client #{party.code}")
      end
      monthly = MONTHLY_CUSTOMER
      decoval = ok(Cards.create_card(system, Cards::CardInput.new(category_id: category("CUSTOMER"), name: monthly.name,
        code: monthly.code, siren: monthly.siren, customer_nature: monthly.nature, email: monthly.email,
        vat_number: vat_number(monthly.siren), address: address(monthly.line1, monthly.postcode, monthly.city))),
        "client #{monthly.code}")
      ok(Inv.update_customer_billing(actor, decoval.id, Inv::CustomerBillingInput.new("monthly", d(MONTHLY_CREDIT_LIMIT))),
        "facturation mensuelle de #{monthly.code}")
      ok(Cards.create_card(system, Cards::CardInput.new(category_id: category("CUSTOMER"), name: Simulators::PUBLIC_NAME,
        code: "CLI-VALBRENNE", siren: Simulators::PUBLIC_SIRET[0, 9], siret: Simulators::PUBLIC_SIRET, customer_nature: "public",
        email: "factures@val-de-brenne.test", address: address("Place de la Mairie", "37190", "Val-de-Brenne"))), "client public")
      SUPPLIERS.each do |party|
        individual = party.nature == "individual"
        ok(Cards.create_card(system, Cards::CardInput.new(category_id: category("SUPPLIER"), name: individual ? "" : party.name,
          code: party.code, siren: party.siren.presence, email: party.email.presence,
          vat_number: party.siren.empty? ? nil : vat_number(party.siren), supplier_nature: party.nature,
          last_name: individual ? "Garnier" : nil, first_names: individual ? "Hélène" : nil,
          birth_date: individual ? Time.utc(1984, 5, 17) : nil, description: individual ? "Architecte d'intérieur" : nil,
          address: address(party.line1, party.postcode, party.city))), "fournisseur #{party.code}")
      end

      # Taux hors champ de la TVA (catégorie O) : frais d'impayé refacturés,
      # indemnité non soumise à la TVA (D-INV3-010).
      ok(Vat.create_rate(system, Vat::RateInput.new(code: "HC", label: "Hors champ de la TVA", rate: d("0"), category: "O",
        exemption_code: "VATEX-EU-O", exemption_reason: "Indemnité hors champ de la TVA")), "taux hors champ")
      normal = rate("NOR")
      SALE_ITEMS.each do |(item_code, name, unit, price, account_number, _, _)|
        item = ok(Cards.create_card(system, Cards::CardInput.new(category_id: category("SALE"), name: name, code: item_code,
          unit_code: unit, sale_price: d(price), vat_rate_id: normal)), "article #{item_code}")
        ok(Acc.assign_card_account(system, Acc::AssignCardAccountInput.new(item.id, account_number)), "compte de #{item_code}")
      end
      MATERIALS.each do |(item_code, name, unit, price)|
        item = ok(Cards.create_card(system, Cards::CardInput.new(category_id: category("PURCHASE"), name: name, code: item_code,
          unit_code: unit, purchase_price: d(price), vat_rate_id: normal)), "matière #{item_code}")
        ok(Acc.assign_card_account(system, Acc::AssignCardAccountInput.new(item.id, "601")), "compte de #{item_code}")
      end

      plan = ok(Ana.create_plan(actor, Ana::PlanInput.new("Activités", "Rentabilité par ligne d'activité")), "plan analytique")
      ANALYTIC_POSTS.each do |post_code, description|
        @posts[post_code] = ok(Ana.create_post(actor, Ana::PostInput.new(plan.id, post_code, description)), "poste #{post_code}").id
      end
      ok(Ana.create_key(actor, Ana::KeyInput.new("Matières par activité", [
        Ana::KeyRowInput.new(d("50"), [@posts["MOBILIER"]]),
        Ana::KeyRowInput.new(d("40"), [@posts["AGENCEMENT"]]),
        Ana::KeyRowInput.new(d("10"), [@posts["POSE"]]),
      ], "Répartition des achats de bois et de quincaillerie", [@purchase_id])), "clé de répartition")

      repository = ok(Stk.create_repository(actor, Stk::RepositoryInput.new("Atelier de Tours", "14 rue des Charpentiers",
        "Tours", "FR", "02 47 00 00 00")), "dépôt")
      @repository_id = repository.id
      ok(Stk.update_settings(actor, Stk::SettingsInput.new(repository.id)), "dépôt par défaut")
      (SALE_ITEMS.select(&.[5]).map(&.[0]) + MATERIALS.first(2).map(&.[0])).each do |item_code|
        ok(Stk.track_item(actor, Stk::ItemInput.new(card(item_code).id)), "suivi en stock de #{item_code}")
      end

      ok(Einvoicing::Api.configure(actor, Einvoicing::Api::ConnectionInput.new("AFNOR", Simulators::PLATFORM_VALUES)),
        "raccordement à la plateforme agréée simulée")
      ok(Choruspro::Api.save_credentials(actor, Choruspro::Api::CredentialsInput.new(Choruspro::SimulatedChorusPro::CLIENT_ID,
        Choruspro::SimulatedChorusPro::CLIENT_SECRET, Choruspro::SimulatedChorusPro::LOGIN,
        Choruspro::SimulatedChorusPro::PASSWORD)), "identifiants Chorus Pro simulés")
    end

    # Numéro de TVA intracommunautaire français d'un SIREN.
    def vat_number(siren : String) : String
      "FR%02d%s" % {(12 + 3 * (siren.to_i64 % 97)) % 97, siren}
    end

    # À-nouveaux du 1er janvier de l'exercice complet.
    private def opening(first_year : Int32) : Nil
      agenda.at(date(first_year, 1, 1)) do
        post_misc("Reprise des soldes au 1er janvier", "AN-#{first_year}", [
          {"510001", :debit, "24350"}, {"2154", :debit, "38000"}, {"311", :debit, "4200"},
          {"28154", :credit, "12600"}, {"101", :credit, "20000"}, {"1061", :credit, "2000"},
          {"110", :credit, "11950"}, {"164", :credit, "20000"},
        ])
        ok(Stk.record_inventory(actor, Stk::InventoryInput.new(@repository_id, today, [
          Stk::InventoryLineInput.new(card("ETAG").id, d("12"), d("48")),
          Stk::InventoryLineInput.new(card("TABLE").id, d("3"), d("260")),
          Stk::InventoryLineInput.new(card("BIBLIO").id, d("4"), d("430")),
          Stk::InventoryLineInput.new(card("PL-CHENE").id, d("40"), d("68")),
          Stk::InventoryLineInput.new(card("PL-NOYER").id, d("20"), d("95")),
        ], "Inventaire d'ouverture")), "inventaire d'ouverture")
      end
    end

    # --- Programme d'un mois ---------------------------------------------------------------

    private def month_events(current : Int32, month : Int32) : Nil
      index = (current - (year - 1)) * 12 + month - 1
      at = ->(day : Int32) { date(current, month, day) }

      agenda.at(at.call(3)) { materials_purchase(current, month, index) }
      agenda.at(at.call(5)) { rent(month) }
      agenda.at(at.call(10)) { utilities(month, index) }
      agenda.at(at.call(15)) { vat_return(current, month) }
      agenda.at(at.call(20)) { production(index) }
      agenda.at(at.call(28)) { payroll_and_bank(month) }
      agenda.at(at.call(3) + 1.month) { reconcile(current, month) }
      agenda.at(at.call(12)) { insurance } if month.in?(1, 4, 7, 10)
      agenda.at(at.call(22)) { accountant_fees(month) } if month.in?(3, 6, 9, 12)
      agenda.at(at.call(18)) { architect_fees(month) } if month.in?(3, 10)
      agenda.at(at.call(9)) { hardware(month) } if month.even?
      agenda.at(at.call(14)) { fuel_ticket(current, month, index) }

      sales_month(current, month, index)
      monthly_deliveries(current, month)
    end

    # Trois derniers mois de l'exercice en cours : trois livraisons par mois
    # à Décoration Val de Loire (étagères suivies en stock, pose non suivie),
    # fin de mois planifiée (`month_end`, comme la tâche quotidienne de
    # l'instance) ; la facture récapitulative de l'avant-dernier mois est
    # émise et envoyée d'un clic le 1er, puis réglée ; celle du mois dernier
    # reste proposée dans « À traiter », une étagère rapportée le 25 (bon de
    # retour, entrée en stock) y venant en déduction (D-INV3-003) ; les bons
    # du mois en cours restent à facturer.
    private def monthly_deliveries(current : Int32, month : Int32) : Nil
      return unless current == year
      age = real_today.month - month
      return unless 0 <= age <= 2
      customer = card(MONTHLY_CUSTOMER.code)
      first_delivery = nil.as(Int64?)
      {4, 13, 21}.each_with_index do |day, rank|
        agenda.at(date(current, month, day)) do
          draft = ok(Inv.create_document(actor, Inv::DocumentInput.new(kind: "delivery_note", customer_card_id: customer.id,
            lines: [line("ETAG", 3), line("POSE", 4)], notes: "Livraison n° #{rank + 1} du mois", operation_category: "mixed")),
            "bon de livraison pour #{customer.code}")
          issued = ok(Inv.issue(actor, draft.id, Inv::IssueInput.new(today)), "émission du bon de livraison")
          first_delivery ||= issued.id
        end
      end
      if age == 1
        agenda.at(date(current, month, 25)) do
          origin = first_delivery
          return_shelf(origin) if origin
        end
      end
      return if age == 0
      agenda.at(date(current, month, 31)) { Inv.month_end(actor, today) }
      return unless age == 2
      agenda.at(date(current, month, 31) + 1.day) do
        Inv.issue_and_send_proposals(actor).each do |result|
          outcome = ok(result, "émission de la facture récapitulative")
          distribute_sale(outcome.document)
          pay_later(outcome.document, 20)
        end
      end
    end

    # Ventes du mois : quatre factures directes, un devis ; un mois sur
    # deux, le devis est accepté (acompte de 30 %, puis facture finale).
    private def sales_month(current : Int32, month : Int32, index : Int32) : Nil
      bonus = index % 3
      individual = CUSTOMERS[index % 3].code
      business = CUSTOMERS[3 + index % 4].code

      agenda.at(date(current, month, 6)) do
        invoice = sell(individual, [line("ETAG", 2 + bonus), line("POSE", 3 + bonus)], "Pose d'étagères")
        if month.in?(3, 6, 9, 12)
          agenda.at(today + 6.days) { credit_note(invoice, "Étagère au vernis défectueux, reprise") }
        end
        pay_later(invoice, 21)
      end
      agenda.at(date(current, month, 11)) do
        invoice = sell(business, [line("AGENC", 5 + bonus), line("POSE", 12 + 2 * bonus)], "Agencement")
        pay_later(invoice, business == "CLI-GUINGUETTE" ? 75 : 35)
      end
      agenda.at(date(current, month, 17)) do
        if month.in?(4, 10)
          invoice = sell("CLI-VALBRENNE", [line("BIBLIO", 4), line("POSE", 8)], "Bibliothèques de la médiathèque",
            order_reference: "BC-#{current}-#{month.to_s.rjust(2, '0')}")
          if Choruspro::Api.invoices(actor).any? { |item| item.id == invoice.id }
            ok(Choruspro::Api.transmit(actor, invoice.id), "dépôt sur Chorus Pro simulé")
          end
          pay_later(invoice, 40)
        else
          customer = CUSTOMERS[(index + 1) % 7].code
          invoice = sell(customer, [line("TABLE", 1 + bonus % 2), line("BIBLIO", 1 + bonus)], "Mobilier sur mesure")
          pay_later(invoice, customer == "CLI-GUINGUETTE" ? 80 : 28)
        end
      end
      agenda.at(date(current, month, 24)) do
        invoice = sell(CUSTOMERS[(index + 2) % 7].code, [line("CONCEPT", 1), line("POSE", 4 + bonus)], "Étude et relevés")
        pay_later(invoice, 30)
      end
      agenda.at(date(current, month, 8)) { quote(current, month, index) }
    end

    # Bon de retour d'une étagère au vernis rayé, tiré du bon de livraison
    # (entrée en stock à l'émission) : déduit de la facture récapitulative du
    # mois.
    private def return_shelf(delivery_id : Int64) : Nil
      draft = ok(Inv.transform(actor, delivery_id, Inv::TransformInput.new("return_note")), "bon de retour")
      ok(Inv.update_document(actor, draft.id, Inv::DocumentInput.new(kind: "return_note",
        customer_card_id: draft.customer_card_id, lines: [line("ETAG", 1)], return_reason: "damaged",
        notes: "Étagère au vernis rayé, reprise", operation_category: "goods")), "motif du retour")
      ok(Inv.issue(actor, draft.id, Inv::IssueInput.new(today)), "émission du bon de retour")
    end

    private def line(item_code : String, quantity : Int32) : Inv::LineInput
      Inv::LineInput.new(item_card_id: card(item_code).id, quantity: d(quantity))
    end

    # Facture émise au jour du dossier, ventilée en analytique.
    private def sell(customer_code : String, lines : Array(Inv::LineInput), subject : String,
                     order_reference : String? = nil) : Inv::DocumentView
      customer = card(customer_code)
      document = ok(Inv.create_document(actor, Inv::DocumentInput.new(kind: "invoice", customer_card_id: customer.id,
        lines: lines, notes: subject, order_reference: order_reference, operation_category: category_of(lines))),
        "facture pour #{customer_code}")
      issue(document)
    end

    private def category_of(lines : Array(Inv::LineInput)) : String
      goods = lines.map { |item| SALE_ITEMS.find! { |row| card(row[0]).id == item.item_card_id }[5] }
      goods.all? ? "goods" : (goods.none? ? "services" : "mixed")
    end

    private def issue(document : Inv::DocumentView) : Inv::DocumentView
      issued = ok(Inv.issue(actor, document.id, Inv::IssueInput.new(today)), "émission de #{document.kind} #{document.id}")
      distribute_sale(issued)
      if issued.issue_channel == "email" && !issued.customer.email.empty?
        ok(Inv.send_document(actor, issued.id, Inv::SendInput.new([issued.customer.email])), "envoi par courriel")
      end
      issued
    end

    # Écriture de vente générée par la Comptabilité pour un document émis.
    def sale_entry(document : Inv::DocumentView) : Acc::EntryView?
      prefix = document.kind == "credit_note" ? "credit_note" : "invoice"
      Acc.entries(actor, Acc::EntryQuery.new(source: "#{prefix}:#{document.id}")).first? ||
        Acc.entries(actor, Acc::EntryQuery.new(source: "#{document.kind}:#{document.id}")).first?
    end

    # Ventilation analytique des lignes de produits (70x) d'une vente.
    private def distribute_sale(document : Inv::DocumentView) : Nil
      entry = sale_entry(document) || return
      lines = entry.lines.select(&.account_number.starts_with?("70")).map do |entry_line|
        item = SALE_ITEMS.find { |row| row[1] == entry_line.label || entry_line.label.starts_with?(row[1]) }
        post = item ? item[6] : (entry_line.account_number == "701" ? "MOBILIER" : "AGENCEMENT")
        Ana::LineDistributionInput.new(entry_line.id, [Ana::DistributionRowInput.new(entry_line.amount, [@posts[post]])])
      end
      ok(Ana.distribute_entry(actor, entry.id, lines), "ventilation de #{entry.receipt}") unless lines.empty?
    end

    # Lignes du tiers (client ou fournisseur) d'une écriture, non lettrées,
    # et leur solde signé (débit positif).
    private def party_lines(entry : Acc::EntryView, card_id : Int64) : {Array(Int64), BigDecimal}
      lines = entry.lines.select { |item| item.card_id == card_id && item.matching_id.nil? && item.account_number.starts_with?("4") }
      total = lines.sum(d(0)) { |item| item.side.debit? ? item.amount : -item.amount }
      {lines.map(&.id), total}
    end

    # Encaissement en banque, lettré avec la facture (et ses avoirs).
    private def pay_later(document : Inv::DocumentView, days : Int32) : Nil
      agenda.at(today + days.days) do
        current = Inv.document(actor, document.id)
        next if current.effective_status.in?("paid", "cancelled")
        entry = sale_entry(current) || next
        # Un avoir déjà lettré avec la facture (lettrage partiel) : le
        # lettrage est repris pour réunir facture, avoir et encaissement.
        entry.lines.select(&.card_id.==(current.customer_card_id)).each do |item|
          item.matching_id.try { |matching| ok(Acc.unmatch(actor, matching), "reprise du lettrage de #{current.number}") }
        end
        entry = Acc.entry(actor, entry.id)
        ids, total = party_lines(entry, current.customer_card_id)
        current.credit_notes.each do |link|
          credit = Inv.document(actor, link.id)
          (sale_entry(credit) || next).try do |credit_entry|
            more, amount = party_lines(credit_entry, current.customer_card_id)
            ids.concat(more)
            total += amount
          end
        end
        next if ids.empty? || total <= 0
        customer = card(Inv.document(actor, document.id).customer.code.presence || Cards.card(system, current.customer_card_id).code)
        ok(Acc.post_financial(actor, Acc::FinancialInput.new(@bank_id, today, [
          Acc::PaymentLineInput.new(total, card: customer.code, label: "Virement #{customer.name} #{current.number}",
            match_line_ids: ids),
        ])), "encaissement de #{current.number}")
      end
    end

    private def credit_note(invoice : Inv::DocumentView, reason : String) : Nil
      note = ok(Inv.create_document(actor, Inv::DocumentInput.new(kind: "credit_note", customer_card_id: invoice.customer_card_id,
        lines: [line("ETAG", 1)], credited_document_id: invoice.id, notes: reason, operation_category: "goods")),
        "avoir sur #{invoice.number}")
      issue(note)
    end

    # Devis du mois ; un mois sur deux accepté (acompte, facture finale),
    # sinon refusé ou laissé en attente.
    private def quote(current : Int32, month : Int32, index : Int32) : Nil
      @quote_sequence += 1
      customer = card(CUSTOMERS[(index + 3) % 7].code)
      lines = [line("AGENC", 8 + index % 4), line("BIBLIO", 2 + index % 2), line("POSE", 16)]
      draft = ok(Inv.create_document(actor, Inv::DocumentInput.new(kind: "quote", customer_card_id: customer.id, lines: lines,
        notes: "Projet d'agencement n° #{@quote_sequence}", operation_category: "mixed")), "devis")
      quote = ok(Inv.issue(actor, draft.id, Inv::IssueInput.new(today)), "émission du devis")
      if index.even?
        agenda.at(today + 7.days) do
          ok(Inv.decide_quote(actor, quote.id, "accepted"), "devis accepté")
          deposit = ok(Inv.transform(actor, quote.id, Inv::TransformInput.new("deposit_invoice", d("30"))), "facture d'acompte")
          deposit = issue(deposit)
          pay_later(deposit, 8)
          agenda.at(today + 30.days) do
            final = ok(Inv.transform(actor, quote.id, Inv::TransformInput.new("invoice")), "facture finale")
            final = issue(final)
            pay_later(final, 30)
          end
        end
      elsif index % 4 == 1
        agenda.at(today + 12.days) { ok(Inv.decide_quote(actor, quote.id, "refused"), "devis refusé") }
      end
    end

    # --- Achats ------------------------------------------------------------------------------

    # Facture fournisseur saisie (reçue hors plateforme), payée plus tard.
    private def purchase(supplier_code : String, number : String, lines : Array(Acc::DocumentLineInput), label : String,
                         pay_in : Int32?, attachment_id : Int64? = nil) : Acc::EntryView
      supplier = card(supplier_code)
      attachment_id ||= scanned_invoice(supplier, number, lines)
      document = Acc::DocumentInput.new(ledger_id: @purchase_id, date: today, third_party: supplier_code, lines: lines,
        label: label, due_date: pay_in.try { |days| today + days.days }, attachment_id: attachment_id)
      received = ok(Acc.post_received_invoice(actor, Acc::ReceivedInvoiceInput.new(document, number, today)),
        "facture #{number} de #{supplier_code}")
      entry = Acc.entry(actor, received.entry_id)
      if days = pay_in
        pay_supplier(entry, supplier, days, label)
      end
      entry
    end

    # Copie numérisée de la facture du fournisseur (image générée), jointe
    # à l'écriture comme l'exige une facture reçue hors plateforme.
    private def scanned_invoice(supplier : Cards::CardView, number : String, lines : Array(Acc::DocumentLineInput)) : Int64
      rows = lines.map do |item|
        amount = item.unit_price.try { |price| price * (item.quantity || d(1)) } || item.amount
        label = item.item.try { |code| "#{item.quantity} X #{card(code).name}" } || item.label
        {label, amount, item.vat_rate == "NOR" ? (amount * d("0.2")).round(2) : d(0)}
      end
      net = rows.sum(d(0), &.[1])
      vat = rows.sum(d(0), &.[2])
      party = SUPPLIERS.find { |item| item.code == supplier.code }
      image = Receipt.invoice(supplier.name, party.try { |item| "#{item.line1} #{item.postcode} #{item.city}" } || "",
        number, today, rows.map { |row| {row[0], money(row[1])} }, money(net), money(vat), money(net + vat),
        {120_u8, 72_u8, 40_u8})
      ok(Core.store_attachment(actor, Core::AttachmentInput.new("facture-#{number.downcase}.png", "image/png",
        IO::Memory.new(image))), "copie de la facture #{number}").id
    end

    private def pay_supplier(entry : Acc::EntryView, supplier : Cards::CardView, days : Int32, label : String) : Nil
      agenda.at(today + days.days) do
        current = Acc.entry(actor, entry.id)
        ids, total = party_lines(current, supplier.id)
        next if ids.empty?
        ok(Acc.post_financial(actor, Acc::FinancialInput.new(@bank_id, today, [
          Acc::PaymentLineInput.new(total, card: supplier.code, label: "Règlement #{supplier.name} — #{label}", match_line_ids: ids),
        ])), "règlement de #{supplier.code}")
      end
    end

    private def materials_purchase(current : Int32, month : Int32, index : Int32) : Nil
      @scierie_sequence += 1
      number = "SVL-#{current}-#{(@scierie_sequence * 7 + 100).to_s.rjust(4, '0')}"
      chene = 12 + index % 4
      noyer = 6 + index % 3
      if platform_month?(current, month)
        receive_on_platform(number, chene, noyer)
        return
      end
      entry = purchase("FOU-SCIERIE", number, [
        Acc::DocumentLineInput.new(item: "PL-CHENE", quantity: d(chene), unit_price: d("68"), vat_rate: "NOR"),
        Acc::DocumentLineInput.new(item: "PL-NOYER", quantity: d(noyer), unit_price: d("95"), vat_rate: "NOR"),
      ], "Plateaux de chêne et de noyer", 30)
      distribute_purchase(entry)
    end

    # Deux derniers mois avant le jour réel : la scierie facture par la
    # plateforme agréée (réforme de la facturation électronique).
    private def platform_month?(current : Int32, month : Int32) : Bool
      first = real_today.at_beginning_of_month - 1.month
      date(current, month, 1) >= first
    end

    # Facture de la scierie reçue par la plateforme simulée : relevée par la
    # synchronisation, pré-comptabilisée au journal d'achats (sauf la plus
    # récente, laissée à traiter).
    private def receive_on_platform(number : String, chene : Int32, noyer : Int32) : Nil
      net = d(chene) * d("68") + d(noyer) * d("95")
      vat = (net * d("0.2")).round(2)
      content = Ubl.invoice(number, today, net, vat, supplier: SUPPLIERS[0], buyer_siren: siren,
        buyer_name: settings.company_name.to_s, lines: [{"Plateau chêne 27 mm", chene, d("68")}, {"Plateau noyer 27 mm", noyer, d("95")}])
      Simulators.platform.deliver(content, "#{number}.xml", "UBL")
      ok(Einvoicing::Api.synchronize(actor), "synchronisation avec la plateforme")
      reception = Einvoicing::Api.receptions(actor).find { |item| item.number == number } || return
      return if today.month == real_today.month && today.year == real_today.year
      received = ok(Einvoicing::Api.post(actor, reception.id), "pré-comptabilisation de #{number}")
      pay_supplier(Acc.entry(actor, received.entry_id), card("FOU-SCIERIE"), 30, "Plateaux de chêne et de noyer")
    end

    private def distribute_purchase(entry : Acc::EntryView) : Nil
      key = Ana.keys(actor).first? || return
      lines = entry.lines.select(&.account_number.starts_with?("60")).map do |entry_line|
        Ana::LineDistributionInput.new(entry_line.id, Ana.apply_key(actor, key.id, entry_line.amount))
      end
      ok(Ana.distribute_entry(actor, entry.id, lines), "ventilation de #{entry.receipt}") unless lines.empty?
    end

    private def rent(month : Int32) : Nil
      purchase("FOU-SCI", "LOYER-#{today.to_s("%Y-%m")}", [
        Acc::DocumentLineInput.new(d("1200"), account: "6132", vat_rate: "NOR", label: "Loyer de l'atelier"),
      ], "Loyer #{today.to_s("%m/%Y")}", 0)
    end

    private def utilities(month : Int32, index : Int32) : Nil
      power = d(160 + (month.in?(1, 2, 11, 12) ? 90 : 0) + index % 5 * 7)
      purchase("FOU-ENERGIE", "ECL-#{today.to_s("%Y%m")}-#{4000 + index}", [
        Acc::DocumentLineInput.new(power, account: "6061", vat_rate: "NOR", label: "Électricité de l'atelier"),
      ], "Électricité #{today.to_s("%m/%Y")}", 12)
      purchase("FOU-TELECOM", "TT-#{today.to_s("%Y%m")}-88", [
        Acc::DocumentLineInput.new(d("54.90"), account: "626", vat_rate: "NOR", label: "Téléphone et internet"),
      ], "Télécommunications #{today.to_s("%m/%Y")}", 8)
    end

    private def hardware(month : Int32) : Nil
      entry = purchase("FOU-QUINC", "QR-#{today.to_s("%Y%m")}-#{month * 13}", [
        Acc::DocumentLineInput.new(item: "QUINC", quantity: d(3 + month % 3), unit_price: d("38"), vat_rate: "NOR"),
        Acc::DocumentLineInput.new(d("64.50"), account: "6063", vat_rate: "NOR", label: "Abrasifs et lames de scie"),
      ], "Quincaillerie et consommables", 30)
      distribute_purchase(entry)
    end

    private def insurance : Nil
      purchase("FOU-ASSUR", "MAC-#{today.to_s("%Y")}-T#{(today.month - 1) // 3 + 1}", [
        Acc::DocumentLineInput.new(d("486"), account: "616", label: "Multirisque professionnelle (trimestre)"),
      ], "Assurance du trimestre", 10)
    end

    private def accountant_fees(month : Int32) : Nil
      purchase("FOU-EXPERT", "DA-#{today.to_s("%Y")}-#{month.to_s.rjust(2, '0')}", [
        Acc::DocumentLineInput.new(d("950"), account: "6226", vat_rate: "NOR", label: "Tenue et révision"),
      ], "Honoraires comptables", 30)
    end

    # Architecte d'intérieur, personne physique en franchise de TVA :
    # honoraires déclarés en DAS2.
    private def architect_fees(month : Int32) : Nil
      purchase("FOU-GARNIER", "HG-#{today.to_s("%Y")}-#{month}", [
        Acc::DocumentLineInput.new(d("1650"), account: "6226", label: "Plans d'aménagement intérieur"),
      ], "Honoraires d'architecte d'intérieur", 20)
    end

    # Ticket de carburant photographié : justificatif avec son image ;
    # saisi en achat, sauf ceux du mois en cours (à traiter).
    private def fuel_ticket(current : Int32, month : Int32, index : Int32) : Nil
      net = d(48 + index % 4 * 6) + d("0.75")
      vat = (net * d("0.2")).round(2)
      gross = net + vat
      image = Receipt.ticket("STATION DU CHER", "ROUTE DE SAVONNIERES 37510 BALLAN-MIRE",
        [{"GAZOLE #{30 + index % 9},#{index % 10}0 L", money(gross)}], money(gross), money(vat), today, "CARTE",
        {33_u8, 102_u8, 172_u8})
      receipt = ok(Document::Api.capture(actor, Document::Api::CaptureInput.new("ticket-carburant-#{today.to_s("%Y%m%d")}.png",
        image, "photo", Document::Api::DetailsInput.new(supplier_name: "Station-service du Cher", supplier_code: "FOU-STATION",
        amount: gross, date: today, kind: "ticket", reference: "T#{today.to_s("%y%m%d")}"))), "justificatif photographié")
      return if pending_month?(current, month)
      prefill = Document::Api.purchase_prefill(actor, receipt.id, "NOR")
      document = Acc::DocumentInput.new(ledger_id: @purchase_id, date: today, third_party: "FOU-STATION", label: "Carburant du camion",
        lines: [Acc::DocumentLineInput.new(net, account: "6061", vat_rate: "NOR", vat_amount: vat, label: "Gazole")])
      number = prefill.number.presence || "T#{today.to_s("%y%m%d")}"
      received = ok(Document::Api.post_purchase(actor, receipt.id, Acc::ReceivedInvoiceInput.new(document, number, today)),
        "saisie du ticket")
      pay_supplier(Acc.entry(actor, received.entry_id), card("FOU-STATION"), 0, "Carburant")
    end

    private def pending_month?(current : Int32, month : Int32) : Bool
      current == real_today.year && month == real_today.month
    end

    # --- Production, paie, banque, TVA ----------------------------------------------------------

    private def production(index : Int32) : Nil
      ok(Stk.record_change(actor, Stk::ChangeInput.new(@repository_id, today, [
        Stk::ChangeLineInput.new(card("ETAG").id, d(4 + index % 3), d("48")),
        Stk::ChangeLineInput.new(card("TABLE").id, d(2), d("260")),
        Stk::ChangeLineInput.new(card("BIBLIO").id, d(3 + index % 2), d("430")),
        Stk::ChangeLineInput.new(card("PL-CHENE").id, d(-(10 + index % 4))),
        Stk::ChangeLineInput.new(card("PL-NOYER").id, d(-(5 + index % 3))),
      ], "Fabrication du mois à l'atelier")), "fabrication")
    end

    # Paie du mois en opérations diverses (compagnon et apprenti), salaires
    # nets virés, cotisations du mois précédent, frais bancaires, échéance
    # de l'emprunt.
    private def payroll_and_bank(month : Int32) : Nil
      post_misc("Salaires #{today.to_s("%m/%Y")}", "PAIE-#{today.to_s("%Y%m")}", [
        {"641", :debit, "3400"}, {"645", :debit, "1380"}, {"421", :credit, "2640"}, {"431", :credit, "2140"},
      ])
      bank([{"421", "-2640", "Virement des salaires nets"}])
      agenda.at(today + 17.days) { bank([{"431", "-2140", "Prélèvement URSSAF (cotisations)"}]) }
      bank([
        {"164", "-380", "Échéance d'emprunt (capital)"},
        {"661", "-42", "Échéance d'emprunt (intérêts)"},
        {"627", "-14.90", "Frais de tenue de compte"},
      ])
    end

    private def post_misc(label : String, receipt : String, lines : Array({String, Symbol, String})) : Acc::EntryView
      ok(Acc.post_entry(actor, Acc::EntryInput.new(@misc_id, today, lines.map do |(number, side, amount)|
        Acc::EntryLineInput.new(number, side == :debit ? Acc::Side::Debit : Acc::Side::Credit, d(amount))
      end, label, receipt)), label)
    end

    private def bank(lines : Array({String, String, String})) : Nil
      ok(Acc.post_financial(actor, Acc::FinancialInput.new(@bank_id, today, lines.map do |(number, amount, label)|
        Acc::PaymentLineInput.new(d(amount), account: number, label: label)
      end)), lines.first[2])
    end

    # CA3 du mois précédent, close avec son écriture de liquidation, TVA
    # due payée le 20.
    private def vat_return(current : Int32, month : Int32) : Nil
      period = today - 1.month
      return if period.year < year - 1
      input = Acc::VatReturnInput.new(form: "fr_ca3", year: period.year, periodicity: "month", number: period.month)
      created = ok(Acc.create_vat_return(actor, input), "CA3 de #{period.to_s("%m/%Y")}")
      closed = ok(Acc.close_vat_return(actor, created.id || raise(LoadError.new("CA3 sans identifiant")), Acc::VatSettlementInput.new(ledger_id: @misc_id, date: today)),
        "clôture de la CA3 de #{period.to_s("%m/%Y")}")
      entry = closed.settlement_entry_id.try { |id| Acc.entry(actor, id) } || return
      due = entry.lines.select { |item| item.account_number == "44551" }.sum(d(0)) { |item| item.side.credit? ? item.amount : -item.amount }
      return unless due > 0
      agenda.at(today + 5.days) { bank([{"44551", (-due).to_s, "TVA de #{period.to_s("%m/%Y")} (télépaiement)"}]) }
    end

    # Rapprochement du relevé du mois : toutes les opérations du journal de
    # banque datées du mois.
    private def reconcile(current : Int32, month : Int32) : Nil
      first = date(current, month, 1)
      last = date(current, month, 31)
      view = Acc.reconciliation(actor, @bank_id)
      ids = view.unreconciled.select { |item| first <= item.date <= last }.map(&.entry_id)
      return if ids.empty?
      ok(Acc.reconcile(actor, Acc::ReconcileInput.new(@bank_id, "Relevé #{first.to_s("%m/%Y")}", ids)),
        "rapprochement de #{first.to_s("%m/%Y")}")
    end

    # --- Après le jour le jour : extensions au jour réel ----------------------------------------

    private def after_today : Nil
      say "Relances, facturation électronique, télédéclarations, CRM, modèles de factures"
      rejected_payment
      reminders
      ok(Einvoicing::Api.synchronize(actor), "synchronisation avec la plateforme")
      ok(Einvoicing::Api.synchronize(actor), "relevé des accusés de la plateforme")
      teledec
      CrmSeed.load(self)
      modeles
    end

    # Chèque impayé (D-INV3-007) : le règlement le plus récent d'un client
    # professionnel (hors client mensuel) revient rejeté pour provision
    # insuffisante ; l'encaissement est contre-passé en banque, les frais
    # (15 €) passés en services bancaires et refacturés au client par un
    # brouillon de facture hors champ de la TVA ; relance proposée.
    private def rejected_payment : Nil
      business = CUSTOMERS.select(&.nature.==("business")).map { |party| card(party.code).id }
      paid = Inv.documents(actor, Inv::DocumentQuery.new(kind: "invoice", status: "paid", limit: 500))
        .select { |document| business.includes?(document.customer_card_id) }
      candidates = paid.compact_map do |document|
        payment = Inv.payments(actor, document.id).reject(&.rejected?).max_by?(&.paid_on) || next
        payment if payment.paid_on < today
      end
      payment = candidates.max_by?(&.paid_on) || return
      ok(Inv.reject_payment(actor, payment.id, Inv::PaymentRejectionInput.new(rejected_on: today,
        reason: "insufficient_funds", reason_text: "Chèque revenu impayé", fees: d("15"), rebill_fees: true,
        fees_vat_rate_id: rate("HC"))), "rejet du règlement de #{payment.document_number}")
    end

    private def reminders : Nil
      proposed = Inv.propose_reminders(actor, today)
      proposed.first(1).each do |reminder|
        email = Inv.document(actor, reminder.document_id).customer.email
        next if email.empty?
        ok(Inv.send_reminder(actor, reminder.id, Inv::SendInput.new([email])), "relance de #{reminder.document_number}")
      end
    end

    private def teledec : Nil
      previous = fiscal_year(year - 1)
      ok(Teledec::Api.update_settings(actor, Teledec::Api::SettingsInput.new("is_rsi", "ca3_monthly")), "paramètres TELEDEC")
      ok(Teledec::Api.save_credentials(actor, Teledec::Api::CredentialsInput.new(Teledec::SimulatedTeledec::LOGIN,
        Teledec::SimulatedTeledec::API_KEY, "sandbox", "compta@menuiserie-lambert.test", "#{siren}00018")),
        "identifiants TELEDEC simulés")
      filings = [Teledec::Api::PrepareInput.new("liasse", fiscal_year_id: previous.id),
                 Teledec::Api::PrepareInput.new("das2", year: year - 1)]
      Acc.vat_returns(actor, "fr_ca3", year).max_by? { |item| item.id || 0_i64 }.try do |vat|
        filings << Teledec::Api::PrepareInput.new("vat_ca3", vat_return_id: vat.id)
      end
      filings.each do |input|
        filing = ok(Teledec::Api.prepare(actor, input), "télédéclaration #{input.kind}")
        ok(Teledec::Api.check(actor, filing.id), "contrôle de #{input.kind}")
        ok(Teledec::Api.transmit(actor, filing.id), "transmission de #{input.kind} au TELEDEC simulé")
        ok(Teledec::Api.refresh(actor, filing.id), "accusé de #{input.kind}")
      end
    end

    private def modeles : Nil
      admin = actor
      starters = Modeles::Config::KINDS.flat_map { |kind| Modeles::Config::FORMATS.map { |format| {kind, "fr", format} } }
      starters.each do |(kind, locale, format)|
        name = "#{I18n.with_locale(locale) { I18n.t("modeles.kinds.#{kind}") }} — #{I18n.t("modeles.formats.#{format}")}"
        view = ok(Modeles::Api.upload(admin, Modeles::Api::UploadInput.new(filename: Modeles::Starters.filename(kind, locale, format),
          content: Modeles::Starters.file(kind, locale, format), name: name, kind: kind, locale: locale)), "modèle #{name}")
        ok(Modeles::Api.activate(admin, view.id), "activation du modèle #{name}")
        ok(Modeles::Api.set_default(admin, view.id), "modèle par défaut #{name}") if format == "odt"
      end
      last = Inv.documents(actor, Inv::DocumentQuery.new(kind: "invoice", limit: 1)).first?
      last.try do |invoice|
        pdf = Modeles::Converters.available?("odt")
        ok(Modeles::Api.render(admin, invoice.id, pdf: pdf), "rendu de #{invoice.number} avec le modèle par défaut")
      end
    end
  end
end
