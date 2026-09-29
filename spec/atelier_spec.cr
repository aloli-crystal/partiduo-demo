# SPDX-License-Identifier: AGPL-3.0-or-later

require "./spec_helper"

# Grands totaux du dossier fictif « atelier » sur son exercice complet
# (l'année précédente) : ils ne dépendent que du scénario (montants
# déterministes), pas du jour où il est chargé.
private alias Acc = Partiduo::Api::Accounting
private alias Inv = Partiduo::Api::Invoicing

describe PartiduoDemo::Atelier do
  complete = -> { DemoSpec.atelier.year - 1 }
  whole_year = ->(year : Int32) { Acc::TrialBalanceQuery.new(date_from: Time.utc(year, 1, 1), date_to: Time.utc(year, 12, 31)) }

  it "tient une balance équilibrée sur l'exercice complet et sur l'exercice en cours" do
    actor = DemoSpec.atelier.actor
    balance = Acc.trial_balance(actor, whole_year.call(complete.call))
    balance.delta.should eq(BigDecimal.new(0))
    balance.total.debit.should be > BigDecimal.new(500_000)
    current = Acc.trial_balance(actor, whole_year.call(complete.call + 1))
    current.delta.should eq(BigDecimal.new(0))
  end

  it "réalise le chiffre d'affaires attendu sur l'exercice complet (comptes 70)" do
    rows = Acc.trial_balance(DemoSpec.atelier.actor, whole_year.call(complete.call)).rows.select(&.number.starts_with?("70"))
    turnover = rows.sum(BigDecimal.new(0)) { |row| row.credit - row.debit }
    turnover.should eq(BigDecimal.new("141156"))
  end

  it "collecte la TVA des ventes et déclare douze CA3 closes sur l'exercice complet" do
    actor = DemoSpec.atelier.actor
    sales = Acc.ledgers(actor, Acc::LedgerKind::Sale).map(&.id)
    query = whole_year.call(complete.call).copy_with(ledger_ids: sales)
    collected = Acc.trial_balance(actor, query).rows.select(&.number.==("44571")).sum(BigDecimal.new(0)) { |row| row.credit - row.debit }
    # 20 % du chiffre d'affaires : toutes les ventes sont au taux normal.
    collected.should eq(BigDecimal.new("28231.20"))
    returns = Acc.vat_returns(actor, "fr_ca3", complete.call)
    returns.size.should eq(12)
    returns.all?(&.status.==("closed")).should be_true
  end

  it "émet ses factures en série continue, toutes comptabilisées" do
    actor = DemoSpec.atelier.actor
    year = complete.call
    invoices = Inv.documents(actor, Inv::DocumentQuery.new(kind: "invoice", from: Time.utc(year, 1, 1), to: Time.utc(year, 12, 31), limit: 500))
    invoices.size.should eq(54)
    numbers = invoices.compact_map(&.number).sort!
    numbers.uniq.size.should eq(invoices.size)
    invoices.each do |invoice|
      Acc.entries(actor, Acc::EntryQuery.new(source: "invoice:#{invoice.id}")).should_not be_empty
    end
  end

  it "rapproche chaque relevé bancaire de l'exercice complet et suit le stock de l'atelier" do
    actor = DemoSpec.atelier.actor
    bank = Acc.ledgers(actor, Acc::LedgerKind::Financial).first
    statements = Acc.bank_statements(actor, bank.id).select(&.reference.ends_with?("/#{complete.call}"))
    statements.size.should eq(12)
    Partiduo::Api::Stock.movements(actor, Partiduo::Api::Stock::MovementQuery.new).should_not be_empty
  end

  it "transmet la liasse, la DAS2 et la dernière CA3 au TELEDEC simulé" do
    actor = DemoSpec.atelier.actor
    filings = Teledec::Api.filings(actor)
    filings.map(&.kind).sort!.should eq(%w[das2 liasse vat_ca3])
    filings.all?(&.status.==("acknowledged")).should be_true
  end
end
