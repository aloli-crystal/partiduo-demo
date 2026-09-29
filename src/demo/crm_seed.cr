# SPDX-License-Identifier: AGPL-3.0-or-later

module PartiduoDemo
  # Relation client du dossier « atelier », par le contrat de l'extension
  # CRM : prospects et organisations (dont une collectivité et un
  # particulier), contacts (dont un opposé à la prospection), opportunités à
  # toutes les étapes du pipeline, un devis créé depuis une opportunité,
  # activités en retard, du jour et à venir.
  module CrmSeed
    extend self
    include Support

    alias CApi = ::Crm::Api

    def load(dossier : Dossier) : Nil
      ::Crm::Defaults.ensure!
      owner = dossier.actor
      seller = Auth.user_by_email(system, dossier.people.last.email).try(&.id) || owner.user_id
      manager = owner.user_id
      organizations = {
        "moulin"  => {"Gîte du Moulin de Rochecorbon", "business", "", "Rochecorbon", "website", seller},
        "chauvin" => {"Domaine Chauvin", "business", "", "Vouvray", "fair", manager},
        "halles"  => {"Pharmacie des Halles", "business", "", "Tours", "referral", seller},
        "ccvb"    => {"Communauté de communes du Val de Brenne", "public", "", "Château-Renault", "prospecting", manager},
        "lefort"  => {"Julie Lefort", "individual", "", "Montlouis-sur-Loire", "website", seller},
        "creche"  => {"Crèche Les Petits Copeaux", "business", "", "Tours", "network", seller},
        "brasser" => {"Brasserie de la Loire", "business", "", "Amboise", "fair", manager},
      }.to_h do |key, (name, nature, siren, city, origin, user)|
        input = CApi::OrganizationInput.new(name: name, nature: nature, siren: siren, city: city, country_code: "FR",
          source_id: source(origin), owner_id: user)
        {key, ok(CApi.create_organization(owner, input), "organisation #{name}").id}
      end

      contacts = {
        "roux"    => {"moulin", "ms", "Anne", "Roux", "Gérante", "anne.roux@gite-moulin.test"},
        "chauvin" => {"chauvin", "mr", "Pierre", "Chauvin", "Vigneron", "pierre@domaine-chauvin.test"},
        "halles"  => {"halles", "ms", "Nadia", "Benali", "Pharmacienne titulaire", "n.benali@pharmacie-halles.test"},
        "ccvb"    => {"ccvb", "mr", "Olivier", "Perrin", "Directeur des services techniques", "o.perrin@ccvb.test"},
        "creche"  => {"creche", "ms", "Lucie", "Fabre", "Directrice", "direction@petits-copeaux.test"},
        "brasser" => {"brasser", "mr", "Hugo", "Masson", "Associé", "hugo@brasserie-loire.test"},
      }.to_h do |key, (organization, civility, first, last, job, email)|
        input = CApi::ContactInput.new(last_name: last, first_name: first, organization_id: organizations[organization],
          civility: civility, job_title: job, email: email, legal_basis: "legitimate_interest", source_id: source("fair"))
        {key, ok(CApi.create_contact(owner, input), "contact #{first} #{last}").id}
      end
      opposed = ok(CApi.create_contact(owner, CApi::ContactInput.new(last_name: "Lefort", first_name: "Julie",
        organization_id: organizations["lefort"], email: "julie.lefort@exemple.test", legal_basis: "consent")), "contact opposé")
      ok(CApi.record_opposition(owner, opposed.id, "Ne souhaite plus recevoir d'offres (courriel du client)"), "opposition")

      opportunity = ->(title : String, organization : String, contact : String?, amount : String, stage_code : String, user : Int64?, close_in : Int32) do
        start = stage_code.in?("won", "lost") ? "negotiation" : stage_code
        input = CApi::OpportunityInput.new(title: title, organization_id: organizations[organization],
          contact_id: contact.try { |key| contacts[key] }, amount: d(amount), expected_close_on: today + close_in.days,
          owner_id: user, stage_id: stage(start), source_id: source("fair"))
        ok(CApi.create_opportunity(owner, input), "opportunité #{title}").id
      end
      opportunity.call("Agencement des chambres d'hôtes", "moulin", "roux", "18500", "discovery", seller, 75)
      opportunity.call("Mobilier de la salle du conseil", "ccvb", "ccvb", "32000", "discovery", manager, 120)
      qualification = opportunity.call("Comptoir et rayonnages", "halles", "halles", "14200", "qualification", seller, 40)
      proposal = opportunity.call("Chai de dégustation en chêne", "chauvin", "chauvin", "21800", "discovery", manager, 30)
      opportunity.call("Coin lecture et rangements", "creche", "creche", "6900", "negotiation", seller, 10)
      opportunity.call("Bibliothèque sous escalier", "lefort", nil, "4300", "proposal", seller, 18)
      won = opportunity.call("Bar et étagères à fûts", "brasser", "brasser", "9600", "won", manager, -6)
      lost = opportunity.call("Tables de la terrasse", "moulin", "roux", "5200", "lost", seller, -12)
      ok(CApi.move_opportunity(owner, won, CApi::MoveInput.new(stage("won"))), "opportunité gagnée")
      reason = CApi.loss_reasons(system).find! { |item| item.code == "competitor" }.id
      ok(CApi.move_opportunity(owner, lost, CApi::MoveInput.new(stage("lost"), reason, "Concurrent moins cher de 12 %")),
        "opportunité perdue")
      # Devis brouillon créé depuis l'opportunité : le prospect devient
      # client, l'opportunité passe à « Proposition ».
      ok(CApi.create_quote(owner, proposal), "devis depuis l'opportunité")

      activity = ->(kind : String, subject : String, days : Int32, user : Int64?, opportunity_id : Int64?, organization : String?) do
        input = CApi::ActivityInput.new(kind: kind, subject: subject, due_on: today + days.days, owner_id: user,
          opportunity_id: opportunity_id, organization_id: organization.try { |key| organizations[key] })
        ok(CApi.create_activity(owner, input), "activité #{subject}")
      end
      activity.call("call", "Rappeler Pierre Chauvin au sujet du devis du chai", -2, manager, proposal, nil)
      activity.call("email", "Envoyer des photos de réalisations en pharmacie", 0, seller, qualification, nil)
      activity.call("meeting", "Relevé de cotes au gîte", 4, seller, nil, "moulin")
      activity.call("task", "Chiffrer le mobilier de la salle du conseil", -1, manager, nil, "ccvb")
      activity.call("note", "Préfère être contactée le mardi", 0, seller, nil, "creche")
      activity.call("meeting", "Présentation des essences de bois à la brasserie", 9, manager, won, nil)
    end

    private def stage(code : String) : Int64
      CApi.stages(system).find! { |item| item.code == code }.id
    end

    private def source(code : String) : Int64
      CApi.sources(system).find! { |item| item.code == code }.id
    end
  end
end
